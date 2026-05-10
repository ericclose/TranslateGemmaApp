#!/bin/bash
set -e

APP_NAME="TranslateGemmaApp"
VERSION=${1:-"1.1.1"}
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

# 4. Create PkgInfo (optional but good)
echo "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

# 5. Add /Applications symlink for "Drag to Install"
ln -s /Applications "${BUILD_DIR}/Applications"

# 6. Create DMG
if [ -f "${DMG_NAME}" ]; then rm "${DMG_NAME}"; fi

hdiutil create -volname "${APP_NAME}" -srcfolder "${BUILD_DIR}" -ov -format UDZO "${DMG_NAME}"

echo "DMG created: ${DMG_NAME}"
