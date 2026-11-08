import SwiftUI

/// 左側側邊導覽列（Sidebar）
/// 遵循 macOS 原生 Human Interface Guidelines，精緻、透光、自適應，100% 呼應手繪稿原型
public struct SidebarNavigationView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // [不可變更規則] 左上角固定品牌識別區（含雙旋迴環箭頭 Noty 向量圖形）
            BrandHeaderView()
            
            Divider()
                .padding(.horizontal, 14)
                .opacity(0.6)
            
            // 主要分頁項目捲動/清單區
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 3) {
                    sidebarItem(tab: .home)
                    sidebarItem(tab: .gallery)
                    sidebarItem(tab: .diary)
                    sidebarItem(tab: .calendar)
                    sidebarItem(tab: .albums)
                    sidebarItem(tab: .videos)
                    
                    // 忠實呼應手繪稿中左側側欄的 [Upload] 按鈕
                    sidebarActionItem(
                        title: "Upload",
                        icon: "arrow.up.square",
                        help: "上傳相片、影片或撰寫回憶日記 (⌘U)"
                    ) {
                        appState.isUploadSheetPresented = true
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Collections")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.leading, 12)
                            .padding(.top, 14)
                        
                        sidebarItem(tab: .favorites)
                        sidebarItem(tab: .recentlyAdded)
                        sidebarItem(tab: .duplicates)
                        sidebarItem(tab: .trash)
                    }
                    
                    // 忠實呼應手繪稿中左側側欄的 [...] 更多選單
                    sidebarActionItem(
                        title: "More...",
                        icon: "ellipsis.circle",
                        help: "關於 Noty 與資料庫資訊"
                    ) {
                        appState.isAboutSheetPresented = true
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            
            Spacer(minLength: 10)
            
            Divider()
                .padding(.horizontal, 14)
                .opacity(0.6)
            
            // 底部設定按鈕（對應手繪圖左下角齒輪）
            sidebarItem(tab: .settings)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
        }
        .frame(minWidth: 210, idealWidth: 225, maxWidth: 240)
        .background(
            Color(nsColor: .windowBackgroundColor)
                .opacity(0.85)
                .background(.ultraThinMaterial)
        )
    }
    
    @ViewBuilder
    private func sidebarItem(tab: NavigationTab) -> some View {
        SidebarItemButton(
            tab: tab,
            isSelected: appState.selectedTab == tab
        ) {
            if !reduceMotion {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    appState.selectedTab = tab
                }
            } else {
                appState.selectedTab = tab
            }
        }
    }
    
    @ViewBuilder
    private func sidebarActionItem(title: String, icon: String, help: String, action: @escaping () -> Void) -> some View {
        SidebarActionButton(title: title, iconName: icon, helpText: help, action: action)
    }
}

/// 具備 Hover 平滑微回饋的導覽按鈕
struct SidebarItemButton: View {
    let tab: NavigationTab
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: isSelected ? tab.selectedIconName : tab.iconName)
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    .frame(width: 20)
                    .foregroundColor(isSelected ? .accentColor : (isHovered ? .primary : .secondary))
                
                Text(tab.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(isSelected ? .primary : (isHovered ? .primary : .secondary))
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityHint(isSelected ? "Currently selected tab" : "Switch to \(tab.title) view")
        .onHover { hovering in
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            } else {
                isHovered = hovering
            }
        }
    }
}

/// 側邊欄快速功能按鈕（例如 Upload 與 More）
struct SidebarActionButton: View {
    let title: String
    let iconName: String
    let helpText: String
    let action: () -> Void
    
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                    .foregroundColor(isHovered ? .accentColor : .secondary)
                
                Text(title)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(isHovered ? .primary : .secondary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(helpText)
        .accessibilityLabel(title)
        .accessibilityHint(helpText)
        .onHover { hovering in
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            } else {
                isHovered = hovering
            }
        }
    }
}
