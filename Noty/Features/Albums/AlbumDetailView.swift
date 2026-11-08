import SwiftUI
import SwiftData

/// 自訂相簿詳細內容檢視
public struct AlbumDetailView: View {
    @Bindable var album: Album
    let onBack: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<MediaItem> { !$0.isDeleted }) private var allMedia: [MediaItem]
    
    @State private var showingRenameAlert = false
    @State private var newAlbumName = ""
    @State private var showingDeleteConfirm = false
    @State private var showingAddMediaSheet = false
    @State private var selectedViewerID: UUID? = nil
    
    public init(album: Album, onBack: @escaping () -> Void) {
        self.album = album
        self.onBack = onBack
        self._newAlbumName = State(initialValue: album.name)
    }
    
    private var albumItems: [MediaItem] {
        allMedia.filter { album.mediaItemIDs.contains($0.id) }
            .sorted { $0.capturedAt > $1.capturedAt }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 頂部導航列
            HStack(spacing: 14) {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("All Albums")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // 相簿標題
                Text(album.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                
                Text("(\(albumItems.count) items)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 操作選單 (重新命名、整本匯出、刪除相簿)
                Menu {
                    Button("Add Memories to Album...") {
                        showingAddMediaSheet = true
                    }
                    
                    Button("Rename Album...") {
                        newAlbumName = album.name
                        showingRenameAlert = true
                    }
                    
                    Button("Export Album to Folder...") {
                        exportAlbum()
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete Album", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16))
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            
            Divider()
            
            // MARK: - 媒體網格或空狀態
            if albumItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("This album is empty")
                        .font(.title3.bold())
                    
                    Text("Add photos and videos to organize your memories here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: { showingAddMediaSheet = true }) {
                        Label("Add Memories", systemImage: "plus")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 14)], spacing: 14) {
                        ForEach(albumItems) { item in
                            ZStack(alignment: .topTrailing) {
                                Button(action: { selectedViewerID = item.id }) {
                                    MediaGridCard(item: item, isSelected: false)
                                }
                                .buttonStyle(.plain)
                                
                                // 從相簿移除按鈕
                                Menu {
                                    Button("Set as Album Cover") {
                                        album.coverMediaID = item.id
                                        try? modelContext.save()
                                        ToastService.shared.show("Cover updated", icon: "photo.badge.checkmark")
                                    }
                                    
                                    Button("Remove from Album", role: .destructive) {
                                        removeItem(item)
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                }
                                .menuStyle(.borderlessButton)
                                .padding(6)
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .sheet(isPresented: $showingAddMediaSheet) {
            AddMediaToAlbumModal(album: album)
        }
        .sheet(isPresented: Binding(
            get: { selectedViewerID != nil },
            set: { if !$0 { selectedViewerID = nil } }
        )) {
            MediaViewerModal(items: albumItems, currentItemID: $selectedViewerID)
        }
        .alert("Rename Album", isPresented: $showingRenameAlert) {
            TextField("Album Name", text: $newAlbumName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    album.name = trimmed
                    album.updatedAt = Date()
                    try? modelContext.save()
                    ToastService.shared.show("Album renamed to \(trimmed)")
                }
            }
        }
        .alert("Delete Album \"\(album.name)\"?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Album", role: .destructive) {
                deleteAlbum()
            }
        } message: {
            Text("Photos and videos will remain safe in your library. Only the album folder is removed.")
        }
    }
    
    private func removeItem(_ item: MediaItem) {
        album.mediaItemIDs.removeAll { $0 == item.id }
        if album.coverMediaID == item.id {
            album.coverMediaID = album.mediaItemIDs.first
        }
        album.updatedAt = Date()
        try? modelContext.save()
        ToastService.shared.show("Removed from \(album.name)")
    }
    
    private func deleteAlbum() {
        modelContext.delete(album)
        try? modelContext.save()
        ToastService.shared.show("Album deleted", icon: "trash")
        onBack()
    }
    
    private func exportAlbum() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export Album Here"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let result = try ExportService.shared.exportAlbum(album: album, allItems: allMedia, to: url)
                ToastService.shared.show("Exported \(result.exportedCount) memories to folder", icon: "square.and.arrow.up")
            } catch {
                ToastService.shared.show("Export failed: \(error.localizedDescription)", isSuccess: false)
            }
        }
    }
}

/// 挑選相簿內現有媒體加入的輔助彈窗
struct AddMediaToAlbumModal: View {
    @Bindable var album: Album
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<MediaItem> { !$0.isDeleted }, sort: \MediaItem.capturedAt, order: .reverse)
    private var allMedia: [MediaItem]
    
    @State private var selectedIDs: Set<UUID> = []
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Add Memories to \(album.name)")
                    .font(.title3.bold())
                Spacer()
                Button("Done") {
                    for id in selectedIDs {
                        if !album.mediaItemIDs.contains(id) {
                            album.mediaItemIDs.append(id)
                        }
                    }
                    if album.coverMediaID == nil, let first = selectedIDs.first {
                        album.coverMediaID = first
                    }
                    album.updatedAt = Date()
                    try? modelContext.save()
                    ToastService.shared.show("Added \(selectedIDs.count) items", icon: "plus.circle.fill")
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedIDs.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            
            Divider()
            
            let candidateItems = allMedia.filter { !album.mediaItemIDs.contains($0.id) }
            if candidateItems.isEmpty {
                VStack(spacing: 10) {
                    Text("All your library media are already in this album.")
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110, maximum: 140), spacing: 10)], spacing: 10) {
                        ForEach(candidateItems) { item in
                            let isPicked = selectedIDs.contains(item.id)
                            Button(action: {
                                if isPicked { selectedIDs.remove(item.id) }
                                else { selectedIDs.insert(item.id) }
                            }) {
                                ZStack(alignment: .topTrailing) {
                                    MediaGridCard(item: item, isSelected: isPicked)
                                    Image(systemName: isPicked ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(isPicked ? .accentColor : .white)
                                        .font(.system(size: 18))
                                        .padding(6)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 580, height: 460)
    }
}
