import SwiftUI
import SwiftData

/// 新增自訂相簿彈窗
public struct CreateAlbumSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var albumName: String = ""
    @State private var errorMessage: String? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)
                
                Text("New Album")
                    .font(.title2.bold())
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Album Name")
                    .font(.headline)
                
                TextField("e.g. Travel, Family, School, Personal...", text: $albumName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
                
                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Create Album") {
                    createAlbum()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
    
    private func createAlbum() {
        let trimmed = albumName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let newAlbum = Album(name: trimmed)
        modelContext.insert(newAlbum)
        try? modelContext.save()
        
        Task { @MainActor in
            ToastService.shared.show("Album \"\(trimmed)\" created", icon: "folder.badge.plus")
        }
        dismiss()
    }
}
