# Noty — 專案規格書 (PROJECT_SPEC.md)

> **版本**：1.0.0  
> **更新日期**：2026-11-06  
> **系統架構定位**：Native macOS Private Media & Diary Application (Apple Silicon Only)

---

## 1. 專案願景與核心定位

**Noty** 是一款專為 macOS 設計的本機私密媒體庫與日記應用程式。它融合了類似 Instagram 的視覺化圖文瀏覽體驗，但**完全運行於使用者的本機 Mac** 上。

### 1.1 核心哲學
- **極致隱私（100% Local & Private）**：不架設外部伺服器、不建立社群網絡、無帳號系統、無雲端同步、無任何第三方追蹤分析。
- **純原生體驗（True Native macOS）**：以 Swift、SwiftUI、SwiftData 與 AVKit/AVFoundation 打造，完全融入 macOS 設計語彙（Human Interface Guidelines），效能輕快、記憶體精簡。
- **邊緣智慧（Edge AI with Ollama）**：AI 能力全數交由本機運行的 Ollama 處理（限縮於 `127.0.0.1` / `localhost`），保障私人日記與照片絕對不外洩。

---

## 2. 品牌與視覺識別規範（Immutable Brand Rules）

### 2.1 品牌名稱
- **應用程式法定名稱**：`Noty`（不可更動大小寫組合與拼法，嚴禁替換為其他名稱）。

### 2.2 品牌識別區（Brand Header）
- **位置**：左側導覽列最上方（Top-Left），永久固定置頂。
- **內容**：
  1. **Noty 品牌圖示**：依據原創手繪稿設計——方形記事紙外觀、中央大寫「N」、筆記橫線條紋飾，以及右下/左下微折或對話框尾巴（象徵「記事」與「個人心聲紀錄」）。
  2. **Noty 字樣**：原生字體排印（SF Pro Rounded / Heavy），不可在後續 UI 迭代中被刪除、摺疊隱藏、移動至其他角落或替換為通訊圖標。

### 2.3 手繪原型對照與 UI 區域劃分
依據設計手繪稿，整體 macOS 視窗劃分為三大主軸與五大功能核心區：

```
+-------------------------------------------------------------------------------+
| [ N ] Noty        |  You are now at: gallery [🖼️]             [ ↑ Quick Upload ]|
|-------------------+-----------------------------------------------------------|
| [🏠 Gallery    *] |  2026/11/6 (五)                       [↑] [↓] [🔍 Filter] |
| [📰 Timeline   ] | +-------------------------------------------------------+ |
| [⬆️ Upload     ] | |                                                       | |
| [••• More      ] | |                   Nothing here...                     | |
|                   | |                  try [ ↑ upload ]                     |A|
|                   | |                     [ open file... ]                  |I|
|                   | |                                                       |←|
|                   | |                                                       | |
|                   | +-------------------------------------------------------+ |
| [⚙️ Settings   ] |                                                [•••] [🔒] |
+-------------------------------------------------------------------------------+
```

1. **左側側邊導覽列（Sidebar）**：
   - 頂部：固定品牌識別區（`[N] Noty`）。
   - 中部：功能分頁項目（Gallery 相簿、Timeline 時間軸貼文、Upload 上傳、More 更多）。
   - 底部：設定按鈕（Settings ⚙️）。
2. **中央主要內容區（Main Canvas）**：
   - 頂部導航指示：動態顯示當前視圖（如 `You are now at gallery` 與圖示）。
   - 日期與控制列：顯示日期（如 `2026/11/6 (五)`）、排序切換（升冪/降冪 `↑` `↓`）、篩選/搜尋按鈕。
   - 內容主容器：空狀態時提供直覺的「Upload」與「Open file...」按鈕；有內容時以高效瀑布流/格狀檢視呈現照片與影片。
3. **右側功能錨點（Right Rail & Overlays）**：
   - 右上角：`Quick upload` 快速匯入按鈕。
   - 右側垂直居中：`AI ←` 側邊智慧助理抽屜拉柄，點擊展開本地 Ollama 語意搜尋與分析面板。
   - 右下角：`Lock 🔒`（應用程式即時上鎖/Touch ID 解鎖）與 `More •••` 快捷選單。

---

## 3. 功能規格（Functional Specifications）

### 3.1 媒體匯入與管理（Media Management）
- **支援格式**：
  - 圖片：JPEG, PNG, HEIC, WebP, GIF, TIFF。
  - 影片：MP4, MOV, M4V（透過 AVKit 原生解碼播放）。
- **匯入方式**：
  - 支援點擊按鈕開啟 macOS 原生 `NSOpenPanel`。
  - 支援將檔案或資料夾直接拖曳（Drag & Drop）進視窗。
- **儲存原則**：
  - 非破壞性儲存：匯入時將媒體複製至 Noty 本機 Sandboxed 儲存庫，**嚴格禁止刪除或移動使用者的原始檔案**。
  - 媒體去重：匯入時計算 SHA-256 雜湊值，避免重複匯入相同檔案佔用硬碟空間。
  - 快取管理：自動非同步產生並快取多尺寸縮圖（Thumbnail），保障千張以上媒體流暢滾動。

### 3.2 日記與貼文系統（Diary & Post Engine）
- **貼文型態**：
  - 純文字日記（Daily Notes）。
  - 單圖/多圖貼文（類似 Instagram 照片輪播）。
  - 短片/影片日記（附帶內嵌原生播放控制器）。
- **屬性標籤**：
  - 建立時間（Timestamp，支援依真實拍攝 Exif 或手動指定調整）。
  - 心情狀態（Mood）、地理位置文字（非聯網定位）、標籤分類（Tags）。
  - 富文字 Markdown 格式日記本文。

### 3.3 本機 Ollama AI 整合（Local Ollama AI Integration）
- **端點白名單**：僅限 `http://127.0.0.1:11434` 或 `http://localhost:11434`。
- **核心功能**：
  1. **本機模型自動探測**：透過 `/api/tags` 檢查 Ollama 是否運行，並列出可用的本機模型（如 `llama3.2`、`llava`、`qwen2.5` 等）。
  2. **私密相片與日記語意搜尋**：以自然語言輸入「去年夏天在海邊的照片」或「開心的露營回憶」，比對日記內文與本機生成的圖片特徵。
  3. **自動視覺打標（Vision Tagging，需搭配視覺模型）**：本機端分析照片內容，自動補充描述標籤，全程不離線。
  4. **日記回顧摘要**：生成週報或月度記憶精選，所有推論皆在 Apple Silicon NPU / GPU 上執行。

### 3.4 隱私安全防護（Privacy & App Lock）
- **本機保險庫上鎖（Vault Lock）**：
  - 支援點擊右下角 `Lock 🔒` 按鈕立即隱藏內容並鎖定介面。
  - 支援 macOS 原生 Touch ID 或本機密碼解鎖（基於 `LocalAuthentication` 框架）。
  - 逾時自動上鎖（自訂閒置時間）。

---

## 4. 非功能性需求與邊界規範（Non-Functional Requirements）

| 項目 | 規範標準 | 理由 |
| :--- | :--- | :--- |
| **目標平台** | macOS 14.0+ (Sonoma) / macOS 15.0+ (Sequoia) / Apple Silicon (ARM64) | 充分發揮 Metal, Apple Neural Engine, SwiftData 效能 |
| **開發語言** | Swift 6.0+（啟用現代並發 Swift Concurrency `async/await`） | 記憶體安全、高效非同步任務 |
| **UI 框架** | 100% 原生 SwiftUI | 原生外觀與動態手勢，無 Web 容器負擔 |
| **本機資料庫** | SwiftData (`@Model`) | 現代化原生持久化，與 SwiftUI 無縫響應 |
| **多媒體引擎** | AVKit / AVFoundation / ImageIO / QuickLookThumbnailing | 原生硬體加速解碼，不耗費額外 CPU |
| **第三方依賴** | 嚴格最小化，原則上 0 第三方套件（零 CocoaPods / 不濫用 SPM） | 杜絕供應鏈漏洞與雲端外洩風險 |
| **網路權限** | 僅允許本機環回連線（Localhost Loopback for Ollama） | 系統層級防堵隱私外洩 |
| **啟動效能** | 冷啟動時間 < 0.6 秒，記憶體基準佔用 < 80MB | 保障輕盈且常駐的私人筆記體驗 |
