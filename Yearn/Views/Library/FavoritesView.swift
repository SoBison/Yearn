//
//  FavoritesView.swift
//  Yearn
//
//  Favorites games view
//

import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject private var biosManager = BIOSManager.shared
    @State private var showingGameInfo: Game?
    @State private var showingBIOSAlert = false
    @State private var pendingGame: Game?
    
    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.favoriteGames.isEmpty {
                    EmptyFavoritesView()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(viewModel.favoriteGames) { game in
                                FavoriteGameCard(game: game)
                                    .onTapGesture {
                                        launchGame(game)
                                    }
                                    .contextMenu {
                                        Button {
                                            launchGame(game)
                                        } label: {
                                            Label("Play", systemImage: "play.fill")
                                        }
                                        
                                        Button {
                                            showingGameInfo = game
                                        } label: {
                                            Label("Info", systemImage: "info.circle")
                                        }
                                        
                                        Button {
                                            viewModel.toggleFavorite(game)
                                        } label: {
                                            Label("Remove from Favorites", systemImage: "heart.slash")
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Favorites")
            .sheet(item: $showingGameInfo) { game in
                GameInfoView(game: game)
            }
            // BIOS 缺失提示弹窗
            .alert("bios.alert.title".localized, isPresented: $showingBIOSAlert) {
                Button("bios.alert.goToSettings".localized) {
                    NotificationCenter.default.post(name: .openBIOSSettings, object: nil)
                    pendingGame = nil
                }
                Button("common.cancel".localized, role: .cancel) {
                    pendingGame = nil
                }
            } message: {
                if let game = pendingGame {
                    Text("bios.alert.message.\(game.system.rawValue)".localized)
                }
            }
        }
    }
    
    /// 启动游戏前检查 BIOS 是否可用
    private func launchGame(_ game: Game) {
        // 检查是否需要 BIOS
        if game.system == .ps1 && !biosManager.checkPS1BIOSAvailable() {
            pendingGame = game
            showingBIOSAlert = true
            return
        }
        
        viewModel.recordGamePlayed(game)
        appState.currentGame = game
        appState.isEmulating = true
    }
}

// MARK: - Empty Favorites View

struct EmptyFavoritesView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Favorites", systemImage: "heart")
        } description: {
            Text("Games you mark as favorites will appear here for quick access.")
        }
    }
}

// MARK: - Favorite Game Card

struct FavoriteGameCard: View {
    let game: Game
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Game artwork
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                game.system.color.opacity(0.3),
                                game.system.color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .aspectRatio(1, contentMode: .fit)
                
                VStack(spacing: 8) {
                    Image(systemName: game.system.iconName)
                        .font(.system(size: 36))
                        .foregroundStyle(game.system.color)
                    
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.9))
                }
                
                // Favorite badge
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(8)
                    }
                    Spacer()
                }
                
                // System badge
                VStack {
                    HStack {
                        Text(game.system.shortName)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(game.system.color)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(8)
                        Spacer()
                    }
                    Spacer()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: game.system.color.opacity(0.3), radius: 8, y: 4)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
            
            // Game name
            Text(game.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

#Preview {
    FavoritesView(viewModel: LibraryViewModel())
        .environmentObject(AppState())
}

