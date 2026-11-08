# Noty — 編譯與建置說明指南 (BUILD_INSTRUCTIONS.md)

> **目標平台**：Apple Silicon ARM64 (macOS 14.0 Sonoma 或更高版本)  
> **編譯工具鏈**：Xcode 16+ / Xcode 27+ (含 Command Line Tools)  
> **輸出產物**：`dist/Noty.app`、`dist/Noty-arm64.dmg`

---

## 1. 環境前置檢查

在終端機中執行下列指令確認開發環境已正確就緒：

```bash
# 檢查 CPU 架構（必須為 arm64）
uname -m

# 檢查 Xcode 與 Swift 工具鏈版本
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version
swift --version
```

---

## 2. 自動化一鍵 Release 編譯與 DMG 打包

專案已內建完整的自動化打包腳本 [scripts/build_release_dmg.sh](file:///Users/libao/Downloads/Noty/scripts/build_release_dmg.sh)，執行後將依序完成 Release 編譯、架構過濾、代碼簽名、暫存裝配與 UDZO 壓縮 DMG 產出：

```bash
# 授予執行權限並執行打包
chmod +x scripts/build_release_dmg.sh
./scripts/build_release_dmg.sh
```

### 產物清單：
- 應用程式：`dist/Noty.app` (二進制架構純為 `arm64`)
- 安裝映像檔：`dist/Noty-arm64.dmg` (內含 `Noty.app`、`/Applications` 捷徑與安裝說明)

---

## 3. 手動命令列逐步編譯 (Manual Steps)

### A. 編譯 Release 版本
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -scheme Noty \
    -configuration Release \
    -derivedDataPath DerivedData \
    -destination "platform=macOS,arch=arm64" \
    clean build
```

### B. 驗證產物架構
```bash
lipo -info DerivedData/Build/Products/Release/Noty.app/Contents/MacOS/Noty
# 輸出應顯示: Non-fat file: ... is architecture: arm64
```

### C. 執行代碼簽章 (Ad-Hoc / Developer ID)
```bash
# 檢查是否有 Apple 官方 Developer ID Application 憑證
DEV_ID=$(security find-identity -p codesigning -v | grep "Developer ID Application:" | head -n 1 | awk -F '"' '{print $2}')

if [ -n "$DEV_ID" ]; then
    codesign --force --deep --sign "$DEV_ID" \
        --options runtime \
        --entitlements Noty/Resources/Noty.entitlements \
        --timestamp \
        DerivedData/Build/Products/Release/Noty.app
else
    # 本機測試與無憑證環境使用 Ad-Hoc 簽名
    codesign --force --deep --sign - \
        --entitlements Noty/Resources/Noty.entitlements \
        DerivedData/Build/Products/Release/Noty.app
fi

# 驗證簽章狀態
codesign --verify --deep --strict --verbose=2 DerivedData/Build/Products/Release/Noty.app
```

### D. 建立 DMG 映像檔
```bash
mkdir -p dist/staging
cp -R DerivedData/Build/Products/Release/Noty.app dist/staging/Noty.app
ln -s /Applications dist/staging/Applications

hdiutil create \
    -volname "Noty" \
    -srcfolder dist/staging \
    -ov \
    -format UDZO \
    dist/Noty-arm64.dmg

rm -rf dist/staging
```

---

## 4. 執行全套自動化單元測試

專案包含 68 項嚴密的自動化測試，涵蓋圖庫、日記生命週期、SHA-256 數位指紋對齊、Ollama 本機迴路白名單及密碼學演算法：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -scheme Noty \
    -derivedDataPath DerivedData \
    -destination "platform=macOS,arch=arm64" \
    test
```
所有測試應顯示 `** TEST SUCCEEDED **`，通過率維持 100%。

---

## 5. 常見問題與除錯 (Troubleshooting)

1. **`xcode-select: error: tool 'xcodebuild' requires Xcode`**：
   * 原因：當前 CommandLineTools 未關聯至完整 Xcode。
   * 解法：在前綴加入 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` 或執行 `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`。
2. **首次安裝提示「無法驗證開發者」**：
   * 原因：本發行版本採用本機 Ad-Hoc 簽章，無 Apple 官方付費 Notarization 公證。
   * 解法：在 `/Applications/Noty.app` 按右鍵選擇「打開」，或至 macOS「系統設定」>「隱私權與安全性」點擊「仍要打開」。
