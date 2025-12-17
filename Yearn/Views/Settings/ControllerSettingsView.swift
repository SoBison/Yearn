//
//  ControllerSettingsView.swift
//  Yearn
//
//  Controller configuration and mapping settings
//

import SwiftUI
import GameController

struct ControllerSettingsView: View {
    // Virtual Controller Settings
    @AppStorage("controllerOpacity") private var controllerOpacity = 0.7
    @AppStorage("controllerSize") private var controllerSize = 1.0
    @AppStorage("controllerHaptics") private var hapticsEnabled = true
    @AppStorage("showControllerLabels") private var showLabels = false
    @AppStorage("autoHideController") private var autoHide = true
    
    // Physical Controller Settings
    @AppStorage("controllerVibration") private var vibrationEnabled = true
    @AppStorage("hideVirtualControllerWhenConnected") private var hideVirtualWhenConnected = true
    @AppStorage("useLeftStickAsDPad") private var useLeftStickAsDPad = true
    @AppStorage("useRightStickForCamera") private var useRightStickForCamera = true
    @AppStorage("stickDeadzone") private var stickDeadzone = 0.15
    
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var connectedControllers: [GCController] = []
    @State private var showSkinPicker = false
    @State private var refreshID = UUID()
    
    var body: some View {
        Form {
            // Connected Controllers
            Section {
                if connectedControllers.isEmpty {
                    HStack {
                        Image(systemName: "gamecontroller")
                            .foregroundStyle(.secondary)
                        Text("controller.noConnected".localized)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(connectedControllers, id: \.vendorName) { controller in
                        ControllerRow(controller: controller)
                    }
                }
                
                Button {
                    refreshControllers()
                } label: {
                    Label("controller.refresh".localized, systemImage: "arrow.clockwise")
                }
            } header: {
                Text("controller.connected".localized)
            } footer: {
                Text("controller.supported".localized)
            }
            
            // Physical Controller Settings
            Section("controller.physical".localized) {
                Toggle("controller.vibration".localized, isOn: $vibrationEnabled)
                
                Toggle("controller.hideVirtual".localized, isOn: $hideVirtualWhenConnected)
                
                Toggle("controller.leftStickDPad".localized, isOn: $useLeftStickAsDPad)
                
                Toggle("controller.rightStickCamera".localized, isOn: $useRightStickForCamera)
                
                VStack(alignment: .leading) {
                    Text("controller.deadzone".localized + ": \(Int(stickDeadzone * 100))%")
                    Slider(value: $stickDeadzone, in: 0.05...0.35, step: 0.05)
                }
                
                NavigationLink {
                    ControllerMappingView()
                } label: {
                    Text("controller.mapping".localized)
                }
            }
            
            // Virtual Controller
            Section("controller.virtual".localized) {
                VStack(alignment: .leading) {
                    Text("controller.opacity".localized + ": \(Int(controllerOpacity * 100))%")
                    Slider(value: $controllerOpacity, in: 0.3...1.0, step: 0.1)
                }
                
                VStack(alignment: .leading) {
                    Text("controller.size".localized + ": \(Int(controllerSize * 100))%")
                    Slider(value: $controllerSize, in: 0.7...1.3, step: 0.1)
                }
                
                Toggle("controller.showLabels".localized, isOn: $showLabels)
                Toggle("controller.haptics".localized, isOn: $hapticsEnabled)
                Toggle("controller.autoHide".localized, isOn: $autoHide)
                
                Button {
                    showSkinPicker = true
                } label: {
                    HStack {
                        Text("controller.skin".localized)
                        Spacer()
                        Text(ControllerSkinManager.shared.currentSkin.name)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Presets
            Section("controller.presets".localized) {
                Button("controller.preset.compact".localized) {
                    applyPreset(.compact)
                }
                
                Button("controller.preset.default".localized) {
                    applyPreset(.default)
                }
                
                Button("controller.preset.large".localized) {
                    applyPreset(.large)
                }
            }
            
            // Turbo Settings
            Section("controller.turbo".localized) {
                NavigationLink {
                    TurboSettingsView()
                } label: {
                    Text("controller.turbo.settings".localized)
                }
            }
        }
        .id(refreshID)
        .navigationTitle("controller.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .themedListBackground()
        .sheet(isPresented: $showSkinPicker) {
            ControllerSkinPickerView()
        }
        .onAppear {
            refreshControllers()
            setupControllerNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            refreshID = UUID()
        }
    }
    
    private func refreshControllers() {
        connectedControllers = GCController.controllers()
    }
    
    private func setupControllerNotifications() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { _ in
            refreshControllers()
        }
        
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { _ in
            refreshControllers()
        }
    }
    
    private func applyPreset(_ preset: ControllerPreset) {
        switch preset {
        case .compact:
            controllerOpacity = 0.6
            controllerSize = 0.8
        case .default:
            controllerOpacity = 0.7
            controllerSize = 1.0
        case .large:
            controllerOpacity = 0.8
            controllerSize = 1.2
        }
        HapticManager.shared.success()
    }
    
    enum ControllerPreset {
        case compact, `default`, large
    }
}

// MARK: - Controller Row

struct ControllerRow: View {
    let controller: GCController
    
    var body: some View {
        HStack {
            Image(systemName: controllerIcon)
                .font(.title2)
                .foregroundStyle(controllerColor)
            
            VStack(alignment: .leading) {
                Text(controller.vendorName ?? "controller.unknown".localized)
                    .fontWeight(.medium)
                
                Text(controllerType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let battery = controller.battery {
                BatteryIndicator(level: battery.batteryLevel, state: battery.batteryState)
            }
        }
    }
    
    private var controllerIcon: String {
        let name = controller.vendorName?.lowercased() ?? ""
        
        if name.contains("xbox") {
            return "xbox.logo"
        } else if name.contains("dualshock") || name.contains("dualsense") || name.contains("playstation") {
            return "playstation.logo"
        } else if name.contains("switch") || name.contains("nintendo") {
            return "logo.nintendo.switch"
        } else if controller.extendedGamepad != nil {
            return "gamecontroller.fill"
        } else if controller.microGamepad != nil {
            return "appletvremote.gen4.fill"
        } else {
            return "gamecontroller"
        }
    }
    
    private var controllerColor: Color {
        let name = controller.vendorName?.lowercased() ?? ""
        
        if name.contains("xbox") {
            return Color(red: 0.07, green: 0.49, blue: 0.17)
        } else if name.contains("dualshock") || name.contains("dualsense") || name.contains("playstation") {
            return Color(red: 0.0, green: 0.55, blue: 0.9)
        } else if name.contains("switch") || name.contains("nintendo") {
            return Color(red: 0.89, green: 0.19, blue: 0.19)
        } else {
            return .green
        }
    }
    
    private var controllerType: String {
        let name = controller.vendorName?.lowercased() ?? ""
        
        if name.contains("xbox") {
            return "Xbox Controller"
        } else if name.contains("dualsense") {
            return "DualSense"
        } else if name.contains("dualshock") {
            return "DualShock 4"
        } else if name.contains("switch") {
            return "Switch Pro Controller"
        } else if controller.extendedGamepad != nil {
            return "controller.extended".localized
        } else if controller.microGamepad != nil {
            return "Siri Remote"
        } else {
            return "controller.basic".localized
        }
    }
}

// MARK: - Battery Indicator

struct BatteryIndicator: View {
    let level: Float
    let state: GCDeviceBattery.State
    
    var body: some View {
        HStack(spacing: 4) {
            if state == .charging {
                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
            
            Image(systemName: batteryIcon)
                .foregroundStyle(batteryColor)
            
            Text("\(Int(level * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var batteryIcon: String {
        switch level {
        case 0..<0.25: return "battery.25"
        case 0.25..<0.5: return "battery.50"
        case 0.5..<0.75: return "battery.75"
        default: return "battery.100"
        }
    }
    
    private var batteryColor: Color {
        if level < 0.2 {
            return .red
        } else if level < 0.4 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Controller Mapping View

struct ControllerMappingView: View {
    @AppStorage("buttonMapping") private var buttonMappingData: Data = Data()
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var mapping: ButtonMapping = .default
    @State private var isListening = false
    @State private var listeningButton: GameInput?
    @State private var refreshID = UUID()
    
    var body: some View {
        List {
            Section("controller.mapping.face".localized) {
                MappingRow(input: .a, mapping: $mapping, isListening: $isListening, listeningButton: $listeningButton)
                MappingRow(input: .b, mapping: $mapping, isListening: $isListening, listeningButton: $listeningButton)
                MappingRow(input: .x, mapping: $mapping, isListening: $isListening, listeningButton: $listeningButton)
                MappingRow(input: .y, mapping: $mapping, isListening: $isListening, listeningButton: $listeningButton)
            }
            
            Section("controller.mapping.dpad".localized) {
                MappingRow(input: .up, mapping: $mapping, isListening: $isListening, listeningButton: $listeningButton)
                MappingRow(input: .down, mapping: $mapping, isListening: $isListening, listeningButton: $listeningButton)
                MappingRow(input: .left, mapping: $mapping, isListening: $isListening, listeningButton: $listeningButton)
                MappingRow(input: .right, mapping: $mapping, isListening: $isListening, listeningButton: $listeningButton)
            }
            
            Section("controller.mapping.shoulder".localized) {
                MappingRow(input: .l, mapping: $mapping, isListening: $isListening, listeningButton: $listeningButton)
                MappingRow(input: .r, mapping: $mapping, isListening: $isListening, listeningButton: $listeningButton)
                MappingRow(input: .l2, mapping: $mapping, isListening: $isListening, listeningButton: $listeningButton)
                MappingRow(input: .r2, mapping: $mapping, isListening: $isListening, listeningButton: $listeningButton)
            }
            
            Section("controller.mapping.thumbstick".localized) {
                MappingRow(input: .l3, mapping: $mapping, isListening: $isListening, listeningButton: $listeningButton)
                MappingRow(input: .r3, mapping: $mapping, isListening: $isListening, listeningButton: $listeningButton)
            }
            
            Section("controller.mapping.system".localized) {
                MappingRow(input: .start, mapping: $mapping, isListening: $isListening, listeningButton: $listeningButton)
                MappingRow(input: .select, mapping: $mapping, isListening: $isListening, listeningButton: $listeningButton)
            }
            
            Section {
                Button("controller.mapping.reset".localized) {
                    mapping = .default
                    saveMapping()
                    HapticManager.shared.success()
                }
            }
        }
        .id(refreshID)
        .navigationTitle("controller.mapping".localized)
        .navigationBarTitleDisplayMode(.inline)
        .themedListBackground()
        .onAppear {
            loadMapping()
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            refreshID = UUID()
        }
    }
    
    private func loadMapping() {
        if let decoded = try? JSONDecoder().decode(ButtonMapping.self, from: buttonMappingData) {
            mapping = decoded
        }
    }
    
    private func saveMapping() {
        if let encoded = try? JSONEncoder().encode(mapping) {
            buttonMappingData = encoded
        }
    }
}

// MARK: - Mapping Row

struct MappingRow: View {
    let input: GameInput
    @Binding var mapping: ButtonMapping
    @Binding var isListening: Bool
    @Binding var listeningButton: GameInput?
    
    var body: some View {
        HStack {
            Text(input.localizedName)
            
            Spacer()
            
            if listeningButton == input {
                Text("controller.mapping.press".localized)
                    .foregroundStyle(.blue)
            } else {
                Text(mapping.physicalButton(for: input))
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            listeningButton = input
            isListening = true
        }
    }
}

// MARK: - Button Mapping

struct ButtonMapping: Codable {
    var mappings: [String: String]
    
    static let `default` = ButtonMapping(mappings: [
        "a": "A",
        "b": "B",
        "x": "X",
        "y": "Y",
        "up": "D-Pad Up",
        "down": "D-Pad Down",
        "left": "D-Pad Left",
        "right": "D-Pad Right",
        "l": "L1",
        "r": "R1",
        "l2": "L2",
        "r2": "R2",
        "l3": "L3",
        "r3": "R3",
        "start": "Start",
        "select": "Select"
    ])
    
    func physicalButton(for input: GameInput) -> String {
        mappings[input.rawValue] ?? "controller.mapping.notSet".localized
    }
    
    mutating func setMapping(_ physical: String, for input: GameInput) {
        mappings[input.rawValue] = physical
    }
}

// MARK: - Game Input Extension

extension GameInput {
    var localizedName: String {
        switch self {
        case .a: return "controller.button.a".localized
        case .b: return "controller.button.b".localized
        case .x: return "controller.button.x".localized
        case .y: return "controller.button.y".localized
        case .up: return "controller.button.up".localized
        case .down: return "controller.button.down".localized
        case .left: return "controller.button.left".localized
        case .right: return "controller.button.right".localized
        case .l: return "controller.button.l".localized
        case .r: return "controller.button.r".localized
        case .l2: return "controller.button.l2".localized
        case .r2: return "controller.button.r2".localized
        case .l3: return "controller.button.l3".localized
        case .r3: return "controller.button.r3".localized
        case .start: return "controller.button.start".localized
        case .select: return "controller.button.select".localized
        }
    }
}

#Preview {
    NavigationStack {
        ControllerSettingsView()
    }
}
