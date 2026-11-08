import SwiftUI
import SwiftData
import AppKit

/// 對話訊息實體
public struct AIMessage: Identifiable {
    public let id: UUID
    public var isUser: Bool
    public var content: String
    public var attachedImage: NSImage?
    public var attachedImageBase64: String?
    public var timestamp: Date
    
    public init(
        id: UUID = UUID(),
        isUser: Bool,
        content: String,
        attachedImage: NSImage? = nil,
        attachedImageBase64: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.isUser = isUser
        self.content = content
        self.attachedImage = attachedImage
        self.attachedImageBase64 = attachedImageBase64
        self.timestamp = timestamp
    }
}

/// 本機 Ollama AI 側拉對話抽屜面板（AI Assistant Drawer）
/// 寬度約 360 pt，以浮層疊加在中央內容右側，杜絕任何雲端通訊
public struct AIAssistantPanelView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @ObservedObject private var ollamaService = OllamaService.shared
    
    @Query(filter: #Predicate<DiaryEntry> { !$0.isDeleted }) private var diaries: [DiaryEntry]
    @Query(filter: #Predicate<MediaItem> { !$0.isDeleted }) private var mediaItems: [MediaItem]
    
    @State private var inputPrompt: String = ""
    @State private var pendingImage: NSImage? = nil
    @State private var pendingImageBase64: String? = nil
    @State private var showingImagePicker: Bool = false
    
    @State private var messages: [AIMessage] = [
        AIMessage(
            isUser: false,
            content: "你好！我是運行於本機 Mac 的 Noty 私密 AI 助理。\n\n所有推論皆經由 127.0.0.1 處理，絕對不外傳任何資料。\n我可以根據你的本機資料庫回答問題，或為你分析特定回憶。"
        )
    ]
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 1. 抽屜頂部標題與連線狀態列
            headerSection
            
            Divider()
            
            // MARK: - 2. 離線指引橫幅（未連線時顯示）
            if !ollamaService.isOnline {
                offlineTroubleshootingBanner
            }
            
            // MARK: - 3. 智慧回憶查詢推薦標籤
            suggestionChipsSection
            
            Divider()
            
            // MARK: - 4. 對話訊息流串
            conversationScrollView
            
            Divider()
            
            // MARK: - 5. 待傳送多模態圖片預覽條
            if let img = pendingImage {
                pendingImageBar(image: img)
                Divider()
            }
            
            // MARK: - 6. 底部輸入與多模態操作列
            bottomInputSection
        }
        .frame(width: 360)
        .background(
            Color(nsColor: .windowBackgroundColor)
                .opacity(0.96)
                .background(.ultraThinMaterial)
        )
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color.primary.opacity(0.1)),
            alignment: .leading
        )
        .shadow(color: Color.black.opacity(0.16), radius: 18, x: -6, y: 0)
        .task {
            await ollamaService.checkConnection()
        }
    }
    
    // MARK: - 頂部標題與狀態組件
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Noty Local AI")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        
                        statusBadgeView
                    }
                }
                
                Spacer()
                
                // 清空對話按鈕
                Button(action: clearChat) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear Chat History")
                
                // 關閉抽屜按鈕
                Button(action: closeDrawer) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close AI Drawer")
            }
            
            // 模型選擇下拉選單
            if ollamaService.isOnline && !ollamaService.availableModels.isEmpty {
                HStack(spacing: 6) {
                    Text("Model:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Menu {
                        ForEach(ollamaService.availableModels, id: \.self) { model in
                            Button(action: {
                                ollamaService.selectedModel = model
                            }) {
                                HStack {
                                    Text(model)
                                    if model == ollamaService.selectedModel {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(ollamaService.selectedModel)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .lineLimit(1)
                            
                            if ollamaService.isCurrentModelVisionCapable {
                                Text("Vision")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.blue.opacity(0.18))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                            
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(6)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - 連線狀態 Badge
    private var statusBadgeView: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusIndicatorColor)
                .frame(width: 6, height: 6)
            
            Text(ollamaService.connectionState.rawValue)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
            
            if ollamaService.connectionState == .loadingModels {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 8, height: 8)
            } else {
                Button(action: {
                    Task { await ollamaService.checkConnection() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Recheck 127.0.0.1 connection")
            }
        }
    }
    
    private var statusIndicatorColor: Color {
        switch ollamaService.connectionState {
        case .disconnected: return .red
        case .loadingModels: return .orange
        case .connected: return .yellow
        case .modelReady: return .green
        case .generating: return .blue
        }
    }
    
    // MARK: - 離線提示引導
    private var offlineTroubleshootingBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                Text("Ollama is Offline (127.0.0.1:11434)")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
            }
            
            Text("To use private AI on your Mac mini:\n1. Open Terminal and run: `ollama serve`\n2. Download model: `ollama run llama3.2`\n3. For photos: `ollama run llava`")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .lineSpacing(2)
        }
        .padding(10)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(8)
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }
    
    // MARK: - 建議查詢標籤 (Phase 9.5 記憶助理捷徑)
    private var suggestionChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                suggestionChip("📅 Summarize My Month")
                suggestionChip("🗓️ Summarize My Week")
                suggestionChip("🔍 Find Related Memories")
                suggestionChip("🏷️ Suggest Tags")
                suggestionChip("✍️ Create Diary Draft")
                suggestionChip("📊 Memory Stats")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }
    
    private func suggestionChip(_ text: String) -> some View {
        Button(action: {
            inputPrompt = text
            sendMessage()
        }) {
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.08))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 對話紀錄滾動視圖
    private var conversationScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(messages) { msg in
                        chatMessageRow(for: msg)
                            .id(msg.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: messages.count) { _, _ in
                if let lastID = messages.last?.id {
                    withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                }
            }
            .onChange(of: messages.last?.content) { _, _ in
                if let lastID = messages.last?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }
    
    private func chatMessageRow(for msg: AIMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if msg.isUser {
                Spacer(minLength: 24)
                VStack(alignment: .trailing, spacing: 4) {
                    if let img = msg.attachedImage {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 140, height: 100)
                            .cornerRadius(10)
                            .clipped()
                    }
                    
                    Text(msg.content)
                        .font(.system(size: 13))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.accentColor)
                        )
                        .foregroundColor(.white)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                        Text("Local Grounded AI")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // 將 AI 回覆內容快速轉為新日記草稿
                        if !msg.content.isEmpty {
                            Button(action: {
                                appState.openDiaryComposer(initialContent: msg.content)
                            }) {
                                Label("Use as Diary", systemImage: "square.and.pencil")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("Load this AI text into Diary Composer as editable draft")
                        }
                    }
                    
                    Text(msg.content.isEmpty ? "Thinking..." : msg.content)
                        .font(.system(size: 13))
                        .lineSpacing(3)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .foregroundColor(.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                }
                Spacer(minLength: 24)
            }
        }
    }
    
    // MARK: - 待傳送多模態圖片條
    private func pendingImageBar(image: NSImage) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .cornerRadius(6)
                .clipped()
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Image attached for analysis")
                    .font(.system(size: 11, weight: .medium))
                
                if !ollamaService.isCurrentModelVisionCapable {
                    Text("⚠️ Selected model does not support Vision. Switch to llava.")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                } else {
                    Text("Ready for \(ollamaService.selectedModel)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                pendingImage = nil
                pendingImageBase64 = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.06))
    }
    
    // MARK: - 底部輸入與多模態按鈕列
    private var bottomInputSection: some View {
        HStack(spacing: 8) {
            // 附加照片/影片分析按鈕
            Button(action: attachImageFromMac) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Attach an image for Vision analysis")
            
            TextField("Ask local AI about your memories...", text: $inputPrompt)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                .onSubmit {
                    sendMessage()
                }
                .disabled(ollamaService.connectionState == .generating)
            
            if ollamaService.connectionState == .generating {
                Button(action: {
                    ollamaService.stopGeneration()
                }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Stop Generation")
            } else {
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(canSendMessage ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!canSendMessage)
            }
        }
        .padding(12)
    }
    
    private var canSendMessage: Bool {
        !inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pendingImage != nil
    }
    
    // MARK: - 操作邏輯
    private func closeDrawer() {
        if !reduceMotion {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                appState.isAIDrawerOpen = false
            }
        } else {
            appState.isAIDrawerOpen = false
        }
    }
    
    private func clearChat() {
        messages = [
            AIMessage(
                isUser: false,
                content: "對話紀錄已清除。歡迎隨時詢問您在本機的私密回憶或日記！"
            )
        ]
    }
    
    private func attachImageFromMac() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.message = "Select an image for Ollama Vision analysis"
        panel.prompt = "Attach"
        
        if panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) {
            self.pendingImage = image
            self.pendingImageBase64 = image.jpegBase64String()
        }
    }
    
    private func sendMessage() {
        let text = inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let promptToSend = text.isEmpty ? (pendingImage != nil ? "Please analyze and describe this image." : "") : text
        guard !promptToSend.isEmpty else { return }
        
        let sentImage = pendingImage
        let sentImageBase64 = pendingImageBase64
        
        messages.append(AIMessage(
            isUser: true,
            content: promptToSend,
            attachedImage: sentImage,
            attachedImageBase64: sentImageBase64
        ))
        
        inputPrompt = ""
        pendingImage = nil
        pendingImageBase64 = nil
        
        if !ollamaService.isOnline {
            messages.append(AIMessage(
                isUser: false,
                content: "⚠️ Ollama 本機服務目前未啟動。\n\n請在終端機中執行：\n`ollama serve`\n\nNoty 保證所有資料 100% 留存在您的 Mac 本機上，絕無外部連線。"
            ))
            return
        }
        
        // 檢查 Vision 支援
        if sentImageBase64 != nil && !ollamaService.isCurrentModelVisionCapable {
            messages.append(AIMessage(
                isUser: false,
                content: "⚠️ 當前選取的模型「\(ollamaService.selectedModel)」不支援 Vision 影像分析。\n\n請在上方模型選單切換至支援多模態的模型（如 llava 或 llama3.2-vision），再進行圖片分析。"
            ))
            return
        }
        
        // 構建精確接地氣之本機私密回憶上下文 (Local Grounded RAG)
        let groundedSystemContext = ollamaService.buildGroundedMemoryContext(
            query: promptToSend,
            diaries: diaries,
            mediaItems: mediaItems
        )
        
        var payloadList: [OllamaService.ChatMessagePayload] = [
            OllamaService.ChatMessagePayload(role: "system", content: groundedSystemContext)
        ]
        
        // 保留最近幾輪對話
        for msg in messages.suffix(6) {
            let images = (msg.attachedImageBase64 != nil) ? [msg.attachedImageBase64!] : nil
            payloadList.append(OllamaService.ChatMessagePayload(
                role: msg.isUser ? "user" : "assistant",
                content: msg.content,
                images: images
            ))
        }
        
        let responseMessageIndex = messages.count
        messages.append(AIMessage(isUser: false, content: ""))
        
        ollamaService.streamChat(
            messages: payloadList,
            onToken: { token in
                guard responseMessageIndex < messages.count else { return }
                messages[responseMessageIndex].content += token
            },
            onComplete: {},
            onError: { err in
                guard responseMessageIndex < messages.count else { return }
                if messages[responseMessageIndex].content.isEmpty {
                    messages[responseMessageIndex].content = "⚠️ \(err)"
                }
            }
        )
    }
}

// MARK: - NSImage 轉 Base64 輔助擴充
extension NSImage {
    public func jpegBase64String(compressionFactor: Double = 0.8) -> String? {
        guard let tiffData = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionFactor]) else {
            return nil
        }
        return jpegData.base64EncodedString()
    }
}
