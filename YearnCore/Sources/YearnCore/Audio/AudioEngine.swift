//
//  AudioEngine.swift
//  YearnCore
//
//  Audio output management using AVAudioEngine
//

import Foundation
import AVFoundation

/// Manages audio output for emulation
public final class AudioEngine {
    
    // MARK: - Properties
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFormat: AVAudioFormat?
    private var audioBuffer: AudioRingBuffer?
    
    private var isConfigured = false
    private var isRunning = false
    
    // MARK: - Public Properties
    
    public var volume: Float = 1.0 {
        didSet {
            playerNode?.volume = volume
        }
    }
    
    public var isMuted: Bool = false {
        didSet {
            playerNode?.volume = isMuted ? 0 : volume
        }
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Configuration
    
    /// Configure the audio engine with the specified format
    public func configure(format: AudioFormat) {
        // Create AVAudioFormat from our AudioFormat
        guard let avFormat = AVAudioFormat(
            commonFormat: format.commonFormat,
            sampleRate: format.sampleRate,
            channels: AVAudioChannelCount(format.channels),
            interleaved: format.interleaved
        ) else {
            print("Failed to create AVAudioFormat")
            return
        }
        
        self.audioFormat = avFormat
        self.audioBuffer = AudioRingBuffer(capacity: Int(format.sampleRate) * format.channels)
        
        setupAudioEngine()
        isConfigured = true
    }
    
    // MARK: - Lifecycle
    
    /// Start audio playback
    public func start() {
        guard isConfigured, !isRunning else { return }
        
        do {
            try audioEngine?.start()
            playerNode?.play()
            isRunning = true
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    /// Pause audio playback
    public func pause() {
        playerNode?.pause()
        isRunning = false
    }
    
    /// Resume audio playback
    public func resume() {
        playerNode?.play()
        isRunning = true
    }
    
    /// Stop audio playback
    public func stop() {
        playerNode?.stop()
        audioEngine?.stop()
        isRunning = false
    }
    
    // MARK: - Audio Data
    
    /// Write audio samples to the buffer
    public func writeSamples(_ samples: UnsafePointer<Int16>, count: Int) {
        audioBuffer?.write(samples, count: count)
    }
    
    /// Write audio samples from Data
    public func writeSamples(_ data: Data) {
        data.withUnsafeBytes { buffer in
            if let pointer = buffer.baseAddress?.assumingMemoryBound(to: Int16.self) {
                audioBuffer?.write(pointer, count: buffer.count / MemoryLayout<Int16>.size)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine,
              let player = playerNode,
              let format = audioFormat else {
            return
        }
        
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        
        // Setup audio session (iOS only)
        #if canImport(UIKit)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
        #endif
        
        // Schedule buffer callback
        scheduleNextBuffer()
    }
    
    private func scheduleNextBuffer() {
        guard let player = playerNode,
              let format = audioFormat,
              let ringBuffer = audioBuffer else {
            return
        }
        
        let bufferSize: AVAudioFrameCount = 2048
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize) else {
            return
        }
        
        // Read from ring buffer
        let framesRead = ringBuffer.read(into: buffer)
        buffer.frameLength = AVAudioFrameCount(framesRead)
        
        if framesRead > 0 {
            player.scheduleBuffer(buffer) { [weak self] in
                self?.scheduleNextBuffer()
            }
        } else {
            // No data available, try again shortly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                self?.scheduleNextBuffer()
            }
        }
    }
}

// MARK: - Audio Format

/// Audio format specification
public struct AudioFormat: Sendable {
    public let sampleRate: Double
    public let channels: Int
    public let bitsPerSample: Int
    public let interleaved: Bool
    
    public init(sampleRate: Double, channels: Int, bitsPerSample: Int = 16, interleaved: Bool = true) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitsPerSample = bitsPerSample
        self.interleaved = interleaved
    }
    
    var commonFormat: AVAudioCommonFormat {
        switch bitsPerSample {
        case 16:
            return .pcmFormatInt16
        case 32:
            return .pcmFormatInt32
        default:
            return .pcmFormatFloat32
        }
    }
    
    /// Common audio formats for different systems
    public static let nes = AudioFormat(sampleRate: 44100, channels: 1)
    public static let snes = AudioFormat(sampleRate: 32000, channels: 2)
    public static let gba = AudioFormat(sampleRate: 32768, channels: 2)
    public static let n64 = AudioFormat(sampleRate: 44100, channels: 2)
    public static let ps1 = AudioFormat(sampleRate: 44100, channels: 2)
}

