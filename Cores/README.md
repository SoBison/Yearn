# Libretro Cores 静态库集成指南

## 概述

由于 iOS App Store 不允许动态加载可执行代码，我们需要将 libretro cores 编译为静态库并直接链接到 App 中。

## 方案一：使用预编译的静态库（推荐）

### 1. 下载静态库源码

从以下仓库克隆核心源码：

```bash
cd /Users/ugreen/Desktop/work/Yearn/Cores

# NES - FCEUmm
git clone https://github.com/libretro/libretro-fceumm.git

# SNES - Snes9x
git clone https://github.com/libretro/snes9x.git

# GB/GBC - Gambatte
git clone https://github.com/libretro/gambatte-libretro.git

# GBA - mGBA
git clone https://github.com/libretro/mgba.git
```

### 2. 编译为静态库

每个核心需要配置为编译静态库 (.a)：

```bash
# 示例：编译 FCEUmm
cd libretro-fceumm
make -f Makefile.libretro platform=ios-arm64 STATIC_LINKING=1
```

### 3. 在 Xcode 中添加静态库

1. 将编译好的 `.a` 文件拖入 Xcode 项目
2. 在 Build Phases → Link Binary With Libraries 中添加
3. 在 Build Settings → Library Search Paths 中添加路径

---

## 方案二：直接编译源码到项目（最简单）

### 1. 创建核心 Swift Package

为每个核心创建一个 Swift Package，包含 C/C++ 源码：

```
YearnCores/
├── Package.swift
├── Sources/
│   ├── FCEUmm/           # NES 核心源码
│   ├── Snes9x/           # SNES 核心源码
│   ├── Gambatte/         # GB/GBC 核心源码
│   └── mGBA/             # GBA 核心源码
```

### 2. Package.swift 示例

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YearnCores",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FCEUmm", targets: ["FCEUmm"]),
        .library(name: "Snes9x", targets: ["Snes9x"]),
    ],
    targets: [
        .target(
            name: "FCEUmm",
            path: "Sources/FCEUmm",
            sources: ["src/"],
            publicHeadersPath: "include",
            cSettings: [
                .define("HAVE_STRINGS_H"),
                .define("HAVE_STDINT_H"),
                .define("HAVE_INTTYPES_H"),
                .define("__LIBRETRO__"),
                .define("FRONTEND_SUPPORTS_RGB565"),
            ]
        ),
    ]
)
```

---

## 方案三：使用桥接头文件注册核心

### 1. 在 App 中注册静态核心

```swift
// AppDelegate.swift 或 YearnApp.swift

import YearnCore

// 声明外部 C 函数（来自静态链接的核心）
@_silgen_name("retro_init") func fceumm_retro_init()
@_silgen_name("retro_deinit") func fceumm_retro_deinit()
// ... 其他函数

func registerCores() {
    let fceummInterface = LibretroCoreInterface(
        retro_init: fceumm_retro_init,
        retro_deinit: fceumm_retro_deinit,
        // ... 其他函数指针
    )
    
    let fceummCore = StaticCoreInfo(
        identifier: "fceumm",
        name: "FCEUmm",
        systemName: "NES",
        supportedExtensions: ["nes", "fds"],
        coreInterface: fceummInterface
    )
    
    StaticCoreRegistry.shared.register(fceummCore)
}
```

---

## 当前文件说明

目录中的 `.dylib` 文件是动态库，仅用于开发测试：

| 文件 | 系统 | 说明 |
|------|------|------|
| fceumm_libretro_ios.dylib | NES | 动态库（需转为静态库） |
| snes9x_libretro_ios.dylib | SNES | 动态库（需转为静态库） |
| gambatte_libretro_ios.dylib | GB/GBC | 动态库（需转为静态库） |
| mgba_libretro_ios.dylib | GBA | 动态库（需转为静态库） |
| mupen64plus_next_libretro_ios.dylib | N64 | 动态库（需转为静态库） |
| melonds_libretro_ios.dylib | NDS | 动态库（需转为静态库） |
| genesis_plus_gx_libretro_ios.dylib | Genesis | 动态库（需转为静态库） |
| pcsx_rearmed_libretro_ios.dylib | PS1 | 动态库（需转为静态库） |

---

## 推荐步骤

1. **开发阶段**：使用动态库在模拟器/越狱设备上测试
2. **发布阶段**：编译静态库并集成到项目中
3. **App Store 提交**：确保所有代码都是静态链接的

## 注意事项

- 某些核心有 GPL 许可证要求
- N64 和 PS1 核心较大，可能影响 App 大小
- 建议先集成 NES、SNES、GB/GBC、GBA 等较小的核心

