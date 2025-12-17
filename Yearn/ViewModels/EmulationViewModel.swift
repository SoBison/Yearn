//
//  EmulationViewModel.swift
//  Yearn
//
//  View model for emulation
//

import Foundation
import SwiftUI
import Combine
import AVFoundation
import YearnCore

@MainActor
class EmulationViewModel: ObservableObject {
    let game: Game
    
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var isFastForwarding = false
    @Published var errorMessage: String?
    @Published var currentFPS: Double = 0
    @Published var frameTexture: MTLTexture?
    @Published var currentScreenshot: UIImage?
    
    // Speed settings
    @Published var emulationSpeed: EmulationSpeed = .normal
    
    // Core components
    private var bridge: LibretroBridge?
    private var staticBridge: StaticLibretroBridge?
    // simpleBridge 已移除 - 现在使用多核心模式
    private var useStaticCore: Bool = false
    // useSimpleBridge 已移除 - 现在使用多核心模式
    private var displayLink: CADisplayLink?
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    
    // Frame timing
    private var targetFPS: Double = 60.0
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var fpsUpdateTime: CFTimeInterval = 0
    private var framesToSkip: Int = 0
    private var currentFrameSkip: Int = 0
    
    // Video buffer
    private var videoBuffer: UnsafeMutableRawPointer?
    private var videoBufferCapacity: Int = 0
    private var videoWidth: Int = 0
    private var videoHeight: Int = 0
    private var videoPitch: Int = 0
    private var videoPixelFormat: LibretroPixelFormat = .rgb565
    
    // Debug: video frame counter
    private var debugVideoFrameCount: Int = 0
    
    // Audio buffer
    private var audioBuffer: [Int16] = []
    private var sampleRate: Double = 44100
    
    // Input state
    private var inputState: [GameInput: Bool] = [:]
    
    // Save paths
    private var saveStatePath: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("SaveStates/\(game.id)")
    }
    
    private var batterySavePath: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Saves/\(game.id).sav")
    }
    
    init(game: Game) {
        self.game = game
        setupDirectories()
    }
    
    deinit {
        // Clean up - invalidate display link and audio directly
        displayLink?.invalidate()
        audioPlayerNode?.stop()
        audioEngine?.stop()
        // Note: bridge cleanup will happen when it's deallocated
    }
    
    // MARK: - Lifecycle
    
    func start() {
        guard !isRunning else { return }
        
        Task {
            do {
                try await loadCore()
                try await loadGame()
                setupAudio()
                startEmulationLoop()
                isRunning = true
                isPaused = false
            } catch {
                errorMessage = error.localizedDescription
                print("Failed to start emulation: \(error)")
            }
        }
    }
    
    func stop() {
        guard isRunning else { return }
        
        // Save battery RAM before stopping
        saveBatteryRAM()
        
        stopEmulationLoop()
        stopAudio()
        
        if useStaticCore {
            staticBridge?.unloadGame()
            staticBridge?.unloadCore()
            staticBridge = nil
        } else {
            bridge?.unloadGame()
            bridge?.unloadCore()
            bridge = nil
        }
        
        isRunning = false
        isPaused = false
        useStaticCore = false
    }
    
    func pause() {
        guard isRunning && !isPaused else { return }
        isPaused = true
        displayLink?.isPaused = true
        audioPlayerNode?.pause()
    }
    
    func resume() {
        guard isRunning && isPaused else { return }
        isPaused = false
        displayLink?.isPaused = false
        audioPlayerNode?.play()
    }
    
    // MARK: - Fast Forward
    
    func startFastForward() {
        guard isRunning && !isPaused else { return }
        isFastForwarding = true
        emulationSpeed = .fast
        updateEmulationSpeed()
    }
    
    func stopFastForward() {
        isFastForwarding = false
        emulationSpeed = .normal
        updateEmulationSpeed()
    }
    
    func setSpeed(_ speed: EmulationSpeed) {
        emulationSpeed = speed
        updateEmulationSpeed()
    }
    
    private func updateEmulationSpeed() {
        // Adjust frame rate and audio
        let speedMultiplier = emulationSpeed.multiplier
        
        // Update display link frame rate
        let adjustedFPS = min(targetFPS * speedMultiplier, 120.0)
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: 30,
            maximum: Float(adjustedFPS),
            preferred: Float(adjustedFPS)
        )
        
        // Calculate frame skip for fast forward
        if speedMultiplier > 1.0 {
            framesToSkip = Int(speedMultiplier) - 1
            // Mute audio during fast forward to prevent glitches
            audioPlayerNode?.volume = 0
        } else if speedMultiplier < 1.0 {
            framesToSkip = 0
            audioPlayerNode?.volume = 1.0
        } else {
            framesToSkip = 0
            audioPlayerNode?.volume = 1.0
        }
    }
    
    // MARK: - Video Buffer Access
    
    struct VideoBufferData {
        let data: Data
        let width: Int
        let height: Int
        let pitch: Int
        let pixelFormat: LibretroPixelFormat
    }
    
    func getVideoBuffer() -> VideoBufferData? {
        guard let buffer = videoBuffer,
              videoWidth > 0 && videoHeight > 0 else {
            return nil
        }
        
        let size = videoPitch * videoHeight
        let data = Data(bytes: buffer, count: size)
        return VideoBufferData(data: data, width: videoWidth, height: videoHeight, pitch: videoPitch, pixelFormat: videoPixelFormat)
    }
    
    // Debug: Check if video callback is being called
    var videoFrameCount: Int = 0
    
    // MARK: - Screenshot
    
    func takeScreenshot() -> UIImage? {
        guard let buffer = videoBuffer,
              videoWidth > 0 && videoHeight > 0 else {
            return nil
        }
        
        // Create CGImage from video buffer
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        
        guard let context = CGContext(
            data: buffer,
            width: videoWidth,
            height: videoHeight,
            bitsPerComponent: 8,
            bytesPerRow: videoPitch,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        guard let cgImage = context.makeImage() else {
            return nil
        }
        
        let screenshot = UIImage(cgImage: cgImage)
        currentScreenshot = screenshot
        
        return screenshot
    }
    
    func saveScreenshot() async throws -> URL {
        guard let screenshot = takeScreenshot() else {
            throw EmulationError.screenshotFailed
        }
        
        guard let data = screenshot.pngData() else {
            throw EmulationError.screenshotFailed
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let screenshotsPath = documentsPath.appendingPathComponent("Screenshots/\(game.id)")
        try FileManager.default.createDirectory(at: screenshotsPath, withIntermediateDirectories: true)
        
        let fileName = "\(game.name)_\(Date().timeIntervalSince1970).png"
        let fileURL = screenshotsPath.appendingPathComponent(fileName)
        
        try data.write(to: fileURL)
        
        // Also save to photo library if permission granted
        UIImageWriteToSavedPhotosAlbum(screenshot, nil, nil, nil)
        
        return fileURL
    }
    
    // MARK: - Reset
    
    func reset() {
        if useStaticCore {
            staticBridge?.reset()
        } else {
            bridge?.reset()
        }
    }
    
    // MARK: - Input
    
    func handleInput(_ input: GameInput, pressed: Bool) {
        inputState[input] = pressed
        
        let button = input.retroButton
        if useStaticCore {
            staticBridge?.setInput(port: 0, button: button, pressed: pressed)
        } else {
            bridge?.setInput(port: 0, button: button, pressed: pressed)
        }
    }
    
    // MARK: - Save States
    
    func saveState(to slot: Int) async throws {
        let url = saveStatePath.appendingPathComponent("slot\(slot).state")
        
        if useStaticCore {
            guard let data = staticBridge?.saveState() else {
                throw EmulationError.notRunning
            }
            try data.write(to: url)
        } else {
            guard let bridge = bridge else {
                throw EmulationError.notRunning
            }
            try bridge.saveState(to: url)
        }
    }
    
    func loadState(from slot: Int) async throws {
        let url = saveStatePath.appendingPathComponent("slot\(slot).state")
        
        if useStaticCore {
            guard let staticBridge = staticBridge else {
                throw EmulationError.notRunning
            }
            let data = try Data(contentsOf: url)
            guard staticBridge.loadState(data) else {
                throw EmulationError.notRunning
            }
        } else {
            guard let bridge = bridge else {
                throw EmulationError.notRunning
            }
            try bridge.loadState(from: url)
        }
    }
    
    func getSaveStateSlots() -> [SaveStateSlot] {
        var slots: [SaveStateSlot] = []
        
        for i in 0..<10 {
            let url = saveStatePath.appendingPathComponent("slot\(i).state")
            let exists = FileManager.default.fileExists(atPath: url.path)
            var date: Date?
            
            if exists {
                date = try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
            }
            
            slots.append(SaveStateSlot(index: i, exists: exists, date: date))
        }
        
        return slots
    }
    
    // MARK: - Private Methods
    
    private func setupDirectories() {
        let fm = FileManager.default
        try? fm.createDirectory(at: saveStatePath, withIntermediateDirectories: true)
        try? fm.createDirectory(at: batterySavePath.deletingLastPathComponent(), withIntermediateDirectories: true)
    }
    
    private func loadCore() async throws {
        print("🎮 Loading core for system: \(game.system.rawValue)")
        
        #if STATIC_CORES_ENABLED
        // 使用 StaticLibretroBridge 支持多核心
        // 根据游戏系统选择对应的核心
        let coreIdentifier = getCoreIdentifierForSystem(game.system)
        print("🎮 Using StaticLibretroBridge (multi-core mode)")
        print("🎮 Selected core: \(coreIdentifier) for system: \(game.system.rawValue)")
        
        // 确保核心已注册
        registerAllStaticCores()
        
        // 检查核心是否可用
        guard let coreInfo = StaticCoreRegistry.shared.getCore(identifier: coreIdentifier) else {
            print("❌ Core not found in registry: \(coreIdentifier)")
            throw EmulationError.coreNotFound
        }
        
        print("🎮 Found core: \(coreInfo.name) for \(coreInfo.systemName)")
        
        staticBridge = StaticLibretroBridge()
        
        do {
            try staticBridge?.loadCore(identifier: coreIdentifier)
            print("✅ Static core loaded: \(coreInfo.name)")
            useStaticCore = true
            setupStaticCallbacks()
            return
        } catch {
            print("❌ Failed to load static core: \(error)")
            staticBridge = nil
            throw error
        }
        
        #else
        // Fall back to dynamic core (for simulator/development)
        print("🎮 Using dynamic core (STATIC_CORES_ENABLED not defined)")
        useStaticCore = false
        bridge = LibretroBridge()
        
        // Find the appropriate core for this game system
        guard let corePath = getCorePathForSystem(game.system) else {
            print("❌ Core not found for system: \(game.system.rawValue)")
            throw EmulationError.coreNotFound
        }
        
        print("🎮 Core path: \(corePath)")
        
        do {
            try bridge?.loadCore(at: corePath)
            print("✅ Dynamic core loaded successfully")
        } catch {
            print("❌ Failed to load core: \(error)")
            throw error
        }
        
        // Setup callbacks
        setupCallbacks()
        print("✅ Callbacks setup complete")
        #endif
    }
    
    private func getCoreIdentifierForSystem(_ system: GameSystem) -> String {
        switch system {
        case .nes: return "fceumm"
        case .snes: return "bsnes"  // 使用 bsnes (GPL v3) 替代 snes9x (非商业许可证)
        case .gbc: return "gambatte"
        case .gba: return "mgba"
        case .n64: return "mupen64plus_next"
        case .nds: return "melonds"
        case .genesis: return "clownmdemu"  // 使用 ClownMDEmu (AGPL v3) 替代 Genesis Plus GX (非商业)
        case .ps1: return "pcsx_rearmed"
        }
    }
    
    private func loadGame() async throws {
        print("🎮 Loading game: \(game.name)")
        print("🎮 Game file URL: \(game.fileURL.path)")
        
        // Verify file exists
        if !FileManager.default.fileExists(atPath: game.fileURL.path) {
            print("❌ Game file does not exist at: \(game.fileURL.path)")
            throw EmulationError.gameNotFound
        }
        
        // For PS1, if loading .img or .bin file, try to find or create accompanying .cue file
        var gameURLToLoad = game.fileURL
        if game.system == .ps1 {
            let ext = game.fileURL.pathExtension.lowercased()
            if ext == "img" || ext == "bin" {
                let baseName = game.fileURL.deletingPathExtension().lastPathComponent
                let directory = game.fileURL.deletingLastPathComponent()
                let cueURL = directory.appendingPathComponent(baseName).appendingPathExtension("cue")
                
                if FileManager.default.fileExists(atPath: cueURL.path) {
                    print("🎮 Found .cue file for \(ext) file, using: \(cueURL.lastPathComponent)")
                    gameURLToLoad = cueURL
                } else {
                    print("⚠️ .cue file not found for \(ext) file.")
                    
                    // Check if there's a .ccd file (CloneCD format)
                    let ccdURL = directory.appendingPathComponent(baseName).appendingPathExtension("ccd")
                    if FileManager.default.fileExists(atPath: ccdURL.path) {
                        print("📀 Found .ccd file (CloneCD format). Creating .cue file...")
                        
                        // Try to parse .ccd file for track information
                        var trackMode = "MODE2/2352" // Default for PS1
                        if let ccdContent = try? String(contentsOf: ccdURL, encoding: .utf8) {
                            print("📀 Parsing .ccd file...")
                            // Look for track mode in .ccd file
                            if ccdContent.contains("MODE=2") {
                                trackMode = "MODE2/2352"
                                print("📀 Detected MODE2/2352 (PS1 CD-ROM XA)")
                            } else if ccdContent.contains("MODE=1") {
                                trackMode = "MODE1/2352"
                                print("📀 Detected MODE1/2352 (CD-ROM)")
                            }
                        }
                        
                        // Create a .cue file for CloneCD .img format
                        let cueContent = """
                        FILE "\(game.fileURL.lastPathComponent)" BINARY
                          TRACK 01 \(trackMode)
                            INDEX 01 00:00:00
                        """
                        
                        do {
                            try cueContent.write(to: cueURL, atomically: true, encoding: .utf8)
                            print("✅ Created .cue file with \(trackMode): \(cueURL.lastPathComponent)")
                            gameURLToLoad = cueURL
                        } catch {
                            print("❌ Failed to create .cue file: \(error)")
                            print("⚠️ Attempting to load .img directly, may not work correctly.")
                        }
                    } else {
                        print("⚠️ Expected .cue file at: \(cueURL.path)")
                        print("⚠️ Attempting to load .img directly, may not work correctly.")
                    }
                }
            }
        }
        
        if useStaticCore {
            guard let staticBridge = staticBridge else {
                print("❌ Static bridge is nil")
                throw EmulationError.notRunning
            }
            
            do {
                try staticBridge.loadGame(url: gameURLToLoad)
                print("✅ Game loaded successfully (static)")
            } catch {
                print("❌ Failed to load game: \(error)")
                throw error
            }
            
            // Get AV info from static bridge
            if let avInfo = staticBridge.avInfo {
                videoWidth = avInfo.baseWidth
                videoHeight = avInfo.baseHeight
                targetFPS = avInfo.fps
                sampleRate = avInfo.sampleRate
                print("✅ AV Info: \(videoWidth)x\(videoHeight) @ \(targetFPS) FPS, \(sampleRate) Hz")
            } else {
                print("⚠️ No AV info available")
            }
        } else {
            guard let bridge = bridge else {
                print("❌ Bridge is nil")
                throw EmulationError.notRunning
            }
            
            do {
                try bridge.loadGame(url: gameURLToLoad)
                print("✅ Game loaded successfully (dynamic)")
            } catch {
                print("❌ Failed to load game: \(error)")
                throw error
            }
            
            // Get AV info from dynamic bridge
            if let avInfo = bridge.avInfo {
                videoWidth = avInfo.baseWidth
                videoHeight = avInfo.baseHeight
                targetFPS = avInfo.fps
                sampleRate = avInfo.sampleRate
                print("✅ AV Info: \(videoWidth)x\(videoHeight) @ \(targetFPS) FPS, \(sampleRate) Hz")
            } else {
                print("⚠️ No AV info available")
            }
        }
        
        // Load battery save if exists
        loadBatteryRAM()
    }
    
    private func setupCallbacks() {
        bridge?.videoCallback = { [weak self] data, width, height, pitch, format in
            self?.handleVideoFrame(data: data, width: width, height: height, pitch: pitch, format: format)
        }
        
        bridge?.audioCallback = { [weak self] data, samples in
            self?.handleAudioSamples(data: data, samples: samples)
        }
        
        bridge?.inputPollCallback = {
            // Input is updated directly via handleInput
            // No action needed here
        }
    }
    
    private func setupStaticCallbacks() {
        staticBridge?.videoCallback = { [weak self] data, width, height, pitch, format in
            self?.handleVideoFrame(data: data, width: width, height: height, pitch: pitch, format: format)
        }
        
        staticBridge?.audioCallback = { [weak self] data, samples in
            self?.handleAudioSamples(data: data, samples: samples)
        }
        
        staticBridge?.inputPollCallback = {
            // Input is updated directly via handleInput
            // No action needed here
        }
    }
    
    // setupSimpleCallbacks 已移除 - 现在使用多核心模式
    
    
    private func handleVideoFrame(data: UnsafeRawPointer, width: Int, height: Int, pitch: Int, format: LibretroPixelFormat = .rgb565) {
        // Store frame data for rendering
        videoWidth = width
        videoHeight = height
        videoPitch = pitch
        videoPixelFormat = format
        
        // 验证数据指针有效性
        let size = pitch * height
        guard size > 0 else {
            #if DEBUG
            print("⚠️ Invalid video frame size: \(size), pitch: \(pitch), height: \(height)")
            #endif
            return
        }

        if videoBuffer == nil || size > videoBufferCapacity {
            videoBuffer?.deallocate()
            videoBuffer = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 4)
            videoBufferCapacity = size
        }
        
        videoBuffer?.copyMemory(from: data, byteCount: size)
        
        // 调试：检查复制后的数据
        #if DEBUG
        debugVideoFrameCount += 1
        if debugVideoFrameCount <= 5 || debugVideoFrameCount % 300 == 0 {
            if let buffer = videoBuffer {
                let bytes = buffer.bindMemory(to: UInt8.self, capacity: size)
                var nonZeroCount = 0
                for i in 0..<min(100, size) {
                    if bytes[i] != 0 {
                        nonZeroCount += 1
                    }
                }
                if nonZeroCount == 0 {
                    print("⚠️ Copied video data is all zeros (frame #\(debugVideoFrameCount), size=\(size))")
                } else {
                    print("✅ Video data has \(nonZeroCount) non-zero bytes in first 100 (frame #\(debugVideoFrameCount))")
                }
            }
        }
        #endif
    }
    
    private func handleAudioSamples(data: UnsafePointer<Int16>, samples: Int) {
        // Buffer audio samples for playback
        let buffer = UnsafeBufferPointer(start: data, count: samples)
        audioBuffer.append(contentsOf: buffer)
        
        // Play buffered audio
        playAudioBuffer()
    }
    
    // MARK: - Emulation Loop
    
    private func startEmulationLoop() {
        displayLink = CADisplayLink(target: self, selector: #selector(runFrame))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: Float(targetFPS), preferred: Float(targetFPS))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopEmulationLoop() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    private var crashFrameCount = 0
    
    @objc private func runFrame(_ displayLink: CADisplayLink) {
        guard !isPaused else { return }
        guard isRunning else { return }
        
        crashFrameCount += 1
        
        // Handle frame skipping for fast forward
        if framesToSkip > 0 {
            for _ in 0..<framesToSkip {
                if useStaticCore {
                    staticBridge?.runFrame()
                } else {
                    bridge?.runFrame()
                }
            }
        }
        
        // Run one frame with crash detection
        if useStaticCore {
            staticBridge?.runFrame()
        } else {
            bridge?.runFrame()
        }
        
        // Update FPS counter
        frameCount += 1
        let currentTime = displayLink.timestamp
        
        if currentTime - fpsUpdateTime >= 1.0 {
            currentFPS = Double(frameCount) / (currentTime - fpsUpdateTime) * emulationSpeed.multiplier
            frameCount = 0
            fpsUpdateTime = currentTime
        }
    }
    
    // MARK: - Audio
    
    private func setupAudio() {
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine,
              let player = audioPlayerNode else { return }
        
        engine.attach(player)
        
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        engine.connect(player, to: engine.mainMixerNode, format: format)
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            player.play()
        } catch {
            print("Audio setup failed: \(error)")
        }
    }
    
    private func stopAudio() {
        audioPlayerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        audioPlayerNode = nil
    }
    
    private func playAudioBuffer() {
        guard let player = audioPlayerNode,
              audioBuffer.count >= 2048 else { return }
        
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let frameCount = AVAudioFrameCount(audioBuffer.count / 2)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        
        // Convert Int16 to Float32
        let floatData = buffer.floatChannelData!
        for i in 0..<Int(frameCount) {
            let leftSample = Float(audioBuffer[i * 2]) / 32768.0
            let rightSample = Float(audioBuffer[i * 2 + 1]) / 32768.0
            floatData[0][i] = leftSample
            floatData[1][i] = rightSample
        }
        
        player.scheduleBuffer(buffer)
        audioBuffer.removeAll()
    }
    
    // MARK: - Battery Save
    
    private func saveBatteryRAM() {
        if useStaticCore {
            guard let data = staticBridge?.getSaveRAM() else { return }
            try? data.write(to: batterySavePath)
        } else {
            guard let bridge = bridge else { return }
            try? bridge.saveBatteryRAM(to: batterySavePath)
        }
    }
    
    private func loadBatteryRAM() {
        if useStaticCore {
            guard let staticBridge = staticBridge,
                  FileManager.default.fileExists(atPath: batterySavePath.path),
                  let data = try? Data(contentsOf: batterySavePath) else { return }
            staticBridge.setSaveRAM(data)
        } else {
            guard let bridge = bridge else { return }
            try? bridge.loadBatteryRAM(from: batterySavePath)
        }
    }
    
    // MARK: - Core Path
    
    private func getCorePathForSystem(_ system: GameSystem) -> String? {
        // Core file names - try macOS version first (for simulator), then iOS version
        let coreFileNames: [String]
        switch system {
        case .nes: 
            coreFileNames = ["fceumm_libretro.dylib", "fceumm_libretro_ios.dylib"]
        case .snes: 
            coreFileNames = ["snes9x_libretro.dylib", "snes9x_libretro_ios.dylib"]
        case .gbc: 
            coreFileNames = ["gambatte_libretro.dylib", "gambatte_libretro_ios.dylib"]
        case .gba: 
            coreFileNames = ["mgba_libretro.dylib", "mgba_libretro_ios.dylib"]
        case .n64: 
            coreFileNames = ["mupen64plus_next_libretro.dylib", "mupen64plus_next_libretro_ios.dylib"]
        case .nds: 
            coreFileNames = ["melonds_libretro.dylib", "melonds_libretro_ios.dylib"]
        case .genesis: 
            coreFileNames = ["genesis_plus_gx_libretro.dylib", "genesis_plus_gx_libretro_ios.dylib"]
        case .ps1: 
            coreFileNames = ["pcsx_rearmed_libretro.dylib", "pcsx_rearmed_libretro_ios.dylib"]
        }
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let coresURL = documentsURL.appendingPathComponent("Cores")
        
        // Try each core file name
        for coreFileName in coreFileNames {
            // 1. Check app bundle Resources/Cores
            if let bundlePath = Bundle.main.path(forResource: coreFileName, ofType: nil, inDirectory: "Cores") {
                print("Found core in bundle Cores/: \(bundlePath)")
                return bundlePath
            }
            
            // 2. Check app bundle root
            let baseName = coreFileName.replacingOccurrences(of: ".dylib", with: "")
            if let bundlePath = Bundle.main.path(forResource: baseName, ofType: "dylib") {
                print("Found core in bundle root: \(bundlePath)")
                return bundlePath
            }
            
            // 3. Check Documents/Cores
            let documentsCorePath = coresURL.appendingPathComponent(coreFileName).path
            if FileManager.default.fileExists(atPath: documentsCorePath) {
                print("Found core in documents: \(documentsCorePath)")
                return documentsCorePath
            }
        }
        
        print("Core not found for system: \(system.rawValue), tried: \(coreFileNames)")
        return nil
    }
}

// MARK: - Supporting Types

struct SaveStateSlot: Identifiable {
    let index: Int
    let exists: Bool
    let date: Date?
    
    var id: Int { index }
    
    var displayName: String {
        if exists, let date = date {
            return "Slot \(index + 1) - \(date.formatted(date: .abbreviated, time: .shortened))"
        } else {
            return "Slot \(index + 1) - Empty"
        }
    }
}

enum EmulationError: LocalizedError {
    case coreNotFound
    case coreNotSupported
    case notRunning
    case gameNotFound
    case gameLoadFailed
    case screenshotFailed
    
    var errorDescription: String? {
        switch self {
        case .coreNotFound:
            return "No emulator core found for this game system. Please ensure the core file is installed."
        case .coreNotSupported:
            return "This game system is temporarily not supported on iOS. PS1 emulation requires a special build."
        case .notRunning:
            return "Emulator is not running"
        case .gameNotFound:
            return "Game file not found. It may have been moved or deleted."
        case .gameLoadFailed:
            return "Failed to load game"
        case .screenshotFailed:
            return "Failed to capture screenshot"
        }
    }
}

// MARK: - Emulation Speed

enum EmulationSpeed: String, CaseIterable, Identifiable {
    case quarter = "0.25x"
    case half = "0.5x"
    case normal = "1x"
    case double = "2x"
    case fast = "4x"
    case turbo = "8x"
    
    var id: String { rawValue }
    
    var multiplier: Double {
        switch self {
        case .quarter: return 0.25
        case .half: return 0.5
        case .normal: return 1.0
        case .double: return 2.0
        case .fast: return 4.0
        case .turbo: return 8.0
        }
    }
    
    var displayName: String {
        switch self {
        case .quarter: return "Quarter Speed"
        case .half: return "Half Speed"
        case .normal: return "Normal"
        case .double: return "2x Speed"
        case .fast: return "4x Speed (Fast)"
        case .turbo: return "8x Speed (Turbo)"
        }
    }
}

// MARK: - Input Mapping

extension GameInput {
    var retroButton: RetroButton {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .a: return .a
        case .b: return .b
        case .x: return .x
        case .y: return .y
        case .start: return .start
        case .select: return .select
        case .l: return .l
        case .r: return .r
        case .l2: return .l2
        case .r2: return .r2
        case .l3: return .l3
        case .r3: return .r3
        }
    }
}
