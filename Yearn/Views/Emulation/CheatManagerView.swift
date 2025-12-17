//
//  CheatManagerView.swift
//  Yearn
//
//  Cheat code management view
//

import SwiftUI

// MARK: - Cheat Model

struct Cheat: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var code: String
    var isEnabled: Bool
    var system: String
    var gameID: UUID
    
    init(id: UUID = UUID(), name: String, code: String, isEnabled: Bool = false, system: String, gameID: UUID) {
        self.id = id
        self.name = name
        self.code = code
        self.isEnabled = isEnabled
        self.system = system
        self.gameID = gameID
    }
}

// MARK: - Cheat Manager

@MainActor
class CheatManager: ObservableObject {
    static let shared = CheatManager()
    
    @Published var cheats: [Cheat] = []
    
    private let userDefaults = UserDefaults.standard
    private let cheatsKey = "savedCheats"
    
    private init() {
        loadCheats()
    }
    
    // MARK: - Public Methods
    
    func cheats(for gameID: UUID) -> [Cheat] {
        cheats.filter { $0.gameID == gameID }
    }
    
    func addCheat(_ cheat: Cheat) {
        cheats.append(cheat)
        saveCheats()
    }
    
    func updateCheat(_ cheat: Cheat) {
        if let index = cheats.firstIndex(where: { $0.id == cheat.id }) {
            cheats[index] = cheat
            saveCheats()
        }
    }
    
    func deleteCheat(_ cheat: Cheat) {
        cheats.removeAll { $0.id == cheat.id }
        saveCheats()
    }
    
    func toggleCheat(_ cheat: Cheat) {
        if let index = cheats.firstIndex(where: { $0.id == cheat.id }) {
            cheats[index].isEnabled.toggle()
            saveCheats()
        }
    }
    
    func enabledCheats(for gameID: UUID) -> [Cheat] {
        cheats.filter { $0.gameID == gameID && $0.isEnabled }
    }
    
    // MARK: - Persistence
    
    private func loadCheats() {
        guard let data = userDefaults.data(forKey: cheatsKey),
              let decoded = try? JSONDecoder().decode([Cheat].self, from: data) else {
            return
        }
        cheats = decoded
    }
    
    private func saveCheats() {
        guard let data = try? JSONEncoder().encode(cheats) else { return }
        userDefaults.set(data, forKey: cheatsKey)
    }
}

// MARK: - Cheat Manager View

struct CheatManagerView: View {
    let game: Game
    @ObservedObject var cheatManager = CheatManager.shared
    @State private var showingAddCheat = false
    @State private var editingCheat: Cheat?
    @Environment(\.dismiss) var dismiss
    
    var gameCheats: [Cheat] {
        cheatManager.cheats(for: game.id)
    }
    
    var body: some View {
        NavigationView {
            List {
                if gameCheats.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "wand.and.stars")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No Cheats")
                                .font(.headline)
                            Text("Add cheat codes to enhance your gameplay.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                } else {
                    Section {
                        ForEach(gameCheats) { cheat in
                            CheatRow(cheat: cheat) {
                                cheatManager.toggleCheat(cheat)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    cheatManager.deleteCheat(cheat)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    editingCheat = cheat
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                        }
                    } header: {
                        Text("Cheats")
                    } footer: {
                        Text("Enabled cheats will be applied when the game runs.")
                    }
                }
                
                Section {
                    CheatFormatInfo(system: game.system)
                }
            }
            .navigationTitle("Cheats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddCheat = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCheat) {
                AddCheatView(game: game)
            }
            .sheet(item: $editingCheat) { cheat in
                EditCheatView(cheat: cheat)
            }
        }
    }
}

// MARK: - Cheat Row

struct CheatRow: View {
    let cheat: Cheat
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(cheat.name)
                    .font(.headline)
                Text(cheat.code)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { cheat.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
    }
}

// MARK: - Add Cheat View

struct AddCheatView: View {
    let game: Game
    @ObservedObject var cheatManager = CheatManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var code = ""
    
    var isValid: Bool {
        !name.isEmpty && !code.isEmpty && isValidCheatCode(code)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Cheat Name", text: $name)
                    TextField("Cheat Code", text: $code)
                        .fontDesign(.monospaced)
                        .autocapitalization(.allCharacters)
                        .autocorrectionDisabled()
                } header: {
                    Text("Cheat Details")
                } footer: {
                    Text(cheatFormatDescription(for: game.system))
                }
                
                Section {
                    CheatFormatInfo(system: game.system)
                }
            }
            .navigationTitle("Add Cheat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let cheat = Cheat(
                            name: name,
                            code: code.uppercased(),
                            isEnabled: true,
                            system: game.system.rawValue,
                            gameID: game.id
                        )
                        cheatManager.addCheat(cheat)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private func isValidCheatCode(_ code: String) -> Bool {
        // Basic validation - hex characters and common separators
        let cleanCode = code.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
        
        return cleanCode.allSatisfy { $0.isHexDigit }
    }
    
    private func cheatFormatDescription(for system: GameSystem) -> String {
        switch system {
        case .nes:
            return "Use Game Genie format (e.g., SXIOPO)"
        case .snes:
            return "Use Game Genie or Pro Action Replay format"
        case .gbc:
            return "Use Game Genie or GameShark format"
        case .gba:
            return "Use GameShark or CodeBreaker format"
        case .n64:
            return "Use GameShark format (e.g., 8033B21E 00FF)"
        case .nds:
            return "Use Action Replay format"
        case .genesis:
            return "Use Game Genie format (e.g., RFKA-A6WL)"
        case .ps1:
            return "Use GameShark format (e.g., 800A1234 00FF)"
        }
    }
}

// MARK: - Edit Cheat View

struct EditCheatView: View {
    let cheat: Cheat
    @ObservedObject var cheatManager = CheatManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String
    @State private var code: String
    
    init(cheat: Cheat) {
        self.cheat = cheat
        _name = State(initialValue: cheat.name)
        _code = State(initialValue: cheat.code)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Cheat Details") {
                    TextField("Cheat Name", text: $name)
                    TextField("Cheat Code", text: $code)
                        .fontDesign(.monospaced)
                        .autocapitalization(.allCharacters)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Edit Cheat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updatedCheat = cheat
                        updatedCheat.name = name
                        updatedCheat.code = code.uppercased()
                        cheatManager.updateCheat(updatedCheat)
                        dismiss()
                    }
                    .disabled(name.isEmpty || code.isEmpty)
                }
            }
        }
    }
}

// MARK: - Cheat Format Info

struct CheatFormatInfo: View {
    let system: GameSystem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Supported Formats")
                .font(.headline)
            
            ForEach(supportedFormats, id: \.self) { format in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text(format)
                        .font(.caption)
                }
            }
        }
        .foregroundStyle(.secondary)
    }
    
    var supportedFormats: [String] {
        switch system {
        case .nes:
            return ["Game Genie (6 or 8 characters)"]
        case .snes:
            return ["Game Genie (XXXX-XXXX)", "Pro Action Replay"]
        case .gbc:
            return ["Game Genie", "GameShark"]
        case .gba:
            return ["GameShark v1/v3", "CodeBreaker", "Action Replay"]
        case .n64:
            return ["GameShark (8 hex + space + 4 hex)"]
        case .nds:
            return ["Action Replay DS"]
        case .genesis:
            return ["Game Genie (XXXX-XXXX)"]
        case .ps1:
            return ["GameShark (8 hex + space + 4 hex)"]
        }
    }
}

#Preview {
    CheatManagerView(game: Game(
        name: "Test Game",
        fileURL: URL(fileURLWithPath: "/test.nes"),
        system: .nes
    ))
}

