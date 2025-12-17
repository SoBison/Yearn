//
//  QuickSaveWidget.swift
//  Yearn
//
//  Quick save/load widget for emulation
//

import SwiftUI

// MARK: - Quick Save Widget

struct QuickSaveWidget: View {
    @ObservedObject var viewModel: EmulationViewModel
    @State private var showingSaved = false
    @State private var showingLoaded = false
    @State private var quickSaveExists = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Quick Save Button
            Button {
                Task {
                    try? await viewModel.saveState(to: 0)
                    quickSaveExists = true
                    showingSaved = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showingSaved = false
                    }
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.title2)
                    Text("Save")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.blue.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Quick Load Button
            Button {
                Task {
                    try? await viewModel.loadState(from: 0)
                    showingLoaded = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showingLoaded = false
                    }
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.title2)
                    Text("Load")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(quickSaveExists ? Color.green.opacity(0.7) : Color.gray.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!quickSaveExists)
        }
        .overlay {
            if showingSaved {
                SavedIndicator(text: "Saved!")
            } else if showingLoaded {
                SavedIndicator(text: "Loaded!")
            }
        }
        .onAppear {
            checkQuickSaveExists()
        }
    }
    
    private func checkQuickSaveExists() {
        let slots = viewModel.getSaveStateSlots()
        quickSaveExists = slots.first?.exists ?? false
    }
}

// MARK: - Saved Indicator

struct SavedIndicator: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.green)
            .clipShape(Capsule())
            .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Floating Quick Actions

struct FloatingQuickActions: View {
    @ObservedObject var viewModel: EmulationViewModel
    @Binding var isExpanded: Bool
    
    @State private var showingSaved = false
    
    var body: some View {
        VStack(spacing: 12) {
            if isExpanded {
                // Quick Save
                QuickActionButton(
                    icon: "square.and.arrow.down.fill",
                    color: .blue
                ) {
                    Task {
                        try? await viewModel.saveState(to: 0)
                        showingSaved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            showingSaved = false
                        }
                    }
                }
                .transition(.scale.combined(with: .opacity))
                
                // Quick Load
                QuickActionButton(
                    icon: "square.and.arrow.up.fill",
                    color: .green
                ) {
                    Task {
                        try? await viewModel.loadState(from: 0)
                    }
                }
                .transition(.scale.combined(with: .opacity))
                
                // Screenshot
                QuickActionButton(
                    icon: "camera.fill",
                    color: .orange
                ) {
                    Task {
                        try? await viewModel.saveScreenshot()
                    }
                }
                .transition(.scale.combined(with: .opacity))
                
                // Fast Forward
                QuickActionButton(
                    icon: viewModel.isFastForwarding ? "forward.fill" : "forward",
                    color: viewModel.isFastForwarding ? .purple : .gray
                ) {
                    if viewModel.isFastForwarding {
                        viewModel.stopFastForward()
                    } else {
                        viewModel.startFastForward()
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Toggle Button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "xmark" : "ellipsis")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(isExpanded ? Color.red.opacity(0.8) : Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
        }
        .overlay {
            if showingSaved {
                Text("Saved!")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.green)
                    .clipShape(Capsule())
                    .offset(x: -70)
                    .transition(.opacity)
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.8))
                .clipShape(Circle())
        }
    }
}

// MARK: - Minimized Save State Preview

struct SaveStatePreview: View {
    let slot: SaveStateSlot
    let game: Game
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Preview image placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(game.system.color.opacity(0.2))
                .aspectRatio(4/3, contentMode: .fit)
                .overlay {
                    if slot.exists {
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(game.system.color.opacity(0.5))
                    } else {
                        VStack {
                            Image(systemName: "square.dashed")
                                .font(.title)
                            Text("Empty")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            
            // Slot info
            VStack(alignment: .leading, spacing: 2) {
                Text("Slot \(slot.index + 1)")
                    .font(.caption)
                    .fontWeight(.medium)
                
                if let date = slot.date {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 100)
    }
}

// MARK: - Save State Grid

struct SaveStateGrid: View {
    @ObservedObject var viewModel: EmulationViewModel
    let game: Game
    let onSelect: (Int, Bool) -> Void // (slot, isLoad)
    
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 12)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(viewModel.getSaveStateSlots()) { slot in
                SaveStatePreview(slot: slot, game: game)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(slot.index, slot.exists)
                    }
                    .contextMenu {
                        Button {
                            onSelect(slot.index, false)
                        } label: {
                            Label("Save Here", systemImage: "square.and.arrow.down")
                        }
                        
                        if slot.exists {
                            Button {
                                onSelect(slot.index, true)
                            } label: {
                                Label("Load", systemImage: "square.and.arrow.up")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                // Delete save state
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
            }
        }
    }
}

#Preview {
    VStack {
        QuickSaveWidget(viewModel: EmulationViewModel(game: Game(
            name: "Test",
            fileURL: URL(fileURLWithPath: "/test.nes"),
            system: .nes
        )))
        
        FloatingQuickActions(
            viewModel: EmulationViewModel(game: Game(
                name: "Test",
                fileURL: URL(fileURLWithPath: "/test.nes"),
                system: .nes
            )),
            isExpanded: .constant(true)
        )
    }
    .padding()
    .background(Color.black)
}

