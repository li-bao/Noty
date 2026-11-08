import SwiftUI
import SwiftData

public enum MediaFilterOption: String, CaseIterable, Identifiable {
    case all = "All"
    case photos = "Photos"
    case videos = "Videos"
    public var id: String { rawValue }
}

/// 附加媒體選擇視窗（從 Noty 本機圖庫挑選媒體以附加到日記）
public struct MediaPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<MediaItem> { !$0.isDeleted }, sort: \MediaItem.capturedAt, order: .reverse)
    private var allMediaItems: [MediaItem]
    
    @Binding var selectedMediaIDs: [UUID]
    @State private var filterMode: MediaFilterOption = .all
    @State private var localSelection: Set<UUID> = []
    
    public init(selectedMediaIDs: Binding<[UUID]>) {
        self._selectedMediaIDs = selectedMediaIDs
    }
    
    private var filteredItems: [MediaItem] {
        allMediaItems.filter { item in
            switch filterMode {
            case .all: return true
            case .photos: return item.mediaType == .image
            case .videos: return item.mediaType == .video
            }
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 頂部導航
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Select Media for Diary")
                        .font(.headline)
                    Text("\(localSelection.count) item(s) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Picker("", selection: $filterMode) {
                    ForEach(MediaFilterOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                
                Spacer()
                
                Button("Done") {
                    selectedMediaIDs = Array(localSelection)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "photo.stack")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No media found in Noty library")
                        .font(.headline)
                    Text("Import photos or videos to Noty first.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 10)], spacing: 10) {
                        ForEach(filteredItems) { item in
                            mediaSelectionCell(for: item)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(minWidth: 540, minHeight: 450)
        .onAppear {
            localSelection = Set(selectedMediaIDs)
        }
    }
    
    private func mediaSelectionCell(for item: MediaItem) -> some View {
        let isSelected = localSelection.contains(item.id)
        
        return ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                if let nsImage = ThumbnailService.shared.loadCachedThumbnail(for: item.storedFileName) ?? (item.mediaType == .image ? NSImage(contentsOf: item.fileURL) : nil) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.15))
                        .aspectRatio(1, contentMode: .fill)
                        .overlay(
                            Image(systemName: item.mediaType == .video ? "film" : "photo")
                                .foregroundColor(.secondary)
                        )
                }
                
                if item.mediaType == .video {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8))
                        Text(formatDuration(item.durationSeconds))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                    .padding(6)
                }
            }
            .frame(height: 120)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )
            
            // 選取勾號圓圈
            Button(action: {
                if isSelected {
                    localSelection.remove(item.id)
                } else {
                    localSelection.insert(item.id)
                }
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .accentColor : .white)
                    .shadow(color: .black.opacity(0.6), radius: 2)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                localSelection.remove(item.id)
            } else {
                localSelection.insert(item.id)
            }
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}
