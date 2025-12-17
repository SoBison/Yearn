//
//  YearnAdapters.swift
//  YearnAdapters
//
//  Platform-specific emulator core adapters
//

import Foundation
import YearnCore

/// YearnAdapters provides platform-specific implementations of CoreAdapter
public struct YearnAdapters {
    public static let version = "1.0.0"
    
    /// All available adapters
    public static var availableAdapters: [any CoreAdapter.Type] {
        return [
            NESAdapter.self,
            SNESAdapter.self,
            GBCAdapter.self,
            GBAAdapter.self,
            N64Adapter.self,
            NDSAdapter.self,
            GenesisAdapter.self,
            PS1Adapter.self
        ]
    }
    
    /// Get adapter for a specific system
    public static func adapter(for system: String) -> (any CoreAdapter)? {
        switch system.lowercased() {
        case "nes":
            return NESAdapter()
        case "snes":
            return SNESAdapter()
        case "gbc", "gb":
            return GBCAdapter()
        case "gba":
            return GBAAdapter()
        case "n64":
            return N64Adapter()
        case "nds", "ds":
            return NDSAdapter()
        case "genesis", "megadrive", "md":
            return GenesisAdapter()
        case "ps1", "psx", "playstation":
            return PS1Adapter()
        default:
            return nil
        }
    }
    
    /// Get adapter for a file extension
    public static func adapter(forExtension ext: String) -> (any CoreAdapter)? {
        let lowercased = ext.lowercased()
        
        for adapterType in availableAdapters {
            let adapter = adapterType.init()
            if adapter.supportedExtensions.contains(lowercased) {
                return adapter
            }
        }
        
        return nil
    }
    
    private init() {}
}

