#!/bin/bash

# bsnes iOS 静态库编译脚本
# 使用符号前缀避免与其他核心冲突

set -e

CORES_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$CORES_DIR/build/bsnes-libretro"
OUTPUT_DIR="$CORES_DIR/static_prefixed"
PREFIX_HEADER="$CORES_DIR/prefix_headers/prefix_bsnes.h"

# iOS SDK 路径
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IOS_MIN_VERSION="17.0"

echo "======================================"
echo "bsnes iOS 静态库编译脚本"
echo "======================================"
echo "iOS SDK: $IOS_SDK"
echo "输出目录: $OUTPUT_DIR"
echo ""

mkdir -p "$OUTPUT_DIR"

if [ ! -d "$BUILD_DIR" ]; then
    echo "错误: 找不到 bsnes 源代码目录"
    echo "请先运行: git clone --branch libretro https://github.com/libretro/bsnes-libretro.git $BUILD_DIR"
    exit 1
fi

cd "$BUILD_DIR"

echo ">>> 清理旧构建..."
make clean || true

echo ">>> 编译 bsnes (SNES)..."

# 使用前缀头文件编译
make platform=ios-arm64 \
    STATIC_LINKING=1 \
    CFLAGS="-include $PREFIX_HEADER" \
    CXXFLAGS="-include $PREFIX_HEADER" \
    -j$(sysctl -n hw.ncpu)

# 复制到输出目录
if [ -f "bsnes_libretro_ios.dylib" ]; then
    cp "bsnes_libretro_ios.dylib" "$OUTPUT_DIR/bsnes_libretro_ios.a"
    echo "✓ bsnes 编译完成"
    echo "静态库已保存到: $OUTPUT_DIR/bsnes_libretro_ios.a"
else
    echo "错误: 未找到编译输出文件"
    exit 1
fi

echo ""
echo "======================================"
echo "编译完成！"
echo "======================================"
ls -la "$OUTPUT_DIR/bsnes_libretro_ios.a"

