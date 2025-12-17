//
//  FrameworkCoreLoader.swift
//  YearnCore
//
//  动态 Framework 核心加载器
//  用于加载以 .framework 格式打包的 libretro 核心
//

import Foundation
import CLibretro

// MARK: - Framework Core Loader

/// 从动态 Framework 加载 libretro 核心
public class FrameworkCoreLoader {
    
    /// 单例
    public static let shared = FrameworkCoreLoader()
    
    /// 已加载的 Framework 句柄
    private var loadedFrameworks: [String: UnsafeMutableRawPointer] = [:]
    
    /// Framework 搜索路径
    private var frameworkSearchPaths: [URL] = []
    
    private init() {
        setupSearchPaths()
    }
    
    // MARK: - Setup
    
    /// 设置 Framework 搜索路径
    private func setupSearchPaths() {
        // 1. App Bundle 中的 Frameworks 目录
        if let frameworksURL = Bundle.main.privateFrameworksURL {
            frameworkSearchPaths.append(frameworksURL)
        }
        
        // 2. App Bundle 中的 Resources/Frameworks 目录
        if let resourceURL = Bundle.main.resourceURL {
            let customFrameworksURL = resourceURL.appendingPathComponent("Frameworks")
            frameworkSearchPaths.append(customFrameworksURL)
        }
        
        // 3. Documents 目录中的 Frameworks（用于开发测试）
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let documentsFrameworksURL = documentsURL.appendingPathComponent("Frameworks")
            frameworkSearchPaths.append(documentsFrameworksURL)
        }
        
        print("🔧 FrameworkCoreLoader: 搜索路径:")
        for path in frameworkSearchPaths {
            print("   - \(path.path)")
        }
    }
    
    // MARK: - Framework Discovery
    
    /// 查找指定名称的 Framework
    public func findFramework(named name: String) -> URL? {
        // 尝试多种命名格式（不包含通配符回退）
        let possibleNames = [
            "\(name).framework",
            "\(name.lowercased()).framework",
            "\(name.replacingOccurrences(of: "_", with: ".")).framework"
        ]
        
        for searchPath in frameworkSearchPaths {
            for frameworkName in possibleNames {
                let frameworkURL = searchPath.appendingPathComponent(frameworkName)
                if FileManager.default.fileExists(atPath: frameworkURL.path) {
                    print("✅ 找到 Framework: \(name) -> \(frameworkURL.path)")
                    return frameworkURL
                }
            }
        }
        
        // 不打印未找到的日志，避免刷屏
        return nil
    }
    
    /// 获取所有可用的 Framework 核心
    public func discoverFrameworks() -> [String] {
        var frameworks: [String] = []
        
        for searchPath in frameworkSearchPaths {
            guard let contents = try? FileManager.default.contentsOfDirectory(at: searchPath, includingPropertiesForKeys: nil) else {
                continue
            }
            
            for url in contents where url.pathExtension == "framework" {
                let name = url.deletingPathExtension().lastPathComponent
                if !frameworks.contains(name) {
                    frameworks.append(name)
                    print("🔍 发现 Framework: \(name)")
                }
            }
        }
        
        return frameworks
    }
    
    // MARK: - Core Loading
    
    /// 从 Framework 加载核心接口
    public func loadCore(frameworkURL: URL) throws -> LibretroCoreInterface {
        let frameworkName = frameworkURL.deletingPathExtension().lastPathComponent
        
        // 获取 Framework 内的二进制文件路径
        let binaryURL = frameworkURL.appendingPathComponent(frameworkName)
        
        guard FileManager.default.fileExists(atPath: binaryURL.path) else {
            throw FrameworkLoadError.binaryNotFound(frameworkName)
        }
        
        print("📦 加载 Framework: \(binaryURL.path)")
        
        // 使用 dlopen 加载动态库
        guard let handle = dlopen(binaryURL.path, RTLD_NOW | RTLD_LOCAL) else {
            let error = String(cString: dlerror())
            print("❌ dlopen 失败: \(error)")
            throw FrameworkLoadError.dlopenFailed(error)
        }
        
        // 保存句柄以便后续卸载
        loadedFrameworks[frameworkName] = handle
        
        // 获取所有必需的函数指针
        let interface = try loadFunctionPointers(from: handle, frameworkName: frameworkName)
        
        print("✅ Framework 核心加载成功: \(frameworkName)")
        return interface
    }
    
    /// 从句柄加载函数指针
    private func loadFunctionPointers(from handle: UnsafeMutableRawPointer, frameworkName: String) throws -> LibretroCoreInterface {
        
        // 辅助函数：获取符号
        func getSymbol<T>(_ name: String) throws -> T {
            guard let symbol = dlsym(handle, name) else {
                let error = String(cString: dlerror())
                throw FrameworkLoadError.symbolNotFound(name, error)
            }
            return unsafeBitCast(symbol, to: T.self)
        }
        
        // 加载所有必需的函数
        let retro_init: @convention(c) () -> Void = try getSymbol("retro_init")
        let retro_deinit: @convention(c) () -> Void = try getSymbol("retro_deinit")
        let retro_api_version: @convention(c) () -> UInt32 = try getSymbol("retro_api_version")
        let retro_get_system_info: @convention(c) (UnsafeMutablePointer<retro_system_info>?) -> Void = try getSymbol("retro_get_system_info")
        let retro_get_system_av_info: @convention(c) (UnsafeMutablePointer<retro_system_av_info>?) -> Void = try getSymbol("retro_get_system_av_info")
        let retro_set_environment: @convention(c) (retro_environment_t?) -> Void = try getSymbol("retro_set_environment")
        let retro_set_video_refresh: @convention(c) (retro_video_refresh_t?) -> Void = try getSymbol("retro_set_video_refresh")
        let retro_set_audio_sample: @convention(c) (retro_audio_sample_t?) -> Void = try getSymbol("retro_set_audio_sample")
        let retro_set_audio_sample_batch: @convention(c) (retro_audio_sample_batch_t?) -> Void = try getSymbol("retro_set_audio_sample_batch")
        let retro_set_input_poll: @convention(c) (retro_input_poll_t?) -> Void = try getSymbol("retro_set_input_poll")
        let retro_set_input_state: @convention(c) (retro_input_state_t?) -> Void = try getSymbol("retro_set_input_state")
        let retro_reset: @convention(c) () -> Void = try getSymbol("retro_reset")
        let retro_run: @convention(c) () -> Void = try getSymbol("retro_run")
        let retro_load_game: @convention(c) (UnsafePointer<retro_game_info>?) -> Bool = try getSymbol("retro_load_game")
        let retro_unload_game: @convention(c) () -> Void = try getSymbol("retro_unload_game")
        let retro_serialize_size: @convention(c) () -> Int = try getSymbol("retro_serialize_size")
        let retro_serialize: @convention(c) (UnsafeMutableRawPointer?, Int) -> Bool = try getSymbol("retro_serialize")
        let retro_unserialize: @convention(c) (UnsafeRawPointer?, Int) -> Bool = try getSymbol("retro_unserialize")
        let retro_get_memory_data: @convention(c) (UInt32) -> UnsafeMutableRawPointer? = try getSymbol("retro_get_memory_data")
        let retro_get_memory_size: @convention(c) (UInt32) -> Int = try getSymbol("retro_get_memory_size")
        
        // 可选函数
        let retro_cheat_reset: (@convention(c) () -> Void)? = try? getSymbol("retro_cheat_reset")
        let retro_cheat_set: (@convention(c) (UInt32, Bool, UnsafePointer<CChar>?) -> Void)? = try? getSymbol("retro_cheat_set")
        
        return LibretroCoreInterface(
            retro_init: retro_init,
            retro_deinit: retro_deinit,
            retro_api_version: retro_api_version,
            retro_get_system_info: retro_get_system_info,
            retro_get_system_av_info: retro_get_system_av_info,
            retro_set_environment: retro_set_environment,
            retro_set_video_refresh: retro_set_video_refresh,
            retro_set_audio_sample: retro_set_audio_sample,
            retro_set_audio_sample_batch: retro_set_audio_sample_batch,
            retro_set_input_poll: retro_set_input_poll,
            retro_set_input_state: retro_set_input_state,
            retro_reset: retro_reset,
            retro_run: retro_run,
            retro_load_game: retro_load_game,
            retro_unload_game: retro_unload_game,
            retro_serialize_size: retro_serialize_size,
            retro_serialize: retro_serialize,
            retro_unserialize: retro_unserialize,
            retro_get_memory_data: retro_get_memory_data,
            retro_get_memory_size: retro_get_memory_size,
            retro_cheat_reset: retro_cheat_reset,
            retro_cheat_set: retro_cheat_set
        )
    }
    
    /// 卸载 Framework
    public func unloadFramework(named name: String) {
        guard let handle = loadedFrameworks[name] else {
            return
        }
        
        dlclose(handle)
        loadedFrameworks.removeValue(forKey: name)
        print("📦 Framework 已卸载: \(name)")
    }
    
    /// 卸载所有 Framework
    public func unloadAllFrameworks() {
        for (name, handle) in loadedFrameworks {
            dlclose(handle)
            print("📦 Framework 已卸载: \(name)")
        }
        loadedFrameworks.removeAll()
    }
    
    // MARK: - System Specific Loaders
    
    /// 核心名称映射表 (系统 -> 可能的 Framework 名称)
    private static let coreNameMap: [String: [String]] = [
        // PS1
        "ps1": ["pcsx.rearmed.libretro", "pcsx_rearmed_libretro", "pcsx_rearmed", "swanstation.libretro"],
        // GBA
        "gba": ["mgba.libretro", "mgba_libretro", "vba.next.libretro", "gpsp.libretro"],
        // GBC/GB
        "gbc": ["gambatte.libretro", "gambatte_libretro", "mgba.libretro"],
        "gb": ["gambatte.libretro", "gambatte_libretro", "mgba.libretro"],
        // NES
        "nes": ["fceumm.libretro", "fceumm_libretro", "nestopia.libretro", "quicknes.libretro"],
        // SNES - 使用 bsnes (GPL v3)
        "snes": ["bsnes.libretro", "bsnes_libretro"],
        // Genesis/Mega Drive - 使用 ClownMDEmu (AGPL v3)
        "genesis": ["clownmdemu.libretro", "clownmdemu_libretro"],
        "megadrive": ["clownmdemu.libretro", "clownmdemu_libretro"],
        // N64
        "n64": ["mupen64plus.next.libretro", "mupen64plus_next_libretro", "parallel.n64.libretro"],
        // NDS
        "nds": ["melonds.libretro", "melonds_libretro", "desmume.libretro"],
        // PSP
        "psp": ["ppsspp.libretro", "ppsspp_libretro"],
        // Arcade
        "arcade": ["fbneo.libretro", "mame2003.plus.libretro", "fbalpha2012.libretro"],
    ]
    
    /// 加载指定系统的核心
    public func loadCore(forSystem system: String) throws -> LibretroCoreInterface {
        let systemLower = system.lowercased()
        
        guard let possibleNames = Self.coreNameMap[systemLower] else {
            throw FrameworkLoadError.frameworkNotFound("未知系统: \(system)")
        }
        
        for name in possibleNames {
            if let frameworkURL = findFramework(named: name) {
                print("🎮 为系统 \(system) 加载核心: \(name)")
                return try loadCore(frameworkURL: frameworkURL)
            }
        }
        
        throw FrameworkLoadError.frameworkNotFound("\(system) 核心")
    }
    
    /// 加载 PS1 (PCSX ReARMed) 核心
    public func loadPS1Core() throws -> LibretroCoreInterface {
        return try loadCore(forSystem: "ps1")
    }
    
    /// 加载 GBA 核心
    public func loadGBACore() throws -> LibretroCoreInterface {
        return try loadCore(forSystem: "gba")
    }
    
    /// 加载 GBC 核心
    public func loadGBCCore() throws -> LibretroCoreInterface {
        return try loadCore(forSystem: "gbc")
    }
    
    /// 加载 NES 核心
    public func loadNESCore() throws -> LibretroCoreInterface {
        return try loadCore(forSystem: "nes")
    }
    
    /// 加载 SNES 核心
    public func loadSNESCore() throws -> LibretroCoreInterface {
        return try loadCore(forSystem: "snes")
    }
    
    /// 加载 Genesis 核心
    public func loadGenesisCore() throws -> LibretroCoreInterface {
        return try loadCore(forSystem: "genesis")
    }
    
    /// 加载 N64 核心
    public func loadN64Core() throws -> LibretroCoreInterface {
        return try loadCore(forSystem: "n64")
    }
    
    /// 加载 NDS 核心
    public func loadNDSCore() throws -> LibretroCoreInterface {
        return try loadCore(forSystem: "nds")
    }
    
    /// 检查指定系统是否有可用的动态核心
    public func hasDynamicCore(forSystem system: String) -> Bool {
        let systemLower = system.lowercased()
        
        guard let possibleNames = Self.coreNameMap[systemLower] else {
            return false
        }
        
        for name in possibleNames {
            if findFramework(named: name) != nil {
                return true
            }
        }
        
        return false
    }
    
    /// 获取所有可用的动态核心信息
    public func getAvailableDynamicCores() -> [(system: String, coreName: String, frameworkURL: URL)] {
        var result: [(system: String, coreName: String, frameworkURL: URL)] = []
        
        for (system, possibleNames) in Self.coreNameMap {
            for name in possibleNames {
                if let frameworkURL = findFramework(named: name) {
                    result.append((system: system, coreName: name, frameworkURL: frameworkURL))
                    break // 每个系统只取第一个可用的核心
                }
            }
        }
        
        return result
    }
}

// MARK: - Errors

public enum FrameworkLoadError: Error, LocalizedError {
    case frameworkNotFound(String)
    case binaryNotFound(String)
    case dlopenFailed(String)
    case symbolNotFound(String, String)
    
    public var errorDescription: String? {
        switch self {
        case .frameworkNotFound(let name):
            return "找不到 Framework: \(name)"
        case .binaryNotFound(let name):
            return "找不到 Framework 二进制文件: \(name)"
        case .dlopenFailed(let error):
            return "加载动态库失败: \(error)"
        case .symbolNotFound(let symbol, let error):
            return "找不到符号 \(symbol): \(error)"
        }
    }
}

