#!/bin/bash

# Build SwanStation for iOS as a static library

set -e

CORES_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$CORES_DIR/build"
OUTPUT_DIR="$CORES_DIR/static_prefixed"
PREFIX_DIR="$CORES_DIR/prefix_headers"

IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IOS_MIN_VERSION="14.0"

SWANSTATION_SRC="$BUILD_DIR/swanstation"
SWANSTATION_BUILD="$BUILD_DIR/swanstation-build-ios"

echo "======================================"
echo "Building SwanStation for iOS"
echo "======================================"
echo "iOS SDK: $IOS_SDK"
echo "Source: $SWANSTATION_SRC"
echo "Build: $SWANSTATION_BUILD"
echo ""

# Create prefix header for swanstation
mkdir -p "$PREFIX_DIR"
cat > "$PREFIX_DIR/prefix_swanstation.h" << 'HEADER'
// Symbol prefix for swanstation core - AUTO GENERATED
#define retro_init swanstation_retro_init
#define retro_deinit swanstation_retro_deinit
#define retro_api_version swanstation_retro_api_version
#define retro_get_system_info swanstation_retro_get_system_info
#define retro_get_system_av_info swanstation_retro_get_system_av_info
#define retro_set_environment swanstation_retro_set_environment
#define retro_set_video_refresh swanstation_retro_set_video_refresh
#define retro_set_audio_sample swanstation_retro_set_audio_sample
#define retro_set_audio_sample_batch swanstation_retro_set_audio_sample_batch
#define retro_set_input_poll swanstation_retro_set_input_poll
#define retro_set_input_state swanstation_retro_set_input_state
#define retro_reset swanstation_retro_reset
#define retro_run swanstation_retro_run
#define retro_load_game swanstation_retro_load_game
#define retro_load_game_special swanstation_retro_load_game_special
#define retro_unload_game swanstation_retro_unload_game
#define retro_serialize_size swanstation_retro_serialize_size
#define retro_serialize swanstation_retro_serialize
#define retro_unserialize swanstation_retro_unserialize
#define retro_get_memory_data swanstation_retro_get_memory_data
#define retro_get_memory_size swanstation_retro_get_memory_size
#define retro_get_region swanstation_retro_get_region
#define retro_cheat_reset swanstation_retro_cheat_reset
#define retro_cheat_set swanstation_retro_cheat_set
#define retro_set_controller_port_device swanstation_retro_set_controller_port_device
HEADER

# Create iOS toolchain file
cat > "$BUILD_DIR/ios-toolchain.cmake" << 'TOOLCHAIN'
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_DEPLOYMENT_TARGET "14.0")

# Find the SDK
execute_process(
    COMMAND xcrun --sdk iphoneos --show-sdk-path
    OUTPUT_VARIABLE CMAKE_OSX_SYSROOT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

set(CMAKE_C_COMPILER xcrun clang)
set(CMAKE_CXX_COMPILER xcrun clang++)

set(CMAKE_C_FLAGS_INIT "-arch arm64 -isysroot ${CMAKE_OSX_SYSROOT} -miphoneos-version-min=14.0")
set(CMAKE_CXX_FLAGS_INIT "-arch arm64 -isysroot ${CMAKE_OSX_SYSROOT} -miphoneos-version-min=14.0")

# Disable code signing for library builds
set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED NO)
set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "")
TOOLCHAIN

# Clean and create build directory
rm -rf "$SWANSTATION_BUILD"
mkdir -p "$SWANSTATION_BUILD"
cd "$SWANSTATION_BUILD"

# Patch zlib to use system zlib instead of bundled one (iOS compatibility)
echo ">>> Patching zlib for iOS..."
# The bundled zlib has iOS compatibility issues, we need to fix them
# Add -Wno-error=deprecated-non-prototype to ignore prototype warnings
EXTRA_C_FLAGS="-Wno-deprecated-non-prototype -Wno-error=deprecated-non-prototype"

# Configure with CMake
echo ">>> Configuring SwanStation..."
cmake "$SWANSTATION_SRC" \
    -DCMAKE_TOOLCHAIN_FILE="$BUILD_DIR/ios-toolchain.cmake" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DCMAKE_C_FLAGS="-include $PREFIX_DIR/prefix_swanstation.h $EXTRA_C_FLAGS" \
    -DCMAKE_CXX_FLAGS="-include $PREFIX_DIR/prefix_swanstation.h" \
    -G "Unix Makefiles"

# Build
echo ">>> Building SwanStation..."
make -j$(sysctl -n hw.ncpu) 2>&1

# Find the output library
echo ">>> Looking for output..."
find . -name "*.dylib" -o -name "*.a" | head -10

echo "======================================"
echo "Build Complete!"
echo "======================================"
