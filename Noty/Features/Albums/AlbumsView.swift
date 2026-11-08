import SwiftUI
import SwiftData

/// 自訂相簿列表畫面（Albums View）
public struct AlbumsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    
    @Query(sort: \Album.createdAt, order: .reverse) private var albums: [Album]
    @Query(filter: #Predicate<MediaItem> { !$0.isDeleted }) private var allMedia: [MediaItem]
    
    @State private var selectedAlbum: Album? = nil
    @State private var showingCreateSheet = false
    
    public init() {}
    
    public var body: some View {
        Group {
            if let album = selectedAlbum {
                AlbumDetailView(album: album) {
                    selectedAlbum = nil
                }
            } else {
                mainAlbumsContent
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateAlbumSheet()
        }
    }
    
    private var mainAlbumsContent: some View {
        VStack(spacing: 0) {
            // MARK: - 頂部標題與新建相簿按鈕
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Collections")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Text("Albums")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                }
                
                Spacer()
                
                Button(action: { showingCreateSheet = true }) {
                    Label("New Album", systemImage: "plus")
                }
                .buttonStyle(.notyPrimary(height: 30))
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 16)
            
            Divider()
                .padding(.horizontal, 28)
            
            // MARK: - 相簿卡片網格或空狀態
            if albums.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 52))
                        .foregroundColor(.secondary.opacity(0.4))
                    
                    Text("No Custom Albums")
                        .font(.title2.bold())
                    
                    Text("Create albums like \"Travel\", \"Family\", or \"Projects\" to organize your memories.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: { showingCreateSheet = true }) {
                        Label("Create First Album", systemImage: "plus")
                    }
                    .buttonStyle(.notyPrimary(height: 34))
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 20)], spacing: 20) {
                        ForEach(albums) { album in
                            albumCard(album: album)
                        }
                    }
                    .padding(28)
                }
            }
        }
    }
    
    @ViewBuilder
    private func albumCard(album: Album) -> some View {
        Button(action: { selectedAlbum = album }) {
            VStack(alignment: .leading, spacing: 10) {
                // 封面圖
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.1))
                        .aspectRatio(1.0, contentMode: .fit)
                    
                    if let coverID = album.coverMediaID,
                       let coverItem = allMedia.first(where: { $0.id == coverID }) {
                        AsyncThumbnailView(storedFileName: coverItem.storedFileName, isVideo: coverItem.mediaType == .video)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else if let firstID = album.mediaItemIDs.first,
                              let firstItem = allMedia.first(where: { $0.id == firstID }) {
                        AsyncThumbnailView(storedFileName: firstItem.storedFileName, isVideo: firstItem.mediaType == .video)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("Empty Album")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("\(album.mediaItemIDs.count) items")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open Album") {
                selectedAlbum = album
            }
            Divider()
            Button("Delete Album", role: .destructive) {
                modelContext.delete(album)
                try? modelContext.save()
                ToastService.shared.show("Album \"\(album.name)\" deleted", icon: "trash")
            }
        }
    }
}
