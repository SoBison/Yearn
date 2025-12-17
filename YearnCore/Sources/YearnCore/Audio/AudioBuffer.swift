//
//  AudioBuffer.swift
//  YearnCore
//
//  Thread-safe ring buffer for audio samples
//

import Foundation
import AVFoundation

/// Thread-safe ring buffer for audio samples
public final class AudioRingBuffer {
    
    private var buffer: [Int16]
    private var readIndex: Int = 0
    private var writeIndex: Int = 0
    private let capacity: Int
    private let lock = NSLock()
    
    public init(capacity: Int) {
        self.capacity = capacity
        self.buffer = [Int16](repeating: 0, count: capacity)
    }
    
    /// Number of samples available for reading
    public var availableSamples: Int {
        lock.lock()
        defer { lock.unlock() }
        
        if writeIndex >= readIndex {
            return writeIndex - readIndex
        } else {
            return capacity - readIndex + writeIndex
        }
    }
    
    /// Number of samples that can be written
    public var availableSpace: Int {
        return capacity - availableSamples - 1
    }
    
    /// Write samples to the buffer
    public func write(_ samples: UnsafePointer<Int16>, count: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        let toWrite = min(count, availableSpace)
        
        for i in 0..<toWrite {
            buffer[writeIndex] = samples[i]
            writeIndex = (writeIndex + 1) % capacity
        }
    }
    
    /// Read samples into an AVAudioPCMBuffer
    public func read(into pcmBuffer: AVAudioPCMBuffer) -> Int {
        lock.lock()
        defer { lock.unlock() }
        
        let available = availableSamples
        let toRead = min(Int(pcmBuffer.frameCapacity), available)
        
        guard toRead > 0,
              let channelData = pcmBuffer.int16ChannelData else {
            return 0
        }
        
        let channels = Int(pcmBuffer.format.channelCount)
        
        for i in 0..<toRead {
            for channel in 0..<channels {
                let sampleIndex = (readIndex + i * channels + channel) % capacity
                channelData[channel][i] = buffer[sampleIndex]
            }
        }
        
        readIndex = (readIndex + toRead * channels) % capacity
        
        return toRead
    }
    
    /// Read samples into a raw buffer
    public func read(_ destination: UnsafeMutablePointer<Int16>, count: Int) -> Int {
        lock.lock()
        defer { lock.unlock() }
        
        let toRead = min(count, availableSamples)
        
        for i in 0..<toRead {
            destination[i] = buffer[readIndex]
            readIndex = (readIndex + 1) % capacity
        }
        
        return toRead
    }
    
    /// Clear the buffer
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        readIndex = 0
        writeIndex = 0
    }
}

