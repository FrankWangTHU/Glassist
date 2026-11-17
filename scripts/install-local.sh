#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" == "--help" ]]; then
  echo 'Usage: bash scripts/install-local.sh [--build-only | /Applications/Glassist.app]'
  echo 'Uses the Xcode account and Configuration/LocalSigning.xcconfig on this Mac.'
  exit 0
fi
if [[ ! -f Configuration/LocalSigning.xcconfig ]]; then
  echo 'Copy Configuration/LocalSigning.xcconfig.example to LocalSigning.xcconfig and enter your Xcode Team ID.' >&2
  exit 1
fi
build_only=false
if [[ "${1:-}" == "--build-only" ]]; then build_only=true; fi
destination="${1:-/Applications/Glassist.app}"
if ! $build_only; then
  if [[ "$destination" != /*/Glassist.app ]]; then
    echo 'Use an absolute destination ending in /Glassist.app.' >&2; exit 1
  fi
  if [[ -e "$destination" ]]; then
    existing_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$destination/Contents/Info.plist")
    [[ "$existing_id" == 'com.frankwang.Glassist' ]] || { echo 'Destination belongs to another app.' >&2; exit 1; }
  fi
fi
xcodebuild -project Glassist.xcodeproj -scheme Glassist -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/signed-xcode \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
app="$PWD/.build/signed-xcode/Build/Products/Release/Glassist.app"
/usr/bin/codesign --verify --deep --strict "$app"
if $build_only; then echo "Signed application: $app"; exit 0; fi

parent=$(dirname "$destination")
mkdir -p "$parent"
stage=$(mktemp -d "$parent/.glassist-install.XXXXXX")
restore_previous() {
  if [[ ! -e "$destination" && -d "$stage/Previous.app" ]]; then mv "$stage/Previous.app" "$destination"; fi
  rm -rf "$stage"
}
trap restore_previous EXIT
/usr/bin/ditto "$app" "$stage/Glassist.app"
/usr/bin/codesign --verify --deep --strict "$stage/Glassist.app"
if /usr/bin/pgrep -x Glassist >/dev/null; then
  /usr/bin/osascript -e 'tell application id "com.frankwang.Glassist" to quit'
  for attempt in {1..20}; do
    /usr/bin/pgrep -x Glassist >/dev/null || break
    sleep 0.1
  done
  if /usr/bin/pgrep -x Glassist >/dev/null; then
    echo 'Close Glassist, then run this installer again.' >&2; exit 1
  fi
fi
# WidgetKit keeps its extension process alive independently of the settings app.
# Stop it before replacing its executable; otherwise its audit token can point to a deleted bundle.
if /usr/bin/pgrep -x GlassistWidgets >/dev/null; then
  /usr/bin/pkill -TERM -x GlassistWidgets || true
fi
if [[ -e "$destination" ]]; then mv "$destination" "$stage/Previous.app"; fi
mv "$stage/Glassist.app" "$destination"
# Xcode also registers its build product. Keep a single installed copy for gallery metadata and URL routing.
lsregister='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
"$lsregister" -u "$app"
"$lsregister" -f -R -trusted "$destination"
/usr/bin/pluginkit -a "$destination/Contents/PlugIns/GlassistWidgets.appex"
# A visible widget can relaunch the old extension during the short replacement window.
if /usr/bin/pgrep -x GlassistWidgets >/dev/null; then
  /usr/bin/pkill -TERM -x GlassistWidgets || true
fi
/usr/bin/open "$destination"
echo "Installed: $destination"
