import SwiftUI
import SwiftData

/// 專業級大圖與影片預覽燈箱（Media Viewer Modal）
/// 支援手勢縮放拖曳、原生影片播放、上一張/下一張切換、側邊詳細資訊面板與全螢幕
public struct MediaViewerModal: View {
    public let items: [MediaItem]
    @Binding public var currentItemID: UUID?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var currentIndex: Int = 0
    @State private var isInspectorOpen: Bool = false
    
    public init(items: [MediaItem], currentItemID: Binding<UUID?>) {
        self.items = items
        self._currentItemID = currentItemID
    }
    
    private var currentItem: MediaItem? {
        guard currentIndex >= 0 && currentIndex < items.count else { return nil }
        return items[currentIndex]
    }
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let item = currentItem {
                HStack(spacing: 0) {
                    // 主體預覽視窗
                    ZStack {
                        if item.mediaType == .video && item.fileExistsOnDisk {
                            CustomVideoPlayerView(videoURL: item.fileURL)
                                .id(item.id) // 切換檔案時重新掛載播放器
                        } else if item.fileExistsOnDisk {
                            InteractiveZoomImageView(imageURL: item.fileURL)
                                .id(item.id)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.orange)
                                Text("Media file is missing on disk")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // 左右切換導覽按鈕
                        navigationArrows
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 側邊資訊面板
                    if isInspectorOpen {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                        
                        MediaInspectorView(item: item)
                            .transition(.move(edge: .trailing))
                    }
                }
            }
            
            // 頂部懸浮工具列
            VStack {
                topToolbar
                Spacer()
            }
        }
        .frame(minWidth: 800, minHeight: 560)
        .onAppear {
            if let id = currentItemID, let idx = items.firstIndex(where: { $0.id == id }) {
                currentIndex = idx
            }
        }
        // 快捷鍵控制上一張 / 下一張
        .background(
            KeyEventListenerView(
                onSpace: {},
                onLeftArrow: { goToPrevious() },
                onRightArrow: { goToNext() }
            )
        )
    }
    
    // MARK: - 頂部控制列
    private var topToolbar: some View {
        HStack(spacing: 16) {
            // 關閉按鈕
            Button(action: {
                currentItemID = nil
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .help("關閉預覽 (Esc)")
            
            if let item = currentItem {
                Text(item.originalFileName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("(\(currentIndex + 1) / \(items.count))")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            if let item = currentItem {
                // 收藏切換
                Button(action: {
                    item.isFavorite.toggle()
                    try? modelContext.save()
                }) {
                    Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundColor(item.isFavorite ? .red : .white.opacity(0.85))
                }
                .buttonStyle(.plain)
                .help(item.isFavorite ? "移除收藏" : "加入收藏")
                
                // 資訊側欄開關
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isInspectorOpen.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 16))
                        .foregroundColor(isInspectorOpen ? .accentColor : .white.opacity(0.85))
                }
                .buttonStyle(.plain)
                .help("顯示詳細資訊與標籤")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - 左右換頁按鈕
    private var navigationArrows: some View {
        HStack {
            // 上一張
            if currentIndex > 0 {
                Button(action: goToPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)
                .help("上一張 (左方向鍵)")
            }
            
            Spacer()
            
            // 下一張
            if currentIndex < items.count - 1 {
                Button(action: goToNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .help("下一張 (右方向鍵)")
            }
        }
    }
    
    private func goToPrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        currentItemID = items[currentIndex].id
    }
    
    private func goToNext() {
        guard currentIndex < items.count - 1 else { return }
        currentIndex += 1
        currentItemID = items[currentIndex].id
    }
}
