//
//  HapticManager.swift
//  Yearn
//
//  Centralized haptic feedback management
//

import UIKit
import CoreHaptics
import SwiftUI

// MARK: - Haptic Manager

class HapticManager {
    static let shared = HapticManager()
    
    // MARK: - Properties
    
    private var engine: CHHapticEngine?
    private var isHapticsSupported: Bool
    
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "hapticFeedbackEnabled")
        }
    }
    
    // Standard feedback generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // MARK: - Initialization
    
    private init() {
        isHapticsSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        isEnabled = UserDefaults.standard.bool(forKey: "hapticFeedbackEnabled")
        
        // Default to enabled if not set
        if !UserDefaults.standard.bool(forKey: "hapticFeedbackSet") {
            isEnabled = true
            UserDefaults.standard.set(true, forKey: "hapticFeedbackSet")
        }
        
        prepareGenerators()
        setupHapticEngine()
    }
    
    // MARK: - Setup
    
    private func prepareGenerators() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        impactSoft.prepare()
        impactRigid.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    private func setupHapticEngine() {
        guard isHapticsSupported else { return }
        
        do {
            engine = try CHHapticEngine()
            engine?.playsHapticsOnly = true
            
            engine?.stoppedHandler = { [weak self] reason in
                DispatchQueue.main.async {
                    self?.restartEngine()
                }
            }
            
            engine?.resetHandler = { [weak self] in
                DispatchQueue.main.async {
                    self?.restartEngine()
                }
            }
            
            try engine?.start()
        } catch {
            print("Haptic engine setup failed: \(error)")
        }
    }
    
    private func restartEngine() {
        do {
            try engine?.start()
        } catch {
            print("Failed to restart haptic engine: \(error)")
        }
    }
    
    // MARK: - Standard Haptics
    
    /// Light impact - for subtle feedback
    func lightImpact() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }
    
    /// Medium impact - for standard button presses
    func mediumImpact() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }
    
    /// Heavy impact - for significant actions
    func heavyImpact() {
        guard isEnabled else { return }
        impactHeavy.impactOccurred()
    }
    
    /// Soft impact - for gentle feedback
    func softImpact() {
        guard isEnabled else { return }
        impactSoft.impactOccurred()
    }
    
    /// Rigid impact - for firm feedback
    func rigidImpact() {
        guard isEnabled else { return }
        impactRigid.impactOccurred()
    }
    
    /// Selection changed - for picker/selection changes
    func selectionChanged() {
        guard isEnabled else { return }
        selectionFeedback.selectionChanged()
    }
    
    /// Success notification
    func success() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.success)
    }
    
    /// Warning notification
    func warning() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.warning)
    }
    
    /// Error notification
    func error() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.error)
    }
    
    // MARK: - Game Controller Haptics
    
    /// Button press haptic for virtual controller
    func buttonPress() {
        guard isEnabled else { return }
        
        if isHapticsSupported {
            playCustomHaptic(intensity: 0.6, sharpness: 0.8, duration: 0.05)
        } else {
            impactMedium.impactOccurred()
        }
    }
    
    /// Button release haptic
    func buttonRelease() {
        guard isEnabled else { return }
        
        if isHapticsSupported {
            playCustomHaptic(intensity: 0.3, sharpness: 0.5, duration: 0.03)
        } else {
            impactLight.impactOccurred()
        }
    }
    
    /// D-pad direction press
    func dpadPress() {
        guard isEnabled else { return }
        
        if isHapticsSupported {
            playCustomHaptic(intensity: 0.5, sharpness: 0.6, duration: 0.04)
        } else {
            impactLight.impactOccurred()
        }
    }
    
    /// Shoulder button press
    func shoulderPress() {
        guard isEnabled else { return }
        
        if isHapticsSupported {
            playCustomHaptic(intensity: 0.7, sharpness: 0.9, duration: 0.06)
        } else {
            impactRigid.impactOccurred()
        }
    }
    
    // MARK: - Game Events
    
    /// Game saved haptic
    func gameSaved() {
        guard isEnabled else { return }
        success()
    }
    
    /// Game loaded haptic
    func gameLoaded() {
        guard isEnabled else { return }
        
        if isHapticsSupported {
            playCustomHaptic(intensity: 0.5, sharpness: 0.4, duration: 0.15)
        } else {
            mediumImpact()
        }
    }
    
    /// Screenshot taken haptic
    func screenshotTaken() {
        guard isEnabled else { return }
        
        if isHapticsSupported {
            playCustomHaptic(intensity: 0.8, sharpness: 1.0, duration: 0.1)
        } else {
            rigidImpact()
        }
    }
    
    /// Fast forward toggle
    func fastForwardToggle() {
        guard isEnabled else { return }
        mediumImpact()
    }
    
    // MARK: - Custom Haptics
    
    /// Play a custom haptic pattern
    func playCustomHaptic(intensity: Float, sharpness: Float, duration: TimeInterval) {
        guard isEnabled, isHapticsSupported, let engine = engine else { return }
        
        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensityParam, sharpnessParam],
            relativeTime: 0,
            duration: duration
        )
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Fallback to standard haptic
            impactMedium.impactOccurred()
        }
    }
    
    /// Play a continuous haptic (for things like rumble)
    func playContinuousHaptic(intensity: Float, sharpness: Float, duration: TimeInterval) {
        guard isEnabled, isHapticsSupported, let engine = engine else { return }
        
        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intensityParam, sharpnessParam],
            relativeTime: 0,
            duration: duration
        )
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Ignore errors for continuous haptics
        }
    }
}

// MARK: - Haptic Type

enum HapticType {
    case light, medium, heavy, soft, rigid
    case selection
    case success, warning, error
    case button, dpad
    
    func trigger() {
        let manager = HapticManager.shared
        
        switch self {
        case .light: manager.lightImpact()
        case .medium: manager.mediumImpact()
        case .heavy: manager.heavyImpact()
        case .soft: manager.softImpact()
        case .rigid: manager.rigidImpact()
        case .selection: manager.selectionChanged()
        case .success: manager.success()
        case .warning: manager.warning()
        case .error: manager.error()
        case .button: manager.buttonPress()
        case .dpad: manager.dpadPress()
        }
    }
}
