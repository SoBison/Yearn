#!/bin/bash
# Build libretro-common static library for iOS ARM64

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
OUTPUT_DIR="$SCRIPT_DIR/static_prefixed"

# Use libretro-common from one of the cores (mupen64plus has a complete version)
LIBRETRO_COMMON_DIR="$BUILD_DIR/mupen64plus-libretro-nx-master/libretro-common"

# iOS SDK settings
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IOS_MIN_VERSION="15.0"

CC="xcrun -sdk iphoneos clang"
AR="xcrun -sdk iphoneos ar"

COMMON_FLAGS="-arch arm64 -isysroot $IOS_SDK -miphoneos-version-min=$IOS_MIN_VERSION -O2 -DIOS -DHAVE_ZLIB"

# Include paths
INCLUDE_FLAGS="-I$LIBRETRO_COMMON_DIR/include"

echo "=== Building libretro-common static library for iOS ARM64 ==="
echo "Source: $LIBRETRO_COMMON_DIR"

# Create temp build directory
TEMP_BUILD="/tmp/libretro_common_build"
rm -rf "$TEMP_BUILD"
mkdir -p "$TEMP_BUILD"

# Source files needed for the missing symbols
SOURCE_FILES=(
    # Memory stream (memstream_*)
    "streams/memory_stream.c"
    # File stream (rf* functions like rfopen, rfclose, rfread, etc.)
    "streams/file_stream.c"
    "streams/file_stream_transforms.c"
    # Dependencies
    "file/file_path.c"
    "file/file_path_io.c"
    "compat/compat_strl.c"
    "compat/compat_strcasestr.c"
    "compat/compat_posix_string.c"
    "compat/fopen_utf8.c"
    "vfs/vfs_implementation.c"
    "string/stdstring.c"
    "encodings/encoding_utf.c"
    "time/rtime.c"
)

echo ""
echo "Compiling source files..."

OBJECT_FILES=""
for src in "${SOURCE_FILES[@]}"; do
    src_path="$LIBRETRO_COMMON_DIR/$src"
    if [ -f "$src_path" ]; then
        obj_name=$(basename "$src" .c).o
        echo "  Compiling: $src"
        $CC $COMMON_FLAGS $INCLUDE_FLAGS -c "$src_path" -o "$TEMP_BUILD/$obj_name" 2>/dev/null || {
            echo "    Warning: Failed to compile $src, skipping..."
            continue
        }
        OBJECT_FILES="$OBJECT_FILES $TEMP_BUILD/$obj_name"
    else
        echo "  Warning: $src not found, skipping..."
    fi
done

# Check if we have any object files
if [ -z "$OBJECT_FILES" ]; then
    echo "Error: No object files compiled!"
    exit 1
fi

# Create static library
OUTPUT_LIB="$OUTPUT_DIR/libretro_common_ios.a"
echo ""
echo "Creating static library: $OUTPUT_LIB"
$AR rcs "$OUTPUT_LIB" $OBJECT_FILES

# Copy to Resources
cp "$OUTPUT_LIB" "$SCRIPT_DIR/../Yearn/Resources/StaticCores/"

# Verify
echo ""
echo "=== Verification ==="
file "$OUTPUT_LIB"
echo ""
echo "Symbols exported:"
nm -g "$OUTPUT_LIB" | grep -E "memstream_|^_rf" | head -20

# Cleanup
rm -rf "$TEMP_BUILD"

echo ""
echo "=== Done! ==="
echo "Library: $OUTPUT_LIB"
echo "Also copied to: $SCRIPT_DIR/../Yearn/Resources/StaticCores/"

