//
//  OnboardingView.swift
//  Yearn
//
//  First-time user onboarding experience
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    
    let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to Yearn",
            subtitle: "Your retro gaming companion",
            description: "Play classic games from NES, SNES, Game Boy, N64, PlayStation and more on your iOS device.",
            imageName: "gamecontroller.fill",
            color: .purple
        ),
        OnboardingPage(
            title: "Import Your Games",
            subtitle: "Easy ROM management",
            description: "Import ROM files from Files app, AirDrop, or any cloud storage. Organize by system automatically.",
            imageName: "square.and.arrow.down.fill",
            color: .blue
        ),
        OnboardingPage(
            title: "Play Anywhere",
            subtitle: "Touch or controller",
            description: "Use the on-screen controller or connect your favorite Bluetooth gamepad for the best experience.",
            imageName: "hand.tap.fill",
            color: .green
        ),
        OnboardingPage(
            title: "Save Your Progress",
            subtitle: "Never lose your game",
            description: "Save states, auto-save, and iCloud sync keep your progress safe across all your devices.",
            imageName: "icloud.fill",
            color: .cyan
        ),
        OnboardingPage(
            title: "Ready to Play",
            subtitle: "Let's get started",
            description: "Import your first ROM and start reliving your favorite gaming memories.",
            imageName: "play.circle.fill",
            color: .orange
        )
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    pages[currentPage].color.opacity(0.3),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Page indicator and buttons
                VStack(spacing: 24) {
                    // Page dots
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? pages[currentPage].color : Color.secondary.opacity(0.3))
                                .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    
                    // Buttons
                    HStack(spacing: 16) {
                        if currentPage > 0 {
                            Button {
                                withAnimation {
                                    currentPage -= 1
                                }
                            } label: {
                                Text("Back")
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        
                        Button {
                            if currentPage < pages.count - 1 {
                                withAnimation {
                                    currentPage += 1
                                }
                            } else {
                                hasCompletedOnboarding = true
                            }
                        } label: {
                            Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(pages[currentPage].color)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal)
                    
                    // Skip button
                    if currentPage < pages.count - 1 {
                        Button {
                            hasCompletedOnboarding = true
                        } label: {
                            Text("Skip")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let title: String
    let subtitle: String
    let description: String
    let imageName: String
    let color: Color
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 160, height: 160)
                
                Circle()
                    .fill(page.color.opacity(0.1))
                    .frame(width: 200, height: 200)
                
                Image(systemName: page.imageName)
                    .font(.system(size: 64))
                    .foregroundStyle(page.color)
            }
            
            // Text content
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(page.color)
                
                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Onboarding Wrapper

struct OnboardingWrapper<Content: View>: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showLaunchScreen = true
    @State private var launchScreenOpacity: Double = 1.0
    
    let content: () -> Content
    
    var body: some View {
        ZStack {
            // 主内容层
            if hasCompletedOnboarding {
                content()
            } else {
                OnboardingView()
            }
            
            // 启动屏幕层（覆盖在上面）
            if showLaunchScreen {
                LaunchScreenView()
                    .opacity(launchScreenOpacity)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .onAppear {
            // 2 秒后开始淡出启动屏幕
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    launchScreenOpacity = 0
                }
                
                // 动画完成后移除启动屏幕
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showLaunchScreen = false
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
}

