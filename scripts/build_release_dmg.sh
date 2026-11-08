#!/bin/bash
set -e

echo "=========================================================="
echo "  Noty — macOS Native Release Build & DMG Packaging"
echo "  Target Architecture: Apple Silicon ARM64"
echo "=========================================================="

# 1. 環境設定
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

DIST_DIR="$PROJECT_DIR/dist"
STAGING_DIR="$DIST_DIR/staging"
OUTPUT_DMG="$DIST_DIR/Noty-arm64.dmg"
DERIVED_DATA_DIR="$PROJECT_DIR/DerivedData"
RELEASE_APP_SRC="$DERIVED_DATA_DIR/Build/Products/Release/Noty.app"
FINAL_APP_DEST="$DIST_DIR/Noty.app"

echo "專案目錄: $PROJECT_DIR"
echo "Xcode 路徑: $DEVELOPER_DIR"

# 2. 清理輸出目錄
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
mkdir -p "$STAGING_DIR"

# 3. 使用 xcodebuild 執行 Release 編譯
echo ""
echo "▶ 步驟 1/5：編譯 Release 產物 (arm64)..."
xcodebuild -scheme Noty \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    -destination "platform=macOS,arch=arm64" \
    clean build \
    | xcbeautify 2>/dev/null || xcodebuild -scheme Noty \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    -destination "platform=macOS,arch=arm64" \
    build

if [ ! -d "$RELEASE_APP_SRC" ]; then
    echo "❌ 錯誤：未在預期路徑找到 Release 產物：$RELEASE_APP_SRC"
    exit 1
fi

echo "✅ Release 編譯成功！"

# 4. 架構校驗與隱私審查
echo ""
echo "▶ 步驟 2/5：二進制架構與隱私安全校驗..."
EXEC_PATH="$RELEASE_APP_SRC/Contents/MacOS/Noty"
ARCH_INFO=$(lipo -info "$EXEC_PATH")
echo "二進制架構資訊: $ARCH_INFO"

if ! echo "$ARCH_INFO" | grep -q "arm64"; then
    echo "❌ 錯誤：二進制檔未包含 arm64 架構！"
    exit 1
fi

# 確認無使用者私人資料或資料庫被打入 App 本體
if find "$RELEASE_APP_SRC" -name "*.store*" -o -name "*.sqlite*" -o -name "*.db" | grep -q .; then
    echo "❌ 警告：App 本體中偵測到資料庫檔案，正在清理..."
    find "$RELEASE_APP_SRC" -name "*.store*" -o -name "*.sqlite*" -o -name "*.db" -delete
fi

# 5. 代碼簽署 (Code Signing)
echo ""
echo "▶ 步驟 3/5：代碼簽署與完整性校驗..."
DEV_ID=$(security find-identity -p codesigning -v | grep "Developer ID Application:" | head -n 1 | awk -F '"' '{print $2}' || true)

if [ -n "$DEV_ID" ]; then
    echo "🔒 偵測到可用的 Developer ID 憑證：$DEV_ID"
    echo "正在使用 Developer ID 與 Hardened Runtime 簽署..."
    codesign --force --deep --sign "$DEV_ID" \
        --options runtime \
        --entitlements "$PROJECT_DIR/Noty/Resources/Noty.entitlements" \
        --timestamp \
        "$RELEASE_APP_SRC"
else
    echo "ℹ️ 本機未配置 Apple Developer ID 憑證。"
    echo "使用標準 Ad-Hoc 簽名完成本機獨立執行封裝..."
    codesign --force --deep --sign - \
        --entitlements "$PROJECT_DIR/Noty/Resources/Noty.entitlements" \
        "$RELEASE_APP_SRC"
fi

echo "校驗簽章狀態："
codesign --verify --deep --strict --verbose=2 "$RELEASE_APP_SRC"

# 複製獨立 Noty.app 至 dist/
cp -R "$RELEASE_APP_SRC" "$FINAL_APP_DEST"
echo "✅ 已生成 dist/Noty.app"

# 6. 構建 DMG 暫存區 (Staging)
echo ""
echo "▶ 步驟 4/5：組裝 DMG 暫存結構..."
cp -R "$FINAL_APP_DEST" "$STAGING_DIR/Noty.app"
ln -s /Applications "$STAGING_DIR/Applications"

# 建立安裝導引說明
cat << 'EOF' > "$STAGING_DIR/INSTALL_INSTRUCTIONS.txt"
==========================================================
               Noty — Private Memory Center
==========================================================

【安裝說明 / Installation Instructions】

1. 請將「Noty.app」拖曳至右側「Applications」資料夾捷徑中。
   Drag "Noty.app" into the "Applications" folder shortcut.

2. 首次啟動：
   至「應用程式」點擊 Noty 啟動。
   若系統提示「無法驗證開發者」，請：
   - 在 Noty.app 按右鍵 (Control + 點擊)，選擇「打開」(Open)
   - 或至「系統設定」>「隱私權與安全性」點擊「仍要打開」
   - 此提示係因本版本為獨立開源/本機編譯發行版本，未包含 Apple 官方付費公證 (Notarization)。

3. 本機 AI 配置：
   如需使用側邊欄 AI Assistant，請確認 Mac 已安裝 Ollama：
   - 官方網站：https://ollama.com
   - 啟動終端機執行：ollama run qwen3.5:9b (或 llama3.2, gemma4)
   - Noty 將自動透過 127.0.0.1:11434 嚴格本機私密連接。

4. 隱私與儲存：
   所有照片、影片、日記與資料庫均儲存在本機：
   ~/Library/Application Support/Noty/

感謝使用 Noty，願回憶永恆溫暖陪伴。
==========================================================
EOF

# 7. 使用原生 hdiutil 建立壓縮唯讀 DMG
echo ""
echo "▶ 步驟 5/5：封裝壓縮 DMG (UDZO)..."
rm -f "$OUTPUT_DMG"

hdiutil create \
    -volname "Noty" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$OUTPUT_DMG"

# 清理 staging 暫存目錄
rm -rf "$STAGING_DIR"

# 8. 成果摘要報告
echo ""
echo "=========================================================="
echo "🎉 Noty Release 與 DMG 打包圓滿完成！"
echo "=========================================================="
ls -lh "$FINAL_APP_DEST"
ls -lh "$OUTPUT_DMG"

DMG_SHA256=$(shasum -a 256 "$OUTPUT_DMG" | awk '{print $1}')
echo "產物路徑: $OUTPUT_DMG"
echo "SHA-256 : $DMG_SHA256"
echo "=========================================================="
