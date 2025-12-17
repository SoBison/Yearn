//
//  RewindManager.swift
//  YearnCore
//
//  Manages rewind functionality for emulation
//

import Foundation

// MARK: - Rewind Manager

/// Manages save state history for rewind functionality
public class RewindManager {
    
    // MARK: - Configuration
    
    public struct Configuration {
        /// Maximum number of states to keep in history
        public var maxStates: Int
        /// Interval between state captures (in frames)
        public var captureInterval: Int
        /// Maximum memory usage in bytes (0 = unlimited)
        public var maxMemoryUsage: Int
        
        public init(maxStates: Int = 300, captureInterval: Int = 2, maxMemoryUsage: Int = 100 * 1024 * 1024) {
            self.maxStates = maxStates
            self.captureInterval = captureInterval
            self.maxMemoryUsage = maxMemoryUsage
        }
        
        /// Preset for low memory devices
        public static let lowMemory = Configuration(maxStates: 60, captureInterval: 4, maxMemoryUsage: 30 * 1024 * 1024)
        
        /// Preset for high performance
        public static let highPerformance = Configuration(maxStates: 600, captureInterval: 1, maxMemoryUsage: 200 * 1024 * 1024)
    }
    
    // MARK: - Properties
    
    public var configuration: Configuration
    public var isEnabled: Bool = true
    
    /// Current rewind progress (0.0 to 1.0)
    public var progress: Float {
        guard !stateHistory.isEmpty else { return 0 }
        return Float(currentIndex) / Float(stateHistory.count - 1)
    }
    
    /// Duration of available rewind in seconds (at 60fps)
    public var availableDuration: TimeInterval {
        let frames = stateHistory.count * configuration.captureInterval
        return TimeInterval(frames) / 60.0
    }
    
    /// Whether rewind is currently active
    public private(set) var isRewinding: Bool = false
    
    // MARK: - Private Properties
    
    private var stateHistory: [Data] = []
    private var currentIndex: Int = 0
    private var frameCounter: Int = 0
    private var totalMemoryUsage: Int = 0
    
    // Compression
    private var useCompression: Bool = true
    
    // MARK: - Initialization
    
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    /// Capture current state for rewind history
    public func captureState(_ stateData: Data) {
        guard isEnabled && !isRewinding else { return }
        
        frameCounter += 1
        
        // Only capture at specified interval
        guard frameCounter >= configuration.captureInterval else { return }
        frameCounter = 0
        
        // Compress if enabled
        let dataToStore: Data
        if useCompression {
            dataToStore = compress(stateData) ?? stateData
        } else {
            dataToStore = stateData
        }
        
        // Add to history
        stateHistory.append(dataToStore)
        totalMemoryUsage += dataToStore.count
        currentIndex = stateHistory.count - 1
        
        // Trim if needed
        trimHistory()
    }
    
    /// Start rewinding
    public func startRewind() {
        guard !stateHistory.isEmpty else { return }
        isRewinding = true
    }
    
    /// Stop rewinding and resume normal play
    public func stopRewind() {
        isRewinding = false
        
        // Remove states after current position (we've "branched" the timeline)
        if currentIndex < stateHistory.count - 1 {
            let removedStates = stateHistory.suffix(from: currentIndex + 1)
            totalMemoryUsage -= removedStates.reduce(0) { $0 + $1.count }
            stateHistory.removeLast(stateHistory.count - currentIndex - 1)
        }
    }
    
    /// Step back one state during rewind
    public func stepBack() -> Data? {
        guard isRewinding && currentIndex > 0 else { return nil }
        currentIndex -= 1
        return getState(at: currentIndex)
    }
    
    /// Step forward one state during rewind
    public func stepForward() -> Data? {
        guard isRewinding && currentIndex < stateHistory.count - 1 else { return nil }
        currentIndex += 1
        return getState(at: currentIndex)
    }
    
    /// Get state at specific position (0.0 to 1.0)
    public func getState(atProgress progress: Float) -> Data? {
        guard !stateHistory.isEmpty else { return nil }
        let index = Int(Float(stateHistory.count - 1) * max(0, min(1, progress)))
        currentIndex = index
        return getState(at: index)
    }
    
    /// Get current state
    public func getCurrentState() -> Data? {
        return getState(at: currentIndex)
    }
    
    /// Clear all history
    public func clear() {
        stateHistory.removeAll()
        currentIndex = 0
        frameCounter = 0
        totalMemoryUsage = 0
        isRewinding = false
    }
    
    /// Get memory usage info
    public var memoryInfo: MemoryInfo {
        MemoryInfo(
            usedBytes: totalMemoryUsage,
            maxBytes: configuration.maxMemoryUsage,
            stateCount: stateHistory.count,
            maxStates: configuration.maxStates
        )
    }
    
    // MARK: - Private Methods
    
    private func getState(at index: Int) -> Data? {
        guard index >= 0 && index < stateHistory.count else { return nil }
        
        let storedData = stateHistory[index]
        
        if useCompression {
            return decompress(storedData) ?? storedData
        }
        
        return storedData
    }
    
    private func trimHistory() {
        // Trim by count
        while stateHistory.count > configuration.maxStates {
            if let removed = stateHistory.first {
                totalMemoryUsage -= removed.count
            }
            stateHistory.removeFirst()
            currentIndex = max(0, currentIndex - 1)
        }
        
        // Trim by memory
        if configuration.maxMemoryUsage > 0 {
            while totalMemoryUsage > configuration.maxMemoryUsage && !stateHistory.isEmpty {
                if let removed = stateHistory.first {
                    totalMemoryUsage -= removed.count
                }
                stateHistory.removeFirst()
                currentIndex = max(0, currentIndex - 1)
            }
        }
    }
    
    // MARK: - Compression
    
    private func compress(_ data: Data) -> Data? {
        // Use simple run-length encoding for save states
        // (Save states often have many repeated bytes)
        guard data.count > 64 else { return data }
        
        var compressed = Data()
        compressed.reserveCapacity(data.count)
        
        var i = 0
        while i < data.count {
            let byte = data[i]
            var count = 1
            
            // Count consecutive same bytes (max 255)
            while i + count < data.count && data[i + count] == byte && count < 255 {
                count += 1
            }
            
            if count >= 4 {
                // Use RLE: marker (0xFF), byte, count
                compressed.append(0xFF)
                compressed.append(byte)
                compressed.append(UInt8(count))
                i += count
            } else {
                // Store literally, escape 0xFF
                if byte == 0xFF {
                    compressed.append(0xFF)
                    compressed.append(0xFF)
                    compressed.append(1)
                } else {
                    compressed.append(byte)
                }
                i += 1
            }
        }
        
        // Only use compressed if smaller
        return compressed.count < data.count ? compressed : data
    }
    
    private func decompress(_ data: Data) -> Data? {
        var decompressed = Data()
        
        var i = 0
        while i < data.count {
            let byte = data[i]
            
            if byte == 0xFF && i + 2 < data.count {
                let value = data[i + 1]
                let count = Int(data[i + 2])
                decompressed.append(contentsOf: [UInt8](repeating: value, count: count))
                i += 3
            } else {
                decompressed.append(byte)
                i += 1
            }
        }
        
        return decompressed
    }
}

// MARK: - Memory Info

public struct MemoryInfo {
    public let usedBytes: Int
    public let maxBytes: Int
    public let stateCount: Int
    public let maxStates: Int
    
    public var usedMB: Double {
        Double(usedBytes) / (1024 * 1024)
    }
    
    public var maxMB: Double {
        Double(maxBytes) / (1024 * 1024)
    }
    
    public var usagePercent: Double {
        guard maxBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(maxBytes) * 100
    }
}

