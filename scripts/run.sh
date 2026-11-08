#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

# 先執行編譯
"$SCRIPT_DIR/build.sh" Debug

APP_PATH="$ROOT_DIR/DerivedData/Build/Products/Debug/Noty.app"

echo ">> 啟動 Noty.app..."
open "$APP_PATH"
