#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: ./create_icns.sh <path_to_image>"
    exit 1
fi

SOURCE_IMAGE="$1"
ICONSET_DIR="AppIcon.iconset"

# Create iconset directory
mkdir -p "$ICONSET_DIR"

# Helper function to resize
resize_icon() {
    SIZE=$1
    NAME=$2
    sips -z $SIZE $SIZE -s format png "$SOURCE_IMAGE" --out "$ICONSET_DIR/$NAME" > /dev/null
}

echo "Generating iconset from $SOURCE_IMAGE..."

# Standard sizes
resize_icon 16 "icon_16x16.png"
resize_icon 32 "icon_16x16@2x.png"
resize_icon 32 "icon_32x32.png"
resize_icon 64 "icon_32x32@2x.png"
resize_icon 128 "icon_128x128.png"
resize_icon 256 "icon_128x128@2x.png"
resize_icon 256 "icon_256x256.png"
resize_icon 512 "icon_256x256@2x.png"
resize_icon 512 "icon_512x512.png"
resize_icon 1024 "icon_512x512@2x.png"

echo "Converting to .icns..."
iconutil -c icns "$ICONSET_DIR"

# Cleanup
rm -rf "$ICONSET_DIR"

if [ -f "AppIcon.icns" ]; then
    echo "Done! AppIcon.icns created."
    
    # Copy to app if it exists, but keep the original here for package.sh
    if [ -d "Launcher.app" ]; then
        mkdir -p Launcher.app/Contents/Resources
        cp AppIcon.icns Launcher.app/Contents/Resources/
        echo "Icon copied to Launcher.app."
    fi
    
    echo "Icon generated. Run ./package.sh to include it in the bundle."
    echo "You may need to restart Finder or the Dock to see changes immediately:"
    echo "  killall Finder"
    echo "  killall Dock"
else
    echo "Error: Failed to create AppIcon.icns"
    exit 1
fi
