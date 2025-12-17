//
//  LibraryView.swift
//  Yearn
//
//  Game library view
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

// MARK: - Document Picker 适配器
// 使用 UIKit 的 UIDocumentPickerViewController 来确保文件选择器能正确显示

/// 文件选择器 UIViewControllerRepresentable 适配器
/// 解决 SwiftUI fileImporter 在某些情况下不显示的问题
struct DocumentPickerView: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onPicked: ([URL]) -> Void
    let onCancelled: () -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.delegate = context.coordinator
        print("📂 DocumentPickerView: Created UIDocumentPickerViewController")
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked, onCancelled: onCancelled)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: ([URL]) -> Void
        let onCancelled: () -> Void
        
        init(onPicked: @escaping ([URL]) -> Void, onCancelled: @escaping () -> Void) {
            self.onPicked = onPicked
            self.onCancelled = onCancelled
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            print("📂 DocumentPicker: Selected \(urls.count) file(s)")
            for url in urls {
                print("📂 - \(url.lastPathComponent)")
            }
            onPicked(urls)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("📂 DocumentPicker: Cancelled")
            onCancelled()
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = LibraryViewModel()
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @ObservedObject private var biosManager = BIOSManager.shared
    
    @State private var searchText = ""
    @State private var showingImporter = false
    @State private var showingFolderPicker = false
    @State private var selectedSystem: GameSystem?
    @State private var sortOrder: SortOrder = .name
    @State private var viewMode: ViewMode = .grid
    @State private var showingDeleteAlert = false
    @State private var gameToDelete: Game?
    @State private var showingGameInfo: Game?
    @State private var refreshID = UUID()
    
    // BIOS 缺失提示相关状态
    @State private var showingBIOSAlert = false
    @State private var pendingGame: Game?
    
    // 帮助界面状态
    @State private var showingImportHelp = false
    
    enum ViewMode: String, CaseIterable {
        case grid
        case list
        
        var localizedName: String {
            switch self {
            case .grid: return "library.viewMode.grid".localized
            case .list: return "library.viewMode.list".localized
            }
        }
        
        var icon: String {
            switch self {
            case .grid: return "square.grid.2x2"
            case .list: return "list.bullet"
            }
        }
    }
    
    enum SortOrder: String, CaseIterable {
        case name
        case system
        case recent
        
        var localizedName: String {
            switch self {
            case .name: return "library.sort.name".localized
            case .system: return "library.sort.system".localized
            case .recent: return "library.sort.date".localized
            }
        }
        
        var icon: String {
            switch self {
            case .name: return "textformat"
            case .system: return "gamecontroller"
            case .recent: return "clock"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.games.isEmpty && !viewModel.isLoading {
                    EmptyLibraryView(
                        showingImporter: $showingImporter,
                        showingFolderPicker: $showingFolderPicker,
                        showingImportHelp: $showingImportHelp
                    )
                } else {
                    libraryContent
                }
            }
            .id(refreshID)
            .navigationTitle("library.title".localized)
            .themedListBackground()
            .searchable(text: $searchText, prompt: "library.search.placeholder".localized)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // View mode toggle
                    Menu {
                        Picker("library.viewMode".localized, selection: $viewMode) {
                            ForEach(ViewMode.allCases, id: \.self) { mode in
                                Label(mode.localizedName, systemImage: mode.icon)
                            }
                        }
                    } label: {
                        Image(systemName: viewMode.icon)
                    }
                    
                    // Sort menu
                    Menu {
                        Picker("library.sortBy".localized, selection: $sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Label(order.localizedName, systemImage: order.icon)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    
                    // Add games menu
                    Menu {
                        Button {
                            showingImporter = true
                        } label: {
                            Label("library.import".localized, systemImage: "doc.badge.plus")
                        }
                        
                        Button {
                            showingFolderPicker = true
                        } label: {
                            Label("library.import.folder".localized, systemImage: "folder.badge.plus")
                        }
                        
                        Divider()
                        
                        Button {
                            showingImportHelp = true
                        } label: {
                            Label("import.help.button".localized, systemImage: "questionmark.circle")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                // System filter
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            selectedSystem = nil
                        } label: {
                            Label("library.filter.all".localized, systemImage: "square.grid.2x2")
                        }
                        
                        Divider()
                        
                        ForEach(GameSystem.allCases, id: \.self) { system in
                            let count = viewModel.games.filter { $0.system == system }.count
                            if count > 0 {
                                Button {
                                    selectedSystem = system
                                } label: {
                                    Label("\(system.localizedName) (\(count))", systemImage: system.iconName)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: selectedSystem?.iconName ?? "square.grid.2x2")
                            Text(selectedSystem?.localizedName ?? "library.filter.all".localized)
                                .font(.subheadline)
                        }
                    }
                }
            }
            // 使用 sheet 配合 UIKit DocumentPicker 来确保文件选择器能正确显示
            .sheet(isPresented: $showingImporter) {
                DocumentPickerView(
                    contentTypes: romContentTypes,
                    allowsMultipleSelection: true,
                    onPicked: { urls in
                        showingImporter = false
                        handleImportURLs(urls)
                    },
                    onCancelled: {
                        showingImporter = false
                    }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showingFolderPicker) {
                DocumentPickerView(
                    contentTypes: [.folder],
                    allowsMultipleSelection: false,
                    onPicked: { urls in
                        showingFolderPicker = false
                        if let folderURL = urls.first {
                            handleFolderImportURL(folderURL)
                        }
                    },
                    onCancelled: {
                        showingFolderPicker = false
                    }
                )
                .ignoresSafeArea()
            }
            .onChange(of: showingImporter) { oldValue, newValue in
                print("📂 showingImporter changed: \(oldValue) -> \(newValue)")
            }
            .onChange(of: showingFolderPicker) { oldValue, newValue in
                print("📂 showingFolderPicker changed: \(oldValue) -> \(newValue)")
            }
            .alert("library.game.delete".localized, isPresented: $showingDeleteAlert) {
                Button("common.cancel".localized, role: .cancel) {}
                Button("common.delete".localized, role: .destructive) {
                    if let game = gameToDelete {
                        viewModel.deleteGame(game)
                    }
                }
            } message: {
                if let game = gameToDelete {
                    Text("library.game.delete.confirm".localized(game.name))
                }
            }
            .sheet(item: $showingGameInfo) { game in
                GameInfoSheet(game: game)
            }
            .sheet(isPresented: $showingImportHelp) {
                ImportHelpView()
            }
            .refreshable {
                viewModel.loadGames()
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                refreshID = UUID()
            }
            // 监听从其他应用导入游戏的通知
            .onReceive(NotificationCenter.default.publisher(for: .importGameFromURL)) { notification in
                if let url = notification.userInfo?["url"] as? URL {
                    handleExternalImport(url)
                }
            }
            // 监听游戏导入完成的通知
            .onReceive(NotificationCenter.default.publisher(for: .gameImportCompleted)) { _ in
                refreshID = UUID()
                viewModel.loadGames()
            }
            // BIOS 缺失提示弹窗
            .alert("bios.alert.title".localized, isPresented: $showingBIOSAlert) {
                Button("bios.alert.goToSettings".localized) {
                    // 打开设置页面的 BIOS 管理
                    NotificationCenter.default.post(name: .openBIOSSettings, object: nil)
                    pendingGame = nil
                }
                Button("common.cancel".localized, role: .cancel) {
                    pendingGame = nil
                }
            } message: {
                if let game = pendingGame {
                    Text("bios.alert.message.\(game.system.rawValue)".localized)
                }
            }
        }
    }
    
    @ViewBuilder
    private var libraryContent: some View {
        if viewModel.isLoading {
            ProgressView("common.loading".localized)
        } else {
            switch viewMode {
            case .grid:
                GameGridView(
                    games: filteredAndSortedGames,
                    onGameSelected: { game in
                        launchGame(game)
                    },
                    onGameLongPress: { game in
                        showingGameInfo = game
                    },
                    onDeleteGame: { game in
                        gameToDelete = game
                        showingDeleteAlert = true
                    }
                )
            case .list:
                GameListView(
                    games: filteredAndSortedGames,
                    onGameSelected: { game in
                        launchGame(game)
                    },
                    onDeleteGame: { game in
                        gameToDelete = game
                        showingDeleteAlert = true
                    }
                )
            }
        }
    }
    
    private var filteredAndSortedGames: [Game] {
        var result = viewModel.games
        
        // Filter by system
        if let system = selectedSystem {
            result = result.filter { $0.system == system }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            result = result.filter { game in
                game.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort
        switch sortOrder {
        case .name:
            result.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .system:
            result.sort { ($0.system.rawValue, $0.name) < ($1.system.rawValue, $1.name) }
        case .recent:
            result.sort { ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast) }
        }
        
        return result
    }
    
    private var romContentTypes: [UTType] {
        // Use .data and .item to allow selecting any file type
        // This is more permissive and works better with iCloud Drive
        return [.data, .item]
    }
    
    /// 启动游戏前检查 BIOS 是否可用
    private func launchGame(_ game: Game) {
        // 检查是否需要 BIOS
        if game.system == .ps1 && !biosManager.checkPS1BIOSAvailable() {
            // PS1 需要 BIOS 但未找到
            pendingGame = game
            showingBIOSAlert = true
            return
        }
        
        // BIOS 检查通过，启动游戏
        appState.currentGame = game
        appState.isEmulating = true
    }
    
    /// 处理导入的文件 URL 列表
    private func handleImportURLs(_ urls: [URL]) {
        print("📂 handleImportURLs called with \(urls.count) URLs")
        for url in urls {
            print("📂 - URL: \(url.path)")
            print("📂 - Extension: \(url.pathExtension)")
        }
        Task {
            await viewModel.importGames(from: urls)
            // 强制刷新 UI
            await MainActor.run {
                refreshID = UUID()
                viewModel.loadGames()
                print("📂 UI refreshed after import, total games: \(viewModel.games.count)")
            }
        }
    }
    
    /// 处理导入的文件夹 URL
    private func handleFolderImportURL(_ folderURL: URL) {
        print("📂 handleFolderImportURL called with: \(folderURL.path)")
        print("📂 URL scheme: \(folderURL.scheme ?? "none")")
        print("📂 Is file URL: \(folderURL.isFileURL)")
        Task {
            await viewModel.importGamesFromFolder(folderURL)
            // 强制刷新 UI
            await MainActor.run {
                refreshID = UUID()
                viewModel.loadGames()
                print("📂 UI refreshed after folder import, total games: \(viewModel.games.count)")
            }
        }
    }
    
    /// 处理从其他应用导入的文件
    private func handleExternalImport(_ url: URL) {
        print("📂 handleExternalImport called with: \(url.path)")
        print("📂 URL scheme: \(url.scheme ?? "none")")
        print("📂 Is file URL: \(url.isFileURL)")
        print("📂 File exists: \(FileManager.default.fileExists(atPath: url.path))")
        
        Task {
            // 获取安全访问权限
            let accessing = url.startAccessingSecurityScopedResource()
            print("📂 Security scoped access: \(accessing)")
            
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("❌ File does not exist at path: \(url.path)")
                // 尝试从 Inbox 目录读取（某些应用会将文件复制到 Inbox）
                if let inboxURL = getInboxFileURL(for: url) {
                    print("📂 Found file in Inbox: \(inboxURL.path)")
                    await viewModel.importGame(from: inboxURL)
                } else {
                    print("❌ Could not find file in Inbox either")
                }
                return
            }
            
            await viewModel.importGame(from: url)
            
            // 强制刷新 UI
            await MainActor.run {
                refreshID = UUID()
                viewModel.loadGames()
                print("📂 UI refreshed after external import, total games: \(viewModel.games.count)")
                
                // 发送导入完成通知
                NotificationCenter.default.post(name: .gameImportCompleted, object: nil)
            }
        }
    }
    
    /// 获取 Inbox 中的文件 URL（其他应用通过"用...打开"会将文件复制到 Documents/Inbox）
    private func getInboxFileURL(for originalURL: URL) -> URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let inboxURL = documentsURL.appendingPathComponent("Inbox")
        let fileName = originalURL.lastPathComponent
        let inboxFileURL = inboxURL.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: inboxFileURL.path) {
            return inboxFileURL
        }
        
        // 尝试查找 Inbox 目录中的所有文件
        do {
            let inboxContents = try FileManager.default.contentsOfDirectory(at: inboxURL, includingPropertiesForKeys: nil)
            print("📂 Inbox contents: \(inboxContents.map { $0.lastPathComponent })")
            
            // 查找匹配的文件
            if let matchingFile = inboxContents.first(where: { $0.lastPathComponent == fileName }) {
                return matchingFile
            }
            
            // 如果只有一个文件，返回它
            if inboxContents.count == 1 {
                return inboxContents.first
            }
        } catch {
            print("❌ Failed to read Inbox directory: \(error)")
        }
        
        return nil
    }
}

// MARK: - Empty State View

struct EmptyLibraryView: View {
    @Binding var showingImporter: Bool
    @Binding var showingFolderPicker: Bool
    @Binding var showingImportHelp: Bool
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var refreshID = UUID()
    
    var body: some View {
        ContentUnavailableView {
            Label("library.empty.title".localized, systemImage: "gamecontroller")
        } description: {
            Text("library.empty.message".localized)
                .multilineTextAlignment(.center)
        } actions: {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Button {
                        print("📂 Import button tapped, setting showingImporter = true")
                        showingImporter = true
                        print("📂 showingImporter is now: \(showingImporter)")
                    } label: {
                        Label("library.import".localized, systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        print("📂 Folder button tapped, setting showingFolderPicker = true")
                        showingFolderPicker = true
                        print("📂 showingFolderPicker is now: \(showingFolderPicker)")
                    } label: {
                        Label("library.import.folder".localized, systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.bordered)
                }
                
                Button {
                    showingImportHelp = true
                } label: {
                    Label("import.help.button".localized, systemImage: "questionmark.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .id(refreshID)
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            refreshID = UUID()
        }
    }
}

// MARK: - Game Grid View

struct GameGridView: View {
    let games: [Game]
    let onGameSelected: (Game) -> Void
    let onGameLongPress: (Game) -> Void
    let onDeleteGame: (Game) -> Void
    
    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(games) { game in
                    GameCardView(game: game)
                        .onTapGesture {
                            onGameSelected(game)
                        }
                        .onLongPressGesture {
                            onGameLongPress(game)
                        }
                        .contextMenu {
                            Button {
                                onGameSelected(game)
                            } label: {
                                Label("library.game.play".localized, systemImage: "play.fill")
                            }
                            
                            Button {
                                onGameLongPress(game)
                            } label: {
                                Label("library.game.info".localized, systemImage: "info.circle")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                onDeleteGame(game)
                            } label: {
                                Label("common.delete".localized, systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
        }
    }
}

// MARK: - Game List View

struct GameListView: View {
    let games: [Game]
    let onGameSelected: (Game) -> Void
    let onDeleteGame: (Game) -> Void
    
    var body: some View {
        List {
            ForEach(games) { game in
                GameRowView(game: game)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onGameSelected(game)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onDeleteGame(game)
                        } label: {
                            Label("common.delete".localized, systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
    }
}

struct GameRowView: View {
    let game: Game
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: game.system.iconName)
                        .foregroundStyle(.secondary)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(game.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label(game.system.localizedName, systemImage: game.system.iconName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let size = game.fileSize {
                        Text(size)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Game Card View

struct GameCardView: View {
    let game: Game
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Artwork placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(game.system.color.opacity(0.15))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: game.system.iconName)
                            .font(.system(size: 32))
                            .foregroundStyle(game.system.color)
                        
                        Text(game.system.localizedName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(game.system.color.opacity(0.8))
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if game.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(6)
                    }
                }
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeOut(duration: 0.1), value: isPressed)
            
            VStack(spacing: 2) {
                Text(game.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Game Info Sheet

struct GameInfoSheet: View {
    let game: Game
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var refreshID = UUID()
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(game.system.color.opacity(0.15))
                            .frame(width: 80, height: 80)
                            .overlay {
                                Image(systemName: game.system.iconName)
                                    .font(.largeTitle)
                                    .foregroundStyle(game.system.color)
                            }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(game.name)
                                .font(.headline)
                            Text(game.system.localizedName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                
                Section("gameInfo.fileInfo".localized) {
                    LabeledContent("gameInfo.system".localized, value: game.system.localizedName)
                    LabeledContent("gameInfo.file".localized, value: game.fileURL.lastPathComponent)
                    if let size = game.fileSize {
                        LabeledContent("gameInfo.size".localized, value: size)
                    }
                    if let date = game.dateAdded {
                        LabeledContent("gameInfo.added".localized, value: date.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                
                Section("gameInfo.extensions".localized) {
                    Text(game.system.supportedExtensions.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .id(refreshID)
            .navigationTitle("library.game.info".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                refreshID = UUID()
            }
        }
    }
}

// MARK: - Import Help View

struct ImportHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var refreshID = UUID()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 头部图标和标题
                    VStack(spacing: 12) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        
                        Text("import.help.title".localized)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("import.help.subtitle".localized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                    
                    // 支持的平台
                    helpSection(
                        title: "import.help.systems.title".localized,
                        icon: "gamecontroller.fill",
                        color: .purple
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(GameSystem.allCases, id: \.self) { system in
                                HStack(spacing: 12) {
                                    Image(systemName: system.iconName)
                                        .foregroundStyle(system.color)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(system.displayName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(system.supportedExtensions.map { ".\($0)" }.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    // 导入方式
                    helpSection(
                        title: "import.help.methods.title".localized,
                        icon: "square.and.arrow.down.fill",
                        color: .green
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            importMethodRow(
                                icon: "doc.badge.plus",
                                title: "import.help.method.files".localized,
                                description: "import.help.method.files.desc".localized
                            )
                            
                            importMethodRow(
                                icon: "folder.badge.plus",
                                title: "import.help.method.folder".localized,
                                description: "import.help.method.folder.desc".localized
                            )
                            
                            importMethodRow(
                                icon: "icloud.and.arrow.down",
                                title: "import.help.method.icloud".localized,
                                description: "import.help.method.icloud.desc".localized
                            )
                            
                            importMethodRow(
                                icon: "airplayaudio",
                                title: "import.help.method.airdrop".localized,
                                description: "import.help.method.airdrop.desc".localized
                            )
                        }
                    }
                    
                    // 提示
                    helpSection(
                        title: "import.help.tips.title".localized,
                        icon: "lightbulb.fill",
                        color: .orange
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            tipRow("import.help.tip.1".localized)
                            tipRow("import.help.tip.2".localized)
                            tipRow("import.help.tip.3".localized)
                            tipRow("import.help.tip.4".localized)
                        }
                    }
                    
                    // PS1 BIOS 提示
                    helpSection(
                        title: "import.help.bios.title".localized,
                        icon: "cpu.fill",
                        color: .gray
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("import.help.bios.desc".localized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .id(refreshID)
            .navigationTitle("import.help.nav.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                refreshID = UUID()
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func helpSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
            }
            
            content()
                .padding(.leading, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func importMethodRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.orange)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(AppState())
}

#Preview("Import Help") {
    ImportHelpView()
}
