#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
preview_bundle="$PWD/.build/design-preview/GlassistPreview.app"
mkdir -p "$preview_bundle/Contents/MacOS" "$preview_bundle/Contents/Resources"
xcrun swiftc -D DESIGN_PREVIEW -parse-as-library -target arm64-apple-macos14.0 \
  -module-cache-path .build/preview-modules \
  Sources/GlassistCore/*.swift Sources/GlassistWidgets/*.swift scripts/render-previews.swift \
  -o "$preview_bundle/Contents/MacOS/GlassistPreview"
ditto Sources/GlassistCore/Resources "$preview_bundle/Contents/Resources"
cat > "$preview_bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>GlassistPreview</string><key>CFBundleIdentifier</key><string>com.frankwang.Glassist.DesignPreview</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>
PLIST
"$preview_bundle/Contents/MacOS/GlassistPreview" "${1:-/tmp/Glassist-preview.png}" "${2:-}"
