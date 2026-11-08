import SwiftUI

/// 精緻的相簿空狀態視圖（100% 忠實呼應手繪稿原型佈局）
/// 頂部帶有日期條 2026/11/6 (五) 與 (↑)(↓)(🗂️) 控制鈕，
/// 內部卡片呈現 "Nothing here... ☹️" 與 "try [↑ upload]" 以及 "[open file...]"
public struct GalleryEmptyView: View {
    public let onUpload: () -> Void
    public let onOpenFile: () -> Void
    
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(onUpload: @escaping () -> Void, onOpenFile: @escaping () -> Void) {
        self.onUpload = onUpload
        self.onOpenFile = onOpenFile
    }
    
    /// 依手繪稿格式化當前日期（例如 2026/11/6(五)）
    private var formattedTodayDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.dateFormat = "yyyy/M/d (E)"
        return formatter.string(from: Date())
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            
            // 手繪稿中央外框卡片（含日期頂標與空狀態內容）
            VStack(spacing: 0) {
                // MARK: - 日期與排序操作條 (2026/11/6(五)  (↑)(↓)(🗂️))
                HStack(alignment: .center, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.accentColor)
                        
                        Text(formattedTodayDate)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // (↑) 升冪排序按鈕
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.isAscendingOrder = true
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 17))
                            .foregroundColor(appState.isAscendingOrder ? .accentColor : .secondary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .help("依日期升冪排序（最舊優先）")
                    
                    // (↓) 降冪排序按鈕
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.isAscendingOrder = false
                        }
                    }) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 17))
                            .foregroundColor(!appState.isAscendingOrder ? .accentColor : .secondary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .help("依日期降冪排序（最新優先）")
                    
                    // (🗂️) 分類模式
                    Button(action: {
                        appState.selectedTab = .diary
                    }) {
                        Image(systemName: "folder.circle.fill")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("切換至時間軸回憶或資料夾模式")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                
                Divider()
                
                // MARK: - 中央空狀態主體區
                VStack(spacing: 24) {
                    Spacer()
                    
                    // "Nothing here... ☹️"
                    HStack(spacing: 8) {
                        Text("Nothing here...")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("☹️")
                            .font(.system(size: 28))
                    }
                    
                    // "try [↑ upload]"
                    HStack(spacing: 12) {
                        Text("try")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Button(action: onUpload) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 13, weight: .bold))
                                Text("upload")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .help("開啟 Noty 上傳面板或撰寫新回憶 (⌘U)")
                    }
                    
                    // "[open file...]"
                    Button(action: onOpenFile) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder")
                                .font(.system(size: 13))
                            Text("open file...")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.bordered)
                    .help("直接從 Mac 挑選檔案匯入至 Noty 沙盒庫")
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 260)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
            }
            .frame(maxWidth: 540)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 32)
            
            Spacer(minLength: 30)
        }
    }
}
