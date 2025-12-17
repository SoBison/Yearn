//
//  SpeedManager.swift
//  Yearn
//
//  Emulation speed control (fast forward, slow motion)
//

import Foundation
import Combine

// MARK: - Speed Manager

@MainActor
class SpeedManager: ObservableObject {
    static let shared = SpeedManager()
    
    // MARK: - Properties
    
    @Published var currentSpeed: EmulationSpeed = .normal
    @Published var isFastForwarding = false
    @Published var isSlowMotion = false
    
    // Settings
    @Published var fastForwardSpeed: EmulationSpeed = .x2
    @Published var slowMotionSpeed: EmulationSpeed = .half
    @Published var holdToFastForward = true
    @Published var showSpeedIndicator = true
    
    private var previousSpeed: EmulationSpeed = .normal
    
    // MARK: - Emulation Speed
    
    enum EmulationSpeed: Double, CaseIterable, Identifiable {
        case quarter = 0.25
        case half = 0.5
        case threeQuarter = 0.75
        case normal = 1.0
        case x1_5 = 1.5
        case x2 = 2.0
        case x3 = 3.0
        case x4 = 4.0
        case x8 = 8.0
        case unlimited = 0.0  // 0 means no frame limiting
        
        var id: Double { rawValue }
        
        var displayName: String {
            switch self {
            case .quarter: return "0.25x (Slow)"
            case .half: return "0.5x (Slow)"
            case .threeQuarter: return "0.75x"
            case .normal: return "1x (Normal)"
            case .x1_5: return "1.5x"
            case .x2: return "2x"
            case .x3: return "3x"
            case .x4: return "4x"
            case .x8: return "8x"
            case .unlimited: return "Unlimited"
            }
        }
        
        var shortName: String {
            switch self {
            case .quarter: return "¼×"
            case .half: return "½×"
            case .threeQuarter: return "¾×"
            case .normal: return "1×"
            case .x1_5: return "1.5×"
            case .x2: return "2×"
            case .x3: return "3×"
            case .x4: return "4×"
            case .x8: return "8×"
            case .unlimited: return "∞"
            }
        }
        
        var isSlowMotion: Bool {
            rawValue > 0 && rawValue < 1.0
        }
        
        var isFastForward: Bool {
            rawValue > 1.0 || rawValue == 0
        }
        
        /// Frame time in seconds (for frame limiting)
        var frameTime: TimeInterval? {
            guard rawValue > 0 else { return nil }  // Unlimited
            return (1.0 / 60.0) / rawValue
        }
        
        static var fastForwardSpeeds: [EmulationSpeed] {
            [.x1_5, .x2, .x3, .x4, .x8, .unlimited]
        }
        
        static var slowMotionSpeeds: [EmulationSpeed] {
            [.quarter, .half, .threeQuarter]
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        loadSettings()
    }
    
    // MARK: - Speed Control
    
    func setSpeed(_ speed: EmulationSpeed) {
        previousSpeed = currentSpeed
        currentSpeed = speed
        
        isFastForwarding = speed.isFastForward
        isSlowMotion = speed.isSlowMotion
    }
    
    func toggleFastForward() {
        if isFastForwarding {
            setSpeed(.normal)
        } else {
            setSpeed(fastForwardSpeed)
        }
        HapticManager.shared.fastForwardToggle()
    }
    
    func toggleSlowMotion() {
        if isSlowMotion {
            setSpeed(.normal)
        } else {
            setSpeed(slowMotionSpeed)
        }
        HapticManager.shared.mediumImpact()
    }
    
    func startFastForward() {
        guard !isFastForwarding else { return }
        previousSpeed = currentSpeed
        setSpeed(fastForwardSpeed)
    }
    
    func stopFastForward() {
        guard isFastForwarding else { return }
        setSpeed(previousSpeed.isFastForward ? .normal : previousSpeed)
    }
    
    func startSlowMotion() {
        guard !isSlowMotion else { return }
        previousSpeed = currentSpeed
        setSpeed(slowMotionSpeed)
    }
    
    func stopSlowMotion() {
        guard isSlowMotion else { return }
        setSpeed(previousSpeed.isSlowMotion ? .normal : previousSpeed)
    }
    
    func resetSpeed() {
        setSpeed(.normal)
    }
    
    // MARK: - Settings
    
    private func loadSettings() {
        if let ffSpeed = UserDefaults.standard.object(forKey: "fastForwardSpeed") as? Double,
           let speed = EmulationSpeed(rawValue: ffSpeed) {
            fastForwardSpeed = speed
        }
        
        if let smSpeed = UserDefaults.standard.object(forKey: "slowMotionSpeed") as? Double,
           let speed = EmulationSpeed(rawValue: smSpeed) {
            slowMotionSpeed = speed
        }
        
        holdToFastForward = UserDefaults.standard.bool(forKey: "holdToFastForward")
        showSpeedIndicator = UserDefaults.standard.bool(forKey: "showSpeedIndicator")
        
        // Set defaults if not configured
        if !UserDefaults.standard.bool(forKey: "speedSettingsInitialized") {
            holdToFastForward = true
            showSpeedIndicator = true
            UserDefaults.standard.set(true, forKey: "speedSettingsInitialized")
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(fastForwardSpeed.rawValue, forKey: "fastForwardSpeed")
        UserDefaults.standard.set(slowMotionSpeed.rawValue, forKey: "slowMotionSpeed")
        UserDefaults.standard.set(holdToFastForward, forKey: "holdToFastForward")
        UserDefaults.standard.set(showSpeedIndicator, forKey: "showSpeedIndicator")
    }
}

// MARK: - Speed Indicator View

import SwiftUI

struct SpeedIndicator: View {
    @ObservedObject private var speedManager = SpeedManager.shared
    
    var body: some View {
        if speedManager.showSpeedIndicator && speedManager.currentSpeed != .normal {
            HStack(spacing: 4) {
                Image(systemName: speedManager.isFastForwarding ? "forward.fill" : "backward.fill")
                    .font(.caption)
                
                Text(speedManager.currentSpeed.shortName)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(speedManager.isFastForwarding ? Color.orange : Color.blue)
            .clipShape(Capsule())
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.3), value: speedManager.currentSpeed)
        }
    }
}

// MARK: - Speed Control Button

struct SpeedControlButton: View {
    @ObservedObject private var speedManager = SpeedManager.shared
    let type: SpeedType
    
    enum SpeedType {
        case fastForward
        case slowMotion
    }
    
    var body: some View {
        Button {
            switch type {
            case .fastForward:
                speedManager.toggleFastForward()
            case .slowMotion:
                speedManager.toggleSlowMotion()
            }
        } label: {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isActive ? activeColor : .white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(isActive ? 0.3 : 0.15))
                .clipShape(Circle())
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.1)
                .onEnded { _ in
                    if speedManager.holdToFastForward && type == .fastForward {
                        speedManager.startFastForward()
                    }
                }
        )
    }
    
    private var icon: String {
        switch type {
        case .fastForward:
            return speedManager.isFastForwarding ? "forward.fill" : "forward"
        case .slowMotion:
            return speedManager.isSlowMotion ? "tortoise.fill" : "tortoise"
        }
    }
    
    private var isActive: Bool {
        switch type {
        case .fastForward:
            return speedManager.isFastForwarding
        case .slowMotion:
            return speedManager.isSlowMotion
        }
    }
    
    private var activeColor: Color {
        switch type {
        case .fastForward:
            return .orange
        case .slowMotion:
            return .blue
        }
    }
}

// MARK: - Speed Settings View

struct SpeedSettingsView: View {
    @ObservedObject private var speedManager = SpeedManager.shared
    
    var body: some View {
        List {
            Section("Fast Forward") {
                Picker("Speed", selection: $speedManager.fastForwardSpeed) {
                    ForEach(SpeedManager.EmulationSpeed.fastForwardSpeeds) { speed in
                        Text(speed.displayName).tag(speed)
                    }
                }
                
                Toggle("Hold to Fast Forward", isOn: $speedManager.holdToFastForward)
            }
            
            Section("Slow Motion") {
                Picker("Speed", selection: $speedManager.slowMotionSpeed) {
                    ForEach(SpeedManager.EmulationSpeed.slowMotionSpeeds) { speed in
                        Text(speed.displayName).tag(speed)
                    }
                }
            }
            
            Section("Display") {
                Toggle("Show Speed Indicator", isOn: $speedManager.showSpeedIndicator)
            }
        }
        .navigationTitle("Speed Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: speedManager.fastForwardSpeed) { _, _ in speedManager.saveSettings() }
        .onChange(of: speedManager.slowMotionSpeed) { _, _ in speedManager.saveSettings() }
        .onChange(of: speedManager.holdToFastForward) { _, _ in speedManager.saveSettings() }
        .onChange(of: speedManager.showSpeedIndicator) { _, _ in speedManager.saveSettings() }
    }
}

// Note: SpeedPickerSheet is defined in EmulationView.swift

#Preview {
    NavigationStack {
        SpeedSettingsView()
    }
}

