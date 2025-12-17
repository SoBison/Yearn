//
//  SaveStatesView.swift
//  Yearn
//
//  Save states management view
//

import SwiftUI

struct SaveStatesView: View {
    let game: Game
    let onLoad: (SaveState) -> Void
    let onSave: (Int) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var saveStates: [SaveState] = []
    @State private var isLoading = true
    @State private var showDeleteConfirmation = false
    @State private var stateToDelete: SaveState?
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding(.top, 100)
                } else if saveStates.isEmpty {
                    emptyStateView
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        // Quick save slot
                        SaveStateCard(
                            slot: 0,
                            saveState: saveStates.first { $0.slot == 0 },
                            isQuickSave: true,
                            onLoad: { if let state = saveStates.first(where: { $0.slot == 0 }) { onLoad(state) } },
                            onSave: { onSave(0) },
                            onDelete: { if let state = saveStates.first(where: { $0.slot == 0 }) { confirmDelete(state) } }
                        )
                        
                        // Regular slots
                        ForEach(1...8, id: \.self) { slot in
                            SaveStateCard(
                                slot: slot,
                                saveState: saveStates.first { $0.slot == slot },
                                isQuickSave: false,
                                onLoad: { if let state = saveStates.first(where: { $0.slot == slot }) { onLoad(state) } },
                                onSave: { onSave(slot) },
                                onDelete: { if let state = saveStates.first(where: { $0.slot == slot }) { confirmDelete(state) } }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Save States")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Save State", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    stateToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let state = stateToDelete {
                        deleteState(state)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this save state?")
            }
            .task {
                await loadSaveStates()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Save States")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Save your progress to continue later")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 100)
    }
    
    private func loadSaveStates() async {
        isLoading = true
        // Would load from SaveStateManager
        saveStates = []
        isLoading = false
    }
    
    private func confirmDelete(_ state: SaveState) {
        stateToDelete = state
        showDeleteConfirmation = true
    }
    
    private func deleteState(_ state: SaveState) {
        saveStates.removeAll { $0.id == state.id }
        stateToDelete = nil
    }
}

// MARK: - Save State Card

struct SaveStateCard: View {
    let slot: Int
    let saveState: SaveState?
    let isQuickSave: Bool
    let onLoad: () -> Void
    let onSave: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Screenshot
            ZStack {
                if let screenshot = saveState?.screenshot {
                    Image(uiImage: screenshot)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color(.tertiarySystemGroupedBackground))
                    
                    Image(systemName: "plus")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Info
            VStack(spacing: 4) {
                Text(isQuickSave ? "Quick Save" : "Slot \(slot)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let date = saveState?.date {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Empty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2), value: isPressed)
        .onTapGesture {
            if saveState != nil {
                onLoad()
            } else {
                onSave()
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            // Long press for options
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
        .contextMenu {
            if saveState != nil {
                Button {
                    onLoad()
                } label: {
                    Label("Load", systemImage: "arrow.down.circle")
                }
            }
            
            Button {
                onSave()
            } label: {
                Label("Save", systemImage: "arrow.up.circle")
            }
            
            if saveState != nil {
                Divider()
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Save State Model

struct SaveState: Identifiable {
    let id: UUID
    let slot: Int
    let date: Date
    let screenshot: UIImage?
    let dataURL: URL
    
    init(id: UUID = UUID(), slot: Int, date: Date = Date(), screenshot: UIImage? = nil, dataURL: URL) {
        self.id = id
        self.slot = slot
        self.date = date
        self.screenshot = screenshot
        self.dataURL = dataURL
    }
}

#Preview {
    SaveStatesView(
        game: Game(name: "Test", fileURL: URL(fileURLWithPath: "/test.nes"), system: .nes),
        onLoad: { _ in },
        onSave: { _ in }
    )
}

