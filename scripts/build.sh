#!/bin/bash
set -e

# 切換到專案根目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

echo "=== Noty 本機編譯管線 (Apple Silicon ARM64) ==="

# 檢查 Xcode 環境
DEVELOPER_DIR_PATH="/Applications/Xcode.app/Contents/Developer"
if [ ! -d "$DEVELOPER_DIR_PATH" ]; then
    echo "錯誤：未在 /Applications/Xcode.app 找到完整的 Xcode 安裝。"
    echo "請至 Mac App Store 或 Apple Developer 下載並安裝 Xcode。"
    exit 1
fi

export DEVELOPER_DIR="$DEVELOPER_DIR_PATH"

# 確保專案檔案結構最新
python3 "$SCRIPT_DIR/generate_project.py"

CONFIGURATION="${1:-Debug}"

echo ">> 正在以 [$CONFIGURATION] 模式編譯 Noty (arm64)..."

xcodebuild -project Noty.xcodeproj \
    -scheme Noty \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$ROOT_DIR/DerivedData" \
    build

APP_PATH="$ROOT_DIR/DerivedData/Build/Products/$CONFIGURATION/Noty.app"

if [ -d "$APP_PATH" ]; then
    echo ">> 編譯成功！應用程式產物位置："
    echo "   $APP_PATH"
    file "$APP_PATH/Contents/MacOS/Noty"
else
    echo "警告：編譯似乎完成，但未在預期位置找到 Noty.app"
fi
