//
//  StaticCoreRegistry.swift
//  YearnCore
//
//  Registry for statically linked libretro cores
//  This allows cores to be compiled directly into the app for App Store compliance
//

import Foundation
import CLibretro

// MARK: - Core Function Pointers

/// Structure containing all required libretro function pointers for a core
public struct LibretroCoreInterface {
    public let retro_init: @convention(c) () -> Void
    public let retro_deinit: @convention(c) () -> Void
    public let retro_api_version: @convention(c) () -> UInt32
    public let retro_get_system_info: @convention(c) (UnsafeMutablePointer<retro_system_info>?) -> Void
    public let retro_get_system_av_info: @convention(c) (UnsafeMutablePointer<retro_system_av_info>?) -> Void
    public let retro_set_environment: @convention(c) (retro_environment_t?) -> Void
    public let retro_set_video_refresh: @convention(c) (retro_video_refresh_t?) -> Void
    public let retro_set_audio_sample: @convention(c) (retro_audio_sample_t?) -> Void
    public let retro_set_audio_sample_batch: @convention(c) (retro_audio_sample_batch_t?) -> Void
    public let retro_set_input_poll: @convention(c) (retro_input_poll_t?) -> Void
    public let retro_set_input_state: @convention(c) (retro_input_state_t?) -> Void
    public let retro_reset: @convention(c) () -> Void
    public let retro_run: @convention(c) () -> Void
    public let retro_load_game: @convention(c) (UnsafePointer<retro_game_info>?) -> Bool
    public let retro_unload_game: @convention(c) () -> Void
    public let retro_serialize_size: @convention(c) () -> Int
    public let retro_serialize: @convention(c) (UnsafeMutableRawPointer?, Int) -> Bool
    public let retro_unserialize: @convention(c) (UnsafeRawPointer?, Int) -> Bool
    public let retro_get_memory_data: @convention(c) (UInt32) -> UnsafeMutableRawPointer?
    public let retro_get_memory_size: @convention(c) (UInt32) -> Int
    public let retro_cheat_reset: (@convention(c) () -> Void)?
    public let retro_cheat_set: (@convention(c) (UInt32, Bool, UnsafePointer<CChar>?) -> Void)?
    
    public init(
        retro_init: @escaping @convention(c) () -> Void,
        retro_deinit: @escaping @convention(c) () -> Void,
        retro_api_version: @escaping @convention(c) () -> UInt32,
        retro_get_system_info: @escaping @convention(c) (UnsafeMutablePointer<retro_system_info>?) -> Void,
        retro_get_system_av_info: @escaping @convention(c) (UnsafeMutablePointer<retro_system_av_info>?) -> Void,
        retro_set_environment: @escaping @convention(c) (retro_environment_t?) -> Void,
        retro_set_video_refresh: @escaping @convention(c) (retro_video_refresh_t?) -> Void,
        retro_set_audio_sample: @escaping @convention(c) (retro_audio_sample_t?) -> Void,
        retro_set_audio_sample_batch: @escaping @convention(c) (retro_audio_sample_batch_t?) -> Void,
        retro_set_input_poll: @escaping @convention(c) (retro_input_poll_t?) -> Void,
        retro_set_input_state: @escaping @convention(c) (retro_input_state_t?) -> Void,
        retro_reset: @escaping @convention(c) () -> Void,
        retro_run: @escaping @convention(c) () -> Void,
        retro_load_game: @escaping @convention(c) (UnsafePointer<retro_game_info>?) -> Bool,
        retro_unload_game: @escaping @convention(c) () -> Void,
        retro_serialize_size: @escaping @convention(c) () -> Int,
        retro_serialize: @escaping @convention(c) (UnsafeMutableRawPointer?, Int) -> Bool,
        retro_unserialize: @escaping @convention(c) (UnsafeRawPointer?, Int) -> Bool,
        retro_get_memory_data: @escaping @convention(c) (UInt32) -> UnsafeMutableRawPointer?,
        retro_get_memory_size: @escaping @convention(c) (UInt32) -> Int,
        retro_cheat_reset: (@convention(c) () -> Void)? = nil,
        retro_cheat_set: (@convention(c) (UInt32, Bool, UnsafePointer<CChar>?) -> Void)? = nil
    ) {
        self.retro_init = retro_init
        self.retro_deinit = retro_deinit
        self.retro_api_version = retro_api_version
        self.retro_get_system_info = retro_get_system_info
        self.retro_get_system_av_info = retro_get_system_av_info
        self.retro_set_environment = retro_set_environment
        self.retro_set_video_refresh = retro_set_video_refresh
        self.retro_set_audio_sample = retro_set_audio_sample
        self.retro_set_audio_sample_batch = retro_set_audio_sample_batch
        self.retro_set_input_poll = retro_set_input_poll
        self.retro_set_input_state = retro_set_input_state
        self.retro_reset = retro_reset
        self.retro_run = retro_run
        self.retro_load_game = retro_load_game
        self.retro_unload_game = retro_unload_game
        self.retro_serialize_size = retro_serialize_size
        self.retro_serialize = retro_serialize
        self.retro_unserialize = retro_unserialize
        self.retro_get_memory_data = retro_get_memory_data
        self.retro_get_memory_size = retro_get_memory_size
        self.retro_cheat_reset = retro_cheat_reset
        self.retro_cheat_set = retro_cheat_set
    }
}

// MARK: - Static Core Info

/// Information about a statically linked core
public struct StaticCoreInfo {
    public let identifier: String
    public let name: String
    public let systemName: String
    public let supportedExtensions: [String]
    public let coreInterface: LibretroCoreInterface
    
    public init(
        identifier: String,
        name: String,
        systemName: String,
        supportedExtensions: [String],
        coreInterface: LibretroCoreInterface
    ) {
        self.identifier = identifier
        self.name = name
        self.systemName = systemName
        self.supportedExtensions = supportedExtensions
        self.coreInterface = coreInterface
    }
}

// MARK: - Static Core Registry

/// Registry for all statically linked cores
/// Cores must be registered at app startup
public final class StaticCoreRegistry {
    
    public static let shared = StaticCoreRegistry()
    
    private var cores: [String: StaticCoreInfo] = [:]
    
    /// 动态加载的 Framework 核心
    private var dynamicCores: [String: StaticCoreInfo] = [:]
    
    /// 是否优先使用动态 Framework 核心
    public var preferDynamicCores: Bool = true
    
    private init() {}
    
    /// Register a static core
    public func register(_ core: StaticCoreInfo) {
        cores[core.identifier] = core
        print("Registered static core: \(core.name) for \(core.systemName)")
    }
    
    /// 注册动态 Framework 核心
    public func registerDynamic(_ core: StaticCoreInfo) {
        dynamicCores[core.identifier] = core
        print("Registered dynamic core: \(core.name) for \(core.systemName)")
    }
    
    /// Get a core by identifier
    public func getCore(identifier: String) -> StaticCoreInfo? {
        // 优先使用动态核心（如果启用）
        if preferDynamicCores, let dynamicCore = dynamicCores[identifier] {
            return dynamicCore
        }
        return cores[identifier]
    }
    
    /// Get a core for a file extension
    public func getCore(forExtension ext: String) -> StaticCoreInfo? {
        let lowercased = ext.lowercased()
        
        // 优先使用动态核心（如果启用）
        if preferDynamicCores {
            if let dynamicCore = dynamicCores.values.first(where: { $0.supportedExtensions.contains(lowercased) }) {
                return dynamicCore
            }
        }
        
        return cores.values.first { core in
            core.supportedExtensions.contains(lowercased)
        }
    }
    
    /// Get all registered cores (包括动态核心)
    public var allCores: [StaticCoreInfo] {
        var result = Array(cores.values)
        // 添加动态核心（避免重复）
        for dynamicCore in dynamicCores.values {
            if !result.contains(where: { $0.identifier == dynamicCore.identifier }) {
                result.append(dynamicCore)
            }
        }
        return result
    }
    
    /// Check if any cores are registered
    public var hasCores: Bool {
        return !cores.isEmpty || !dynamicCores.isEmpty
    }
    
    /// 尝试从 Framework 加载 PS1 核心
    public func tryLoadPS1FrameworkCore() -> Bool {
        return tryLoadDynamicCore(
            system: "ps1",
            identifier: "pcsx_rearmed",  // 使用与静态核心相同的标识符
            name: "PCSX ReARMed",
            systemName: "PS1",
            extensions: ["cue", "bin", "img", "mdf", "pbp", "chd"]
        )
    }
    
    /// 尝试加载所有可用的动态 Framework 核心
    public func tryLoadAllDynamicCores() -> Int {
        var loadedCount = 0
        
        // 系统配置表 - 使用与静态核心相同的标识符
        // 这样 EmulationViewModel 可以用相同的方式查找核心
        let systemConfigs: [(system: String, identifier: String, name: String, systemName: String, extensions: [String])] = [
            ("ps1", "pcsx_rearmed", "PCSX ReARMed", "PS1", ["cue", "bin", "img", "mdf", "pbp", "chd"]),
            ("gba", "mgba", "mGBA", "GBA", ["gba", "gbc", "gb"]),
            ("gbc", "gambatte", "Gambatte", "GBC", ["gbc", "gb"]),
            ("nes", "fceumm", "FCEUmm", "NES", ["nes", "fds", "unf"]),
            ("snes", "snes9x", "Snes9x", "SNES", ["sfc", "smc", "swc"]),
            ("genesis", "genesis_plus_gx", "Genesis Plus GX", "Genesis", ["md", "gen", "smd", "bin"]),
            ("n64", "mupen64plus_next", "Mupen64Plus-Next", "N64", ["n64", "z64", "v64"]),
            ("nds", "melonds", "melonDS", "NDS", ["nds", "dsi"]),
        ]
        
        for config in systemConfigs {
            if tryLoadDynamicCore(
                system: config.system,
                identifier: config.identifier,
                name: config.name,
                systemName: config.systemName,
                extensions: config.extensions
            ) {
                loadedCount += 1
            }
        }
        
        return loadedCount
    }
    
    /// 通用动态核心加载方法
    private func tryLoadDynamicCore(
        system: String,
        identifier: String,
        name: String,
        systemName: String,
        extensions: [String]
    ) -> Bool {
        // 检查是否有可用的动态核心
        guard FrameworkCoreLoader.shared.hasDynamicCore(forSystem: system) else {
            return false
        }
        
        do {
            let interface = try FrameworkCoreLoader.shared.loadCore(forSystem: system)
            
            let core = StaticCoreInfo(
                identifier: identifier,
                name: name,
                systemName: systemName,
                supportedExtensions: extensions,
                coreInterface: interface
            )
            
            registerDynamic(core)
            print("✅ \(systemName) 动态 Framework 核心加载成功")
            return true
        } catch {
            print("⚠️ \(systemName) 动态 Framework 核心加载失败: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Static Bridge

/// LibretroBridge variant that uses statically linked cores
public final class StaticLibretroBridge {
    
    private var coreInterface: LibretroCoreInterface?
    private var isLoaded = false
    private var gameLoaded = false
    
    // Callbacks
    public var videoCallback: ((UnsafeRawPointer, Int, Int, Int, LibretroPixelFormat) -> Void)?
    public var audioCallback: ((UnsafePointer<Int16>, Int) -> Void)?
    public var inputPollCallback: (() -> Void)?
    public var inputStateCallback: ((UInt32, UInt32, UInt32, UInt32) -> Int16)?
    
    // System info
    public private(set) var systemInfo: SystemInfo?
    public private(set) var avInfo: AVInfo?
    public private(set) var pixelFormat: LibretroPixelFormat = .rgb565
    
    // Directories
    private let systemDirectory: String
    private let saveDirectory: String
    
    // C-String buffers to ensure pointers remain valid
    private var systemDirectoryBuffer: [CChar]?
    private var saveDirectoryBuffer: [CChar]?
    
    // Input state
    private var inputState: [[Int16]] = Array(repeating: Array(repeating: 0, count: 16), count: 4)
    
    // 调试用：记录查询的按键
    fileprivate static var debugQueryIds: Set<Int> = []
    fileprivate static var debugLastLogTime: CFAbsoluteTime = 0
    
    // 调试用：视频和音频帧计数
    fileprivate static var videoCallbackCount = 0
    fileprivate static var audioCallbackCount = 0
    
    // Singleton for callbacks
    fileprivate static var currentBridge: StaticLibretroBridge?
    
    public init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // BIOS 文件存放在 Documents/BIOS 目录
        // libretro 核心会在 system directory 中查找 BIOS 文件
        self.systemDirectory = documentsPath.appendingPathComponent("BIOS").path
        self.saveDirectory = documentsPath.appendingPathComponent("Saves").path
        
        // Create directories
        try? FileManager.default.createDirectory(atPath: systemDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: saveDirectory, withIntermediateDirectories: true)
        
        // Initialize C-String buffers
        self.systemDirectoryBuffer = systemDirectory.cString(using: .utf8)
        self.saveDirectoryBuffer = saveDirectory.cString(using: .utf8)
        
        print("📁 System/BIOS directory: \(systemDirectory)")
        print("📁 Save directory: \(saveDirectory)")
    }
    
    deinit {
        unloadCore()
    }
    
    /// Load a statically linked core by identifier
    public func loadCore(identifier: String) throws {
        guard let coreInfo = StaticCoreRegistry.shared.getCore(identifier: identifier) else {
            throw LibretroError.loadFailed("Core not found: \(identifier)")
        }
        
        try loadCore(coreInfo.coreInterface)
    }
    
    /// Load a core interface directly
    public func loadCore(_ interface: LibretroCoreInterface) throws {
        guard !isLoaded else {
            throw LibretroError.alreadyLoaded
        }
        
        self.coreInterface = interface
        StaticLibretroBridge.currentBridge = self
        
        // Setup environment callback
        interface.retro_set_environment { cmd, data in
            return StaticLibretroBridge.currentBridge?.handleEnvironment(cmd, data: data) ?? false
        }
        
        // Initialize core
        interface.retro_init()
        
        // Setup other callbacks
        setupCallbacks()
        
        // Get system info
        var info = retro_system_info()
        interface.retro_get_system_info(&info)
        
        systemInfo = SystemInfo(
            libraryName: info.library_name != nil ? String(cString: info.library_name) : "Unknown",
            libraryVersion: info.library_version != nil ? String(cString: info.library_version) : "0.0",
            validExtensions: info.valid_extensions != nil ? String(cString: info.valid_extensions) : "",
            needFullpath: info.need_fullpath,
            blockExtract: info.block_extract
        )
        
        isLoaded = true
    }
    
    /// Unload the current core
    public func unloadCore() {
        guard isLoaded else { return }
        
        if gameLoaded {
            unloadGame()
        }
        
        coreInterface?.retro_deinit()
        coreInterface = nil
        isLoaded = false
        systemInfo = nil
        avInfo = nil
        
        if StaticLibretroBridge.currentBridge === self {
            StaticLibretroBridge.currentBridge = nil
        }
    }
    
    /// Load a game
    public func loadGame(url: URL) throws {
        guard let interface = coreInterface, isLoaded else {
            throw LibretroError.coreNotLoaded
        }
        
        let path = url.path
        let needFullpath = systemInfo?.needFullpath ?? false
        print("🎮 Loading game: \(url.lastPathComponent) (fullpath: \(needFullpath))")
        
        var success = false
        
        if needFullpath {
            // 核心可以直接从路径加载
            path.withCString { pathPtr in
                var gameInfo = retro_game_info()
                gameInfo.path = pathPtr
                gameInfo.data = nil
                gameInfo.size = 0
                gameInfo.meta = nil
                
                success = interface.retro_load_game(&gameInfo)
            }
        } else {
            // 核心需要 ROM 数据在内存中
            print("🎮 Loading ROM data into memory...")
            guard let romData = try? Data(contentsOf: url) else {
                print("❌ Failed to read ROM file")
                throw LibretroError.loadFailed("Failed to read ROM file")
            }
            print("🎮 ROM size: \(romData.count) bytes")
            
            romData.withUnsafeBytes { buffer in
                path.withCString { pathPtr in
                    var gameInfo = retro_game_info()
                    gameInfo.path = pathPtr
                    gameInfo.data = buffer.baseAddress
                    gameInfo.size = romData.count
                    gameInfo.meta = nil
                    
                    success = interface.retro_load_game(&gameInfo)
                }
            }
        }
        
        guard success else {
            print("❌ Failed to load game")
            throw LibretroError.loadFailed("Failed to load game")
        }
        
        // Get AV info
        var info = retro_system_av_info()
        interface.retro_get_system_av_info(&info)
        
        avInfo = AVInfo(
            baseWidth: Int(info.geometry.base_width),
            baseHeight: Int(info.geometry.base_height),
            maxWidth: Int(info.geometry.max_width),
            maxHeight: Int(info.geometry.max_height),
            aspectRatio: info.geometry.aspect_ratio > 0 ? info.geometry.aspect_ratio : Float(info.geometry.base_width) / Float(info.geometry.base_height),
            fps: info.timing.fps,
            sampleRate: info.timing.sample_rate
        )
        
        print("✅ Game loaded: \(avInfo!.baseWidth)x\(avInfo!.baseHeight) @ \(Int(avInfo!.fps)) FPS")
        
        gameLoaded = true
    }
    
    /// Unload the current game
    public func unloadGame() {
        guard gameLoaded else { return }
        coreInterface?.retro_unload_game()
        gameLoaded = false
        avInfo = nil
    }
    
    /// Run one frame
    public func runFrame() {
        guard let interface = coreInterface, gameLoaded else { 
            print("⚠️ runFrame called but game not loaded or core not initialized")
            return 
        }
        
        // Add crash detection
        let start = CFAbsoluteTimeGetCurrent()
        interface.retro_run()
        let duration = CFAbsoluteTimeGetCurrent() - start
        
        // Log if frame takes unusually long (possible infinite loop or crash)
        if duration > 1.0 {
            print("⚠️ Frame took \(duration)s to complete (unusually long)")
        }
    }
    
    /// Reset the game
    public func reset() {
        guard gameLoaded else { return }
        coreInterface?.retro_reset()
    }
    
    /// Set input state
    public func setInput(port: Int, button: RetroButton, pressed: Bool) {
        guard port >= 0 && port < 4 else {
            print("⚠️ StaticLibretroBridge.setInput: Invalid port \(port)")
            return
        }
        inputState[port][button.rawValue] = pressed ? 1 : 0
    }
    
    /// 获取当前按下的按钮名称（调试用）
    func getPressedButtonNames() -> String {
        let buttonNames = ["B", "Y", "SELECT", "START", "UP", "DOWN", "LEFT", "RIGHT", "A", "X", "L", "R", "L2", "R2", "L3", "R3"]
        var pressed: [String] = []
        for i in 0..<16 {
            if inputState[0][i] != 0 {
                pressed.append(buttonNames[i])
            }
        }
        return pressed.isEmpty ? "none" : pressed.joined(separator: ", ")
    }
    
    /// Save state
    public func saveState() -> Data? {
        guard let interface = coreInterface, gameLoaded else { return nil }
        
        let size = interface.retro_serialize_size()
        guard size > 0 else { return nil }
        
        var data = Data(count: size)
        let success = data.withUnsafeMutableBytes { buffer -> Bool in
            return interface.retro_serialize(buffer.baseAddress!, size)
        }
        
        return success ? data : nil
    }
    
    /// Load state
    public func loadState(_ data: Data) -> Bool {
        guard let interface = coreInterface, gameLoaded else { return false }
        
        return data.withUnsafeBytes { buffer -> Bool in
            return interface.retro_unserialize(buffer.baseAddress!, buffer.count)
        }
    }
    
    /// Get save RAM
    public func getSaveRAM() -> Data? {
        guard let interface = coreInterface else { return nil }
        
        guard let pointer = interface.retro_get_memory_data(UInt32(RETRO_MEMORY_SAVE_RAM)),
              interface.retro_get_memory_size(UInt32(RETRO_MEMORY_SAVE_RAM)) > 0 else {
            return nil
        }
        
        let size = interface.retro_get_memory_size(UInt32(RETRO_MEMORY_SAVE_RAM))
        return Data(bytes: pointer, count: size)
    }
    
    /// Set save RAM
    public func setSaveRAM(_ data: Data) {
        guard let interface = coreInterface else { return }
        
        guard let pointer = interface.retro_get_memory_data(UInt32(RETRO_MEMORY_SAVE_RAM)),
              interface.retro_get_memory_size(UInt32(RETRO_MEMORY_SAVE_RAM)) > 0 else {
            return
        }
        
        let size = interface.retro_get_memory_size(UInt32(RETRO_MEMORY_SAVE_RAM))
        data.withUnsafeBytes { buffer in
            memcpy(pointer, buffer.baseAddress!, min(buffer.count, size))
        }
    }
    
    // MARK: - Private
    
    private func setupCallbacks() {
        guard let interface = coreInterface else { return }
        
        interface.retro_set_video_refresh { data, width, height, pitch in
            guard let data = data,
                  let bridge = StaticLibretroBridge.currentBridge else { return }
            
            // 调试：检查数据指针的有效性
            #if DEBUG
            let dataPtr = data.assumingMemoryBound(to: UInt8.self)
            var sampleCount = 0
            var nonZeroCount = 0
            for i in 0..<min(100, Int(pitch) * Int(height)) {
                if dataPtr[i] != 0 {
                    nonZeroCount += 1
                    if sampleCount < 5 {
                        sampleCount += 1
                    }
                }
            }
            if nonZeroCount == 0 && Int(width) > 0 && Int(height) > 0 {
                // 只在第一次或每300帧打印一次
                StaticLibretroBridge.videoCallbackCount += 1
                let count = StaticLibretroBridge.videoCallbackCount
                if count <= 5 || count % 300 == 0 {
                    print("⚠️ Video callback: \(Int(width))x\(Int(height)), pitch=\(pitch), all pixels are 0 (frame #\(count))")
                }
            }
            #endif
            
            bridge.videoCallback?(data, Int(width), Int(height), pitch, bridge.pixelFormat)
        }
        
        // Set single sample callback (some cores use this)
        interface.retro_set_audio_sample { left, right in
            // Most cores use batch, but we need to provide this callback
            // to avoid crashes in cores that use single sample mode
        }
        
        interface.retro_set_audio_sample_batch { data, frames in
            guard let data = data,
                  let bridge = StaticLibretroBridge.currentBridge else { return 0 }
            
            // 调试：检查音频数据
            #if DEBUG
            StaticLibretroBridge.audioCallbackCount += 1
            let count = StaticLibretroBridge.audioCallbackCount
            if count <= 5 || count % 300 == 0 {
                let samples = Int(frames) * 2
                var nonZeroCount = 0
                for i in 0..<min(100, samples) {
                    if data[i] != 0 {
                        nonZeroCount += 1
                    }
                }
                if nonZeroCount > 0 {
                    print("🔊 Audio: \(samples) samples, \(nonZeroCount) non-zero (frame #\(count))")
                } else if count <= 5 {
                    print("⚠️ Audio: all samples are zero (frame #\(count))")
                }
            }
            #endif
            
            bridge.audioCallback?(data, Int(frames) * 2)
            return frames
        }
        
        interface.retro_set_input_poll {
            StaticLibretroBridge.currentBridge?.inputPollCallback?()
        }
        
        interface.retro_set_input_state { port, device, index, id in
            guard let bridge = StaticLibretroBridge.currentBridge else {
                return 0
            }
            
            let portInt = Int(port)
            let idInt = Int(id)
            
            // 记录被查询的按键 ID（仅调试时）
            #if DEBUG
            let now = CFAbsoluteTimeGetCurrent()
            StaticLibretroBridge.debugQueryIds.insert(idInt)
            if now - StaticLibretroBridge.debugLastLogTime > 5.0 {
                StaticLibretroBridge.debugQueryIds.removeAll()
                StaticLibretroBridge.debugLastLogTime = now
            }
            #endif
            
            // JOYPAD_MASK 模式：返回所有按键的位掩码 (id == 256)
            if id == UInt32(RETRO_DEVICE_ID_JOYPAD_MASK) {
                var mask: Int16 = 0
                for i in 0..<16 {
                    if bridge.inputState[portInt][i] != 0 {
                        mask |= Int16(1 << i)
                    }
                }
                return mask
            }
            
            guard portInt >= 0 && portInt < 4 && idInt >= 0 && idInt < 16 else { return 0 }
            
            return bridge.inputState[portInt][idInt]
        }
    }
    
    private func handleEnvironment(_ cmd: UInt32, data: UnsafeMutableRawPointer?) -> Bool {
        // Mask out the experimental flag
        let command = Int32(cmd & 0xFFFF)
        
        switch command {
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
            if let data = data {
                let format = data.assumingMemoryBound(to: UInt32.self).pointee
                switch format {
                case UInt32(RETRO_PIXEL_FORMAT_0RGB1555):
                    pixelFormat = .rgb1555
                case UInt32(RETRO_PIXEL_FORMAT_XRGB8888):
                    pixelFormat = .xrgb8888
                case UInt32(RETRO_PIXEL_FORMAT_RGB565):
                    pixelFormat = .rgb565
                default:
                    pixelFormat = .rgb565
                }
            }
            return true
            
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
            if let data = data {
                let pathPtr = data.assumingMemoryBound(to: UnsafePointer<CChar>?.self)
                if let buffer = systemDirectoryBuffer {
                    pathPtr.pointee = UnsafePointer(buffer)
                }
            }
            return true
            
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
            if let data = data {
                let pathPtr = data.assumingMemoryBound(to: UnsafePointer<CChar>?.self)
                if let buffer = saveDirectoryBuffer {
                    pathPtr.pointee = UnsafePointer(buffer)
                }
            }
            return true
            
        case RETRO_ENVIRONMENT_GET_CAN_DUPE:
            if let data = data {
                data.assumingMemoryBound(to: Bool.self).pointee = true
            }
            return true
            
        case RETRO_ENVIRONMENT_GET_LANGUAGE:
            if let data = data {
                data.assumingMemoryBound(to: UInt32.self).pointee = UInt32(RETRO_LANGUAGE_ENGLISH)
            }
            return true
            
        case RETRO_ENVIRONMENT_GET_LOG_INTERFACE:
            // Log interface not fully supported yet
            // Return false so cores use their fallback logging
            return false
            
        case RETRO_ENVIRONMENT_GET_VARIABLE:
            // Return false to indicate variable not found
            // Cores should use defaults
            return false
            
        case RETRO_ENVIRONMENT_SET_VARIABLES:
            // Accept variable definitions
            return true
            
        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
            if let data = data {
                data.assumingMemoryBound(to: Bool.self).pointee = false
            }
            return true
            
        case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
            return true
            
        case RETRO_ENVIRONMENT_GET_RUMBLE_INTERFACE:
            // Rumble not supported
            return false
            
        case RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL:
            return true
            
        case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
            return true
            
        case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
            return true
            
        case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION:
            if let data = data {
                data.assumingMemoryBound(to: UInt32.self).pointee = 0
            }
            return true
            
        case RETRO_ENVIRONMENT_SET_MESSAGE:
            // Accept message callbacks (cores may use this for status messages)
            return true
            
        case RETRO_ENVIRONMENT_SET_ROTATION:
            // Accept rotation requests
            return true
            
        case RETRO_ENVIRONMENT_GET_OVERSCAN:
            // Return false to indicate no overscan
            if let data = data {
                data.assumingMemoryBound(to: Bool.self).pointee = false
            }
            return true
            
        case RETRO_ENVIRONMENT_GET_AUDIO_VIDEO_ENABLE:
            // Return that both audio and video are enabled
            if let data = data {
                let flags = data.assumingMemoryBound(to: UInt32.self)
                flags.pointee = 3 // Both audio and video enabled
            }
            return true
            
        default:
            // Return false for unsupported commands
            // This is normal - not all commands need to be supported
            return false
        }
    }
}

