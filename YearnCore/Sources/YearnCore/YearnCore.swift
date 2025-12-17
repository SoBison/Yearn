//
//  YearnCore.swift
//  YearnCore
//
//  Core framework for Yearn emulator
//

import Foundation

/// YearnCore version information
public struct YearnCore {
    public static let version = "1.0.0"
    public static let name = "YearnCore"
    
    private init() {}
}

// Re-export all public types
@_exported import struct Foundation.URL
@_exported import struct Foundation.Data

