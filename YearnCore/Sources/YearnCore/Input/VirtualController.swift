//
//  VirtualController.swift
//  YearnCore
//
//  Virtual controller UI component with haptic feedback
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import CoreHaptics

// MARK: - Virtual Controller View

/// A customizable virtual controller overlay
public struct VirtualControllerView: View {
    
    let layout: ControllerLayout
    let onInput: (ControllerButton, Bool) -> Void
    
    @StateObject private var hapticManager = HapticManager()
    @State private var pressedButtons: Set<ControllerButton> = []
    
    public init(layout: ControllerLayout, onInput: @escaping (ControllerButton, Bool) -> Void) {
        self.layout = layout
        self.onInput = onInput
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                // D-Pad
                DPadView(
                    pressedButtons: $pressedButtons,
                    hapticManager: hapticManager,
                    onInput: onInput
                )
                .frame(width: layout.dpadSize, height: layout.dpadSize)
                .position(dpadPosition(for: geometry.size, isLandscape: isLandscape))
                
                // Action Buttons
                ActionButtonCluster(
                    buttons: layout.actionButtons,
                    pressedButtons: $pressedButtons,
                    hapticManager: hapticManager,
                    onInput: onInput
                )
                .frame(width: layout.actionButtonsSize, height: layout.actionButtonsSize)
                .position(actionButtonsPosition(for: geometry.size, isLandscape: isLandscape))
                
                // Shoulder Buttons (if applicable)
                if layout.hasShoulderButtons {
                    HStack {
                        ShoulderButton(
                            button: .l,
                            pressedButtons: $pressedButtons,
                            hapticManager: hapticManager,
                            onInput: onInput
                        )
                        Spacer()
                        ShoulderButton(
                            button: .r,
                            pressedButtons: $pressedButtons,
                            hapticManager: hapticManager,
                            onInput: onInput
                        )
                    }
                    .padding(.horizontal, 20)
                    .position(x: geometry.size.width / 2, y: isLandscape ? 40 : 60)
                }
                
                // Start/Select Buttons
                HStack(spacing: 20) {
                    SmallButton(
                        button: .select,
                        label: "SELECT",
                        pressedButtons: $pressedButtons,
                        hapticManager: hapticManager,
                        onInput: onInput
                    )
                    SmallButton(
                        button: .start,
                        label: "START",
                        pressedButtons: $pressedButtons,
                        hapticManager: hapticManager,
                        onInput: onInput
                    )
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height - (isLandscape ? 30 : 50))
            }
        }
        .onAppear {
            hapticManager.prepareHaptics()
        }
    }
    
    private func dpadPosition(for size: CGSize, isLandscape: Bool) -> CGPoint {
        if isLandscape {
            return CGPoint(x: layout.dpadSize / 2 + 30, y: size.height / 2)
        } else {
            return CGPoint(x: layout.dpadSize / 2 + 20, y: size.height - layout.dpadSize / 2 - 100)
        }
    }
    
    private func actionButtonsPosition(for size: CGSize, isLandscape: Bool) -> CGPoint {
        if isLandscape {
            return CGPoint(x: size.width - layout.actionButtonsSize / 2 - 30, y: size.height / 2)
        } else {
            return CGPoint(x: size.width - layout.actionButtonsSize / 2 - 20, y: size.height - layout.actionButtonsSize / 2 - 100)
        }
    }
}

// MARK: - D-Pad View

struct DPadView: View {
    @Binding var pressedButtons: Set<ControllerButton>
    let hapticManager: HapticManager
    let onInput: (ControllerButton, Bool) -> Void
    
    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(.ultraThinMaterial)
                .opacity(0.8)
            
            // Direction buttons
            VStack(spacing: 0) {
                DPadButton(direction: .up, pressedButtons: $pressedButtons, hapticManager: hapticManager, onInput: onInput)
                HStack(spacing: 0) {
                    DPadButton(direction: .left, pressedButtons: $pressedButtons, hapticManager: hapticManager, onInput: onInput)
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 40, height: 40)
                    DPadButton(direction: .right, pressedButtons: $pressedButtons, hapticManager: hapticManager, onInput: onInput)
                }
                DPadButton(direction: .down, pressedButtons: $pressedButtons, hapticManager: hapticManager, onInput: onInput)
            }
        }
    }
}

struct DPadButton: View {
    let direction: ControllerButton
    @Binding var pressedButtons: Set<ControllerButton>
    let hapticManager: HapticManager
    let onInput: (ControllerButton, Bool) -> Void
    
    private var isPressed: Bool {
        pressedButtons.contains(direction)
    }
    
    var body: some View {
        Rectangle()
            .fill(isPressed ? Color.white.opacity(0.5) : Color.clear)
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            pressedButtons.insert(direction)
                            hapticManager.playButtonPress()
                            onInput(direction, true)
                        }
                    }
                    .onEnded { _ in
                        pressedButtons.remove(direction)
                        onInput(direction, false)
                    }
            )
    }
}

// MARK: - Action Button Cluster

struct ActionButtonCluster: View {
    let buttons: [ControllerButton]
    @Binding var pressedButtons: Set<ControllerButton>
    let hapticManager: HapticManager
    let onInput: (ControllerButton, Bool) -> Void
    
    var body: some View {
        ZStack {
            // 2-button layout (NES, GB)
            if buttons.count == 2 {
                HStack(spacing: 10) {
                    ActionButton(button: buttons[1], label: "B", pressedButtons: $pressedButtons, hapticManager: hapticManager, onInput: onInput)
                    ActionButton(button: buttons[0], label: "A", pressedButtons: $pressedButtons, hapticManager: hapticManager, onInput: onInput)
                }
            }
            // 4-button layout (SNES, etc.)
            else if buttons.count >= 4 {
                // Diamond layout
                ActionButton(button: .x, label: "X", pressedButtons: $pressedButtons, hapticManager: hapticManager, onInput: onInput)
                    .offset(x: 0, y: -35)
                
                ActionButton(button: .y, label: "Y", pressedButtons: $pressedButtons, hapticManager: hapticManager, onInput: onInput)
                    .offset(x: -35, y: 0)
                
                ActionButton(button: .a, label: "A", pressedButtons: $pressedButtons, hapticManager: hapticManager, onInput: onInput)
                    .offset(x: 35, y: 0)
                
                ActionButton(button: .b, label: "B", pressedButtons: $pressedButtons, hapticManager: hapticManager, onInput: onInput)
                    .offset(x: 0, y: 35)
            }
        }
    }
}

struct ActionButton: View {
    let button: ControllerButton
    let label: String
    @Binding var pressedButtons: Set<ControllerButton>
    let hapticManager: HapticManager
    let onInput: (ControllerButton, Bool) -> Void
    
    private var isPressed: Bool {
        pressedButtons.contains(button)
    }
    
    var body: some View {
        Circle()
            .fill(isPressed ? Color.white.opacity(0.7) : Color.white.opacity(0.3))
            .frame(width: 55, height: 55)
            .overlay {
                Text(label)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.3), radius: isPressed ? 2 : 4)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            pressedButtons.insert(button)
                            hapticManager.playButtonPress()
                            onInput(button, true)
                        }
                    }
                    .onEnded { _ in
                        pressedButtons.remove(button)
                        onInput(button, false)
                    }
            )
    }
}

// MARK: - Shoulder Button

struct ShoulderButton: View {
    let button: ControllerButton
    @Binding var pressedButtons: Set<ControllerButton>
    let hapticManager: HapticManager
    let onInput: (ControllerButton, Bool) -> Void
    
    private var isPressed: Bool {
        pressedButtons.contains(button)
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isPressed ? Color.white.opacity(0.7) : Color.white.opacity(0.3))
            .frame(width: 70, height: 35)
            .overlay {
                Text(button == .l ? "L" : "R")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            pressedButtons.insert(button)
                            hapticManager.playShoulderPress()
                            onInput(button, true)
                        }
                    }
                    .onEnded { _ in
                        pressedButtons.remove(button)
                        onInput(button, false)
                    }
            )
    }
}

// MARK: - Small Button (Start/Select)

struct SmallButton: View {
    let button: ControllerButton
    let label: String
    @Binding var pressedButtons: Set<ControllerButton>
    let hapticManager: HapticManager
    let onInput: (ControllerButton, Bool) -> Void
    
    private var isPressed: Bool {
        pressedButtons.contains(button)
    }
    
    var body: some View {
        Capsule()
            .fill(isPressed ? Color.white.opacity(0.5) : Color.white.opacity(0.2))
            .frame(width: 60, height: 25)
            .overlay {
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            pressedButtons.insert(button)
                            hapticManager.playSmallButtonPress()
                            onInput(button, true)
                        }
                    }
                    .onEnded { _ in
                        pressedButtons.remove(button)
                        onInput(button, false)
                    }
            )
    }
}

// MARK: - Controller Button Enum

public enum ControllerButton: Int, Hashable, CaseIterable, Sendable {
    case up = 4
    case down = 5
    case left = 6
    case right = 7
    case a = 8
    case b = 0
    case x = 9
    case y = 1
    case l = 10
    case r = 11
    case start = 3
    case select = 2
    case l2 = 12
    case r2 = 13
}

// MARK: - Controller Layout

public struct ControllerLayout: Sendable {
    public let dpadSize: CGFloat
    public let actionButtonsSize: CGFloat
    public let actionButtons: [ControllerButton]
    public let hasShoulderButtons: Bool
    
    public init(
        dpadSize: CGFloat = 120,
        actionButtonsSize: CGFloat = 120,
        actionButtons: [ControllerButton] = [.a, .b],
        hasShoulderButtons: Bool = false
    ) {
        self.dpadSize = dpadSize
        self.actionButtonsSize = actionButtonsSize
        self.actionButtons = actionButtons
        self.hasShoulderButtons = hasShoulderButtons
    }
    
    // Preset layouts
    public static let nes = ControllerLayout(actionButtons: [.a, .b])
    public static let snes = ControllerLayout(actionButtons: [.a, .b, .x, .y], hasShoulderButtons: true)
    public static let gbc = ControllerLayout(dpadSize: 100, actionButtonsSize: 100, actionButtons: [.a, .b])
    public static let gba = ControllerLayout(actionButtons: [.a, .b], hasShoulderButtons: true)
    public static let n64 = ControllerLayout(actionButtons: [.a, .b], hasShoulderButtons: true)
    public static let nds = ControllerLayout(actionButtons: [.a, .b, .x, .y], hasShoulderButtons: true)
    public static let genesis = ControllerLayout(actionButtons: [.a, .b, .x])
    public static let ps1 = ControllerLayout(actionButtons: [.a, .b, .x, .y], hasShoulderButtons: true)
}

// MARK: - Haptic Manager

@MainActor
class HapticManager: ObservableObject {
    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = false
    
    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            supportsHaptics = false
            return
        }
        
        supportsHaptics = true
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            
            engine?.resetHandler = { [weak self] in
                Task { @MainActor in
                    do {
                        try self?.engine?.start()
                    } catch {
                        print("Failed to restart haptic engine: \(error)")
                    }
                }
            }
        } catch {
            print("Failed to create haptic engine: \(error)")
            supportsHaptics = false
        }
    }
    
    func playButtonPress() {
        guard supportsHaptics else {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            return
        }
        
        playHaptic(intensity: 0.5, sharpness: 0.5)
    }
    
    func playShoulderPress() {
        guard supportsHaptics else {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            return
        }
        
        playHaptic(intensity: 0.7, sharpness: 0.3)
    }
    
    func playSmallButtonPress() {
        guard supportsHaptics else {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            #endif
            return
        }
        
        playHaptic(intensity: 0.3, sharpness: 0.7)
    }
    
    private func playHaptic(intensity: Float, sharpness: Float) {
        guard let engine = engine else { return }
        
        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensityParam, sharpnessParam],
            relativeTime: 0
        )
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error)")
        }
    }
}
