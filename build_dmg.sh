#!/bin/bash
set -e

# ==========================================
# QueuePaste Build & Package Script
# ==========================================
# This script builds the Xcode project and packages it into a DMG format.
# Requires: Homebrew and `create-dmg` (brew install create-dmg)

APP_NAME="QueuePaste"
# Use the same directory as this script is located in
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ARCHIVE_PATH="$PROJECT_DIR/build/$APP_NAME.xcarchive"
EXPORT_OPTIONS_PLIST="$PROJECT_DIR/ExportOptions.plist"
RELEASE_DIR="$PROJECT_DIR/release"
APP_PATH="$RELEASE_DIR/$APP_NAME.app"
DMG_PATH="$RELEASE_DIR/$APP_NAME.dmg"

echo "Cleaning previous builds..."
rm -rf "$PROJECT_DIR/build"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

echo "Archiving the Xcode project..."
xcodebuild -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    archive

echo "Creating temporary ExportOptions.plist..."
cat <<EOF > "$EXPORT_OPTIONS_PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>teamID</key>
    <string></string>
</dict>
</plist>
EOF

echo "Exporting the .app from Archive..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
    -exportPath "$RELEASE_DIR"

# Clean up temporary export options
rm "$EXPORT_OPTIONS_PLIST"

echo "Installing create-dmg (if necessary)..."
if ! command -v create-dmg &> /dev/null; then
    echo "create-dmg not found. Installing via Homebrew..."
    brew install create-dmg
fi

echo "Generating DMG icon..."
mkdir -p "$PROJECT_DIR/build/icon.iconset"
cp "$PROJECT_DIR/QueuePaste/Assets.xcassets/AppIcon.appiconset/"*.png "$PROJECT_DIR/build/icon.iconset/"
iconutil -c icns "$PROJECT_DIR/build/icon.iconset" -o "$PROJECT_DIR/build/AppIcon.icns"

echo "Creating DMG..."
create-dmg \
  --volname "$APP_NAME Installer" \
  --volicon "$PROJECT_DIR/build/AppIcon.icns" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "$APP_NAME.app" 175 120 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 425 120 \
  "$DMG_PATH" \
  "$APP_PATH"

echo "Cleaning up intermediate files..."
rm -rf "$APP_PATH"

echo "Done! The DMG is located at:"
echo "$DMG_PATH"
