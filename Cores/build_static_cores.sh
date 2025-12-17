#!/bin/bash

# Libretro Cores 静态库编译脚本
# 用于将 libretro cores 编译为 iOS 静态库

set -e

CORES_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$CORES_DIR/build"
OUTPUT_DIR="$CORES_DIR/static"

# iOS SDK 路径
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IOS_MIN_VERSION="17.0"

# 编译器设置 - 不覆盖 CC/CXX，让 Makefile 自己处理
export IOSSDK="$IOS_SDK"

echo "======================================"
echo "Libretro Cores 静态库编译脚本"
echo "======================================"
echo "iOS SDK: $IOS_SDK"
echo "输出目录: $OUTPUT_DIR"
echo ""

mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

# 辅助函数：查找目录（支持带后缀的目录名）
find_dir() {
    local base_name="$1"
    local dir
    
    # 尝试精确匹配
    if [ -d "$BUILD_DIR/$base_name" ]; then
        echo "$BUILD_DIR/$base_name"
        return 0
    fi
    
    # 尝试带 -master 后缀
    if [ -d "$BUILD_DIR/${base_name}-master" ]; then
        echo "$BUILD_DIR/${base_name}-master"
        return 0
    fi
    
    # 尝试带 -develop 后缀
    if [ -d "$BUILD_DIR/${base_name}-develop" ]; then
        echo "$BUILD_DIR/${base_name}-develop"
        return 0
    fi
    
    # 尝试带 -main 后缀
    if [ -d "$BUILD_DIR/${base_name}-main" ]; then
        echo "$BUILD_DIR/${base_name}-main"
        return 0
    fi
    
    echo ""
    return 1
}

# 函数：编译 FCEUmm (NES)
build_fceumm() {
    echo ">>> 编译 FCEUmm (NES)..."
    
    local src_dir=$(find_dir "libretro-fceumm")
    if [ -z "$src_dir" ]; then
        echo "错误: 找不到 libretro-fceumm 源代码目录"
        return 1
    fi
    
    cd "$src_dir"
    
    make -f Makefile.libretro clean || true
    make -f Makefile.libretro \
        platform=ios-arm64 \
        STATIC_LINKING=1 \
        -j$(sysctl -n hw.ncpu)
    
    # 查找生成的静态库文件
    local output_file=$(find . -maxdepth 1 -name "*.a" -o -name "fceumm_libretro_ios.dylib" | head -1)
    if [ -n "$output_file" ]; then
        cp "$output_file" "$OUTPUT_DIR/fceumm_libretro_ios.a"
    fi
    echo "✓ FCEUmm 编译完成"
}

# 函数：编译 Snes9x (SNES)
build_snes9x() {
    echo ">>> 编译 Snes9x (SNES)..."
    
    local src_dir=$(find_dir "snes9x")
    if [ -z "$src_dir" ]; then
        echo "错误: 找不到 snes9x 源代码目录"
        return 1
    fi
    
    cd "$src_dir/libretro"
    
    make clean || true
    make \
        platform=ios-arm64 \
        STATIC_LINKING=1 \
        -j$(sysctl -n hw.ncpu)
    
    local output_file=$(find . -maxdepth 1 -name "*.a" -o -name "snes9x_libretro_ios.dylib" | head -1)
    if [ -n "$output_file" ]; then
        cp "$output_file" "$OUTPUT_DIR/snes9x_libretro_ios.a"
    fi
    echo "✓ Snes9x 编译完成"
}

# 函数：编译 Gambatte (GB/GBC)
build_gambatte() {
    echo ">>> 编译 Gambatte (GB/GBC)..."
    
    local src_dir=$(find_dir "gambatte-libretro")
    if [ -z "$src_dir" ]; then
        echo "错误: 找不到 gambatte-libretro 源代码目录"
        return 1
    fi
    
    cd "$src_dir"
    
    make -f Makefile.libretro clean || true
    make -f Makefile.libretro \
        platform=ios-arm64 \
        STATIC_LINKING=1 \
        -j$(sysctl -n hw.ncpu)
    
    local output_file=$(find . -maxdepth 1 -name "*.a" -o -name "gambatte_libretro_ios.dylib" | head -1)
    if [ -n "$output_file" ]; then
        cp "$output_file" "$OUTPUT_DIR/gambatte_libretro_ios.a"
    fi
    echo "✓ Gambatte 编译完成"
}

# 函数：编译 mGBA (GBA)
build_mgba() {
    echo ">>> 编译 mGBA (GBA)..."
    
    local src_dir=$(find_dir "mgba")
    if [ -z "$src_dir" ]; then
        echo "错误: 找不到 mgba 源代码目录"
        return 1
    fi
    
    cd "$src_dir"
    
    make -f Makefile.libretro clean || true
    make -f Makefile.libretro \
        platform=ios-arm64 \
        STATIC_LINKING=1 \
        -j$(sysctl -n hw.ncpu)
    
    local output_file=$(find . -maxdepth 1 -name "*.a" -o -name "mgba_libretro_ios.dylib" | head -1)
    if [ -n "$output_file" ]; then
        cp "$output_file" "$OUTPUT_DIR/mgba_libretro_ios.a"
    fi
    echo "✓ mGBA 编译完成"
}

# 函数：编译 Genesis Plus GX (Genesis/Mega Drive)
build_genesis_plus_gx() {
    echo ">>> 编译 Genesis Plus GX (Genesis)..."
    
    local src_dir=$(find_dir "Genesis-Plus-GX")
    if [ -z "$src_dir" ]; then
        echo "错误: 找不到 Genesis-Plus-GX 源代码目录"
        return 1
    fi
    
    cd "$src_dir"
    
    make -f Makefile.libretro clean || true
    make -f Makefile.libretro \
        platform=ios-arm64 \
        STATIC_LINKING=1 \
        -j$(sysctl -n hw.ncpu)
    
    local output_file=$(find . -maxdepth 1 -name "*.a" -o -name "genesis_plus_gx_libretro_ios.dylib" | head -1)
    if [ -n "$output_file" ]; then
        cp "$output_file" "$OUTPUT_DIR/genesis_plus_gx_libretro_ios.a"
    fi
    echo "✓ Genesis Plus GX 编译完成"
}

# 函数：编译 melonDS (NDS)
build_melonds() {
    echo ">>> 编译 melonDS (NDS)..."
    
    local src_dir=$(find_dir "melonDS")
    if [ -z "$src_dir" ]; then
        echo "错误: 找不到 melonDS 源代码目录"
        return 1
    fi
    
    cd "$src_dir"
    
    make -f Makefile clean || true
    make -f Makefile \
        platform=ios-arm64 \
        STATIC_LINKING=1 \
        -j$(sysctl -n hw.ncpu)
    
    local output_file=$(find . -maxdepth 1 -name "*.a" -o -name "melonds_libretro_ios.dylib" | head -1)
    if [ -n "$output_file" ]; then
        cp "$output_file" "$OUTPUT_DIR/melonds_libretro_ios.a"
    fi
    echo "✓ melonDS 编译完成"
}

# 函数：编译 Mupen64Plus-Next (N64)
build_mupen64plus() {
    echo ">>> 编译 Mupen64Plus-Next (N64)..."
    
    local src_dir=$(find_dir "mupen64plus-libretro-nx")
    if [ -z "$src_dir" ]; then
        echo "错误: 找不到 mupen64plus-libretro-nx 源代码目录"
        return 1
    fi
    
    cd "$src_dir"
    
    make clean || true
    make \
        platform=ios-arm64 \
        STATIC_LINKING=1 \
        WITH_DYNAREC=arm64 \
        -j$(sysctl -n hw.ncpu)
    
    local output_file=$(find . -maxdepth 1 -name "*.a" -o -name "mupen64plus_next_libretro_ios.dylib" | head -1)
    if [ -n "$output_file" ]; then
        cp "$output_file" "$OUTPUT_DIR/mupen64plus_next_libretro_ios.a"
    fi
    echo "✓ Mupen64Plus-Next 编译完成"
}

# 函数：编译 PCSX ReARMed (PS1)
build_pcsx_rearmed() {
    echo ">>> 编译 PCSX ReARMed (PS1)..."
    
    local src_dir=$(find_dir "pcsx_rearmed")
    if [ -z "$src_dir" ]; then
        echo "错误: 找不到 pcsx_rearmed 源代码目录"
        return 1
    fi
    
    cd "$src_dir"
    
    make -f Makefile.libretro clean || true
    make -f Makefile.libretro \
        platform=ios-arm64 \
        STATIC_LINKING=1 \
        DYNAREC=lightrec \
        -j$(sysctl -n hw.ncpu)
    
    local output_file=$(find . -maxdepth 1 -name "*.a" -o -name "pcsx_rearmed_libretro_ios.dylib" | head -1)
    if [ -n "$output_file" ]; then
        cp "$output_file" "$OUTPUT_DIR/pcsx_rearmed_libretro_ios.a"
    fi
    echo "✓ PCSX ReARMed 编译完成"
}

# 显示帮助
show_help() {
    echo "用法: $0 [核心名称...]"
    echo ""
    echo "可用的核心:"
    echo "  fceumm      - NES (FCEUmm)"
    echo "  snes9x      - SNES (Snes9x)"
    echo "  gambatte    - GB/GBC (Gambatte)"
    echo "  mgba        - GBA (mGBA)"
    echo "  genesis     - Genesis/Mega Drive (Genesis Plus GX)"
    echo "  melonds     - NDS (melonDS)"
    echo "  mupen64plus - N64 (Mupen64Plus-Next)"
    echo "  pcsx        - PS1 (PCSX ReARMed)"
    echo "  all         - 编译所有核心"
    echo ""
    echo "示例:"
    echo "  $0 fceumm gambatte    # 只编译 NES 和 GB/GBC"
    echo "  $0 all                # 编译所有核心"
}

# 主程序
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

for core in "$@"; do
    case "$core" in
        fceumm)
            build_fceumm
            ;;
        snes9x)
            build_snes9x
            ;;
        gambatte)
            build_gambatte
            ;;
        mgba)
            build_mgba
            ;;
        genesis)
            build_genesis_plus_gx
            ;;
        melonds)
            build_melonds
            ;;
        mupen64plus)
            build_mupen64plus
            ;;
        pcsx)
            build_pcsx_rearmed
            ;;
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
        help|--help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "未知核心: $core"
            show_help
            exit 1
            ;;
    esac
done

echo ""
echo "======================================"
echo "编译完成！"
echo "静态库位于: $OUTPUT_DIR"
echo "======================================"
ls -la "$OUTPUT_DIR"
