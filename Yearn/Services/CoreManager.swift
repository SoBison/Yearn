//
//  CoreManager.swift
//  Yearn
//
//  Core manager for auto-detecting and loading libretro cores
//

import Foundation
import Combine
import YearnCore

// MARK: - Core Info

struct CoreInfo: Identifiable, Codable {
    let id: String
    let name: String
    let displayName: String
    let version: String
    let supportedExtensions: [String]
    let systemIdentifier: String
    let corePath: URL
    
    var isValid: Bool {
        FileManager.default.fileExists(atPath: corePath.path)
    }
}

// MARK: - System Type

enum SystemType: String, CaseIterable, Codable {
    case nes = "NES"
    case snes = "SNES"
    case gbc = "GBC"
    case gba = "GBA"
    case n64 = "N64"
    case nds = "NDS"
    case genesis = "Genesis"
    case ps1 = "PS1"
    
    var displayName: String {
        switch self {
        case .nes: return "Nintendo Entertainment System"
        case .snes: return "Super Nintendo"
        case .gbc: return "Game Boy Color"
        case .gba: return "Game Boy Advance"
        case .n64: return "Nintendo 64"
        case .nds: return "Nintendo DS"
        case .genesis: return "Sega Genesis"
        case .ps1: return "PlayStation 1"
        }
    }
    
    var supportedExtensions: [String] {
        switch self {
        case .nes: return ["nes", "fds", "unf", "unif"]
        case .snes: return ["sfc", "smc", "fig", "swc", "bs"]
        case .gbc: return ["gb", "gbc", "sgb"]
        case .gba: return ["gba", "agb"]
        case .n64: return ["n64", "v64", "z64", "u1"]  // 移除 .bin，N64 有专用格式
        case .nds: return ["nds", "dsi"]
        case .genesis: return ["md", "gen", "smd"]  // 移除 .bin，Genesis 有专用格式
        case .ps1: return ["cue", "bin", "img", "mdf", "pbp", "chd"]  // PS1 保留 .bin
        }
    }
    
    var recommendedCore: String {
        switch self {
        case .nes: return "fceumm"
        case .snes: return "bsnes"  // 使用 bsnes (GPL v3) 替代 snes9x (非商业许可证)
        case .gbc: return "gambatte"
        case .gba: return "mgba"
        case .n64: return "mupen64plus_next"
        case .nds: return "melonds"
        case .genesis: return "clownmdemu"  // 使用 ClownMDEmu (AGPL v3)
        case .ps1: return "pcsx_rearmed"
        }
    }
    
    var iconName: String {
        switch self {
        case .nes: return "gamecontroller"
        case .snes: return "gamecontroller.fill"
        case .gbc: return "handheld.game.console"
        case .gba: return "handheld.game.console.fill"
        case .n64: return "n.circle"
        case .nds: return "rectangle.split.2x1"
        case .genesis: return "s.circle"
        case .ps1: return "playstation.logo"
        }
    }
}

// MARK: - Core Manager

@MainActor
class CoreManager: ObservableObject {
    
    static let shared = CoreManager()
    
    // MARK: - Published Properties
    
    @Published var availableCores: [CoreInfo] = []
    @Published var loadedCore: CoreInfo?
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Private Properties
    
    private let fileManager = FileManager.default
    private var coreCache: [String: CoreInfo] = [:]
    
    /// User's Cores directory in Documents (for imported cores)
    private var coresDirectory: URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("Cores")
    }
    
    /// Bundled Cores directory in App Bundle
    private var bundledCoresDirectory: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("Cores")
    }
    
    // MARK: - Initialization
    
    private init() {
        setupCoresDirectory()
    }
    
    // MARK: - Public Methods
    
    /// Scan for available cores
    func scanForCores() async {
        isLoading = true
        defer { isLoading = false }
        
        var foundCores: [CoreInfo] = []
        
        // Scan bundled cores (in App Bundle)
        if let bundledDir = bundledCoresDirectory {
            let bundledCores = await scanDirectory(bundledDir)
            foundCores.append(contentsOf: bundledCores)
        }
        
        // Scan user-imported cores (in Documents/Cores)
        let userCores = await scanDirectory(coresDirectory)
        foundCores.append(contentsOf: userCores)
        
        // Update published property
        availableCores = foundCores
        
        // Update cache
        for core in foundCores {
            coreCache[core.id] = core
        }
        
        print("Found \(foundCores.count) cores")
    }
    
    /// Get core for a specific system
    func getCore(for system: SystemType) -> CoreInfo? {
        return availableCores.first { $0.systemIdentifier == system.rawValue }
    }
    
    /// Get core that supports a specific file extension
    func getCore(forExtension ext: String) -> CoreInfo? {
        let lowercasedExt = ext.lowercased()
        return availableCores.first { $0.supportedExtensions.contains(lowercasedExt) }
    }
    
    /// Get system type for a file extension
    func getSystemType(forExtension ext: String) -> SystemType? {
        let lowercasedExt = ext.lowercased()
        return SystemType.allCases.first { $0.supportedExtensions.contains(lowercasedExt) }
    }
    
    /// Load a core (static or dynamic)
    func loadCore(_ core: CoreInfo) async throws {
        // First check if there's a static core registered
        if let staticCore = StaticCoreRegistry.shared.getCore(identifier: core.name) {
            // Use static core
            loadedCore = core
            print("Loaded static core: \(staticCore.name)")
            return
        }
        
        // Fall back to dynamic loading (development only)
        guard core.isValid else {
            throw CoreManagerError.coreNotFound(core.name)
        }
        
        loadedCore = core
        print("Loaded dynamic core: \(core.name)")
    }
    
    /// Check if using static cores
    var isUsingStaticCores: Bool {
        return StaticCoreRegistry.shared.hasCores
    }
    
    /// Unload current core
    func unloadCore() {
        loadedCore = nil
    }
    
    /// Import a core from URL
    func importCore(from url: URL) async throws {
        let fileName = url.lastPathComponent
        let destinationURL = coresDirectory.appendingPathComponent(fileName)
        
        // Copy to cores directory
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            try fileManager.copyItem(at: url, to: destinationURL)
        } else {
            try fileManager.copyItem(at: url, to: destinationURL)
        }
        
        // Rescan cores
        await scanForCores()
    }
    
    /// Delete a core
    func deleteCore(_ core: CoreInfo) throws {
        guard fileManager.fileExists(atPath: core.corePath.path) else {
            throw CoreManagerError.coreNotFound(core.name)
        }
        
        // Don't allow deleting bundled cores
        if let bundledDir = bundledCoresDirectory,
           core.corePath.path.hasPrefix(bundledDir.path) {
            throw CoreManagerError.cannotDeleteBundledCore
        }
        
        try fileManager.removeItem(at: core.corePath)
        
        // Remove from list
        availableCores.removeAll { $0.id == core.id }
        coreCache.removeValue(forKey: core.id)
    }
    
    // MARK: - Private Methods
    
    private func setupCoresDirectory() {
        if !fileManager.fileExists(atPath: coresDirectory.path) {
            try? fileManager.createDirectory(at: coresDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func scanDirectory(_ directory: URL) async -> [CoreInfo] {
        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }
        
        var cores: [CoreInfo] = []
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
            for file in contents {
                if file.pathExtension == "dylib" {
                    if let coreInfo = parseCoreName(from: file) {
                        cores.append(coreInfo)
                    }
                }
            }
        } catch {
            print("Error scanning directory: \(error)")
        }
        
        return cores
    }
    
    private func parseCoreName(from url: URL) -> CoreInfo? {
        let fileName = url.deletingPathExtension().lastPathComponent.lowercased()
        
        // Try to match known core names (supports both regular and iOS naming)
        let coreMapping: [String: (name: String, system: SystemType)] = [
            "fceumm": ("FCEUmm", .nes),
            "fceumm_libretro_ios": ("FCEUmm", .nes),
            "nestopia": ("Nestopia", .nes),
            "bsnes": ("bsnes", .snes),
            "bsnes_libretro_ios": ("bsnes", .snes),
            "gambatte": ("Gambatte", .gbc),
            "gambatte_libretro_ios": ("Gambatte", .gbc),
            "mgba": ("mGBA", .gba),
            "mgba_libretro_ios": ("mGBA", .gba),
            "vba_next": ("VBA-M", .gba),
            "mupen64plus_next": ("Mupen64Plus", .n64),
            "mupen64plus_next_libretro_ios": ("Mupen64Plus", .n64),
            "parallel_n64": ("ParaLLEl N64", .n64),
            "melonds": ("melonDS", .nds),
            "melonds_libretro_ios": ("melonDS", .nds),
            "desmume": ("DeSmuME", .nds),
            "clownmdemu": ("ClownMDEmu", .genesis),
            "clownmdemu_libretro_ios": ("ClownMDEmu", .genesis),
            "pcsx_rearmed": ("PCSX ReARMed", .ps1),
            "pcsx_rearmed_libretro_ios": ("PCSX ReARMed", .ps1),
            "mednafen_psx": ("Mednafen PSX", .ps1)
        ]
        
        // Direct match first
        if let value = coreMapping[fileName] {
            return CoreInfo(
                id: UUID().uuidString,
                name: fileName,
                displayName: value.name,
                version: "1.0",
                supportedExtensions: value.system.supportedExtensions,
                systemIdentifier: value.system.rawValue,
                corePath: url
            )
        }
        
        // Partial match
        for (key, value) in coreMapping {
            if fileName.contains(key) {
                return CoreInfo(
                    id: UUID().uuidString,
                    name: key,
                    displayName: value.name,
                    version: "1.0",
                    supportedExtensions: value.system.supportedExtensions,
                    systemIdentifier: value.system.rawValue,
                    corePath: url
                )
            }
        }
        
        // Unknown core
        return CoreInfo(
            id: UUID().uuidString,
            name: fileName,
            displayName: fileName,
            version: "Unknown",
            supportedExtensions: [],
            systemIdentifier: "Unknown",
            corePath: url
        )
    }
}

// MARK: - Core Manager Error

enum CoreManagerError: LocalizedError {
    case coreNotFound(String)
    case cannotDeleteBundledCore
    case loadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .coreNotFound(let name):
            return "Core '\(name)' not found."
        case .cannotDeleteBundledCore:
            return "Cannot delete bundled cores."
        case .loadFailed(let reason):
            return "Failed to load core: \(reason)"
        }
    }
}

// MARK: - Core List View

import SwiftUI

struct CoreListView: View {
    @ObservedObject var coreManager = CoreManager.shared
    @State private var showingImporter = false
    
    var body: some View {
        List {
            if coreManager.isLoading {
                HStack {
                    ProgressView()
                    Text("Scanning for cores...")
                        .foregroundStyle(.secondary)
                }
            } else if coreManager.availableCores.isEmpty {
                ContentUnavailableView(
                    "No Cores Found",
                    systemImage: "cpu",
                    description: Text("Import libretro cores to start playing games.")
                )
            } else {
                ForEach(SystemType.allCases, id: \.self) { system in
                    let systemCores = coreManager.availableCores.filter { 
                        $0.systemIdentifier == system.rawValue 
                    }
                    
                    if !systemCores.isEmpty {
                        Section(system.displayName) {
                            ForEach(systemCores) { core in
                                CoreRow(core: core)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Emulator Cores")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingImporter = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Button {
                    Task {
                        await coreManager.scanForCores()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.init(filenameExtension: "dylib")!],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        try? await coreManager.importCore(from: url)
                    }
                }
            case .failure(let error):
                print("Import error: \(error)")
            }
        }
        .task {
            await coreManager.scanForCores()
        }
    }
}

struct CoreRow: View {
    let core: CoreInfo
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(core.displayName)
                    .font(.headline)
                Text("v\(core.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if core.isValid {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

