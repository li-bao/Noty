import SwiftUI
import AppKit
import Combine

/// 全域外觀主題管理服務（AppearanceManager）
/// 徹底解決 Dark / Light / System 外觀切換 Bug：
/// 1. Light -> 強制 .light，NSApp.appearance = NSAppearance(named: .aqua)
/// 2. Dark -> 強制 .dark，NSApp.appearance = NSAppearance(named: .darkAqua)
/// 3. System -> 設為 nil，NSApp.appearance = nil，主動通知所有視窗即時重置，釋放 Dark 覆寫
/// 4. 啟動時自動同步，無需使用者重啟 App
@MainActor
public final class AppearanceManager: ObservableObject {
    public static let shared = AppearanceManager()
    
    public enum ThemeOption: String, CaseIterable, Identifiable {
        case system = "system"
        case light = "light"
        case dark = "dark"
        
        public var id: String { rawValue }
        
        public var localizedName: String {
            switch self {
            case .system: return "跟隨系統 (System)"
            case .light: return "淺色模式 (Light)"
            case .dark: return "深色模式 (Dark)"
            }
        }
    }
    
    @Published public private(set) var currentTheme: ThemeOption = .system
    
    private init() {
        let stored = UserDefaults.standard.string(forKey: "app_theme") ?? "system"
        self.currentTheme = ThemeOption(rawValue: stored) ?? .system
        apply(self.currentTheme)
    }
    
    public var preferredColorScheme: ColorScheme? {
        switch currentTheme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
    
    public func setTheme(_ option: ThemeOption) {
        self.currentTheme = option
        UserDefaults.standard.set(option.rawValue, forKey: "app_theme")
        apply(option)
    }
    
    public func apply(_ option: ThemeOption) {
        switch option {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil
        }
        
        // 確保所有已開啟之 macOS 原生視窗即時更新 Appearance
        for window in NSApp.windows {
            switch option {
            case .light:
                window.appearance = NSAppearance(named: .aqua)
            case .dark:
                window.appearance = NSAppearance(named: .darkAqua)
            case .system:
                window.appearance = nil
            }
        }
    }
}
