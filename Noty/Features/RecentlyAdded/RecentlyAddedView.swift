import SwiftUI
import SwiftData

/// 最近新增視圖（Recently Added View）
public struct RecentlyAddedView: View {
    @Query(filter: #Predicate<MediaItem> { !$0.isDeleted }, sort: \MediaItem.importedAt, order: .reverse)
    private var recentItems: [MediaItem]
    
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
                        Text("Recently Added")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.accentColor)
                    }
                }
                Spacer()
                Text("\(recentItems.count) memories")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 14)
            
            Divider()
                .padding(.horizontal, 28)
            
            if recentItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No recent memories")
                        .font(.headline)
                    Text("Memories you upload will appear here in chronological order.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 18)], spacing: 18) {
                        ForEach(recentItems) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.secondary.opacity(0.12))
                                        .aspectRatio(1, contentMode: .fit)
                                        .overlay(
                                            Group {
                                                if let thumb = ThumbnailService.shared.loadCachedThumbnail(for: item.storedFileName) {
                                                    Image(nsImage: thumb)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                } else if item.mediaType == .image, let image = NSImage(contentsOf: item.fileURL) {
                                                    Image(nsImage: image)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                } else {
                                                    Image(systemName: item.mediaType == .video ? "video.fill" : "photo.fill")
                                                        .font(.system(size: 34))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        )
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.originalFileName)
                                        .font(.caption.bold())
                                        .lineLimit(1)
                                    Text("Imported \(item.importedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                            }
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
            MediaViewerModal(items: recentItems, currentItemID: $selectedViewerID)
        }
    }
}
