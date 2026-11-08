import Foundation
import Security

/// macOS 原生 Keychain 安全存取服務（KeychainService）
/// 遵循 Apple 原生 Security 框架，專門儲存 Noty 保險庫備援解鎖密碼
/// 嚴格技術規範：絕對不要將明文密碼存入 UserDefaults 或 SwiftData！
public final class KeychainService: @unchecked Sendable {
    public static let shared = KeychainService()
    
    private let serviceName = "com.libao.noty.vault"
    private let accountName = "vault_passcode"
    
    private init() {}
    
    /// 儲存或更新應用程式解鎖密碼至 Keychain
    @discardableResult
    public func savePasscode(_ passcode: String) -> Bool {
        guard let data = passcode.data(using: .utf8) else { return false }
        
        // 1. 先嘗試查詢是否已存在
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            // 已存在，執行更新
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            return updateStatus == errSecSuccess
        } else if status == errSecItemNotFound {
            // 不存在，新增條目
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            return addStatus == errSecSuccess
        } else {
            return false
        }
    }
    
    /// 從 Keychain 讀取密碼（內部比對專用，不公開明文給非驗證層）
    private func retrievePasscode() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return password
    }
    
    /// 驗證使用者輸入的密碼是否與 Keychain 儲存的一致
    public func verifyPasscode(_ input: String) -> Bool {
        guard let stored = retrievePasscode() else {
            return false
        }
        return stored == input
    }
    
    /// 檢查使用者是否已設定應用程式鎖定密碼
    public func hasPasscode() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// 從 Keychain 安全抹除應用程式鎖定密碼
    @discardableResult
    public func deletePasscode() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
