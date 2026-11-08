import Foundation
import CryptoKit
import Security
import Combine
import SwiftUI

/// Noty 保險庫全域狀態與金鑰管理服務（VaultEncryptionService）
/// 負責：
/// - 保險庫生命週期（Disabled, Locked, Unlocked, Migrating）
/// - 密碼設定與金鑰推導
/// - SwiftData 欄位級敏感資訊加解密 (Field-Level Encryption)
/// - 媒體檔案與縮圖安全串流加解密
/// - 記憶體金鑰安全釋放（Lock 時立即抹除主金鑰）
@MainActor
public final class VaultEncryptionService: ObservableObject {
    public static let shared = VaultEncryptionService()
    
    public enum VaultStatus: String, CaseIterable, Identifiable {
        case disabled = "Disabled"
        case locked = "Locked"
        case unlocked = "Unlocked"
        case migrating = "Migrating"
        case error = "Error"
        
        public var id: String { rawValue }
    }
    
    @Published public private(set) var status: VaultStatus = .disabled
    @Published public private(set) var isVaultConfigured: Bool = false
    @Published public private(set) var lastErrorMessage: String? = nil
    @Published public private(set) var migrationProgress: Double = 0.0
    @Published public private(set) var migrationStatusText: String = ""
    
    // 記憶體中暫存的活動對稱金鑰（鎖定時徹底抹除，絕不落盤）
    private var activeKey: SymmetricKey? = nil
    
    private let keychainService = "com.libao.noty.aes256"
    private let saltAccount = "vault_salt"
    private let verificationAccount = "vault_verification_token"
    private let verificationSentinel = "NOTY_VAULT_ACTIVE_SENTINEL_OK"
    
    private init() {
        checkVaultConfiguration()
    }
    
    // MARK: - State Inspection
    
    /// 檢查系統是否已配置過 AES-256 保險庫
    public func checkVaultConfiguration() {
        if hasStoredSalt() && hasStoredVerification() {
            self.isVaultConfigured = true
            if self.activeKey == nil {
                self.status = .locked
            } else {
                self.status = .unlocked
            }
        } else {
            self.isVaultConfigured = false
            self.status = .disabled
        }
    }
    
    public var isUnlocked: Bool {
        return status == .unlocked && activeKey != nil
    }
    
    public var currentKey: SymmetricKey? {
        return activeKey
    }
    
    // MARK: - Vault Setup & Authentication
    
    /// 初始化並啟用 AES-256 保險庫
    public func setupVault(masterPassword: String) throws {
        guard !masterPassword.isEmpty else {
            throw AES256VaultEngine.VaultError.invalidKey
        }
        
        // 1. 生成全新 32 位元組隨機 Salt
        let salt = try AES256VaultEngine.shared.generateSalt()
        
        // 2. 執行 600,000 次 PBKDF2 推導 256 位元金鑰
        let key = try AES256VaultEngine.shared.deriveKey(from: masterPassword, salt: salt)
        
        // 3. 生成認證標記 (Verification Sentinel)
        guard let sentinelData = verificationSentinel.data(using: .utf8) else {
            throw AES256VaultEngine.VaultError.invalidData
        }
        let verificationCiphertext = try AES256VaultEngine.shared.encryptData(sentinelData, withKey: key)
        
        // 4. 寫入 Keychain (Salt 與 驗證密文)
        saveKeychainData(salt, forAccount: saltAccount)
        saveKeychainData(verificationCiphertext, forAccount: verificationAccount)
        
        // 5. 設為解鎖狀態
        self.activeKey = key
        self.status = .unlocked
        self.isVaultConfigured = true
        self.lastErrorMessage = nil
    }
    
    /// 使用主密碼解鎖保險庫
    public func unlockVault(password: String) -> Bool {
        guard let salt = loadKeychainData(forAccount: saltAccount),
              let verificationCiphertext = loadKeychainData(forAccount: verificationAccount) else {
            self.lastErrorMessage = "保險庫未配置或 Salt 遺失"
            return false
        }
        
        do {
            let key = try AES256VaultEngine.shared.deriveKey(from: password, salt: salt)
            let decrypted = try AES256VaultEngine.shared.decryptData(verificationCiphertext, withKey: key)
            guard let decryptedString = String(data: decrypted, encoding: .utf8),
                  decryptedString == verificationSentinel else {
                self.lastErrorMessage = "密碼驗證未通過"
                return false
            }
            
            // 驗證通過，金鑰進駐記憶體
            self.activeKey = key
            self.status = .unlocked
            self.lastErrorMessage = nil
            return true
        } catch {
            self.lastErrorMessage = "解鎖失敗：密碼不符或資料已遭竄改"
            return false
        }
    }
    
    /// 立即鎖定保險庫，徹底抹除記憶體金鑰
    public func lockVault() {
        self.activeKey = nil
        self.status = isVaultConfigured ? .locked : .disabled
    }
    
    // MARK: - Field-Level Encryption (SwiftData DiaryEntry & MediaItem)
    
    private let fieldPrefix = "notyvlt:aes256:"
    
    /// 對敏感文字欄位進行加密（回傳可存入 SwiftData 的前綴 Base64 字串）
    public func encryptField(_ text: String) -> String {
        guard let key = activeKey, !text.isEmpty else {
            return text
        }
        
        guard let data = text.data(using: .utf8),
              let encrypted = try? AES256VaultEngine.shared.encryptData(data, withKey: key) else {
            return text
        }
        
        return fieldPrefix + encrypted.base64EncodedString()
    }
    
    /// 解密 SwiftData 欄位文字（若保險庫鎖定，則顯示安全提示遮罩）
    public func decryptField(_ cipherString: String) -> String {
        guard cipherString.hasPrefix(fieldPrefix) else {
            // 未加密之舊資料或明文
            return cipherString
        }
        
        guard let key = activeKey else {
            return "🔒 [此筆私人內容已加密保全，請解鎖保險庫查看]"
        }
        
        let base64Part = String(cipherString.dropFirst(fieldPrefix.count))
        guard let cipherData = Data(base64Encoded: base64Part),
              let decryptedData = try? AES256VaultEngine.shared.decryptData(cipherData, withKey: key),
              let result = String(data: decryptedData, encoding: .utf8) else {
            return "⚠️ [密文已毀損或金鑰不符]"
        }
        
        return result
    }
    
    // MARK: - File Encryption Utilities
    
    /// 加密沙盒內指定媒體檔案至 .notyvault
    public func encryptMedia(sourceURL: URL, destinationURL: URL) throws {
        guard let key = activeKey, let salt = loadKeychainData(forAccount: saltAccount) else {
            throw AES256VaultEngine.VaultError.invalidKey
        }
        try AES256VaultEngine.shared.encryptFile(at: sourceURL, to: destinationURL, key: key, salt: salt)
    }
    
    /// 解密指定 .notyvault 容器至暫存播放/檢視路徑
    public func decryptMedia(sourceVaultURL: URL, destinationURL: URL) throws {
        guard let key = activeKey else {
            throw AES256VaultEngine.VaultError.invalidKey
        }
        try AES256VaultEngine.shared.decryptFile(at: sourceVaultURL, to: destinationURL, key: key)
    }
    
    // MARK: - Keychain Helper Methods
    
    private func hasStoredSalt() -> Bool {
        return loadKeychainData(forAccount: saltAccount) != nil
    }
    
    private func hasStoredVerification() -> Bool {
        return loadKeychainData(forAccount: verificationAccount) != nil
    }
    
    private func saveKeychainData(_ data: Data, forAccount account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let updateAttrs: [String: Any] = [kSecValueData as String: data]
            SecItemUpdate(query as CFDictionary, updateAttrs as CFDictionary)
        } else {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }
    
    private func loadKeychainData(forAccount account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var ref: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &ref)
        guard status == errSecSuccess, let data = ref as? Data else {
            return nil
        }
        return data
    }
    
    public func resetVaultForTesting() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService
        ]
        SecItemDelete(query as CFDictionary)
        self.activeKey = nil
        self.status = .disabled
        self.isVaultConfigured = false
    }
}
