import SwiftUI
import SwiftData

/// 單日回憶時間軸區塊（TimelineDaySectionView）
/// 將同一天的日記、照片與影片優雅組合呈現，形成豐富的私人回憶資料庫
public struct TimelineDaySectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    
    let date: Date
    let diaries: [DiaryEntry]
    let mediaItems: [MediaItem]
    let contentMode: TimelineContentMode
    let onEditDiary: (DiaryEntry) -> Void
    let onCreateDiaryWithMedia: (MediaItem) -> Void
    
    @State private var selectedMediaIDForViewer: UUID? = nil
    
    public init(
        date: Date,
        diaries: [DiaryEntry],
        mediaItems: [MediaItem],
        contentMode: TimelineContentMode,
        onEditDiary: @escaping (DiaryEntry) -> Void,
        onCreateDiaryWithMedia: @escaping (MediaItem) -> Void
    ) {
        self.date = date
        self.diaries = diaries
        self.mediaItems = mediaItems
        self.contentMode = contentMode
        self.onEditDiary = onEditDiary
        self.onCreateDiaryWithMedia = onCreateDiaryWithMedia
    }
    
    // 計算該日期已附加至日記的媒體 ID 集合
    private var attachedMediaIDsInDay: Set<UUID> {
        Set(diaries.flatMap { $0.attachedMediaIDs })
    }
    
    // 獨立拍攝但未綁定進當天日記的照片/影片
    private var standaloneMediaItems: [MediaItem] {
        mediaItems.filter { !attachedMediaIDsInDay.contains($0.id) }
    }
    
    private var formattedDateTitle: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_Hant_TW")
        df.dateFormat = "yyyy/MM/dd (E)"
        return df.string(from: date)
    }
    
    private var relativeDayDescription: String? {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        }
        return nil
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 18) {
            // MARK: - 左側垂直時間軸節點與引導線
            VStack(spacing: 0) {
                // 日期節點圓圈
                ZStack {
                    Circle()
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .frame(width: 34, height: 34)
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                    
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 2.5)
                        .frame(width: 34, height: 34)
                    
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.top, 4)
                
                // 垂直時間軸導線
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 4)
            }
            .frame(width: 36)
            
            // MARK: - 右側單日回憶主內容
            VStack(alignment: .leading, spacing: 18) {
                // 日期與數量統計標頭
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(formattedDateTitle)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    if let rel = relativeDayDescription {
                        Text(rel)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.14))
                            .foregroundColor(.accentColor)
                            .cornerRadius(6)
                    }
                    
                    Spacer()
                    
                    // 回憶統計徽章
                    HStack(spacing: 8) {
                        if !diaries.isEmpty {
                            Label("\(diaries.count)", systemImage: "book.pages")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                        
                        let photoCount = mediaItems.filter { $0.mediaType == .image }.count
                        if photoCount > 0 {
                            Label("\(photoCount)", systemImage: "photo")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        
                        let videoCount = mediaItems.filter { $0.mediaType == .video }.count
                        if videoCount > 0 {
                            Label("\(videoCount)", systemImage: "film")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(10)
                }
                .padding(.bottom, 2)
                
                // 1. 當日日記卡片（包含日記與其附件照片/影片）
                if contentMode != .mediaOnly && !diaries.isEmpty {
                    VStack(spacing: 16) {
                        ForEach(diaries) { entry in
                            DiaryPostCardView(entry: entry) {
                                onEditDiary(entry)
                            }
                        }
                    }
                }
                
                // 2. 當日未綁定進日記的獨立照片與影片（或媒體模式下的全部照片影片）
                let displayedMedia = (contentMode == .mediaOnly) ? mediaItems : standaloneMediaItems
                if contentMode != .diariesOnly && !displayedMedia.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        if contentMode == .composite && !diaries.isEmpty {
                            Label("Captured on this day (\(displayedMedia.count))", systemImage: "camera")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)], spacing: 12) {
                            ForEach(displayedMedia) { media in
                                dayMediaCard(for: media)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.secondary.opacity(0.04))
                    .cornerRadius(14)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 28)
        }
        .sheet(isPresented: Binding(
            get: { selectedMediaIDForViewer != nil },
            set: { if !$0 { selectedMediaIDForViewer = nil } }
        )) {
            MediaViewerModal(
                items: mediaItems,
                currentItemID: $selectedMediaIDForViewer
            )
        }
    }
    
    // MARK: - 單日照片/影片小卡片
    private func dayMediaCard(for media: MediaItem) -> some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                if let thumb = ThumbnailService.shared.loadCachedThumbnail(for: media.storedFileName) ?? (media.mediaType == .image ? NSImage(contentsOf: media.fileURL) : nil) {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 110, maxHeight: 110)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 110)
                        .overlay(
                            Image(systemName: media.mediaType == .video ? "film" : "photo")
                                .foregroundColor(.secondary)
                        )
                }
                
                if media.mediaType == .video {
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 7))
                        Text(formatDuration(media.durationSeconds))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.65))
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .padding(6)
                }
            }
            .frame(height: 110)
            .cornerRadius(10)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedMediaIDForViewer = media.id
            }
            
            // 轉為日記按鈕
            Menu {
                Button(action: {
                    onCreateDiaryWithMedia(media)
                }) {
                    Label("Write Diary with this Media", systemImage: "square.and.pencil")
                }
                
                Button(action: {
                    selectedMediaIDForViewer = media.id
                }) {
                    Label("View Fullscreen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 3)
                    .padding(6)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
    
    private func formatDuration(_ sec: Double) -> String {
        let total = Int(sec)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}
