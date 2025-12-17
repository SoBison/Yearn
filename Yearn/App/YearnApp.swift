//
//  YearnApp.swift
//  Yearn
//
//  A retro game emulator powered by libretro
//

import SwiftUI
import CoreSpotlight
import YearnCore

@main
struct YearnApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Register static cores at app startup
        #if STATIC_CORES_ENABLED
        registerAllStaticCores()
        print("✅ Static cores registered")
        #else
        print("ℹ️ Using dynamic cores (STATIC_CORES_ENABLED not defined)")
        #endif
        
        // Setup BIOS files (copy bundled FreeBIOS to Documents/BIOS)
        BIOSManager.shared.setupBIOS()
    }
    
    var body: some Scene {
        WindowGroup {
            OnboardingWrapper {
                ContentView()
            }
            .themed()
            .environmentObject(appState)
            .onOpenURL { url in
                handleOpenURL(url)
            }
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                handleSpotlightActivity(activity)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .commands {
            EmulationKeyboardCommands()
        }
    }
    
    private func handleOpenURL(_ url: URL) {
        // Handle file URLs (ROM imports from other apps)
        print("📂 handleOpenURL called with: \(url)")
        print("📂 URL scheme: \(url.scheme ?? "none")")
        print("📂 Is file URL: \(url.isFileURL)")
        
        if url.isFileURL {
            // 发送通知让 LibraryView 处理导入
            NotificationCenter.default.post(
                name: .importGameFromURL,
                object: nil,
                userInfo: ["url": url]
            )
        }
    }
    
    private func handleSpotlightActivity(_ activity: NSUserActivity) {
        // Handle Spotlight search result tap
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let uuid = UUID(uuidString: identifier) else {
            return
        }
        
        // Find and launch the game
        let viewModel = LibraryViewModel()
        if let game = viewModel.games.first(where: { $0.id == uuid }) {
            appState.currentGame = game
            appState.isEmulating = true
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // App became active
            break
        case .inactive:
            // App became inactive - auto-save if emulating
            if appState.isEmulating {
                // Trigger auto-save
            }
        case .background:
            // App went to background
            break
        @unknown default:
            break
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Setup Quick Actions
        setupQuickActions()
        
        // 检查启动时是否有通过其他应用打开的文件
        if let launchOptions = launchOptions,
           let url = launchOptions[.url] as? URL {
            print("📂 App launched with URL: \(url)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(
                    name: .importGameFromURL,
                    object: nil,
                    userInfo: ["url": url]
                )
            }
        }
        
        return true
    }
    
    // 处理通过"用...打开"从其他应用传入的文件（iOS 13 以下或某些特殊情况）
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        print("📂 AppDelegate.open URL: \(url)")
        print("📂 Options: \(options)")
        
        // 发送通知让 LibraryView 处理导入
        NotificationCenter.default.post(
            name: .importGameFromURL,
            object: nil,
            userInfo: ["url": url]
        )
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
    
    private func setupQuickActions() {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: "com.yearn.quickaction.recent",
                localizedTitle: "Continue Playing",
                localizedSubtitle: "Resume your last game",
                icon: UIApplicationShortcutIcon(systemImageName: "play.circle.fill"),
                userInfo: nil
            ),
            UIApplicationShortcutItem(
                type: "com.yearn.quickaction.import",
                localizedTitle: "Import Game",
                localizedSubtitle: "Add a new ROM file",
                icon: UIApplicationShortcutIcon(systemImageName: "plus.circle.fill"),
                userInfo: nil
            )
        ]
    }
}

// MARK: - Scene Delegate

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // 处理通过"用...打开"在场景连接时传入的 URL
        if let urlContext = connectionOptions.urlContexts.first {
            let url = urlContext.url
            print("📂 Scene willConnectTo with URL: \(url)")
            
            // 延迟发送通知，确保 UI 已经准备好
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(
                    name: .importGameFromURL,
                    object: nil,
                    userInfo: ["url": url]
                )
            }
        }
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // 处理应用运行时通过"用...打开"传入的 URL
        guard let urlContext = URLContexts.first else { return }
        let url = urlContext.url
        
        print("📂 Scene openURLContexts: \(url)")
        
        NotificationCenter.default.post(
            name: .importGameFromURL,
            object: nil,
            userInfo: ["url": url]
        )
    }
    
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        handleQuickAction(shortcutItem)
        completionHandler(true)
    }
    
    private func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) {
        switch shortcutItem.type {
        case "com.yearn.quickaction.recent":
            // Launch most recent game
            NotificationCenter.default.post(name: .launchRecentGame, object: nil)
        case "com.yearn.quickaction.import":
            // Show import dialog
            NotificationCenter.default.post(name: .showImportDialog, object: nil)
        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let launchRecentGame = Notification.Name("launchRecentGame")
    static let showImportDialog = Notification.Name("showImportDialog")
    static let importGameFromURL = Notification.Name("importGameFromURL")
    static let gameImportCompleted = Notification.Name("gameImportCompleted")
}

/// Global application state
@MainActor
class AppState: ObservableObject {
    @Published var selectedTab: Tab = .library
    @Published var isEmulating: Bool = false
    @Published var currentGame: Game?
    @Published var showingImporter: Bool = false
    
    /// 是否需要导航到 BIOS 设置页面
    @Published var shouldNavigateToBIOSSettings: Bool = false
    
    enum Tab: Hashable {
        case library
        case settings
    }
    
    init() {
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .launchRecentGame,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.launchRecentGame()
        }
        
        NotificationCenter.default.addObserver(
            forName: .showImportDialog,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showingImporter = true
        }
        
        // 监听打开 BIOS 设置的通知
        NotificationCenter.default.addObserver(
            forName: .openBIOSSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.navigateToBIOSSettings()
        }
    }
    
    private func launchRecentGame() {
        let viewModel = LibraryViewModel()
        if let recentGame = viewModel.recentGames.first {
            currentGame = recentGame
            isEmulating = true
        }
    }
    
    /// 导航到 BIOS 设置页面
    func navigateToBIOSSettings() {
        // 先切换到设置 Tab
        selectedTab = .settings
        // 延迟一小段时间后触发导航，确保 Tab 切换完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.shouldNavigateToBIOSSettings = true
        }
    }
}

