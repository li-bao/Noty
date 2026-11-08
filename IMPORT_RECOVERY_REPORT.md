# Noty Persistent Import Queue & Crash Recovery Report (IMPORT_RECOVERY_REPORT.md)
**Date**: 2026-11-07  
**Platform**: macOS 14.0+ / 15.0+ (Apple Silicon ARM64, Mac mini M4 24GB)  
**Status**: Real Implementation Completed & Verified  

---

## 1. 架構核心理念

匯入是 Noty 最神聖且關鍵的操作之一。在 Phase 9.875 中，我們將原本僅存於記憶體的匯入狀態提升為**持久化狀態機（Persistent State Machine）**，杜絕以下潛在風險：
- 匯入數十部大型影片時，若系統異常斷電或強制關閉，暫存檔永久孤立霸佔硬碟空間。
- 未完成校驗的半成品檔案被誤認為成功匯入並污染資料庫。
- 剩餘磁碟空間不足時盲目啟動大量複製，造成寫入失敗與資料損毀。

---

## 2. 匯入任務狀態機 (Import Job State Machine)

每批匯入工作即時記錄於 `~/Library/Application Support/Noty/Library/Temp/import_queue.json`：
1. **Pending**：已接收使用者選取或拖放檔案，排入處理序列。
2. **Copying**：以非破壞性流體讀取原始檔案並複製至 `Library/Temp/`。
3. **Verifying**：進行複製後雙重驗證（檔案大小與 SHA-256 指紋完全吻合）。
4. **GeneratingThumbnail**：背景解碼影像生成 256×256 縮圖。
5. **Committed**：原子性移入正式 `Media/` 資料夾並提交 SwiftData 資料庫紀錄。
6. **Failed / Cancelled**：若發生錯誤或被使用者取消，即刻回滾並清理暫存。

---

## 3. 磁碟剩餘空間前置預檢 (Disk Space Pre-check)

在呼叫任何複製動作前，`ImportQueueService.shared.checkDiskSpaceSufficient(for:)` 依據以下準則執行檢驗：
- 計算欲匯入檔案清單之總位元組數（`requiredBytes`）。
- 查詢 macOS 磁碟卷宗實際剩餘可用空間（`availableBytes`）。
- **1.5 倍安全餘裕原則**：必須滿足 `availableBytes > requiredBytes * 1.5`（預留縮圖快取與資料庫日誌空間），方允許啟動批次作業；否則彈出警示並提供清理暫存選項。

---

## 4. 啟動自我修復機制 (Startup Self-Healing & Orphan Cleanup)

於 Noty 啟動時：
- 自動執行 `ImportQueueService.shared.recoverQueueOnLaunch()`。
- 掃描所有滯留於 `Pending`、`Copying`、`Verifying`、`GeneratingThumbnail` 的中斷任務，標記為 `Failed (App interrupted unexpectedly)`。
- 自動遍歷 `Library/Temp/` 目錄，將未完成或孤立殘留的暫存檔進行安全銷毀，回報回收磁碟位元組數。
- 絕不遺留任何偽冒成功之半成品。
