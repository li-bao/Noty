import SwiftUI
import SwiftData

/// 將選取的媒體項目加入自訂相簿彈窗
public struct AddToAlbumSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    
    @Query(sort: \Album.createdAt, order: .reverse) private var albums: [Album]
    
    @State private var newAlbumName: String = ""
    @State private var isCreatingNew = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 18) {
            HStack {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 22))
                    .foregroundColor(.accentColor)
                
                Text("Add to Album")
                    .font(.title3.bold())
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text("Select an album for \(appState.itemsToAddToAlbum.count) items:")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if isCreatingNew {
                HStack(spacing: 8) {
                    TextField("New Album Name", text: $newAlbumName)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Create & Add") {
                        createAndAdd()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button("Cancel") {
                        isCreatingNew = false
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button(action: { isCreatingNew = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                        Text("Create New Album...")
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.accentColor.opacity(0.08))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            if albums.isEmpty && !isCreatingNew {
                VStack(spacing: 8) {
                    Text("No custom albums yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(albums) { album in
                            Button(action: { addItems(to: album) }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.accentColor)
                                        .font(.system(size: 20))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(album.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("\(album.mediaItemIDs.count) items")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(10)
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 180)
            }
            
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
        }
        .padding(22)
        .frame(width: 420)
    }
    
    private func addItems(to album: Album) {
        let newIDs = appState.itemsToAddToAlbum.map { $0.id }
        for id in newIDs {
            if !album.mediaItemIDs.contains(id) {
                album.mediaItemIDs.append(id)
            }
        }
        if album.coverMediaID == nil, let first = newIDs.first {
            album.coverMediaID = first
        }
        album.updatedAt = Date()
        try? modelContext.save()
        
        ToastService.shared.show("Added \(newIDs.count) items to \(album.name)", icon: "checkmark.circle.fill")
        dismiss()
    }
    
    private func createAndAdd() {
        let trimmed = newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newIDs = appState.itemsToAddToAlbum.map { $0.id }
        let album = Album(name: trimmed, coverMediaID: newIDs.first, mediaItemIDs: newIDs)
        modelContext.insert(album)
        try? modelContext.save()
        
        ToastService.shared.show("Created \(trimmed) & added \(newIDs.count) items", icon: "folder.badge.plus")
        dismiss()
    }
}
