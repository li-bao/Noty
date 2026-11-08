# Noty — 私人本機回憶管理與日記系統 (Native macOS Application)

<p align="center">
  <b>純本機、零雲端、極致私密的 Apple Liquid Glass 私人回憶資料庫</b><br>
  <i>專為 Apple Silicon Mac 打造的原生 Swift / SwiftUI / SwiftData 應用程式</i>
</p>

---

## 📌 關於 Noty

Noty 是一款專為長期保存個人珍貴照片、影片、生活隨筆與日記而設計的原生 macOS 應用程式。
我們堅持**極致隱私與數據自主**原則：無雲端伺服器、無帳號註冊、無追蹤分析代碼，所有檔案皆留在您的 Mac 上。

---

## 🚀 1. 如何安裝 (Installation)

### 方式 A：透過 DMG 映像檔安裝（推薦）
1. 至 `dist/` 目錄取得 `Noty-arm64.dmg`。
2. 雙擊掛載 `Noty-arm64.dmg`。
3. 將映像檔內的 **Noty.app** 拖曳至 **Applications**（應用程式）捷徑。
4. 退出（Eject）映像檔即可完成安裝。

### 方式 B：自行從原始碼編譯
```bash
./scripts/build_release_dmg.sh
```
編譯產物將直接輸出於 `dist/Noty.app` 與 `dist/Noty-arm64.dmg`。

---

## 🖥️ 2. 如何啟動 (Launch & First Run)

1. 開啟 Finder，進入「應用程式」（Applications），點擊 **Noty** 啟動。
2. **首次啟動提示處理**：
   * 由於本版本為本機自編譯/Ad-Hoc 簽名版本（未包含 Apple 官方年費 Notarization 公證），macOS Gatekeeper 可能彈出安全提示。
   * 請對著 `Noty.app` 按 **右鍵（Control + 點擊）**，選擇 **「打開」(Open)**，並在確認對話框中點擊「打開」即可。
   * 或至 macOS「系統設定」>「隱私權與安全性」點擊「仍要打開」。

---

## 📖 3. 如何使用 (Usage Guide)

### A. 圖庫管理 (Gallery)
* **媒體瀏覽**：以自適應 Lazy Grid 呈現所有照片與影片縮圖，支援按日期分組（今天、昨天、本月等）。
* **排序與篩選**：支援「最新優先」與「最舊優先」排序，並可依「照片」、「影片」、「收藏」進行即時過濾。
* **水平滾輪滑動**：頂部分類列完全支援**滑鼠滾輪直接左右水平滾動**，無繁瑣箭頭干擾。
* **照片大圖預覽**：點擊照片進入大型預覽，支援放大、縮小、拖曳檢視與 EXIF 詳細資訊面板。
* **影片原生播放器**：整合 AVKit / AVPlayer 硬體加速播放，支援全螢幕、音量調節、鍵盤快速鍵與進度拖曳。

### B. 私人日記 (Diary & Memories Timeline)
* **時間軸檢視**：支援「Memories（圖文整合）」、「Diaries（純日記）」、「Photos & Videos（純媒體）」三種模式。
* **新增與編輯**：點擊右上角「Write Diary」開啟編輯器，支援撰寫標題、正文、選擇心情 Emoji（😊 ☕️ 🌟 🏖️ 💻 🌧️ 🌿 🎉 ❤️）與關聯 Gallery 媒體。
* **自動草稿防遺失**：內建自動儲存機制，切換頁面文字永不遺失。
* **非破壞性關聯**：移除日記附件或刪除日記，**絕對不會誤刪 Gallery 原生照片與影片**。

### C. 垃圾桶與誤刪保護 (Trash)
* 刪除的照片與日記皆先移入「Trash」，可隨時單筆或批次還原；只有點擊「Empty Trash」時才會永久抹除。

### D. 快速鍵支援 (Keyboard Shortcuts)
* `⌘ 1` ～ `⌘ 5`：快速切換 Home、Gallery、Diary、Calendar、Albums
* `⌘ N`：新增日記
* `⌘ U`：匯入媒體
* `⌘ F`：全域搜尋
* `⌘ K`：開關 AI 助理
* `⌘ ⇧ L`：立即鎖定保險庫

---

## 📂 4. 媒體與資料儲存位置 (Storage Locations)

Noty 嚴格將所有資料儲存在標準 macOS 本機沙盒目錄中：

```
~/Library/Application Support/Noty/
├── Database/
│   └── Noty.store           # SwiftData 本機 SQLite 資料庫
├── Library/
│   ├── Media/
│   │   ├── Images/          # 匯入的照片副本 (以 SHA-256 數位指紋命名)
│   │   └── Videos/          # 匯入的影片副本
│   ├── Thumbnails/          # ImageIO / AVAsset 高效縮圖快取
│   └── Temp/                # 串流匯入與分塊複製暫存區
└── Backups/                 # 自動與手動建立的回憶備份壓縮包
```
> [!NOTE]
> 匯入照片與影片時，Noty 採用**絕對安全副本原則**：原始硬碟中的檔案永遠保持唯讀，絕不會被修改、移動或刪除。

---

## 🤖 5. 如何連接本機 Ollama AI (Ollama Integration)

Noty 側邊欄整合了 100% 離線的本機邊緣 AI，無須聯網、不上傳資料：

1. **安裝 Ollama**：至 [https://ollama.com](https://ollama.com) 下載並安裝。
2. **下載模型**（推薦）：
   ```bash
   ollama pull qwen3.5:9b
   # 或
   ollama pull gemma4:e4b
   # 或
   ollama pull llama3.2
   ```
3. **啟動 Ollama 服務**：
   ```bash
   ollama serve
   ```
4. **Noty 自動對接**：
   * 點擊 Noty 右側「AI」按鈕開啟面板。
   * Noty 自動檢測 `http://127.0.0.1:11434` 本機端點，並列出已安裝模型。
   * **安全性保證**：Noty 內建迴路白名單防護，拒絕任何外部網址，全面保護個人回憶私密性。

---

## 💾 6. 如何備份與還原資料 (Backup & Restore)

### A. 完整封裝匯出 (Full Backup Export)
1. 點擊側邊欄「More...」或右下角工具列進入「Settings」>「Storage」或選單。
2. 選擇「Export Backup」匯出 `.notybackup` 封裝包。
3. 封裝包內含完整資料庫快照、所有照片影片、縮圖以及附帶 SHA-256 數位簽章的 `manifest.json`。

### B. 災難復原 (Restore)
1. 選擇「Import Backup」並選取欲還原的備份包。
2. Noty 將於隔離沙盒中預檢校驗，確認校驗碼正確後才進行復原，並自動保留目前資料庫的 Safety Snapshot。

---

## ⚠️ 7. 已知限制 (Known Limitations)

1. **架構專用性**：Noty 專為 **Apple Silicon ARM64**（M1/M2/M3/M4 系列晶片）設計，最低作業系統版本為 **macOS 14.0 (Sonoma)**。不提供亦不支援 Intel x86_64 舊架構。
2. **本機 AI 端點限制**：出於隱私合規，AI 通訊端點嚴格鎖定於迴路位址（`127.0.0.1`、`localhost`、`::1`），無法連接遠端私有雲或公網 API。
3. **應用程式鎖定範疇**：右下角「Lock」按鈕可透過 Touch ID / 密碼鎖定 Noty 介面與資料庫檢視；如需保護磁碟上的實體檔案，建議搭配 macOS 系統內建之 FileVault 全碟加密。

---

## 📦 8. Release 交付檔案清單

- **DMG 安裝映像檔**：[dist/Noty-arm64.dmg](file:///Users/libao/Downloads/Noty/dist/Noty-arm64.dmg)
- **獨立應用程式本體**：[dist/Noty.app](file:///Users/libao/Downloads/Noty/dist/Noty.app)
- **建置與打包腳本**：[scripts/build_release_dmg.sh](file:///Users/libao/Downloads/Noty/scripts/build_release_dmg.sh)
- **編譯指南文件**：[BUILD_INSTRUCTIONS.md](file:///Users/libao/Downloads/Noty/BUILD_INSTRUCTIONS.md)
- **全套測試與驗收報告**：[TEST_REPORT.md](file:///Users/libao/Downloads/Noty/TEST_REPORT.md)
- **系統架構設計規格**：[ARCHITECTURE.md](file:///Users/libao/Downloads/Noty/ARCHITECTURE.md)
