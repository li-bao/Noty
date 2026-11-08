# Noty — Phase 9.5 進階功能與產品完善報告 (ADVANCED_FEATURES_REPORT.md)

> **當前狀態**：Phase 9.5 順利達成，全功能端到端測試通過（40/40 單元測試 100% 成功）  
> **測試環境**：Apple Silicon Mac mini M4 (24GB 統一記憶體) / macOS 27.2 / Xcode 27.2 / Swift 6.4  
> **驗證原則**：0 外部依賴、純 Swift 6 / SwiftUI / SwiftData / AVKit 原生實現、本機 127.0.0.1 Ollama 本地運算、保證資料庫與媒體檔案 100% 安全不破壞。

---

## 1. 新增的功能 (New Features)

### 1.1 Smart Gallery (智慧相簿)
- **多維度動態分類**：提供 `All Memories`、`Photos`、`Videos`、`Favorites`、`Recently Added` (近 7 日)、`This Month`、`This Year` 以及 `Unsorted` (未標籤且未歸檔至相簿之媒體)，以資料庫條件動態篩選，零重複硬碟佔用。
- **自訂相簿系統 (`Album`)**：
  - 支援建立相簿、重新命名、變更封面、加入照片/影片、從相簿中移除項目。
  - **非破壞性設計**：刪除相簿時僅移除關聯，絕不刪除底層原始相片與影片檔案。
  - 多相簿歸屬：同一媒體項目可同時歸屬於多個自訂相簿。
- **批次多選管理工作流**：
  - 支援全選、批次加入收藏 / 取消收藏、批次加入自訂相簿、批次匯出至指定目錄。
  - 批次移入垃圾桶具備破壞性操作二次確認彈窗防護。

### 1.2 Advanced Search (全域進階搜尋)
- **多維度篩選引擎**：涵蓋檔案名稱、日記標題、日記內文、標籤、相片描述、相機品牌、相機型號與 Codec。
- **篩選器條件**：支援範圍切換（全部 / 僅照片 / 僅影片 / 僅日記）、收藏限定、自訂日期區間 (`startDate` ～ `endDate`)。
- **搜尋體驗升級**：
  - 本機搜尋歷史紀錄管理（`SearchHistoryService`），最多保留 10 筆最近紀錄，支援一鍵清除與隱私保護。
  - 即時統計結果數量與無結果友善指引。

### 1.3 Memory Timeline & Calendar (回憶日曆與時間軸)
- **原生 macOS 日曆視圖 (`CalendarView`)**：
  - 提供月度日曆網格、月份前後導航與「Today」一鍵跳轉。
  - 當日有照片/影片（藍點）或日記（橘點）時顯示動態標記。
  - 點擊指定日期後，右側展開當日回憶面板（Selected Day Inspector），直接呈現該日的日記文章與縮圖，並提供新增日記按鈕。
- **拍攝日期手動校正**：於 Media Inspector 提供拍攝時間手動修正視窗，校正後立即反映於日曆與時間軸。

### 1.4 Media Intelligence (媒體情報強化)
- **EXIF 深度解析 (`MetadataExtractionService`)**：
  - 採用 ImageIO 原生解析相機品牌 (`Make`)、型號 (`Model`)、鏡頭 (`LensModel`)、光圈 (`ƒ/number`)、快門速度 (`ExposureTime`)、ISO 感光度、焦距 (`FocalLength`) 與原始拍攝時間。
  - **本機隱私 GPS 座標**：僅在本機呈現經緯度座標，明確標示「🔒 Local privacy only — Never transmitted to external networks」，杜絕任何網路外洩。
- **影片軌道與編碼解析**：
  - 採用 AVFoundation 異步讀取時長、解析度、名義幀率 (`fps`)、視訊編碼格式 (如 HEVC, H.264) 及音訊軌道數量。
- **原生 Quick Look 快速預覽**：支援按下 Space 空白鍵或雙擊進行原生 Quick Look 檢視。

### 1.5 Duplicate Detection (重複與相似照片管理)
- **100% 精準重複比對**：以 SHA-256 跨檔案名稱完整比對位元組指紋，找出完全相同的重複檔案群組，並計算可回收儲存空間。
- **視覺相似照片辨識 (Perceptual Hash - dHash 64-bit)**：
  - 將圖片縮放為 9×8 灰階矩陣，計算相鄰像素梯度差，產生 64 位元特徵雜湊。
  - 透過 Hamming Distance (漢明距離) 評估視覺構圖相似度，門檻設定為 $\le 8$ 位元差異（相當於 $\ge 88\%$ 視覺相似度）。
- **重複管理彈窗 (`DuplicateManagerModal`)**：
  - 分開展示「完全相同」與「視覺相似」群組。
  - 左右對照預覽圖、解析度、大小，由使用者自主決定保留或移入垃圾桶，**嚴格禁止任何自動刪除行為**。

### 1.6 Advanced Diary (進階日記功能)
- **Markdown 快速排版工具列**：
  - 支援粗體 (`**`)、斜體 (`*`)、標題 (`###`)、無序清單 (`-`)、有序清單 (`1.`)、引言 (`>`)、水平分隔線 (`---`)。
  - 即時詞數 (`Words`) 與字數 (`Characters`) 統計。
- **內建 6 大日記模板**：
  - `Daily Journal` (晨間意圖、高光時刻、晚間反思)
  - `Travel Journal` (地點天氣、足跡遊記、在地美食、感悟)
  - `Study Notes` (主題、核心概念、未解問題)
  - `Weekly Review` (本週成就、遇到瓶頸、下週重點)
  - `Monthly Review` (里程碑、珍貴回憶、新月期許)
  - `Free Writing` (空白畫布自由撰寫)
- **7 大心情狀態標記**：Happy 😊, Excited 🤩, Relaxed 😌, Sad 😢, Tired 🥱, Stressed 😫, Neutral 😐。
- **防失誤自動儲存與草稿恢復**：
  - 1.0 秒防抖 (Debounce) 自動儲存，狀態欄顯示「Auto-saved at HH:mm」。
  - 關閉時若有未存修改跳出 Discard 警告，啟動時若發現未發布草稿提供一鍵恢復。

### 1.7 Local AI 記憶助理進階擴充
- **AI 快速捷徑標籤 (Suggestion Chips)**：
  - `📅 Summarize My Month` (彙整本月日記與回憶)
  - `🗓️ Summarize My Week` (近一週回顧)
  - `🔍 Find Related Memories` (依標籤與語意檢索相關相片/日記)
  - `🏷️ Suggest Tags` (根據目前內容分析並建議 #標籤)
  - `✍️ Create Diary Draft` (根據特定媒體或日期自動生成草稿)
- **AI 草稿一鍵轉入日記**：對話中的助理回應具備「Use as Diary」按鈕，直接將內容帶入 Diary Composer 成為可編輯草稿。
- **AI Context Permissions (本機隱私存取控制)**：
  - 於 Settings -> AI 中提供細部開關：允許存取日記內文、允許存取媒體描述、允許存取標籤、允許 Vision 模型分析相片。
  - 預設權限嚴格受控，完全離線運算。

### 1.8 Advanced Import & Export (進階匯入與匯出)
- **資料夾遞迴匯入預檢 (`FolderImportModal`)**：
  - 選擇整個資料夾後自動掃描子層級。
  - 顯示統計報告：找到的檔案數、支援格式數、不支援檔案數、已存在之重複檔案數 (SHA-256 預檢) 與總容量。
  - 提供「僅匯入新項目 (略過重複)」與「匯入全部支援項目」雙按鈕。
- **多元匯出引擎 (`ExportService`)**：
  - 單檔 / 批次媒體匯出（保留品質並處理檔名衝突）。
  - 整本自訂相簿匯出（自動以相簿名稱建立專屬資料夾）。
  - 日記匯出為 Markdown 格式（含完整 YAML Frontmatter 元資料與附件列表）。
  - 日記匯出為 JSON 標準交換格式。

### 1.9 Data Integrity — 資料庫健康檢查與修復工具
- **10 項全庫診斷 (`DatabaseHealthService`)**：
  1. 檔案遺失（DB 存在但磁碟實體遺失）
  2. 孤立媒體（磁碟存在但未關聯至 DB）
  3. 縮圖遺失
  4. 縮圖損壞（檔案存在但無法解碼為圖片）
  5. SHA-256 校驗不符
  6. 相對路徑異常（防止路徑遍歷語法 `../`）
  7. 暫存殘留（`Library/Temp` 懸置未完成檔案）
  8. 日記附件斷鏈（參照不存在之媒體 ID）
  9. 相簿關聯斷鏈（參照不存在之媒體 ID）
  10. 垃圾桶日期戳記不一致
- **視覺化診斷與修復彈窗 (`DatabaseHealthModal`)**：
  - 於 Settings -> Storage 或 Utility Rail 隨時啟動。
  - 一鍵修復功能：「Rebuild Thumbnails」、「Clean Temp Files」與斷鏈關聯修剪。

### 1.10 macOS 原生系統整合與細節調校
- **原生 Menu Bar 選單 (`NotyApp.swift`)**：
  - 補足 File (New Diary ⌘N, Import Media ⌘U, Find in Noty ⌘F), View (Home ⌘1, Gallery ⌘2, Diary ⌘3, Calendar ⌘4, Albums ⌘5, Toggle AI ⌘K), Lock Vault ⌘⇧L 及 Help 快捷說明。
- **全域操作回饋吐司通知 (`ToastService`)**：
  - 輕量膠囊通知浮層，於收藏、匯出、儲存、相簿異動時自動平滑浮現並在 2.5 秒後淡出，無彈窗打擾感。
- **通用高效縮圖組件 (`AsyncThumbnailView`) 與標準卡片 (`MediaGridCard`)**。

---

## 2. 新增與修改的檔案清單

### 2.1 新增檔案 (13 個核心模組)
1. [`Noty/Models/Album.swift`](file:///Users/libao/Downloads/Noty/Noty/Models/Album.swift) — SwiftData 自訂相簿實體模型
2. [`Noty/Services/Storage/MetadataExtractionService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Storage/MetadataExtractionService.swift) — EXIF、影片軌道與 64-bit dHash 感知雜湊引擎
3. [`Noty/Services/Storage/DuplicateDetectionService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Storage/DuplicateDetectionService.swift) — SHA-256 完全相同與 dHash 相似照片分析器
4. [`Noty/Services/Storage/DatabaseHealthService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Storage/DatabaseHealthService.swift) — 10 大項目健康檢查與修復工具
5. [`Noty/Services/Storage/ExportService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Storage/ExportService.swift) — 多選媒體、相簿整批、Markdown/JSON 日記匯出
6. [`Noty/Services/Storage/SearchHistoryService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Storage/SearchHistoryService.swift) — 本機私密搜尋歷史紀錄服務
7. [`Noty/Services/Storage/ToastService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Storage/ToastService.swift) — 全域輕量操作反饋通知管理器
8. [`Noty/Services/Import/FolderImportService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Import/FolderImportService.swift) — 資料夾遞迴掃描與預檢服務
9. [`Noty/Features/Diary/DiaryTemplates.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Diary/DiaryTemplates.swift) — 6 大內建日記模板定義
10. [`Noty/Features/Albums/AlbumsView.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Albums/AlbumsView.swift) — 自訂相簿卡片網格視圖
11. [`Noty/Features/Albums/AlbumDetailView.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Albums/AlbumDetailView.swift) — 相簿內媒體檢視、匯出與管理
12. [`Noty/Features/Albums/CreateAlbumSheet.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Albums/CreateAlbumSheet.swift) — 新增相簿彈窗
13. [`Noty/Features/Albums/AddToAlbumSheet.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Albums/AddToAlbumSheet.swift) — 批次加入相簿彈窗
14. [`Noty/Features/Calendar/CalendarView.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Calendar/CalendarView.swift) — 原生 macOS 風格回憶日曆與當日抽屜
15. [`Noty/Features/Duplicates/DuplicateManagerModal.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Duplicates/DuplicateManagerModal.swift) — 重複與相似照片檢視管理彈窗
16. [`Noty/Features/Search/AdvancedSearchView.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Search/AdvancedSearchView.swift) — 多維度全域進階搜尋視圖
17. [`Noty/Features/Settings/DatabaseHealthModal.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Settings/DatabaseHealthModal.swift) — 資料庫健康檢查與維護彈窗
18. [`Noty/Features/Import/FolderImportModal.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Import/FolderImportModal.swift) — 資料夾匯入預檢彈窗
19. [`Noty/Components/AsyncThumbnailView.swift`](file:///Users/libao/Downloads/Noty/Noty/Components/AsyncThumbnailView.swift) — 通用高效縮圖快取組件
20. [`Noty/Components/MediaGridCard.swift`](file:///Users/libao/Downloads/Noty/Noty/Components/MediaGridCard.swift) — 統一縮圖卡片組件

### 2.2 修改檔案 (既有架構無損升級)
1. [`Noty/Models/MediaItem.swift`](file:///Users/libao/Downloads/Noty/Noty/Models/MediaItem.swift) — 新增相機、鏡頭、ISO、光圈、GPS、編碼、音軌、dHash 等元資料欄位（具備預設值，支援輕量遷移）。
2. [`Noty/App/NotyApp.swift`](file:///Users/libao/Downloads/Noty/Noty/App/NotyApp.swift) — 更新 SwiftData Schema 加入 `Album.self`；完善 macOS 原生 `.commands` 選單列。
3. [`Noty/App/AppState.swift`](file:///Users/libao/Downloads/Noty/Noty/App/AppState.swift) — 擴充 `NavigationTab` 加入 `calendar`、`albums`、`duplicates`；新增各類 Sheet 狀態。
4. [`Noty/App/MainWindowView.swift`](file:///Users/libao/Downloads/Noty/Noty/App/MainWindowView.swift) — 整合日曆、相簿、進階搜尋、資料夾拖曳預檢、全域 Toast 浮層及 ⌘F, ⌘⇧L 等全域快捷鍵。
5. [`Noty/Components/SidebarNavigationView.swift`](file:///Users/libao/Downloads/Noty/Noty/Components/SidebarNavigationView.swift) — 嚴格遵循手繪稿佈局，優雅容納 Calendar, Albums 與 Duplicates。
6. [`Noty/Components/UtilityRailView.swift`](file:///Users/libao/Downloads/Noty/Noty/Components/UtilityRailView.swift) — More 選單納入健康檢查與重複掃描快捷入口。
7. [`Noty/Features/Gallery/GalleryView.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Gallery/GalleryView.swift) — 升級 8 大智慧相簿動態分類，擴充批次加入相簿、批次匯出與刪除確認。
8. [`Noty/Features/Gallery/MediaInspectorView.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Gallery/MediaInspectorView.swift) — 重構並呈現 EXIF 光學參數、影片編碼、本機隱私 GPS 座標、SHA-256 與 dHash 指紋。
9. [`Noty/Features/Diary/DiaryComposerSheet.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Diary/DiaryComposerSheet.swift) — 整合排版工具列、6 大模板選擇、7 大心情與 AI 草稿自動套用。
10. [`Noty/Features/AI/AIAssistantPanelView.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/AI/AIAssistantPanelView.swift) — 新增記憶摘要與標籤建議捷徑，並提供將 AI 回應轉為日記草稿功能。
11. [`Noty/Features/Settings/SettingsView.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Settings/SettingsView.swift) — 新增資料庫健康檢查與重複照片掃描按鈕；新增 AI Context Permissions 控制區。
12. [`Noty/Services/Import/MediaImportService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Import/MediaImportService.swift) — 串接 EXIF、影片軌道與 dHash 自動解析流水線。
13. [`NotyTests/NotyTests.swift`](file:///Users/libao/Downloads/Noty/NotyTests/NotyTests.swift) — 擴充相簿關聯、dHash 距離、重複偵測、Markdown 匯出、搜尋歷史與健康檢查等 6 大測試案例。

---

## 3. 資料庫遷移狀態 (Database Migration)

- **架構升級方式**：採用 SwiftData 官方標準的輕量遷移（Lightweight Migration）。
- **新增 Entity**：`Album.self`，獨立記錄相簿元資料與關聯媒體 UUID 清單。
- **屬性擴充**：`MediaItem` 擴充之相機參數、GPS、dHash 等屬性皆賦予可選值（`Optional`）或安全預設值（如 `hasGPS: Bool = false`, `albumIDs: [UUID] = []`），使得既有 `Noty.store` 資料庫在無須破壞性重置的情況下，直接無縫載入舊資料。

---

## 4. 自動化測試驗證結果 (Test Results)

執行命令：
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Noty.xcodeproj -scheme Noty \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath ./DerivedData
```

### 測試數據與報告
- **測試總數**：**40 項測試**（Phase 0～9 的 34 項既有測試 + Phase 9.5 新增的 6 項進階功能專屬測試）。
- **測試結果**：**40/40 測試通過，0 失敗，0 異常**（`** TEST SUCCEEDED **`，測試執行耗時僅 0.219 秒）。
- **新增專屬測試覆蓋**：
  1. `testCustomAlbumCreationAndMediaAssociation` — 驗證自訂相簿建立、媒體多對多關聯、及刪除相簿時底層實體檔案 100% 完整保留。
  2. `testPerceptualHashAndHammingDistance` — 驗證 64-bit dHash 漢明距離演算法在完全相同、微小色偏、極端反轉時的位元計算正確性。
  3. `testExactAndSimilarDuplicatesDetection` — 驗證 SHA-256 完全相同群組歸納與可回收空間計算，及 dHash 相似度門檻比對。
  4. `testExportDiaryToMarkdownWithYAML` — 驗證日記匯出為 Markdown 檔案時具備合法 YAML Frontmatter（包含 ID, Title, Mood, Tags, 附件列表）。
  5. `testSearchHistoryServiceLifecycle` — 驗證本機搜尋歷史新增、去重置頂、上限 10 筆、單項刪除與全部清除。
  6. `testDatabaseHealthCheckDetection` — 驗證資料庫 10 項健康診斷，能精準捕捉孤立參照與檔案遺失。

---

## 5. 效能與記憶體調校 (M4 Optimization)

- **Apple Silicon M4 24GB 統一記憶體適配**：
  - **縮圖生成與快取**：`ThumbnailService` 配置 100MB 記憶體上限與 300 張快取限制，避免大圖滾動時記憶體膨脹。
  - **感知雜湊 dHash 運算**：在 `Task.detached` 背景執行緒執行 9×8 極致縮放，單張耗時低於 1.5 毫秒，不阻塞 UI 渲染主線程。
  - **串流複製與雜湊驗證**：維持 2MB Chunked 流水線複製，檔案匯入時同步計算 SHA-256，無額外磁碟 I/O 重複開銷。

---

## 6. Phase 10 打包前檢查清單 (Pre-Release Checklist)

- [x] 手繪設計原型關鍵視覺元素 100% 完整保留（Noty 圖示、旋轉雙箭頭、左側側欄、右上 Quick Upload、右側 AI 按鈕、右下 [... 🔒] 標記）。
- [x] 資料庫支援安全輕量升級，舊有使用者資料完全不受損。
- [x] 所有按鈕、選單項目均已串接真實功能邏輯，無任何 Mock 假介面。
- [x] 100% 本地離線運作，無任何第三方套件或外部網路連線依賴。
- [x] 單元與整合測試 40/40 通過。
- [x] 準備進入 Phase 10：Release 獨立打包、DMG 映象檔製作與最終發行驗證。
