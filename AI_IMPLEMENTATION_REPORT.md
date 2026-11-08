# Noty — 本機 Ollama AI 實作與隱私屏障報告 (AI_IMPLEMENTATION_REPORT.md)

> **服務實作**：`OllamaService.swift` & `AIAssistantPanelView.swift`  
> **端點策略**：純本機迴路（`127.0.0.1:11434` / `localhost` / `::1`），杜絕任何外部 IP 或網域  
> **技術機制**：真實 REST API（`/api/tags` & `/api/chat`）、串流應答 (Streaming)、主動中斷 (Stop Generation)、本地 RAG 檢索、保險庫鎖定屏障 (Vault Privacy Barrier)

---

## 1. 核心實作功能

1. **本機迴路連線管理**：
   - 探測本機 Ollama 守護行程是否啟動。
   - 動態讀取 `/api/tags`，取得已安裝之真實模型清單，不使用假資料。
   - 支援即時模型切換與 Vision 多模態能力偵測（如 `llava`、`llama3.2-vision`）。
2. **True Streaming & 中斷機制**：
   - 使用 `URLSession.bytes(for:)` 進行非同步行串流讀取。
   - 提供實體「停止生成」按鈕，觸發 `Task.cancel()` 立即釋放連線與推論資源。
3. **本機 RAG 私密記憶檢索 (Grounded Retrieval)**：
   - 動態分析使用者提問，檢索本機 SwiftData 之真實日記與照片/影片中繼資料（日期、標籤、EXIF、相機型號）。
   - 構造結構化事實上下文注入 System Prompt，強制 AI 依據本機事實回答，杜絕幻覺與捏造。
4. **保險庫鎖定硬性隱私屏障 (Vault Privacy Barrier)**：
   - 當保險庫處於鎖定狀態時，檢索層主動阻斷對任何私人日記內文與媒體中繼資料之讀取。
   - 向使用者明確揭露：「您的保險庫目前處於鎖定保護狀態，為確保您的隱私安全，請先解鎖保險庫。」
   - 經單元測試 `testOllamaVaultLockedPrivacyBarrier` 100% 驗證通過。
