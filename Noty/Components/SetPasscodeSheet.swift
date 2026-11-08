import SwiftUI

/// 設定 / 變更保險庫鎖定密碼視窗（SetPasscodeSheet）
/// 遵循嚴格資安準則：密碼一律儲存於 macOS Keychain，絕不在 UserDefaults / SwiftData 儲存明文
public struct SetPasscodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var newPasscode: String = ""
    @State private var confirmPasscode: String = ""
    @State private var errorMessage: String? = nil
    @State private var hasExistingPasscode: Bool = KeychainService.shared.hasPasscode()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // 頂部標題區
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hasExistingPasscode ? "變更保險庫密碼" : "設定保險庫密碼")
                            .font(.headline)
                        Text("作為 Touch ID 無法使用時的本機備援解鎖途徑")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("取消") {
                    dismiss()
                }
            }
            .padding(20)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            VStack(spacing: 18) {
                // 資安提示橫幅
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.green)
                    Text("安全保證：密碼將安全加密儲存於 macOS 原生 Keychain，Noty 不會在任何明文檔案或資料庫中保存密碼。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.green.opacity(0.08))
                .cornerRadius(8)
                
                if let err = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("輸入新密碼：")
                        .font(.caption.bold())
                    SecureField("至少 4 位數密碼...", text: $newPasscode)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("確認新密碼：")
                        .font(.caption.bold())
                    SecureField("再次輸入相同密碼...", text: $confirmPasscode)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack(spacing: 12) {
                    if hasExistingPasscode {
                        Button("移除密碼 (僅用 Touch ID)", role: .destructive) {
                            KeychainService.shared.deletePasscode()
                            SecurityService.shared.refreshCustomPasscodeStatus()
                            dismiss()
                        }
                    }
                    
                    Spacer()
                    
                    Button("儲存至 Keychain") {
                        savePasscode()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newPasscode.isEmpty || confirmPasscode.isEmpty)
                }
                .padding(.top, 10)
            }
            .padding(24)
        }
        .frame(width: 440)
    }
    
    private func savePasscode() {
        guard newPasscode.count >= 4 else {
            errorMessage = "密碼長度至少需為 4 個字元"
            return
        }
        
        guard newPasscode == confirmPasscode else {
            errorMessage = "兩次輸入的密碼不相符，請重新確認"
            return
        }
        
        let success = KeychainService.shared.savePasscode(newPasscode)
        if success {
            SecurityService.shared.refreshCustomPasscodeStatus()
            dismiss()
        } else {
            errorMessage = "儲存密碼至 Keychain 失敗，請檢查系統存取權限"
        }
    }
}
