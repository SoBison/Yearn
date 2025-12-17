#!/bin/bash
# Build libretro cores for iOS Simulator (x86_64 + arm64)

set -e

CORES_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$CORES_DIR/simulator_build"
OUTPUT_DIR="$CORES_DIR/simulator"

mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

# Clone and build Gambatte (GB/GBC)
echo "Building Gambatte for simulator..."
cd "$BUILD_DIR"

if [ ! -d "gambatte-libretro" ]; then
    git clone --depth 1 https://github.com/libretro/gambatte-libretro.git
fi

cd gambatte-libretro

# Build for x86_64 simulator
make clean || true
make platform=ios-sim -j$(sysctl -n hw.ncpu)

if [ -f "gambatte_libretro_ios.dylib" ]; then
    cp gambatte_libretro_ios.dylib "$OUTPUT_DIR/"
    echo "✅ Built gambatte for simulator"
fi

echo "Done! Simulator cores are in: $OUTPUT_DIR"
