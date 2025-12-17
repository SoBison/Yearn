//
//  SimpleStaticBridge.swift
//  YearnCore
//
//  A simplified bridge for a single statically linked libretro core
//  Uses standard retro_* functions without prefixes
//
//  注意：此文件已禁用，因为现在使用多核心模式（带前缀符号）
//  如果需要单核心模式，请定义 SINGLE_CORE_MODE 编译标志
//

import Foundation
import CLibretro

// =============================================================================
// MARK: - SimpleStaticBridge (已禁用)
// =============================================================================
// 此类用于单核心模式，使用无前缀的 retro_* 符号
// 现在使用 StaticLibretroBridge 和带前缀的多核心模式
// 如果需要启用，请取消下面的注释并定义 SINGLE_CORE_MODE

#if SINGLE_CORE_MODE

/// Simple bridge for a single statically linked core
/// This version directly calls the standard libretro C functions
public final class SimpleStaticBridge {
    
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
    private var systemDirectory: String
    private var saveDirectory: String
    
    // Input state
    private var inputState: [[Int16]] = Array(repeating: Array(repeating: 0, count: 16), count: 4)
    
    // Singleton for callbacks
    private static var currentBridge: SimpleStaticBridge?
    
    public init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.systemDirectory = documentsPath.appendingPathComponent("System").path
        self.saveDirectory = documentsPath.appendingPathComponent("Saves").path
        
        // Create directories
        try? FileManager.default.createDirectory(atPath: systemDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: saveDirectory, withIntermediateDirectories: true)
    }
    
    deinit {
        unloadCore()
    }
    
    /// Load the statically linked core
    public func loadCore() throws {
        guard !isLoaded else {
            throw LibretroError.alreadyLoaded
        }
        
        SimpleStaticBridge.currentBridge = self
        
        print("🔧 Setting up environment callback...")
        
        // Setup environment callback FIRST
        retro_set_environment { cmd, data in
            return SimpleStaticBridge.currentBridge?.handleEnvironment(cmd, data: data) ?? false
        }
        
        print("🔧 Calling retro_init...")
        
        // Initialize core
        retro_init()
        
        print("🔧 Setting up other callbacks...")
        
        // Setup other callbacks
        setupCallbacks()
        
        print("🔧 Getting system info...")
        
        // Get system info
        var info = retro_system_info()
        retro_get_system_info(&info)
        
        systemInfo = SystemInfo(
            libraryName: info.library_name != nil ? String(cString: info.library_name) : "Unknown",
            libraryVersion: info.library_version != nil ? String(cString: info.library_version) : "0.0",
            validExtensions: info.valid_extensions != nil ? String(cString: info.valid_extensions) : "",
            needFullpath: info.need_fullpath,
            blockExtract: info.block_extract
        )
        
        print("✅ Core loaded: \(systemInfo?.libraryName ?? "Unknown") v\(systemInfo?.libraryVersion ?? "?")")
        
        isLoaded = true
    }
    
    /// Unload the current core
    public func unloadCore() {
        guard isLoaded else { return }
        
        if gameLoaded {
            unloadGame()
        }
        
        retro_deinit()
        isLoaded = false
        systemInfo = nil
        avInfo = nil
        
        if SimpleStaticBridge.currentBridge === self {
            SimpleStaticBridge.currentBridge = nil
        }
    }
    
    /// Load a game
    public func loadGame(url: URL) throws {
        guard isLoaded else {
            throw LibretroError.coreNotLoaded
        }
        
        let path = url.path
        print("🎮 Loading game from: \(path)")
        
        // Check if core needs full path or data in memory
        let needFullpath = systemInfo?.needFullpath ?? false
        print("🎮 Core needs fullpath: \(needFullpath)")
        
        var success = false
        
        if needFullpath {
            // Core can load from path directly
            path.withCString { pathPtr in
                var gameInfo = retro_game_info()
                gameInfo.path = pathPtr
                gameInfo.data = nil
                gameInfo.size = 0
                gameInfo.meta = nil
                
                success = retro_load_game(&gameInfo)
            }
        } else {
            // Core needs ROM data in memory
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
                    
                    success = retro_load_game(&gameInfo)
                }
            }
        }
        
        guard success else {
            print("❌ retro_load_game returned false")
            throw LibretroError.loadFailed("Failed to load game")
        }
        
        print("✅ retro_load_game succeeded")
        
        // Get AV info
        var info = retro_system_av_info()
        retro_get_system_av_info(&info)
        
        avInfo = AVInfo(
            baseWidth: Int(info.geometry.base_width),
            baseHeight: Int(info.geometry.base_height),
            maxWidth: Int(info.geometry.max_width),
            maxHeight: Int(info.geometry.max_height),
            aspectRatio: info.geometry.aspect_ratio > 0 ? info.geometry.aspect_ratio : Float(info.geometry.base_width) / Float(info.geometry.base_height),
            fps: info.timing.fps,
            sampleRate: info.timing.sample_rate
        )
        
        print("✅ AV Info: \(avInfo!.baseWidth)x\(avInfo!.baseHeight) @ \(avInfo!.fps) FPS")
        
        gameLoaded = true
    }
    
    /// Unload the current game
    public func unloadGame() {
        guard gameLoaded else { return }
        retro_unload_game()
        gameLoaded = false
        avInfo = nil
    }
    
    /// Run one frame
    public func runFrame() {
        guard gameLoaded else {
            print("⚠️ runFrame called but no game loaded")
            return
        }
        retro_run()
    }
    
    /// Reset the game
    public func reset() {
        guard gameLoaded else { return }
        retro_reset()
    }
    
    /// Set input state
    public func setInput(port: Int, button: RetroButton, pressed: Bool) {
        guard port >= 0 && port < 4 else { return }
        inputState[port][button.rawValue] = pressed ? 1 : 0
        if pressed {
            print("🕹️ SimpleStaticBridge: Button \(button.rawValue) pressed on port \(port), inputState: \(inputState[port])")
        }
    }
    
    /// Save state
    public func saveState() -> Data? {
        guard gameLoaded else { return nil }
        
        let size = retro_serialize_size()
        guard size > 0 else { return nil }
        
        var data = Data(count: size)
        let success = data.withUnsafeMutableBytes { buffer -> Bool in
            return retro_serialize(buffer.baseAddress!, size)
        }
        
        return success ? data : nil
    }
    
    /// Load state
    public func loadState(_ data: Data) -> Bool {
        guard gameLoaded else { return false }
        
        return data.withUnsafeBytes { buffer -> Bool in
            return retro_unserialize(buffer.baseAddress!, buffer.count)
        }
    }
    
    /// Get save RAM
    public func getSaveRAM() -> Data? {
        guard let pointer = retro_get_memory_data(UInt32(RETRO_MEMORY_SAVE_RAM)) else {
            return nil
        }
        
        let size = retro_get_memory_size(UInt32(RETRO_MEMORY_SAVE_RAM))
        guard size > 0 else { return nil }
        
        return Data(bytes: pointer, count: size)
    }
    
    /// Set save RAM
    public func setSaveRAM(_ data: Data) {
        guard let pointer = retro_get_memory_data(UInt32(RETRO_MEMORY_SAVE_RAM)) else {
            return
        }
        
        let size = retro_get_memory_size(UInt32(RETRO_MEMORY_SAVE_RAM))
        guard size > 0 else { return }
        
        data.withUnsafeBytes { buffer in
            memcpy(pointer, buffer.baseAddress!, min(buffer.count, size))
        }
    }
    
    // MARK: - Private
    
    private func setupCallbacks() {
        print("🔧 Setting up video refresh callback...")
        retro_set_video_refresh { data, width, height, pitch in
            guard let data = data,
                  let bridge = SimpleStaticBridge.currentBridge else {
                print("⚠️ Video callback: data or bridge is nil")
                return
            }
            bridge.videoCallback?(data, Int(width), Int(height), pitch, bridge.pixelFormat)
        }
        
        // Set single sample callback (some cores use this)
        retro_set_audio_sample { left, right in
            // Most cores use batch, but we need to provide this callback
        }
        
        retro_set_audio_sample_batch { data, frames in
            guard let data = data,
                  let bridge = SimpleStaticBridge.currentBridge else { return 0 }
            bridge.audioCallback?(data, Int(frames) * 2)
            return frames
        }
        
        retro_set_input_poll {
            SimpleStaticBridge.currentBridge?.inputPollCallback?()
        }
        
        retro_set_input_state { port, device, index, id in
            guard let bridge = SimpleStaticBridge.currentBridge else { return 0 }
            
            if id == UInt32(RETRO_DEVICE_ID_JOYPAD_MASK) {
                var mask: Int16 = 0
                for i in 0..<16 {
                    if bridge.inputState[Int(port)][i] != 0 {
                        mask |= Int16(1 << i)
                    }
                }
                return mask
            }
            
            let portInt = Int(port)
            let idInt = Int(id)
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
                print("🎨 Pixel format set to: \(pixelFormat)")
            }
            return true
            
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
            if let data = data {
                let pathPtr = data.assumingMemoryBound(to: UnsafePointer<CChar>?.self)
                pathPtr.pointee = (systemDirectory as NSString).utf8String
            }
            return true
            
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
            if let data = data {
                let pathPtr = data.assumingMemoryBound(to: UnsafePointer<CChar>?.self)
                pathPtr.pointee = (saveDirectory as NSString).utf8String
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
            return false
            
        case RETRO_ENVIRONMENT_GET_VARIABLE:
            return false
            
        case RETRO_ENVIRONMENT_SET_VARIABLES:
            return true
            
        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
            if let data = data {
                data.assumingMemoryBound(to: Bool.self).pointee = false
            }
            return true
            
        case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
            return true
            
        case RETRO_ENVIRONMENT_GET_RUMBLE_INTERFACE:
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
            
        default:
            return false
        }
    }
}

#else

// MARK: - 占位符类（多核心模式）
// 在多核心模式下提供一个空的占位符，避免编译错误

/// 占位符类 - 在多核心模式下不可用
/// 请使用 StaticLibretroBridge 代替
@available(*, unavailable, message: "SimpleStaticBridge 在多核心模式下不可用，请使用 StaticLibretroBridge")
public final class SimpleStaticBridge {
    public init() {
        fatalError("SimpleStaticBridge 在多核心模式下不可用")
    }
}

#endif
