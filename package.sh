#!/bin/bash

APP_NAME="Launcher"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
EXECUTABLE="$APP_NAME"

# Build the project
echo "Building $APP_NAME..."
swift build -c release

# Create App Bundle Structure
echo "Creating $APP_BUNDLE..."
if [ -d "$APP_BUNDLE" ]; then
    rm -rf "$APP_BUNDLE"
fi

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Executable
cp "$BUILD_DIR/$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.launcher.swift</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Copy Icon if it exists
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

echo "App Bundle created at $APP_BUNDLE"

# Create DMG
echo "Creating DMG..."
DMG_NAME="Launcher.dmg"
DMG_ROOT="dmg_root"

# Clean up previous
rm -rf "$DMG_ROOT" "$DMG_NAME"
mkdir -p "$DMG_ROOT"

# Copy App to DMG root
cp -r "$APP_BUNDLE" "$DMG_ROOT/"

# Create Applications shortcut
ln -s /Applications "$DMG_ROOT/Applications"

# Create DMG
hdiutil create -volname "Launcher" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_NAME"

# Cleanup
rm -rf "$DMG_ROOT"

echo "DMG created at $DMG_NAME"
open .
