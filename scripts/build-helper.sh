#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
HELPER_DIR="$ROOT_DIR/helper"
ASSETS_DIR="$ROOT_DIR/assets"
SCRATCH_DIR="/tmp/clean-screen-helper-build"
BUILD_OUTPUT="$SCRATCH_DIR/release/CleanScreenHelper"
TARGET_OUTPUT="$ASSETS_DIR/CleanScreenHelper"
APP_DIR="$ASSETS_DIR/CleanScreenHelper.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
PLIST_PATH="$APP_DIR/Contents/Info.plist"

swift build -c release --package-path "$HELPER_DIR" --scratch-path "$SCRATCH_DIR"
cp "$BUILD_OUTPUT" "$TARGET_OUTPUT"
chmod +x "$TARGET_OUTPUT"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_OUTPUT" "$MACOS_DIR/CleanScreenHelper"
chmod +x "$MACOS_DIR/CleanScreenHelper"

cat > "$PLIST_PATH" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>CleanScreenHelper</string>
  <key>CFBundleIdentifier</key>
  <string>com.eigenlicht.clean-screen-helper</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Clean Screen Helper</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

echo "Built helper to $TARGET_OUTPUT"
echo "Built app bundle to $APP_DIR"
