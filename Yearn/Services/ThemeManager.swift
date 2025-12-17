//
//  ThemeManager.swift
//  Yearn
//
//  Theme management with gaming-inspired color schemes
//

import SwiftUI

// MARK: - App Theme

struct AppTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let localizedNameKey: String
    let description: String
    let localizedDescKey: String
    let icon: String
    
    // Light mode colors
    let accentColor: Color
    let listBackgroundColor: Color
    let cardBackgroundColor: Color
    
    // Is this a dark theme?
    let isDarkTheme: Bool
    
    // Tab bar tint
    var tabBarTint: Color { accentColor }
    
    static func == (lhs: AppTheme, rhs: AppTheme) -> Bool {
        lhs.id == rhs.id
    }
    
    var localizedName: String {
        localizedNameKey.localized
    }
    
    var localizedDescription: String {
        localizedDescKey.localized
    }
}

// MARK: - Built-in Themes

extension AppTheme {
    
    // MARK: - Default (System)
    static let `default` = AppTheme(
        id: "default",
        name: "Default",
        localizedNameKey: "theme.default",
        description: "Clean and modern system style",
        localizedDescKey: "theme.default.desc",
        icon: "circle.lefthalf.filled",
        accentColor: .blue,
        listBackgroundColor: Color(.systemGroupedBackground),
        cardBackgroundColor: Color(.secondarySystemGroupedBackground),
        isDarkTheme: false
    )
    
    // MARK: - Nintendo Classic (Light - Red accent)
    static let nintendoClassic = AppTheme(
        id: "nintendo",
        name: "Nintendo Classic",
        localizedNameKey: "theme.nintendo",
        description: "Inspired by the classic NES/Famicom",
        localizedDescKey: "theme.nintendo.desc",
        icon: "gamecontroller.fill",
        accentColor: Color(red: 0.89, green: 0.19, blue: 0.19),  // Nintendo Red
        listBackgroundColor: Color(.systemGroupedBackground),
        cardBackgroundColor: Color(.secondarySystemGroupedBackground),
        isDarkTheme: false
    )
    
    // MARK: - Super Nintendo (Light - Purple/Yellow accent)
    static let superNintendo = AppTheme(
        id: "snes",
        name: "Super Nintendo",
        localizedNameKey: "theme.snes",
        description: "Colorful SNES button style",
        localizedDescKey: "theme.snes.desc",
        icon: "square.grid.2x2.fill",
        accentColor: Color(red: 0.5, green: 0.2, blue: 0.7),  // Purple
        listBackgroundColor: Color(.systemGroupedBackground),
        cardBackgroundColor: Color(.secondarySystemGroupedBackground),
        isDarkTheme: false
    )
    
    // MARK: - Game Boy (Light - Green accent)
    static let gameBoy = AppTheme(
        id: "gameboy",
        name: "Game Boy",
        localizedNameKey: "theme.gameboy",
        description: "Classic green monochrome display",
        localizedDescKey: "theme.gameboy.desc",
        icon: "rectangle.portrait.fill",
        accentColor: Color(red: 0.55, green: 0.67, blue: 0.06),  // GB Green
        listBackgroundColor: Color(red: 0.85, green: 0.89, blue: 0.78),  // Light GB green
        cardBackgroundColor: Color(red: 0.90, green: 0.93, blue: 0.83),
        isDarkTheme: false
    )
    
    // MARK: - PlayStation (Dark - Blue accent)
    static let playStation = AppTheme(
        id: "playstation",
        name: "PlayStation",
        localizedNameKey: "theme.playstation",
        description: "Sony PlayStation inspired dark theme",
        localizedDescKey: "theme.playstation.desc",
        icon: "circle.grid.cross.fill",
        accentColor: Color(red: 0.0, green: 0.55, blue: 0.9),  // PS Blue
        listBackgroundColor: Color(red: 0.06, green: 0.06, blue: 0.12),
        cardBackgroundColor: Color(red: 0.12, green: 0.12, blue: 0.18),
        isDarkTheme: true
    )
    
    // MARK: - Xbox (Dark - Green accent)
    static let xbox = AppTheme(
        id: "xbox",
        name: "Xbox",
        localizedNameKey: "theme.xbox",
        description: "Microsoft Xbox green accent theme",
        localizedDescKey: "theme.xbox.desc",
        icon: "xmark.circle.fill",
        accentColor: Color(red: 0.07, green: 0.49, blue: 0.17),  // Xbox Green
        listBackgroundColor: Color(red: 0.08, green: 0.08, blue: 0.08),
        cardBackgroundColor: Color(red: 0.14, green: 0.14, blue: 0.14),
        isDarkTheme: true
    )
    
    // MARK: - Sega Genesis (Dark - Blue/Gold accent)
    static let segaGenesis = AppTheme(
        id: "genesis",
        name: "Sega Genesis",
        localizedNameKey: "theme.genesis",
        description: "Sega blue and speed style",
        localizedDescKey: "theme.genesis.desc",
        icon: "bolt.circle.fill",
        accentColor: Color(red: 0.0, green: 0.4, blue: 0.8),  // Sega Blue
        listBackgroundColor: Color(red: 0.04, green: 0.04, blue: 0.1),
        cardBackgroundColor: Color(red: 0.08, green: 0.08, blue: 0.16),
        isDarkTheme: true
    )
    
    // MARK: - Retro Arcade (Dark - Neon accent)
    static let retroArcade = AppTheme(
        id: "arcade",
        name: "Retro Arcade",
        localizedNameKey: "theme.arcade",
        description: "Neon lights and dark cabinets",
        localizedDescKey: "theme.arcade.desc",
        icon: "sparkles",
        accentColor: Color(red: 1.0, green: 0.0, blue: 0.5),  // Hot Pink
        listBackgroundColor: Color(red: 0.06, green: 0.02, blue: 0.1),
        cardBackgroundColor: Color(red: 0.12, green: 0.04, blue: 0.16),
        isDarkTheme: true
    )
    
    // MARK: - Cyberpunk (Dark - Cyan accent)
    static let cyberpunk = AppTheme(
        id: "cyberpunk",
        name: "Cyberpunk",
        localizedNameKey: "theme.cyberpunk",
        description: "Futuristic neon cyber style",
        localizedDescKey: "theme.cyberpunk.desc",
        icon: "cpu.fill",
        accentColor: Color(red: 0.0, green: 0.96, blue: 0.88),  // Cyber Cyan
        listBackgroundColor: Color(red: 0.05, green: 0.03, blue: 0.1),
        cardBackgroundColor: Color(red: 0.1, green: 0.06, blue: 0.16),
        isDarkTheme: true
    )
    
    // MARK: - Pixel Art (Dark - Orange accent)
    static let pixelArt = AppTheme(
        id: "pixel",
        name: "Pixel Art",
        localizedNameKey: "theme.pixel",
        description: "8-bit inspired warm colors",
        localizedDescKey: "theme.pixel.desc",
        icon: "square.grid.3x3.fill",
        accentColor: Color(red: 0.95, green: 0.6, blue: 0.2),  // Orange
        listBackgroundColor: Color(red: 0.14, green: 0.1, blue: 0.18),
        cardBackgroundColor: Color(red: 0.2, green: 0.14, blue: 0.24),
        isDarkTheme: true
    )
    
    // MARK: - Midnight (Dark - Soft Blue accent)
    static let midnight = AppTheme(
        id: "midnight",
        name: "Midnight",
        localizedNameKey: "theme.midnight",
        description: "Pure dark OLED-friendly theme",
        localizedDescKey: "theme.midnight.desc",
        icon: "moon.stars.fill",
        accentColor: Color(red: 0.4, green: 0.5, blue: 1.0),  // Soft Blue
        listBackgroundColor: .black,
        cardBackgroundColor: Color(red: 0.1, green: 0.1, blue: 0.12),
        isDarkTheme: true
    )
    
    // MARK: - Sunset (Dark - Coral accent)
    static let sunset = AppTheme(
        id: "sunset",
        name: "Sunset",
        localizedNameKey: "theme.sunset",
        description: "Warm gradient sunset colors",
        localizedDescKey: "theme.sunset.desc",
        icon: "sun.horizon.fill",
        accentColor: Color(red: 1.0, green: 0.4, blue: 0.3),  // Coral
        listBackgroundColor: Color(red: 0.12, green: 0.06, blue: 0.1),
        cardBackgroundColor: Color(red: 0.18, green: 0.1, blue: 0.14),
        isDarkTheme: true
    )
    
    // MARK: - Ocean (Dark - Teal accent)
    static let ocean = AppTheme(
        id: "ocean",
        name: "Ocean",
        localizedNameKey: "theme.ocean",
        description: "Deep sea blue tones",
        localizedDescKey: "theme.ocean.desc",
        icon: "water.waves",
        accentColor: Color(red: 0.0, green: 0.8, blue: 0.7),  // Teal
        listBackgroundColor: Color(red: 0.03, green: 0.08, blue: 0.12),
        cardBackgroundColor: Color(red: 0.06, green: 0.12, blue: 0.18),
        isDarkTheme: true
    )
    
    // MARK: - Forest (Dark - Green accent)
    static let forest = AppTheme(
        id: "forest",
        name: "Forest",
        localizedNameKey: "theme.forest",
        description: "Natural green woodland style",
        localizedDescKey: "theme.forest.desc",
        icon: "leaf.fill",
        accentColor: Color(red: 0.2, green: 0.65, blue: 0.35),  // Forest Green
        listBackgroundColor: Color(red: 0.06, green: 0.08, blue: 0.05),
        cardBackgroundColor: Color(red: 0.1, green: 0.13, blue: 0.08),
        isDarkTheme: true
    )
    
    // MARK: - All Themes
    static let allThemes: [AppTheme] = [
        .default,
        .nintendoClassic,
        .superNintendo,
        .gameBoy,
        .playStation,
        .xbox,
        .segaGenesis,
        .retroArcade,
        .cyberpunk,
        .pixelArt,
        .midnight,
        .sunset,
        .ocean,
        .forest
    ]
    
    // MARK: - Gaming Themes
    static let gamingThemes: [AppTheme] = [
        .nintendoClassic,
        .superNintendo,
        .gameBoy,
        .playStation,
        .xbox,
        .segaGenesis
    ]
    
    // MARK: - Style Themes
    static let styleThemes: [AppTheme] = [
        .retroArcade,
        .cyberpunk,
        .pixelArt,
        .midnight,
        .sunset,
        .ocean,
        .forest
    ]
}

// MARK: - Theme Manager

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: AppTheme = .default {
        didSet {
            saveTheme()
        }
    }
    
    private init() {
        // Load saved theme after initialization
        let savedId = UserDefaults.standard.string(forKey: "selectedThemeId") ?? "default"
        if let theme = AppTheme.allThemes.first(where: { $0.id == savedId }) {
            currentTheme = theme
        }
    }
    
    func setTheme(_ theme: AppTheme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTheme = theme
        }
    }
    
    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.id, forKey: "selectedThemeId")
    }
}

// MARK: - Theme Environment Key

struct ThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .default
}

extension EnvironmentValues {
    var theme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Themed View Modifier

struct ThemedViewModifier: ViewModifier {
    @ObservedObject var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .environment(\.theme, themeManager.currentTheme)
            .tint(themeManager.currentTheme.accentColor)
            .preferredColorScheme(themeManager.currentTheme.id == "default" ? nil :
                                  (themeManager.currentTheme.isDarkTheme ? .dark : .light))
    }
}

extension View {
    func themed() -> some View {
        modifier(ThemedViewModifier())
    }
    
    func themedBackground() -> some View {
        modifier(ThemedBackgroundModifier())
    }
    
    func themedListBackground() -> some View {
        modifier(ThemedListBackgroundModifier())
    }
}

// MARK: - Themed Background Modifier

struct ThemedBackgroundModifier: ViewModifier {
    @ObservedObject var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .background(themeManager.currentTheme.listBackgroundColor)
    }
}

// MARK: - Themed List Background Modifier

struct ThemedListBackgroundModifier: ViewModifier {
    @ObservedObject var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(themeManager.currentTheme.listBackgroundColor)
    }
}

// MARK: - Theme Settings View

struct ThemeSettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var refreshID = UUID()
    
    var body: some View {
        List {
            // Current theme preview
            Section {
                ThemePreviewCard(theme: themeManager.currentTheme, isSelected: true)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                Text("theme.current".localized)
            }
            
            // Default
            Section("theme.system".localized) {
                ThemeRow(theme: .default, isSelected: themeManager.currentTheme.id == "default") {
                    themeManager.setTheme(.default)
                }
            }
            
            // Gaming themes
            Section("theme.gaming".localized) {
                ForEach(AppTheme.gamingThemes) { theme in
                    ThemeRow(theme: theme, isSelected: themeManager.currentTheme.id == theme.id) {
                        themeManager.setTheme(theme)
                    }
                }
            }
            
            // Style themes
            Section("theme.styles".localized) {
                ForEach(AppTheme.styleThemes) { theme in
                    ThemeRow(theme: theme, isSelected: themeManager.currentTheme.id == theme.id) {
                        themeManager.setTheme(theme)
                    }
                }
            }
        }
        .id(refreshID)
        .themedListBackground()
        .navigationTitle("theme.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            refreshID = UUID()
        }
    }
}

// MARK: - Theme Row

struct ThemeRow: View {
    let theme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            onSelect()
            HapticManager.shared.selectionChanged()
        }) {
            HStack(spacing: 12) {
                // Color preview circles
                HStack(spacing: 4) {
                    Circle()
                        .fill(theme.accentColor)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .fill(theme.listBackgroundColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: theme.icon)
                            .foregroundStyle(theme.accentColor)
                            .font(.system(size: 14))
                        Text(theme.localizedName)
                            .fontWeight(.medium)
                    }
                    
                    Text(theme.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accentColor)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Theme Preview Card

struct ThemePreviewCard: View {
    let theme: AppTheme
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Mock navigation bar
            HStack {
                Text("tab.library".localized)
                    .font(.headline)
                    .foregroundStyle(theme.isDarkTheme ? .white : .primary)
                Spacer()
                Image(systemName: "plus")
                    .foregroundStyle(theme.accentColor)
            }
            .padding()
            .background(theme.cardBackgroundColor)
            
            // Mock content
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { i in
                    VStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.listBackgroundColor)
                            .frame(width: 70, height: 90)
                            .overlay {
                                Image(systemName: "gamecontroller.fill")
                                    .foregroundStyle(theme.accentColor.opacity(0.6))
                            }
                        
                        Text("theme.preview.game".localized + " \(i + 1)")
                            .font(.caption)
                            .foregroundStyle(theme.isDarkTheme ? .white : .primary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(theme.cardBackgroundColor)
            
            // Mock tab bar
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "gamecontroller.fill")
                    Text("tab.library".localized)
                        .font(.caption2)
                }
                .foregroundStyle(theme.accentColor)
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "gearshape")
                    Text("tab.settings".localized)
                        .font(.caption2)
                }
                .foregroundStyle(theme.isDarkTheme ? .gray : .secondary)
                Spacer()
            }
            .padding(.vertical, 8)
            .background(theme.listBackgroundColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? theme.accentColor : Color.clear, lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .padding()
    }
}

#Preview {
    NavigationStack {
        ThemeSettingsView()
    }
}
