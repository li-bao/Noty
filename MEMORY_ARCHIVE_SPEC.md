# Noty Portable Memory Archive Specification (MEMORY_ARCHIVE_SPEC.md)
**Specification Version**: 1.0.0  
**Date**: 2026-11-07  
**Guiding Principle**: "Decades-Proof Private Preservation" — My memories stay mine forever.

---

## 1. 宗旨與架構理念

Noty 堅信：**使用者儲存於應用程式中的私人照片、影片、日記與相簿關聯，絕不能被私有二進位資料庫永久綁定。**

`NotyArchive` 是一個公開、自包含、支援跨平台與跨時代讀取的開放式資料夾架構：
- **零專有鎖定 (Zero Vendor Lock-in)**：即使 20 年後 SwiftData 或 macOS 淘汰，任何人只要擁有基本的檔案瀏覽器與 JSON 解析器，即可完整閱讀與導航所有記憶。
- **雙軌保存 (Dual-Format Journaling)**：日記同時保存為標準結構化 `diaries.json` 與帶有 YAML Front Matter 的通用 `Markdown (.md)` 檔案。
- **逐檔雜湊防竄改 (SHA-256 Checksums)**：提供完整的 `sha256.txt` 雜湊比對清單，供未來校驗磁區老化或損壞。

---

## 2. 目錄階層架構 (Directory Structure)

```text
NotyArchive_2026-11-07T12-00-00Z/
├── manifest.json                  # 封裝庫全域中介資訊與規範版本
├── metadata/                      # 結構化關係資料庫 (JSON)
│   ├── media.json                 # 所有照片與影片中繼資料
│   ├── diaries.json               # 所有日記全文、時間與附件關聯
│   ├── albums.json                # 自訂相簿分類結構
│   └── tags.json                  # 全域標籤清單
├── media/                         # 原始二進位媒體實體
│   ├── Images/                    # 照片（JPG, PNG, HEIC, TIFF, WebP, GIF...）
│   └── Videos/                    # 影片（MP4, MOV, M4V...）
├── diaries/                       # 人類可直接預覽的 Markdown 日記檔案
│   ├── 2026-08-15_京都旅行.md
│   └── 2026-11-06_雨夜散步.md
└── checksums/                     # 完整性驗證資訊
    └── sha256.txt                 # 所有檔案之 SHA-256 數位指紋
```

---

## 3. JSON Schema 規格定義

### 3.1 `manifest.json`
```json
{
  "archiveVersion": "1.0.0",
  "appName": "Noty",
  "createdAt": "2026-11-07T12:00:00Z",
  "totalPhotos": 1420,
  "totalVideos": 68,
  "totalDiaries": 315,
  "totalAlbums": 12,
  "isEncrypted": false,
  "notes": "Portable standalone memory archive. Designed for decades of private preservation."
}
```

### 3.2 `metadata/media.json` (片段)
```json
[
  {
    "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
    "originalFileName": "sunset_beach.heic",
    "mediaType": "image",
    "fileFormat": "heic",
    "fileSizeBytes": 3450120,
    "sha256": "4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a",
    "capturedAt": "2026-07-20T18:45:00Z",
    "importedAt": "2026-07-21T09:12:00Z",
    "caption": "黃金海岸的傍晚日落",
    "tags": ["beach", "summer", "sunset"],
    "isFavorite": true,
    "isImportant": true,
    "relativeFilePath": "media/Images/sunset_beach.heic"
  }
]
```

### 3.3 `metadata/diaries.json` (片段)
```json
[
  {
    "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
    "title": "海邊假日記事",
    "content": "今天下午與家人驅車來到海邊，海風微涼，夕陽將天際染成金黃色……",
    "entryDate": "2026-07-20T21:00:00Z",
    "mood": "🏖️",
    "tags": ["beach", "family"],
    "isFavorite": true,
    "isImportant": true,
    "attachedMediaIDs": ["E621E1F8-C36C-495A-93FC-0C247A3E6E5F"]
  }
]
```

### 3.4 `checksums/sha256.txt`
```text
4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a  media/Images/sunset_beach.heic
d3b07384d113edec49eaa6238ad5ff00  diaries/2026-07-20_海邊假日記事.md
```

---

## 4. 安全加密可攜性 (AES-256-GCM Encrypted Archive)

當使用者選擇加密封裝匯出時：
1. 封裝庫內部依然遵照上述標準結構。
2. 透過 `AES256VaultEngine.swift` 以 `NOTYVLT1` 容器格式將封裝資料夾進行分塊加密為單一 `.notyarchive` 密文檔案。
3. 密文標頭包含 32 位元組隨機 Salt，需透過密碼進行 PBKDF2 600,000 次金鑰推導方可解開。
