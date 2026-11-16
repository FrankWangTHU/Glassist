#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# This build proves compilation, not signing/registration of the system widget.
xcodebuild -project Glassist.xcodeproj -scheme Glassist -configuration Release \
  -derivedDataPath .build/xcode CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO ARCHS=arm64 build
mkdir -p dist
# The unsigned archive is for developers to sign in Xcode, not a ready-to-install widget release.
ditto -c -k --sequesterRsrc --keepParent .build/xcode/Build/Products/Release/Glassist.app dist/Glassist-WidgetKit-UNSIGNED.zip
