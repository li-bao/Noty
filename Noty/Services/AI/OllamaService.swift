import Foundation
import SwiftData
import AppKit

/// 本機 Ollama 連線狀態枚舉
public enum OllamaConnectionState: String, CaseIterable {
    case disconnected = "Ollama Disconnected"
    case loadingModels = "Loading Models"
    case connected = "Ollama Connected"
    case modelReady = "Model Ready"
    case generating = "Generating"
}

/// 本機 Ollama AI 服務實體（OllamaService）
/// 遵循 100% 極致隱私與離線規範：嚴格只連線至本機迴路（127.0.0.1 / localhost / ::1），杜絕外部網絡
@MainActor
public final class OllamaService: ObservableObject {
    public static let shared = OllamaService()
    
    /// 預設端點
    public static let defaultEndpointString = "http://127.0.0.1:11434"
    
    /// 當前設定之端點（受到嚴格本機白名單檢查保護）
    @Published public private(set) var endpoint: String = defaultEndpointString
    
    @Published public var connectionState: OllamaConnectionState = .disconnected
    @Published public var isOnline: Bool = false
    @Published public var availableModels: [String] = []
    @Published public var selectedModel: String = "llama3.2"
    @Published public var lastErrorMessage: String? = nil
    
    private var activeTask: Task<Void, Never>? = nil
    
    private init() {
        // 從 UserDefaults 載入端點並嚴格校驗
        if let saved = UserDefaults.standard.string(forKey: "ollama_endpoint"),
           let url = URL(string: saved), Self.isLoopback(url: url) {
            self.endpoint = saved
        }
    }
    
    // MARK: - 1. 本機迴路白名單校驗（安全性防護）
    
    /// 嚴格驗證 URL 是否為本機迴路位址（localhost, 127.0.0.1, ::1）
    /// 拒絕任何外部網域、公共 IP 或私有 LAN IP
    public static func isLoopback(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let cleanHost = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let allowedLoopbackHosts: Set<String> = ["127.0.0.1", "localhost", "::1"]
        return allowedLoopbackHosts.contains(cleanHost)
    }
    
    /// 更新自訂端點（若非本機位址則拋出拒絕）
    @discardableResult
    public func setEndpoint(_ urlString: String) -> (success: Bool, message: String) {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return (false, "無效的 URL 格式。")
        }
        
        guard Self.isLoopback(url: url) else {
            return (false, "隱私安全政策限制：端點僅限本機迴路（127.0.0.1、localhost、::1）。嚴格禁止對外連線。")
        }
        
        self.endpoint = url.absoluteString
        UserDefaults.standard.set(self.endpoint, forKey: "ollama_endpoint")
        return (true, "端點已更新至本機位址：\(self.endpoint)")
    }
    
    // MARK: - 2. 探測本機 Ollama 服務狀態與可用模型
    
    public func checkConnection() async {
        connectionState = .loadingModels
        lastErrorMessage = nil
        
        guard let url = URL(string: "\(endpoint)/api/tags") else {
            connectionState = .disconnected
            isOnline = false
            lastErrorMessage = "Invalid endpoint URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                connectionState = .disconnected
                isOnline = false
                lastErrorMessage = "Ollama returned status \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                return
            }
            
            struct TagsResponse: Decodable {
                struct ModelInfo: Decodable {
                    let name: String
                }
                let models: [ModelInfo]?
            }
            
            if let decoded = try? JSONDecoder().decode(TagsResponse.self, from: data),
               let models = decoded.models, !models.isEmpty {
                self.availableModels = models.map { $0.name }
                if !self.availableModels.contains(selectedModel) {
                    self.selectedModel = self.availableModels.first ?? "llama3.2"
                }
                self.isOnline = true
                self.connectionState = .modelReady
            } else {
                // 服務在線但尚未安裝模型
                self.availableModels = []
                self.isOnline = true
                self.connectionState = .connected
            }
        } catch {
            self.connectionState = .disconnected
            self.isOnline = false
            self.lastErrorMessage = "Ollama is not running on \(endpoint)."
        }
    }
    
    // MARK: - 3. Vision 多模態能力判斷
    
    /// 當前選定模型是否支援 Vision 多模態分析
    public var isCurrentModelVisionCapable: Bool {
        let lower = selectedModel.lowercased()
        return lower.contains("llava") ||
               lower.contains("vision") ||
               lower.contains("vl") ||
               lower.contains("bakllava") ||
               lower.contains("minicpm") ||
               lower.contains("moondream")
    }
    
    // MARK: - 4. 串流對話請求（支援文字與 Base64 圖片）
    
    public struct ChatMessagePayload {
        public let role: String
        public let content: String
        public let images: [String]? // Base64 encoded JPEG/PNG
        
        public init(role: String, content: String, images: [String]? = nil) {
            self.role = role
            self.content = content
            self.images = images
        }
        
        public func toDictionary() -> [String: Any] {
            var dict: [String: Any] = [
                "role": role,
                "content": content
            ]
            if let images = images, !images.isEmpty {
                dict["images"] = images
            }
            return dict
        }
    }
    
    public func streamChat(
        messages: [ChatMessagePayload],
        onToken: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {
        guard isOnline else {
            onError("Ollama 本機服務目前未啟動。請在 Mac 終端機執行 `ollama serve`。")
            return
        }
        
        guard let url = URL(string: "\(endpoint)/api/chat") else {
            onError("無效的本機端點。")
            return
        }
        
        connectionState = .generating
        
        let rawMessages = messages.map { $0.toDictionary() }
        let requestPayload: [String: Any] = [
            "model": selectedModel,
            "messages": rawMessages,
            "stream": true
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestPayload) else {
            connectionState = .modelReady
            onError("封裝對話請求失敗。")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        request.timeoutInterval = 120.0
        
        activeTask?.cancel()
        activeTask = Task {
            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    self.connectionState = .modelReady
                    onError("Ollama 回應狀態碼：\((response as? HTTPURLResponse)?.statusCode ?? 500)")
                    return
                }
                
                for try await line in bytes.lines {
                    if Task.isCancelled { break }
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }
                    
                    if let lineData = trimmed.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                       let msg = json["message"] as? [String: Any],
                       let content = msg["content"] as? String,
                       !content.isEmpty {
                        onToken(content)
                    }
                }
                
                self.connectionState = .modelReady
                onComplete()
            } catch {
                if !Task.isCancelled {
                    self.connectionState = .modelReady
                    onError("串流傳輸中斷：\(error.localizedDescription)")
                }
            }
        }
    }
    
    public func stopGeneration() {
        activeTask?.cancel()
        activeTask = nil
        connectionState = .modelReady
    }
    
    // MARK: - 5. 本機私密回憶 RAG 上下文檢索引擎 (Grounded Local RAG)
    
    public func buildGroundedMemoryContext(
        query: String,
        diaries: [DiaryEntry],
        mediaItems: [MediaItem]
    ) -> String {
        // MARK: - 保險庫隱私屏障 (Vault Privacy Barrier)
        // 當保險庫配置且處於鎖定狀態時，嚴格阻絕 AI 存取任何私人日記與媒體資料
        if VaultEncryptionService.shared.isVaultConfigured && !VaultEncryptionService.shared.isUnlocked {
            return """
            【Noty 隱私保險庫防護啟動中】
            當前 Noty AES-256 保險庫處於鎖定保護狀態。
            基於本機資料安全最高原則，私人日記正文、中繼資料、照片與影片內容已全面封鎖，本機 AI 無法存取任何私人記憶。
            請明確告知使用者：「您的 Noty 保險庫目前處於鎖定保護狀態。為確保您的隱私安全，請先解鎖保險庫，我才能為您檢索私人日記與照片回憶。」
            """
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        let activeDiaries = diaries.filter { !$0.isDeleted }
        let activeMedia = mediaItems.filter { !$0.isDeleted }
        
        let photos = activeMedia.filter { $0.mediaType == .image }
        let videos = activeMedia.filter { $0.mediaType == .video }
        
        // 計算統計數據（本月、上個月）
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        
        let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        let lastMonthYear = calendar.component(.year, from: lastMonthDate)
        let lastMonth = calendar.component(.month, from: lastMonthDate)
        
        let photosThisMonth = photos.filter {
            let y = calendar.component(.year, from: $0.importedAt)
            let m = calendar.component(.month, from: $0.importedAt)
            return y == currentYear && m == currentMonth
        }.count
        
        let photosLastMonth = photos.filter {
            let y = calendar.component(.year, from: $0.importedAt)
            let m = calendar.component(.month, from: $0.importedAt)
            return y == lastMonthYear && m == lastMonth
        }.count
        
        let videosThisMonth = videos.filter {
            let y = calendar.component(.year, from: $0.importedAt)
            let m = calendar.component(.month, from: $0.importedAt)
            return y == currentYear && m == currentMonth
        }.count
        
        let videosLastMonth = videos.filter {
            let y = calendar.component(.year, from: $0.importedAt)
            let m = calendar.component(.month, from: $0.importedAt)
            return y == lastMonthYear && m == lastMonth
        }.count
        
        let diariesThisMonth = activeDiaries.filter {
            let y = calendar.component(.year, from: $0.entryDate)
            let m = calendar.component(.month, from: $0.entryDate)
            return y == currentYear && m == currentMonth
        }.count
        
        // 彙整所有出現過的標籤與頻率
        var tagCounts: [String: Int] = [:]
        for d in activeDiaries {
            for t in d.tags { tagCounts[t, default: 0] += 1 }
        }
        for m in activeMedia {
            for t in m.tags { tagCounts[t, default: 0] += 1 }
        }
        let topTags = tagCounts.sorted { $0.value > $1.value }.prefix(10)
        let tagsSummary = topTags.map { "#\($0.key) (\($0.value)次)" }.joined(separator: ", ")
        
        var lines: [String] = []
        lines.append("你是 Noty 的本機私密 AI 助理，運行於 Apple Silicon Mac 上，所有數據均 100% 離線 (offline) 保存於本機沙盒資料庫。")
        lines.append("當前時間：\(now.formatted(date: .abbreviated, time: .shortened))")
        lines.append("")
        lines.append("【本機資料庫真實統計數據（精確無誤）】")
        lines.append("- 總照片數量：\(photos.count) 張")
        lines.append("- 總影片數量：\(videos.count) 部")
        lines.append("- 總日記數量：\(activeDiaries.count) 篇")
        lines.append("- 本月（\(currentYear)年\(currentMonth)月）上傳照片：\(photosThisMonth) 張、影片：\(videosThisMonth) 部、日記：\(diariesThisMonth) 篇")
        lines.append("- 上個月（\(lastMonthYear)年\(lastMonth)月）上傳照片：\(photosLastMonth) 張、影片：\(videosLastMonth) 部")
        lines.append("- 常見標籤：\(tagsSummary.isEmpty ? "目前無標籤" : tagsSummary)")
        lines.append("")
        
        // 檢索相關日記（最多 15 篇）
        lines.append("【本機已發布日記真實清單】")
        if activeDiaries.isEmpty {
            lines.append("（目前尚無日記紀錄）")
        } else {
            for diary in activeDiaries.prefix(15) {
                let dStr = diary.entryDate.formatted(date: .abbreviated, time: .omitted)
                let title = diary.title.isEmpty ? "無標題" : diary.title
                let tagsStr = diary.tags.isEmpty ? "" : " [標籤: \(diary.tags.joined(separator: ", "))]"
                let snippet = diary.content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(180)
                lines.append("- 日期: \(dStr) | 心情: \(diary.mood) | 標題: \(title)\(tagsStr)\n  內文: \(snippet)")
            }
        }
        lines.append("")
        
        // 檢索近期照片與影片（最多 20 筆）
        lines.append("【本機媒體庫真實紀錄（部分精選）】")
        if activeMedia.isEmpty {
            lines.append("（目前尚無媒體紀錄）")
        } else {
            for item in activeMedia.prefix(20) {
                let dStr = item.capturedAt.formatted(date: .abbreviated, time: .omitted)
                let typeStr = item.mediaType == .video ? "影片(時長\(Int(item.durationSeconds))秒)" : "照片"
                let tagsStr = item.tags.isEmpty ? "" : " [標籤: \(item.tags.joined(separator: ", "))]"
                let desc = item.caption.isEmpty ? "" : " - 描述: \(item.caption)"
                lines.append("- \(item.originalFileName) (\(typeStr), 日期: \(dStr))\(tagsStr)\(desc)")
            }
        }
        lines.append("")
        lines.append("【AI 回答強制規範】")
        lines.append("1. 【真實性第一】：你只能根據上方提供的「本機資料庫真實統計數據與紀錄」回答問題。如果使用者詢問的內容在資料庫中不存在（例如不存在的日期、不存在的某張照片或日記），請明確誠實地告知「在您的本機 Noty 庫中未找到相關紀錄」，絕不可以虛構、捏造或猜測不存在的記憶。")
        lines.append("2. 【明確區分】：必須明確區分「資料庫中實際記錄的事實」與「你依據文字所做的推測與建議」。")
        lines.append("3. 【統計精確】：當使用者詢問「上個月上傳了多少照片」或「最近有哪些影片」等問題，請直接引用上方真實統計數據精確回答。")
        lines.append("4. 請以繁體中文親切、簡潔、真誠地回答使用者。")
        
        return lines.joined(separator: "\n")
    }
    
    /// 兼容性別名
    public func buildMemoryContext(
        query: String,
        diaries: [DiaryEntry],
        mediaItems: [MediaItem]
    ) -> String {
        buildGroundedMemoryContext(query: query, diaries: diaries, mediaItems: mediaItems)
    }
}
