//
//  SpotlightService.swift
//  Yearn
//
//  Service for indexing games in Spotlight
//

import Foundation
import CoreSpotlight
import MobileCoreServices
import UniformTypeIdentifiers

/// Service for managing Spotlight search indexing
class SpotlightService {
    static let shared = SpotlightService()
    
    private let searchableIndex = CSSearchableIndex.default()
    private let domainIdentifier = "com.yearn.games"
    
    private init() {}
    
    // MARK: - Indexing
    
    /// Index all games for Spotlight search
    func indexGames(_ games: [Game]) {
        let items = games.map { createSearchableItem(for: $0) }
        
        searchableIndex.indexSearchableItems(items) { error in
            if let error = error {
                print("Spotlight indexing error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Index a single game
    func indexGame(_ game: Game) {
        let item = createSearchableItem(for: game)
        
        searchableIndex.indexSearchableItems([item]) { error in
            if let error = error {
                print("Spotlight indexing error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Remove a game from Spotlight index
    func removeGame(_ game: Game) {
        searchableIndex.deleteSearchableItems(withIdentifiers: [game.id.uuidString]) { error in
            if let error = error {
                print("Spotlight removal error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Remove all games from Spotlight index
    func removeAllGames() {
        searchableIndex.deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { error in
            if let error = error {
                print("Spotlight removal error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Private
    
    private func createSearchableItem(for game: Game) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .data)
        
        // Basic info
        attributeSet.title = game.name
        attributeSet.contentDescription = "\(game.system.displayName) game"
        
        // Keywords for search
        attributeSet.keywords = [
            game.name,
            game.system.rawValue,
            game.system.displayName,
            game.system.manufacturer,
            "game",
            "emulator",
            "retro"
        ]
        
        // Display information
        attributeSet.displayName = game.name
        attributeSet.alternateNames = [game.system.shortName]
        
        // File information
        attributeSet.contentURL = game.fileURL
        if let size = game.fileSizeBytes {
            attributeSet.fileSize = NSNumber(value: size)
        }
        
        // Custom attributes
        attributeSet.creator = game.system.manufacturer
        attributeSet.genre = "Video Game"
        
        let item = CSSearchableItem(
            uniqueIdentifier: game.id.uuidString,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
        
        // Set expiration (never expires)
        item.expirationDate = .distantFuture
        
        return item
    }
}

// MARK: - LibraryViewModel Extension

extension LibraryViewModel {
    /// Update Spotlight index when games change
    func updateSpotlightIndex() {
        SpotlightService.shared.indexGames(games)
    }
}

