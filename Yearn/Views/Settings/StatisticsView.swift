//
//  StatisticsView.swift
//  Yearn
//
//  Statistics and usage view
//

import SwiftUI
import Charts

// MARK: - Statistics View

struct StatisticsView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @State private var selectedTimeRange: TimeRange = .week
    
    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case allTime = "All Time"
    }
    
    var body: some View {
        List {
            // Overview Section
            Section("stats.overview".localized) {
                StatRow(title: "stats.totalGames".localized, value: "\(viewModel.totalGames)", icon: "gamecontroller.fill", color: .blue)
                StatRow(title: "stats.totalSize".localized, value: viewModel.totalSize, icon: "internaldrive.fill", color: .orange)
                StatRow(title: "stats.favorites".localized, value: "\(viewModel.favoriteGames.count)", icon: "heart.fill", color: .red)
            }
            
            // Games by System
            Section("stats.gamesBySystem".localized) {
                ForEach(GameSystem.allCases) { system in
                    let count = viewModel.gamesBySystem[system] ?? 0
                    if count > 0 {
                        HStack {
                            Image(systemName: system.iconName)
                                .foregroundStyle(system.color)
                                .frame(width: 24)
                            
                            Text(system.shortName)
                            
                            Spacer()
                            
                            Text("\(count)")
                                .foregroundStyle(.secondary)
                            
                            // Progress bar
                            ProgressView(value: Double(count), total: Double(viewModel.totalGames))
                                .frame(width: 60)
                                .tint(system.color)
                        }
                    }
                }
            }
            
            // Play Time Chart (placeholder)
            Section("stats.recentActivity".localized) {
                if #available(iOS 17.0, *) {
                    PlayTimeChart(games: viewModel.recentGames)
                        .frame(height: 200)
                } else {
                    Text("stats.chartsRequireIOS17".localized)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Recently Played
            Section("stats.recentlyPlayed".localized) {
                if viewModel.recentGames.isEmpty {
                    Text("stats.noRecentGames".localized)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.recentGames.prefix(5)) { game in
                        HStack {
                            Image(systemName: game.system.iconName)
                                .foregroundStyle(game.system.color)
                            
                            VStack(alignment: .leading) {
                                Text(game.name)
                                    .lineLimit(1)
                                if let lastPlayed = game.lastPlayed {
                                    Text(lastPlayed.formatted(.relative(presentation: .named)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            
            // Storage Breakdown
            Section("stats.storage".localized) {
                StorageBreakdownView()
            }
        }
        .navigationTitle("stats.title".localized)
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)
            
            Text(title)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Play Time Chart

@available(iOS 17.0, *)
struct PlayTimeChart: View {
    let games: [Game]
    
    var chartData: [ChartDataPoint] {
        // Group by day for the last 7 days
        let calendar = Calendar.current
        var data: [ChartDataPoint] = []
        
        for dayOffset in (0..<7).reversed() {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            let gamesPlayedThatDay = games.filter { game in
                guard let lastPlayed = game.lastPlayed else { return false }
                return lastPlayed >= dayStart && lastPlayed < dayEnd
            }.count
            
            data.append(ChartDataPoint(date: dayStart, count: gamesPlayedThatDay))
        }
        
        return data
    }
    
    var body: some View {
        Chart(chartData) { point in
            BarMark(
                x: .value("Day", point.date, unit: .day),
                y: .value("Games", point.count)
            )
            .foregroundStyle(.blue.gradient)
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    }
                }
            }
        }
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

// MARK: - Storage Breakdown View

struct StorageBreakdownView: View {
    @State private var romsSize: String = "stats.calculating".localized
    @State private var savesSize: String = "stats.calculating".localized
    @State private var statesSize: String = "stats.calculating".localized
    @State private var coresSize: String = "stats.calculating".localized
    
    var body: some View {
        VStack(spacing: 12) {
            StorageRow(label: "stats.roms".localized, size: romsSize, color: .blue)
            StorageRow(label: "stats.saveStates".localized, size: savesSize, color: .green)
            StorageRow(label: "stats.batterySaves".localized, size: statesSize, color: .orange)
            StorageRow(label: "stats.cores".localized, size: coresSize, color: .purple)
        }
        .task {
            await calculateSizes()
        }
    }
    
    private func calculateSizes() async {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        romsSize = formatSize(directorySize(at: documentsURL.appendingPathComponent("ROMs")))
        savesSize = formatSize(directorySize(at: documentsURL.appendingPathComponent("SaveStates")))
        statesSize = formatSize(directorySize(at: documentsURL.appendingPathComponent("Saves")))
        coresSize = formatSize(directorySize(at: documentsURL.appendingPathComponent("Cores")))
    }
    
    private func directorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }
        
        return totalSize
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

struct StorageRow: View {
    let label: String
    let size: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(label)
            
            Spacer()
            
            Text(size)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Achievement Badge (Future Feature)

struct AchievementBadge: View {
    let title: String
    let description: String
    let icon: String
    let isUnlocked: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(isUnlocked ? .yellow : .gray)
                .frame(width: 50, height: 50)
                .background(isUnlocked ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(isUnlocked ? .primary : .secondary)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .opacity(isUnlocked ? 1.0 : 0.5)
    }
}

#Preview {
    NavigationStack {
        StatisticsView(viewModel: LibraryViewModel())
    }
}

