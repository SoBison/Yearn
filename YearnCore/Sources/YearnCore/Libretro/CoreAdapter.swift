//
//  CoreAdapter.swift
//  YearnCore
//
//  Protocol for emulator core adapters
//

import Foundation

/// Protocol that all emulator core adapters must implement
public protocol CoreAdapter: AnyObject {
    
    /// Required initializer
    init()
    
    // MARK: - Core Information
    
    /// Display name of the core
    var name: String { get }
    
    /// Unique identifier for the core
    var identifier: String { get }
    
    /// Version string
    var version: String { get }
    
    /// Supported file extensions (without dot)
    var supportedExtensions: [String] { get }
    
    // MARK: - Format Information
    
    /// Audio format used by this core
    var audioFormat: AudioFormat { get }
    
    /// Video format used by this core
    var videoFormat: VideoFormat { get }
    
    /// Input mapping for this core
    var inputMapping: InputMapping { get }
    
    /// Frame duration in seconds
    var frameDuration: TimeInterval { get }
    
    // MARK: - Lifecycle
    
    /// Load a ROM file
    func load(romURL: URL) throws
    
    /// Unload the current ROM
    func unload()
    
    /// Reset the emulation
    func reset()
    
    // MARK: - Emulation
    
    /// Run a single frame of emulation
    func runFrame()
    
    /// Set input state
    func setInput(_ input: Int, pressed: Bool, playerIndex: Int)
    
    // MARK: - Save States
    
    /// Save state to file
    func saveState(to url: URL) throws
    
    /// Load state from file
    func loadState(from url: URL) throws
    
    /// Get serialized state size
    var saveStateSize: Int { get }
    
    // MARK: - Game Saves (Battery/SRAM)
    
    /// Save game data (battery save)
    func saveGameData(to url: URL) throws
    
    /// Load game data (battery save)
    func loadGameData(from url: URL) throws
    
    // MARK: - Cheats (Optional)
    
    /// Add a cheat code
    func addCheat(code: String, enabled: Bool) -> Bool
    
    /// Remove all cheats
    func clearCheats()
    
    // MARK: - Callbacks
    
    /// Video output callback
    var videoCallback: ((UnsafeRawPointer, Int) -> Void)? { get set }
    
    /// Audio output callback
    var audioCallback: ((UnsafePointer<Int16>, Int) -> Void)? { get set }
}

// MARK: - Default Implementations

public extension CoreAdapter {
    
    var version: String { "1.0.0" }
    
    var frameDuration: TimeInterval {
        return 1.0 / videoFormat.frameRate
    }
    
    func addCheat(code: String, enabled: Bool) -> Bool {
        return false // Default: cheats not supported
    }
    
    func clearCheats() {
        // Default: no-op
    }
}

// MARK: - Core Errors

public enum CoreError: LocalizedError {
    case loadFailed(String)
    case saveFailed(String)
    case invalidState
    case unsupportedFormat
    case coreNotLoaded
    
    public var errorDescription: String? {
        switch self {
        case .loadFailed(let message):
            return "Failed to load: \(message)"
        case .saveFailed(let message):
            return "Failed to save: \(message)"
        case .invalidState:
            return "Invalid emulator state"
        case .unsupportedFormat:
            return "Unsupported file format"
        case .coreNotLoaded:
            return "No core is currently loaded"
        }
    }
}

