#!/bin/bash
set -e

APP_NAME="TranslateGemmaApp"
VERSION=${1:-"1.2.1-beta"}
ARCH=$(uname -m)
DMG_NAME="${APP_NAME}-${ARCH}-v${VERSION}.dmg"

# --- High Precision Timing Utility (using perl for ms on macOS) ---
declare -a STEP_NAMES
declare -a STEP_TIMES

function get_time() {
    perl -MTime::HiRes=time -e 'printf "%.3f\n", time'
}

TOTAL_START=$(get_time)

function record_step() {
    local name=$1
    local start=$2
    local end=$(get_time)
    # Calculate duration with 2 decimal places
    local duration=$(perl -e "printf '%.2f', $end - $start")
    STEP_NAMES+=("$name")
    STEP_TIMES+=("$duration")
}

echo "🚀 Starting Build for ${APP_NAME} v${VERSION} (${ARCH})..."

# 1. Build release binary
echo "📦 Step 1: Running Swift Build (Release)..."
S1_START=$(get_time)
swift build -c release
record_step "Swift Compilation (Release)" "$S1_START"

# 2. Prepare App Bundle structure
echo "📂 Step 2: Preparing App Bundle structure..."
S2_START=$(get_time)
BUILD_DIR="build/dmg_root"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
rm -rf build/dmg_root
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
record_step "Bundle Structure Setup" "$S2_START"

# 3. Manual Metal compilation for MLX
echo "🔥 Step 3: Compiling Metal kernels in parallel..."
S3_START=$(get_time)
mkdir -p build/metal_objects
find .build/checkouts/mlx-swift -name "*.metal" -print0 | xargs -0 -n 1 -P $(sysctl -n hw.ncpu) sh -c '
    FILE="$1"
    OBJ_NAME=$(basename "$FILE").air
    if [ ! -f "build/metal_objects/$OBJ_NAME" ]; then
        xcrun -sdk macosx metal -c "$FILE" -I .build/checkouts/mlx-swift/Source/Cmlx/mlx/ -o "build/metal_objects/$OBJ_NAME"
    fi
' --
xcrun -sdk macosx metallib build/metal_objects/*.air -o "build/default.metallib"
record_step "Metal Kernel Compilation" "$S3_START"

# 4. Copy binary and Resources
echo "🚚 Step 4: Copying binaries and resources..."
S4_START=$(get_time)
cp ".build/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
cp "Sources/TranslateGemmaApp/Resources/Info.plist" "${APP_BUNDLE}/Contents/"
cp "build/default.metallib" "${APP_BUNDLE}/Contents/Resources/"
if [ ! -f "${APP_BUNDLE}/Contents/Resources/default.metallib" ]; then
    echo "❌ Error: metallib failed to copy."
    exit 1
fi
record_step "Resource Bundling & Injection" "$S4_START"

# 5. Deep Sign the entire bundle
echo "🔏 Step 5: Performing Deep Recursive Signing..."
S5_START=$(get_time)
ENTITLEMENTS="Sources/TranslateGemmaApp/Resources/TranslateGemmaApp.entitlements"
if [ -f "$ENTITLEMENTS" ]; then
    codesign --force --sign - "${APP_BUNDLE}/Contents/Resources/default.metallib"
    codesign --force --entitlements "$ENTITLEMENTS" --timestamp --options runtime --sign - "${APP_BUNDLE}"
fi
record_step "Code Signing (Deep)" "$S5_START"

# 6. Create DMG
echo "💿 Step 6: Creating DMG Disk Image..."
S6_START=$(get_time)
ln -s /Applications "${BUILD_DIR}/Applications"
if [ -f "${DMG_NAME}" ]; then rm "${DMG_NAME}"; fi
hdiutil create -volname "${APP_NAME}" -srcfolder "${BUILD_DIR}" -ov -format UDZO "${DMG_NAME}" > /dev/null
record_step "DMG Image Creation" "$S6_START"

TOTAL_END=$(get_time)
TOTAL_DURATION=$(perl -e "printf '%.2f', $TOTAL_END - $TOTAL_START")

# --- FINAL PERFORMANCE REPORT ---
echo ""
echo "==========================================="
echo "📊 BUILD PERFORMANCE REPORT (Precision)"
echo "==========================================="
printf "%-30s %-10s\n" "Step Description" "Duration"
printf "%-30s %-10s\n" "------------------------------" "----------"
for i in "${!STEP_NAMES[@]}"; do
    printf "%-30s %-10ss\n" "${STEP_NAMES[$i]}" "${STEP_TIMES[$i]}"
done
echo "-------------------------------------------"
echo "⏱️  TOTAL TIME: ${TOTAL_DURATION}s"
echo "==========================================="
echo "🎉 SUCCESS: ${DMG_NAME} created!"
