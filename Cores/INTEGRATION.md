# 静态核心集成指南

本指南说明如何将编译好的静态 libretro 核心集成到 Yearn iOS 项目中。

## 已编译的静态库

位置：`Yearn/Resources/StaticCores/`

| 文件 | 系统 | 核心 |
|------|------|------|
| `fceumm_libretro_ios.a` | NES | FCEUmm |
| `snes9x_libretro_ios.a` | SNES | Snes9x |
| `gambatte_libretro_ios.a` | GB/GBC | Gambatte |
| `mgba_libretro_ios.a` | GBA | mGBA |
| `genesis_plus_gx_libretro_ios.a` | Genesis/MD | Genesis Plus GX |
| `melonds_libretro_ios.a` | NDS | melonDS |
| `mupen64plus_next_libretro_ios.a` | N64 | Mupen64Plus-Next |

## Xcode 配置步骤

### 方法 1：使用 xcconfig 文件（推荐）

1. 在 Xcode 中，选择项目 → Info → Configurations
2. 对于 Debug 和 Release 配置，设置 Based on Configuration File 为 `StaticCores.xcconfig`

### 方法 2：手动配置

#### 步骤 1：添加静态库到项目

1. 在 Xcode 中，右键点击 `Yearn/Resources` 文件夹
2. 选择 "Add Files to Yearn..."
3. 选择 `StaticCores` 文件夹
4. 确保勾选 "Copy items if needed" 和 "Create folder references"

#### 步骤 2：配置 Build Settings

1. 选择 Yearn target
2. 进入 Build Settings 标签
3. 搜索并设置以下选项：

**Swift Compiler - Custom Flags > Other Swift Flags:**
```
-DSTATIC_CORES_ENABLED
```

**Apple Clang - Preprocessing > Preprocessor Macros:**
```
STATIC_CORES_ENABLED=1
```

**Search Paths > Library Search Paths:**
```
$(SRCROOT)/Yearn/Resources/StaticCores
```

#### 步骤 3：链接静态库

1. 选择 Yearn target
2. 进入 Build Phases 标签
3. 展开 "Link Binary With Libraries"
4. 点击 "+" 添加以下库：
   - `fceumm_libretro_ios.a`
   - `snes9x_libretro_ios.a`
   - `gambatte_libretro_ios.a`
   - `mgba_libretro_ios.a`
   - `genesis_plus_gx_libretro_ios.a`
   - `melonds_libretro_ios.a`
   - `mupen64plus_next_libretro_ios.a`

5. 还需要添加系统库（如果尚未添加）：
   - `libz.tbd` (zlib)
   - `libc++.tbd` (C++ 标准库)

#### 步骤 4：清理并重新编译

1. Product → Clean Build Folder (Shift+Cmd+K)
2. Product → Build (Cmd+B)

## 验证

编译成功后，在控制台应该看到：
```
✅ Static cores registered
```

如果看到：
```
ℹ️ Using dynamic cores (STATIC_CORES_ENABLED not defined)
```

则表示编译标志未正确设置。

## 故障排除

### 链接错误：Undefined symbols

确保：
1. 所有静态库都已添加到 "Link Binary With Libraries"
2. Library Search Paths 设置正确
3. 静态库文件实际存在于指定路径

### 编译错误：Cannot find 'registerAllStaticCores' in scope

确保：
1. `STATIC_CORES_ENABLED` 编译标志已设置
2. YearnCore 包正确链接

### 运行时错误：Core not found

确保：
1. `StaticCoreRegistry` 中的核心标识符与 `EmulationViewModel` 中使用的一致
2. 静态核心在 app 启动时被注册

## 重新编译核心

如果需要重新编译静态库：

```bash
cd /Users/ugreen/Desktop/work/Yearn/Cores
./build_prefixed_static_cores.sh all
```

编译完成后，将 `static_prefixed/` 目录下的 `.a` 文件复制到 `Yearn/Resources/StaticCores/`。

