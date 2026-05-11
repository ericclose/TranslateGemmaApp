#!/bin/bash
set -e

# Copy to .build directories for 'swift run' to work
# We copy to both debug and release to be safe
DEBUG_DIR=".build/arm64-apple-macosx/debug"

if [ -d "$DEBUG_DIR" ]; then
    cp build/default.metallib "$DEBUG_DIR/mlx.metallib"
    echo "✅ Copied mlx.metallib to Debug folder"
fi

echo "🚀 Setup complete. You can now run 'swift run Diagnostic' without Metal errors."

swift run Diagnostic
