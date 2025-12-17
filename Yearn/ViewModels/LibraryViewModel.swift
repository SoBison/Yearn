//
//  LibraryViewModel.swift
//  Yearn
//
//  View model for the game library
//

import Foundation
import SwiftUI

@MainActor
class LibraryViewModel: ObservableObject {
    @Published var games: [Game] = []
    @Published var recentGames: [Game] = []
    @Published var favoriteGames: [Game] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var importProgress: ImportProgress?
    
    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private let recentGamesKey = "recentGameIDs"
    private let favoriteGamesKey = "favoriteGameIDs"
    private let lastPlayedKey = "lastPlayedDates"
    
    struct ImportProgress {
        var current: Int
        var total: Int
        var currentFile: String
        
        var percentage: Double {
            guard total > 0 else { return 0 }
            return Double(current) / Double(total)
        }
    }
    
    init() {
        loadGames()
        loadRecentGames()
        loadFavorites()
    }
    
    // MARK: - Recent Games
    
    /// Record that a game was played
    func recordGamePlayed(_ game: Game) {
        // Update last played date
        var lastPlayedDates = userDefaults.dictionary(forKey: lastPlayedKey) as? [String: Date] ?? [:]
        lastPlayedDates[game.id.uuidString] = Date()
        userDefaults.set(lastPlayedDates, forKey: lastPlayedKey)
        
        // Update recent games list
        var recentIDs = userDefaults.stringArray(forKey: recentGamesKey) ?? []
        recentIDs.removeAll { $0 == game.id.uuidString }
        recentIDs.insert(game.id.uuidString, at: 0)
        recentIDs = Array(recentIDs.prefix(20)) // Keep last 20
        userDefaults.set(recentIDs, forKey: recentGamesKey)
        
        loadRecentGames()
    }
    
    /// Load recent games from UserDefaults
    private func loadRecentGames() {
        let recentIDs = userDefaults.stringArray(forKey: recentGamesKey) ?? []
        let lastPlayedDates = userDefaults.dictionary(forKey: lastPlayedKey) as? [String: Date] ?? [:]
        
        recentGames = recentIDs.compactMap { idString in
            guard let uuid = UUID(uuidString: idString),
                  var game = games.first(where: { $0.id == uuid }) else {
                return nil
            }
            game.lastPlayed = lastPlayedDates[idString]
            return game
        }
    }
    
    /// Clear recent games history
    func clearRecentGames() {
        userDefaults.removeObject(forKey: recentGamesKey)
        userDefaults.removeObject(forKey: lastPlayedKey)
        recentGames = []
    }
    
    // MARK: - Loading Games
    
    /// Load games from the documents directory
    func loadGames() {
        isLoading = true
        defer { isLoading = false }
        
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("🔍 Could not get documents directory")
            return
        }
        
        let romsURL = documentsURL.appendingPathComponent("ROMs", isDirectory: true)
        print("🔍 Scanning ROMs directory: \(romsURL.path)")
        
        // Create ROMs directory if it doesn't exist
        if !fileManager.fileExists(atPath: romsURL.path) {
            try? fileManager.createDirectory(at: romsURL, withIntermediateDirectories: true)
            print("🔍 Created ROMs directory")
        }
        
        // List directory contents for debugging
        if let contents = try? fileManager.contentsOfDirectory(at: romsURL, includingPropertiesForKeys: nil) {
            print("🔍 ROMs directory contents: \(contents.map { $0.lastPathComponent })")
        }
        
        // Scan for ROM files
        guard let enumerator = fileManager.enumerator(
            at: romsURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            print("🔍 Could not create enumerator")
            return
        }
        
        var foundGames: [Game] = []
        var allFiles: [URL] = []
        
        // 首先收集所有文件
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true else {
                continue
            }
            allFiles.append(fileURL)
        }
        
        // 构建已存在的 .cue 文件集合（用于跳过对应的 .bin 文件）
        let cueFiles = Set(allFiles.filter { $0.pathExtension.lowercased() == "cue" }
            .map { $0.deletingPathExtension().lastPathComponent.lowercased() })
        
        // 构建已存在的 .img 文件集合（用于跳过对应的 .ccd/.sub 文件）
        let imgFiles = Set(allFiles.filter { $0.pathExtension.lowercased() == "img" }
            .map { $0.deletingPathExtension().lastPathComponent.lowercased() })
        
        for fileURL in allFiles {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey]) else {
                continue
            }
            
            let ext = fileURL.pathExtension.lowercased()
            let baseName = fileURL.deletingPathExtension().lastPathComponent.lowercased()
            
            print("🔍 Found file: \(fileURL.lastPathComponent) (ext: .\(ext))")
            
            // 如果有 .cue 文件，跳过对应的 .bin 文件（优先使用 .cue）
            if ext == "bin" && cueFiles.contains(baseName) {
                print("🔍 Skipped .bin (has .cue file): \(fileURL.lastPathComponent)")
                continue
            }
            
            // 如果有 .img 文件，跳过对应的 .ccd 和 .sub 文件
            if (ext == "ccd" || ext == "sub") && imgFiles.contains(baseName) {
                print("🔍 Skipped .\(ext) (has .img file): \(fileURL.lastPathComponent)")
                continue
            }
            
            // 对于 .bin 文件，使用文件头检测来确定正确的系统
            let system: GameSystem?
            if ext == "bin" || ext == "iso" {
                system = GameSystem.system(forFileAt: fileURL)
            } else {
                system = GameSystem.system(forExtension: ext)
            }
            
            if let system = system {
                let game = Game(
                    name: fileURL.deletingPathExtension().lastPathComponent,
                    fileURL: fileURL,
                    system: system,
                    dateAdded: resourceValues.creationDate,
                    fileSizeBytes: resourceValues.fileSize
                )
                foundGames.append(game)
                print("🔍 Added game: \(game.name) (\(system.rawValue))")
            } else {
                print("🔍 Skipped (unsupported extension): \(fileURL.lastPathComponent)")
            }
        }
        
        games = foundGames.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        print("🔍 Total games loaded: \(games.count)")
    }
    
    // MARK: - Importing Games
    
    /// Import games from multiple URLs
    func importGames(from urls: [URL]) async {
        print("📥 Starting import of \(urls.count) file(s)")
        
        // Filter out auxiliary files if their main file is also in the list
        var filteredURLs: [URL] = []
        var skippedAuxFiles: Set<String> = []
        
        for url in urls {
            let ext = url.pathExtension.lowercased()
            let baseName = url.deletingPathExtension().lastPathComponent
            
            // If this is a .ccd or .sub file, check if corresponding .img exists
            if ext == "ccd" || ext == "sub" {
                let imgURL = url.deletingLastPathComponent().appendingPathComponent(baseName).appendingPathExtension("img")
                if urls.contains(imgURL) {
                    print("📥 Skipping \(url.lastPathComponent) (will be imported with .img file)")
                    skippedAuxFiles.insert(url.lastPathComponent)
                    continue
                }
            }
            
            // If this is a .cue file, check if corresponding .bin exists
            if ext == "cue" {
                let binURL = url.deletingLastPathComponent().appendingPathComponent(baseName).appendingPathExtension("bin")
                if urls.contains(binURL) {
                    print("📥 Skipping \(url.lastPathComponent) (will be imported with .bin file)")
                    skippedAuxFiles.insert(url.lastPathComponent)
                    continue
                }
            }
            
            filteredURLs.append(url)
        }
        
        print("📥 Processing \(filteredURLs.count) main file(s) (skipped \(skippedAuxFiles.count) auxiliary files)")
        importProgress = ImportProgress(current: 0, total: filteredURLs.count, currentFile: "")
        
        for (index, url) in filteredURLs.enumerated() {
            importProgress?.current = index
            importProgress?.currentFile = url.lastPathComponent
            print("📥 Importing [\(index + 1)/\(filteredURLs.count)]: \(url.lastPathComponent)")
            
            await importGame(from: url)
        }
        
        importProgress = nil
        print("📥 Import complete, refreshing game list...")
        loadGames()
        print("📥 Game list refreshed. Total games: \(games.count)")
    }
    
    /// Import a game from an external URL
    func importGame(from sourceURL: URL) async {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let ext = sourceURL.pathExtension.lowercased()
        print("📥 File extension: .\(ext)")
        
        // 跳过 PS1 光盘镜像的辅助文件（.ccd, .sub），只处理主镜像文件
        if ext == "ccd" || ext == "sub" {
            print("📥 Skipping auxiliary file: .\(ext) (will be imported with main .img file)")
            return
        }
        
        // 对于 .bin 文件，使用文件头检测来确定正确的系统
        let system: GameSystem?
        if ext == "bin" || ext == "iso" {
            print("📥 Analyzing file content to detect system...")
            system = GameSystem.system(forFileAt: sourceURL)
        } else {
            system = GameSystem.system(forExtension: ext)
        }
        
        guard let system = system else {
            errorMessage = "Unsupported file format: .\(ext)"
            print("❌ Unsupported file format: .\(ext)")
            return
        }
        
        print("📥 Detected system: \(system.rawValue)")
        
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not get documents directory")
            return
        }
        
        let romsURL = documentsURL.appendingPathComponent("ROMs", isDirectory: true)
        let systemURL = romsURL.appendingPathComponent(system.rawValue, isDirectory: true)
        
        print("📥 Target directory: \(systemURL.path)")
        
        // Create system directory if needed
        if !fileManager.fileExists(atPath: systemURL.path) {
            do {
                try fileManager.createDirectory(at: systemURL, withIntermediateDirectories: true)
                print("📥 Created directory: \(systemURL.path)")
            } catch {
                print("❌ Failed to create directory: \(error)")
            }
        }
        
        let destinationURL = systemURL.appendingPathComponent(sourceURL.lastPathComponent)
        print("📥 Destination: \(destinationURL.path)")
        
        do {
            // Remove existing file if present
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
                print("📥 Removed existing file")
            }
            
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            print("✅ Successfully copied to: \(destinationURL.path)")
            
            // For PS1 files, also copy accompanying auxiliary files if they exist
            if system == .ps1 {
                let baseName = sourceURL.deletingPathExtension().lastPathComponent
                let sourceDirectory = sourceURL.deletingLastPathComponent()
                
                // For .img files, copy .ccd and .sub files
                if ext == "img" {
                    print("📥 Checking for CloneCD auxiliary files in: \(sourceDirectory.path)")
                    
                    // Copy .ccd file
                    let ccdSource = sourceDirectory.appendingPathComponent(baseName).appendingPathExtension("ccd")
                    print("📥 Looking for .ccd file: \(ccdSource.lastPathComponent)")
                    
                    let ccdAccessing = ccdSource.startAccessingSecurityScopedResource()
                    defer {
                        if ccdAccessing {
                            ccdSource.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    if fileManager.fileExists(atPath: ccdSource.path) {
                        print("📥 Found .ccd file")
                        let ccdDest = systemURL.appendingPathComponent(baseName).appendingPathExtension("ccd")
                        do {
                            if fileManager.fileExists(atPath: ccdDest.path) {
                                try fileManager.removeItem(at: ccdDest)
                            }
                            try fileManager.copyItem(at: ccdSource, to: ccdDest)
                            print("✅ Also copied: \(ccdSource.lastPathComponent)")
                        } catch {
                            print("⚠️ Failed to copy .ccd file: \(error)")
                        }
                    } else {
                        print("📥 .ccd file not found")
                    }
                    
                    // Copy .sub file
                    let subSource = sourceDirectory.appendingPathComponent(baseName).appendingPathExtension("sub")
                    print("📥 Looking for .sub file: \(subSource.lastPathComponent)")
                    
                    let subAccessing = subSource.startAccessingSecurityScopedResource()
                    defer {
                        if subAccessing {
                            subSource.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    if fileManager.fileExists(atPath: subSource.path) {
                        print("📥 Found .sub file")
                        let subDest = systemURL.appendingPathComponent(baseName).appendingPathExtension("sub")
                        do {
                            if fileManager.fileExists(atPath: subDest.path) {
                                try fileManager.removeItem(at: subDest)
                            }
                            try fileManager.copyItem(at: subSource, to: subDest)
                            print("✅ Also copied: \(subSource.lastPathComponent)")
                        } catch {
                            print("⚠️ Failed to copy .sub file: \(error)")
                        }
                    } else {
                        print("📥 .sub file not found")
                    }
                }
                
                // For .bin files, copy .cue file
                else if ext == "bin" {
                    print("📥 Checking for .cue file in: \(sourceDirectory.path)")
                    
                    let cueSource = sourceDirectory.appendingPathComponent(baseName).appendingPathExtension("cue")
                    print("📥 Looking for .cue file: \(cueSource.lastPathComponent)")
                    
                    let cueAccessing = cueSource.startAccessingSecurityScopedResource()
                    defer {
                        if cueAccessing {
                            cueSource.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    if fileManager.fileExists(atPath: cueSource.path) {
                        print("📥 Found .cue file")
                        let cueDest = systemURL.appendingPathComponent(baseName).appendingPathExtension("cue")
                        do {
                            if fileManager.fileExists(atPath: cueDest.path) {
                                try fileManager.removeItem(at: cueDest)
                            }
                            try fileManager.copyItem(at: cueSource, to: cueDest)
                            print("✅ Also copied: \(cueSource.lastPathComponent)")
                        } catch {
                            print("⚠️ Failed to copy .cue file: \(error)")
                        }
                    } else {
                        print("📥 .cue file not found")
                    }
                }
                
                // For .cue files, copy .bin file
                else if ext == "cue" {
                    print("📥 Checking for .bin file in: \(sourceDirectory.path)")
                    
                    let binSource = sourceDirectory.appendingPathComponent(baseName).appendingPathExtension("bin")
                    print("📥 Looking for .bin file: \(binSource.lastPathComponent)")
                    
                    let binAccessing = binSource.startAccessingSecurityScopedResource()
                    defer {
                        if binAccessing {
                            binSource.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    if fileManager.fileExists(atPath: binSource.path) {
                        print("📥 Found .bin file")
                        let binDest = systemURL.appendingPathComponent(baseName).appendingPathExtension("bin")
                        do {
                            if fileManager.fileExists(atPath: binDest.path) {
                                try fileManager.removeItem(at: binDest)
                            }
                            try fileManager.copyItem(at: binSource, to: binDest)
                            print("✅ Also copied: \(binSource.lastPathComponent)")
                        } catch {
                            print("⚠️ Failed to copy .bin file: \(error)")
                        }
                    } else {
                        print("📥 .bin file not found")
                    }
                }
            }
            
            // Verify the file exists
            if fileManager.fileExists(atPath: destinationURL.path) {
                print("✅ File verified at destination")
            } else {
                print("❌ File not found at destination after copy!")
            }
        } catch {
            errorMessage = "Failed to import \(sourceURL.lastPathComponent): \(error.localizedDescription)"
            print("❌ Import failed: \(error.localizedDescription)")
        }
    }
    
    /// Import all games from a folder (or a single file if user selected a file instead)
    func importGamesFromFolder(_ folderURL: URL) async {
        let accessing = folderURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        
        print("📂 importGamesFromFolder: \(folderURL.path)")
        
        // Check if the URL is actually a file (not a folder)
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory)
        
        print("📂 Path exists: \(exists), isDirectory: \(isDirectory.boolValue)")
        
        if exists && !isDirectory.boolValue {
            // User selected a single file instead of a folder - import it directly
            print("📂 Selected item is a file, importing directly...")
            await importGames(from: [folderURL])
            return
        }
        
        // Find all ROM files in the folder
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            print("📂 Could not create enumerator for folder")
            return
        }
        
        var romURLs: [URL] = []
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true else {
                continue
            }
            
            let ext = fileURL.pathExtension.lowercased()
            print("📂 Found file in folder: \(fileURL.lastPathComponent) (ext: .\(ext))")
            if GameSystem.system(forExtension: ext) != nil {
                romURLs.append(fileURL)
            }
        }
        
        print("📂 Found \(romURLs.count) ROM file(s) in folder")
        
        if romURLs.isEmpty {
            errorMessage = "No supported ROM files found in the selected folder"
            print("📂 No supported ROM files found")
            return
        }
        
        await importGames(from: romURLs)
    }
    
    /// Delete a game
    func deleteGame(_ game: Game) {
        do {
            try fileManager.removeItem(at: game.fileURL)
            games.removeAll { $0.id == game.id }
            
            // Also delete associated save files
            deleteSaveFiles(for: game)
        } catch {
            errorMessage = "Failed to delete game: \(error.localizedDescription)"
        }
    }
    
    /// Delete all save files for a game
    private func deleteSaveFiles(for game: Game) {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        // Delete save states
        let saveStatesURL = documentsURL.appendingPathComponent("SaveStates/\(game.id)")
        try? fileManager.removeItem(at: saveStatesURL)
        
        // Delete battery saves
        let batterySaveURL = documentsURL.appendingPathComponent("Saves/\(game.id).sav")
        try? fileManager.removeItem(at: batterySaveURL)
    }
    
    // MARK: - Favorites
    
    func toggleFavorite(_ game: Game) {
        if let index = games.firstIndex(where: { $0.id == game.id }) {
            games[index].isFavorite.toggle()
            saveFavorites()
            loadFavorites()
        }
    }
    
    /// Load favorites from UserDefaults
    private func loadFavorites() {
        let favoriteIDs = Set(userDefaults.stringArray(forKey: favoriteGamesKey) ?? [])
        
        // Update isFavorite flag on games
        for index in games.indices {
            games[index].isFavorite = favoriteIDs.contains(games[index].id.uuidString)
        }
        
        favoriteGames = games.filter { $0.isFavorite }
    }
    
    /// Save favorites to UserDefaults
    private func saveFavorites() {
        let favoriteIDs = games.filter { $0.isFavorite }.map { $0.id.uuidString }
        userDefaults.set(favoriteIDs, forKey: favoriteGamesKey)
    }
    
    // MARK: - Statistics
    
    var totalGames: Int {
        games.count
    }
    
    var gamesBySystem: [GameSystem: Int] {
        Dictionary(grouping: games, by: { $0.system })
            .mapValues { $0.count }
    }
    
    var totalSize: String {
        let totalBytes = games.compactMap { $0.fileSizeBytes }.reduce(0, +)
        return ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
    }
}
