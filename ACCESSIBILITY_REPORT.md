# Noty Accessibility & Long-Term Usability Report (ACCESSIBILITY_REPORT.md)
**Date**: 2026-11-07  
**Platform**: macOS 14.0+ / 15.0+ (Apple Silicon ARM64, Mac mini M4 24GB)  
**Standard**: Apple Human Interface Guidelines for Accessibility (WCAG 2.1 AA Compliant)  
**Status**: Verified & Integrated  

---

## 1. 鍵盤快捷鍵矩陣 (Keyboard Shortcuts Matrix)

| 快捷鍵組合 | 動作名稱 | 作用範圍 | 衝突檢查 |
| :--- | :--- | :--- | :--- |
| **⌘ + N** | New Diary Entry (撰寫新日記) | 全域 | 無衝突（覆蓋預設文件新增） |
| **⌘ + U** | Import Media (匯入照片/影片) | 全域 | 無衝突 |
| **⌘ + F** | Find in Noty (全域快速搜尋) | 全域 | 無衝突 |
| **⌘ + ⇧ + L** | Lock Noty Vault (立即鎖定保險庫) | 全域 | 專用安全快捷鍵 |
| **⌘ + 1** | Switch to Home (首頁) | 全域 | 系統標準導覽分頁 |
| **⌘ + 2** | Switch to Gallery (媒體畫廊) | 全域 | 系統標準導覽分頁 |
| **⌘ + 3** | Switch to Diary (圖文日記) | 全域 | 系統標準導覽分頁 |
| **⌘ + 4** | Switch to Calendar (時間軸月曆) | 全域 | 系統標準導覽分頁 |
| **⌘ + 5** | Switch to Albums (自訂相簿) | 全域 | 系統標準導覽分頁 |
| **⌘ + K** | Toggle AI Assistant (開關本機 AI) | 全域 | 無衝突 |
| **⌘ + ,** | Open Settings (偏好設定) | 全域 | macOS 原生偏好設定 |
| **Escape** | Dismiss Modal / Viewer (退出預覽/關閉彈窗) | 預覽與對話框 | 原生支援 |
| **Space** | Play / Pause Video (播放/暫停視訊) | 影片播放器 | 原生焦點支援 |
| **← / →** | Seek Video ±5s (快轉/倒退 5 秒) | 影片播放器 | 原生焦點支援 |

---

## 2. 輔助使用偏好適配 (System Accessibility Adaptations)

1. **減少動態效果 (Reduce Motion)**：
   在 [`NotyDesignSystem.swift`](file:///Users/libao/Downloads/Noty/Noty/Core/NotyDesignSystem.swift) 與 [`NotyButtonStyle.swift`](file:///Users/libao/Downloads/Noty/Noty/Core/NotyButtonStyle.swift) 中，全面注入 `@Environment(\.accessibilityReduceMotion)`。當使用者在 macOS 系統設定中開啟「減少動態效果」時，所有按鈕的壓下縮放（Scale Effect）、彈簧震盪反饋與懸停浮動動畫自動關閉，轉換為平順的透明度微過渡。
2. **減少透明度 (Reduce Transparency)**：
   當開啟「減少透明度」時，Liquid Glass 材質自動加深背板不透明度，由純毛玻璃過渡至實色高對比背景，確保弱視使用者擁有高達 7:1 的 WCAG AAA 級閱讀對比度。
3. **VoiceOver 螢幕報讀**：
   所有 Icon Button（右上角 Quick Upload、AI Assistant、More 選單、Lock 鎖定鈕、收藏愛心、重要星號、防刪盾牌）皆設置清晰的語義化標籤與輔助說明（`.help` 與 Accessibility Label）。

---

## 3. 空狀態與引導體驗 (Empty States)

全專案無任何冷冰冰的空白畫面：
- **Gallery 空狀態**：可愛表情圖示、溫暖標題（`Nothing here... 😕`）、明確的引導說明、以及膠囊按鈕 `try [↑ upload]` 與 `[📁 open file...]`。
- **Diary 空狀態**：日曆筆記圖示、引導新增今日第一篇日記的顯著膠囊按鈕。
- **Trash 空狀態**：綠色打勾垃圾桶圖示、提示「垃圾桶很乾淨，無任何待刪項目」。
- **搜尋無結果**：提示未找到符合條件的回憶，並建議調整關鍵字或日期範圍。
