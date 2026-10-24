#!/bin/bash
# Builds Goose.app next to this script.
set -euo pipefail
cd "$(dirname "$0")"
APP="Goose.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Build a universal macOS binary so the same app runs natively on both
# Apple Silicon and Intel Macs.
TMP_BUILD="$(mktemp -d)"
trap 'rm -rf "$TMP_BUILD"' EXIT
SDK="$(xcrun --sdk macosx --show-sdk-path)"
SOURCES=(goose.swift pixel_art.swift coyote_art.swift coyote.swift ui.swift app.swift)
xcrun swiftc -O -parse-as-library -sdk "$SDK" -target arm64-apple-macosx12.0 "${SOURCES[@]}" -o "$TMP_BUILD/Goose-arm64"
xcrun swiftc -O -parse-as-library -sdk "$SDK" -target x86_64-apple-macosx12.0 "${SOURCES[@]}" -o "$TMP_BUILD/Goose-x86_64"
xcrun lipo -create "$TMP_BUILD/Goose-arm64" "$TMP_BUILD/Goose-x86_64" -output "$APP/Contents/MacOS/Goose"
# goose-shaped app icon, rendered by the binary itself
ICONSET="$(mktemp -d)/Goose.iconset"
"$APP/Contents/MacOS/Goose" --iconset "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Goose.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Goose</string>
  <key>CFBundleDisplayName</key><string>Desktop Goose</string>
  <key>CFBundleIdentifier</key><string>local.desktop.goose</string>
  <key>CFBundleExecutable</key><string>Goose</string>
  <key>CFBundleIconFile</key><string>Goose</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP" 2>/dev/null || true
echo "built $(pwd)/$APP"
