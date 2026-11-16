#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ARCH="${GLASSIST_ARCH:-arm64}"
swift build -c release --arch "$ARCH"
BIN_DIR="$(swift build -c release --arch "$ARCH" --show-bin-path)"
APP="dist/Glassist.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Glassist" "$APP/Contents/MacOS/Glassist"
cp scripts/Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/Glassist-$ARCH.zip"
echo "Built $APP"
