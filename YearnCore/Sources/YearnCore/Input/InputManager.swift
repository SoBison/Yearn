//
//  InputManager.swift
//  YearnCore
//
//  Input management for emulation with enhanced controller support
//

import Foundation
import GameController
import CoreHaptics

/// Manages input from virtual controllers and physical gamepads
public final class InputManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published public private(set) var connectedControllers: [GCController] = []
    @Published public var hideVirtualControllerWhenConnected: Bool = true
    @Published public var useLeftStickAsDPad: Bool = true
    @Published public var useRightStickForCamera: Bool = true
    @Published public var enableControllerVibration: Bool = true
    @Published public var stickDeadzone: Float = 0.15
    
    /// Whether a physical controller is currently connected
    public var hasPhysicalController: Bool {
        !connectedControllers.isEmpty
    }
    
    /// Should hide virtual controller based on settings and connection status
    public var shouldHideVirtualController: Bool {
        hideVirtualControllerWhenConnected && hasPhysicalController
    }
    
    private var inputState: [Int: [Int: Bool]] = [:] // [playerIndex: [input: pressed]]
    private var analogState: [Int: [AnalogInput: Float]] = [:] // [playerIndex: [analog: value]]
    private var inputMapping: InputMapping?
    private var customMappings: [Int: CustomButtonMapping] = [:] // [playerIndex: mapping]
    private let lock = NSLock()
    
    // Haptic engines for each controller
    private var hapticEngines: [GCController: CHHapticEngine] = [:]
    
    // MARK: - Analog Input
    
    public enum AnalogInput: Int, CaseIterable {
        case leftStickX = 0
        case leftStickY = 1
        case rightStickX = 2
        case rightStickY = 3
        case leftTrigger = 4
        case rightTrigger = 5
    }
    
    // MARK: - Initialization
    
    public init() {
        setupControllerNotifications()
        loadSettings()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        hapticEngines.values.forEach { $0.stop() }
    }
    
    // MARK: - Settings
    
    private func loadSettings() {
        hideVirtualControllerWhenConnected = UserDefaults.standard.object(forKey: "hideVirtualControllerWhenConnected") as? Bool ?? true
        useLeftStickAsDPad = UserDefaults.standard.object(forKey: "useLeftStickAsDPad") as? Bool ?? true
        useRightStickForCamera = UserDefaults.standard.object(forKey: "useRightStickForCamera") as? Bool ?? true
        enableControllerVibration = UserDefaults.standard.object(forKey: "enableControllerVibration") as? Bool ?? true
        stickDeadzone = UserDefaults.standard.object(forKey: "stickDeadzone") as? Float ?? 0.15
    }
    
    public func saveSettings() {
        UserDefaults.standard.set(hideVirtualControllerWhenConnected, forKey: "hideVirtualControllerWhenConnected")
        UserDefaults.standard.set(useLeftStickAsDPad, forKey: "useLeftStickAsDPad")
        UserDefaults.standard.set(useRightStickForCamera, forKey: "useRightStickForCamera")
        UserDefaults.standard.set(enableControllerVibration, forKey: "enableControllerVibration")
        UserDefaults.standard.set(stickDeadzone, forKey: "stickDeadzone")
    }
    
    // MARK: - Configuration
    
    /// Configure input mapping for the current system
    public func configure(mapping: InputMapping) {
        self.inputMapping = mapping
        
        // Initialize input state for all players
        for playerIndex in 0..<mapping.maxPlayers {
            inputState[playerIndex] = [:]
            analogState[playerIndex] = [:]
        }
        
        // Re-setup existing controllers with new mapping
        for controller in connectedControllers {
            setupController(controller)
        }
    }
    
    /// Set custom button mapping for a player
    public func setCustomMapping(_ mapping: CustomButtonMapping, forPlayer playerIndex: Int) {
        customMappings[playerIndex] = mapping
        saveCustomMapping(mapping, forPlayer: playerIndex)
        
        // Re-setup controllers with new mapping
        for controller in connectedControllers {
            setupController(controller)
        }
    }
    
    /// Get custom mapping for a player
    public func getCustomMapping(forPlayer playerIndex: Int) -> CustomButtonMapping? {
        if let mapping = customMappings[playerIndex] {
            return mapping
        }
        return loadCustomMapping(forPlayer: playerIndex)
    }
    
    private func saveCustomMapping(_ mapping: CustomButtonMapping, forPlayer playerIndex: Int) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(mapping) {
            UserDefaults.standard.set(data, forKey: "customMapping_\(playerIndex)")
        }
    }
    
    private func loadCustomMapping(forPlayer playerIndex: Int) -> CustomButtonMapping? {
        guard let data = UserDefaults.standard.data(forKey: "customMapping_\(playerIndex)") else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode(CustomButtonMapping.self, from: data)
    }
    
    // MARK: - Input State
    
    /// Set input state for a specific input and player
    public func setInput(_ input: Int, pressed: Bool, playerIndex: Int = 0) {
        lock.lock()
        defer { lock.unlock() }
        
        if inputState[playerIndex] == nil {
            inputState[playerIndex] = [:]
        }
        inputState[playerIndex]?[input] = pressed
    }
    
    /// Set analog input value
    public func setAnalogInput(_ input: AnalogInput, value: Float, playerIndex: Int = 0) {
        lock.lock()
        defer { lock.unlock() }
        
        if analogState[playerIndex] == nil {
            analogState[playerIndex] = [:]
        }
        analogState[playerIndex]?[input] = value
    }
    
    /// Get analog input value
    public func getAnalogInput(_ input: AnalogInput, playerIndex: Int = 0) -> Float {
        lock.lock()
        defer { lock.unlock() }
        
        return analogState[playerIndex]?[input] ?? 0
    }
    
    /// Get current input state for a player
    public func getInputState(playerIndex: Int = 0) -> [Int: Bool] {
        lock.lock()
        defer { lock.unlock() }
        
        return inputState[playerIndex] ?? [:]
    }
    
    /// Get combined input state as a bitmask
    public func getInputBitmask(playerIndex: Int = 0) -> UInt32 {
        lock.lock()
        defer { lock.unlock() }
        
        var bitmask: UInt32 = 0
        
        if let state = inputState[playerIndex] {
            for (input, pressed) in state where pressed {
                bitmask |= UInt32(1 << input)
            }
        }
        
        return bitmask
    }
    
    /// Current state for all players
    public var currentState: [[Int: Bool]] {
        lock.lock()
        defer { lock.unlock() }
        
        return (0..<4).map { inputState[$0] ?? [:] }
    }
    
    /// Reset all inputs
    public func resetInputs() {
        lock.lock()
        defer { lock.unlock() }
        
        for playerIndex in inputState.keys {
            inputState[playerIndex] = [:]
        }
        for playerIndex in analogState.keys {
            analogState[playerIndex] = [:]
        }
    }
    
    // MARK: - Controller Management
    
    private func setupControllerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect),
            name: .GCControllerDidConnect,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidDisconnect),
            name: .GCControllerDidDisconnect,
            object: nil
        )
        
        // Discover existing controllers
        GCController.startWirelessControllerDiscovery()
        updateConnectedControllers()
    }
    
    @objc private func controllerDidConnect(_ notification: Notification) {
        updateConnectedControllers()
        
        if let controller = notification.object as? GCController {
            setupController(controller)
            setupHaptics(for: controller)
            
            // Notify about controller connection
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .controllerDidConnect, object: controller)
            }
        }
    }
    
    @objc private func controllerDidDisconnect(_ notification: Notification) {
        if let controller = notification.object as? GCController {
            hapticEngines[controller]?.stop()
            hapticEngines.removeValue(forKey: controller)
            
            // Notify about controller disconnection
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .controllerDidDisconnect, object: controller)
            }
        }
        
        updateConnectedControllers()
    }
    
    private func updateConnectedControllers() {
        DispatchQueue.main.async {
            self.connectedControllers = GCController.controllers()
        }
    }
    
    private func setupController(_ controller: GCController) {
        guard let mapping = inputMapping else { return }
        
        let playerIndex = connectedControllers.firstIndex(of: controller) ?? 0
        let customMapping = getCustomMapping(forPlayer: playerIndex)
        
        // Setup extended gamepad
        if let gamepad = controller.extendedGamepad {
            setupExtendedGamepad(gamepad, playerIndex: playerIndex, mapping: mapping, customMapping: customMapping)
        }
        // Setup micro gamepad (Siri Remote, etc.)
        else if let gamepad = controller.microGamepad {
            setupMicroGamepad(gamepad, playerIndex: playerIndex, mapping: mapping)
        }
    }
    
    private func setupExtendedGamepad(_ gamepad: GCExtendedGamepad, playerIndex: Int, mapping: InputMapping, customMapping: CustomButtonMapping?) {
        let effectiveMapping = customMapping ?? CustomButtonMapping.default(for: mapping)
        
        // D-Pad
        gamepad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.setInput(effectiveMapping.dpadUp, pressed: pressed, playerIndex: playerIndex)
        }
        gamepad.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.setInput(effectiveMapping.dpadDown, pressed: pressed, playerIndex: playerIndex)
        }
        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.setInput(effectiveMapping.dpadLeft, pressed: pressed, playerIndex: playerIndex)
        }
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.setInput(effectiveMapping.dpadRight, pressed: pressed, playerIndex: playerIndex)
        }
        
        // Left Stick (can act as D-Pad)
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            guard let self = self else { return }
            
            // Store analog values
            self.setAnalogInput(.leftStickX, value: xValue, playerIndex: playerIndex)
            self.setAnalogInput(.leftStickY, value: yValue, playerIndex: playerIndex)
            
            // Convert to digital if enabled
            if self.useLeftStickAsDPad {
                let deadzone = self.stickDeadzone
                self.setInput(effectiveMapping.dpadUp, pressed: yValue > deadzone, playerIndex: playerIndex)
                self.setInput(effectiveMapping.dpadDown, pressed: yValue < -deadzone, playerIndex: playerIndex)
                self.setInput(effectiveMapping.dpadLeft, pressed: xValue < -deadzone, playerIndex: playerIndex)
                self.setInput(effectiveMapping.dpadRight, pressed: xValue > deadzone, playerIndex: playerIndex)
            }
        }
        
        // Right Stick
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            guard let self = self else { return }
            
            self.setAnalogInput(.rightStickX, value: xValue, playerIndex: playerIndex)
            self.setAnalogInput(.rightStickY, value: yValue, playerIndex: playerIndex)
            
            // For systems that support camera control (N64, PS1)
            if self.useRightStickForCamera, let cButtons = effectiveMapping.cButtons {
                let deadzone = self.stickDeadzone
                self.setInput(cButtons.up, pressed: yValue > deadzone, playerIndex: playerIndex)
                self.setInput(cButtons.down, pressed: yValue < -deadzone, playerIndex: playerIndex)
                self.setInput(cButtons.left, pressed: xValue < -deadzone, playerIndex: playerIndex)
                self.setInput(cButtons.right, pressed: xValue > deadzone, playerIndex: playerIndex)
            }
        }
        
        // Face buttons
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.setInput(effectiveMapping.buttonA, pressed: pressed, playerIndex: playerIndex)
        }
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.setInput(effectiveMapping.buttonB, pressed: pressed, playerIndex: playerIndex)
        }
        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            if let x = effectiveMapping.buttonX {
                self?.setInput(x, pressed: pressed, playerIndex: playerIndex)
            }
        }
        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            if let y = effectiveMapping.buttonY {
                self?.setInput(y, pressed: pressed, playerIndex: playerIndex)
            }
        }
        
        // Shoulder buttons
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            if let l = effectiveMapping.leftShoulder {
                self?.setInput(l, pressed: pressed, playerIndex: playerIndex)
            }
        }
        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            if let r = effectiveMapping.rightShoulder {
                self?.setInput(r, pressed: pressed, playerIndex: playerIndex)
            }
        }
        
        // Triggers (L2/R2)
        gamepad.leftTrigger.valueChangedHandler = { [weak self] _, value, pressed in
            guard let self = self else { return }
            
            self.setAnalogInput(.leftTrigger, value: value, playerIndex: playerIndex)
            
            if let l2 = effectiveMapping.leftTrigger {
                self.setInput(l2, pressed: pressed, playerIndex: playerIndex)
            }
        }
        gamepad.rightTrigger.valueChangedHandler = { [weak self] _, value, pressed in
            guard let self = self else { return }
            
            self.setAnalogInput(.rightTrigger, value: value, playerIndex: playerIndex)
            
            if let r2 = effectiveMapping.rightTrigger {
                self.setInput(r2, pressed: pressed, playerIndex: playerIndex)
            }
        }
        
        // Thumbstick buttons (L3/R3)
        gamepad.leftThumbstickButton?.pressedChangedHandler = { [weak self] _, _, pressed in
            if let l3 = effectiveMapping.leftThumbstickButton {
                self?.setInput(l3, pressed: pressed, playerIndex: playerIndex)
            }
        }
        gamepad.rightThumbstickButton?.pressedChangedHandler = { [weak self] _, _, pressed in
            if let r3 = effectiveMapping.rightThumbstickButton {
                self?.setInput(r3, pressed: pressed, playerIndex: playerIndex)
            }
        }
        
        // Start/Select
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.setInput(effectiveMapping.start, pressed: pressed, playerIndex: playerIndex)
        }
        gamepad.buttonOptions?.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.setInput(effectiveMapping.select, pressed: pressed, playerIndex: playerIndex)
        }
        
        // Home button (for pause menu)
        gamepad.buttonHome?.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .controllerHomeButtonPressed, object: nil)
                }
            }
        }
    }
    
    private func setupMicroGamepad(_ gamepad: GCMicroGamepad, playerIndex: Int, mapping: InputMapping) {
        gamepad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.setInput(mapping.up, pressed: pressed, playerIndex: playerIndex)
        }
        gamepad.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.setInput(mapping.down, pressed: pressed, playerIndex: playerIndex)
        }
        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.setInput(mapping.left, pressed: pressed, playerIndex: playerIndex)
        }
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.setInput(mapping.right, pressed: pressed, playerIndex: playerIndex)
        }
        
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.setInput(mapping.a, pressed: pressed, playerIndex: playerIndex)
        }
        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.setInput(mapping.b, pressed: pressed, playerIndex: playerIndex)
        }
    }
    
    // MARK: - Haptic Feedback
    
    private func setupHaptics(for controller: GCController) {
        guard enableControllerVibration else { return }
        
        // Check if controller supports haptics
        guard let haptics = controller.haptics else { return }
        
        // Try to create engine for the controller
        do {
            if let engine = try haptics.createEngine(withLocality: .default) {
                try engine.start()
                hapticEngines[controller] = engine
            }
        } catch {
            print("Failed to setup haptic engine: \(error)")
        }
    }
    
    /// Play haptic feedback on connected controllers
    public func playHaptic(intensity: Float = 1.0, sharpness: Float = 0.5, duration: TimeInterval = 0.1) {
        guard enableControllerVibration else { return }
        
        for (_, engine) in hapticEngines {
            playHapticOnEngine(engine, intensity: intensity, sharpness: sharpness, duration: duration)
        }
    }
    
    /// Play rumble effect (for game events like explosions, hits, etc.)
    public func playRumble(type: RumbleType) {
        guard enableControllerVibration else { return }
        
        let (intensity, sharpness, duration) = type.parameters
        playHaptic(intensity: intensity, sharpness: sharpness, duration: duration)
    }
    
    private func playHapticOnEngine(_ engine: CHHapticEngine, intensity: Float, sharpness: Float, duration: TimeInterval) {
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
            print("Failed to play haptic: \(error)")
        }
    }
    
    /// Get controller info for display
    public func getControllerInfo(_ controller: GCController) -> ControllerInfo {
        let name = controller.vendorName ?? "Unknown Controller"
        let type: PhysicalControllerType
        
        if controller.extendedGamepad != nil {
            if name.lowercased().contains("xbox") {
                type = .xbox
            } else if name.lowercased().contains("dualshock") || name.lowercased().contains("dualsense") || name.lowercased().contains("playstation") {
                type = .playstation
            } else if name.lowercased().contains("switch") || name.lowercased().contains("nintendo") {
                type = .nintendo
            } else {
                type = .mfi
            }
        } else if controller.microGamepad != nil {
            type = .siriRemote
        } else {
            type = .unknown
        }
        
        return ControllerInfo(
            name: name,
            type: type,
            playerIndex: connectedControllers.firstIndex(of: controller) ?? 0,
            batteryLevel: controller.battery?.batteryLevel,
            batteryState: controller.battery?.batteryState
        )
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let controllerDidConnect = Notification.Name("controllerDidConnect")
    static let controllerDidDisconnect = Notification.Name("controllerDidDisconnect")
    static let controllerHomeButtonPressed = Notification.Name("controllerHomeButtonPressed")
}

// MARK: - Controller Info

public struct ControllerInfo {
    public let name: String
    public let type: PhysicalControllerType
    public let playerIndex: Int
    public let batteryLevel: Float?
    public let batteryState: GCDeviceBattery.State?
    
    public var batteryIcon: String {
        guard let level = batteryLevel else { return "battery.0" }
        
        switch batteryState {
        case .charging:
            return "battery.100.bolt"
        default:
            if level > 0.75 { return "battery.100" }
            else if level > 0.5 { return "battery.75" }
            else if level > 0.25 { return "battery.50" }
            else { return "battery.25" }
        }
    }
    
    public var batteryPercentage: Int? {
        guard let level = batteryLevel else { return nil }
        return Int(level * 100)
    }
}

public enum PhysicalControllerType: String {
    case xbox = "Xbox"
    case playstation = "PlayStation"
    case nintendo = "Nintendo"
    case mfi = "MFi"
    case siriRemote = "Siri Remote"
    case unknown = "Unknown"
    
    public var icon: String {
        switch self {
        case .xbox: return "xbox.logo"
        case .playstation: return "playstation.logo"
        case .nintendo: return "logo.nintendo.switch"
        case .mfi: return "gamecontroller.fill"
        case .siriRemote: return "appletvremote.gen4.fill"
        case .unknown: return "gamecontroller"
        }
    }
}

// MARK: - Rumble Types

public enum RumbleType {
    case light       // Light feedback
    case medium      // Medium feedback
    case heavy       // Heavy feedback
    case explosion   // Explosion effect
    case hit         // Getting hit
    case collect     // Collecting item
    case success     // Success/achievement
    case failure     // Failure/death
    
    var parameters: (intensity: Float, sharpness: Float, duration: TimeInterval) {
        switch self {
        case .light:     return (0.3, 0.3, 0.05)
        case .medium:    return (0.6, 0.5, 0.1)
        case .heavy:     return (1.0, 0.8, 0.2)
        case .explosion: return (1.0, 0.2, 0.4)
        case .hit:       return (0.8, 0.7, 0.15)
        case .collect:   return (0.4, 0.9, 0.05)
        case .success:   return (0.5, 0.6, 0.3)
        case .failure:   return (0.7, 0.3, 0.5)
        }
    }
}

// MARK: - Custom Button Mapping

public struct CustomButtonMapping: Codable, Equatable {
    public var dpadUp: Int
    public var dpadDown: Int
    public var dpadLeft: Int
    public var dpadRight: Int
    public var buttonA: Int
    public var buttonB: Int
    public var buttonX: Int?
    public var buttonY: Int?
    public var leftShoulder: Int?
    public var rightShoulder: Int?
    public var leftTrigger: Int?
    public var rightTrigger: Int?
    public var leftThumbstickButton: Int?
    public var rightThumbstickButton: Int?
    public var start: Int
    public var select: Int
    public var cButtons: CButtons?
    
    public struct CButtons: Codable, Equatable {
        public var up: Int
        public var down: Int
        public var left: Int
        public var right: Int
        
        public init(up: Int, down: Int, left: Int, right: Int) {
            self.up = up
            self.down = down
            self.left = left
            self.right = right
        }
    }
    
    public init(
        dpadUp: Int,
        dpadDown: Int,
        dpadLeft: Int,
        dpadRight: Int,
        buttonA: Int,
        buttonB: Int,
        buttonX: Int? = nil,
        buttonY: Int? = nil,
        leftShoulder: Int? = nil,
        rightShoulder: Int? = nil,
        leftTrigger: Int? = nil,
        rightTrigger: Int? = nil,
        leftThumbstickButton: Int? = nil,
        rightThumbstickButton: Int? = nil,
        start: Int,
        select: Int,
        cButtons: CButtons? = nil
    ) {
        self.dpadUp = dpadUp
        self.dpadDown = dpadDown
        self.dpadLeft = dpadLeft
        self.dpadRight = dpadRight
        self.buttonA = buttonA
        self.buttonB = buttonB
        self.buttonX = buttonX
        self.buttonY = buttonY
        self.leftShoulder = leftShoulder
        self.rightShoulder = rightShoulder
        self.leftTrigger = leftTrigger
        self.rightTrigger = rightTrigger
        self.leftThumbstickButton = leftThumbstickButton
        self.rightThumbstickButton = rightThumbstickButton
        self.start = start
        self.select = select
        self.cButtons = cButtons
    }
    
    /// Create default mapping from InputMapping
    public static func `default`(for mapping: InputMapping) -> CustomButtonMapping {
        return CustomButtonMapping(
            dpadUp: mapping.up,
            dpadDown: mapping.down,
            dpadLeft: mapping.left,
            dpadRight: mapping.right,
            buttonA: mapping.a,
            buttonB: mapping.b,
            buttonX: mapping.x,
            buttonY: mapping.y,
            leftShoulder: mapping.l,
            rightShoulder: mapping.r,
            leftTrigger: mapping.l2,
            rightTrigger: mapping.r2,
            leftThumbstickButton: mapping.l3,
            rightThumbstickButton: mapping.r3,
            start: mapping.start,
            select: mapping.select,
            cButtons: mapping.cUp != nil ? CButtons(
                up: mapping.cUp!,
                down: mapping.cDown!,
                left: mapping.cLeft!,
                right: mapping.cRight!
            ) : nil
        )
    }
}

// MARK: - Input Mapping

/// Input mapping for a specific system
public struct InputMapping: Sendable {
    public let up: Int
    public let down: Int
    public let left: Int
    public let right: Int
    public let a: Int
    public let b: Int
    public let x: Int?
    public let y: Int?
    public let l: Int?
    public let r: Int?
    public let l2: Int?
    public let r2: Int?
    public let l3: Int?
    public let r3: Int?
    public let start: Int
    public let select: Int
    public let maxPlayers: Int
    
    // N64 C-buttons / PS1 right stick
    public let cUp: Int?
    public let cDown: Int?
    public let cLeft: Int?
    public let cRight: Int?
    
    public init(
        up: Int,
        down: Int,
        left: Int,
        right: Int,
        a: Int,
        b: Int,
        x: Int? = nil,
        y: Int? = nil,
        l: Int? = nil,
        r: Int? = nil,
        l2: Int? = nil,
        r2: Int? = nil,
        l3: Int? = nil,
        r3: Int? = nil,
        start: Int,
        select: Int,
        maxPlayers: Int = 2,
        cUp: Int? = nil,
        cDown: Int? = nil,
        cLeft: Int? = nil,
        cRight: Int? = nil
    ) {
        self.up = up
        self.down = down
        self.left = left
        self.right = right
        self.a = a
        self.b = b
        self.x = x
        self.y = y
        self.l = l
        self.r = r
        self.l2 = l2
        self.r2 = r2
        self.l3 = l3
        self.r3 = r3
        self.start = start
        self.select = select
        self.maxPlayers = maxPlayers
        self.cUp = cUp
        self.cDown = cDown
        self.cLeft = cLeft
        self.cRight = cRight
    }
    
    // Standard mappings for common systems
    public static let nes = InputMapping(
        up: 4, down: 5, left: 6, right: 7,
        a: 0, b: 1,
        start: 3, select: 2
    )
    
    public static let snes = InputMapping(
        up: 4, down: 5, left: 6, right: 7,
        a: 0, b: 1, x: 8, y: 9,
        l: 10, r: 11,
        start: 3, select: 2
    )
    
    public static let gbc = InputMapping(
        up: 4, down: 5, left: 6, right: 7,
        a: 0, b: 1,
        start: 3, select: 2,
        maxPlayers: 1
    )
    
    public static let gba = InputMapping(
        up: 4, down: 5, left: 6, right: 7,
        a: 0, b: 1,
        l: 10, r: 11,
        start: 3, select: 2,
        maxPlayers: 1
    )
    
    public static let n64 = InputMapping(
        up: 4, down: 5, left: 6, right: 7,
        a: 0, b: 1,
        l: 10, r: 11,
        start: 3, select: 2,
        maxPlayers: 4,
        cUp: 12, cDown: 13, cLeft: 14, cRight: 15
    )
    
    public static let nds = InputMapping(
        up: 4, down: 5, left: 6, right: 7,
        a: 0, b: 1, x: 8, y: 9,
        l: 10, r: 11,
        start: 3, select: 2,
        maxPlayers: 1
    )
    
    public static let genesis = InputMapping(
        up: 4, down: 5, left: 6, right: 7,
        a: 0, b: 1, x: 8,  // Genesis has A, B, C (mapped to X)
        y: 9,  // Genesis 6-button has X, Y, Z
        start: 3, select: 2,  // Mode button
        maxPlayers: 2
    )
    
    public static let ps1 = InputMapping(
        up: 4, down: 5, left: 6, right: 7,
        a: 0,  // Cross
        b: 1,  // Circle
        x: 8,  // Square
        y: 9,  // Triangle
        l: 10, r: 11,  // L1, R1
        l2: 12, r2: 13,  // L2, R2
        l3: 14, r3: 15,  // L3, R3
        start: 3, select: 2,
        maxPlayers: 2
    )
}
