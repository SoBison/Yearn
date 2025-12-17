//
//  ArtworkService.swift
//  Yearn
//
//  Service for downloading and caching game artwork
//

import SwiftUI

/// Service for managing game artwork/cover images
@MainActor
class ArtworkService: ObservableObject {
    static let shared = ArtworkService()
    
    private let fileManager = FileManager.default
    private let artworkDirectory: URL
    private var downloadTasks: [String: Task<URL?, Error>] = [:]
    
    // Cache for loaded images
    private var imageCache = NSCache<NSString, UIImage>()
    
    private init() {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        artworkDirectory = documentsURL.appendingPathComponent("Artwork", isDirectory: true)
        
        // Create artwork directory if needed
        try? fileManager.createDirectory(at: artworkDirectory, withIntermediateDirectories: true)
        
        // Configure cache
        imageCache.countLimit = 100
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    /// Get artwork for a game, downloading if necessary
    func getArtwork(for game: Game) async -> UIImage? {
        let cacheKey = game.id.uuidString as NSString
        
        // Check memory cache
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        // Check disk cache
        let localURL = artworkDirectory.appendingPathComponent("\(game.id.uuidString).jpg")
        if fileManager.fileExists(atPath: localURL.path) {
            if let image = UIImage(contentsOfFile: localURL.path) {
                imageCache.setObject(image, forKey: cacheKey)
                return image
            }
        }
        
        // Download artwork
        if let downloadedImage = await downloadArtwork(for: game) {
            imageCache.setObject(downloadedImage, forKey: cacheKey)
            return downloadedImage
        }
        
        return nil
    }
    
    /// Download artwork from various sources
    private func downloadArtwork(for game: Game) async -> UIImage? {
        // 尝试多种名称变体来匹配封面
        let nameVariants = generateNameVariants(for: game.name)
        
        for variant in nameVariants {
            // 创建临时游戏对象使用变体名称
            let tempGame = Game(
                id: game.id,
                name: variant,
                fileURL: game.fileURL,
                system: game.system
            )
            
            // 尝试从 Libretro Thumbnails 下载
            if let url = ArtworkSource.libretroThumbnails.url(for: tempGame) {
                if let image = await downloadFromURL(url) {
                    print("🎨 Found cover with name variant: \(variant)")
                    await saveArtwork(image, for: game)
                    return image
                }
            }
        }
        
        print("🎨 No cover found for: \(game.name)")
        return nil
    }
    
    /// 生成游戏名称的多种变体以提高匹配概率
    private func generateNameVariants(for name: String) -> [String] {
        var variants: [String] = []
        
        // 1. 原始名称
        variants.append(name)
        
        // 2. 清理后的名称（移除括号内容）
        let cleanedName = cleanGameNameForSearch(name)
        if cleanedName != name {
            variants.append(cleanedName)
        }
        
        // 3. 尝试常见的地区后缀变体
        let regionSuffixes = [
            " (USA)",
            " (Japan)",
            " (Europe)",
            " (USA, Europe)",
            " (World)",
            " (Japan, USA)",
            ""
        ]
        
        for suffix in regionSuffixes {
            let variant = cleanedName + suffix
            if !variants.contains(variant) {
                variants.append(variant)
            }
        }
        
        return variants
    }
    
    /// 从指定 URL 下载图片
    private func downloadFromURL(_ url: URL) async -> UIImage? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
    
    /// 清理游戏名称以提高封面匹配率
    private func cleanGameNameForSearch(_ name: String) -> String {
        var cleanName = name
        
        // 移除常见的地区/版本标识（括号内容）
        let bracketPatterns = [
            "\\([^)]*\\)",      // 移除 (xxx) 格式
            "\\[[^\\]]*\\]",    // 移除 [xxx] 格式
        ]
        
        for pattern in bracketPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                cleanName = regex.stringByReplacingMatches(
                    in: cleanName,
                    options: [],
                    range: NSRange(cleanName.startIndex..., in: cleanName),
                    withTemplate: ""
                )
            }
        }
        
        // 移除常见后缀
        let suffixesToRemove = [
            " - Disc 1", " - Disc 2", " - Disc 3", " - Disc 4",
            " Disc 1", " Disc 2", " Disc 3", " Disc 4",
        ]
        
        for suffix in suffixesToRemove {
            if cleanName.lowercased().hasSuffix(suffix.lowercased()) {
                cleanName = String(cleanName.dropLast(suffix.count))
            }
        }
        
        // 清理多余空格
        cleanName = cleanName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
        
        return cleanName
    }
    
    private func saveArtwork(_ image: UIImage, for game: Game) async {
        let localURL = artworkDirectory.appendingPathComponent("\(game.id.uuidString).jpg")
        
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: localURL)
        }
    }
    
    /// Fetch artwork from online sources (public method)
    func fetchArtwork(for game: Game) async -> UIImage? {
        return await downloadArtwork(for: game)
    }
    
    /// Clear artwork cache
    func clearCache() {
        imageCache.removeAllObjects()
        try? fileManager.removeItem(at: artworkDirectory)
        try? fileManager.createDirectory(at: artworkDirectory, withIntermediateDirectories: true)
    }
    
    /// Get cache size
    func getCacheSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(at: artworkDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }
        
        return totalSize
    }
}

// MARK: - Artwork Sources

enum ArtworkSource {
    case libretroThumbnails
    case screenscraper
    
    /// 构建封面图片 URL
    /// - Parameter game: 游戏对象（名称应该已经是要尝试的变体）
    func url(for game: Game) -> URL? {
        switch self {
        case .libretroThumbnails:
            return libretroURL(for: game)
        case .screenscraper:
            return nil // 需要 API Key
        }
    }
    
    private func libretroURL(for game: Game) -> URL? {
        // Libretro thumbnail database URL format
        // https://thumbnails.libretro.com/{system}/Named_Boxarts/{game_name}.png
        
        let systemName: String
        switch game.system {
        case .nes: systemName = "Nintendo - Nintendo Entertainment System"
        case .snes: systemName = "Nintendo - Super Nintendo Entertainment System"
        case .gbc: systemName = "Nintendo - Game Boy Color"
        case .gba: systemName = "Nintendo - Game Boy Advance"
        case .n64: systemName = "Nintendo - Nintendo 64"
        case .nds: systemName = "Nintendo - Nintendo DS"
        case .genesis: systemName = "Sega - Mega Drive - Genesis"
        case .ps1: systemName = "Sony - PlayStation"
        }
        
        // 处理游戏名称中的特殊字符
        let cleanName = game.name
            .replacingOccurrences(of: "&", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? game.name
        
        let urlString = "https://thumbnails.libretro.com/\(systemName)/Named_Boxarts/\(cleanName).png"
        return URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString)
    }
}

// MARK: - Async Image View

struct GameArtworkView: View {
    let game: Game
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
            } else {
                // Placeholder
                Image(systemName: game.system.iconName)
                    .font(.largeTitle)
                    .foregroundStyle(game.system.color)
            }
        }
        .task {
            await loadArtwork()
        }
    }
    
    private func loadArtwork() async {
        isLoading = true
        image = await ArtworkService.shared.getArtwork(for: game)
        isLoading = false
    }
}

#Preview {
    GameArtworkView(
        game: Game(name: "Super Mario Bros", fileURL: URL(fileURLWithPath: "/test.nes"), system: .nes)
    )
    .frame(width: 120, height: 120)
}

