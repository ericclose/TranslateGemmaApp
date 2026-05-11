#!/bin/bash
set -e

echo "🛠️  Preparing Development Environment..."

# 1. Compile Metal kernels for MLX
echo "🔥 Compiling Metal kernels..."
mkdir -p build/metal_objects
find .build/checkouts/mlx-swift -name "*.metal" -print0 | xargs -0 -n 1 -P $(sysctl -n hw.ncpu) sh -c '
    FILE="$1"
    OBJ_NAME=$(basename "$FILE").air
    if [ ! -f "build/metal_objects/$OBJ_NAME" ]; then
        xcrun -sdk macosx metal -c "$FILE" -I .build/checkouts/mlx-swift/Source/Cmlx/mlx/ -o "build/metal_objects/$OBJ_NAME"
    fi
' --
xcrun -sdk macosx metallib build/metal_objects/*.air -o "build/default.metallib"

# 2. Copy to .build directories for 'swift run' to work
# We copy to both debug and release to be safe
DEBUG_DIR=".build/arm64-apple-macosx/debug"
RELEASE_DIR=".build/arm64-apple-macosx/release"

if [ -d "$DEBUG_DIR" ]; then
    cp build/default.metallib "$DEBUG_DIR/mlx.metallib"
    echo "✅ Copied mlx.metallib to Debug folder"
fi

if [ -d "$RELEASE_DIR" ]; then
    cp build/default.metallib "$RELEASE_DIR/mlx.metallib"
    echo "✅ Copied mlx.metallib to Release folder"
fi

echo "🚀 Setup complete. You can now run 'swift run Diagnostic' or 'swift run TranslateGemmaApp' without Metal errors."
