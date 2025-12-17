#!/bin/bash
# 将 libretro .dylib 封装成 iOS Framework
# 用法: ./create_framework.sh <dylib_path> <core_name>
# 示例: ./create_framework.sh gambatte_libretro_ios.dylib gambatte

set -e

DYLIB_PATH="$1"
CORE_NAME="$2"

if [ -z "$DYLIB_PATH" ] || [ -z "$CORE_NAME" ]; then
    echo "用法: $0 <dylib_path> <core_name>"
    echo "示例: $0 gambatte_libretro_ios.dylib gambatte"
    exit 1
fi

if [ ! -f "$DYLIB_PATH" ]; then
    echo "错误: 找不到文件 $DYLIB_PATH"
    exit 1
fi

# Framework 名称（使用点分隔符以匹配 RetroArch 的命名方式）
FRAMEWORK_NAME="${CORE_NAME}.libretro"
FRAMEWORK_DIR="${FRAMEWORK_NAME}.framework"
OUTPUT_DIR="$(dirname "$0")/Frameworks"

echo "======================================"
echo "创建 Framework: $FRAMEWORK_NAME"
echo "======================================"

# 创建输出目录
mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/$FRAMEWORK_DIR"

# 复制二进制文件
cp "$DYLIB_PATH" "$OUTPUT_DIR/$FRAMEWORK_DIR/$FRAMEWORK_NAME"

# 设置执行权限
chmod +x "$OUTPUT_DIR/$FRAMEWORK_DIR/$FRAMEWORK_NAME"

# 修复 install name (必须，否则 iOS 无法加载)
echo "修复 install name..."
install_name_tool -id "@rpath/${FRAMEWORK_DIR}/${FRAMEWORK_NAME}" "$OUTPUT_DIR/$FRAMEWORK_DIR/$FRAMEWORK_NAME"

# 获取 dylib 的架构信息
ARCH=$(lipo -info "$DYLIB_PATH" 2>/dev/null | grep -o 'arm64\|x86_64' | head -1)
if [ -z "$ARCH" ]; then
    ARCH="arm64"
fi

# 创建 Info.plist
cat > "$OUTPUT_DIR/$FRAMEWORK_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${FRAMEWORK_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.libretro.${CORE_NAME}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${FRAMEWORK_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>14.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>iPhoneOS</string>
    </array>
</dict>
</plist>
EOF

echo "✅ Framework 创建成功: $OUTPUT_DIR/$FRAMEWORK_DIR"
echo ""
echo "下一步操作:"
echo "1. 将 Framework 复制到 Yearn/Resources/Frameworks/"
echo "2. 在 Xcode 中添加 Framework 引用"
echo "3. 在 FrameworkCoreLoader.swift 中注册核心"
echo ""
echo "注意: Framework 需要在真机上签名后才能使用"

