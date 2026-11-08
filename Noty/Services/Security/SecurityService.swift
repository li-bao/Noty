import Foundation
import LocalAuthentication
import SwiftUI
import Combine

/// 隱私保險庫與本機生物識別服務（SecurityService）
/// 遵循 macOS 原生 LocalAuthentication 與 Security Keychain 規範，
/// 支援 Touch ID、系統認證以及本機 Keychain 獨立鎖定密碼雙層解鎖
@MainActor
public final class SecurityService: ObservableObject {
    public static let shared = SecurityService()
    
    @Published public var isBiometricsAvailable: Bool = false
    @Published public var biometryType: LABiometryType = .none
    @Published public var authErrorMessage: String? = nil
    @Published public var lastActiveTimestamp: Date = Date()
    @Published public var isCustomPasscodeSet: Bool = false
    
    /// 隱私聲明（強制性宣告，誠實揭露鎖定邊界）
    public static let privacyNotice = "注意：Noty 應用程式鎖定主要保護 Noty 應用程式的操作介面與畫面隱私，避免在多工環境下被他人窺視。它不會加密本機 Finder 中的媒體檔案本身。"
    
    private var idleCheckTimer: AnyCancellable?
    
    private init() {
        checkBiometricsAvailability()
        refreshCustomPasscodeStatus()
        setupIdleMonitor()
    }
    
    /// 檢查硬體是否具備 Touch ID 或系統驗證支援
    public func checkBiometricsAvailability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            self.isBiometricsAvailable = true
            self.biometryType = context.biometryType
        } else {
            self.isBiometricsAvailable = false
            self.biometryType = .none
        }
    }
    
    /// 更新 Keychain 密碼設置狀態
    public func refreshCustomPasscodeStatus() {
        self.isCustomPasscodeSet = KeychainService.shared.hasPasscode()
    }
    
    /// 記錄使用者活動，刷新閒置計時器
    public func recordUserActivity() {
        self.lastActiveTimestamp = Date()
    }
    
    /// 設定閒置自動鎖定監控
    private func setupIdleMonitor() {
        // 每 15 秒檢查一次是否超時
        idleCheckTimer = Timer.publish(every: 15, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.evaluateIdleAutoLock()
            }
    }
    
    /// 評估是否觸發自動鎖定
    private func evaluateIdleAutoLock() {
        let autoLockMinutes = UserDefaults.standard.integer(forKey: "auto_lock_minutes")
        guard autoLockMinutes > 0 else { return } // 0 代表「從不」
        
        let idleSeconds = Date().timeIntervalSince(lastActiveTimestamp)
        let thresholdSeconds = Double(autoLockMinutes * 60)
        
        if idleSeconds >= thresholdSeconds {
            NotificationCenter.default.post(name: .notyRequestAutoLock, object: nil)
        }
    }
    
    /// 驗證獨立應用程式鎖定密碼（透過 Keychain 比對，零明文儲存）
    public func unlockWithCustomPasscode(_ input: String) -> Bool {
        if KeychainService.shared.verifyPasscode(input) {
            self.authErrorMessage = nil
            self.recordUserActivity()
            return true
        } else {
            self.authErrorMessage = "密碼不正確，請重新輸入"
            return false
        }
    }
    
    /// 要求 Touch ID 或 macOS 系統身分驗證解鎖
    public func requestUnlockVault(reason: String = "解鎖 Noty 私人媒體與日記保險庫") async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "取消"
        
        var error: NSError?
        let policy: LAPolicy = .deviceOwnerAuthentication
        
        guard context.canEvaluatePolicy(policy, error: &error) else {
            // 如果環境完全不具備生物認證及密碼，回退檢查是否有 Keychain 密碼
            if isCustomPasscodeSet {
                self.authErrorMessage = "請使用應用程式密碼解鎖"
                return false
            }
            self.authErrorMessage = nil
            self.recordUserActivity()
            return true
        }
        
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: reason) { [weak self] success, evalError in
                DispatchQueue.main.async {
                    guard let self = self else {
                        continuation.resume(returning: false)
                        return
                    }
                    if success {
                        self.authErrorMessage = nil
                        self.recordUserActivity()
                        continuation.resume(returning: true)
                    } else {
                        if let evalError = evalError as? LAError {
                            switch evalError.code {
                            case .userCancel:
                                self.authErrorMessage = "已取消解鎖"
                            case .authenticationFailed:
                                self.authErrorMessage = "生物識別驗證失敗，請再試一次"
                            case .biometryLockout:
                                self.authErrorMessage = "Touch ID 已被鎖定，請使用系統或應用程式密碼"
                            default:
                                self.authErrorMessage = evalError.localizedDescription
                            }
                        }
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
}

public extension Notification.Name {
    static let notyRequestAutoLock = Notification.Name("notyRequestAutoLock")
}
