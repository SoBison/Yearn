//
//  SettingsView.swift
//  Yearn
//
//  Settings view
//

import SwiftUI

// MARK: - Settings Navigation Destination

/// 设置页面的导航目的地
enum SettingsDestination: Hashable {
    case bios
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("autoSave") private var autoSave = true
    @AppStorage("autoSaveInterval") private var autoSaveInterval = 60
    @AppStorage("showFPS") private var showFPS = false
    @AppStorage("keepScreenAwake") private var keepScreenAwake = true
    @AppStorage("controllerOpacity") private var controllerOpacity = 0.7
    @AppStorage("selectedFilter") private var selectedFilter = "nearest"
    @AppStorage("iCloudSync") private var iCloudSync = true
    @AppStorage("gameScreenScale") private var gameScreenScale = 1.0
    
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var showingClearDataAlert = false
    @State private var storageInfo: StorageInfo?
    @State private var refreshID = UUID()
    
    /// 导航路径，用于程序化导航
    @State private var navigationPath = NavigationPath()
    
    private var currentLanguageDisplayName: String {
        if localizationManager.currentLanguage.isEmpty {
            return "settings.general.language.system".localized
        }
        return SupportedLanguage(rawValue: localizationManager.currentLanguage)?.displayName ?? "settings.general.language.system".localized
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                // Appearance Section
                Section("settings.appearance".localized) {
                    NavigationLink {
                        ThemeSettingsView()
                    } label: {
                        HStack {
                            Label("theme.title".localized, systemImage: "paintpalette.fill")
                            Spacer()
                            Text(themeManager.currentTheme.localizedName)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    NavigationLink {
                        LanguageSettingsView()
                    } label: {
                        HStack {
                            Label("settings.general.language".localized, systemImage: "globe")
                            Spacer()
                            Text(currentLanguageDisplayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // General Section
                Section {
                    Toggle("settings.general.haptics".localized, isOn: $hapticFeedback)
                    Toggle("settings.general.keepAwake".localized, isOn: $keepScreenAwake)
                    Toggle("settings.general.showFPS".localized, isOn: $showFPS)
                } header: {
                    Text("settings.general".localized)
                } footer: {
                    Text("settings.general.haptics.desc".localized)
                }
                
                // Save Section
                Section {
                    Toggle("settings.saves.autoSave".localized, isOn: $autoSave)
                    
                    if autoSave {
                        Picker("settings.saves.autoSave.interval".localized, selection: $autoSaveInterval) {
                            Text("settings.saves.autoSave.interval.30sec".localized).tag(30)
                            Text("settings.saves.autoSave.interval.1min".localized).tag(60)
                            Text("settings.saves.autoSave.interval.2min".localized).tag(120)
                            Text("settings.saves.autoSave.interval.5min".localized).tag(300)
                        }
                    }
                    
                    Toggle("settings.saves.icloud".localized, isOn: $iCloudSync)
                } header: {
                    Text("settings.saves".localized)
                } footer: {
                    Text("settings.saves.desc".localized)
                }
                
                // Display Section
                Section("settings.display".localized) {
                    Picker("settings.display.filter".localized, selection: $selectedFilter) {
                        Text("settings.display.filter.none".localized).tag("nearest")
                        Text("settings.display.filter.smooth".localized).tag("bilinear")
                        Text("settings.display.filter.crt".localized).tag("crt")
                        Text("settings.display.filter.lcd".localized).tag("lcd")
                    }
                    
                    VStack(alignment: .leading) {
                        Text("settings.controls.opacity".localized + ": \(Int(controllerOpacity * 100))%")
                        Slider(value: $controllerOpacity, in: 0.3...1.0, step: 0.1)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("settings.display.gameScale".localized + ": \(Int(gameScreenScale * 100))%")
                        Slider(value: $gameScreenScale, in: 0.8...1.5, step: 0.05)
                    }
                }
                
                // Controllers Section
                Section("settings.controls".localized) {
                    NavigationLink {
                        ControllerSettingsView()
                    } label: {
                        Label("settings.controls.mapping".localized, systemImage: "gamecontroller")
                    }
                    
                    NavigationLink {
                        ControllerSkinsView()
                    } label: {
                        Label("settings.controls.skin".localized, systemImage: "paintbrush")
                    }
                    
                    NavigationLink {
                        ExternalControllerView()
                    } label: {
                        Label("settings.controls.connected".localized, systemImage: "dot.radiowaves.left.and.right")
                    }
                    
                    NavigationLink {
                        ExternalDisplaySettingsView()
                    } label: {
                        HStack {
                            Label("display.title".localized, systemImage: "tv")
                            Spacer()
                            if ExternalDisplayManager.shared.isExternalDisplayConnected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                // Statistics Section
                Section("stats.title".localized) {
                    NavigationLink {
                        StatisticsView(viewModel: LibraryViewModel())
                    } label: {
                        Label("stats.title".localized, systemImage: "chart.bar.fill")
                    }
                }
                
                // Cores Section
                Section("settings.cores".localized) {
                    NavigationLink {
                        CoresListView()
                    } label: {
                        Label("settings.cores.manage".localized, systemImage: "cpu")
                    }
                    
                    ForEach(GameSystem.allCases) { system in
                        NavigationLink {
                            CoreSettingsView(system: system)
                        } label: {
                            HStack {
                                Image(systemName: system.iconName)
                                    .foregroundStyle(system.color)
                                    .frame(width: 24)
                                Text(system.localizedName)
                            }
                        }
                    }
                }
                
                // BIOS Section
                Section("settings.bios".localized) {
                    NavigationLink(value: SettingsDestination.bios) {
                        HStack {
                            Label("settings.bios.manage".localized, systemImage: "memorychip")
                            Spacer()
                            if BIOSManager.shared.isPS1BIOSAvailable {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            } else {
                                Text("settings.bios.ps1.missing".localized)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                
                // Storage Section
                Section {
                    if let info = storageInfo {
                        HStack {
                            Text("settings.storage.roms".localized)
                            Spacer()
                            Text(info.romsSize)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("settings.storage.saves".localized)
                            Spacer()
                            Text(info.saveStatesSize)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("settings.storage.battery".localized)
                            Spacer()
                            Text(info.batterySavesSize)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("settings.storage.total".localized)
                            Spacer()
                            Text(info.totalSize)
                                .foregroundStyle(.secondary)
                                .fontWeight(.medium)
                        }
                    } else {
                        HStack {
                            Text("common.loading".localized)
                            Spacer()
                            ProgressView()
                        }
                    }
                    
                    Button(role: .destructive) {
                        showingClearDataAlert = true
                    } label: {
                        Text("settings.storage.clearAll".localized)
                    }
                } header: {
                    Text("settings.storage".localized)
                }
                
                // About Section
                Section("settings.about".localized) {
                    HStack {
                        Text("settings.about.version".localized)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("settings.about.build".localized)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundStyle(.secondary)
                    }
                    
                    NavigationLink {
                        LicensesView()
                    } label: {
                        Text("settings.about.licenses".localized)
                    }
                }
            }
            .id(refreshID)
            .navigationTitle("settings.title".localized)
            .themedListBackground()
            .navigationDestination(for: SettingsDestination.self) { destination in
                switch destination {
                case .bios:
                    BIOSSettingsView()
                }
            }
            .task {
                await calculateStorageInfo()
            }
            .alert("settings.storage.clearAll".localized, isPresented: $showingClearDataAlert) {
                Button("common.cancel".localized, role: .cancel) {}
                Button("common.delete".localized, role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("settings.storage.clearAll.confirm".localized)
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                refreshID = UUID()
            }
            // 监听 appState 的导航请求
            .onChange(of: appState.shouldNavigateToBIOSSettings) { _, shouldNavigate in
                if shouldNavigate {
                    navigationPath.append(SettingsDestination.bios)
                    // 重置标志
                    appState.shouldNavigateToBIOSSettings = false
                }
            }
        }
    }
    
    private func calculateStorageInfo() async {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let romsSize = directorySize(at: documentsURL.appendingPathComponent("ROMs"))
        let saveStatesSize = directorySize(at: documentsURL.appendingPathComponent("SaveStates"))
        let batterySavesSize = directorySize(at: documentsURL.appendingPathComponent("Saves"))
        
        await MainActor.run {
            storageInfo = StorageInfo(
                romsSize: formatBytes(romsSize),
                saveStatesSize: formatBytes(saveStatesSize),
                batterySavesSize: formatBytes(batterySavesSize),
                totalSize: formatBytes(romsSize + saveStatesSize + batterySavesSize)
            )
        }
    }
    
    private func directorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
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
    
    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    private func clearAllData() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        try? fileManager.removeItem(at: documentsURL.appendingPathComponent("ROMs"))
        try? fileManager.removeItem(at: documentsURL.appendingPathComponent("SaveStates"))
        try? fileManager.removeItem(at: documentsURL.appendingPathComponent("Saves"))
        try? fileManager.removeItem(at: documentsURL.appendingPathComponent("Cores"))
        
        // Reset storage info
        Task {
            await calculateStorageInfo()
        }
    }
}

// MARK: - Storage Info

struct StorageInfo {
    let romsSize: String
    let saveStatesSize: String
    let batterySavesSize: String
    let totalSize: String
}

// MARK: - Controller Skins View

struct ControllerSkinsView: View {
    @ObservedObject private var skinManager = ControllerSkinManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    // Map skin names to localization keys
    private func localizedName(for skin: ControllerSkin) -> String {
        switch skin.name {
        case "Default": return "skin.default".localized
        case "Minimal": return "skin.minimal".localized
        case "Retro": return "skin.retro".localized
        case "Neon": return "skin.neon".localized
        case "Classic Nintendo": return "skin.classicNintendo".localized
        case "PlayStation": return "skin.playStation".localized
        case "Xbox": return "skin.xbox".localized
        case "Transparent": return "skin.transparent".localized
        case "Dark Mode": return "skin.darkMode".localized
        default: return skin.name
        }
    }
    
    var body: some View {
        List {
            // Standard skins
            Section("skin.category.standard".localized) {
                ForEach([ControllerSkin.default, .minimal, .retro]) { skin in
                    skinRow(for: skin)
                }
            }
            
            // Themed skins
            Section("skin.category.themed".localized) {
                ForEach([ControllerSkin.neon, .classicNintendo, .playStation, .xbox]) { skin in
                    skinRow(for: skin)
                }
            }
            
            // Special skins
            Section("skin.category.special".localized) {
                ForEach([ControllerSkin.transparent, .darkMode]) { skin in
                    skinRow(for: skin)
                }
            }
            
            // Custom skins
            let customSkins = skinManager.availableSkins.filter { skin in
                !ControllerSkin.allBuiltIn.contains(where: { $0.name == skin.name })
            }
            
            if !customSkins.isEmpty {
                Section("skin.category.custom".localized) {
                    ForEach(customSkins) { skin in
                        skinRow(for: skin, isCustom: true)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            try? skinManager.deleteSkin(customSkins[index])
                        }
                    }
                }
            }
        }
        .themedListBackground()
        .navigationTitle("settings.controls.skin".localized)
    }
    
    @ViewBuilder
    private func skinRow(for skin: ControllerSkin, isCustom: Bool = false) -> some View {
        HStack {
            // Skin preview
            SkinPreviewView(skin: skin)
                .frame(width: 60, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading) {
                Text(localizedName(for: skin))
                    .font(.headline)
                Text(isCustom ? "skin.custom".localized : "skin.builtin".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if skinManager.currentSkin.name == skin.name {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            skinManager.setCurrentSkin(skin)
            HapticManager.shared.selectionChanged()
        }
    }
}

// MARK: - External Controller View

struct ExternalControllerView: View {
    @State private var connectedControllers: [String] = []
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        List {
            if connectedControllers.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "gamecontroller")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("settings.controls.noControllers".localized)
                            .font(.headline)
                        Text("settings.controls.noControllers.desc".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                Section("settings.controls.connected".localized) {
                    ForEach(connectedControllers, id: \.self) { controller in
                        HStack {
                            Image(systemName: "gamecontroller.fill")
                                .foregroundStyle(.green)
                            Text(controller)
                        }
                    }
                }
            }
            
            Section {
                Text("settings.controls.supported".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .themedListBackground()
        .navigationTitle("settings.controls.connected".localized)
        .onAppear {
            checkConnectedControllers()
        }
    }
    
    private func checkConnectedControllers() {
        connectedControllers = []
    }
}

// MARK: - Cores List View

struct CoresListView: View {
    @State private var cores: [CoreDisplayInfo] = []
    @State private var isLoading = true
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        List {
            if isLoading {
                HStack {
                    ProgressView()
                    Text("settings.cores.scanning".localized)
                        .foregroundStyle(.secondary)
                }
            } else if cores.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "cpu")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("settings.cores.notFound".localized)
                            .font(.headline)
                        Text("settings.cores.notFound.desc".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                ForEach(cores) { core in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(core.name)
                                .font(.headline)
                            Text(core.system)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: core.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(core.isValid ? .green : .orange)
                    }
                }
            }
        }
        .themedListBackground()
        .navigationTitle("settings.cores".localized)
        .task {
            await loadCores()
        }
    }
    
    private func loadCores() async {
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            cores = [
                CoreDisplayInfo(name: "FCEUmm", system: "NES", isValid: true),
                CoreDisplayInfo(name: "Snes9x", system: "SNES", isValid: true),
                CoreDisplayInfo(name: "Gambatte", system: "GB/GBC", isValid: true),
                CoreDisplayInfo(name: "mGBA", system: "GBA", isValid: true),
                CoreDisplayInfo(name: "Mupen64Plus", system: "N64", isValid: true),
                CoreDisplayInfo(name: "melonDS", system: "NDS", isValid: true),
                CoreDisplayInfo(name: "Genesis Plus GX", system: "Genesis", isValid: true),
                CoreDisplayInfo(name: "PCSX ReARMed", system: "PS1", isValid: true),
            ]
            isLoading = false
        }
    }
}

struct CoreDisplayInfo: Identifiable {
    let id = UUID()
    let name: String
    let system: String
    let isValid: Bool
}

// MARK: - Core Settings View

struct CoreSettingsView: View {
    let system: GameSystem
    
    @AppStorage("frameSkip") private var frameSkip = 0
    @AppStorage("audioLatency") private var audioLatency = 64
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        List {
            Section("settings.cores.info".localized) {
                HStack {
                    Text("settings.cores.core".localized)
                    Spacer()
                    Text(coreNameForSystem(system))
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("settings.cores.status".localized)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("settings.cores.ready".localized)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("settings.cores.performance".localized) {
                Stepper("settings.cores.frameSkip".localized + ": \(frameSkip)", value: $frameSkip, in: 0...4)
                
                Picker("settings.cores.audioLatency".localized, selection: $audioLatency) {
                    Text("settings.cores.audioLatency.low".localized).tag(32)
                    Text("settings.cores.audioLatency.medium".localized).tag(64)
                    Text("settings.cores.audioLatency.high".localized).tag(128)
                }
            }
            
            Section("settings.cores.systemSpecific".localized) {
                switch system {
                case .gbc:
                    NavigationLink("settings.cores.gbc.palette".localized) {
                        GBCPaletteView()
                    }
                case .nds:
                    NavigationLink("settings.cores.nds.layout".localized) {
                        NDSScreenLayoutView()
                    }
                default:
                    Text("settings.cores.noAdditional".localized)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .themedListBackground()
        .navigationTitle(system.localizedName)
    }
    
    private func coreNameForSystem(_ system: GameSystem) -> String {
        switch system {
        case .nes: return "FCEUmm"
        case .snes: return "Snes9x"
        case .gbc: return "Gambatte"
        case .gba: return "mGBA"
        case .n64: return "Mupen64Plus"
        case .nds: return "melonDS"
        case .genesis: return "Genesis Plus GX"
        case .ps1: return "PCSX ReARMed"
        }
    }
}

// MARK: - GBC Palette View

struct GBCPaletteView: View {
    @AppStorage("gbcPalette") private var selectedPalette = "default"
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    let palettes = [
        ("default", "settings.cores.gbc.palette.default", Color.green),
        ("grayscale", "settings.cores.gbc.palette.grayscale", Color.gray),
        ("green", "settings.cores.gbc.palette.green", Color.green),
        ("brown", "settings.cores.gbc.palette.brown", Color.brown)
    ]
    
    var body: some View {
        List {
            ForEach(palettes, id: \.0) { palette in
                HStack {
                    Circle()
                        .fill(palette.2)
                        .frame(width: 24, height: 24)
                    
                    Text(palette.1.localized)
                    
                    Spacer()
                    
                    if selectedPalette == palette.0 {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedPalette = palette.0
                    HapticManager.shared.selectionChanged()
                }
            }
        }
        .themedListBackground()
        .navigationTitle("settings.cores.gbc.palette".localized)
    }
}

// MARK: - NDS Screen Layout View

struct NDSScreenLayoutView: View {
    @AppStorage("ndsLayout") private var selectedLayout = "vertical"
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        List {
            Section {
                LayoutOption(
                    title: "settings.cores.nds.layout.vertical".localized,
                    description: "settings.cores.nds.layout.vertical.desc".localized,
                    icon: "rectangle.split.1x2",
                    isSelected: selectedLayout == "vertical"
                ) {
                    selectedLayout = "vertical"
                }
                
                LayoutOption(
                    title: "settings.cores.nds.layout.horizontal".localized,
                    description: "settings.cores.nds.layout.horizontal.desc".localized,
                    icon: "rectangle.split.2x1",
                    isSelected: selectedLayout == "horizontal"
                ) {
                    selectedLayout = "horizontal"
                }
                
                LayoutOption(
                    title: "settings.cores.nds.layout.single".localized,
                    description: "settings.cores.nds.layout.single.desc".localized,
                    icon: "rectangle",
                    isSelected: selectedLayout == "single"
                ) {
                    selectedLayout = "single"
                }
            }
        }
        .themedListBackground()
        .navigationTitle("settings.cores.nds.layout".localized)
    }
}

struct LayoutOption: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 40)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            action()
            HapticManager.shared.selectionChanged()
        }
    }
}

// MARK: - Licenses View

struct LicensesView: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        List {
            // 开源项目列表
            Section {
                Text("settings.about.licenses.content".localized)
                    .font(.footnote)
            }
            
            // 源代码
            Section {
                Link(destination: URL(string: "https://github.com")!) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .foregroundStyle(.purple)
                        Text("settings.about.sourceCode".localized)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // BIOS 许可证
            Section("settings.about.licenses.bios".localized) {
                ForEach(BIOSManager.bundledBIOSLicenses, id: \.name) { license in
                    NavigationLink {
                        BIOSLicenseDetailView(license: license)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(license.name)
                                .font(.headline)
                            Text(license.license)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            // 致谢
            Section("settings.about.acknowledgements".localized) {
                VStack(alignment: .leading, spacing: 12) {
                    // 特别感谢
                    Text("settings.about.acknowledgements.thanks".localized)
                        .font(.headline)
                    
                    Text("settings.about.acknowledgements.libretro".localized)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    Text("settings.about.acknowledgements.cores".localized)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    Text("settings.about.acknowledgements.community".localized)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    // 贡献者
                    Text("settings.about.acknowledgements.contributors".localized)
                        .font(.headline)
                    
                    Text("settings.about.acknowledgements.contributors.desc".localized)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .themedListBackground()
        .navigationTitle("settings.about.licenses".localized)
    }
}

// MARK: - BIOS License Detail View

struct BIOSLicenseDetailView: View {
    let license: BIOSManager.BIOSLicense
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题
                Text(license.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                // 作者和许可证类型
                VStack(alignment: .leading, spacing: 8) {
                    Label(license.author, systemImage: "person.fill")
                    Label(license.license, systemImage: "doc.text.fill")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                
                Divider()
                
                // 完整许可证文本
                Text(license.fullText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding()
        }
        .navigationTitle(license.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Acknowledgements View

struct AcknowledgementsView: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        List {
            Section("settings.about.acknowledgements.thanks".localized) {
                Text("settings.about.acknowledgements.libretro".localized)
                Text("settings.about.acknowledgements.cores".localized)
                Text("settings.about.acknowledgements.community".localized)
            }
            
            Section("settings.about.acknowledgements.contributors".localized) {
                Text("settings.about.acknowledgements.contributors.desc".localized)
            }
        }
        .themedListBackground()
        .navigationTitle("settings.about.acknowledgements".localized)
    }
}

// MARK: - Game System Extensions

extension GameSystem {
    var hasXYButtons: Bool {
        switch self {
        case .snes, .nds, .ps1:
            return true
        default:
            return false
        }
    }
    
    var hasShoulderButtons: Bool {
        switch self {
        case .snes, .gba, .nds, .ps1, .n64:
            return true
        default:
            return false
        }
    }
    
    var localizedName: String {
        switch self {
        case .nes: return "system.nes".localized
        case .snes: return "system.snes".localized
        case .gbc: return "system.gbc".localized
        case .gba: return "system.gba".localized
        case .n64: return "system.n64".localized
        case .nds: return "system.nds".localized
        case .genesis: return "system.genesis".localized
        case .ps1: return "system.ps1".localized
        }
    }
}

// MARK: - BIOS Settings View

struct BIOSSettingsView: View {
    @ObservedObject private var biosManager = BIOSManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var showingImportPicker = false
    @State private var showingImportAlert = false
    @State private var importAlertMessage = ""
    @State private var importAlertIsError = false
    @State private var refreshID = UUID()
    
    var body: some View {
        List {
            // PS1 BIOS Section
            Section {
                ForEach(biosManager.getPS1BIOSStatus()) { bios in
                    PS1BIOSRow(bios: bios)
                }
            } header: {
                Text("bios.ps1.title".localized)
            } footer: {
                Text("bios.ps1.footer".localized)
            }
            
            // NDS BIOS Section
            Section {
                let ndsFiles = biosManager.installedFiles.filter { $0.system == "NDS" }
                if ndsFiles.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("bios.nds.builtin".localized)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(ndsFiles) { bios in
                        BIOSFileRow(bios: bios)
                    }
                }
            } header: {
                Text("bios.nds.title".localized)
            } footer: {
                Text("bios.nds.footer".localized)
            }
            
            // Import Section
            Section {
                Button {
                    showingImportPicker = true
                } label: {
                    Label("bios.import".localized, systemImage: "square.and.arrow.down")
                }
                
                // BIOS 目录路径
                VStack(alignment: .leading, spacing: 4) {
                    Text("bios.directory".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(biosManager.biosDirectory.path)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            } header: {
                Text("bios.import.section".localized)
            } footer: {
                Text("bios.import.footer".localized)
            }
            
            // Help Section
            Section {
                DisclosureGroup("bios.help.whatIs".localized) {
                    Text("bios.help.whatIs.content".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                DisclosureGroup("bios.help.whereToGet".localized) {
                    Text("bios.help.whereToGet.content".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                DisclosureGroup("bios.help.fileNames".localized) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("bios.help.fileNames.ps1".localized)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("• scph5500.bin (\("bios.region.japan".localized))")
                            .font(.caption2)
                        Text("• scph5501.bin (\("bios.region.usa".localized))")
                            .font(.caption2)
                        Text("• scph5502.bin (\("bios.region.europe".localized))")
                            .font(.caption2)
                        Text("• scph1001.bin (\("bios.region.usa.old".localized))")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text("bios.help.title".localized)
            }
        }
        .id(refreshID)
        .themedListBackground()
        .navigationTitle("settings.bios".localized)
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: true
        ) { result in
            handleImportResult(result)
        }
        .alert(importAlertIsError ? "common.error".localized : "common.success".localized, 
               isPresented: $showingImportAlert) {
            Button("common.ok".localized, role: .cancel) {}
        } message: {
            Text(importAlertMessage)
        }
        .onAppear {
            biosManager.refreshBIOSStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            refreshID = UUID()
        }
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var importedCount = 0
            var failedFiles: [String] = []
            
            for url in urls {
                let importResult = biosManager.importBIOSFile(from: url)
                switch importResult {
                case .success:
                    importedCount += 1
                case .failure(let error):
                    failedFiles.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            
            if importedCount > 0 && failedFiles.isEmpty {
                importAlertMessage = String(format: "bios.import.success".localized, importedCount)
                importAlertIsError = false
            } else if importedCount > 0 {
                importAlertMessage = String(format: "bios.import.partial".localized, importedCount, failedFiles.joined(separator: "\n"))
                importAlertIsError = false
            } else {
                importAlertMessage = failedFiles.joined(separator: "\n")
                importAlertIsError = true
            }
            showingImportAlert = true
            
        case .failure(let error):
            importAlertMessage = error.localizedDescription
            importAlertIsError = true
            showingImportAlert = true
        }
    }
}

// MARK: - PS1 BIOS Row

struct PS1BIOSRow: View {
    let bios: BIOSFileInfo
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(bios.name)
                    .font(.headline)
                Text(bios.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if bios.isInstalled {
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(bios.formattedSize)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - BIOS File Row

struct BIOSFileRow: View {
    let bios: BIOSFileInfo
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(bios.name)
                    .font(.headline)
                Text(bios.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(bios.formattedSize)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
