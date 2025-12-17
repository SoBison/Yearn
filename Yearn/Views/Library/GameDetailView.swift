//
//  GameDetailView.swift
//  Yearn
//
//  Detailed game information view
//

import SwiftUI

struct GameDetailView: View {
    let game: Game
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var biosManager = BIOSManager.shared
    
    @State private var showCoverPicker = false
    @State private var showDeleteConfirmation = false
    @State private var gameInfo: GameInfoResult?
    @State private var isLoadingInfo = false
    @State private var showingBIOSAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Cover image with edit button
                coverSection
                
                // Game info
                infoSection
                
                // Actions
                actionsSection
                
                // Technical details
                technicalSection
                
                // Statistics
                if let info = gameInfo {
                    onlineInfoSection(info)
                }
            }
            .padding()
        }
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showCoverPicker = true
                    } label: {
                        Label("Change Cover", systemImage: "photo")
                    }
                    
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Game", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showCoverPicker) {
            CoverPickerSheet(game: game, isPresented: $showCoverPicker)
        }
        .alert("Delete Game", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteGame()
            }
        } message: {
            Text("Are you sure you want to delete \"\(game.name)\"? This action cannot be undone.")
        }
        .task {
            await loadGameInfo()
        }
        // BIOS 缺失提示弹窗
        .alert("bios.alert.title".localized, isPresented: $showingBIOSAlert) {
            Button("bios.alert.goToSettings".localized) {
                // 打开设置页面的 BIOS 管理
                NotificationCenter.default.post(name: .openBIOSSettings, object: nil)
                dismiss()
            }
            Button("common.cancel".localized, role: .cancel) {}
        } message: {
            Text("bios.alert.message.\(game.system.rawValue)".localized)
        }
    }
    
    // MARK: - Cover Section
    
    private var coverSection: some View {
        VStack {
            GameCoverView(game: game, size: .detail)
                .onTapGesture {
                    showCoverPicker = true
                }
            
            Text("Tap to change cover")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // System badge
            HStack {
                Label(game.system.displayName, systemImage: game.system.iconName)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(game.system.color.opacity(0.2))
                    .foregroundStyle(game.system.color)
                    .clipShape(Capsule())
                
                Spacer()
                
                if game.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                }
            }
            
            // Dates
            VStack(alignment: .leading, spacing: 8) {
                if let dateAdded = game.dateAdded {
                    InfoRow(title: "Added", value: dateAdded.formatted(date: .abbreviated, time: .omitted))
                }
                
                if let lastPlayed = game.lastPlayed {
                    InfoRow(title: "Last Played", value: lastPlayed.formatted(date: .abbreviated, time: .shortened))
                } else {
                    InfoRow(title: "Last Played", value: "Never")
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Play button
            Button {
                playGame()
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            HStack(spacing: 12) {
                // Favorite button
                Button {
                    toggleFavorite()
                } label: {
                    Label(
                        game.isFavorite ? "Unfavorite" : "Favorite",
                        systemImage: game.isFavorite ? "heart.slash" : "heart"
                    )
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Share button
                ShareLink(item: game.fileURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    // MARK: - Technical Section
    
    private var technicalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Technical Details")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(title: "File Name", value: game.fileURL.lastPathComponent)
                InfoRow(title: "Extension", value: game.fileExtension.uppercased())
                
                if let fileSize = game.fileSize {
                    InfoRow(title: "File Size", value: fileSize)
                }
                
                InfoRow(title: "System", value: game.system.shortName)
                InfoRow(title: "Core", value: game.system.recommendedCore)
                InfoRow(title: "Resolution", value: "\(Int(game.system.nativeResolution.width))×\(Int(game.system.nativeResolution.height))")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Online Info Section
    
    @ViewBuilder
    private func onlineInfoSection(_ info: GameInfoResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Game Information")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                if !info.description.isEmpty {
                    Text(info.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if !info.developer.isEmpty {
                    InfoRow(title: "Developer", value: info.developer)
                }
                
                if !info.publisher.isEmpty {
                    InfoRow(title: "Publisher", value: info.publisher)
                }
                
                if !info.releaseDate.isEmpty {
                    InfoRow(title: "Release Date", value: info.releaseDate)
                }
                
                if !info.genre.isEmpty {
                    InfoRow(title: "Genre", value: info.genre)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Actions
    
    /// 启动游戏前检查 BIOS 是否可用
    private func playGame() {
        // 检查是否需要 BIOS
        if game.system == .ps1 && !biosManager.checkPS1BIOSAvailable() {
            // PS1 需要 BIOS 但未找到
            showingBIOSAlert = true
            return
        }
        
        // BIOS 检查通过，启动游戏
        appState.currentGame = game
        appState.isEmulating = true
        dismiss()
    }
    
    private func toggleFavorite() {
        // Would update in database
        HapticManager.shared.mediumImpact()
    }
    
    private func deleteGame() {
        // Would delete from database and file system
        dismiss()
    }
    
    private func loadGameInfo() async {
        isLoadingInfo = true
        gameInfo = await GameInfoService.shared.searchGameInfo(for: game)
        isLoadingInfo = false
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

#Preview {
    NavigationStack {
        GameDetailView(
            game: Game(
                name: "Super Mario Bros",
                fileURL: URL(fileURLWithPath: "/test.nes"),
                system: .nes
            )
        )
        .environmentObject(AppState())
    }
}

