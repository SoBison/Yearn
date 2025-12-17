//
//  Game.swift
//  Yearn
//
//  Game model representing a ROM file
//

import Foundation
import SwiftUI

/// Represents a game ROM file
struct Game: Identifiable, Hashable {
    let id: UUID
    let name: String
    let fileURL: URL
    let system: GameSystem
    let artworkURL: URL?
    var dateAdded: Date?
    var lastPlayed: Date?
    var isFavorite: Bool
    var fileSizeBytes: Int?
    
    init(
        id: UUID = UUID(),
        name: String,
        fileURL: URL,
        system: GameSystem,
        artworkURL: URL? = nil,
        dateAdded: Date? = Date(),
        lastPlayed: Date? = nil,
        isFavorite: Bool = false,
        fileSizeBytes: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.fileURL = fileURL
        self.system = system
        self.artworkURL = artworkURL
        self.dateAdded = dateAdded
        self.lastPlayed = lastPlayed
        self.isFavorite = isFavorite
        self.fileSizeBytes = fileSizeBytes
    }
    
    /// Formatted file size string
    var fileSize: String? {
        guard let bytes = fileSizeBytes else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
    
    /// File extension
    var fileExtension: String {
        fileURL.pathExtension.lowercased()
    }
}

/// Supported game systems
enum GameSystem: String, CaseIterable, Identifiable, Codable {
    case nes = "NES"
    case snes = "SNES"
    case gbc = "GBC"
    case gba = "GBA"
    case n64 = "N64"
    case nds = "NDS"
    case genesis = "Genesis"
    case ps1 = "PS1"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .nes: return "Nintendo Entertainment System"
        case .snes: return "Super Nintendo"
        case .gbc: return "Game Boy / Game Boy Color"
        case .gba: return "Game Boy Advance"
        case .n64: return "Nintendo 64"
        case .nds: return "Nintendo DS"
        case .genesis: return "Sega Genesis / Mega Drive"
        case .ps1: return "PlayStation"
        }
    }
    
    var shortName: String {
        switch self {
        case .nes: return "NES"
        case .snes: return "SNES"
        case .gbc: return "GB/GBC"
        case .gba: return "GBA"
        case .n64: return "N64"
        case .nds: return "NDS"
        case .genesis: return "Genesis"
        case .ps1: return "PS1"
        }
    }
    
    var supportedExtensions: [String] {
        switch self {
        case .nes: return ["nes", "fds", "unf", "unif"]
        case .snes: return ["sfc", "smc", "fig", "swc", "bs"]
        case .gbc: return ["gb", "gbc", "sgb"]
        case .gba: return ["gba", "agb"]
        case .n64: return ["n64", "z64", "v64", "u1"]  // 移除 .bin，N64 有专用格式
        case .nds: return ["nds", "dsi"]
        case .genesis: return ["md", "gen", "smd"]  // 移除 .bin，Genesis 有专用格式
        case .ps1: return ["bin", "cue", "iso", "pbp", "chd", "img", "mdf"]  // PS1 保留 .bin
        }
    }
    
    var iconName: String {
        switch self {
        case .nes: return "tv"
        case .snes: return "tv.fill"
        case .gbc: return "rectangle.portrait"
        case .gba: return "rectangle"
        case .n64: return "cube"
        case .nds: return "rectangle.split.1x2"
        case .genesis: return "tv.circle"
        case .ps1: return "opticaldisc"
        }
    }
    
    var color: Color {
        switch self {
        case .nes: return .red
        case .snes: return .purple
        case .gbc: return .green
        case .gba: return .indigo
        case .n64: return .orange
        case .nds: return .blue
        case .genesis: return .cyan
        case .ps1: return .gray
        }
    }
    
    var manufacturer: String {
        switch self {
        case .nes, .snes, .gbc, .gba, .n64, .nds:
            return "Nintendo"
        case .genesis:
            return "Sega"
        case .ps1:
            return "Sony"
        }
    }
    
    var releaseYear: Int {
        switch self {
        case .nes: return 1983
        case .snes: return 1990
        case .gbc: return 1998
        case .gba: return 2001
        case .n64: return 1996
        case .nds: return 2004
        case .genesis: return 1988
        case .ps1: return 1994
        }
    }
    
    /// Recommended libretro core name
    var recommendedCore: String {
        switch self {
        case .nes: return "fceumm"
        case .snes: return "snes9x"
        case .gbc: return "gambatte"
        case .gba: return "mgba"
        case .n64: return "mupen64plus_next"
        case .nds: return "melonds"
        case .genesis: return "genesis_plus_gx"
        case .ps1: return "pcsx_rearmed"
        }
    }
    
    /// Native screen resolution
    var nativeResolution: CGSize {
        switch self {
        case .nes: return CGSize(width: 256, height: 240)
        case .snes: return CGSize(width: 256, height: 224)
        case .gbc: return CGSize(width: 160, height: 144)
        case .gba: return CGSize(width: 240, height: 160)
        case .n64: return CGSize(width: 320, height: 240)
        case .nds: return CGSize(width: 256, height: 384) // Dual screens stacked
        case .genesis: return CGSize(width: 320, height: 224)
        case .ps1: return CGSize(width: 320, height: 240)
        }
    }
    
    /// Native aspect ratio
    var aspectRatio: CGFloat {
        let res = nativeResolution
        return res.width / res.height
    }
    
    /// Get the system for a given file extension
    static func system(forExtension ext: String) -> GameSystem? {
        let lowercased = ext.lowercased()
        return GameSystem.allCases.first { system in
            system.supportedExtensions.contains(lowercased)
        }
    }
    
    /// Get the system for a file by analyzing its content (for ambiguous extensions like .bin)
    /// - Parameter url: The file URL to analyze
    /// - Returns: The detected GameSystem, or nil if unknown
    static func system(forFileAt url: URL) -> GameSystem? {
        let ext = url.pathExtension.lowercased()
        
        // 对于非歧义的扩展名，直接返回
        if ext != "bin" && ext != "iso" {
            return system(forExtension: ext)
        }
        
        // 对于 .bin 文件，需要分析文件头来确定平台
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            // 如果无法读取文件，默认返回 PS1（最常见的 .bin 用途）
            return .ps1
        }
        
        defer { try? fileHandle.close() }
        
        // 读取文件头（前 16 字节）
        guard let headerData = try? fileHandle.read(upToCount: 16),
              headerData.count >= 4 else {
            return .ps1
        }
        
        let header = [UInt8](headerData)
        
        // N64 ROM 检测
        // - Big-endian (.z64): 0x80 0x37 0x12 0x40
        // - Little-endian (.n64): 0x40 0x12 0x37 0x80
        // - Byte-swapped (.v64): 0x37 0x80 0x40 0x12
        if header.count >= 4 {
            // Z64 格式 (Big-endian)
            if header[0] == 0x80 && header[1] == 0x37 && header[2] == 0x12 && header[3] == 0x40 {
                print("🔍 Detected N64 ROM (Z64 format)")
                return .n64
            }
            // N64 格式 (Little-endian)
            if header[0] == 0x40 && header[1] == 0x12 && header[2] == 0x37 && header[3] == 0x80 {
                print("🔍 Detected N64 ROM (N64 format)")
                return .n64
            }
            // V64 格式 (Byte-swapped)
            if header[0] == 0x37 && header[1] == 0x80 && header[2] == 0x40 && header[3] == 0x12 {
                print("🔍 Detected N64 ROM (V64 format)")
                return .n64
            }
        }
        
        // Genesis/Mega Drive ROM 检测
        // 通常在偏移 0x100 处有 "SEGA" 字符串，但 .bin 文件可能没有标准头
        // 检查文件大小：Genesis ROM 通常 < 16MB
        if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 {
            // Genesis ROM 通常在 256KB - 8MB 之间
            if fileSize >= 256 * 1024 && fileSize <= 8 * 1024 * 1024 {
                // 尝试读取偏移 0x100 处的 SEGA 标识
                try? fileHandle.seek(toOffset: 0x100)
                if let segaData = try? fileHandle.read(upToCount: 16) {
                    let segaString = String(data: segaData, encoding: .ascii) ?? ""
                    if segaString.contains("SEGA") {
                        print("🔍 Detected Genesis/Mega Drive ROM")
                        return .genesis
                    }
                }
            }
        }
        
        // PS1 CD-ROM 检测
        // PS1 .bin 文件通常是光盘镜像，大小 > 100MB
        // 检查是否有配套的 .cue 文件
        let baseName = url.deletingPathExtension().lastPathComponent
        let directory = url.deletingLastPathComponent()
        let cueURL = directory.appendingPathComponent(baseName).appendingPathExtension("cue")
        
        if FileManager.default.fileExists(atPath: cueURL.path) {
            print("🔍 Detected PS1 CD-ROM (found .cue file)")
            return .ps1
        }
        
        // 检查文件大小：PS1 光盘镜像通常 > 100MB
        if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 {
            if fileSize > 100 * 1024 * 1024 {
                print("🔍 Detected PS1 CD-ROM (large file size: \(fileSize / 1024 / 1024) MB)")
                return .ps1
            }
        }
        
        // 默认返回 PS1（最常见的 .bin 用途）
        print("🔍 Defaulting to PS1 for .bin file")
        return .ps1
    }
    
    /// All supported file extensions across all systems
    static var allSupportedExtensions: [String] {
        GameSystem.allCases.flatMap { $0.supportedExtensions }
    }
}
