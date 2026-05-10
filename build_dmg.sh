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

# 3. Manual Metal compilation for MLX
echo "Compiling Metal kernels for MLX in parallel..."
mkdir -p build/metal_objects
find .build/checkouts/mlx-swift -name "*.metal" -print0 | xargs -0 -n 1 -P $(sysctl -n hw.ncpu) sh -c '
    FILE="$1"
    OBJ_NAME=$(basename "$FILE").air
    if [ ! -f "build/metal_objects/$OBJ_NAME" ]; then
        xcrun -sdk macosx metal -c "$FILE" -I .build/checkouts/mlx-swift/Source/Cmlx/mlx/ -o "build/metal_objects/$OBJ_NAME"
    fi
' --
xcrun -sdk macosx metallib build/metal_objects/*.air -o "build/default.metallib"

# 4. Copy binary
cp ".build/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# 5. Copy Info.plist and Resources
cp "Sources/TranslateGemmaApp/Resources/Info.plist" "${APP_BUNDLE}/Contents/"

echo "Copying resource bundles and injecting metallib..."
find ".build/release" -name "*.bundle" -exec cp -R {} "${APP_BUNDLE}/Contents/Resources/" \;

# [IMPORTANT] Inject metallib into EVERY resource bundle to ensure MLX finds it
# This covers cases where MLX is running inside a framework/library bundle
cp "build/default.metallib" "${APP_BUNDLE}/Contents/Resources/default.metallib"
find "${APP_BUNDLE}/Contents/Resources" -name "*.bundle" -type d -exec cp "build/default.metallib" {}/ \;

# 6. Ad-hoc sign
ENTITLEMENTS="Sources/TranslateGemmaApp/Resources/TranslateGemmaApp.entitlements"
if [ -f "$ENTITLEMENTS" ]; then
    echo "Signing with entitlements..."
    codesign --force --entitlements "$ENTITLEMENTS" --sign - "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
fi

# 7. Add /Applications symlink
ln -s /Applications "${BUILD_DIR}/Applications"

# 8. Create DMG
if [ -f "${DMG_NAME}" ]; then rm "${DMG_NAME}"; fi
hdiutil create -volname "${APP_NAME}" -srcfolder "${BUILD_DIR}" -ov -format UDZO "${DMG_NAME}"

echo "DMG created: ${DMG_NAME}"
