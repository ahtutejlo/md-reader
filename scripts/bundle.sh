#!/bin/bash
set -euo pipefail

APP_NAME="MDReader"
BUNDLE_DIR=".build/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

# Build
swift build

# Create .app bundle structure
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}" "${CONTENTS_DIR}/Resources"

# Copy executable
cp .build/debug/MDReaderApp "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist and add required bundle keys
cat > "${CONTENTS_DIR}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MDReader</string>
    <key>CFBundleIdentifier</key>
    <string>com.mdreader.app</string>
    <key>CFBundleName</key>
    <string>MDReader</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.mdreader.open</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>mdreader</string>
            </array>
        </dict>
    </array>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
PLIST

# Copy icon
cp Sources/MDReaderApp/Resources/AppIcon.icns "${CONTENTS_DIR}/Resources/"

echo "Built: ${BUNDLE_DIR}"
echo "Run:   open ${BUNDLE_DIR}"
