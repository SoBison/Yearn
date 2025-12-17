#!/bin/bash

# Build script for iOS static libretro cores with prefixed symbols
# This allows multiple cores to be linked into the same binary

set -e

CORES_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$CORES_DIR/build"
OUTPUT_DIR="$CORES_DIR/static_prefixed"
PREFIX_DIR="$CORES_DIR/prefix_headers"

IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IOS_MIN_VERSION="14.0"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$PREFIX_DIR"

echo "======================================"
echo "Building iOS Static Cores with Prefixed Symbols"
echo "======================================"
echo "iOS SDK: $IOS_SDK"
echo "Output: $OUTPUT_DIR"
echo ""

# Function to create prefix header for a core
create_prefix_header() {
    local PREFIX=$1
    local HEADER_FILE="$PREFIX_DIR/prefix_${PREFIX}.h"
    
    cat > "$HEADER_FILE" << EOF
// Symbol prefix for ${PREFIX} core - AUTO GENERATED
#define retro_init ${PREFIX}_retro_init
#define retro_deinit ${PREFIX}_retro_deinit
#define retro_api_version ${PREFIX}_retro_api_version
#define retro_get_system_info ${PREFIX}_retro_get_system_info
#define retro_get_system_av_info ${PREFIX}_retro_get_system_av_info
#define retro_set_environment ${PREFIX}_retro_set_environment
#define retro_set_video_refresh ${PREFIX}_retro_set_video_refresh
#define retro_set_audio_sample ${PREFIX}_retro_set_audio_sample
#define retro_set_audio_sample_batch ${PREFIX}_retro_set_audio_sample_batch
#define retro_set_input_poll ${PREFIX}_retro_set_input_poll
#define retro_set_input_state ${PREFIX}_retro_set_input_state
#define retro_reset ${PREFIX}_retro_reset
#define retro_run ${PREFIX}_retro_run
#define retro_load_game ${PREFIX}_retro_load_game
#define retro_load_game_special ${PREFIX}_retro_load_game_special
#define retro_unload_game ${PREFIX}_retro_unload_game
#define retro_serialize_size ${PREFIX}_retro_serialize_size
#define retro_serialize ${PREFIX}_retro_serialize
#define retro_unserialize ${PREFIX}_retro_unserialize
#define retro_get_memory_data ${PREFIX}_retro_get_memory_data
#define retro_get_memory_size ${PREFIX}_retro_get_memory_size
#define retro_get_region ${PREFIX}_retro_get_region
#define retro_cheat_reset ${PREFIX}_retro_cheat_reset
#define retro_cheat_set ${PREFIX}_retro_cheat_set
#define retro_set_controller_port_device ${PREFIX}_retro_set_controller_port_device
EOF
    
    echo "$HEADER_FILE"
}

# Function to create compiler wrapper
create_wrapper() {
    local PREFIX=$1
    local HEADER_FILE=$(create_prefix_header "$PREFIX")
    
    cat > /tmp/cc_${PREFIX}.sh << EOF
#!/bin/bash
exec xcrun -sdk iphoneos clang -include "$HEADER_FILE" "\$@"
EOF
    
    cat > /tmp/cxx_${PREFIX}.sh << EOF
#!/bin/bash
exec xcrun -sdk iphoneos clang++ -include "$HEADER_FILE" "\$@"
EOF
    
    chmod +x /tmp/cc_${PREFIX}.sh /tmp/cxx_${PREFIX}.sh
}

# Function to find directory
find_dir() {
    local base_name="$1"
    for suffix in "" "-master" "-develop" "-main"; do
        if [ -d "$BUILD_DIR/${base_name}${suffix}" ]; then
            echo "$BUILD_DIR/${base_name}${suffix}"
            return 0
        fi
    done
    echo ""
    return 1
}

# Build FCEUmm (NES)
build_fceumm() {
    echo ">>> Building FCEUmm (NES)..."
    local PREFIX="fceumm"
    create_wrapper "$PREFIX"
    
    local src_dir=$(find_dir "libretro-fceumm")
    if [ -z "$src_dir" ]; then
        echo "Error: libretro-fceumm not found"
        return 1
    fi
    
    cd "$src_dir"
    export IOSSDK="$IOS_SDK"
    
    make -f Makefile.libretro clean 2>/dev/null || true
    make -f Makefile.libretro \
        platform=ios-arm64 \
        STATIC_LINKING=1 \
        CC="/tmp/cc_${PREFIX}.sh -arch arm64 -isysroot $IOS_SDK" \
        CXX="/tmp/cxx_${PREFIX}.sh -arch arm64 -isysroot $IOS_SDK" \
        -j$(sysctl -n hw.ncpu)
    
    local output=$(find . -maxdepth 1 -name "*.a" -o -name "*_libretro_ios.dylib" | head -1)
    if [ -n "$output" ]; then
        cp "$output" "$OUTPUT_DIR/${PREFIX}_libretro_ios.a"
        echo "✓ FCEUmm built successfully"
    fi
}

# Build Snes9x (SNES)
build_snes9x() {
    echo ">>> Building Snes9x (SNES)..."
    local PREFIX="snes9x"
    create_wrapper "$PREFIX"
    
    local src_dir=$(find_dir "snes9x")
    if [ -z "$src_dir" ]; then
        echo "Error: snes9x not found"
        return 1
    fi
    
    cd "$src_dir/libretro"
    export IOSSDK="$IOS_SDK"
    
    make clean 2>/dev/null || true
    make \
        platform=ios-arm64 \
        STATIC_LINKING=1 \
        CC="/tmp/cc_${PREFIX}.sh -arch arm64 -isysroot $IOS_SDK" \
        CXX="/tmp/cxx_${PREFIX}.sh -arch arm64 -isysroot $IOS_SDK" \
        -j$(sysctl -n hw.ncpu)
    
    local output=$(find . -maxdepth 1 -name "*.a" -o -name "*_libretro_ios.dylib" | head -1)
    if [ -n "$output" ]; then
        cp "$output" "$OUTPUT_DIR/${PREFIX}_libretro_ios.a"
        echo "✓ Snes9x built successfully"
    fi
}

# Build Gambatte (GB/GBC)
build_gambatte() {
    echo ">>> Building Gambatte (GB/GBC)..."
    local PREFIX="gambatte"
    create_wrapper "$PREFIX"
    
    local src_dir=$(find_dir "gambatte-libretro")
    if [ -z "$src_dir" ]; then
        echo "Error: gambatte-libretro not found"
        return 1
    fi
    
    cd "$src_dir"
    export IOSSDK="$IOS_SDK"
    
    make -f Makefile.libretro clean 2>/dev/null || true
    make -f Makefile.libretro \
        platform=ios-arm64 \
        STATIC_LINKING=1 \
        CC="/tmp/cc_${PREFIX}.sh -arch arm64 -isysroot $IOS_SDK" \
        CXX="/tmp/cxx_${PREFIX}.sh -arch arm64 -isysroot $IOS_SDK" \
        -j$(sysctl -n hw.ncpu)
    
    local output=$(find . -maxdepth 1 -name "*.a" -o -name "*_libretro_ios.dylib" | head -1)
    if [ -n "$output" ]; then
        cp "$output" "$OUTPUT_DIR/${PREFIX}_libretro_ios.a"
        echo "✓ Gambatte built successfully"
    fi
}

# Build mGBA (GBA)
build_mgba() {
    echo ">>> Building mGBA (GBA)..."
    local PREFIX="mgba"
    create_wrapper "$PREFIX"
    
    local src_dir=$(find_dir "mgba")
    if [ -z "$src_dir" ]; then
        echo "Error: mgba not found"
        return 1
    fi
    
    cd "$src_dir"
    export IOSSDK="$IOS_SDK"
    
    make -f Makefile.libretro clean 2>/dev/null || true
    make -f Makefile.libretro \
        platform=ios-arm64 \
        STATIC_LINKING=1 \
        CC="/tmp/cc_${PREFIX}.sh -arch arm64 -isysroot $IOS_SDK" \
        CXX="/tmp/cxx_${PREFIX}.sh -arch arm64 -isysroot $IOS_SDK" \
        -j$(sysctl -n hw.ncpu)
    
    local output=$(find . -maxdepth 1 -name "*.a" -o -name "*_libretro_ios.dylib" | head -1)
    if [ -n "$output" ]; then
        cp "$output" "$OUTPUT_DIR/${PREFIX}_libretro_ios.a"
        echo "✓ mGBA built successfully"
    fi
}

# Build Genesis Plus GX (Genesis/Mega Drive)
build_genesis_plus_gx() {
    echo ">>> Building Genesis Plus GX (Genesis)..."
    local PREFIX="genesis_plus_gx"
    create_wrapper "$PREFIX"
    
    local src_dir=$(find_dir "Genesis-Plus-GX")
    if [ -z "$src_dir" ]; then
        echo "Error: Genesis-Plus-GX not found"
        return 1
    fi
    
    cd "$src_dir"
    export IOSSDK="$IOS_SDK"
    
    make -f Makefile.libretro clean 2>/dev/null || true
    make -f Makefile.libretro \
        platform=ios-arm64 \
        STATIC_LINKING=1 \
        CC="/tmp/cc_${PREFIX}.sh -arch arm64 -isysroot $IOS_SDK" \
        CXX="/tmp/cxx_${PREFIX}.sh -arch arm64 -isysroot $IOS_SDK" \
        -j$(sysctl -n hw.ncpu)
    
    local output=$(find . -maxdepth 1 -name "*.a" -o -name "*_libretro_ios.dylib" | head -1)
    if [ -n "$output" ]; then
        cp "$output" "$OUTPUT_DIR/${PREFIX}_libretro_ios.a"
        echo "✓ Genesis Plus GX built successfully"
    fi
}

# Build melonDS (NDS)
build_melonds() {
    echo ">>> Building melonDS (NDS)..."
    local PREFIX="melonds"
    create_wrapper "$PREFIX"
    
    local src_dir=$(find_dir "melonDS")
    if [ -z "$src_dir" ]; then
        echo "Error: melonDS not found"
        return 1
    fi
    
    cd "$src_dir"
    export IOSSDK="$IOS_SDK"
    
    make -f Makefile clean 2>/dev/null || true
    make -f Makefile \
        platform=ios-arm64 \
        STATIC_LINKING=1 \
        CC="/tmp/cc_${PREFIX}.sh -arch arm64 -isysroot $IOS_SDK" \
        CXX="/tmp/cxx_${PREFIX}.sh -arch arm64 -isysroot $IOS_SDK" \
        -j$(sysctl -n hw.ncpu)
    
    local output=$(find . -maxdepth 1 -name "*.a" -o -name "*_libretro_ios.dylib" | head -1)
    if [ -n "$output" ]; then
        cp "$output" "$OUTPUT_DIR/${PREFIX}_libretro_ios.a"
        echo "✓ melonDS built successfully"
    fi
}

# Build Mupen64Plus-Next (N64)
build_mupen64plus() {
    echo ">>> Building Mupen64Plus-Next (N64)..."
    local PREFIX="mupen64plus_next"
    create_wrapper "$PREFIX"
    
    local src_dir=$(find_dir "mupen64plus-libretro-nx")
    if [ -z "$src_dir" ]; then
        echo "Error: mupen64plus-libretro-nx not found"
        return 1
    fi
    
    cd "$src_dir"
    export IOSSDK="$IOS_SDK"
    
    make clean 2>/dev/null || true
    make \
        platform=ios-arm64 \
        STATIC_LINKING=1 \
        SYSTEM_ZLIB=1 \
        WITH_DYNAREC=arm64 \
        CC="/tmp/cc_${PREFIX}.sh -arch arm64 -isysroot $IOS_SDK" \
        CXX="/tmp/cxx_${PREFIX}.sh -arch arm64 -isysroot $IOS_SDK" \
        -j$(sysctl -n hw.ncpu)
    
    local output=$(find . -maxdepth 1 -name "*.a" -o -name "*_libretro_ios.dylib" | head -1)
    if [ -n "$output" ]; then
        cp "$output" "$OUTPUT_DIR/${PREFIX}_libretro_ios.a"
        echo "✓ Mupen64Plus-Next built successfully"
    fi
}

# Build PCSX ReARMed (PS1)
build_pcsx_rearmed() {
    echo ">>> Building PCSX ReARMed (PS1)..."
    local PREFIX="pcsx_rearmed"
    create_wrapper "$PREFIX"
    
    local src_dir=$(find_dir "pcsx_rearmed")
    if [ -z "$src_dir" ]; then
        echo "Error: pcsx_rearmed not found"
        return 1
    fi
    
    cd "$src_dir"
    export IOSSDK="$IOS_SDK"
    
    # 确保 config.h 存在（make clean 可能会删除它）
    if [ ! -f "config.h" ] && [ -f "include/config.h" ]; then
        cp include/config.h .
    fi
    
    # 修复 zlib gzguts.h 缺少 unistd.h 的问题
    # 这会导致 read/write/lseek/close 函数未声明
    local GZGUTS_FILE="deps/libchdr/deps/zlib-1.3.1/gzguts.h"
    if [ -f "$GZGUTS_FILE" ]; then
        if ! grep -q "unistd.h" "$GZGUTS_FILE"; then
            echo ">>> Patching gzguts.h to include unistd.h..."
            # 在 #include <fcntl.h> 后添加 #include <unistd.h>
            sed -i '' 's/#include <fcntl.h>/#include <fcntl.h>\n#include <unistd.h>/' "$GZGUTS_FILE"
        fi
    fi
    
    # 注意: psxmem.c 已在源码中修复，当 P_HAVE_MMAP=0 时跳过地址检查
    
    make -f Makefile.libretro clean 2>/dev/null || true
    
    # 彻底清理所有 .o 文件，特别是 dynarec 相关的
    # 这些文件在 DRC_DISABLE 模式下不应该存在
    find . -name "*.o" -type f -delete 2>/dev/null || true
    rm -f pcsx_rearmed_libretro*.dylib pcsx_rearmed_libretro*.a 2>/dev/null || true
    
    # 再次确保 config.h 存在（clean 后）
    if [ ! -f "config.h" ] && [ -f "include/config.h" ]; then
        cp include/config.h .
    fi
    
    # 注意：iOS 上需要禁用动态重编译器以避免 ptrace 崩溃
    # DYNAREC=0 使用解释器模式（性能较低但稳定）
    # 添加 -DTVOS 跳过 ptrace 系统调用
    # 添加 include 路径确保能找到所有头文件
    local PCSX_INCLUDES="-I$(pwd) -I$(pwd)/include -I$(pwd)/libpcsxcore"
    # libchdr 需要的额外 include 路径
    local LIBCHDR_INCLUDES="-I$(pwd)/deps/libchdr/include -I$(pwd)/deps/libchdr/deps/lzma-24.05/include -I$(pwd)/deps/libchdr/deps/zstd-1.5.6/lib -I$(pwd)/deps/libretro-common/include"
    local ALL_INCLUDES="$PCSX_INCLUDES $LIBCHDR_INCLUDES"
    # Z7_ST 启用 LZMA 单线程模式，避免需要 LzFindMt.h
    # NO_FRONTEND 禁用前端 UI（libretro 模式不需要）
    # DRC_DISABLE 禁用动态重编译器（iOS 上必须禁用以避免 ptrace 崩溃）
    # P_HAVE_MMAP=0 禁用 mmap，使用 calloc 分配内存（iOS 上更安全）
    # DISABLE_MEM_LUTS=1 禁用内存查找表，使用直接内存访问（避免 LUT 初始化问题）
    # SIMD_BUILD 启用 GPU NEON SIMD 优化（gpu_neon 需要这个）
    # HAVE_ARMV8 启用 ARM64 优化
    local EXTRA_DEFINES="-DTVOS -DZ7_ST -DSIMD_BUILD -DNO_FRONTEND -DDRC_DISABLE -DHAVE_ARMV8 -D__ARM_NEON__ -DP_HAVE_MMAP=0 -DDISABLE_MEM_LUTS=1"
    
    make -f Makefile.libretro \
        platform=ios-arm64 \
        STATIC_LINKING=1 \
        DYNAREC=0 \
        NO_MMAP=1 \
        CFLAGS="$EXTRA_DEFINES $ALL_INCLUDES" \
        CC="/tmp/cc_${PREFIX}.sh -arch arm64 -isysroot $IOS_SDK $EXTRA_DEFINES $ALL_INCLUDES" \
        CXX="/tmp/cxx_${PREFIX}.sh -arch arm64 -isysroot $IOS_SDK $EXTRA_DEFINES $ALL_INCLUDES" \
        -j$(sysctl -n hw.ncpu)
    
    local output=$(find . -maxdepth 1 -name "*.a" -o -name "*_libretro_ios.dylib" | head -1)
    if [ -n "$output" ]; then
        cp "$output" "$OUTPUT_DIR/${PREFIX}_libretro_ios.a"
        echo "✓ PCSX ReARMed built successfully"
    fi
}

# Main
show_help() {
    echo "Usage: $0 [core...]"
    echo ""
    echo "Available cores:"
    echo "  fceumm      - NES"
    echo "  snes9x      - SNES"
    echo "  gambatte    - GB/GBC"
    echo "  mgba        - GBA"
    echo "  genesis     - Genesis/Mega Drive"
    echo "  melonds     - NDS"
    echo "  mupen64plus - N64"
    echo "  pcsx        - PS1"
    echo "  all         - Build all cores"
}

if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

for core in "$@"; do
    case "$core" in
        fceumm) build_fceumm ;;
        snes9x) build_snes9x ;;
        gambatte) build_gambatte ;;
        mgba) build_mgba ;;
        genesis) build_genesis_plus_gx ;;
        melonds) build_melonds ;;
        mupen64plus) build_mupen64plus ;;
        pcsx) build_pcsx_rearmed ;;
        all)
            build_fceumm
            build_snes9x
            build_gambatte
            build_mgba
            build_genesis_plus_gx
            build_melonds
            build_mupen64plus
            build_pcsx_rearmed
            ;;
        help|--help|-h) show_help; exit 0 ;;
        *) echo "Unknown core: $core"; show_help; exit 1 ;;
    esac
done

echo ""
echo "======================================"
echo "Build Complete!"
echo "======================================"
ls -la "$OUTPUT_DIR"

echo ""
echo "Verifying symbol prefixes..."
for lib in "$OUTPUT_DIR"/*.a; do
    name=$(basename "$lib" .a | sed 's/_libretro_ios//')
    count=$(nm "$lib" 2>/dev/null | grep " T " | grep "${name}_retro_" | wc -l)
    echo "  $name: $count prefixed symbols"
done
