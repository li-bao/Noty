import SwiftUI

/// 今日回憶流體玻璃時光機卡片（OnThisDayCardView）
public struct OnThisDayCardView: View {
    public let memory: OnThisDayMemory
    public var onSelectMedia: (MediaItem) -> Void
    public var onSelectDiary: (DiaryEntry) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered: Bool = false
    
    public init(
        memory: OnThisDayMemory,
        onSelectMedia: @escaping (MediaItem) -> Void,
        onSelectDiary: @escaping (DiaryEntry) -> Void
    ) {
        self.memory = memory
        self.onSelectMedia = onSelectMedia
        self.onSelectDiary = onSelectDiary
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 頂部標頭
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.accentColor)
                
                Text("On This Day • \(memory.yearsAgo) Year\(memory.yearsAgo > 1 ? "s" : "") Ago")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(memory.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            // 媒體縮圖橫向預覽
            if !memory.mediaItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(memory.mediaItems.prefix(8)) { item in
                            Button(action: { onSelectMedia(item) }) {
                                AsyncThumbnailView(
                                    storedFileName: item.storedFileName,
                                    isVideo: item.mediaType == .video,
                                    fallbackURL: item.fileURL
                                )
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            
            // 日記摘錄
            if let diary = memory.diaries.first {
                Button(action: { onSelectDiary(diary) }) {
                    HStack(alignment: .top, spacing: 10) {
                        Text(diary.mood)
                            .font(.title3)
                            .fixedSize()
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(diary.title.isEmpty ? "Diary Entry" : diary.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            if !diary.content.isEmpty {
                                Text(diary.content)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .padding(10)
                    .background(Color.accentColor.opacity(0.08))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.35),
                            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06), radius: 10, x: 0, y: 4)
    }
}
