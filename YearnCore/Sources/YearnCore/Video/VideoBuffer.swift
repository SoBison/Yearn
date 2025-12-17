//
//  VideoBuffer.swift
//  YearnCore
//
//  Video frame buffer
//

import Foundation
import Metal

/// Video frame buffer for storing pixel data
public final class VideoBuffer {
    
    // MARK: - Properties
    
    public let width: Int
    public let height: Int
    public let pixelFormat: PixelFormat
    public let bytesPerRow: Int
    
    private var buffer: UnsafeMutableRawPointer
    private let bufferSize: Int
    
    // MARK: - Initialization
    
    public init(width: Int, height: Int, pixelFormat: PixelFormat) {
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.bytesPerRow = width * pixelFormat.bytesPerPixel
        self.bufferSize = bytesPerRow * height
        self.buffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: 16)
        
        // Clear buffer
        memset(buffer, 0, bufferSize)
    }
    
    deinit {
        buffer.deallocate()
    }
    
    // MARK: - Access
    
    /// Get raw pointer to buffer
    public var pointer: UnsafeMutableRawPointer {
        return buffer
    }
    
    /// Access buffer with closure
    public func withUnsafeBytes<T>(_ body: (UnsafeRawPointer) -> T) -> T {
        return body(UnsafeRawPointer(buffer))
    }
    
    /// Access mutable buffer with closure
    public func withUnsafeMutableBytes<T>(_ body: (UnsafeMutableRawPointer) -> T) -> T {
        return body(buffer)
    }
    
    /// Copy data into buffer
    public func copyFrom(_ source: UnsafeRawPointer, bytesPerRow srcBytesPerRow: Int) {
        if srcBytesPerRow == bytesPerRow {
            memcpy(buffer, source, bufferSize)
        } else {
            // Row-by-row copy for different strides
            for y in 0..<height {
                let srcRow = source.advanced(by: y * srcBytesPerRow)
                let dstRow = buffer.advanced(by: y * bytesPerRow)
                memcpy(dstRow, srcRow, min(bytesPerRow, srcBytesPerRow))
            }
        }
    }
    
    /// Clear the buffer
    public func clear() {
        memset(buffer, 0, bufferSize)
    }
}

// MARK: - Pixel Format

public enum PixelFormat: Sendable {
    case rgb565
    case rgba8888
    case bgra8888
    case xrgb8888
    
    public var bytesPerPixel: Int {
        switch self {
        case .rgb565:
            return 2
        case .rgba8888, .bgra8888, .xrgb8888:
            return 4
        }
    }
    
    public var metalPixelFormat: MTLPixelFormat {
        switch self {
        case .rgb565:
            return .b5g6r5Unorm
        case .rgba8888:
            return .rgba8Unorm
        case .bgra8888:
            return .bgra8Unorm
        case .xrgb8888:
            return .bgra8Unorm
        }
    }
}

// MARK: - Video Format

/// Video format specification
public struct VideoFormat: Sendable {
    public let width: Int
    public let height: Int
    public let pixelFormat: PixelFormat
    public let frameRate: Double
    
    public init(width: Int, height: Int, pixelFormat: PixelFormat = .rgba8888, frameRate: Double = 60.0) {
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.frameRate = frameRate
    }
    
    public var aspectRatio: Double {
        return Double(width) / Double(height)
    }
    
    var metalPixelFormat: MTLPixelFormat {
        return pixelFormat.metalPixelFormat
    }
    
    // Common video formats for different systems
    public static let nes = VideoFormat(width: 256, height: 240, pixelFormat: .rgb565, frameRate: 60.0988)
    public static let snes = VideoFormat(width: 256, height: 224, pixelFormat: .rgb565, frameRate: 60.0988)
    public static let gbc = VideoFormat(width: 160, height: 144, pixelFormat: .rgb565, frameRate: 59.7275)
    public static let gba = VideoFormat(width: 240, height: 160, pixelFormat: .rgb565, frameRate: 59.7275)
    public static let n64 = VideoFormat(width: 320, height: 240, pixelFormat: .rgba8888, frameRate: 60.0)
    public static let nds = VideoFormat(width: 256, height: 384, pixelFormat: .rgba8888, frameRate: 59.8261)
    public static let genesis = VideoFormat(width: 320, height: 224, pixelFormat: .rgb565, frameRate: 59.9275)
    public static let ps1 = VideoFormat(width: 320, height: 240, pixelFormat: .rgba8888, frameRate: 60.0)
}

