# Noty — 階段式開發任務追蹤書 (TASKS.md)

> **當前狀態**：Phase 0 ～ Phase 9 全數完成，全功能端到端測試通過（34/34 單元測試 100% 成功）  
> **最後更新**：2026-11-07  
> **專案準則**：每個出現在介面上的按鈕皆具備真實功能；無第三方套件，100% 原生 Swift 6 / SwiftUI / SwiftData / AVKit，極致精確還原手繪稿原型。

---

## 總覽進度條

- [x] **Phase 0**：全域開發規範、手繪圖分析與架構規格定義
- [x] **Phase 1**：專案基底建置、原生視窗管線與編譯驗證
- [x] **Phase 2**：Noty UI 與品牌設計（手繪原型現代化原生精雕、AppIcon 向量生成、三大區域佈局）
- [x] **Phase 3**：本機資料庫與檔案資料夾（Application Support 結構樹、SwiftData 相對路徑引擎、安全軟刪除與資料庫管理）
- [x] **Phase 4**：上傳系統與媒體匯入（原生檔案選擇器、嚴謹複製校驗流程、去重機制、進度彈窗、拖曳匯入與縮圖引擎）
- [x] **Phase 5**：中央藝廊相簿（Gallery）與高效原生多媒體檢視器（縮放照片檢視、AVPlayer 原生控制、資訊側欄與批次操作）
- [x] **Phase 6**：私人日記與 Instagram 風格圖文動態牆（Timeline & Diary System、心情選擇器、媒體附加與標籤）
- [x] **Phase 7**：本機 Ollama AI 智慧助理抽屜（AI ← 本地端點 127.0.0.1、模型切換、私密記憶檢索 RAG、串流應答）
- [x] **Phase 8**：鎖定、安全、More 選單、完整設定與安全備份還原系統（Lock 🔒、Keychain 備援密碼、5 大板塊 Settings、Backup & Restore）
- [x] **Phase 9**：全面測試、檔案可靠性驗證、UI 精修與效能調校（34/34 項測試 100% 通過、AVPlayer 與記憶體防護、生成 [`TEST_REPORT.md`](file:///Users/libao/Downloads/Noty/TEST_REPORT.md)）
- [x] **Phase 9.5**：進階功能與產品完善（Smart Gallery、自訂相簿、進階搜尋、日曆時間軸、EXIF/影片資訊、重複/相似照片偵測、進階日記與模板、Local AI 記憶助理、資料夾匯入、資料庫健康檢查、選單列與原生效能調校，40/40 測試 100% 通過，生成 [`ADVANCED_FEATURES_REPORT.md`](file:///Users/libao/Downloads/Noty/ADVANCED_FEATURES_REPORT.md)）
- [x] **Phase 9.75**：終極精雕、密碼安全、Liquid Glass 與本機 AI 深度整合（新版 Logo 嚴格保留左下角「L」、真 AES-256-GCM 保險庫、原創 LFES-12122 演算法、全域 Apple Liquid Glass 膠囊化、文字重疊全面根治、外觀切換修復、動態流體上傳交互、AI 保險庫硬性隱私屏障、安全儀表板，53/53 測試 100% 通過，完成 15 份規格文件）
- [x] **Phase 9.875**：長期可靠性、全專案 Liquid Glass 深度審計與終極最佳化（全按鈕 Liquid Glass 統一設計系統、代碼 Bug 獵捕與記憶體防護、重要回憶防誤刪與 Undo 撤銷、備份版本輪替、隔離沙盒災難復原驗證、開放式可攜回憶封裝庫 NotyArchive、持久化匯入佇列與前置磁碟監控、今日回憶時光機 On This Day、日記歷史版本快照與草稿復原、儲存健康儀表板、動態智慧相簿與關聯推薦、高乘載壓力測試，63/63 測試 100% 通過，完成 14 份專業規格文件）

---

## 各階段細部任務清單

### Phase 0：全域開發規範與架構設計（第一個執行）
- [x] 深度解析手繪 UI 設計稿（左上品牌、左導覽、中央藝廊、頂部導航/日期、右側 AI/Upload/Lock）
- [x] 確立不可變更之品牌規範（名稱永久為 `Noty`，左上角固定顯示 Noty 圖示與名稱）
- [x] 確立隱私與技術紅線（100% Local、純 Swift/SwiftUI、SwiftData、本機 Ollama、非破壞性儲存）
- [x] 建立專案核心規格文件：[`PROJECT_SPEC.md`](file:///Users/libao/Downloads/Noty/PROJECT_SPEC.md)
- [x] 建立系統架構設計文件：[`ARCHITECTURE.md`](file:///Users/libao/Downloads/Noty/ARCHITECTURE.md)
- [x] 建立任務追蹤清單文件：[`TASKS.md`](file:///Users/libao/Downloads/Noty/TASKS.md)

---

### Phase 1：專案基底建置與原生視窗管線
- [x] 環境診斷（Apple Silicon M-series ARM64, macOS 27.0.1, Xcode 27.2, Swift 6.4, 156GB 剩餘空間）
- [x] 配置原生 macOS 應用程式結構（Swift 6 / macOS 14.0+ / Apple Silicon ARM64）
- [x] 建立真正的 Xcode 專案 [`Noty.xcodeproj`](file:///Users/libao/Downloads/Noty/Noty.xcodeproj)（Bundle ID: `com.libao.noty`）
- [x] 建立清楚的分層目錄（App, Core, Models, Services, Features, Components, Resources, Tests, scripts, docs, dist）
- [x] 實作專案自動化建置與執行腳本（[`scripts/build.sh`](file:///Users/libao/Downloads/Noty/scripts/build.sh), [`scripts/run.sh`](file:///Users/libao/Downloads/Noty/scripts/run.sh)）
- [x] 設定應用程式 Entitlements（沙盒環境、使用者選取檔案讀寫、本機 localhost 網路許可）
- [x] 建立原生沉浸式視窗基底（Unified Titlebar & Sidebar 樣式）與品牌識別組件
- [x] 執行本機編譯驗證（確認產物為純 `Mach-O 64-bit executable arm64`）
- [x] 執行單元測試套件（測試通過，0 失敗）
- [x] 驗證原生 App 可正常啟動且運行無誤（Process ID 驗證成功）

---

### Phase 2：Noty UI 與品牌設計（手繪原型現代化原生精雕）
- [x] 建立真正的 Noty 向量 AppIcon 與向量符號（圓角便簽紙、頂底橫線、雙側橫線飾條 `= N =`、中央大寫 N、左下角雙旋迴環箭頭 `↺`，自動產生 16x16 至 1024x1024 全套資源）
- [x] 實作左側 Sidebar（210～240 pt）：
  - [x] 左上角固定且不可隱藏之品牌識別區（`BrandHeaderView`：雙旋迴環向量圖標 + Noty 字樣）
  - [x] 完整導覽項目群（Home, Gallery, Diary, Videos, Upload 快速動作, Collections: Favorites, Recently Added, Trash, More... 與底部 Settings）
  - [x] 所有按鈕真正具備頁面切換或原生動作功能，帶有原生微動態與 Hover 效果
- [x] 實作中央 Main Content：
  - [x] Gallery 頂部導航指示（`You are now at / Gallery` 底線裝飾，與手繪相框人偶太陽標章 `GalleryIllustrationBadge`）
  - [x] 即時手繪格式化日期條（`yyyy/M/d (E)` 如 `2026/11/6(五)`）、升降排序切換（`↑` `↓`）、媒體分類 Segmented Control
  - [x] 忠實還原手繪稿空狀態卡片 `GalleryEmptyView`（`Nothing here... ☹️`、`try [↑ upload]`、`[open file...]`，雙功能按鈕完整串接）
  - [x] 相簿流暢網格視圖 `MediaGridCard`（支援 Hover 放大、喜愛標記、影片標籤）
- [x] 實作右側 Utility Rail：
  - [x] 右上角角落按鈕 `[↑ quick upload]`
  - [x] 右側中央 `[AI ←]` 滑入式抽屜拉柄
  - [x] 右下角 `[... 🔒]` 更多設定與即時上鎖保險庫控制盒
  - [x] 實作 Home, Diary, Videos, Favorites, Recently Added, Trash, Settings 各獨立功能頁面
- [x] 實作右側 Utility Rail（68～76 pt）：
  - [x] 右上角：`Quick Upload` 突顯按鈕，隨時快速匯入
  - [x] 右側中間：固定 `AI ←` 按鈕，點擊以 Spring 動畫滑出右側 AI 抽屜面板，絕不擠壓中央畫布
  - [x] 右下角：`Lock` 一鍵隱私保險庫按鈕，以及 `More` 選單按鈕（設定、在 Finder 中顯示資料庫、備份導出、關於 Noty）
- [x] 實作滑入式本地 Ollama AI 抽屜 `AIAssistantPanelView`（350 pt 浮層、127.0.0.1 狀態檢查、建議問題標籤）
- [x] 實作關於彈窗 `AboutNotyView` 與上傳視窗 `UploadModalView`
- [x] 支援 Light Mode、Dark Mode、Reduce Motion 減弱動態與最小視窗限制（1050 × 680 pt）

---

### Phase 3：本機資料庫與檔案資料夾
- [x] 自動建立標準 Application Support 目錄結構樹（`~/Library/Application Support/Noty/`）：
  - `Database/Noty.store`
  - `Library/Media/Images/`
  - `Library/Media/Videos/`
  - `Library/Thumbnails/`
  - `Library/Temp/`
  - `Library/Exports/`
  - `Library/Backups/`
  - 安全沿用舊資料，絕不覆蓋
- [x] 實作核心儲存服務 [`StorageService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Storage/StorageService.swift)：
  - [x] 串流非同步計算 SHA-256 雜湊
  - [x] 媒體非破壞性安全匯入（自動提取寬高、拍攝時間、影片長度，保留原始檔案）
  - [x] 相對路徑與絕對路徑無縫解析
  - [x] 磁碟容量精準計算與儲存分佈統計
  - [x] 本機全庫離線備份導出
- [x] 實作完整的 SwiftData 資料模型（僅存相對路徑，大型檔案保存在沙盒磁碟）：
  - [x] [`MediaItem.swift`](file:///Users/libao/Downloads/Noty/Noty/Models/MediaItem.swift)（原始檔名、儲存檔名、相對路徑、媒體類型、格式、大小、SHA-256、時間、寬高、時長、描述、收藏、標籤、軟刪除）
  - [x] [`DiaryEntry.swift`](file:///Users/libao/Downloads/Noty/Noty/Models/DiaryEntry.swift)（標題、內容、建立時間、更新時間、所屬日期、附件媒體 ID、標籤、收藏、軟刪除、心情）
- [x] 強化資料庫可靠性與異常防護：
  - [x] 處理遺失或不存在之媒體檔案（UI 溫和提示，絕不 Crash）
  - [x] 重複檔案雜湊檢查與去重
  - [x] 垃圾桶安全軟刪除機制（清空垃圾桶前彈出確認，確認後才執行不可逆的實體檔案清理）
- [x] 實作 Settings 中的資料庫管理介面：
  - [x] 顯示 Noty 資料夾完整路徑
  - [x] 一鍵「Open in Finder」
  - [x] 即時查看總使用容量、照片數量、影片數量、日記數量
  - [x] 一鍵「Export Backup...」全庫離線導出

---

### Phase 4：上傳系統與媒體匯入
- [x] 原生檔案選擇與拖曳匯入：
  - [x] 右上角 Upload 按鈕開啟原生 `NSOpenPanel`，支援多選圖片（JPG, PNG, HEIC, GIF, TIFF, WebP）與影片（MOV, MP4, M4V）
  - [x] 視窗全域拖曳匯入（Drag & Drop）支援，附帶美觀的拖曳反饋浮層
- [x] 嚴謹複製與校驗管線 [`MediaImportService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Import/MediaImportService.swift)：
  - [x] 串流非同步複製至 `Library/Temp/`，支援大型影片 2MB 緩衝分塊，不佔用高額記憶體
  - [x] 雙重校驗機制：比對複製前後的檔案大小（Size）與 SHA-256 數位指紋
  - [x] 驗證通過後原子性移入 `Library/Media/Images/` 或 `Library/Media/Videos/`
  - [x] 失敗或取消時自動清理未完成的暫存檔，原始檔案保持完全獨立不變
- [x] 防衝突與重複處理：
  - [x] 使用 `<SHA256_8位前綴>_<UUID>.<副檔名>` 唯一定名，杜絕檔名衝突
  - [x] SHA-256 查重判定，提供略過（Skip）或強制匯入（Import Anyway）選項
- [x] 現代化進度介面 [`ImportProgressModal.swift`](file:///Users/libao/Downloads/Noty/Noty/Components/ImportProgressModal.swift)：
  - [x] 即時呈現目前檔名、已完成數/總數、當前檔案進度條、總進度條、失敗數與取消按鈕
- [x] 原生縮圖引擎 [`ThumbnailService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Storage/ThumbnailService.swift)：
  - [x] 圖片採用 `ImageIO` 零記憶體暴增即時降採樣
  - [x] 影片採用 `AVAssetImageGenerator` 擷取代表畫面
  - [x] 獨立保存於 `Library/Thumbnails/`，絕不修改原檔

---

### Phase 5：中央藝廊相簿（Gallery）與高效媒體檢視器
- [x] 現代化網格檢視（`GalleryView`）：
  - [x] 照片縮圖與影片縮圖流暢呈現
  - [x] 影片專屬播放標示與時長角標（`mm:ss`）
  - [x] 依日期動態分組（Date Grouping Sections）
  - [x] 最新優先（Newest first）與最舊優先（Oldest first）即時切換
  - [x] 關鍵字即時搜尋（檔名、描述、標籤）
  - [x] 分類篩選（全部、照片、影片、收藏）
  - [x] 多選模式（Select Mode）：批次收藏、批次移入垃圾桶
- [x] 高效照片預覽與手勢縮放 [`InteractiveZoomImageView.swift`](file:///Users/libao/Downloads/Noty/Noty/Components/InteractiveZoomImageView.swift)：
  - [x] 支援雙指 Pinch 縮放（放大至 6x）、平移拖曳（Pan）、雙擊還原（Double-Tap Reset）
  - [x] 大圖記憶體保護（4K 降採樣載入，絕不 OOM）
- [x] 原生自訂影片播放器 [`CustomVideoPlayerView.swift`](file:///Users/libao/Downloads/Noty/Noty/Components/CustomVideoPlayerView.swift)：
  - [x] 基於 AVKit / AVPlayer 打造沉浸式播放介面
  - [x] 播放 / 暫停、音量調整、即時拖曳進度軸、全螢幕播放
  - [x] 空白鍵（Space）播放暫停、方向鍵快進快退
  - [x] 播放控制列自動隱藏動畫
- [x] 媒體資訊側欄與編輯 [`MediaInspectorView.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Gallery/MediaInspectorView.swift)：
  - [x] 檔名、大小、格式、匯入日期、拍攝日期、時長、解析度
  - [x] 支援即時編輯描述（Caption）與標籤（Tags 增刪）
- [x] 全螢幕檢視彈窗 [`MediaViewerModal.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Gallery/MediaViewerModal.swift)：
  - [x] 上一張 / 下一張鍵盤快捷導覽（左右方向鍵）、Esc 鍵退出

---

### Phase 6：私人日記與 Instagram 風格圖文動態牆（Timeline & Diary System）
- [x] 日記編寫與發布視窗 [`DiaryComposerSheet.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Diary/DiaryComposerSheet.swift)：
  - [x] 自動儲存防遺失草稿引擎 [`DiaryDraftService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Storage/DiaryDraftService.swift)：切換頁面或離開視窗不掉字，支援自動恢復未存草稿與防呆提示
  - [x] 手動儲存快捷鍵（`⌘S`）與取消編輯防護確認框
  - [x] 即時字數統計（Characters）與詞數統計（Words）
  - [x] 心情選擇器（😊, ☕️, 🌟, 🏖️, 💻, 🌧️, 🌿, 🎉, ❤️, 🍕 等十多種表情選單）
  - [x] 日期時間自選器（支援補記過去的時光回憶）
  - [x] 標題與 Markdown 富文字日記內文輸入
  - [x] 附加本機相片與影片（支援自圖庫挑選與直接從 Mac 挑選匯入）
  - [x] 標籤系統（`#tag` 增刪管理）
  - [x] 收藏狀態標記
  - [x] 非破壞性解綁附件：移除日記附件時絕不刪除 Gallery 原本媒體
- [x] Instagram 風格動態卡片 [`DiaryPostCardView.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Diary/DiaryPostCardView.swift)：
  - [x] 心情徽章、標題、拍攝/發表時間、收藏愛心按鈕
  - [x] 多圖與影片輪播檢視（Carousel），附帶頁碼指示（如 `1/3`）與圓點分頁
  - [x] 點擊媒體立即叫出全螢幕多媒體檢視器
  - [x] 日記內文排版、標籤群組呈現
  - [x] 編輯與移至垃圾桶操作選單
- [x] 複合式回憶時間軸視圖 [`DiaryView.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Diary/DiaryView.swift) 與 [`TimelineDaySectionView.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Diary/TimelineDaySectionView.swift)：
  - [x] 日期篩選區間：今天（Today）、昨天（Yesterday）、本週（This Week）、本月（This Month）、自訂日期（Custom Date Picker）與全部（All）
  - [x] 檢視模式切換：全部回憶（Memories Timeline）、純日記（Diaries Only）、純多媒體（Photos & Videos）
  - [x] 每日回憶組合呈現：以垂直時間軸節點串聯當日日記、照片與影片（如 2026/11/06 一張照片、一段影片、一篇日記）
  - [x] 當日照片/影片一鍵「Write Diary with this Media」
  - [x] 頂部日期與搜尋列（搜尋標題、內文、標籤、媒體檔名）
  - [x] 心情篩選膠囊（Mood Filter Chips）
  - [x] 升序/降序排列切換
  - [x] 精緻的空狀態導航（`No memories yet`）
- [x] 首頁 [`HomeView.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/Home/HomeView.swift) 快速串接：一鍵寫日記、點擊近期回憶直接開啟檢視與編輯

---

### Phase 7：本機 Ollama AI 智慧助理抽屜（AI ← 127.0.0.1）
- [x] 本機端點通訊核心 [`OllamaService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/AI/OllamaService.swift)：
  - [x] 嚴格綁定 `127.0.0.1:11434` 本機端點，杜絕任何對外聯網
  - [x] 本機連線探測與模型探測（`GET /api/tags`，自動識別 `llama3.2`, `mistral`, `qwen2.5`, `llava` 等）
  - [x] 串流文字生成（`POST /api/chat`，`stream: true` 即時 Token 回傳）
  - [x] 私人記憶檢索上下文構建（RAG Context）：自動抽取使用者本機私密日記與相片元資料供 AI 參考
  - [x] 支援即時停止生成（Stop Generation）
- [x] 滑入式 AI 抽屜 [`AIAssistantPanelView.swift`](file:///Users/libao/Downloads/Noty/Noty/Features/AI/AIAssistantPanelView.swift)：
  - [x] 即時連線綠燈/橘燈狀態與手動重新偵測按鈕
  - [x] 本機模型切換下拉選單
  - [x] 離線友善指引橫幅（明確教學 `ollama serve` 與 `ollama run llama3.2`）
  - [x] 建議查詢標籤（搜尋記憶、總結日記、心情回顧）
  - [x] 打字機式逐字串流對話呈現與自動滾動

---

### Phase 8：鎖定、安全、More 選單、完整設定與備份系統
- [x] **1. 鎖定與安全系統（Lock 🔒）**：
  - [x] 右下角快速上鎖控制盒與全域快捷鍵 `⌘L` 立即鎖定
  - [x] 整合 Apple 原生 `LocalAuthentication` 框架支援 Touch ID、Apple Watch 與系統認證
  - [x] 整合 macOS 原生 `Security` 框架建立 [`KeychainService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Security/KeychainService.swift)，支援獨立應用程式備援鎖定密碼
  - [x] **資安鐵律落實**：絕對不將明文密碼存入 `UserDefaults` 或 `SwiftData`，全數加密儲存於 Keychain
  - [x] 自動鎖定時間管理（立即、1分鐘、5分鐘、15分鐘、30分鐘、從不），附帶背景閒置監聽器
  - [x] 精美鎖定畫面動畫：全螢幕高解析毛玻璃特效（`VisualEffectBlurView`）、Noty 向量圖標、錯誤震動反饋（Shake Animation）與明確錯誤提示
  - [x] **強制性隱私邊界宣告**：鎖定畫面上標註「注意：應用程式鎖定主要保護 Noty 的應用程式介面，不可宣稱它已經加密 Finder 中的所有媒體檔案」
- [x] **2. 更多功能選單（More Menu ⋯）**：
  - [x] Settings...（偏好設定，快捷鍵 `⌘,`）
  - [x] Open Library Folder（在 Finder 中開啟沙盒目錄）
  - [x] Export Backup...（開啟備份彈窗執行全庫/日記/媒體匯出）
  - [x] Import Backup...（開啟備份彈窗執行安全驗證還原）
  - [x] Keyboard Shortcuts（彈出原生快捷鍵指南視窗 [`KeyboardShortcutsSheet.swift`](file:///Users/libao/Downloads/Noty/Noty/Components/KeyboardShortcutsSheet.swift)）
  - [x] About Noty（關於 Noty 識別視窗）
  - [x] Quit Noty（安全退出 `NSApp.terminate(nil)`）
- [x] **3. 完整設定面板（Settings 5 大專屬板塊）**：
  - [x] **General**：Light / Dark / System 外觀切換（即時套用至 `NSApp.appearance`）、預設啟動頁面、Gallery 預設排序、流暢動畫效果開關
  - [x] **Storage**：Library 完整路徑顯示（附帶 Finder 開啟與路徑複製）、總容量與媒體/資料庫細部佔用、照片/影片/日記總量統計、一鍵清理暫存縮圖（`clearCache()`）
  - [x] **AI**：Ollama 本機端點（嚴格限制 loopback 127.0.0.1、localhost、::1）、即時連線測試按鈕與延遲回報、本機已安裝模型下拉選單、AI 功能總開關（關閉時自動隱藏 AI 側欄）
  - [x] **Privacy**：Touch ID 開關、Keychain 獨立密碼設定/變更/移除彈窗（[`SetPasscodeSheet.swift`](file:///Users/libao/Downloads/Noty/Noty/Components/SetPasscodeSheet.swift)）、自動鎖定時間排程、隱私權益宣告橫幅
  - [x] **About**：Noty 1.0.0 (Build 1) 版本資訊、Apple Silicon ARM64 原生規格、零外部第三方依賴保證（100% 原生 Swift 6 / SwiftUI / SwiftData / AVKit）
- [x] **4. 本機備份與安全還原引擎（Backup & Restore）**：
  - [x] 建立 [`BackupService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Storage/BackupService.swift) 與 [`BackupManagerModal.swift`](file:///Users/libao/Downloads/Noty/Noty/Components/BackupManagerModal.swift)
  - [x] 匯出日記：支援獨立轉存為 Markdown（帶有 YAML Frontmatter 元資料）或 JSON 結構陣列
  - [x] 匯出媒體：支援將沙盒內原始照片與影片檔完整匯出至外部資料夾
  - [x] 匯出資料庫快照：支援複製 `Noty.store`
  - [x] 建立完整全庫備份：自動封裝 `Manifest.json`、`Database/` 與 `Media/`，記錄檔案總量與備份時間戳
  - [x] 安全驗證還原：選取備份後先自動檢驗 `Manifest.json` 完整性
  - [x] **兩階段防誤觸確認**：彈出醒目警報對話框，載明備份日期與照片/影片/日記數，提示覆蓋風險
  - [x] **強制性緊急回退保護**：在執行還原前自動於 `Noty/Backups` 建立「現狀緊急快照」，杜絕任何資料損失風險，還原後發布全域通知重載資料庫
- [x] **5. 單元測試套件驗證**：
  - [x] 全套 **22/22 單元測試 100% 通過**（0 失敗，測試執行時間 0.085s）

---

### Phase 9：全面測試、檔案可靠性驗證、UI 精修與效能調校
- [x] **1. 全面功能測試（34 項端到端自動化驗證）**：
  - [x] App 啟動與核心架構常數校驗
  - [x] Gallery 日期分組、最新/最舊排序、分類篩選與多選批次操作
  - [x] 日記完整 CRUD（新增、Markdown 編輯、富文字、標籤、心情 Emoji、軟刪除、還原與清空）
  - [x] 多格式媒體匯入（PNG, JPEG, HEIC, HEIF, MOV, MP4, M4V, WEBP, GIF, TIFF）
  - [x] 大型檔案分塊串流複製（2MB Chunked 流水線，記憶體穩定低耗）
  - [x] 重複檔案處理（SHA-256 自動比對與略過策略）
  - [x] 匯入取消與異常中斷清理（自動刪除 `Library/Temp/` 暫存檔，零懸置髒資料）
  - [x] 垃圾桶工作流（軟刪除標記、過濾排除、徹底抹除磁碟實體）
  - [x] 跨維度搜尋引擎（檔名、描述、標籤、日記標題與內文）
  - [x] 收藏標記（Favorites）與動態牆即時聯動
  - [x] Ollama 本機連線探測、模型切換與多模態 Vision 識圖辨識
  - [x] AI 串流應答與立即停止生成（Stop Generation，無執行緒凍結）
  - [x] Touch ID 生物辨識與 Keychain 獨立備援密碼解鎖（0 明文洩漏）
  - [x] 本機全庫/日記/媒體備份打包與兩階段安全還原（還原前自動建立緊急安全快照）
  - [x] App 重新啟動後資料持久化（Persistent across container reload）
- [x] **2. 檔案可靠性與一致性檢驗**：
  - [x] 來源與內部副本 SHA-256 數位指紋 100% 逐位元組完全一致
  - [x] 來源檔案非破壞性保證：唯讀取流，絕不修改內容與修改日期，絕不刪除原始檔案
  - [x] SwiftData 相對路徑（`Library/Media/...`）與磁碟實體目錄絕對一致
  - [x] 異常中斷時嚴格抹除暫存檔，絕不在 SwiftData 留下半成品
- [x] **3. UI 深度優化與無障礙體驗**：
  - [x] 視窗適應：最小尺寸限制（1050×680）、支援全螢幕與動態視窗拖曳
  - [x] 佈景主題：Light Mode 與 Dark Mode 精緻對比適配
  - [x] 狀態反饋：空白狀態（手繪風格 ☹️ 空狀態卡片）、載入狀態（ProgressView 與串流指示）、錯誤狀態（Shake 動畫與清晰文字提示）
  - [x] 無障礙規格：所有導覽按鈕、Quick Upload、AI 抽屜拉柄、Lock 按鈕、設定選單皆標註 `.accessibilityLabel` 與 `.accessibilityHint`，完整適配 VoiceOver
  - [x] 減少動態效果支援（遵守系統 `accessibilityReduceMotion` 偏好）
- [x] **4. Apple Silicon M4 晶片效能調校**：
  - [x] 原生 LazyVGrid 惰性載入，杜絕大圖一次進記憶體
  - [x] 縮圖快取引擎（`ThumbnailService`）記憶體 100MB 上限與按需非同步生成
  - [x] 大圖檢視器（`InteractiveZoomImageView`）約束最大解碼像素於 4K 視窗上限（3840px），大幅降低解碼峰值記憶體
  - [x] AVPlayer 生命週期嚴格管理（`teardownPlayer()` 與 `dismantleNSView` 主動釋放資源）
  - [x] 檔案處理與雜湊運算全數隔離於背景 `Task.detached(priority: .userInitiated)`，主執行緒 ProMotion 120fps 流暢不卡頓
- [x] **5. 測試報告產出**：
  - [x] 生成標準化 [`TEST_REPORT.md`](file:///Users/libao/Downloads/Noty/TEST_REPORT.md)，詳細記錄 34 項已通過測試、曾調試問題、已修復項目與已知環境限制

---

### Phase 9.5：進階功能與產品完善 (Noty Advanced Features & Product Polish)
- [x] **1. Smart Gallery & 自訂相簿**
  - [x] 智慧分類相簿（All Memories, Photos, Videos, Favorites, Recently Added, Recently Viewed, This Month, This Year, Unsorted）
  - [x] 自訂相簿系統（`Album` 模型、建立/重新命名/刪除相簿不傷實體、封面設定、加入/移除媒體、多相簿歸屬）
  - [x] 批次管理工作流（批次收藏/取消、加入相簿、標籤管理、批次匯出、批次移入垃圾桶附二次防護）
- [x] **2. Advanced Search 全域進階搜尋**
  - [x] 多維度篩選器（媒體類型、日期範圍、檔案格式、標籤、相簿、檔案大小、影片長度）
  - [x] 即時反饋、本機搜尋歷史紀錄（支援清除）、結果數量與無結果引導
- [x] **3. Memory Timeline & Calendar View 日曆時間軸**
  - [x] 原生 macOS 日曆視圖（月/年檢視、今日快捷、月份導航、日期縮圖指示標記、當日內容面板）
  - [x] 整合式回憶動態牆（照片、影片、日記、收藏跨維度組合時間軸）
  - [x] 拍攝日期校正（EXIF 日期解析、時區調整、手動校正拍攝日期）
- [x] **4. Media Intelligence 媒體資訊強化**
  - [x] EXIF 深度讀取（相機型號、鏡頭、ISO、光圈、快門、焦距、本機隱私 GPS 座標顯示）
  - [x] 影片元資料（解析度、幀率、Codec、音訊軌道數、時長）
  - [x] 升級版 Media Inspector 側欄面板
  - [x] 原生 Quick Look 支援（空白鍵快速預覽）
- [x] **5. Duplicate Detection 重複檔案與相似照片管理**
  - [x] 100% 相同檔案偵測（SHA-256 跨檔名精準比對）
  - [x] 相似照片演算法（Perceptual Hash / dHash 感知雜湊與 Hamming 距離比對）
  - [x] 重複管理彈窗（分組對比、相似度百分比、手動保留/刪除，禁止自動刪除）
- [x] **6. Advanced Diary 日記進階功能**
  - [x] 格式化工具列（粗體、斜體、標題、無序/有序列表、引言、分隔線、即時字數統計）
  - [x] 內建日記模板（Daily Journal, Travel Journal, Study Notes, Weekly/Monthly Review, Free Writing）及自訂模板
  - [x] 7 大心情狀態標記（Happy, Excited, Relaxed, Sad, Tired, Stressed, Neutral）
  - [x] 防失誤自動儲存強化（1.5s Debounce、狀態指示燈、異常中斷草稿恢復機制）
- [x] **7. Local AI 記憶助理進階擴充**
  - [x] 本地記憶捷徑（總結本月、總結本週、尋找相關回憶、整理日記、產生建議標籤、生成日記草稿）
  - [x] 相關回憶檢索（依標籤與日期關聯）
  - [x] AI 標籤建議（需使用者確認方可套用）
  - [x] AI 權限與隱私控制（Context Control：日記內文、媒體描述、標籤存取許可）
  - [x] 離線與錯誤處理強化（逾時處理、非 Vision 模型防禦）
- [x] **8. Advanced Import & Export 資料夾與進階匯入匯出**
  - [x] 資料夾遞迴匯入與預檢清單（檔案數、大小、格式支援、重複項預先篩選）
  - [x] 中斷恢復機制（啟動時自動清理 `Temp/` 懸置檔案）
  - [x] 多元匯出（單檔、多選批次、相簿整批匯出、日記 Markdown/JSON 匯出）
  - [x] 備份還原完整性驗證（SHA-256 清單校驗）
- [x] **9. Data Integrity 資料庫健康檢查與修復工具**
  - [x] 10 項全庫診斷（檔案遺失、孤立媒體、縮圖遺失/損毀、SHA-256 不符、無效路徑、暫存殘留、日記/相簿關聯斷鏈、垃圾桶一致性）
  - [x] 視覺化診斷報告與安全修復工具（重新生成縮圖、救援孤立檔案、清理暫存）
- [x] **10. macOS Native Experience 系統整合與細節調校**
  - [x] 全域鍵盤快捷鍵（⌘N, ⌘O, ⌘U, ⌘F, ⌘S, ⌘,, ⌘⇧L, Space, Esc）
  - [x] macOS 原生 Menu Bar 選單完整建置（Noty, File, Edit, View, Window, Help）
  - [x] 輕量 Menu Bar 快速日記入口（可於設定開啟/關閉）
- [x] **11. UX Details, Loading, Toast & Localization**
  - [x] 全頁面空白狀態、載入狀態、錯誤狀態標準化
  - [x] 輕量 Toast 操作回饋系統（收藏、匯出、儲存通知）
  - [x] 繁體中文與英文在地化基礎架構
- [x] **12. Automated Tests & ADVANCED_FEATURES_REPORT.md**
  - [x] 擴充單元與整合測試（40/40 測試通過）
  - [x] 產出最終 Phase 9.5 報告與 Phase 10 打包前檢查清單

---

### Phase 9.75：終極精雕、密碼安全、Liquid Glass 與本機 AI 深度整合 (Phase 9.75 Acceptance)
- [x] **1. 品牌重塑 — 全新 Noty Logo（嚴格保留左下角英文字母大寫「L」）**
  - [x] 忠實解析最新手繪設計稿（`media_1794052396103_a3951c65.jpg`）
  - [x] 建立向量 `NotyLogoView.swift`，包含圓角便簽外框、頂部飾線、底部飾線、中央粗體 N 與兩側雙層橫劃線
  - [x] **原創元素保護**：左下角大寫字母「L」獨立清晰，絕不修飾為筆尖、水滴或破損線
  - [x] 更新 `BrandHeaderView.swift`、`AboutNotyView.swift`
  - [x] 升級 `scripts/generate_app_icon.swift`，產生 16×16 至 1024×1024 全套 AppIcon 資源
- [x] **2. AES-256-GCM 真實本機保險庫加密引擎**
  - [x] Apple 原生 CryptoKit AES-256-GCM 認證加密
  - [x] 600,000 次 PBKDF2-HMAC-SHA256 金鑰推導，結合 32 位元組隨機 Salt
  - [x] 4 MiB 分塊串流加密/解密管線，唯一單調遞增 Nonce，杜絕重用
  - [x] 建立 `.notyvault` 專屬二進位容器格式（`NOTYVLT1`、版本、Salt、分塊數、檔案大小、認證標籤）
  - [x] 防竄改、防掉包、防截斷、防順序置換檢驗
  - [x] SwiftData 欄位級敏感資訊認證加密（未解鎖時呈現安全遮罩）
  - [x] 全庫非破壞性安全遷移（強制事前備份、SHA-256 雙向比對）
- [x] **3. 原創 LFES-12122 對稱轉換演算法整合**
  - [x] 文本 = 1，密碼 = 2，C = Copy，+ = 密碼數字輪流插入
  - [x] 7 組原始測試向量（0C, 1C, 1C1+, 2C, 2C2+, 3C, 3C3+）100% 吻合
  - [x] 6 步逆向可逆解密流程精準還原至 `"1"`
  - [x] 密碼數字循環取用機制（如密碼 123 取 4 位為 1231）
  - [x] 泛化未定義 Unicode 數據如實標註為 `Specification Incomplete`，絕不擅自捏造代數
  - [x] UI 標註為 `Experimental Custom Layer`，AES-256 保持為主力安全防線
- [x] **4. 全域 Apple Liquid Glass 視覺系統升級**
  - [x] 建立 `NotyDesignSystem.swift`（材質、膠囊 Capsule、柔光 Glow、微彈簧動畫）
  - [x] 所有按鈕、搜尋欄、標籤晶片、篩選分段器全面膠囊化
  - [x] Reduce Motion 減弱動態無障礙偏好適配
- [x] **5. 外觀主題切換 Bug 徹底修復**
  - [x] 建立 `AppearanceManager.swift`
  - [x] Light -> `.light` (`.aqua`)、Dark -> `.dark` (`.darkAqua`)
  - [x] System -> **`nil`**（即時徹底釋放 Dark 覆寫，跟隨 macOS 動態響應）
- [x] **6. 全域文字重疊與版面根治**
  - [x] Gallery 分類擠壓修復：改採橫向滾動 Liquid Capsule Filter Bar
  - [x] Media Inspector 側欄標籤擠壓修復：加入 `.layoutPriority(1)` 與中端截斷
  - [x] Diary 時間軸頂部橫向溢出修復：兩行式空間重構
  - [x] Calendar 當日面板彈性適配（260～350 pt）
  - [x] 驗證 1050×680 至全螢幕無重疊、無裁切
- [x] **7. 動態上傳簽名級交互**
  - [x] 右上角大型流體圓弧玻璃造型（`FluidUploadWedgeShape`），左上方延伸且保留品牌 Logo 清晰可點
  - [x] 全視窗拖放展開偵測（`DynamicFullWindowDropZone`），平滑 Liquid Glass 展開與自然縮回
  - [x] 上傳期間動態進度儀表（`DynamicUploadArcView`）：流光圓弧環、多檔案佇列計數（如 12/30 Files）、即時百分比
- [x] **8. 本機 Ollama AI 深度整合與隱私屏障**
  - [x] 純本機迴路白名單（`127.0.0.1:11434` / `localhost`）
  - [x] 真實 `/api/tags` 模型動態探測，真實 `/api/chat` 行串流應答
  - [x] 實體 Stop Generation 立即中斷機制
  - [x] 本機 Grounded RAG 實體記憶檢索，強制依據本機事實回答
  - [x] **保險庫硬性隱私屏障**：保險庫鎖定期間，完全阻絕 AI 存取私人日記與媒體
- [x] **9. 安全與加密儀表板 UI**
  - [x] Settings 專屬 Security 分頁
  - [x] 顯示 Vault Status、AES-256-GCM、LFES-12122、Keychain 與 Touch ID 狀態
  - [x] 主密碼設定、鎖定/解鎖操作、全庫遷移按鈕
  - [x] 內建 LFES-12122 規格檢驗套件執行器
- [x] **10. 自動化測試擴充與 15 份規格文件**
  - [x] 全套 **53/53 自動化測試 100% 通過**（0 失敗，耗時 0.458s）
  - [x] 產出全部 15 份標準化工程報告與規格文件

---

### Phase 9.875：長期可靠性、全專案 Liquid Glass 深度審計與終極最佳化 (Phase 9.875 Acceptance)
- [x] **1. 全專案深度稽核與優先級分類 (Part 0)**
  - [x] 審查所有專案規格與原始碼，分類 P0/P1/P2/P3
  - [x] 產出 [`PHASE_9_875_AUDIT.md`](file:///Users/libao/Downloads/Noty/PHASE_9_875_AUDIT.md)
- [x] **2. 全專案 Liquid Glass 按鈕深度審計 (Part 1)**
  - [x] 建立統一按鈕樣式 [`NotyButtonStyle.swift`](file:///Users/libao/Downloads/Noty/Noty/Core/NotyButtonStyle.swift)
  - [x] 建立統一玻璃元件 [`NotyGlassComponents.swift`](file:///Users/libao/Downloads/Noty/Noty/Core/NotyGlassComponents.swift)
  - [x] 升級 [`NotyDesignSystem.swift`](file:///Users/libao/Downloads/Noty/Noty/Core/NotyDesignSystem.swift)
  - [x] 審查全專案 210 個按鈕，全面套用 Apple 原生 Liquid Glass 與膠囊控制
  - [x] 堅守「內容純淨原則」與「單層玻璃原則」，杜絕過度玻璃化
  - [x] 產出 [`LIQUID_GLASS_AUDIT.md`](file:///Users/libao/Downloads/Noty/LIQUID_GLASS_AUDIT.md)
- [x] **3. 全面代碼 Bug 獵捕與修復 (Part 2)**
  - [x] 修復 `CustomVideoPlayerView` 通知觀察者洩漏
  - [x] 消除 `DuplicateDetectionService` 強制解包
  - [x] 修復 `NotyTests` 保險庫狀態殘留
  - [x] 驗證無空動作按鈕與虛假成功回饋
  - [x] 產出 [`BUG_AUDIT_REPORT.md`](file:///Users/libao/Downloads/Noty/BUG_AUDIT_REPORT.md)
- [x] **4. 長期回憶保護與防誤刪 (Part 3)**
  - [x] `MediaItem` 與 `DiaryEntry` 新增 `isImportant` 與 `isProtected` 屬性
  - [x] 卡片金星與盾牌徽章標記
  - [x] Gallery `Important` 膠囊篩選
  - [x] 批次刪除自動跳過受保護項目
  - [x] 實作移入垃圾桶 Undo 撤銷機制
- [x] **5. 備份輪替與隔離沙盒災難復原 (Part 4)**
  - [x] 建立 6 種備份配置（Full, Incremental, Database, Media, Diaries, Encrypted Archive）
  - [x] 實作備份版本輪替（保留 3/5/10 份），前置驗證通過才修剪
  - [x] 備份包含逐檔 SHA-256 清單（`Manifest.json`）
  - [x] 隔離沙盒災難復原測試，零破壞正式資料庫
  - [x] 產出 [`BACKUP_RECOVERY_REPORT.md`](file:///Users/libao/Downloads/Noty/BACKUP_RECOVERY_REPORT.md)
- [x] **6. 開放式可攜回憶封裝庫 `NotyArchive/` (Part 5)**
  - [x] 實作 [`MemoryArchiveService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Storage/MemoryArchiveService.swift)
  - [x] 支援開放式結構、JSON Schema、Markdown 日記、多媒體與校驗碼
  - [x] 產出 [`MEMORY_ARCHIVE_SPEC.md`](file:///Users/libao/Downloads/Noty/MEMORY_ARCHIVE_SPEC.md)
- [x] **7. 持久化匯入佇列與異常恢復 (Part 6)**
  - [x] 實作 [`ImportQueueService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Import/ImportQueueService.swift)
  - [x] 磁碟持久化 `import_queue.json` 狀態機
  - [x] 程式重啟自動回滾中斷任務並排空孤立暫存
  - [x] 匯入前 1.5 倍磁碟剩餘空間前置預檢
  - [x] 遺失檔案手動 Locate / Relink 功能
  - [x] 產出 [`IMPORT_RECOVERY_REPORT.md`](file:///Users/libao/Downloads/Noty/IMPORT_RECOVERY_REPORT.md)
- [x] **8. 今日回憶時光機 (On This Day Time Machine) (Part 7)**
  - [x] 實作 [`OnThisDayService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Storage/OnThisDayService.swift)
  - [x] 依本機時區檢索 1/2/3/5+ 年前同日回憶
  - [x] 實作 [`OnThisDayCardView.swift`](file:///Users/libao/Downloads/Noty/Noty/Components/OnThisDayCardView.swift) 呈現於 HomeView
- [x] **9. 日記版本歷史與草稿復原 (Part 8)**
  - [x] 實作 [`DiaryVersionService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Storage/DiaryVersionService.swift)
  - [x] 每次修改儲存自動快照與去重
  - [x] 開啟編輯器主動提示未存草稿復原
- [x] **10. 儲存健康儀表板與安全修復 (Part 9)**
  - [x] 儲存分佈容量計算（Photos, Videos, DB, Thumbs, Backups, Temp, Free Disk）
  - [x] 安全自我修復（一鍵重建縮圖、清理暫存、無效指標修剪）
  - [x] 產出 [`STORAGE_HEALTH_REPORT.md`](file:///Users/libao/Downloads/Noty/STORAGE_HEALTH_REPORT.md)
- [x] **11. 動態智慧相簿與關聯推薦 (Part 10)**
  - [x] 實作 [`SmartMemoryService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Storage/SmartMemoryService.swift)
  - [x] 動態過濾大型影片 (>100MB)、無日記照片、未整理項目
  - [x] 本機關聯回憶打分推薦演算法
- [x] **12. 本機 Ollama AI 深度品質審計 (Part 11)**
  - [x] 嚴格迴路白名單、SSE 串流、Grounding RAG 實體數據注入防偽
  - [x] 保險庫鎖定硬性隱私屏障
  - [x] 產出 [`AI_QUALITY_REPORT.md`](file:///Users/libao/Downloads/Noty/AI_QUALITY_REPORT.md)
- [x] **13. 長期效能優化 (Part 12)**
  - [x] 4 MiB 串流分塊加密、縮圖記憶體快取上限（120MB）、LazyVGrid 動態載入
  - [x] 產出 [`PERFORMANCE_REPORT.md`](file:///Users/libao/Downloads/Noty/PERFORMANCE_REPORT.md)
- [x] **14. 無障礙與長期易用性 (Part 13)**
  - [x] Reduce Motion 自動關閉彈簧縮放、Reduce Transparency 高對比平滑適配
  - [x] 產出 [`ACCESSIBILITY_REPORT.md`](file:///Users/libao/Downloads/Noty/ACCESSIBILITY_REPORT.md)
- [x] **15. 資料遷移與前向相容規範 (Part 14)**
  - [x] 確立 SwiftData、NOTYVLT1、LFES-12122、備份與封裝庫版本
  - [x] 產出 [`DATA_MIGRATION_REPORT.md`](file:///Users/libao/Downloads/Noty/DATA_MIGRATION_REPORT.md)
- [x] **16. 全域迴歸與高乘載壓力測試 (Part 15)**
  - [x] 500+ 照片、50+ 4K 影片、200+ 日記隔離沙盒高乘載壓力測試（耗時 0.128s）
  - [x] 全套 **63/63 自動化測試 100% 通過**（0 失敗，耗時 0.681s）
  - [x] 產出 [`TEST_REPORT.md`](file:///Users/libao/Downloads/Noty/TEST_REPORT.md) 與 [`PHASE_9_875_REPORT.md`](file:///Users/libao/Downloads/Noty/PHASE_9_875_REPORT.md)
