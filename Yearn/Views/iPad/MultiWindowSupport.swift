//
//  MultiWindowSupport.swift
//  Yearn
//
//  iPad multi-window and Stage Manager support
//

import SwiftUI
import UIKit

// MARK: - Multi-Window Manager

@MainActor
class MultiWindowManager: ObservableObject {
    static let shared = MultiWindowManager()
    
    @Published var activeWindows: [GameWindow] = []
    
    private init() {}
    
    // MARK: - Open New Window
    
    func openNewWindow(for game: Game) {
        let activity = NSUserActivity(activityType: "com.yearn.emulator.game")
        activity.title = game.name
        activity.userInfo = [
            "gameId": game.id.uuidString,
            "gameName": game.name,
            "gameSystem": game.system.rawValue,
            "fileURL": game.fileURL.absoluteString
        ]
        activity.isEligibleForHandoff = true
        
        UIApplication.shared.requestSceneSessionActivation(
            nil,
            userActivity: activity,
            options: nil,
            errorHandler: { error in
                print("Failed to open new window: \(error)")
            }
        )
    }
    
    // MARK: - Register Window
    
    func registerWindow(_ window: GameWindow) {
        if !activeWindows.contains(where: { $0.id == window.id }) {
            activeWindows.append(window)
        }
    }
    
    // MARK: - Unregister Window
    
    func unregisterWindow(_ window: GameWindow) {
        activeWindows.removeAll { $0.id == window.id }
    }
    
    // MARK: - Find Window
    
    func findWindow(for gameId: UUID) -> GameWindow? {
        activeWindows.first { $0.gameId == gameId }
    }
}

// MARK: - Game Window

struct GameWindow: Identifiable, Equatable {
    let id: UUID
    let gameId: UUID
    let gameName: String
    var isPrimary: Bool
    
    static func == (lhs: GameWindow, rhs: GameWindow) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Multi-Window Scene Delegate

class MultiWindowSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        
        // Check if this is a game window
        if let activity = connectionOptions.userActivities.first,
           activity.activityType == "com.yearn.emulator.game" {
            setupGameWindow(windowScene: windowScene, activity: activity)
        } else {
            setupMainWindow(windowScene: windowScene)
        }
    }
    
    private func setupMainWindow(windowScene: UIWindowScene) {
        let window = UIWindow(windowScene: windowScene)
        let contentView = ContentView()
            .environmentObject(AppState())
        
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()
    }
    
    private func setupGameWindow(windowScene: UIWindowScene, activity: NSUserActivity) {
        guard let userInfo = activity.userInfo,
              let gameIdString = userInfo["gameId"] as? String,
              let gameId = UUID(uuidString: gameIdString),
              let gameName = userInfo["gameName"] as? String,
              let systemRaw = userInfo["gameSystem"] as? String,
              let fileURLString = userInfo["fileURL"] as? String,
              let fileURL = URL(string: fileURLString) else {
            return
        }
        
        let system = GameSystem(rawValue: systemRaw) ?? .nes
        let game = Game(id: gameId, name: gameName, fileURL: fileURL, system: system)
        
        let window = UIWindow(windowScene: windowScene)
        let emulationView = EmulationView(game: game)
        
        window.rootViewController = UIHostingController(rootView: emulationView)
        self.window = window
        window.makeKeyAndVisible()
        
        // Register window
        let gameWindow = GameWindow(
            id: UUID(),
            gameId: gameId,
            gameName: gameName,
            isPrimary: false
        )
        Task { @MainActor in
            MultiWindowManager.shared.registerWindow(gameWindow)
        }
        
        // Set window title
        windowScene.title = gameName
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Cleanup when window closes
    }
}

// MARK: - Open in New Window Button

struct OpenInNewWindowButton: View {
    let game: Game
    
    var body: some View {
        Button {
            Task { @MainActor in
                MultiWindowManager.shared.openNewWindow(for: game)
            }
        } label: {
            Label("Open in New Window", systemImage: "rectangle.badge.plus")
        }
        .disabled(!supportsMultipleWindows)
    }
    
    private var supportsMultipleWindows: Bool {
        UIApplication.shared.supportsMultipleScenes
    }
}

// MARK: - Window Size Classes

struct AdaptiveLayout<Compact: View, Regular: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    let compact: () -> Compact
    let regular: () -> Regular
    
    init(
        @ViewBuilder compact: @escaping () -> Compact,
        @ViewBuilder regular: @escaping () -> Regular
    ) {
        self.compact = compact
        self.regular = regular
    }
    
    var body: some View {
        if horizontalSizeClass == .compact {
            compact()
        } else {
            regular()
        }
    }
}

// MARK: - iPad Sidebar Layout

struct iPadSidebarLayout<Sidebar: View, Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    let sidebar: () -> Sidebar
    let content: () -> Content
    
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                sidebar()
            } detail: {
                content()
            }
        } else {
            NavigationStack {
                content()
            }
        }
    }
}

// MARK: - Drag and Drop Support

struct GameDropDelegate: DropDelegate {
    let onDrop: (URL) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.fileURL]).first else {
            return false
        }
        
        itemProvider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, error in
            guard let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }
            
            DispatchQueue.main.async {
                onDrop(url)
            }
        }
        
        return true
    }
}

extension View {
    func onGameDrop(_ handler: @escaping (URL) -> Void) -> some View {
        self.onDrop(of: [.fileURL], delegate: GameDropDelegate(onDrop: handler))
    }
}

// MARK: - Pointer Hover Effect

struct PointerHoverEffect: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func pointerHoverEffect() -> some View {
        modifier(PointerHoverEffect())
    }
}

// MARK: - Context Menu with Preview

struct GameContextMenu: View {
    let game: Game
    let onPlay: () -> Void
    let onFavorite: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Group {
            Button {
                onPlay()
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            
            if UIApplication.shared.supportsMultipleScenes {
                OpenInNewWindowButton(game: game)
            }
            
            Divider()
            
            Button {
                onFavorite()
            } label: {
                Label(
                    game.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: game.isFavorite ? "heart.slash" : "heart"
                )
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

