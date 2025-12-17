//
//  AccessibilitySettingsView.swift
//  Yearn
//
//  Accessibility settings and features
//

import SwiftUI

// MARK: - Accessibility Settings View

struct AccessibilitySettingsView: View {
    @AppStorage("accessibilityReduceMotion") private var reduceMotion = false
    @AppStorage("accessibilityHighContrast") private var highContrast = false
    @AppStorage("accessibilityLargeButtons") private var largeButtons = false
    @AppStorage("accessibilityButtonLabels") private var showButtonLabels = false
    @AppStorage("accessibilityVoiceOverHints") private var voiceOverHints = true
    @AppStorage("accessibilityHoldToConfirm") private var holdToConfirm = false
    @AppStorage("accessibilityAutoHideControls") private var autoHideControls = true
    @AppStorage("accessibilityControlsHideDelay") private var controlsHideDelay = 3.0
    
    var body: some View {
        Form {
            Section {
                Toggle("Reduce Motion", isOn: $reduceMotion)
                Toggle("High Contrast", isOn: $highContrast)
            } header: {
                Text("Visual")
            } footer: {
                Text("Reduce motion disables animations. High contrast increases button visibility.")
            }
            
            Section {
                Toggle("Large Buttons", isOn: $largeButtons)
                Toggle("Show Button Labels", isOn: $showButtonLabels)
            } header: {
                Text("Controls")
            } footer: {
                Text("Large buttons increases touch targets. Labels show A, B, X, Y text on buttons.")
            }
            
            Section {
                Toggle("VoiceOver Hints", isOn: $voiceOverHints)
            } header: {
                Text("VoiceOver")
            } footer: {
                Text("Provides additional hints when using VoiceOver.")
            }
            
            Section {
                Toggle("Hold to Confirm", isOn: $holdToConfirm)
            } header: {
                Text("Safety")
            } footer: {
                Text("Require holding buttons for destructive actions like deleting games or save states.")
            }
            
            Section {
                Toggle("Auto-Hide Controls", isOn: $autoHideControls)
                
                if autoHideControls {
                    VStack(alignment: .leading) {
                        Text("Hide Delay: \(Int(controlsHideDelay))s")
                        Slider(value: $controlsHideDelay, in: 1...10, step: 1)
                    }
                }
            } header: {
                Text("Display")
            } footer: {
                Text("Automatically hide on-screen controls after inactivity.")
            }
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Accessibility Environment

struct AccessibilitySettings {
    static var reduceMotion: Bool {
        UserDefaults.standard.bool(forKey: "accessibilityReduceMotion")
    }
    
    static var highContrast: Bool {
        UserDefaults.standard.bool(forKey: "accessibilityHighContrast")
    }
    
    static var largeButtons: Bool {
        UserDefaults.standard.bool(forKey: "accessibilityLargeButtons")
    }
    
    static var showButtonLabels: Bool {
        UserDefaults.standard.bool(forKey: "accessibilityButtonLabels")
    }
    
    static var voiceOverHints: Bool {
        UserDefaults.standard.bool(forKey: "accessibilityVoiceOverHints")
    }
    
    static var holdToConfirm: Bool {
        UserDefaults.standard.bool(forKey: "accessibilityHoldToConfirm")
    }
    
    static var autoHideControls: Bool {
        UserDefaults.standard.bool(forKey: "accessibilityAutoHideControls")
    }
    
    static var controlsHideDelay: Double {
        UserDefaults.standard.double(forKey: "accessibilityControlsHideDelay")
    }
}

// MARK: - Accessible Button

struct AccessibleButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label
    let accessibilityLabel: String
    let accessibilityHint: String?
    
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    
    init(
        action: @escaping () -> Void,
        accessibilityLabel: String,
        accessibilityHint: String? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.label = label
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }
    
    var body: some View {
        Button(action: action, label: label)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint ?? "")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Hold to Confirm Button

struct HoldToConfirmButton<Label: View>: View {
    let action: () -> Void
    let holdDuration: Double
    let label: () -> Label
    
    @State private var isHolding = false
    @State private var progress: Double = 0
    @State private var timer: Timer?
    
    init(
        holdDuration: Double = 1.0,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.holdDuration = holdDuration
        self.action = action
        self.label = label
    }
    
    var body: some View {
        label()
            .overlay {
                if isHolding {
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.3))
                            .frame(width: geometry.size.width * progress)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isHolding {
                            startHolding()
                        }
                    }
                    .onEnded { _ in
                        stopHolding()
                    }
            )
    }
    
    private func startHolding() {
        isHolding = true
        progress = 0
        
        let interval = 0.05
        let increment = interval / holdDuration
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            progress += increment
            
            if progress >= 1.0 {
                stopHolding()
                action()
                HapticManager.shared.success()
            }
        }
    }
    
    private func stopHolding() {
        isHolding = false
        progress = 0
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Conditional Hold Modifier

struct ConditionalHoldModifier: ViewModifier {
    let requiresHold: Bool
    let action: () -> Void
    
    func body(content: Content) -> some View {
        if requiresHold && AccessibilitySettings.holdToConfirm {
            HoldToConfirmButton(action: action) {
                content
            }
        } else {
            Button(action: action) {
                content
            }
        }
    }
}

extension View {
    func conditionalHold(requiresHold: Bool, action: @escaping () -> Void) -> some View {
        modifier(ConditionalHoldModifier(requiresHold: requiresHold, action: action))
    }
}

// MARK: - Auto-Hide Controls Modifier

struct AutoHideControlsModifier: ViewModifier {
    @Binding var isVisible: Bool
    @State private var hideTask: Task<Void, Never>?
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .animation(AccessibilitySettings.reduceMotion ? nil : .easeInOut(duration: 0.3), value: isVisible)
            .onAppear {
                scheduleHide()
            }
            .onTapGesture {
                isVisible = true
                scheduleHide()
            }
    }
    
    private func scheduleHide() {
        hideTask?.cancel()
        
        guard AccessibilitySettings.autoHideControls else { return }
        
        let delay = AccessibilitySettings.controlsHideDelay
        hideTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if !Task.isCancelled {
                await MainActor.run {
                    isVisible = false
                }
            }
        }
    }
}

extension View {
    func autoHideControls(isVisible: Binding<Bool>) -> some View {
        modifier(AutoHideControlsModifier(isVisible: isVisible))
    }
}

#Preview {
    NavigationStack {
        AccessibilitySettingsView()
    }
}

