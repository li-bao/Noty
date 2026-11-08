# Noty Data Migration & Forward Compatibility Report (DATA_MIGRATION_REPORT.md)
**Date**: 2026-11-07  
**Platform**: macOS 14.0+ / 15.0+ (Apple Silicon ARM64, Mac mini M4 24GB)  
**Standard**: Non-Destructive Multi-Decade Preservation  
**Status**: Formal Versioning Architecture Enforced  

---

## 1. 全域格式版本規範 (Global Versioning Registry)

為了讓使用者 5 年、10 年乃至 30 年後依然能完整開啟 Noty 的資料，專案全面確立格式版本化：

| 格式範疇 | 現行版本識別碼 | 儲存載體 | 遷移相容策略 |
| :--- | :--- | :--- | :--- |
| **SwiftData 模型** | `SchemaVersion: 1.0.0` | `Database/Noty.store` | 支援欄位預設值向後相容，降級記憶體容錯保護 |
| **AES-256 保險庫** | `Magic: NOTYVLT1` | 4 MiB 分塊加密容器 | 標頭首 8 位元組硬編碼版本識別碼，未支援版本自動警示 |
| **LFES 演算法** | `Specification: 1.0` | 純數學雙射演算法 | 嚴格鎖定 7 組標準測試向量，未定義規則拋出異常防偽 |
| **本機備份包** | `ManifestVersion: 1.0.0` | `Library/Backups/` | 含逐檔 SHA-256 指紋與檔案大小清單，支援向下相容解析 |
| **可攜封裝庫** | `ArchiveVersion: 1.0.0` | `NotyArchive/` | 公開 JSON Schema 與 Markdown，零專有格式依賴 |

---

## 2. 遷移安全防禦流程 (Migration Safety Protocol)

未來若因 macOS 大版本升級需進行 SwiftData 或加密架構遷移，必須強制遵循以下 6 大原子性步驟：
1. **預先檢驗現有版本**：讀取現有資料庫與檔案標頭，確定遷移起始版本。
2. **建立自動緊急回滾快照 (Automatic Safety Rollback Snapshot)**：
   在執行任何寫入前，由 [`VaultMigrationService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Security/VaultMigrationService.swift) 或 [`BackupService.swift`](file:///Users/libao/Downloads/Noty/Noty/Services/Storage/BackupService.swift) 在 `Library/Backups/` 建立一份不受影響的完整全庫備份。
3. **驗證備份完整性**：計算備份副本之 SHA-256 雜湊，確認無任何壞軌或損毀。
4. **執行遷移管線**：在臨時工作區進行檔案與資料庫轉換。
5. **雙向對比與驗證**：比對遷移前後之媒體數量、日記篇數與重要標記。
6. **原子性替換**：僅在第 5 步 100% 驗證通過時替換正式庫；若發生任何拋錯，即刻以第 2 步之快照進行無損回滾。

---

## 3. 嚴格本機原則 (Strict Local-Only Commitment)

- **絕無隱蔽雲端上傳**：Noty 絕無任何後門上傳、未經授權的雲端同步、分析追蹤代碼或第三方廣告 SDK。
- **使用者全權掌握**：所有照片、視訊、日記、密鑰與備份資料，物理位置永遠位於使用者的 Mac 本機。
- **My memories stay mine forever.**
