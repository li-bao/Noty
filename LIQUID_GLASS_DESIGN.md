# Noty — Apple Liquid Glass 視覺設計系統規範書 (LIQUID_GLASS_DESIGN.md)

> **設計核心**：Apple Liquid Glass（流體玻璃、微光反射、柔和陰影、膠囊化造型）  
> **管理模組**：`Noty/Core/NotyDesignSystem.swift`  
> **相容性**：macOS 14.0+，支援 Light / Dark / System 動態外觀，支援 Reduce Motion

---

## 1. 設計哲學與材料語言

Noty 告別粗糙直角方塊與普通網頁堆疊卡片，全面升級為 Apple 原生 Liquid Glass 設計語言：

1. **材質層次 (Material Layers)**：
   - 採用 `.ultraThinMaterial` 作為流體基底，透出背後柔和色彩與高斯模糊。
   - 邊界疊加漸層邊框（Specular Border Gradient），營造光線從左上方向右下方折射的立體感。
2. **造型語言 (Shape Grammar)**：
   - 所有主要按鈕、搜尋欄、標籤晶片、分段控制器全面採用 **Capsule（膠囊型）**。
   - 卡片與彈窗採用連續圓角 **Continuous Rounded Rectangle**（曲率半徑 18～24 pt）。
3. **動態微互動 (Micro-Interactions)**：
   - **Hover Soft Glow**：滑鼠懸停時微幅增加邊框光澤與陰影半徑，平滑無突兀感。
   - **Spring Feedback**：點擊或狀態切換採用 `Animation.spring(response: 0.35, dampingFraction: 0.75)`。
   - **Reduce Motion**：嚴格遵循系統無障礙減弱動態偏好，關閉非必要縮放與晃動。
