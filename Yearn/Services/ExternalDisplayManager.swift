//
//  ExternalDisplayManager.swift
//  Yearn
//
//  Manages external display output for AirPlay and wired connections
//

import UIKit
import AVKit
import SwiftUI

/// Manages external display connections (AirPlay, HDMI, USB-C)
@MainActor
class ExternalDisplayManager: ObservableObject {
    static let shared = ExternalDisplayManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var isExternalDisplayConnected = false
    @Published private(set) var externalScreen: UIScreen?
    @Published private(set) var externalWindow: UIWindow?
    @Published var mirrorMode: MirrorMode = .gameOnly
    @Published var showControlsOnDevice: Bool = true
    @Published var externalDisplayScale: CGFloat = 1.0
    
    // MARK: - Mirror Mode
    
    enum MirrorMode: String, CaseIterable, Identifiable {
        case gameOnly = "gameOnly"
        case fullMirror = "fullMirror"
        case gameWithBorder = "gameWithBorder"
        
        var id: String { rawValue }
        
        var localizedName: String {
            switch self {
            case .gameOnly: return "display.mode.gameOnly".localized
            case .fullMirror: return "display.mode.fullMirror".localized
            case .gameWithBorder: return "display.mode.gameWithBorder".localized
            }
        }
        
        var description: String {
            switch self {
            case .gameOnly: return "display.mode.gameOnly.desc".localized
            case .fullMirror: return "display.mode.fullMirror.desc".localized
            case .gameWithBorder: return "display.mode.gameWithBorder.desc".localized
            }
        }
    }
    
    // MARK: - Private Properties
    
    private var gameView: UIView?
    private var externalViewController: UIViewController?
    
    // MARK: - Initialization
    
    private init() {
        setupNotifications()
        checkForExternalDisplay()
        loadSettings()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Settings
    
    private func loadSettings() {
        if let modeString = UserDefaults.standard.string(forKey: "externalDisplayMirrorMode"),
           let mode = MirrorMode(rawValue: modeString) {
            mirrorMode = mode
        }
        showControlsOnDevice = UserDefaults.standard.object(forKey: "showControlsOnDevice") as? Bool ?? true
        externalDisplayScale = UserDefaults.standard.object(forKey: "externalDisplayScale") as? CGFloat ?? 1.0
    }
    
    func saveSettings() {
        UserDefaults.standard.set(mirrorMode.rawValue, forKey: "externalDisplayMirrorMode")
        UserDefaults.standard.set(showControlsOnDevice, forKey: "showControlsOnDevice")
        UserDefaults.standard.set(externalDisplayScale, forKey: "externalDisplayScale")
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidConnect),
            name: UIScreen.didConnectNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidDisconnect),
            name: UIScreen.didDisconnectNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenModeDidChange),
            name: UIScreen.modeDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func screenDidConnect(_ notification: Notification) {
        checkForExternalDisplay()
        
        if let screen = notification.object as? UIScreen {
            setupExternalDisplay(screen)
            
            // Post notification for UI updates
            NotificationCenter.default.post(name: .externalDisplayDidConnect, object: screen)
        }
    }
    
    @objc private func screenDidDisconnect(_ notification: Notification) {
        teardownExternalDisplay()
        checkForExternalDisplay()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .externalDisplayDidDisconnect, object: nil)
    }
    
    @objc private func screenModeDidChange(_ notification: Notification) {
        if let screen = externalScreen {
            updateExternalDisplayLayout(for: screen)
        }
    }
    
    // MARK: - External Display Management
    
    private func checkForExternalDisplay() {
        let screens = UIScreen.screens
        
        if screens.count > 1 {
            externalScreen = screens[1]
            isExternalDisplayConnected = true
        } else {
            externalScreen = nil
            isExternalDisplayConnected = false
        }
    }
    
    private func setupExternalDisplay(_ screen: UIScreen) {
        externalScreen = screen
        isExternalDisplayConnected = true
        
        // Create window for external display
        let window = UIWindow(frame: screen.bounds)
        window.screen = screen
        
        // Create view controller for external display
        let viewController = ExternalDisplayViewController()
        viewController.mirrorMode = mirrorMode
        viewController.displayScale = externalDisplayScale
        
        window.rootViewController = viewController
        window.isHidden = false
        
        externalWindow = window
        externalViewController = viewController
        
        print("External display connected: \(screen.bounds.size)")
    }
    
    private func teardownExternalDisplay() {
        externalWindow?.isHidden = true
        externalWindow = nil
        externalViewController = nil
        externalScreen = nil
        isExternalDisplayConnected = false
        
        print("External display disconnected")
    }
    
    private func updateExternalDisplayLayout(for screen: UIScreen) {
        externalWindow?.frame = screen.bounds
        
        if let vc = externalViewController as? ExternalDisplayViewController {
            vc.updateLayout()
        }
    }
    
    // MARK: - Game View Management
    
    /// Set the game view to be displayed on external screen
    func setGameView(_ view: UIView?) {
        gameView = view
        
        if let vc = externalViewController as? ExternalDisplayViewController {
            vc.setGameContent(view)
        }
    }
    
    /// Update the game frame on external display
    func updateGameFrame(_ image: CGImage) {
        if let vc = externalViewController as? ExternalDisplayViewController {
            vc.updateFrame(image)
        }
    }
    
    /// Get external display info
    var displayInfo: ExternalDisplayInfo? {
        guard let screen = externalScreen else { return nil }
        
        return ExternalDisplayInfo(
            name: screen.description,
            resolution: screen.bounds.size,
            scale: screen.scale,
            refreshRate: screen.maximumFramesPerSecond
        )
    }
}

// MARK: - External Display Info

struct ExternalDisplayInfo {
    let name: String
    let resolution: CGSize
    let scale: CGFloat
    let refreshRate: Int
    
    var resolutionString: String {
        "\(Int(resolution.width * scale)) × \(Int(resolution.height * scale))"
    }
    
    var refreshRateString: String {
        "\(refreshRate) Hz"
    }
}

// MARK: - External Display View Controller

class ExternalDisplayViewController: UIViewController {
    var mirrorMode: ExternalDisplayManager.MirrorMode = .gameOnly
    var displayScale: CGFloat = 1.0
    
    private var gameContentView: UIView?
    private var imageView: UIImageView?
    private var borderView: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        setupImageView()
        setupBorderView()
    }
    
    private func setupImageView() {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor)
        ])
        
        self.imageView = imageView
    }
    
    private func setupBorderView() {
        let borderView = UIView()
        borderView.backgroundColor = .clear
        borderView.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        borderView.layer.borderWidth = 2
        borderView.isHidden = true
        borderView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(borderView)
        
        NSLayoutConstraint.activate([
            borderView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            borderView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            borderView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            borderView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
        
        self.borderView = borderView
    }
    
    func setGameContent(_ view: UIView?) {
        gameContentView?.removeFromSuperview()
        gameContentView = view
        
        if let view = view {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.view.insertSubview(view, at: 0)
            
            NSLayoutConstraint.activate([
                view.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                view.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
                view.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: displayScale),
                view.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: displayScale)
            ])
        }
    }
    
    func updateFrame(_ image: CGImage) {
        imageView?.image = UIImage(cgImage: image)
    }
    
    func updateLayout() {
        borderView?.isHidden = mirrorMode != .gameWithBorder
        
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let externalDisplayDidConnect = Notification.Name("externalDisplayDidConnect")
    static let externalDisplayDidDisconnect = Notification.Name("externalDisplayDidDisconnect")
}

// MARK: - AirPlay Route Picker View

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.tintColor = .white
        routePickerView.activeTintColor = .systemBlue
        routePickerView.prioritizesVideoDevices = true
        return routePickerView
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

// MARK: - External Display Settings View

struct ExternalDisplaySettingsView: View {
    @ObservedObject private var displayManager = ExternalDisplayManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var refreshID = UUID()
    
    var body: some View {
        List {
            // Connection Status
            Section {
                HStack {
                    Image(systemName: displayManager.isExternalDisplayConnected ? "tv.fill" : "tv")
                        .foregroundStyle(displayManager.isExternalDisplayConnected ? .green : .secondary)
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text(displayManager.isExternalDisplayConnected ? 
                             "display.connected".localized : "display.notConnected".localized)
                            .fontWeight(.medium)
                        
                        if let info = displayManager.displayInfo {
                            Text(info.resolutionString + " @ " + info.refreshRateString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // AirPlay button
                    AirPlayButton()
                        .frame(width: 44, height: 44)
                }
            } header: {
                Text("display.status".localized)
            } footer: {
                Text("display.status.desc".localized)
            }
            
            // Mirror Mode
            Section("display.mode".localized) {
                ForEach(ExternalDisplayManager.MirrorMode.allCases) { mode in
                    Button {
                        displayManager.mirrorMode = mode
                        displayManager.saveSettings()
                        HapticManager.shared.selectionChanged()
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(mode.localizedName)
                                    .foregroundStyle(.primary)
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if displayManager.mirrorMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Display Options
            Section("display.options".localized) {
                Toggle("display.showControlsOnDevice".localized, isOn: $displayManager.showControlsOnDevice)
                    .onChange(of: displayManager.showControlsOnDevice) { _, _ in
                        displayManager.saveSettings()
                    }
                
                VStack(alignment: .leading) {
                    Text("display.scale".localized + ": \(Int(displayManager.externalDisplayScale * 100))%")
                    Slider(value: $displayManager.externalDisplayScale, in: 0.5...1.0, step: 0.1)
                        .onChange(of: displayManager.externalDisplayScale) { _, _ in
                            displayManager.saveSettings()
                        }
                }
            }
            
            // Tips
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("display.tip.airplay".localized, systemImage: "airplayvideo")
                    Label("display.tip.hdmi".localized, systemImage: "cable.connector")
                    Label("display.tip.usbc".localized, systemImage: "cable.connector.horizontal")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } header: {
                Text("display.tips".localized)
            }
        }
        .id(refreshID)
        .navigationTitle("display.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .themedListBackground()
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            refreshID = UUID()
        }
    }
}

#Preview {
    NavigationStack {
        ExternalDisplaySettingsView()
    }
}

