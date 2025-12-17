//
//  LibretroBridge.swift
//  YearnCore
//
//  Swift bridge to libretro cores
//

import Foundation
import CLibretro

/// Bridge class for loading and interacting with libretro cores
public final class LibretroBridge {
    
    // MARK: - Types
    
    /// Function pointer types matching libretro API
    public typealias RetroInit = @convention(c) () -> Void
    public typealias RetroDeinit = @convention(c) () -> Void
    public typealias RetroAPIVersion = @convention(c) () -> UInt32
    public typealias RetroGetSystemInfo = @convention(c) (UnsafeMutablePointer<retro_system_info>) -> Void
    public typealias RetroGetSystemAVInfo = @convention(c) (UnsafeMutablePointer<retro_system_av_info>) -> Void
    public typealias RetroSetEnvironment = @convention(c) (retro_environment_t?) -> Void
    public typealias RetroSetVideoRefresh = @convention(c) (retro_video_refresh_t?) -> Void
    public typealias RetroSetAudioSample = @convention(c) (retro_audio_sample_t?) -> Void
    public typealias RetroSetAudioSampleBatch = @convention(c) (retro_audio_sample_batch_t?) -> Void
    public typealias RetroSetInputPoll = @convention(c) (retro_input_poll_t?) -> Void
    public typealias RetroSetInputState = @convention(c) (retro_input_state_t?) -> Void
    public typealias RetroReset = @convention(c) () -> Void
    public typealias RetroRun = @convention(c) () -> Void
    public typealias RetroLoadGame = @convention(c) (UnsafePointer<retro_game_info>?) -> Bool
    public typealias RetroUnloadGame = @convention(c) () -> Void
    public typealias RetroSerializeSize = @convention(c) () -> Int
    public typealias RetroSerialize = @convention(c) (UnsafeMutableRawPointer?, Int) -> Bool
    public typealias RetroUnserialize = @convention(c) (UnsafeRawPointer?, Int) -> Bool
    public typealias RetroGetMemoryData = @convention(c) (UInt32) -> UnsafeMutableRawPointer?
    public typealias RetroGetMemorySize = @convention(c) (UInt32) -> Int
    public typealias RetroCheatReset = @convention(c) () -> Void
    public typealias RetroCheatSet = @convention(c) (UInt32, Bool, UnsafePointer<CChar>?) -> Void
    public typealias RetroGetRegion = @convention(c) () -> UInt32
    public typealias RetroSetControllerPortDevice = @convention(c) (UInt32, UInt32) -> Void
    
    // MARK: - Properties
    
    private var coreHandle: UnsafeMutableRawPointer?
    private var isLoaded = false
    private var gameLoaded = false
    
    // Function pointers
    private var retroInit: RetroInit?
    private var retroDeinit: RetroDeinit?
    private var retroAPIVersion: RetroAPIVersion?
    private var retroGetSystemInfo: RetroGetSystemInfo?
    private var retroGetSystemAVInfo: RetroGetSystemAVInfo?
    private var retroSetEnvironment: RetroSetEnvironment?
    private var retroSetVideoRefresh: RetroSetVideoRefresh?
    private var retroSetAudioSample: RetroSetAudioSample?
    private var retroSetAudioSampleBatch: RetroSetAudioSampleBatch?
    private var retroSetInputPoll: RetroSetInputPoll?
    private var retroSetInputState: RetroSetInputState?
    private var retroReset: RetroReset?
    private var retroRun: RetroRun?
    private var retroLoadGame: RetroLoadGame?
    private var retroUnloadGame: RetroUnloadGame?
    private var retroSerializeSize: RetroSerializeSize?
    private var retroSerialize: RetroSerialize?
    private var retroUnserialize: RetroUnserialize?
    private var retroGetMemoryData: RetroGetMemoryData?
    private var retroGetMemorySize: RetroGetMemorySize?
    private var retroCheatReset: RetroCheatReset?
    private var retroCheatSet: RetroCheatSet?
    private var retroGetRegion: RetroGetRegion?
    private var retroSetControllerPortDevice: RetroSetControllerPortDevice?
    
    // Callbacks
    public var videoCallback: ((UnsafeRawPointer, Int, Int, Int, LibretroPixelFormat) -> Void)?
    public var audioCallback: ((UnsafePointer<Int16>, Int) -> Void)?
    public var inputPollCallback: (() -> Void)?
    public var inputStateCallback: ((UInt32, UInt32, UInt32, UInt32) -> Int16)?
    public var logCallback: ((LogLevel, String) -> Void)?
    
    // System info
    public private(set) var systemInfo: SystemInfo?
    public private(set) var avInfo: AVInfo?
    public private(set) var pixelFormat: LibretroPixelFormat = .rgb565
    
    /// Convenience getter for core pixel format
    public var corePixelFormat: PixelFormat {
        return pixelFormat.toVideoPixelFormat()
    }
    
    // Environment variables
    private var systemDirectory: String
    private var saveDirectory: String
    private var coreAssetsDirectory: String
    
    // Input state
    private var inputState: [[Int16]] = Array(repeating: Array(repeating: 0, count: 16), count: 4)
    
    // MARK: - Singleton for callbacks
    
    fileprivate static var currentBridge: LibretroBridge?
    
    // MARK: - Initialization
    
    public init(systemDirectory: String? = nil, saveDirectory: String? = nil) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // BIOS 文件存放在 Documents/BIOS 目录
        // libretro 核心会在 system directory 中查找 BIOS 文件
        self.systemDirectory = systemDirectory ?? documentsPath.appendingPathComponent("BIOS").path
        self.saveDirectory = saveDirectory ?? documentsPath.appendingPathComponent("Saves").path
        self.coreAssetsDirectory = documentsPath.appendingPathComponent("CoreAssets").path
        
        // Create directories if needed
        createDirectoryIfNeeded(self.systemDirectory)
        createDirectoryIfNeeded(self.saveDirectory)
        createDirectoryIfNeeded(self.coreAssetsDirectory)
        
        print("📁 System/BIOS directory: \(self.systemDirectory)")
        print("📁 Save directory: \(self.saveDirectory)")
    }
    
    deinit {
        unloadCore()
    }
    
    // MARK: - Core Loading
    
    /// Load a libretro core from the specified path
    public func loadCore(at path: String) throws {
        guard !isLoaded else {
            throw LibretroError.alreadyLoaded
        }
        
        // Load the dynamic library
        coreHandle = dlopen(path, RTLD_LAZY)
        guard coreHandle != nil else {
            let error = String(cString: dlerror())
            throw LibretroError.loadFailed(error)
        }
        
        // Load all function pointers
        try loadFunctionPointers()
        
        // Set this as the current bridge for callbacks
        LibretroBridge.currentBridge = self
        
        // Setup environment callback first (before init)
        setupEnvironmentCallback()
        
        // Initialize the core
        retroInit?()
        
        // Setup other callbacks
        setupCallbacks()
        
        // Get system info
        var info = retro_system_info()
        retroGetSystemInfo?(&info)
        
        systemInfo = SystemInfo(
            libraryName: info.library_name != nil ? String(cString: info.library_name) : "Unknown",
            libraryVersion: info.library_version != nil ? String(cString: info.library_version) : "0.0",
            validExtensions: info.valid_extensions != nil ? String(cString: info.valid_extensions) : "",
            needFullpath: info.need_fullpath,
            blockExtract: info.block_extract
        )
        
        isLoaded = true
        log(.info, "Core loaded: \(systemInfo?.libraryName ?? "Unknown") v\(systemInfo?.libraryVersion ?? "0.0")")
    }
    
    /// Unload the current core
    public func unloadCore() {
        guard isLoaded else { return }
        
        if gameLoaded {
            unloadGame()
        }
        
        retroDeinit?()
        
        if let handle = coreHandle {
            dlclose(handle)
        }
        
        coreHandle = nil
        isLoaded = false
        systemInfo = nil
        avInfo = nil
        
        if LibretroBridge.currentBridge === self {
            LibretroBridge.currentBridge = nil
        }
        
        log(.info, "Core unloaded")
    }
    
    // MARK: - Game Loading
    
    /// Load a game ROM
    public func loadGame(path: String, data: Data? = nil) throws {
        guard isLoaded else {
            throw LibretroError.coreNotLoaded
        }
        
        guard !gameLoaded else {
            throw LibretroError.gameAlreadyLoaded
        }
        
        var gameInfo = retro_game_info()
        
        let pathCString = path.withCString { strdup($0) }
        defer { free(pathCString) }
        
        gameInfo.path = UnsafePointer(pathCString)
        
        if let data = data, !(systemInfo?.needFullpath ?? true) {
            // Pass data directly
            let success = data.withUnsafeBytes { buffer -> Bool in
                gameInfo.data = buffer.baseAddress
                gameInfo.size = buffer.count
                return retroLoadGame?(&gameInfo) ?? false
            }
            
            guard success else {
                throw LibretroError.gameLoadFailed
            }
        } else {
            // Load from path
            gameInfo.data = nil
            gameInfo.size = 0
            
            guard retroLoadGame?(&gameInfo) ?? false else {
                throw LibretroError.gameLoadFailed
            }
        }
        
        // Get AV info
        var info = retro_system_av_info()
        retroGetSystemAVInfo?(&info)
        
        avInfo = AVInfo(
            baseWidth: Int(info.geometry.base_width),
            baseHeight: Int(info.geometry.base_height),
            maxWidth: Int(info.geometry.max_width),
            maxHeight: Int(info.geometry.max_height),
            aspectRatio: info.geometry.aspect_ratio > 0 ? info.geometry.aspect_ratio : Float(info.geometry.base_width) / Float(info.geometry.base_height),
            fps: info.timing.fps,
            sampleRate: info.timing.sample_rate
        )
        
        gameLoaded = true
        log(.info, "Game loaded: \(path)")
    }
    
    /// Load a game ROM from URL
    public func loadGame(url: URL) throws {
        let path = url.path
        
        if systemInfo?.needFullpath == false {
            let data = try Data(contentsOf: url)
            try loadGame(path: path, data: data)
        } else {
            try loadGame(path: path, data: nil)
        }
    }
    
    /// Unload the current game
    public func unloadGame() {
        guard gameLoaded else { return }
        retroUnloadGame?()
        gameLoaded = false
        avInfo = nil
        log(.info, "Game unloaded")
    }
    
    // MARK: - Emulation
    
    /// Run one frame of emulation
    public func runFrame() {
        guard gameLoaded else { return }
        retroRun?()
    }
    
    /// Reset the emulation
    public func reset() {
        guard gameLoaded else { return }
        retroReset?()
        log(.info, "Emulation reset")
    }
    
    /// Get the region (NTSC/PAL)
    public var region: Region {
        guard let getRegion = retroGetRegion else { return .ntsc }
        return getRegion() == UInt32(RETRO_REGION_PAL) ? .pal : .ntsc
    }
    
    // MARK: - Input
    
    /// Set input state for a button
    public func setInput(port: Int, button: RetroButton, pressed: Bool) {
        guard port >= 0 && port < 4 else { return }
        inputState[port][button.rawValue] = pressed ? 1 : 0
    }
    
    /// Set analog input
    public func setAnalogInput(port: Int, stick: AnalogStick, x: Int16, y: Int16) {
        guard port >= 0 && port < 4 else { return }
        // Store analog values in extended input state
        // This would need a more sophisticated input system for full analog support
    }
    
    /// Clear all input
    public func clearInput() {
        for i in 0..<4 {
            for j in 0..<16 {
                inputState[i][j] = 0
            }
        }
    }
    
    /// Set controller type for a port
    public func setControllerType(port: Int, type: ControllerType) {
        retroSetControllerPortDevice?(UInt32(port), type.retroValue)
    }
    
    // MARK: - Save States
    
    /// Get the size needed for save state
    public var saveStateSize: Int {
        return retroSerializeSize?() ?? 0
    }
    
    /// Save state to data
    public func saveState() -> Data? {
        guard gameLoaded else { return nil }
        
        let size = saveStateSize
        guard size > 0 else { return nil }
        
        var data = Data(count: size)
        let success = data.withUnsafeMutableBytes { buffer -> Bool in
            return retroSerialize?(buffer.baseAddress!, size) ?? false
        }
        
        if success {
            log(.info, "State saved (\(size) bytes)")
        }
        
        return success ? data : nil
    }
    
    /// Save state to file
    public func saveState(to url: URL) throws {
        guard let data = saveState() else {
            throw LibretroError.saveStateFailed
        }
        try data.write(to: url)
    }
    
    /// Load state from data
    @discardableResult
    public func loadState(_ data: Data) -> Bool {
        guard gameLoaded else { return false }
        
        let success = data.withUnsafeBytes { buffer -> Bool in
            return retroUnserialize?(buffer.baseAddress!, buffer.count) ?? false
        }
        
        if success {
            log(.info, "State loaded (\(data.count) bytes)")
        }
        
        return success
    }
    
    /// Load state from file
    public func loadState(from url: URL) throws {
        let data = try Data(contentsOf: url)
        guard loadState(data) else {
            throw LibretroError.loadStateFailed
        }
    }
    
    // MARK: - Memory Access
    
    /// Get save RAM data
    public func getSaveRAM() -> Data? {
        guard let pointer = retroGetMemoryData?(UInt32(RETRO_MEMORY_SAVE_RAM)),
              let size = retroGetMemorySize?(UInt32(RETRO_MEMORY_SAVE_RAM)),
              size > 0 else {
            return nil
        }
        
        return Data(bytes: pointer, count: size)
    }
    
    /// Set save RAM data
    public func setSaveRAM(_ data: Data) {
        guard let pointer = retroGetMemoryData?(UInt32(RETRO_MEMORY_SAVE_RAM)),
              let size = retroGetMemorySize?(UInt32(RETRO_MEMORY_SAVE_RAM)),
              size > 0 else {
            return
        }
        
        data.withUnsafeBytes { buffer in
            memcpy(pointer, buffer.baseAddress!, min(buffer.count, size))
        }
    }
    
    /// Save battery RAM to file
    public func saveBatteryRAM(to url: URL) throws {
        guard let data = getSaveRAM() else {
            return // No save RAM, not an error
        }
        try data.write(to: url)
        log(.info, "Battery RAM saved")
    }
    
    /// Load battery RAM from file
    public func loadBatteryRAM(from url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return // No save file, not an error
        }
        let data = try Data(contentsOf: url)
        setSaveRAM(data)
        log(.info, "Battery RAM loaded")
    }
    
    /// Get RTC (Real Time Clock) data
    public func getRTCData() -> Data? {
        guard let pointer = retroGetMemoryData?(UInt32(RETRO_MEMORY_RTC)),
              let size = retroGetMemorySize?(UInt32(RETRO_MEMORY_RTC)),
              size > 0 else {
            return nil
        }
        return Data(bytes: pointer, count: size)
    }
    
    // MARK: - Cheats
    
    /// Reset all cheats
    public func resetCheats() {
        retroCheatReset?()
        log(.info, "Cheats reset")
    }
    
    /// Set a cheat code
    public func setCheat(index: UInt32, enabled: Bool, code: String) {
        code.withCString { codePtr in
            retroCheatSet?(index, enabled, codePtr)
        }
        log(.info, "Cheat \(index) \(enabled ? "enabled" : "disabled"): \(code)")
    }
    
    // MARK: - Private Methods
    
    private func createDirectoryIfNeeded(_ path: String) {
        if !FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
    }
    
    private func loadFunctionPointers() throws {
        guard let handle = coreHandle else {
            throw LibretroError.coreNotLoaded
        }
        
        func loadSymbol<T>(_ name: String) -> T? {
            guard let symbol = dlsym(handle, name) else { return nil }
            return unsafeBitCast(symbol, to: T.self)
        }
        
        retroInit = loadSymbol("retro_init")
        retroDeinit = loadSymbol("retro_deinit")
        retroAPIVersion = loadSymbol("retro_api_version")
        retroGetSystemInfo = loadSymbol("retro_get_system_info")
        retroGetSystemAVInfo = loadSymbol("retro_get_system_av_info")
        retroSetEnvironment = loadSymbol("retro_set_environment")
        retroSetVideoRefresh = loadSymbol("retro_set_video_refresh")
        retroSetAudioSample = loadSymbol("retro_set_audio_sample")
        retroSetAudioSampleBatch = loadSymbol("retro_set_audio_sample_batch")
        retroSetInputPoll = loadSymbol("retro_set_input_poll")
        retroSetInputState = loadSymbol("retro_set_input_state")
        retroReset = loadSymbol("retro_reset")
        retroRun = loadSymbol("retro_run")
        retroLoadGame = loadSymbol("retro_load_game")
        retroUnloadGame = loadSymbol("retro_unload_game")
        retroSerializeSize = loadSymbol("retro_serialize_size")
        retroSerialize = loadSymbol("retro_serialize")
        retroUnserialize = loadSymbol("retro_unserialize")
        retroGetMemoryData = loadSymbol("retro_get_memory_data")
        retroGetMemorySize = loadSymbol("retro_get_memory_size")
        retroCheatReset = loadSymbol("retro_cheat_reset")
        retroCheatSet = loadSymbol("retro_cheat_set")
        retroGetRegion = loadSymbol("retro_get_region")
        retroSetControllerPortDevice = loadSymbol("retro_set_controller_port_device")
        
        // Verify essential functions are loaded
        guard retroInit != nil,
              retroDeinit != nil,
              retroRun != nil,
              retroLoadGame != nil else {
            throw LibretroError.missingSymbols
        }
    }
    
    private func setupEnvironmentCallback() {
        retroSetEnvironment?({ cmd, data in
            guard let bridge = LibretroBridge.currentBridge else { return false }
            return bridge.handleEnvironmentCommand(cmd, data: data)
        })
    }
    
    private func handleEnvironmentCommand(_ cmd: UInt32, data: UnsafeMutableRawPointer?) -> Bool {
        switch Int32(cmd) {
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
                log(.debug, "Pixel format set to: \(pixelFormat)")
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
            
        case RETRO_ENVIRONMENT_GET_CORE_ASSETS_DIRECTORY:
            if let data = data {
                let pathPtr = data.assumingMemoryBound(to: UnsafePointer<CChar>?.self)
                pathPtr.pointee = (coreAssetsDirectory as NSString).utf8String
            }
            return true
            
        case RETRO_ENVIRONMENT_GET_LOG_INTERFACE:
            // Could implement log callback here
            return false
            
        case RETRO_ENVIRONMENT_GET_CAN_DUPE:
            if let data = data {
                data.assumingMemoryBound(to: Bool.self).pointee = true
            }
            return true
            
        case RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL:
            // Ignore performance hints
            return true
            
        case RETRO_ENVIRONMENT_GET_VARIABLE:
            // Core options - return false to use defaults
            return false
            
        case RETRO_ENVIRONMENT_SET_VARIABLES:
            // Core declares its options
            return true
            
        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
            if let data = data {
                data.assumingMemoryBound(to: Bool.self).pointee = false
            }
            return true
            
        case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
            return true
            
        case RETRO_ENVIRONMENT_GET_LANGUAGE:
            if let data = data {
                data.assumingMemoryBound(to: UInt32.self).pointee = UInt32(RETRO_LANGUAGE_ENGLISH)
            }
            return true
            
        case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS:
            if let data = data {
                data.assumingMemoryBound(to: Bool.self).pointee = true
            }
            return true
            
        default:
            log(.debug, "Unhandled environment command: \(cmd)")
            return false
        }
    }
    
    private func setupCallbacks() {
        retroSetVideoRefresh?({ data, width, height, pitch in
            guard let data = data,
                  let bridge = LibretroBridge.currentBridge else { return }
            bridge.videoCallback?(data, Int(width), Int(height), pitch, bridge.pixelFormat)
        })
        
        retroSetAudioSampleBatch?({ data, frames in
            guard let data = data,
                  let bridge = LibretroBridge.currentBridge else { return 0 }
            bridge.audioCallback?(data, Int(frames) * 2)
            return frames
        })
        
        retroSetInputPoll?({
            LibretroBridge.currentBridge?.inputPollCallback?()
        })
        
        retroSetInputState?({ port, device, index, id in
            guard let bridge = LibretroBridge.currentBridge else { return 0 }
            
            // Check if using bitmask query
            if id == UInt32(RETRO_DEVICE_ID_JOYPAD_MASK) {
                var mask: Int16 = 0
                for i in 0..<16 {
                    if bridge.inputState[Int(port)][i] != 0 {
                        mask |= Int16(1 << i)
                    }
                }
                return mask
            }
            
            // Check custom callback first
            if let callback = bridge.inputStateCallback {
                return callback(port, device, index, id)
            }
            
            // Return stored input state
            let portInt = Int(port)
            let idInt = Int(id)
            
            guard portInt >= 0 && portInt < 4 && idInt >= 0 && idInt < 16 else { return 0 }
            return bridge.inputState[portInt][idInt]
        })
    }
    
    private func log(_ level: LogLevel, _ message: String) {
        logCallback?(level, message)
        #if DEBUG
        print("[\(level)] \(message)")
        #endif
    }
}

// MARK: - Supporting Types

public struct SystemInfo {
    public let libraryName: String
    public let libraryVersion: String
    public let validExtensions: String
    public let needFullpath: Bool
    public let blockExtract: Bool
    
    public var extensionArray: [String] {
        return validExtensions.split(separator: "|").map { String($0) }
    }
}

public struct AVInfo {
    public let baseWidth: Int
    public let baseHeight: Int
    public let maxWidth: Int
    public let maxHeight: Int
    public let aspectRatio: Float
    public let fps: Double
    public let sampleRate: Double
}

// LibretroPixelFormat is defined in LibretroTypes.swift

public enum Region {
    case ntsc
    case pal
    
    public var fps: Double {
        switch self {
        case .ntsc: return 60.0
        case .pal: return 50.0
        }
    }
}

public enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

public enum RetroButton: Int {
    case b = 0
    case y = 1
    case select = 2
    case start = 3
    case up = 4
    case down = 5
    case left = 6
    case right = 7
    case a = 8
    case x = 9
    case l = 10
    case r = 11
    case l2 = 12
    case r2 = 13
    case l3 = 14
    case r3 = 15
}

public enum AnalogStick {
    case left
    case right
}

public enum ControllerType {
    case none
    case joypad
    case mouse
    case keyboard
    case lightgun
    case analog
    case pointer
    
    var retroValue: UInt32 {
        switch self {
        case .none: return UInt32(RETRO_DEVICE_NONE)
        case .joypad: return UInt32(RETRO_DEVICE_JOYPAD)
        case .mouse: return UInt32(RETRO_DEVICE_MOUSE)
        case .keyboard: return UInt32(RETRO_DEVICE_KEYBOARD)
        case .lightgun: return UInt32(RETRO_DEVICE_LIGHTGUN)
        case .analog: return UInt32(RETRO_DEVICE_ANALOG)
        case .pointer: return UInt32(RETRO_DEVICE_POINTER)
        }
    }
}

public enum LibretroError: LocalizedError {
    case alreadyLoaded
    case loadFailed(String)
    case coreNotLoaded
    case missingSymbols
    case gameLoadFailed
    case gameAlreadyLoaded
    case saveStateFailed
    case loadStateFailed
    
    public var errorDescription: String? {
        switch self {
        case .alreadyLoaded:
            return "A core is already loaded"
        case .loadFailed(let message):
            return "Failed to load core: \(message)"
        case .coreNotLoaded:
            return "No core is loaded"
        case .missingSymbols:
            return "Core is missing required symbols"
        case .gameLoadFailed:
            return "Failed to load game"
        case .gameAlreadyLoaded:
            return "A game is already loaded"
        case .saveStateFailed:
            return "Failed to save state"
        case .loadStateFailed:
            return "Failed to load state"
        }
    }
}
