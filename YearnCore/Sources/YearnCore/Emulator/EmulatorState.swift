//
//  EmulatorState.swift
//  YearnCore
//
//  Emulator state definitions
//

import Foundation

/// Represents the current state of the emulator
public enum EmulatorState: Equatable, Sendable {
    /// Emulator is stopped, no game loaded
    case stopped
    
    /// Game is loaded but not running
    case loaded
    
    /// Emulation is actively running
    case running
    
    /// Emulation is paused
    case paused
    
    /// Emulator encountered an error
    case error(String)
    
    public var isActive: Bool {
        switch self {
        case .running, .paused:
            return true
        default:
            return false
        }
    }
    
    public var canStart: Bool {
        switch self {
        case .loaded, .paused:
            return true
        default:
            return false
        }
    }
    
    public var canPause: Bool {
        self == .running
    }
    
    public var canStop: Bool {
        isActive || self == .loaded
    }
}

