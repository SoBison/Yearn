//
//  TurboManager.swift
//  Yearn
//
//  Turbo (auto-fire) button management
//

import Foundation
import Combine

// MARK: - Turbo Manager

@MainActor
class TurboManager: ObservableObject {
    static let shared = TurboManager()
    
    // MARK: - Properties
    
    @Published var turboButtons: Set<GameInput> = []
    @Published var turboSpeed: TurboSpeed = .normal
    @Published var isEnabled: Bool = true
    
    private var turboTimer: Timer?
    private var turboStates: [GameInput: Bool] = [:]
    private var inputCallback: ((GameInput, Bool) -> Void)?
    
    // MARK: - Turbo Speed
    
    enum TurboSpeed: Double, CaseIterable, Identifiable {
        case slow = 0.1      // 10 Hz
        case normal = 0.05   // 20 Hz
        case fast = 0.033    // 30 Hz
        case veryFast = 0.02 // 50 Hz
        
        var id: Double { rawValue }
        
        var displayName: String {
            switch self {
            case .slow: return "Slow (10 Hz)"
            case .normal: return "Normal (20 Hz)"
            case .fast: return "Fast (30 Hz)"
            case .veryFast: return "Very Fast (50 Hz)"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        loadSettings()
    }
    
    // MARK: - Configuration
    
    func setInputCallback(_ callback: @escaping (GameInput, Bool) -> Void) {
        inputCallback = callback
    }
    
    func toggleTurbo(for button: GameInput) {
        if turboButtons.contains(button) {
            turboButtons.remove(button)
            turboStates.removeValue(forKey: button)
        } else {
            turboButtons.insert(button)
            turboStates[button] = false
        }
        saveSettings()
        updateTimer()
    }
    
    func setTurboSpeed(_ speed: TurboSpeed) {
        turboSpeed = speed
        saveSettings()
        updateTimer()
    }
    
    func isTurboEnabled(for button: GameInput) -> Bool {
        turboButtons.contains(button)
    }
    
    // MARK: - Timer Management
    
    func start() {
        guard isEnabled, !turboButtons.isEmpty else { return }
        
        turboTimer?.invalidate()
        turboTimer = Timer.scheduledTimer(withTimeInterval: turboSpeed.rawValue, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    func stop() {
        turboTimer?.invalidate()
        turboTimer = nil
        
        // Release all turbo buttons
        for button in turboButtons {
            inputCallback?(button, false)
        }
        turboStates = turboStates.mapValues { _ in false }
    }
    
    private func updateTimer() {
        if turboTimer != nil {
            stop()
            start()
        }
    }
    
    private func tick() {
        for button in turboButtons {
            let newState = !(turboStates[button] ?? false)
            turboStates[button] = newState
            inputCallback?(button, newState)
        }
    }
    
    // MARK: - Persistence
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "turboButtons"),
           let buttons = try? JSONDecoder().decode([String].self, from: data) {
            turboButtons = Set(buttons.compactMap { GameInput(rawValue: $0) })
        }
        
        if let speedValue = UserDefaults.standard.object(forKey: "turboSpeed") as? Double,
           let speed = TurboSpeed(rawValue: speedValue) {
            turboSpeed = speed
        }
    }
    
    private func saveSettings() {
        let buttonStrings = turboButtons.map { $0.rawValue }
        if let data = try? JSONEncoder().encode(buttonStrings) {
            UserDefaults.standard.set(data, forKey: "turboButtons")
        }
        UserDefaults.standard.set(turboSpeed.rawValue, forKey: "turboSpeed")
    }
}

// MARK: - Turbo Button View

import SwiftUI

struct TurboButtonView: View {
    let button: GameInput
    @ObservedObject private var turboManager = TurboManager.shared
    
    var body: some View {
        Button {
            turboManager.toggleTurbo(for: button)
            HapticManager.shared.mediumImpact()
        } label: {
            HStack {
                Text(button.displayName)
                Spacer()
                if turboManager.isTurboEnabled(for: button) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.yellow)
                }
            }
        }
    }
}

// MARK: - Turbo Settings View

struct TurboSettingsView: View {
    @ObservedObject private var turboManager = TurboManager.shared
    
    var body: some View {
        List {
            Section {
                Toggle("Enable Turbo", isOn: $turboManager.isEnabled)
            }
            
            Section("Turbo Speed") {
                Picker("Speed", selection: $turboManager.turboSpeed) {
                    ForEach(TurboManager.TurboSpeed.allCases) { speed in
                        Text(speed.displayName).tag(speed)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            
            Section("Face Buttons") {
                TurboButtonView(button: .a)
                TurboButtonView(button: .b)
                TurboButtonView(button: .x)
                TurboButtonView(button: .y)
            }
            
            Section("Shoulder Buttons") {
                TurboButtonView(button: .l)
                TurboButtonView(button: .r)
            }
            
            Section {
                Button("Clear All Turbo") {
                    turboManager.turboButtons.removeAll()
                    HapticManager.shared.success()
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle("Turbo Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        TurboSettingsView()
    }
}

