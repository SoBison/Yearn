//
//  EmptyStateView.swift
//  Yearn
//
//  Empty state component
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SearchEmptyView: View {
    let searchText: String
    
    var body: some View {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Results",
            message: "No games found matching \"\(searchText)\""
        )
    }
}

struct NoFavoritesView: View {
    var body: some View {
        EmptyStateView(
            icon: "heart",
            title: "No Favorites",
            message: "Games you mark as favorites will appear here."
        )
    }
}

#Preview {
    VStack {
        EmptyStateView(
            icon: "gamecontroller",
            title: "No Games",
            message: "Add ROM files to start playing",
            actionTitle: "Import Games",
            action: {}
        )
    }
}

