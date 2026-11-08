# Noty — Complete Liquid Glass Button Audit Report (LIQUID_GLASS_AUDIT.md)
**Date**: 2026-11-07  
**Design Standard**: Apple Human Interface Guidelines for Materials & Liquid Glass  
**Target Architecture**: Apple Silicon macOS 14.0+ / 15.0+  
**Status**: 100% Comprehensive Audit Completed  

---

## 1. 統一設計系統 (Unified Button Design System)

所有互動元件統一由 [`NotyButtonStyle.swift`](file:///Users/libao/Downloads/Noty/Noty/Core/NotyButtonStyle.swift)、[`NotyGlassComponents.swift`](file:///Users/libao/Downloads/Noty/Noty/Core/NotyGlassComponents.swift) 與 [`NotyDesignSystem.swift`](file:///Users/libao/Downloads/Noty/Noty/Core/NotyDesignSystem.swift) 集中管理：

1. **Primary Button (`.buttonStyle(.notyPrimary)`)**:
   - 膠囊造型（高度 34pt / 28pt）。
   - 主題色漸層（`Color.accentColor`）結合流體玻璃背板與 0.8pt 微光高亮邊框。
   - 壓下時 Spring 縮放（0.97）與外發光陰影。
2. **Secondary Button (`.buttonStyle(.notySecondary)`)**:
   - 膠囊造型。
   - `.ultraThinMaterial` 原生材質搭配深淺色自動適配之微邊框與柔和陰影。
3. **Destructive Button (`.buttonStyle(.notyDestructive)`)**:
   - 膠囊造型。
   - 紅色微光漸層，用於垃圾桶清理、永久刪除與保險庫重設。
4. **Icon Button (`.buttonStyle(.notyIcon)`)**:
   - 圓形膠囊（Circle Capsule），Hover 柔光高亮，壓下縮放（0.92）。
5. **Capsule Chip (`NotyCapsuleChip`)**:
   - 用於 Gallery 分類篩選（全部、照片、影片、收藏、重要回憶等），選中時流體漸層發光，未選中時為晶透玻璃材質。
6. **Floating Button (`.buttonStyle(.notyFloating)`)**:
   - 懸浮控制列（如全螢幕播放器浮動條、右下角 Utility Rail），具備更深景深陰影。
7. **Apple 原生相容性**:
   - 原生支援 `.buttonStyle(.glass)` 與 `.buttonStyle(.glassProminent)`。

---

## 2. 全專案互動元件掃描與審計清單 (Full Interactive Controls Inventory)

| 所屬頁面 / 模組 | 元件標籤 / 名稱 | 原有樣式 | 審計判定 | 統一 Liquid Glass 樣式 | 測試結果 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **頂部全局 (Top Bar)** | Quick Upload (右上角) | 自訂流體弧形玻璃 | 符合標準 | `FluidUploadWedgeShape` + Glass Material | 通過 |
| **頂部全局 (Top Bar)** | 拖放全視窗遮罩 | 自訂大型擴張玻璃 | 符合標準 | `DynamicFullWindowDropZone` | 通過 |
| **右側邊欄 (Utility Rail)** | AI Assistant 按鈕 | 膠囊玻璃造型 | 符合標準 | `.notyFloating` + Liquid Capsule | 通過 |
| **右下控制 (Utility Rail)** | More 選單按鈕 (`...`) | 膠囊玻璃半徑 | 符合標準 | `.notyIcon(size: 28)` + Liquid Glass | 通過 |
| **右下控制 (Utility Rail)** | Lock 鎖定按鈕 (`🔒`) | 膠囊玻璃半徑 | 符合標準 | `.notyIcon(size: 28)` + Liquid Glass | 通過 |
| **左側側邊欄 (Sidebar)** | 7 個主分頁按鈕 | `.plain` + 懸停背景 | 需統一膠囊 | `SidebarNavigationButton` with Liquid Capsule | 通過 |
| **左側側邊欄 (Sidebar)** | 5 個收藏分組按鈕 | `.plain` + 懸停背景 | 需統一膠囊 | `SidebarNavigationButton` with Liquid Capsule | 通過 |
| **左側側邊欄 (Sidebar)** | 底部 Settings 按鈕 | `.plain` + 懸停背景 | 需統一膠囊 | `SidebarNavigationButton` with Liquid Capsule | 通過 |
| **Gallery 主頁** | 分類篩選標籤列 (Chips) | 橫向 ScrollView + Capsule | 符合標準 | `NotyCapsuleChip` (全部/照片/影片/收藏/重要) | 通過 |
| **Gallery 主頁** | 排序切換鈕 (↑ / ↓) | `.plain` 圓形按鈕 | 升級 | `.notyIcon(size: 28)` | 通過 |
| **Gallery 主頁** | 多選模式切換鈕 (`Select`) | 膠囊邊框按鈕 | 升級 | `.notySecondary(height: 28)` | 通過 |
| **Gallery 空狀態** | `try [↑ upload]` 按鈕 | `.borderedProminent` | 升級 | `.notyPrimary(height: 34)` | 通過 |
| **Gallery 空狀態** | `[📁 open file...]` 按鈕 | `.bordered` | 升級 | `.notySecondary(height: 34)` | 通過 |
| **媒體預覽 (Viewer)** | 上一張 / 下一張按鈕 | 自訂圓形毛玻璃 | 符合標準 | `.notyIcon(size: 40)` | 通過 |
| **媒體預覽 (Viewer)** | 收藏 / 旋轉 / 資訊 / 關閉 | 頂部浮動列按鈕 | 符合標準 | `.notyIcon(size: 34)` + Floating Glass Bar | 通過 |
| **影片播放器 (Video)** | 播放 / 暫停 / 全螢幕 | 自訂浮動控制條 | 符合標準 | `.notyIcon(size: 32)` + Floating Glass Bar | 通過 |
| **側邊資訊 (Inspector)** | 關閉面板按鈕 (`xmark`) | `.plain` 按鈕 | 升級 | `.notyIcon(size: 26)` | 通過 |
| **側邊資訊 (Inspector)** | 移入垃圾桶 (`Trash`) | `.bordered` | 升級 | `.notyDestructive(height: 30)` | 通過 |
| **側邊資訊 (Inspector)** | 重要回憶標記 (`Important`) | 尚未實作 | 新增 | `NotyCapsuleChip` 標記 | 通過 |
| **日記列表 (Diary)** | 新增日記按鈕 (`+ New`) | `.borderedProminent` | 升級 | `.notyPrimary(height: 32)` | 通過 |
| **日記列表 (Diary)** | 心情篩選膠囊 (Mood Chips) | 橫向膠囊列表 | 符合標準 | `NotyCapsuleChip` | 通過 |
| **日記編輯器 (Composer)** | 儲存按鈕 (`Save`) | `.borderedProminent` | 升級 | `.notyPrimary(height: 32)` | 通過 |
| **日記編輯器 (Composer)** | 取消 / 歷史版本按鈕 | `.bordered` | 升級 | `.notySecondary(height: 32)` | 通過 |
| **日記編輯器 (Composer)** | 附加媒體按鈕 (`+ Media`) | 膠囊邊框 | 升級 | `.notySecondary(height: 28)` | 通過 |
| **相簿列表 (Albums)** | 建立相簿按鈕 (`+ Album`) | `.borderedProminent` | 升級 | `.notyPrimary(height: 32)` | 通過 |
| **垃圾桶 (Trash)** | 全部清空按鈕 (`Empty Trash`) | `.bordered` | 升級 | `.notyDestructive(height: 32)` | 通過 |
| **垃圾桶 (Trash)** | 還原 / 永久刪除單項按鈕 | `.plain` / `.bordered` | 升級 | `.notySecondary` / `.notyDestructive` | 通過 |
| **設定 (Settings)** | 6 個分頁切換按鈕 | 頂部膠囊列 | 符合標準 | `NotyCapsuleChip` | 通過 |
| **設定 (Settings)** | 保險庫配置 / 鎖定 / 解鎖 | 各種邊框按鈕 | 升級 | `.notyPrimary` / `.notySecondary` / `.notyDestructive` | 通過 |
| **設定 (Settings)** | 備份匯出 / 還原按鈕 | `.borderedProminent` / `.bordered` | 升級 | `.notyPrimary` / `.notySecondary` | 通過 |
| **健康檢查 (Health)** | 執行檢查 / 安全修復按鈕 | `.borderedProminent` | 升級 | `.notyPrimary(height: 32)` | 通過 |

---

## 3. 防過度玻璃化原則 (Anti-Over-Glassing Guardrail)

嚴格遵守 Apple Human Interface Guidelines：
- **內容區純淨原則**：所有原始照片、縮圖影像、播放中視訊像素、日記正文長篇排版，維持原生渲染與高對比閱讀性，絕不在影像本體疊加毛玻璃模糊遮罩。
- **單層玻璃原則**：原生 macOS 視窗背景或系統已具備質感的側邊欄中，控制元件僅使用單層微光邊框與流體材質，不產生兩層以上的視覺眩光與文字糊化。
- **無障礙對比**：在 Light Mode 與 Dark Mode 下，文字對比度皆超過 WCAG AA 4.5:1，在開啟「減少透明度 (Reduce Transparency)」系統偏好時自動平滑回退為高對比實色背景。
