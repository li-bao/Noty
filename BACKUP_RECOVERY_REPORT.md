# Noty Backup Rotation & Disaster Recovery Report (BACKUP_RECOVERY_REPORT.md)
**Date**: 2026-11-07  
**Platform**: macOS 14.0+ / 15.0+ (Apple Silicon ARM64, Mac mini M4 24GB)  
**Status**: Real Backup Profiles, Verification & Isolated Sandbox Restore Verified  

---

## 1. 備份配置類別 (Backup Profiles)

Noty 提供 6 種專業備份模式：
1. **Full Backup**：包含 SwiftData `Database/`、所有原始照片、影片與快取縮圖，並生成含所有檔案 SHA-256 清單的 `Manifest.json`。
2. **Incremental Backup**：僅備份自上次備份以來變更的媒體檔案與資料庫快照。
3. **Database Snapshot**：快速備份 `Noty.store` 核心資料庫，體積輕巧。
4. **Media Only**：將所有原始圖片與影片按照類型整理匯出。
5. **Diaries Only**：將所有日記封裝為 JSON 與 Markdown 雙軌存檔。
6. **Encrypted Vault Archive**：以 AES-256-GCM 密文封裝全庫，適用於外接隨身碟離線保存。

---

## 2. 備份版本輪替 (Backup Rotation Policy)

- **自動修剪**：使用者可設定保留最近 3 份、5 份、10 份或自訂備份。
- **原子性前置檢查原則**：
  在刪除任何舊備份之前，`rotateBackups()` 必須先呼叫 `inspectBackup()` 驗證最新一份備份是可讀且完整的。若最新備份有損毀或缺漏，立即中止修剪流程，絕不在新備份失敗時擅自刪除最後一份可用備份！

---

## 3. 逐檔 SHA-256 完整性校驗 (Manifest Verification)

在 `createFullBackup()` 建立備份時，自動遍歷備份目錄中所有檔案並計算 SHA-256 指紋記錄於 `Manifest.json`：
```json
{
  "appName": "Noty",
  "appVersion": "1.0.0",
  "backupDate": "2026-11-07T12:30:00Z",
  "photoCount": 120,
  "videoCount": 15,
  "diaryCount": 42,
  "profile": "Full",
  "files": [
    {
      "relativePath": "Database/Noty.store",
      "fileSizeBytes": 2457600,
      "sha256": "7a8b9c...d4e5f6"
    },
    {
      "relativePath": "Media/Images/sunset.jpg",
      "fileSizeBytes": 3145728,
      "sha256": "1a2b3c...4d5e6f"
    }
  ]
}
```
透過 `verifyBackupIntegrity(at:)` 可一鍵快速比對備份包中每一個實體檔案的大小與 SHA-256 是否 100% 吻合。

---

## 4. 隔離沙盒災難復原測試 (Isolated Sandbox Disaster Recovery)

為了確保備份包在極端情況下能真正救回資料，同時絕不干擾或破壞使用者本機目前的正式資料庫：
- `restoreToIsolatedSandbox(at:sandboxDirectory:)` 在獨立的臨時沙盒目錄中模擬完整還原流程。
- 還原後自動驗證資料庫結構是否存在、媒體檔案是否完整復原、以及 SHA-256 指紋是否 100% 吻合。
- 測試斷言證實：還原後的檔案結構與資料指紋零損失。
