//
//  SystemFilterView.swift
//  Yearn
//
//  System filter chips component
//

import SwiftUI

struct SystemFilterView: View {
    @Binding var selectedSystem: GameSystem?
    let gameCounts: [GameSystem: Int]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All systems chip
                FilterChip(
                    title: "All",
                    count: gameCounts.values.reduce(0, +),
                    color: .gray,
                    isSelected: selectedSystem == nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSystem = nil
                    }
                }
                
                // System chips
                ForEach(GameSystem.allCases) { system in
                    let count = gameCounts[system] ?? 0
                    if count > 0 {
                        FilterChip(
                            title: system.shortName,
                            count: count,
                            color: system.color,
                            isSelected: selectedSystem == system
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSystem = system
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct FilterChip: View {
    let title: String
    let count: Int
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text("\(count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.2)
                    )
                    .clipShape(Capsule())
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? color : Color.secondary.opacity(0.1)
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        SystemFilterView(
            selectedSystem: .constant(nil),
            gameCounts: [
                .nes: 15,
                .snes: 8,
                .gbc: 12,
                .gba: 5,
                .n64: 3,
                .genesis: 7
            ]
        )
        
        SystemFilterView(
            selectedSystem: .constant(.nes),
            gameCounts: [
                .nes: 15,
                .snes: 8,
                .gbc: 12
            ]
        )
    }
}

