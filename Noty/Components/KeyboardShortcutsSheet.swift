import SwiftUI

/// macOS 原生快捷鍵指南視窗（Keyboard Shortcuts Sheet）
public struct KeyboardShortcutsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    private struct ShortcutItem: Identifiable {
        let id = UUID()
        let keys: [String]
        let action: String
        let category: String
    }
    
    private let shortcuts: [ShortcutItem] = [
        ShortcutItem(keys: ["⌘", "U"], action: "快速上傳相片與影片至沙盒庫", category: "媒體與創作"),
        ShortcutItem(keys: ["⌘", "N"], action: "建立並撰寫新日記", category: "媒體與創作"),
        ShortcutItem(keys: ["⌘", "S"], action: "在日記編輯器中立即儲存草稿", category: "媒體與創作"),
        ShortcutItem(keys: ["⌘", "K"], action: "開啟 / 收起本機 Ollama AI 助理", category: "智慧輔助"),
        ShortcutItem(keys: ["⌘", "L"], action: "立即鎖定 Noty 保險庫（防窺上鎖）", category: "安全與隱私"),
        ShortcutItem(keys: ["⌘", "1"], action: "前往「首頁 (Home)」", category: "導覽導引"),
        ShortcutItem(keys: ["⌘", "2"], action: "前往「藝廊 (Gallery)」", category: "導覽導引"),
        ShortcutItem(keys: ["⌘", "3"], action: "前往「日記時間軸 (Diary)」", category: "導覽導引"),
        ShortcutItem(keys: ["⌘", "4"], action: "前往「影片專櫃 (Videos)」", category: "導覽導引"),
        ShortcutItem(keys: ["⌘", ","], action: "開啟「設定 (Settings)」", category: "系統控制"),
        ShortcutItem(keys: ["⌘", "Q"], action: "退出 Noty 應用程式", category: "系統控制")
    ]
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // 頂部標題區
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "command.square.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keyboard Shortcuts")
                            .font(.headline)
                        Text("Noty 原生高效快捷鍵一覽表")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // 快捷鍵清單
            ScrollView {
                VStack(spacing: 16) {
                    let categories = Array(Set(shortcuts.map { $0.category })).sorted()
                    ForEach(categories, id: \.self) { cat in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(cat)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 4)
                            
                            VStack(spacing: 6) {
                                ForEach(shortcuts.filter { $0.category == cat }) { item in
                                    HStack {
                                        Text(item.action)
                                            .font(.system(size: 13, design: .rounded))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 4) {
                                            ForEach(item.keys, id: \.self) { k in
                                                Text(k)
                                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(Color(nsColor: .controlBackgroundColor))
                                                    .cornerRadius(5)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 5)
                                                            .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                                                    )
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.secondary.opacity(0.04))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 480, height: 440)
    }
}
