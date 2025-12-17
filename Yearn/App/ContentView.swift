//
//  ContentView.swift
//  Yearn
//
//  Main content view with tab navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var refreshID = UUID()
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            LibraryView()
                .tabItem {
                    Label("tab.library".localized, systemImage: "gamecontroller.fill")
                }
                .tag(AppState.Tab.library)
            
            SettingsView()
                .tabItem {
                    Label("tab.settings".localized, systemImage: "gearshape.fill")
                }
                .tag(AppState.Tab.settings)
        }
        .id(refreshID)
        .fullScreenCover(isPresented: $appState.isEmulating) {
            if let game = appState.currentGame {
                EmulationView(game: game)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            refreshID = UUID()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
