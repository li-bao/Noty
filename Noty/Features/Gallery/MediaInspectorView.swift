import SwiftUI
import SwiftData
import AppKit

/// 媒體進階詳細資訊與元資料檢視面板（Media Inspector）
public struct MediaInspectorView: View {
    @Bindable public var item: MediaItem
    @Environment(\.modelContext) private var modelContext
    
    @State private var newTagText: String = ""
    @State private var isEditingCaption: Bool = false
    @State private var isEditingDate: Bool = false
    @State private var editedCapturedDate: Date = Date()
    
    public init(item: MediaItem) {
        self.item = item
        self._editedCapturedDate = State(initialValue: item.capturedAt)
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerView
                specsCard
                if item.mediaType == .image && (item.cameraModel != nil || item.iso != nil) {
                    cameraCard
                }
                if item.mediaType == .video {
                    videoCard
                }
                if item.hasGPS, let lat = item.latitude, let lon = item.longitude {
                    gpsCard(lat: lat, lon: lon)
                }
                hashCard
                Divider()
                captionSection
                Divider()
                tagsSection
                Divider()
                systemActionsSection
            }
            .padding(16)
        }
        .frame(width: 290)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        .alert("Manually Correct Date", isPresented: $isEditingDate) {
            DatePicker("", selection: $editedCapturedDate)
            Button("Cancel", role: .cancel) {}
            Button("Update Date") {
                item.capturedAt = editedCapturedDate
                try? modelContext.save()
                ToastService.shared.show("Capture date updated", icon: "calendar.badge.clock")
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Media Intelligence")
                .font(.headline)
            Spacer()
            Button(action: {
                item.isFavorite.toggle()
                try? modelContext.save()
            }) {
                Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(item.isFavorite ? .red : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help(item.isFavorite ? "Remove from Favorites" : "Add to Favorites")
        }
    }
    
    private var specsCard: some View {
        VStack(spacing: 7) {
            infoRow(label: "File Name", value: item.originalFileName)
            infoRow(label: "File Size", value: item.formattedFileSize)
            infoRow(label: "Format", value: item.fileFormat.uppercased())
            if item.pixelWidth > 0 {
                infoRow(label: "Resolution", value: "\(item.pixelWidth) × \(item.pixelHeight) px")
            }
            if item.durationSeconds > 0 {
                infoRow(label: "Duration", value: formatDuration(item.durationSeconds))
            }
            
            HStack {
                Text("Captured Date")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Text(item.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .medium))
                Button(action: { isEditingDate = true }) {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Correct capture date manually")
            }
            
            infoRow(label: "Imported Date", value: item.importedAt.formatted(date: .abbreviated, time: .shortened))
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(10)
    }
    
    private var cameraCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Camera & Optics", systemImage: "camera")
                .font(.subheadline.bold())
            
            VStack(spacing: 6) {
                if let make = item.cameraMake, let model = item.cameraModel {
                    infoRow(label: "Device", value: "\(make) \(model)")
                } else if let model = item.cameraModel {
                    infoRow(label: "Device", value: model)
                }
                if let lens = item.lensModel {
                    infoRow(label: "Lens", value: lens)
                }
                if let f = item.aperture {
                    infoRow(label: "Aperture", value: String(format: "ƒ/%.1f", f))
                }
                if let exp = item.exposureTime {
                    infoRow(label: "Shutter", value: exp)
                }
                if let iso = item.iso {
                    infoRow(label: "ISO", value: "\(iso)")
                }
                if let focal = item.focalLength {
                    infoRow(label: "Focal Length", value: String(format: "%.1f mm", focal))
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.04))
            .cornerRadius(8)
        }
    }
    
    private var videoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Video Tracks & Codec", systemImage: "film")
                .font(.subheadline.bold())
            
            VStack(spacing: 6) {
                if let codec = item.videoCodec {
                    infoRow(label: "Video Codec", value: codec.uppercased())
                }
                if let fps = item.fps, fps > 0 {
                    infoRow(label: "Frame Rate", value: String(format: "%.2f fps", fps))
                }
                if let tracks = item.audioTrackCount {
                    infoRow(label: "Audio Tracks", value: "\(tracks)")
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.04))
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private func gpsCard(lat: Double, lon: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Location (Local Privacy Protected)", systemImage: "location.fill")
                .font(.subheadline.bold())
                .foregroundColor(.blue)
            
            HStack {
                Text(String(format: "%.4f°, %.4f°", lat, lon))
                    .font(.system(size: 12, design: .monospaced))
                Spacer()
                Text("🔒 Never uploaded")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color.blue.opacity(0.06))
            .cornerRadius(6)
        }
    }
    
    private var hashCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Integrity & Hashes", systemImage: "lock.shield")
                .font(.subheadline.bold())
            
            VStack(alignment: .leading, spacing: 4) {
                Text("SHA-256")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                Text(String(item.sha256Hash.prefix(20)) + "...")
                    .font(.caption2.monospaced())
                    .lineLimit(1)
                
                if let phash = item.perceptualHash {
                    Text("pHash (dHash 64-bit)")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                    Text(phash)
                        .font(.caption2.monospaced())
                        .foregroundColor(.purple)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.04))
            .cornerRadius(6)
        }
    }
    
    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Description")
                    .font(.subheadline.bold())
                Spacer()
                if isEditingCaption {
                    Button("Save") {
                        isEditingCaption = false
                        try? modelContext.save()
                    }
                    .font(.caption.bold())
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Edit") {
                        isEditingCaption = true
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
            }
            
            if isEditingCaption {
                TextEditor(text: $item.caption)
                    .font(.body)
                    .frame(height: 60)
                    .padding(4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
            } else {
                Text(item.caption.isEmpty ? "No description provided." : item.caption)
                    .font(.subheadline)
                    .foregroundColor(item.caption.isEmpty ? .secondary : .primary)
            }
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.subheadline.bold())
            
            HStack {
                TextField("Add tag...", text: $newTagText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTag)
                
                Button("Add", action: addTag)
                    .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            
            if !item.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(item.tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text("#\(tag)")
                                    .font(.caption)
                                Button(action: { removeTag(tag) }) {
                                    Image(systemName: "xmark")
                                        .font(.caption2)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12))
                            .cornerRadius(6)
                        }
                    }
                }
            }
        }
    }
    
    private var systemActionsSection: some View {
        HStack {
            Button(action: {
                if item.fileExistsOnDisk {
                    NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
                }
            }) {
                Label("Reveal in Finder", systemImage: "folder")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            Spacer()
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .layoutPriority(1)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
    
    private func addTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !item.tags.contains(trimmed) else { return }
        item.tags.append(trimmed)
        newTagText = ""
        try? modelContext.save()
    }
    
    private func removeTag(_ tag: String) {
        item.tags.removeAll { $0 == tag }
        try? modelContext.save()
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
