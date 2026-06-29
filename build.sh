#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="PowerTop"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "=== Building $APP_NAME ==="

# Prefer the Xcode SDK to avoid Command Line Tools SDK/compiler mismatches.
if [ -d "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk" ]; then
    SDK="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
    SWIFTC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
else
    SDK="$(xcrun --show-sdk-path)"
    SWIFTC="swiftc"
fi

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Compile Swift sources
echo "Compiling..."
SWIFT_FILES=(
    "$PROJECT_DIR/PowerTop/Utilities/AppInfo.swift"
    "$PROJECT_DIR/PowerTop/Utilities/IOKitHelpers.swift"
    "$PROJECT_DIR/PowerTop/Models/PowerConnectionPhase.swift"
    "$PROJECT_DIR/PowerTop/Models/PowerData.swift"
    "$PROJECT_DIR/PowerTop/Services/PowerMonitor.swift"
    "$PROJECT_DIR/PowerTop/Views/PowerRowView.swift"
    "$PROJECT_DIR/PowerTop/Views/MenuBarLabelView.swift"
    "$PROJECT_DIR/PowerTop/Views/PopoverView.swift"
    "$PROJECT_DIR/PowerTop/Views/DetailWindowView.swift"
    "$PROJECT_DIR/PowerTop/PowerTopApp.swift"
)

"$SWIFTC" \
    -target arm64-apple-macosx14.0 \
    -sdk "$SDK" \
    -framework SwiftUI \
    -framework IOKit \
    -framework CoreFoundation \
    -framework AppKit \
    -framework Foundation \
    -framework ServiceManagement \
    -parse-as-library \
    -O \
    -o "$BUILD_DIR/$APP_NAME" \
    "${SWIFT_FILES[@]}"

echo "Creating app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Move executable into bundle
mv "$BUILD_DIR/$APP_NAME" "$EXECUTABLE"

# Copy Info.plist
cp "$PROJECT_DIR/PowerTop/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Copy Assets
cp -R "$PROJECT_DIR/PowerTop/Assets.xcassets" "$APP_BUNDLE/Contents/Resources/Assets.xcassets"

# Compile app icon using iconutil
ICONSET_DIR=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET_DIR"
ICONSET_SRC="$PROJECT_DIR/PowerTop/Assets.xcassets/AppIcon.appiconset"
for f in icon_16x16.png icon_16x16@2x.png icon_32x32.png icon_32x32@2x.png \
         icon_128x128.png icon_128x128@2x.png icon_256x256.png icon_256x256@2x.png \
         icon_512x512.png icon_512x512@2x.png; do
    [ -f "$ICONSET_SRC/$f" ] && cp "$ICONSET_SRC/$f" "$ICONSET_DIR/$f"
done
iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null || true
rm -rf "$ICONSET_DIR"

# Copy localization resources
for lproj in en.lproj zh-Hans.lproj; do
    if [ -d "$PROJECT_DIR/PowerTop/$lproj" ]; then
        mkdir -p "$APP_BUNDLE/Contents/Resources/$lproj"
        cp "$PROJECT_DIR/PowerTop/$lproj/"*.strings "$APP_BUNDLE/Contents/Resources/$lproj/" 2>/dev/null || true
    fi
done

ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "=== Build complete ==="
echo "App bundle: $APP_BUNDLE"
echo "Zip archive: $ZIP_PATH"
echo ""
echo "To run: open \"$APP_BUNDLE\""
echo "Or:     \"$EXECUTABLE\""
