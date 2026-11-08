import SwiftUI
import SwiftData
import AppKit

/// 日記與貼文編寫視窗（Diary Composer Sheet）
/// 具備自動儲存、草稿防遺失、字數即時統計、媒體關聯管理與手動儲存
public struct DiaryComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(filter: #Predicate<MediaItem> { !$0.isDeleted }) private var allMedia: [MediaItem]
    
    var existingEntry: DiaryEntry?
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var mood: String = "😊"
    @State private var entryDate: Date = Date()
    @State private var attachedMediaIDs: [UUID] = []
    @State private var tags: [String] = []
    @State private var newTagText: String = ""
    @State private var isFavorite: Bool = false
    
    @State private var isMediaPickerPresented = false
    @State private var showDiscardAlert = false
    @State private var restoredDraftBanner: String? = nil
    @State private var lastSavedStatusText: String = "Ready"
    @State private var autoSaveTimer: Timer? = nil
    
    private let presetMoods = ["😊", "☕️", "🌟", "🏖️", "💻", "🌧️", "🌿", "🎉", "❤️", "🍕", "📖", "🏃"]
    
    public init(entry: DiaryEntry? = nil) {
        self.existingEntry = entry
    }
    
    // MARK: - 字數與詞數統計
    private var characterCount: Int {
        content.count
    }
    
    private var wordCount: Int {
        let components = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return components.count
    }
    
    private var hasUnsavedModifications: Bool {
        if let entry = existingEntry {
            return title != entry.title ||
                   content != entry.content ||
                   mood != entry.mood ||
                   tags != entry.tags ||
                   attachedMediaIDs != entry.attachedMediaIDs ||
                   isFavorite != entry.isFavorite
        } else {
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                   !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                   !attachedMediaIDs.isEmpty ||
                   !tags.isEmpty
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 頂部控制列
            HStack {
                Button("Cancel") {
                    handleCancel()
                }
                .buttonStyle(.notySecondary(height: 30))
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(existingEntry == nil ? "New Memory & Diary" : "Edit Diary")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green.opacity(0.8))
                            .frame(width: 5, height: 5)
                        Text(lastSavedStatusText)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: saveEntry) {
                    Label(existingEntry == nil ? "Publish" : "Save", systemImage: "checkmark")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.notyPrimary(height: 30))
                .keyboardShortcut("s", modifiers: .command)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty && content.trimmingCharacters(in: .whitespaces).isEmpty && attachedMediaIDs.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // MARK: - 未存草稿恢復提醒橫幅
            if let banner = restoredDraftBanner {
                HStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.accentColor)
                    Text(banner)
                        .font(.system(size: 12))
                    
                    Spacer()
                    
                    Button("Discard Draft") {
                        DiaryDraftService.shared.clearDraft(for: existingEntry?.id)
                        resetToOriginal()
                        restoredDraftBanner = nil
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    
                    Button("Keep") {
                        restoredDraftBanner = nil
                    }
                    .font(.caption.bold())
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.08))
                Divider()
            }
            
            // MARK: - 編輯主體
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 1. 心情與日期時間選擇
                    HStack(alignment: .center, spacing: 16) {
                        Menu {
                            ForEach(presetMoods, id: \.self) { m in
                                Button(m) {
                                    mood = m
                                    triggerAutoSave()
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(mood)
                                    .font(.system(size: 22))
                                    .fixedSize()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .liquidCapsule(isInteractive: true)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        
                        DatePicker(
                            "",
                            selection: $entryDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .onChange(of: entryDate) { _, _ in
                            triggerAutoSave()
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            isFavorite.toggle()
                            triggerAutoSave()
                        }) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(isFavorite ? .red : .secondary)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .help(isFavorite ? "Favorited" : "Mark as Favorite")
                    }
                    
                    // 2. 模板選單與快速排版工具列
                    HStack(spacing: 8) {
                        Menu {
                            ForEach(DiaryTemplate.builtInTemplates) { tmpl in
                                Button {
                                    applyTemplate(tmpl)
                                } label: {
                                    Label(tmpl.name, systemImage: tmpl.icon)
                                }
                            }
                        } label: {
                            Label("Templates", systemImage: "doc.plaintext")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .menuStyle(.borderlessButton)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(6)
                        
                        Divider().frame(height: 14)
                        
                        // 快速 Markdown 格式化按鈕
                        formatButton(title: "B", help: "Bold (**text**)") { insertFormatting(prefix: "**", suffix: "**", placeholder: "bold text") }
                        formatButton(title: "I", help: "Italic (*text*)") { insertFormatting(prefix: "*", suffix: "*", placeholder: "italic text") }
                        formatButton(title: "H3", help: "Heading (### )") { insertFormatting(prefix: "\n### ", suffix: "\n", placeholder: "Heading") }
                        formatButton(title: "• List", help: "Bullet List (- )") { insertFormatting(prefix: "\n- ", suffix: "", placeholder: "List item") }
                        formatButton(title: "1. List", help: "Numbered List (1. )") { insertFormatting(prefix: "\n1. ", suffix: "", placeholder: "Item") }
                        formatButton(title: "“ Quote", help: "Blockquote (> )") { insertFormatting(prefix: "\n> ", suffix: "\n", placeholder: "Quote") }
                        formatButton(title: "— Rule", help: "Divider (---)") { insertFormatting(prefix: "\n\n---\n\n", suffix: "", placeholder: "") }
                        
                        Spacer()
                    }
                    
                    // 3. 標題輸入框
                    TextField("Title (e.g. A peaceful weekend walk)", text: $title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .onChange(of: title) { _, _ in
                            triggerAutoSave()
                        }
                    
                    // 3. 正文編輯器
                    ZStack(alignment: .topLeading) {
                        if content.isEmpty {
                            Text("What's on your mind today? Write down your thoughts, personal memories, or photo stories...")
                                .foregroundColor(.secondary.opacity(0.6))
                                .font(.system(size: 14))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                        
                        TextEditor(text: $content)
                            .font(.system(size: 14))
                            .lineSpacing(5)
                            .padding(12)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(10)
                            .frame(minHeight: 180)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                            .onChange(of: content) { _, _ in
                                triggerAutoSave()
                            }
                    }
                    
                    // 4. 附加媒體區塊（與 Gallery 關聯，移除時絕不刪除 Gallery 原媒體）
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Attached Photos & Videos (\(attachedMediaIDs.count))", systemImage: "photo.on.rectangle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                isMediaPickerPresented = true
                            }) {
                                Label("Choose from Gallery", systemImage: "photo.stack")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)
                            
                            Button(action: importNewMediaDirectly) {
                                Label("Upload New", systemImage: "plus")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        if attachedMediaIDs.isEmpty {
                            HStack {
                                Spacer()
                                Text("No media attached yet. You can attach photos or videos from your library.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 14)
                                Spacer()
                            }
                            .background(Color.secondary.opacity(0.04))
                            .cornerRadius(8)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(attachedMediaIDs, id: \.self) { mediaID in
                                        attachedThumbnailView(for: mediaID)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    // 5. 標籤管理
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Tags", systemImage: "tag")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Text("#\(tag)")
                                        .font(.system(size: 12, weight: .medium))
                                    
                                    Button(action: {
                                        tags.removeAll { $0 == tag }
                                        triggerAutoSave()
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundColor(.accentColor)
                                .cornerRadius(12)
                            }
                            
                            HStack(spacing: 4) {
                                TextField("Add tag...", text: $newTagText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12))
                                    .frame(width: 80)
                                    .onSubmit {
                                        addNewTag()
                                    }
                                
                                Button(action: addNewTag) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                                .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(24)
            }
            
            Divider()
            
            // MARK: - 底部資訊列（字數與詞數統計）
            HStack {
                HStack(spacing: 12) {
                    Text("\(characterCount) characters")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(wordCount) words")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("Shortcuts: ⌘S to Save · Esc to Close")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
        }
        .frame(minWidth: 620, idealWidth: 680, minHeight: 560, idealHeight: 620)
        .onAppear {
            loadInitialContent()
        }
        .onDisappear {
            autoSaveTimer?.invalidate()
        }
        .sheet(isPresented: $isMediaPickerPresented) {
            MediaPickerSheet(selectedMediaIDs: $attachedMediaIDs)
        }
        .confirmationDialog(
            "Discard unsaved changes?",
            isPresented: $showDiscardAlert,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) {
                DiaryDraftService.shared.clearDraft(for: existingEntry?.id)
                dismiss()
            }
            Button("Save as Draft & Close") {
                saveDraftImmediately()
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("You have unsaved text or attachments. Do you want to keep a draft or discard your edits?")
        }
    }
    
    // MARK: - 媒體縮圖呈現
    private func attachedThumbnailView(for id: UUID) -> some View {
        let item = allMedia.first { $0.id == id }
        
        return ZStack(alignment: .topTrailing) {
            if let item = item,
               let nsImg = ThumbnailService.shared.loadCachedThumbnail(for: item.storedFileName) ?? (item.mediaType == .image ? NSImage(contentsOf: item.fileURL) : nil) {
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
            
            // 移除附件按鈕（只解綁，絕不刪除 Gallery 原檔案）
            Button(action: {
                attachedMediaIDs.removeAll { $0 == id }
                triggerAutoSave()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.7)))
            }
            .buttonStyle(.plain)
            .padding(4)
            .help("Detach from diary (Original file remains in Gallery)")
        }
    }
    
    // MARK: - 標籤新增
    private func addNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard !trimmed.isEmpty else { return }
        if !tags.contains(trimmed) {
            tags.append(trimmed)
            triggerAutoSave()
        }
        newTagText = ""
    }
    
    // MARK: - 草稿與初始化
    private func loadInitialContent() {
        if let entry = existingEntry {
            title = entry.title
            content = entry.content
            mood = entry.mood
            entryDate = entry.entryDate
            attachedMediaIDs = entry.attachedMediaIDs
            tags = entry.tags
            isFavorite = entry.isFavorite
            
            // 檢查是否有未儲存之草稿
            if let draft = DiaryDraftService.shared.loadDraft(for: entry.id) {
                title = draft.title
                content = draft.content
                mood = draft.mood
                entryDate = draft.entryDate
                attachedMediaIDs = draft.attachedMediaIDs
                tags = draft.tags
                isFavorite = draft.isFavorite
                restoredDraftBanner = "Restored unsaved draft from \(draft.lastSavedAt.formatted(date: .omitted, time: .shortened))."
                lastSavedStatusText = "Draft Restored"
            }
        } else {
            // 新日記：檢查是否有通用草稿
            if let draft = DiaryDraftService.shared.loadDraft(for: nil) {
                title = draft.title
                content = draft.content
                mood = draft.mood
                entryDate = draft.entryDate
                attachedMediaIDs = draft.attachedMediaIDs
                tags = draft.tags
                isFavorite = draft.isFavorite
                restoredDraftBanner = "Found unsaved new draft from \(draft.lastSavedAt.formatted(date: .omitted, time: .shortened))."
                lastSavedStatusText = "Draft Restored"
            } else {
                // 檢查是否有 AI 或外部預載之標題或草稿內容
                if let preTitle = appState.preloadedDiaryTitle, !preTitle.isEmpty {
                    title = preTitle
                }
                if let preContent = appState.preloadedDiaryContent, !preContent.isEmpty {
                    content = preContent
                }
                appState.preloadedDiaryTitle = nil
                appState.preloadedDiaryContent = nil
            }
        }
    }
    
    // MARK: - 格式化與範本輔助
    @ViewBuilder
    private func formatButton(title: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.06))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .help(help)
    }
    
    private func insertFormatting(prefix: String, suffix: String, placeholder: String) {
        if content.isEmpty {
            content = "\(prefix)\(placeholder)\(suffix)"
        } else {
            content += "\(prefix)\(placeholder)\(suffix)"
        }
        triggerAutoSave()
    }
    
    private func applyTemplate(_ tmpl: DiaryTemplate) {
        if title.isEmpty {
            title = tmpl.defaultTitle
        }
        mood = tmpl.defaultMood
        if content.isEmpty {
            content = tmpl.content
        } else {
            content += "\n\n" + tmpl.content
        }
        triggerAutoSave()
        ToastService.shared.show("Applied \"\(tmpl.name)\" template", icon: tmpl.icon)
    }
    
    private func resetToOriginal() {
        if let entry = existingEntry {
            title = entry.title
            content = entry.content
            mood = entry.mood
            entryDate = entry.entryDate
            attachedMediaIDs = entry.attachedMediaIDs
            tags = entry.tags
            isFavorite = entry.isFavorite
        } else {
            title = ""
            content = ""
            mood = "😊"
            entryDate = Date()
            attachedMediaIDs = []
            tags = []
            isFavorite = false
        }
        lastSavedStatusText = "Draft Cleared"
    }
    
    // MARK: - 自動儲存機制
    private func triggerAutoSave() {
        lastSavedStatusText = "Editing..."
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            Task { @MainActor in
                saveDraftImmediately()
            }
        }
    }
    
    private func saveDraftImmediately() {
        let draft = DiaryDraft(
            entryID: existingEntry?.id,
            title: title,
            content: content,
            mood: mood,
            entryDate: entryDate,
            attachedMediaIDs: attachedMediaIDs,
            tags: tags,
            isFavorite: isFavorite,
            lastSavedAt: Date()
        )
        DiaryDraftService.shared.saveDraft(draft)
        let timeStr = Date().formatted(date: .omitted, time: .shortened)
        lastSavedStatusText = "Auto-saved at \(timeStr)"
    }
    
    // MARK: - 取消防呆處理
    private func handleCancel() {
        if hasUnsavedModifications {
            showDiscardAlert = true
        } else {
            dismiss()
        }
    }
    
    // MARK: - 正式儲存日記
    private func saveEntry() {
        autoSaveTimer?.invalidate()
        
        if let entry = existingEntry {
            entry.title = title
            entry.content = content
            entry.mood = mood
            entry.entryDate = entryDate
            entry.attachedMediaIDs = attachedMediaIDs
            entry.tags = tags
            entry.isFavorite = isFavorite
            entry.updatedAt = Date()
            DiaryVersionService.shared.saveSnapshot(for: entry)
        } else {
            let newEntry = DiaryEntry(
                title: title,
                content: content,
                createdAt: Date(),
                updatedAt: Date(),
                entryDate: entryDate,
                attachedMediaIDs: attachedMediaIDs,
                tags: tags,
                isFavorite: isFavorite,
                mood: mood
            )
            modelContext.insert(newEntry)
            DiaryVersionService.shared.saveSnapshot(for: newEntry)
        }
        
        try? modelContext.save()
        // 清除該篇草稿
        DiaryDraftService.shared.clearDraft(for: existingEntry?.id)
        dismiss()
    }
    
    // MARK: - 直接上傳新媒體並附加
    private func importNewMediaDirectly() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.message = "Select photos or videos to import into Noty and attach to this diary"
        panel.prompt = "Import & Attach"
        
        if panel.runModal() == .OK {
            let urls = panel.urls
            guard !urls.isEmpty else { return }
            
            for fileURL in urls {
                guard MediaImportService.isSupportedFile(url: fileURL) else { continue }
                if let result = try? StorageService.shared.importMedia(from: fileURL) {
                    let mediaType = MediaType(rawValue: result.mediaTypeRaw) ?? .image
                    let newItem = MediaItem(
                        originalFileName: result.originalFileName,
                        storedFileName: result.storedFileName,
                        relativePath: result.relativePath,
                        mediaType: mediaType,
                        fileFormat: result.fileFormat,
                        fileSizeBytes: result.fileSizeBytes,
                        sha256Hash: result.sha256Hash,
                        capturedAt: result.capturedAt,
                        pixelWidth: result.pixelWidth,
                        pixelHeight: result.pixelHeight,
                        durationSeconds: result.durationSeconds
                    )
                    modelContext.insert(newItem)
                    try? modelContext.save()
                    if !attachedMediaIDs.contains(newItem.id) {
                        attachedMediaIDs.append(newItem.id)
                    }
                    
                    Task.detached(priority: .background) {
                        _ = try? await ThumbnailService.shared.generateThumbnail(
                            for: result.absoluteURL,
                            storedFileName: result.storedFileName,
                            isVideo: mediaType == .video
                        )
                    }
                }
            }
            triggerAutoSave()
        }
    }
}
