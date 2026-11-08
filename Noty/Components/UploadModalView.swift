import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 媒體上傳與貼文撰寫視窗
public struct UploadModalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<MediaItem> { !$0.isDeleted }) private var existingMediaItems: [MediaItem]
    
    @State private var diaryTitle: String = ""
    @State private var diaryContent: String = ""
    @State private var selectedURLs: [URL] = []
    @State private var showingFilePicker = false
    @State private var selectedMood = "😊"
    @State private var entryDate = Date()
    @State private var isProcessing = false
    @State private var statusMessage: String?
    
    let availableMoods = ["😊", "🌟", "☕️", "🏖️", "🌿", "🍜", "🎉", "🌙"]
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // 頂部標題列
            HStack {
                Text("Create New Memory")
                    .font(.headline)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 日期選擇
                    HStack {
                        Text("Date:")
                            .font(.subheadline.bold())
                        DatePicker("", selection: $entryDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                        Spacer()
                    }
                    
                    // 檔案選取區域
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Media Files")
                            .font(.subheadline.bold())
                        
                        if selectedURLs.isEmpty {
                            Button(action: {
                                showingFilePicker = true
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 32))
                                        .foregroundColor(.accentColor)
                                    
                                    Text("Click to select photos or videos")
                                        .font(.subheadline.bold())
                                    
                                    Text("Supports JPEG, PNG, HEIC, MP4, MOV (Safe local copy)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                                .background(Color.secondary.opacity(0.06))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                        .foregroundColor(Color.secondary.opacity(0.3))
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("\(selectedURLs.count) files selected")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button("Add more...") {
                                        showingFilePicker = true
                                    }
                                    .font(.caption)
                                }
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(selectedURLs, id: \.self) { url in
                                            ZStack(alignment: .topTrailing) {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.secondary.opacity(0.12))
                                                    .frame(width: 80, height: 80)
                                                
                                                VStack(spacing: 4) {
                                                    Image(systemName: isMovie(url: url) ? "film" : "photo")
                                                        .font(.title3)
                                                        .foregroundColor(.primary)
                                                    Text(url.lastPathComponent)
                                                        .font(.system(size: 9))
                                                        .lineLimit(1)
                                                        .truncationMode(.middle)
                                                        .padding(.horizontal, 4)
                                                }
                                                .frame(width: 80, height: 80)
                                                
                                                Button(action: {
                                                    selectedURLs.removeAll(where: { $0 == url })
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.red)
                                                        .background(Circle().fill(Color.white))
                                                }
                                                .buttonStyle(.plain)
                                                .offset(x: 4, y: -4)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // 心情選擇器
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mood")
                            .font(.subheadline.bold())
                        
                        HStack(spacing: 8) {
                            ForEach(availableMoods, id: \.self) { mood in
                                Button(action: {
                                    selectedMood = mood
                                }) {
                                    Text(mood)
                                        .font(.title3)
                                        .padding(6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedMood == mood ? Color.accentColor.opacity(0.2) : Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // 日記標題
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title (Optional)")
                            .font(.subheadline.bold())
                        TextField("Title of your memory...", text: $diaryTitle)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // 日記內文 (Markdown)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Diary Note (Markdown supported)")
                            .font(.subheadline.bold())
                        
                        TextEditor(text: $diaryContent)
                            .font(.body)
                            .frame(height: 90)
                            .padding(6)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    }
                    
                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // 底部儲存按鈕
            HStack {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Saving to local vault...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Save Memory") {
                    saveMemory()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing || (selectedURLs.isEmpty && diaryContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
            .padding(16)
        }
        .frame(width: 500, height: 500)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image, .movie],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                selectedURLs.append(contentsOf: urls)
            }
        }
    }
    
    private func isMovie(url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) ?? false
    }
    
    private func saveMemory() {
        isProcessing = true
        statusMessage = "Copying media to local Application Support..."
        
        var createdMediaItems: [MediaItem] = []
        
        for url in selectedURLs {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let result = try StorageService.shared.importMedia(from: url)
                
                // 去重檢查：若已有相同 SHA-256 的未刪除項目，沿用或記錄
                if let existing = existingMediaItems.first(where: { $0.sha256Hash == result.sha256Hash }) {
                    createdMediaItems.append(existing)
                    continue
                }
                
                let item = MediaItem(
                    originalFileName: result.originalFileName,
                    storedFileName: result.storedFileName,
                    relativePath: result.relativePath,
                    mediaType: result.mediaTypeRaw == "video" ? .video : .image,
                    fileFormat: result.fileFormat,
                    fileSizeBytes: result.fileSizeBytes,
                    sha256Hash: result.sha256Hash,
                    importedAt: Date(),
                    capturedAt: result.capturedAt,
                    pixelWidth: result.pixelWidth,
                    pixelHeight: result.pixelHeight,
                    durationSeconds: result.durationSeconds
                )
                modelContext.insert(item)
                createdMediaItems.append(item)
            } catch {
                print("匯入檔案失敗: \(url.lastPathComponent), 錯誤: \(error.localizedDescription)")
            }
        }
        
        let trimmedContent = diaryContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = diaryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedContent.isEmpty || !createdMediaItems.isEmpty || !trimmedTitle.isEmpty {
            let entry = DiaryEntry(
                title: trimmedTitle.isEmpty ? (trimmedContent.components(separatedBy: .newlines).first ?? "Memory") : trimmedTitle,
                content: trimmedContent,
                createdAt: Date(),
                updatedAt: Date(),
                entryDate: entryDate,
                attachedMediaIDs: createdMediaItems.map(\.id),
                mood: selectedMood
            )
            modelContext.insert(entry)
        }
        
        try? modelContext.save()
        isProcessing = false
        dismiss()
    }
}
