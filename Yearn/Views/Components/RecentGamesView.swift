//
//  RecentGamesView.swift
//  Yearn
//
//  Recent games carousel component
//

import SwiftUI

struct RecentGamesView: View {
    let games: [Game]
    let onGameSelected: (Game) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Continue Playing")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                if games.count > 3 {
                    Button("See All") {
                        // Navigate to full list
                    }
                    .font(.subheadline)
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(games.prefix(10)) { game in
                        RecentGameCard(game: game)
                            .onTapGesture {
                                onGameSelected(game)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct RecentGameCard: View {
    let game: Game
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Game artwork
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [game.system.color.opacity(0.3), game.system.color.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 100)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: game.system.iconName)
                            .font(.system(size: 28))
                            .foregroundStyle(game.system.color)
                        
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .overlay(alignment: .topTrailing) {
                    Text(game.system.shortName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(game.system.color.opacity(0.8))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeOut(duration: 0.1), value: isPressed)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(game.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let lastPlayed = game.lastPlayed {
                    Text(lastPlayed.timeAgoDisplay())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 140, alignment: .leading)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Date Extension

extension Date {
    func timeAgoDisplay() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfYear], from: self, to: now)
        
        if let weeks = components.weekOfYear, weeks >= 1 {
            return weeks == 1 ? "Last week" : "\(weeks) weeks ago"
        }
        
        if let days = components.day, days >= 1 {
            return days == 1 ? "Yesterday" : "\(days) days ago"
        }
        
        if let hours = components.hour, hours >= 1 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        }
        
        if let minutes = components.minute, minutes >= 1 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        }
        
        return "Just now"
    }
}

#Preview {
    RecentGamesView(
        games: [
            Game(name: "Super Mario Bros", fileURL: URL(fileURLWithPath: "/test.nes"), system: .nes, lastPlayed: Date().addingTimeInterval(-3600)),
            Game(name: "Pokemon Red", fileURL: URL(fileURLWithPath: "/test.gb"), system: .gbc, lastPlayed: Date().addingTimeInterval(-86400)),
            Game(name: "Zelda ALTTP", fileURL: URL(fileURLWithPath: "/test.sfc"), system: .snes, lastPlayed: Date().addingTimeInterval(-172800))
        ],
        onGameSelected: { _ in }
    )
}

