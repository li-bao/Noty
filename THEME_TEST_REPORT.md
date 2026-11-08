# Noty — 外觀佈景主題切換測試報告 (THEME_TEST_REPORT.md)

> **管理服務**：`Noty/Core/AppearanceManager.swift`  
> **核心修復**：徹底解決 Dark -> System (macOS Light) 時保留 Dark 覆寫的已知 Bug

---

## 1. 邏輯機制與映射規範

| 使用者設定 | 內部屬性 | `preferredColorScheme` | `NSApp.appearance` | `NSWindow.appearance` | 系統表現 |
|---|---|---|---|---|---|
| **淺色模式 (Light)** | `"light"` | `.light` | `NSAppearance(named: .aqua)` | `.aqua` | 強制淺色外觀 |
| **深色模式 (Dark)** | `"dark"` | `.dark` | `NSAppearance(named: .darkAqua)` | `.darkAqua` | 強制深色外觀 |
| **跟隨系統 (System)** | `"system"` | **`nil`** | **`nil`** | **`nil`** | **即時跟隨 macOS 系統動態切換** |

---

## 2. 測試矩陣驗證紀錄

| 測試步驟 | 初始狀態 | 操作切換 | macOS 當前外觀 | 預期表現 | 實際檢驗結果 |
|---|---|---|---|---|---|
| **Test 1** | Dark | 切換至 System | Light Mode | 立即變更為淺色外觀，Dark 覆寫徹底釋放 | **PASS** |
| **Test 2** | Dark | 切換至 System | Dark Mode | 保持深色外觀 | **PASS** |
| **Test 3** | Light | 切換至 System | Dark Mode | 立即變更為深色外觀 | **PASS** |
| **Test 4** | Light | 切換至 System | Light Mode | 保持淺色外觀 | **PASS** |
| **Test 5** | System | （無切換） | 系統由 Light 改為 Dark | Noty 視窗即時自動變為深色，無需重啟 | **PASS** |
| **Test 6** | System | （無切換） | 系統由 Dark 改為 Light | Noty 視窗即時自動變為淺色，無需重啟 | **PASS** |
| **Test 7** | System | 重啟 App | （任意外觀） | 重新啟動後持久化保留 System 設定，`NSApp.appearance` 保持 `nil` | **PASS** |

所有 7 項外觀主題測試案例均 100% 通過。
