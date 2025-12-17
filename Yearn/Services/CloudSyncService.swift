//
//  CloudSyncService.swift
//  Yearn
//
//  iCloud sync service for game saves and states
//

import Foundation
import CloudKit

// MARK: - Cloud Sync Service

@MainActor
class CloudSyncService: ObservableObject {
    
    static let shared = CloudSyncService()
    
    // MARK: - Published Properties
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    @Published var isCloudAvailable = false
    
    // MARK: - Private Properties
    
    private let fileManager = FileManager.default
    private let containerIdentifier = "iCloud.com.yearn.emulator"
    
    private var ubiquityContainerURL: URL? {
        fileManager.url(forUbiquityContainerIdentifier: containerIdentifier)
    }
    
    private var documentsURL: URL? {
        ubiquityContainerURL?.appendingPathComponent("Documents")
    }
    
    // MARK: - Initialization
    
    private init() {
        checkCloudAvailability()
        setupNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Check if iCloud is available
    func checkCloudAvailability() {
        Task {
            isCloudAvailable = fileManager.ubiquityIdentityToken != nil
        }
    }
    
    /// Sync all data to iCloud
    func syncAll() async throws {
        guard isCloudAvailable else {
            throw CloudSyncError.cloudNotAvailable
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            try await syncSaveStates()
            try await syncGameSaves()
            lastSyncDate = Date()
            syncError = nil
        } catch {
            syncError = error
            throw error
        }
    }
    
    /// Sync save states
    func syncSaveStates() async throws {
        guard let cloudURL = documentsURL?.appendingPathComponent("SaveStates") else {
            throw CloudSyncError.containerNotFound
        }
        
        // Create cloud directory if needed
        try createDirectoryIfNeeded(at: cloudURL)
        
        // Get local save states directory
        let localURL = getLocalSaveStatesURL()
        
        // Sync bidirectionally
        try await syncDirectory(from: localURL, to: cloudURL)
        try await syncDirectory(from: cloudURL, to: localURL)
    }
    
    /// Sync game saves (battery saves)
    func syncGameSaves() async throws {
        guard let cloudURL = documentsURL?.appendingPathComponent("GameSaves") else {
            throw CloudSyncError.containerNotFound
        }
        
        try createDirectoryIfNeeded(at: cloudURL)
        
        let localURL = getLocalGameSavesURL()
        
        try await syncDirectory(from: localURL, to: cloudURL)
        try await syncDirectory(from: cloudURL, to: localURL)
    }
    
    /// Upload a specific file to iCloud
    func uploadFile(at localURL: URL, to relativePath: String) async throws {
        guard let cloudURL = documentsURL?.appendingPathComponent(relativePath) else {
            throw CloudSyncError.containerNotFound
        }
        
        // Create parent directory if needed
        let parentDir = cloudURL.deletingLastPathComponent()
        try createDirectoryIfNeeded(at: parentDir)
        
        // Copy file
        if fileManager.fileExists(atPath: cloudURL.path) {
            try fileManager.removeItem(at: cloudURL)
        }
        try fileManager.copyItem(at: localURL, to: cloudURL)
    }
    
    /// Download a specific file from iCloud
    func downloadFile(from relativePath: String, to localURL: URL) async throws {
        guard let cloudURL = documentsURL?.appendingPathComponent(relativePath) else {
            throw CloudSyncError.containerNotFound
        }
        
        guard fileManager.fileExists(atPath: cloudURL.path) else {
            throw CloudSyncError.fileNotFound
        }
        
        // Start downloading if needed
        try fileManager.startDownloadingUbiquitousItem(at: cloudURL)
        
        // Wait for download to complete
        try await waitForDownload(at: cloudURL)
        
        // Copy to local
        let parentDir = localURL.deletingLastPathComponent()
        try createDirectoryIfNeeded(at: parentDir)
        
        if fileManager.fileExists(atPath: localURL.path) {
            try fileManager.removeItem(at: localURL)
        }
        try fileManager.copyItem(at: cloudURL, to: localURL)
    }
    
    /// List files in iCloud directory
    func listCloudFiles(at relativePath: String) -> [URL] {
        guard let cloudURL = documentsURL?.appendingPathComponent(relativePath) else {
            return []
        }
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cloudURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        return contents
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ubiquityIdentityDidChange),
            name: .NSUbiquityIdentityDidChange,
            object: nil
        )
    }
    
    @objc private func ubiquityIdentityDidChange() {
        checkCloudAvailability()
    }
    
    private func createDirectoryIfNeeded(at url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    private func getLocalSaveStatesURL() -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("SaveStates")
    }
    
    private func getLocalGameSavesURL() -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("GameSaves")
    }
    
    private func syncDirectory(from source: URL, to destination: URL) async throws {
        guard fileManager.fileExists(atPath: source.path) else { return }
        
        let contents = try fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        
        for sourceFile in contents {
            let fileName = sourceFile.lastPathComponent
            let destFile = destination.appendingPathComponent(fileName)
            
            // Check if we should copy
            if shouldCopyFile(from: sourceFile, to: destFile) {
                if fileManager.fileExists(atPath: destFile.path) {
                    try fileManager.removeItem(at: destFile)
                }
                try fileManager.copyItem(at: sourceFile, to: destFile)
            }
        }
    }
    
    private func shouldCopyFile(from source: URL, to destination: URL) -> Bool {
        // If destination doesn't exist, copy
        guard fileManager.fileExists(atPath: destination.path) else {
            return true
        }
        
        // Compare modification dates
        guard let sourceDate = try? fileManager.attributesOfItem(atPath: source.path)[.modificationDate] as? Date,
              let destDate = try? fileManager.attributesOfItem(atPath: destination.path)[.modificationDate] as? Date else {
            return true
        }
        
        return sourceDate > destDate
    }
    
    private func waitForDownload(at url: URL, timeout: TimeInterval = 30) async throws {
        let startTime = Date()
        
        while true {
            // Use the modern API for checking download status
            let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            
            if let status = resourceValues.ubiquitousItemDownloadingStatus,
               status == .current {
                return
            }
            
            if Date().timeIntervalSince(startTime) > timeout {
                throw CloudSyncError.downloadTimeout
            }
            
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
    }
}

// MARK: - Cloud Sync Error

enum CloudSyncError: LocalizedError {
    case cloudNotAvailable
    case containerNotFound
    case fileNotFound
    case downloadTimeout
    case syncFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .cloudNotAvailable:
            return "iCloud is not available. Please sign in to iCloud in Settings."
        case .containerNotFound:
            return "iCloud container not found."
        case .fileNotFound:
            return "File not found in iCloud."
        case .downloadTimeout:
            return "Download timed out."
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}

// MARK: - Sync Status View

import SwiftUI

struct CloudSyncStatusView: View {
    @ObservedObject var syncService = CloudSyncService.shared
    
    var body: some View {
        HStack(spacing: 8) {
            if syncService.isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Syncing...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let lastSync = syncService.lastSyncDate {
                Image(systemName: "checkmark.icloud")
                    .foregroundStyle(.green)
                Text("Last sync: \(lastSync.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !syncService.isCloudAvailable {
                Image(systemName: "icloud.slash")
                    .foregroundStyle(.orange)
                Text("iCloud unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

