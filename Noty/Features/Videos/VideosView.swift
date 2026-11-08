import SwiftUI
import SwiftData

/// 影片專屬相簿視圖（Videos View）
public struct VideosView: View {
    @Query(filter: #Predicate<MediaItem> { $0.mediaTypeRaw == "video" && !$0.isDeleted }, sort: \MediaItem.capturedAt, order: .reverse)
    private var videoItems: [MediaItem]
    
    @State private var hoveredItemId: UUID?
    @State private var selectedViewerID: UUID?
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Collection")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Text("Videos")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Image(systemName: "film.stack.fill")
                            .foregroundColor(.purple)
                    }
                }
                Spacer()
                Text("\(videoItems.count) videos")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 14)
            
            Divider()
                .padding(.horizontal, 28)
            
            if videoItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "film")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No videos uploaded")
                        .font(.headline)
                    Text("Import your MP4 or MOV memories into Noty.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 18)], spacing: 18) {
                        ForEach(videoItems) { item in
                            ZStack(alignment: .bottomLeading) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.secondary.opacity(0.12))
                                    .aspectRatio(16/9, contentMode: .fit)
                                    .overlay(
                                        Group {
                                            if let thumb = ThumbnailService.shared.loadCachedThumbnail(for: item.storedFileName) {
                                                Image(nsImage: thumb)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } else {
                                                Image(systemName: "play.circle.fill")
                                                    .font(.system(size: 44))
                                                    .foregroundColor(.purple.opacity(0.9))
                                            }
                                        }
                                    )
                                    .overlay(
                                        Image(systemName: "play.fill")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .padding(10)
                                            .background(Circle().fill(Color.black.opacity(0.4)))
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.originalFileName)
                                        .font(.caption.bold())
                                        .lineLimit(1)
                                    HStack {
                                        Text(item.capturedAt.formatted(date: .abbreviated, time: .omitted))
                                        Spacer()
                                        if item.durationSeconds > 0 {
                                            Text(formatDuration(item.durationSeconds))
                                                .font(.system(size: 10, design: .monospaced))
                                        }
                                    }
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.ultraThinMaterial)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color.black.opacity(hoveredItemId == item.id ? 0.15 : 0.04), radius: 6, x: 0, y: 2)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedViewerID = item.id
                            }
                            .onHover { isHovering in
                                hoveredItemId = isHovering ? item.id : nil
                            }
                        }
                    }
                    .padding(28)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedViewerID != nil },
            set: { if !$0 { selectedViewerID = nil } }
        )) {
            MediaViewerModal(items: videoItems, currentItemID: $selectedViewerID)
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
