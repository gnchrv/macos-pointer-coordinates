#!/bin/bash
set -e

APP="PointerCoordinates"
BUNDLE="$APP.app"

# Stop running instance
pkill -x "$APP" 2>/dev/null || true

# Clean previous build
rm -rf "$BUNDLE"

# Create app bundle structure
mkdir -p "$BUNDLE/Contents/MacOS"
mkdir -p "$BUNDLE/Contents/Resources"

# Compile
swiftc -O -o "$BUNDLE/Contents/MacOS/$APP" PointerCoordinates.swift \
    -framework AppKit \
    -framework Foundation

# Write Info.plist (LSUIElement hides the app from the Dock)
cat > "$BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>PointerCoordinates</string>
    <key>CFBundleIdentifier</key>
    <string>io.goncharov.pointer-coordinates</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>PointerCoordinates</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "Built: $BUNDLE"

# Relaunch
open "$BUNDLE"
echo "Launched: $APP"
