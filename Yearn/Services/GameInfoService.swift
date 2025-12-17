//
//  GameInfoService.swift
//  Yearn
//
//  Service for fetching game information and metadata
//

import Foundation

// MARK: - Game Info Result (for GameDetailView)

struct GameInfoResult {
    let description: String
    let developer: String
    let publisher: String
    let releaseDate: String
    let genre: String
    
    init(from gameInfo: GameInfo) {
        self.description = gameInfo.description ?? ""
        self.developer = gameInfo.developer ?? ""
        self.publisher = gameInfo.publisher ?? ""
        self.releaseDate = gameInfo.releaseDate ?? ""
        self.genre = gameInfo.genre ?? ""
    }
}

// MARK: - Game Info Model

struct GameInfo: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let releaseDate: String?
    let developer: String?
    let publisher: String?
    let genre: String?
    let players: String?
    let rating: Double?
    let boxArtURL: String?
    let screenshotURLs: [String]?
    let region: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name = "game_title"
        case description = "overview"
        case releaseDate = "release_date"
        case developer
        case publisher
        case genre
        case players
        case rating
        case boxArtURL = "box_art"
        case screenshotURLs = "screenshots"
        case region
    }
}

// MARK: - Game Info Service

@MainActor
class GameInfoService: ObservableObject {
    static let shared = GameInfoService()
    
    @Published var isLoading = false
    @Published var error: Error?
    
    private let cache = NSCache<NSString, CachedGameInfo>()
    private let userDefaults = UserDefaults.standard
    
    private init() {
        cache.countLimit = 100
    }
    
    // MARK: - Public Methods
    
    /// Search for game info result (simplified for GameDetailView)
    func searchGameInfo(for game: Game) async -> GameInfoResult? {
        let results = await searchGame(name: game.name, system: game.system)
        guard let first = results.first else { return nil }
        return GameInfoResult(from: first)
    }
    
    /// Search for game information by name
    func searchGame(name: String, system: GameSystem) async -> [GameInfo] {
        isLoading = true
        defer { isLoading = false }
        
        // Check cache first
        let cacheKey = "\(name)_\(system.rawValue)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached.results
        }
        
        do {
            let results = try await performSearch(name: name, system: system)
            cache.setObject(CachedGameInfo(results: results), forKey: cacheKey)
            return results
        } catch {
            self.error = error
            return []
        }
    }
    
    /// Get game info by hash (for exact matching)
    func getGameInfo(hash: String, system: GameSystem) async -> GameInfo? {
        isLoading = true
        defer { isLoading = false }
        
        // Check cache
        let cacheKey = hash as NSString
        if let cached = cache.object(forKey: cacheKey), let first = cached.results.first {
            return first
        }
        
        do {
            if let result = try await performHashLookup(hash: hash, system: system) {
                cache.setObject(CachedGameInfo(results: [result]), forKey: cacheKey)
                return result
            }
        } catch {
            self.error = error
        }
        
        return nil
    }
    
    /// Calculate ROM hash for identification
    func calculateHash(for fileURL: URL) -> String? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        
        // Use CRC32 for ROM identification (common in databases)
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc >> 1) ^ (crc & 1 != 0 ? 0xEDB88320 : 0)
            }
        }
        
        return String(format: "%08X", ~crc)
    }
    
    // MARK: - Private Methods
    
    private func performSearch(name: String, system: GameSystem) async throws -> [GameInfo] {
        // Build search URL for TheGamesDB or similar API
        // Note: In production, you'd use an actual API key
        let platformID = getPlatformID(for: system)
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        
        // This is a placeholder - in real implementation, use actual game database API
        let urlString = "https://api.thegamesdb.net/v1/Games/ByGameName?apikey=API_KEY&name=\(encodedName)&filter[platform]=\(platformID)"
        
        guard let url = URL(string: urlString) else {
            throw GameInfoError.invalidURL
        }
        
        // For now, return mock data since we don't have a real API key
        return createMockResults(for: name, system: system)
    }
    
    private func performHashLookup(hash: String, system: GameSystem) async throws -> GameInfo? {
        // In real implementation, this would query a database by ROM hash
        // Many game databases support CRC32/MD5/SHA1 lookups
        return nil
    }
    
    private func getPlatformID(for system: GameSystem) -> Int {
        // TheGamesDB platform IDs
        switch system {
        case .nes: return 7
        case .snes: return 6
        case .gbc: return 4
        case .gba: return 5
        case .n64: return 3
        case .nds: return 8
        case .genesis: return 18
        case .ps1: return 10
        }
    }
    
    private func createMockResults(for name: String, system: GameSystem) -> [GameInfo] {
        // Return mock data for demonstration
        return [
            GameInfo(
                id: UUID().uuidString,
                name: name,
                description: "A classic \(system.displayName) game.",
                releaseDate: nil,
                developer: nil,
                publisher: nil,
                genre: "Action",
                players: "1-2",
                rating: nil,
                boxArtURL: nil,
                screenshotURLs: nil,
                region: "USA"
            )
        ]
    }
}

// MARK: - Cache Helper

private class CachedGameInfo {
    let results: [GameInfo]
    let timestamp: Date
    
    init(results: [GameInfo]) {
        self.results = results
        self.timestamp = Date()
    }
}

// MARK: - Errors

enum GameInfoError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case parseError
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid search URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parseError:
            return "Failed to parse game information"
        case .notFound:
            return "Game not found"
        }
    }
}

// MARK: - Game Info View

import SwiftUI

struct GameInfoView: View {
    let game: Game
    @StateObject private var service = GameInfoService.shared
    @State private var gameInfo: GameInfo?
    @State private var searchResults: [GameInfo] = []
    @State private var isSearching = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Game header
                Section {
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(game.system.color.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay {
                                Image(systemName: game.system.iconName)
                                    .font(.largeTitle)
                                    .foregroundStyle(game.system.color)
                            }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(game.name)
                                .font(.headline)
                            Text(game.system.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let size = game.fileSize {
                                Text(size)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // Game info
                if let info = gameInfo {
                    if let description = info.description {
                        Section("Description") {
                            Text(description)
                                .font(.body)
                        }
                    }
                    
                    Section("Details") {
                        if let developer = info.developer {
                            LabeledContent("Developer", value: developer)
                        }
                        if let publisher = info.publisher {
                            LabeledContent("Publisher", value: publisher)
                        }
                        if let releaseDate = info.releaseDate {
                            LabeledContent("Release Date", value: releaseDate)
                        }
                        if let genre = info.genre {
                            LabeledContent("Genre", value: genre)
                        }
                        if let players = info.players {
                            LabeledContent("Players", value: players)
                        }
                        if let region = info.region {
                            LabeledContent("Region", value: region)
                        }
                    }
                } else if isSearching {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Searching...")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section {
                        Button {
                            searchForGameInfo()
                        } label: {
                            Label("Search for Game Info", systemImage: "magnifyingglass")
                        }
                    }
                }
                
                // File info
                Section("File Information") {
                    LabeledContent("File Name", value: game.fileURL.lastPathComponent)
                    LabeledContent("Extension", value: game.fileExtension.uppercased())
                    if let hash = GameInfoService.shared.calculateHash(for: game.fileURL) {
                        LabeledContent("CRC32", value: hash)
                            .fontDesign(.monospaced)
                    }
                }
            }
            .navigationTitle("Game Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func searchForGameInfo() {
        isSearching = true
        Task {
            let results = await service.searchGame(name: game.name, system: game.system)
            searchResults = results
            gameInfo = results.first
            isSearching = false
        }
    }
}

#Preview {
    GameInfoView(game: Game(
        name: "Super Mario Bros",
        fileURL: URL(fileURLWithPath: "/test.nes"),
        system: .nes
    ))
}

