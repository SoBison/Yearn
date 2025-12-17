#!/bin/bash
# Build libretro cores as static libraries for iOS ARM64
# Uses libretro-super source code but with corrected compiler flags

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIBRETRO_SUPER="$SCRIPT_DIR/libretro-super"
OUTPUT_DIR="$SCRIPT_DIR/static_official"

# iOS SDK settings
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IOS_MIN_VERSION="15.0"

# Compiler settings (no -marm or -mno-thumb for arm64)
export CC="xcrun -sdk iphoneos clang -arch arm64 -isysroot $IOS_SDK -miphoneos-version-min=$IOS_MIN_VERSION"
export CXX="xcrun -sdk iphoneos clang++ -arch arm64 -isysroot $IOS_SDK -miphoneos-version-min=$IOS_MIN_VERSION -stdlib=libc++"
export AR="xcrun -sdk iphoneos ar"
export RANLIB="xcrun -sdk iphoneos ranlib"

mkdir -p "$OUTPUT_DIR"

build_core() {
    local CORE_NAME=$1
    local CORE_DIR=$2
    local MAKEFILE=${3:-Makefile.libretro}
    local EXTRA_FLAGS=${4:-}
    
    echo ""
    echo "=========================================="
    echo "Building $CORE_NAME"
    echo "=========================================="
    
    if [ ! -d "$CORE_DIR" ]; then
        echo "Error: Core directory not found: $CORE_DIR"
        return 1
    fi
    
    cd "$CORE_DIR"
    
    # Clean
    make -f "$MAKEFILE" clean 2>/dev/null || true
    
    # Build with static linking
    make -f "$MAKEFILE" \
        platform=ios-arm64 \
        STATIC_LINKING=1 \
        IOSSDK="$IOS_SDK" \
        CC="$CC" \
        CXX="$CXX" \
        AR="$AR" \
        $EXTRA_FLAGS \
        -j$(sysctl -n hw.ncpu) 2>&1 | tail -20
    
    # Find the output file
    local OUTPUT_FILE=$(find . -maxdepth 1 -name "*.a" -o -name "*_libretro*.dylib" 2>/dev/null | head -1)
    
    if [ -n "$OUTPUT_FILE" ]; then
        # Check if it's a static library
        if file "$OUTPUT_FILE" | grep -q "ar archive"; then
            cp "$OUTPUT_FILE" "$OUTPUT_DIR/${CORE_NAME}_libretro_ios.a"
            echo "✅ Built: ${CORE_NAME}_libretro_ios.a"
        else
            echo "⚠️  Output is not a static library, converting..."
            # Extract objects and create static library
            local TEMP_DIR="/tmp/${CORE_NAME}_objs"
            rm -rf "$TEMP_DIR"
            mkdir -p "$TEMP_DIR"
            find . -name "*.o" -exec cp {} "$TEMP_DIR/" \;
            $AR rcs "$OUTPUT_DIR/${CORE_NAME}_libretro_ios.a" "$TEMP_DIR"/*.o
            rm -rf "$TEMP_DIR"
            echo "✅ Built: ${CORE_NAME}_libretro_ios.a (from objects)"
        fi
    else
        echo "❌ Failed to build $CORE_NAME"
        return 1
    fi
}

# Fetch cores if not present
fetch_core() {
    local CORE_NAME=$1
    cd "$LIBRETRO_SUPER"
    if [ ! -d "libretro-$CORE_NAME" ]; then
        echo "Fetching $CORE_NAME..."
        ./libretro-fetch.sh $CORE_NAME 2>&1 | tail -5
    fi
}

echo "=== Building libretro cores for iOS ARM64 (Static) ==="
echo "iOS SDK: $IOS_SDK"
echo "Output: $OUTPUT_DIR"

# Build gambatte (GB/GBC)
fetch_core gambatte
build_core gambatte "$LIBRETRO_SUPER/libretro-gambatte"

# Build fceumm (NES)
fetch_core fceumm
build_core fceumm "$LIBRETRO_SUPER/libretro-fceumm"

# Build snes9x (SNES)
fetch_core snes9x
build_core snes9x "$LIBRETRO_SUPER/libretro-snes9x/libretro"

# Build mgba (GBA)
fetch_core mgba
build_core mgba "$LIBRETRO_SUPER/libretro-mgba"

# Build genesis_plus_gx (Genesis/Mega Drive)
fetch_core genesis_plus_gx
build_core genesis_plus_gx "$LIBRETRO_SUPER/libretro-genesis_plus_gx"

echo ""
echo "=== Build Complete ==="
echo "Static libraries in: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"

