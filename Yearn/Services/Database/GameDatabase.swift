//
//  GameDatabase.swift
//  Yearn
//
//  SwiftData-based game database service
//

import Foundation
import SwiftData

// MARK: - Game Entity

@Model
final class GameEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var filePath: String
    var systemRawValue: String
    var dateAdded: Date
    var lastPlayed: Date?
    var playTime: TimeInterval
    var isFavorite: Bool
    var artworkPath: String?
    var md5Hash: String?
    
    init(
        id: UUID = UUID(),
        name: String,
        filePath: String,
        system: GameSystem,
        dateAdded: Date = Date(),
        lastPlayed: Date? = nil,
        playTime: TimeInterval = 0,
        isFavorite: Bool = false,
        artworkPath: String? = nil,
        md5Hash: String? = nil
    ) {
        self.id = id
        self.name = name
        self.filePath = filePath
        self.systemRawValue = system.rawValue
        self.dateAdded = dateAdded
        self.lastPlayed = lastPlayed
        self.playTime = playTime
        self.isFavorite = isFavorite
        self.artworkPath = artworkPath
        self.md5Hash = md5Hash
    }
    
    var system: GameSystem {
        GameSystem(rawValue: systemRawValue) ?? .nes
    }
    
    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }
    
    var artworkURL: URL? {
        guard let path = artworkPath else { return nil }
        return URL(fileURLWithPath: path)
    }
    
    func toGame() -> Game {
        Game(
            id: id,
            name: name,
            fileURL: fileURL,
            system: system,
            artworkURL: artworkURL,
            dateAdded: dateAdded,
            lastPlayed: lastPlayed,
            isFavorite: isFavorite
        )
    }
}

// MARK: - Save State Entity

@Model
final class SaveStateEntity {
    @Attribute(.unique) var id: UUID
    var gameID: UUID
    var slot: Int
    var filePath: String
    var screenshotPath: String?
    var dateCreated: Date
    var isAutoSave: Bool
    
    init(
        id: UUID = UUID(),
        gameID: UUID,
        slot: Int,
        filePath: String,
        screenshotPath: String? = nil,
        dateCreated: Date = Date(),
        isAutoSave: Bool = false
    ) {
        self.id = id
        self.gameID = gameID
        self.slot = slot
        self.filePath = filePath
        self.screenshotPath = screenshotPath
        self.dateCreated = dateCreated
        self.isAutoSave = isAutoSave
    }
}

// MARK: - Cheat Entity

@Model
final class CheatEntity {
    @Attribute(.unique) var id: UUID
    var gameID: UUID
    var name: String
    var code: String
    var isEnabled: Bool
    
    init(
        id: UUID = UUID(),
        gameID: UUID,
        name: String,
        code: String,
        isEnabled: Bool = false
    ) {
        self.id = id
        self.gameID = gameID
        self.name = name
        self.code = code
        self.isEnabled = isEnabled
    }
}

// MARK: - Database Service

/// Type alias for backward compatibility
typealias GameDatabase = GameDatabaseService

@MainActor
class GameDatabaseService: ObservableObject {
    
    static let shared = GameDatabaseService()
    
    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?
    
    @Published var games: [GameEntity] = []
    @Published var isLoaded = false
    
    private init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        do {
            let schema = Schema([
                GameEntity.self,
                SaveStateEntity.self,
                CheatEntity.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = modelContainer?.mainContext
            
            loadGames()
            isLoaded = true
        } catch {
            print("Failed to setup database: \(error)")
        }
    }
    
    // MARK: - Game Operations
    
    func loadGames() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<GameEntity>(
            sortBy: [SortDescriptor(\.name)]
        )
        
        do {
            games = try context.fetch(descriptor)
        } catch {
            print("Failed to fetch games: \(error)")
        }
    }
    
    func addGame(_ game: Game) {
        guard let context = modelContext else { return }
        
        let entity = GameEntity(
            id: game.id,
            name: game.name,
            filePath: game.fileURL.path,
            system: game.system,
            dateAdded: game.dateAdded ?? Date(),
            artworkPath: game.artworkURL?.path
        )
        
        context.insert(entity)
        saveContext()
        loadGames()
    }
    
    func updateGame(_ game: GameEntity) {
        saveContext()
        loadGames()
    }
    
    func deleteGame(_ game: GameEntity) {
        guard let context = modelContext else { return }
        
        context.delete(game)
        saveContext()
        loadGames()
    }
    
    func updateLastPlayed(for gameID: UUID) {
        guard let game = games.first(where: { $0.id == gameID }) else { return }
        
        game.lastPlayed = Date()
        saveContext()
    }
    
    func updatePlayTime(for gameID: UUID, additionalTime: TimeInterval) {
        guard let game = games.first(where: { $0.id == gameID }) else { return }
        
        game.playTime += additionalTime
        saveContext()
    }
    
    func toggleFavorite(for gameID: UUID) {
        guard let game = games.first(where: { $0.id == gameID }) else { return }
        
        game.isFavorite.toggle()
        saveContext()
        loadGames()
    }
    
    // MARK: - Save State Operations
    
    func getSaveStates(for gameID: UUID) -> [SaveStateEntity] {
        guard let context = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<SaveStateEntity>(
            predicate: #Predicate { $0.gameID == gameID },
            sortBy: [SortDescriptor(\.slot)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch save states: \(error)")
            return []
        }
    }
    
    func addSaveState(_ saveState: SaveStateEntity) {
        guard let context = modelContext else { return }
        
        context.insert(saveState)
        saveContext()
    }
    
    func deleteSaveState(_ saveState: SaveStateEntity) {
        guard let context = modelContext else { return }
        
        // Delete files
        try? FileManager.default.removeItem(atPath: saveState.filePath)
        if let screenshotPath = saveState.screenshotPath {
            try? FileManager.default.removeItem(atPath: screenshotPath)
        }
        
        context.delete(saveState)
        saveContext()
    }
    
    // MARK: - Cheat Operations
    
    func getCheats(for gameID: UUID) -> [CheatEntity] {
        guard let context = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<CheatEntity>(
            predicate: #Predicate { $0.gameID == gameID },
            sortBy: [SortDescriptor(\.name)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch cheats: \(error)")
            return []
        }
    }
    
    func addCheat(_ cheat: CheatEntity) {
        guard let context = modelContext else { return }
        
        context.insert(cheat)
        saveContext()
    }
    
    func deleteCheat(_ cheat: CheatEntity) {
        guard let context = modelContext else { return }
        
        context.delete(cheat)
        saveContext()
    }
    
    func toggleCheat(_ cheat: CheatEntity) {
        cheat.isEnabled.toggle()
        saveContext()
    }
    
    // MARK: - Queries
    
    func recentlyPlayedGames(limit: Int = 10) -> [GameEntity] {
        return games
            .filter { $0.lastPlayed != nil }
            .sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }
    
    func favoriteGames() -> [GameEntity] {
        return games.filter { $0.isFavorite }
    }
    
    func games(for system: GameSystem) -> [GameEntity] {
        return games.filter { $0.system == system }
    }
    
    func searchGames(query: String) -> [GameEntity] {
        guard !query.isEmpty else { return games }
        return games.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    
    // MARK: - Private
    
    private func saveContext() {
        guard let context = modelContext else { return }
        
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}

// MARK: - Game System Extension

extension GameSystem {
    var displayColor: String {
        switch self {
        case .nes: return "red"
        case .snes: return "purple"
        case .gbc: return "green"
        case .gba: return "blue"
        case .n64: return "orange"
        case .nds: return "cyan"
        case .genesis: return "indigo"
        case .ps1: return "gray"
        }
    }
}

