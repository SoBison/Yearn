//
//  SaveStateManager.swift
//  YearnCore
//
//  Save state management
//

import Foundation

/// Manages save states for games
public final class SaveStateManager {
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let saveStatesDirectory: URL
    
    /// Maximum number of save state slots per game
    public let maxSlots = 10
    
    // MARK: - Initialization
    
    public init() {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        saveStatesDirectory = documentsURL.appendingPathComponent("SaveStates", isDirectory: true)
        
        // Create directory if needed
        try? fileManager.createDirectory(at: saveStatesDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Public Methods
    
    /// Get the URL for a save state slot
    public func saveStateURL(for gameIdentifier: String, slot: Int) -> URL {
        let gameDirectory = saveStatesDirectory.appendingPathComponent(gameIdentifier, isDirectory: true)
        
        // Create game directory if needed
        try? fileManager.createDirectory(at: gameDirectory, withIntermediateDirectories: true)
        
        return gameDirectory.appendingPathComponent("slot\(slot).state")
    }
    
    /// Check if a save state exists for a slot
    public func saveStateExists(for gameIdentifier: String, slot: Int) -> Bool {
        let url = saveStateURL(for: gameIdentifier, slot: slot)
        return fileManager.fileExists(atPath: url.path)
    }
    
    /// Get info for all save states of a game
    public func getSaveStates(for gameIdentifier: String) -> [SaveStateInfo] {
        var states: [SaveStateInfo] = []
        
        for slot in 0..<maxSlots {
            let url = saveStateURL(for: gameIdentifier, slot: slot)
            
            if fileManager.fileExists(atPath: url.path),
               let attributes = try? fileManager.attributesOfItem(atPath: url.path),
               let modificationDate = attributes[.modificationDate] as? Date {
                
                let info = SaveStateInfo(
                    slot: slot,
                    url: url,
                    date: modificationDate,
                    screenshotURL: screenshotURL(for: gameIdentifier, slot: slot)
                )
                states.append(info)
            }
        }
        
        return states.sorted { $0.date > $1.date }
    }
    
    /// Delete a save state
    public func deleteSaveState(for gameIdentifier: String, slot: Int) throws {
        let url = saveStateURL(for: gameIdentifier, slot: slot)
        try fileManager.removeItem(at: url)
        
        // Also delete screenshot if exists
        let screenshot = screenshotURL(for: gameIdentifier, slot: slot)
        try? fileManager.removeItem(at: screenshot)
    }
    
    /// Delete all save states for a game
    public func deleteAllSaveStates(for gameIdentifier: String) throws {
        let gameDirectory = saveStatesDirectory.appendingPathComponent(gameIdentifier, isDirectory: true)
        try fileManager.removeItem(at: gameDirectory)
    }
    
    // MARK: - Screenshots
    
    /// Get the URL for a save state screenshot
    public func screenshotURL(for gameIdentifier: String, slot: Int) -> URL {
        let gameDirectory = saveStatesDirectory.appendingPathComponent(gameIdentifier, isDirectory: true)
        return gameDirectory.appendingPathComponent("slot\(slot).png")
    }
    
    /// Save a screenshot for a save state
    public func saveScreenshot(_ data: Data, for gameIdentifier: String, slot: Int) throws {
        let url = screenshotURL(for: gameIdentifier, slot: slot)
        try data.write(to: url)
    }
    
    // MARK: - Auto Save
    
    /// URL for auto save state
    public func autoSaveURL(for gameIdentifier: String) -> URL {
        let gameDirectory = saveStatesDirectory.appendingPathComponent(gameIdentifier, isDirectory: true)
        try? fileManager.createDirectory(at: gameDirectory, withIntermediateDirectories: true)
        return gameDirectory.appendingPathComponent("auto.state")
    }
    
    /// Check if auto save exists
    public func autoSaveExists(for gameIdentifier: String) -> Bool {
        let url = autoSaveURL(for: gameIdentifier)
        return fileManager.fileExists(atPath: url.path)
    }
}

// MARK: - Save State Info

/// Information about a save state
public struct SaveStateInfo: Identifiable {
    public let id = UUID()
    public let slot: Int
    public let url: URL
    public let date: Date
    public let screenshotURL: URL?
    
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

