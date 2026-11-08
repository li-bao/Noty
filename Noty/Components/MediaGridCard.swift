import SwiftUI

/// 統一的高效媒體縮圖卡片組件（支援影片標記、愛心標記與選取外框）
public struct MediaGridCard: View {
    public let item: MediaItem
    public var isSelected: Bool = false
    public var showTitle: Bool = true
    
    @State private var isHovered = false
    
    public init(item: MediaItem, isSelected: Bool = false, showTitle: Bool = true) {
        self.item = item
        self.isSelected = isSelected
        self.showTitle = showTitle
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomLeading) {
                    AsyncThumbnailView(storedFileName: item.storedFileName, isVideo: item.mediaType == .video, fallbackURL: item.fileURL)
                        .aspectRatio(1, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    if item.mediaType == .video {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 8))
                            if item.durationSeconds > 0 {
                                let mins = Int(item.durationSeconds) / 60
                                let secs = Int(item.durationSeconds) % 60
                                Text(String(format: "%02d:%02d", mins, secs))
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            }
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(5)
                    }
                }
                
                HStack(spacing: 3) {
                    if item.isImportant {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 9))
                            .padding(3)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    if item.isProtected {
                        Image(systemName: "shield.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 9))
                            .padding(3)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    if item.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 10))
                            .padding(3)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(4)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.12 : 0.04), radius: isHovered ? 5 : 2, x: 0, y: isHovered ? 2 : 1)
            .onHover { isHovered = $0 }
            
            if showTitle {
                Text(item.originalFileName)
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .foregroundColor(.primary)
            }
        }
    }
}
