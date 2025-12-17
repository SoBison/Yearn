//
//  LoadingOverlay.swift
//  Yearn
//
//  Loading overlay component
//

import SwiftUI

struct LoadingOverlay: View {
    let message: String
    var progress: Double?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                if let progress = progress {
                    ProgressView(value: progress)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(isLoading ? "Loading..." : title)
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(isLoading)
        .buttonStyle(.borderedProminent)
    }
}

#Preview {
    ZStack {
        Color.gray
        LoadingOverlay(message: "Loading game...")
    }
}

