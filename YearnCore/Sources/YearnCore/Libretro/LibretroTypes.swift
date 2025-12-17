//
//  LibretroTypes.swift
//  YearnCore
//
//  Libretro type definitions and constants
//

import Foundation
import CLibretro

// MARK: - Pixel Format

public enum LibretroPixelFormat: UInt32 {
    case rgb1555 = 0  // RETRO_PIXEL_FORMAT_0RGB1555
    case xrgb8888 = 1 // RETRO_PIXEL_FORMAT_XRGB8888
    case rgb565 = 2   // RETRO_PIXEL_FORMAT_RGB565
    
    public var bytesPerPixel: Int {
        switch self {
        case .rgb1555, .rgb565:
            return 2
        case .xrgb8888:
            return 4
        }
    }
    
    public func toVideoPixelFormat() -> PixelFormat {
        switch self {
        case .rgb1555:
            return .rgb565 // Closest match
        case .xrgb8888:
            return .xrgb8888
        case .rgb565:
            return .rgb565
        }
    }
}

// MARK: - Device Types

public enum LibretroDevice: UInt32 {
    case none = 0
    case joypad = 1
    case mouse = 2
    case keyboard = 3
    case lightgun = 4
    case analog = 5
    case pointer = 6
}

// MARK: - Joypad Buttons

public enum LibretroJoypadButton: Int {
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
    
    /// Convert from standard input ID to libretro button
    public static func fromStandardInput(_ input: Int) -> LibretroJoypadButton? {
        return LibretroJoypadButton(rawValue: input)
    }
    
    /// Get bitmask for this button
    public var bitmask: UInt16 {
        return UInt16(1 << rawValue)
    }
}

// MARK: - Memory Types

public enum LibretroMemoryType: UInt32 {
    case saveRAM = 0
    case rtc = 1
    case systemRAM = 2
    case videoRAM = 3
}

// MARK: - Region

public enum LibretroRegion: UInt32 {
    case ntsc = 0
    case pal = 1
    
    public var frameRate: Double {
        switch self {
        case .ntsc:
            return 60.0
        case .pal:
            return 50.0
        }
    }
}

// MARK: - Log Level

public enum LibretroLogLevel: Int32 {
    case debug = 0
    case info = 1
    case warn = 2
    case error = 3
}

// MARK: - Input State Helper

/// Helper class for managing libretro input state
public final class LibretroInputState {
    
    private var buttonState: [UInt32: UInt16] = [:] // [port: bitmask]
    private var analogState: [UInt32: [UInt32: [UInt32: Int16]]] = [:] // [port: [index: [id: value]]]
    
    public init() {}
    
    /// Set button state
    public func setButton(_ button: LibretroJoypadButton, pressed: Bool, port: UInt32 = 0) {
        var state = buttonState[port] ?? 0
        
        if pressed {
            state |= button.bitmask
        } else {
            state &= ~button.bitmask
        }
        
        buttonState[port] = state
    }
    
    /// Set analog state
    public func setAnalog(x: Int16, y: Int16, index: UInt32, port: UInt32 = 0) {
        if analogState[port] == nil {
            analogState[port] = [:]
        }
        if analogState[port]?[index] == nil {
            analogState[port]?[index] = [:]
        }
        
        analogState[port]?[index]?[0] = x // RETRO_DEVICE_ID_ANALOG_X
        analogState[port]?[index]?[1] = y // RETRO_DEVICE_ID_ANALOG_Y
    }
    
    /// Get input state for libretro callback
    public func getState(port: UInt32, device: UInt32, index: UInt32, id: UInt32) -> Int16 {
        switch LibretroDevice(rawValue: device) {
        case .joypad:
            let state = buttonState[port] ?? 0
            return (state & UInt16(1 << id)) != 0 ? 1 : 0
            
        case .analog:
            return analogState[port]?[index]?[id] ?? 0
            
        default:
            return 0
        }
    }
    
    /// Reset all input state
    public func reset() {
        buttonState.removeAll()
        analogState.removeAll()
    }
    
    /// Get button bitmask for a port
    public func getButtonBitmask(port: UInt32 = 0) -> UInt16 {
        return buttonState[port] ?? 0
    }
}

