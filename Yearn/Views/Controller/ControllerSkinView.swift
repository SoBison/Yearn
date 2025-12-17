//
//  ControllerSkinView.swift
//  Yearn
//
//  Controller skin system for customizable virtual controllers
//

import SwiftUI

// MARK: - Controller Skin

struct ControllerSkin: Identifiable, Codable {
    let id: UUID
    var name: String
    var author: String
    var version: String
    var supportedSystems: [GameSystem]
    
    // Layout configuration
    var dpadPosition: CGPoint
    var dpadSize: CGFloat
    var buttonsPosition: CGPoint
    var buttonSize: CGFloat
    var buttonSpacing: CGFloat
    var startSelectPosition: CGPoint
    var shoulderPosition: CGPoint
    
    // Style configuration
    var backgroundColor: CodableColor
    var buttonColor: CodableColor
    var buttonPressedColor: CodableColor
    var dpadColor: CodableColor
    var opacity: Double
    var buttonStyle: ButtonStyle
    
    enum ButtonStyle: String, Codable, CaseIterable {
        case circle
        case rounded
        case square
        
        var cornerRadius: CGFloat {
            switch self {
            case .circle: return 50
            case .rounded: return 12
            case .square: return 4
            }
        }
    }
    
    // Default skin
    static let `default` = ControllerSkin(
        id: UUID(),
        name: "Default",
        author: "Yearn",
        version: "1.0",
        supportedSystems: GameSystem.allCases,
        dpadPosition: CGPoint(x: 80, y: -100),
        dpadSize: 120,
        buttonsPosition: CGPoint(x: -80, y: -100),
        buttonSize: 50,
        buttonSpacing: 60,
        startSelectPosition: CGPoint(x: 0, y: -30),
        shoulderPosition: CGPoint(x: 0, y: -180),
        backgroundColor: CodableColor(color: .black.opacity(0.3)),
        buttonColor: CodableColor(color: .white.opacity(0.3)),
        buttonPressedColor: CodableColor(color: .white.opacity(0.6)),
        dpadColor: CodableColor(color: .white.opacity(0.3)),
        opacity: 1.0,
        buttonStyle: .circle
    )
    
    // Minimal skin
    static let minimal = ControllerSkin(
        id: UUID(),
        name: "Minimal",
        author: "Yearn",
        version: "1.0",
        supportedSystems: GameSystem.allCases,
        dpadPosition: CGPoint(x: 60, y: -80),
        dpadSize: 100,
        buttonsPosition: CGPoint(x: -60, y: -80),
        buttonSize: 40,
        buttonSpacing: 50,
        startSelectPosition: CGPoint(x: 0, y: -20),
        shoulderPosition: CGPoint(x: 0, y: -150),
        backgroundColor: CodableColor(color: .clear),
        buttonColor: CodableColor(color: .white.opacity(0.2)),
        buttonPressedColor: CodableColor(color: .white.opacity(0.5)),
        dpadColor: CodableColor(color: .white.opacity(0.2)),
        opacity: 0.8,
        buttonStyle: .circle
    )
    
    // Retro skin
    static let retro = ControllerSkin(
        id: UUID(),
        name: "Retro",
        author: "Yearn",
        version: "1.0",
        supportedSystems: GameSystem.allCases,
        dpadPosition: CGPoint(x: 90, y: -110),
        dpadSize: 130,
        buttonsPosition: CGPoint(x: -90, y: -110),
        buttonSize: 55,
        buttonSpacing: 65,
        startSelectPosition: CGPoint(x: 0, y: -35),
        shoulderPosition: CGPoint(x: 0, y: -200),
        backgroundColor: CodableColor(color: Color(white: 0.15)),
        buttonColor: CodableColor(color: Color(red: 0.8, green: 0.2, blue: 0.2)),
        buttonPressedColor: CodableColor(color: Color(red: 1.0, green: 0.3, blue: 0.3)),
        dpadColor: CodableColor(color: Color(white: 0.3)),
        opacity: 1.0,
        buttonStyle: .rounded
    )
    
    // Neon skin - 霓虹灯风格
    static let neon = ControllerSkin(
        id: UUID(),
        name: "Neon",
        author: "Yearn",
        version: "1.0",
        supportedSystems: GameSystem.allCases,
        dpadPosition: CGPoint(x: 85, y: -105),
        dpadSize: 125,
        buttonsPosition: CGPoint(x: -85, y: -105),
        buttonSize: 52,
        buttonSpacing: 62,
        startSelectPosition: CGPoint(x: 0, y: -32),
        shoulderPosition: CGPoint(x: 0, y: -190),
        backgroundColor: CodableColor(color: Color(red: 0.05, green: 0.0, blue: 0.1).opacity(0.8)),
        buttonColor: CodableColor(color: Color(red: 0.0, green: 1.0, blue: 0.8).opacity(0.7)),       // 青色霓虹
        buttonPressedColor: CodableColor(color: Color(red: 1.0, green: 0.0, blue: 0.8).opacity(0.9)), // 粉色霓虹
        dpadColor: CodableColor(color: Color(red: 0.8, green: 0.0, blue: 1.0).opacity(0.7)),         // 紫色霓虹
        opacity: 1.0,
        buttonStyle: .circle
    )
    
    // Classic Nintendo skin - 经典任天堂配色
    static let classicNintendo = ControllerSkin(
        id: UUID(),
        name: "Classic Nintendo",
        author: "Yearn",
        version: "1.0",
        supportedSystems: GameSystem.allCases,
        dpadPosition: CGPoint(x: 85, y: -105),
        dpadSize: 125,
        buttonsPosition: CGPoint(x: -85, y: -105),
        buttonSize: 50,
        buttonSpacing: 60,
        startSelectPosition: CGPoint(x: 0, y: -32),
        shoulderPosition: CGPoint(x: 0, y: -185),
        backgroundColor: CodableColor(color: Color(red: 0.75, green: 0.75, blue: 0.73)),            // NES 灰色
        buttonColor: CodableColor(color: Color(red: 0.8, green: 0.15, blue: 0.2)),                  // 任天堂红
        buttonPressedColor: CodableColor(color: Color(red: 0.6, green: 0.1, blue: 0.15)),           // 深红
        dpadColor: CodableColor(color: Color(red: 0.15, green: 0.15, blue: 0.15)),                  // 黑色十字键
        opacity: 1.0,
        buttonStyle: .circle
    )
    
    // PlayStation skin - PlayStation 风格
    static let playStation = ControllerSkin(
        id: UUID(),
        name: "PlayStation",
        author: "Yearn",
        version: "1.0",
        supportedSystems: GameSystem.allCases,
        dpadPosition: CGPoint(x: 80, y: -100),
        dpadSize: 115,
        buttonsPosition: CGPoint(x: -80, y: -100),
        buttonSize: 48,
        buttonSpacing: 58,
        startSelectPosition: CGPoint(x: 0, y: -30),
        shoulderPosition: CGPoint(x: 0, y: -180),
        backgroundColor: CodableColor(color: Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.9)), // 深蓝黑
        buttonColor: CodableColor(color: Color(red: 0.0, green: 0.45, blue: 0.75).opacity(0.8)),    // PlayStation 蓝
        buttonPressedColor: CodableColor(color: Color(red: 0.0, green: 0.6, blue: 1.0)),            // 亮蓝
        dpadColor: CodableColor(color: Color(red: 0.3, green: 0.3, blue: 0.35).opacity(0.8)),       // 灰色
        opacity: 1.0,
        buttonStyle: .circle
    )
    
    // Xbox skin - Xbox 风格
    static let xbox = ControllerSkin(
        id: UUID(),
        name: "Xbox",
        author: "Yearn",
        version: "1.0",
        supportedSystems: GameSystem.allCases,
        dpadPosition: CGPoint(x: 85, y: -105),
        dpadSize: 120,
        buttonsPosition: CGPoint(x: -85, y: -105),
        buttonSize: 50,
        buttonSpacing: 60,
        startSelectPosition: CGPoint(x: 0, y: -32),
        shoulderPosition: CGPoint(x: 0, y: -185),
        backgroundColor: CodableColor(color: Color(red: 0.1, green: 0.1, blue: 0.1).opacity(0.9)),  // 深黑
        buttonColor: CodableColor(color: Color(red: 0.0, green: 0.5, blue: 0.0).opacity(0.8)),      // Xbox 绿
        buttonPressedColor: CodableColor(color: Color(red: 0.1, green: 0.8, blue: 0.1)),            // 亮绿
        dpadColor: CodableColor(color: Color(red: 0.25, green: 0.25, blue: 0.25).opacity(0.8)),     // 深灰
        opacity: 1.0,
        buttonStyle: .circle
    )
    
    // Transparent skin - 完全透明轮廓
    static let transparent = ControllerSkin(
        id: UUID(),
        name: "Transparent",
        author: "Yearn",
        version: "1.0",
        supportedSystems: GameSystem.allCases,
        dpadPosition: CGPoint(x: 75, y: -95),
        dpadSize: 110,
        buttonsPosition: CGPoint(x: -75, y: -95),
        buttonSize: 45,
        buttonSpacing: 55,
        startSelectPosition: CGPoint(x: 0, y: -25),
        shoulderPosition: CGPoint(x: 0, y: -170),
        backgroundColor: CodableColor(color: Color.clear),
        buttonColor: CodableColor(color: Color.white.opacity(0.15)),                                // 极淡轮廓
        buttonPressedColor: CodableColor(color: Color.white.opacity(0.4)),                          // 按下时稍亮
        dpadColor: CodableColor(color: Color.white.opacity(0.15)),                                  // 极淡轮廓
        opacity: 0.6,
        buttonStyle: .circle
    )
    
    // Dark Mode skin - 深色模式优化
    static let darkMode = ControllerSkin(
        id: UUID(),
        name: "Dark Mode",
        author: "Yearn",
        version: "1.0",
        supportedSystems: GameSystem.allCases,
        dpadPosition: CGPoint(x: 80, y: -100),
        dpadSize: 120,
        buttonsPosition: CGPoint(x: -80, y: -100),
        buttonSize: 50,
        buttonSpacing: 60,
        startSelectPosition: CGPoint(x: 0, y: -30),
        shoulderPosition: CGPoint(x: 0, y: -180),
        backgroundColor: CodableColor(color: Color(red: 0.08, green: 0.08, blue: 0.08).opacity(0.95)), // 纯黑背景
        buttonColor: CodableColor(color: Color(red: 0.2, green: 0.2, blue: 0.22).opacity(0.9)),        // 深灰按钮
        buttonPressedColor: CodableColor(color: Color(red: 0.35, green: 0.35, blue: 0.4)),             // 中灰按下
        dpadColor: CodableColor(color: Color(red: 0.18, green: 0.18, blue: 0.2).opacity(0.9)),         // 深灰十字键
        opacity: 1.0,
        buttonStyle: .rounded
    )
    
    // All built-in skins
    static let allBuiltIn: [ControllerSkin] = [
        .default, .minimal, .retro, .neon, .classicNintendo, .playStation, .xbox, .transparent, .darkMode
    ]
}

// MARK: - Codable Color

struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double
    
    init(color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.opacity = Double(a)
    }
    
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

// MARK: - Controller Skin Manager

class ControllerSkinManager: ObservableObject {
    static let shared = ControllerSkinManager()
    
    @Published var availableSkins: [ControllerSkin] = []
    @Published var currentSkin: ControllerSkin
    
    private let skinsDirectory: URL
    private let currentSkinKey = "currentControllerSkin"
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        skinsDirectory = documentsPath.appendingPathComponent("ControllerSkins", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: skinsDirectory, withIntermediateDirectories: true)
        
        // Load current skin or use default
        if let data = UserDefaults.standard.data(forKey: currentSkinKey),
           let skin = try? JSONDecoder().decode(ControllerSkin.self, from: data) {
            currentSkin = skin
        } else {
            currentSkin = .default
        }
        
        loadSkins()
    }
    
    // MARK: - Load Skins
    
    func loadSkins() {
        var skins: [ControllerSkin] = ControllerSkin.allBuiltIn
        
        // Load custom skins from directory
        if let files = try? FileManager.default.contentsOfDirectory(at: skinsDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file),
                   let skin = try? JSONDecoder().decode(ControllerSkin.self, from: data) {
                    skins.append(skin)
                }
            }
        }
        
        availableSkins = skins
    }
    
    // MARK: - Save Current Skin
    
    func setCurrentSkin(_ skin: ControllerSkin) {
        currentSkin = skin
        
        if let data = try? JSONEncoder().encode(skin) {
            UserDefaults.standard.set(data, forKey: currentSkinKey)
        }
    }
    
    // MARK: - Save Custom Skin
    
    func saveSkin(_ skin: ControllerSkin) throws {
        let fileURL = skinsDirectory.appendingPathComponent("\(skin.id.uuidString).json")
        let data = try JSONEncoder().encode(skin)
        try data.write(to: fileURL)
        loadSkins()
    }
    
    // MARK: - Delete Skin
    
    func deleteSkin(_ skin: ControllerSkin) throws {
        let fileURL = skinsDirectory.appendingPathComponent("\(skin.id.uuidString).json")
        try FileManager.default.removeItem(at: fileURL)
        loadSkins()
    }
}

// MARK: - Controller Skin Picker View

struct ControllerSkinPickerView: View {
    @ObservedObject private var skinManager = ControllerSkinManager.shared
    @Environment(\.dismiss) private var dismiss
    
    private let builtInSkinIds = ControllerSkin.allBuiltIn.map { $0.id }
    
    var body: some View {
        NavigationStack {
            List {
                // Standard skins
                Section("Standard") {
                    ForEach([ControllerSkin.default, .minimal, .retro]) { skin in
                        SkinRow(skin: skin, isSelected: skinManager.currentSkin.name == skin.name) {
                            skinManager.setCurrentSkin(skin)
                        }
                    }
                }
                
                // Themed skins
                Section("Themed") {
                    ForEach([ControllerSkin.neon, .classicNintendo, .playStation, .xbox]) { skin in
                        SkinRow(skin: skin, isSelected: skinManager.currentSkin.name == skin.name) {
                            skinManager.setCurrentSkin(skin)
                        }
                    }
                }
                
                // Special skins
                Section("Special") {
                    ForEach([ControllerSkin.transparent, .darkMode]) { skin in
                        SkinRow(skin: skin, isSelected: skinManager.currentSkin.name == skin.name) {
                            skinManager.setCurrentSkin(skin)
                        }
                    }
                }
                
                // Custom skins
                let customSkins = skinManager.availableSkins.filter { skin in
                    !ControllerSkin.allBuiltIn.contains(where: { $0.name == skin.name })
                }
                
                if !customSkins.isEmpty {
                    Section("Custom Skins") {
                        ForEach(customSkins) { skin in
                            SkinRow(skin: skin, isSelected: skinManager.currentSkin.id == skin.id) {
                                skinManager.setCurrentSkin(skin)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                try? skinManager.deleteSkin(customSkins[index])
                            }
                        }
                    }
                }
                
                Section {
                    NavigationLink {
                        ControllerSkinEditorView()
                    } label: {
                        Label("Create Custom Skin", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Controller Skins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Skin Row

struct SkinRow: View {
    let skin: ControllerSkin
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                // Preview
                SkinPreviewView(skin: skin)
                    .frame(width: 80, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(skin.name)
                        .font(.headline)
                    
                    Text("by \(skin.author)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Skin Preview View

struct SkinPreviewView: View {
    let skin: ControllerSkin
    
    var body: some View {
        ZStack {
            skin.backgroundColor.color
            
            HStack(spacing: 20) {
                // D-Pad preview
                Circle()
                    .fill(skin.dpadColor.color)
                    .frame(width: 20, height: 20)
                
                // Buttons preview
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { _ in
                        Circle()
                            .fill(skin.buttonColor.color)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .opacity(skin.opacity)
    }
}

// MARK: - Controller Skin Editor View

struct ControllerSkinEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var skinManager = ControllerSkinManager.shared
    
    @State private var skin = ControllerSkin.default
    @State private var name = "My Custom Skin"
    @State private var showSaveError = false
    
    var body: some View {
        Form {
            Section("Basic Info") {
                TextField("Name", text: $name)
            }
            
            Section("Button Style") {
                Picker("Style", selection: $skin.buttonStyle) {
                    ForEach(ControllerSkin.ButtonStyle.allCases, id: \.self) { style in
                        Text(style.rawValue.capitalized).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("Sizes") {
                VStack(alignment: .leading) {
                    Text("D-Pad Size: \(Int(skin.dpadSize))")
                    Slider(value: $skin.dpadSize, in: 80...160, step: 10)
                }
                
                VStack(alignment: .leading) {
                    Text("Button Size: \(Int(skin.buttonSize))")
                    Slider(value: $skin.buttonSize, in: 30...70, step: 5)
                }
                
                VStack(alignment: .leading) {
                    Text("Button Spacing: \(Int(skin.buttonSpacing))")
                    Slider(value: $skin.buttonSpacing, in: 40...80, step: 5)
                }
            }
            
            Section("Opacity") {
                VStack(alignment: .leading) {
                    Text("Overall Opacity: \(Int(skin.opacity * 100))%")
                    Slider(value: $skin.opacity, in: 0.3...1.0, step: 0.1)
                }
            }
            
            Section("Preview") {
                SkinPreviewView(skin: skin)
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .navigationTitle("Create Skin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveSkin()
                }
            }
        }
        .alert("Error", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Failed to save skin")
        }
    }
    
    private func saveSkin() {
        var newSkin = skin
        newSkin.name = name
        newSkin.author = "Custom"
        
        do {
            try skinManager.saveSkin(newSkin)
            dismiss()
        } catch {
            showSaveError = true
        }
    }
}

#Preview {
    ControllerSkinPickerView()
}

