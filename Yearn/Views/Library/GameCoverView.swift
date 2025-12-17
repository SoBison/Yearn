//
//  GameCoverView.swift
//  Yearn
//
//  Game cover display and management
//

import SwiftUI
import PhotosUI

// MARK: - Game Cover View

struct GameCoverView: View {
    let game: Game
    let size: CoverSize
    
    @State private var coverImage: UIImage?
    @State private var isLoading = true
    
    enum CoverSize {
        case small   // 60x60
        case medium  // 100x100
        case large   // 150x200
        case detail  // 200x267
        
        var dimensions: CGSize {
            switch self {
            case .small: return CGSize(width: 60, height: 60)
            case .medium: return CGSize(width: 100, height: 100)
            case .large: return CGSize(width: 150, height: 200)
            case .detail: return CGSize(width: 200, height: 267)
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 10
            case .large: return 12
            case .detail: return 14
            }
        }
    }
    
    var body: some View {
        ZStack {
            if let image = coverImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.dimensions.width, height: size.dimensions.height)
                    .clipped()
            } else if isLoading {
                placeholderView
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
            } else {
                placeholderView
            }
        }
        .frame(width: size.dimensions.width, height: size.dimensions.height)
        .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        .task {
            await loadCover()
        }
    }
    
    private var placeholderView: some View {
        ZStack {
            // Gradient background based on system
            LinearGradient(
                colors: [
                    game.system.color.opacity(0.8),
                    game.system.color.opacity(0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 4) {
                Image(systemName: game.system.iconName)
                    .font(.system(size: size == .small ? 20 : 32))
                    .foregroundStyle(.white.opacity(0.9))
                
                if size != .small {
                    Text(game.system.shortName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }
    
    private func loadCover() async {
        isLoading = true
        
        // Try to load custom cover first
        if let customCover = await CoverManager.shared.loadCover(for: game) {
            coverImage = customCover
            isLoading = false
            return
        }
        
        // Try to load from artwork service
        if let artwork = await ArtworkService.shared.getArtwork(for: game) {
            coverImage = artwork
            isLoading = false
            return
        }
        
        isLoading = false
    }
}

// MARK: - Cover Manager

actor CoverManager {
    static let shared = CoverManager()
    
    private let coversDirectory: URL
    private var coverCache: [UUID: UIImage] = [:]
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        coversDirectory = documentsPath.appendingPathComponent("Covers", isDirectory: true)
        
        // Create covers directory if needed
        try? FileManager.default.createDirectory(at: coversDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Load Cover
    
    func loadCover(for game: Game) -> UIImage? {
        // Check cache first
        if let cached = coverCache[game.id] {
            return cached
        }
        
        // Try to load from disk
        let coverURL = coversDirectory.appendingPathComponent("\(game.id.uuidString).jpg")
        
        guard FileManager.default.fileExists(atPath: coverURL.path),
              let data = try? Data(contentsOf: coverURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        // Cache and return
        coverCache[game.id] = image
        return image
    }
    
    // MARK: - Save Cover
    
    func saveCover(_ image: UIImage, for game: Game) throws {
        // Resize image to reasonable size
        let resizedImage = resizeImage(image, maxSize: CGSize(width: 400, height: 534))
        
        guard let data = resizedImage.jpegData(compressionQuality: 0.85) else {
            throw CoverError.compressionFailed
        }
        
        let coverURL = coversDirectory.appendingPathComponent("\(game.id.uuidString).jpg")
        try data.write(to: coverURL)
        
        // Update cache
        coverCache[game.id] = resizedImage
    }
    
    // MARK: - Delete Cover
    
    func deleteCover(for game: Game) throws {
        let coverURL = coversDirectory.appendingPathComponent("\(game.id.uuidString).jpg")
        
        if FileManager.default.fileExists(atPath: coverURL.path) {
            try FileManager.default.removeItem(at: coverURL)
        }
        
        coverCache.removeValue(forKey: game.id)
    }
    
    // MARK: - Has Custom Cover
    
    func hasCustomCover(for game: Game) -> Bool {
        let coverURL = coversDirectory.appendingPathComponent("\(game.id.uuidString).jpg")
        return FileManager.default.fileExists(atPath: coverURL.path)
    }
    
    // MARK: - Clear Cache
    
    func clearCache() {
        coverCache.removeAll()
    }
    
    // MARK: - Helpers
    
    private func resizeImage(_ image: UIImage, maxSize: CGSize) -> UIImage {
        let aspectRatio = image.size.width / image.size.height
        var newSize: CGSize
        
        if aspectRatio > maxSize.width / maxSize.height {
            newSize = CGSize(width: maxSize.width, height: maxSize.width / aspectRatio)
        } else {
            newSize = CGSize(width: maxSize.height * aspectRatio, height: maxSize.height)
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Cover Error

enum CoverError: LocalizedError {
    case compressionFailed
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed: return "Failed to compress cover image"
        case .saveFailed: return "Failed to save cover image"
        }
    }
}

// MARK: - Cover Picker Sheet

struct CoverPickerSheet: View {
    let game: Game
    @Binding var isPresented: Bool
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Current cover preview
                GameCoverView(game: game, size: .detail)
                    .padding(.top, 20)
                
                Text(game.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(game.system.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Choose from Photos", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button {
                        Task {
                            await searchOnlineCover()
                        }
                    } label: {
                        Label("Search Online", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button(role: .destructive) {
                        Task {
                            await deleteCover()
                        }
                    } label: {
                        Label("Remove Custom Cover", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Game Cover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .overlay {
                if isLoading {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
            .onChange(of: selectedItem) { _, newValue in
                if let item = newValue {
                    Task {
                        await loadAndSaveImage(from: item)
                    }
                }
            }
        }
    }
    
    private func loadAndSaveImage(from item: PhotosPickerItem) async {
        isLoading = true
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw CoverError.compressionFailed
            }
            
            try await CoverManager.shared.saveCover(image, for: game)
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    private func searchOnlineCover() async {
        isLoading = true
        
        if let artwork = await ArtworkService.shared.fetchArtwork(for: game) {
            do {
                try await CoverManager.shared.saveCover(artwork, for: game)
                isPresented = false
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        } else {
            errorMessage = "No cover found online"
            showError = true
        }
        
        isLoading = false
    }
    
    private func deleteCover() async {
        do {
            try await CoverManager.shared.deleteCover(for: game)
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// Note: GameSystem.iconName and GameSystem.color are defined in Game.swift

#Preview {
    GameCoverView(
        game: Game(
            name: "Super Mario Bros",
            fileURL: URL(fileURLWithPath: "/path/to/rom.nes"),
            system: .nes
        ),
        size: .large
    )
}

