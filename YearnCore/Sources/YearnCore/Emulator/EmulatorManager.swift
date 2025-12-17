//
//  EmulatorManager.swift
//  YearnCore
//
//  Main emulator management class
//

import Foundation
import Combine

/// Manages emulation lifecycle and coordinates all subsystems
@MainActor
public final class EmulatorManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var state: EmulatorState = .stopped
    @Published public private(set) var currentCore: (any CoreAdapter)?
    @Published public private(set) var fps: Double = 0
    
    // MARK: - Subsystems
    
    public let audioEngine: AudioEngine
    public let videoRenderer: VideoRenderer
    public let inputManager: InputManager
    public let saveStateManager: SaveStateManager
    
    // MARK: - Private Properties
    
    private var emulationTask: Task<Void, Never>?
    private var frameCount: Int = 0
    private var lastFPSUpdate: Date = Date()
    
    // MARK: - Initialization
    
    public init() {
        self.audioEngine = AudioEngine()
        self.videoRenderer = VideoRenderer()
        self.inputManager = InputManager()
        self.saveStateManager = SaveStateManager()
    }
    
    // MARK: - Public Methods
    
    /// Load a game with the specified core adapter
    public func loadGame(url: URL, core: any CoreAdapter) throws {
        guard state == .stopped else {
            throw EmulatorError.invalidState("Cannot load game while emulator is running")
        }
        
        // Configure subsystems
        audioEngine.configure(format: core.audioFormat)
        videoRenderer.configure(format: core.videoFormat)
        inputManager.configure(mapping: core.inputMapping)
        
        // Load the game
        try core.load(romURL: url)
        
        currentCore = core
        state = .loaded
    }
    
    /// Start emulation
    public func start() {
        guard state == .loaded || state == .paused else { return }
        
        state = .running
        audioEngine.start()
        
        startEmulationLoop()
    }
    
    /// Pause emulation
    public func pause() {
        guard state == .running else { return }
        
        state = .paused
        audioEngine.pause()
        emulationTask?.cancel()
    }
    
    /// Resume emulation
    public func resume() {
        guard state == .paused else { return }
        
        state = .running
        audioEngine.resume()
        
        startEmulationLoop()
    }
    
    /// Stop emulation and unload the game
    public func stop() {
        emulationTask?.cancel()
        emulationTask = nil
        
        audioEngine.stop()
        currentCore?.unload()
        currentCore = nil
        
        state = .stopped
        fps = 0
    }
    
    /// Reset the current game
    public func reset() {
        currentCore?.reset()
    }
    
    // MARK: - Input Handling
    
    /// Handle input from virtual controller or physical gamepad
    public func handleInput(_ input: Int, pressed: Bool, playerIndex: Int = 0) {
        inputManager.setInput(input, pressed: pressed, playerIndex: playerIndex)
    }
    
    // MARK: - Save States
    
    /// Save state to the specified slot
    public func saveState(slot: Int) throws {
        guard let core = currentCore else {
            throw EmulatorError.noGameLoaded
        }
        
        let url = saveStateManager.saveStateURL(for: core.identifier, slot: slot)
        try core.saveState(to: url)
    }
    
    /// Load state from the specified slot
    public func loadState(slot: Int) throws {
        guard let core = currentCore else {
            throw EmulatorError.noGameLoaded
        }
        
        let url = saveStateManager.saveStateURL(for: core.identifier, slot: slot)
        try core.loadState(from: url)
    }
    
    // MARK: - Private Methods
    
    private func startEmulationLoop() {
        emulationTask = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled && self.state == .running {
                await self.runFrame()
                
                // Calculate target frame time based on core's frame duration
                let frameDuration = self.currentCore?.frameDuration ?? (1.0 / 60.0)
                try? await Task.sleep(nanoseconds: UInt64(frameDuration * 1_000_000_000))
            }
        }
    }
    
    private func runFrame() async {
        guard let core = currentCore else { return }
        
        // Get current input state
        let inputState = inputManager.currentState
        
        // Run one frame of emulation
        core.runFrame()
        
        // Update FPS counter
        frameCount += 1
        let now = Date()
        let elapsed = now.timeIntervalSince(lastFPSUpdate)
        if elapsed >= 1.0 {
            fps = Double(frameCount) / elapsed
            frameCount = 0
            lastFPSUpdate = now
        }
    }
}

// MARK: - Emulator Errors

public enum EmulatorError: LocalizedError {
    case invalidState(String)
    case noGameLoaded
    case coreNotFound
    case loadFailed(String)
    case saveFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidState(let message):
            return "Invalid state: \(message)"
        case .noGameLoaded:
            return "No game is currently loaded"
        case .coreNotFound:
            return "Emulator core not found"
        case .loadFailed(let message):
            return "Failed to load: \(message)"
        case .saveFailed(let message):
            return "Failed to save: \(message)"
        }
    }
}

