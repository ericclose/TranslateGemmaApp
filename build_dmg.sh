#!/bin/bash
set -e

APP_NAME="TranslateGemmaApp"
VERSION=${1:-"1.2.1-beta"}
ARCH=$(uname -m)
DMG_NAME="${APP_NAME}-${ARCH}-v${VERSION}.dmg"

echo "Building ${APP_NAME} v${VERSION} for ${ARCH}..."

# 1. Build release binary
swift build -c release

# 2. Prepare App Bundle structure
BUILD_DIR="build/dmg_root"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

rm -rf build/dmg_root
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# 3. Copy binary
cp ".build/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# 4. Copy Info.plist and Resources
cp "Sources/TranslateGemmaApp/Resources/Info.plist" "${APP_BUNDLE}/Contents/"

echo "Copying resource bundles from dependencies..."
# Find all .bundle directories in the build folder and copy them to Resources
find ".build/release" -name "*.bundle" -exec cp -R {} "${APP_BUNDLE}/Contents/Resources/" \;

# Specifically check for MLX metallib if it's not in a bundle (some versions)
find ".build/release" -name "*.metallib" -exec cp {} "${APP_BUNDLE}/Contents/Resources/" \;

# 5. Ad-hoc sign with entitlements (important for Metal/JIT on Apple Silicon)
ENTITLEMENTS="Sources/TranslateGemmaApp/Resources/TranslateGemmaApp.entitlements"
if [ -f "$ENTITLEMENTS" ]; then
    echo "Signing with entitlements..."
    codesign --force --entitlements "$ENTITLEMENTS" --sign - "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
fi

# 6. Add /Applications symlink for "Drag to Install"
ln -s /Applications "${BUILD_DIR}/Applications"

# 7. Create DMG
if [ -f "${DMG_NAME}" ]; then rm "${DMG_NAME}"; fi

hdiutil create -volname "${APP_NAME}" -srcfolder "${BUILD_DIR}" -ov -format UDZO "${DMG_NAME}"

echo "DMG created: ${DMG_NAME}"
