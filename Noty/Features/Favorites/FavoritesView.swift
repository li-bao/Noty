import SwiftUI
import SwiftData

/// 收藏珍藏視圖（Favorites View）
public struct FavoritesView: View {
    @Query(filter: #Predicate<MediaItem> { $0.isFavorite && !$0.isDeleted }, sort: \MediaItem.capturedAt, order: .reverse)
    private var favoriteItems: [MediaItem]
    
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
                        Text("Favorites")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                    }
                }
                Spacer()
                Text("\(favoriteItems.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 14)
            
            Divider()
                .padding(.horizontal, 28)
            
            if favoriteItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "heart")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No favorites yet")
                        .font(.headline)
                    Text("Click the heart icon on any memory in your gallery to save it here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 18)], spacing: 18) {
                        ForEach(favoriteItems) { item in
                            ZStack(alignment: .bottomLeading) {
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
                                                    .font(.system(size: 36))
                                                    .foregroundColor(.red.opacity(0.8))
                                            }
                                        }
                                    )
                                
                                Text(item.originalFileName)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .padding(8)
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
            MediaViewerModal(items: favoriteItems, currentItemID: $selectedViewerID)
        }
    }
}
