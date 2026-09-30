#!/bin/bash
set -euo pipefail

APP_NAME="MDReader"
CONFIG="${CONFIG:-debug}"
MIN_MACOS="14.0"
BUNDLE_DIR=".build/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

# swiftbuild stamps the deployment target as the SDK version, which gives the app
# macOS's legacy pre-26 look; hand the linker the real SDK version instead.
swift build -c "${CONFIG}" -Xlinker -platform_version -Xlinker macos \
    -Xlinker "${MIN_MACOS}" -Xlinker "$(xcrun --sdk macosx --show-sdk-version)"

# Create .app bundle structure
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}" "${CONTENTS_DIR}/Resources"

# Copy executable and its SwiftPM resource bundle (Bundle.module looks in Contents/Resources)
cp ".build/${CONFIG}/MDReaderApp" "${MACOS_DIR}/${APP_NAME}"
cp -R ".build/${CONFIG}/MDReader_MDReaderApp.bundle" "${CONTENTS_DIR}/Resources/"

# Copy Info.plist and add required bundle keys
cat > "${CONTENTS_DIR}/Info.plist" << PLIST
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
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Markdown Document</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>net.daringfireball.markdown</string>
            </array>
        </dict>
    </array>
    <key>UTImportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>net.daringfireball.markdown</string>
            <key>UTTypeDescription</key>
            <string>Markdown Document</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.plain-text</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>md</string>
                    <string>markdown</string>
                    <string>mdown</string>
                    <string>mkdn</string>
                    <string>mkd</string>
                </array>
                <key>public.mime-type</key>
                <array>
                    <string>text/markdown</string>
                </array>
            </dict>
        </dict>
    </array>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS}</string>
</dict>
</plist>
PLIST

# Copy icon
cp Sources/MDReaderApp/Resources/AppIcon.icns "${CONTENTS_DIR}/Resources/"

echo "Built: ${BUNDLE_DIR}"
echo "Run:   open ${BUNDLE_DIR}"
