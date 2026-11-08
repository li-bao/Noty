import Foundation
import SwiftData

/// 應用程式本機設定實體
@Model
public final class AppSettings {
    @Attribute(.unique) public var id: UUID
    public var ollamaBaseURL: String
    public var selectedOllamaModel: String
    public var isBiometricLockEnabled: Bool
    public var autoLockTimeoutMinutes: Int
    public var themeMode: String
    
    public init(
        id: UUID = UUID(),
        ollamaBaseURL: String = "http://127.0.0.1:11434",
        selectedOllamaModel: String = "llama3.2",
        isBiometricLockEnabled: Bool = false,
        autoLockTimeoutMinutes: Int = 5,
        themeMode: String = "system"
    ) {
        self.id = id
        self.ollamaBaseURL = ollamaBaseURL
        self.selectedOllamaModel = selectedOllamaModel
        self.isBiometricLockEnabled = isBiometricLockEnabled
        self.autoLockTimeoutMinutes = autoLockTimeoutMinutes
        self.themeMode = themeMode
    }
}
