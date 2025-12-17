//
//  LaunchScreenView.swift
//  Yearn
//
//  Custom launch screen with retro gaming animation
//

import SwiftUI

// MARK: - Launch Screen View

struct LaunchScreenView: View {
    @State private var phase: LaunchPhase = .initial
    @State private var pixelOffset: CGFloat = 0
    @State private var scanlineOffset: CGFloat = 0
    @State private var glitchOffset: CGFloat = 0
    @State private var showGlitch = false
    
    enum LaunchPhase {
        case initial
        case logoAppear
        case titleAppear
        case systemsAppear
        case ready
    }
    
    // 支持的游戏系统图标
    private let systemIcons = [
        ("tv", Color.red),              // NES
        ("tv.fill", Color.purple),       // SNES
        ("rectangle.portrait", Color.green), // GB
        ("rectangle", Color.indigo),     // GBA
        ("cube", Color.orange),          // N64
        ("rectangle.split.1x2", Color.blue), // NDS
        ("tv.circle", Color.cyan),       // Genesis
        ("opticaldisc", Color.gray)      // PS1
    ]
    
    var body: some View {
        ZStack {
            // 深色背景
            backgroundView
            
            // CRT 扫描线效果
            scanlineEffect
            
            // 主内容
            VStack(spacing: 32) {
                Spacer()
                
                // Logo 区域
                logoView
                
                // 标题
                titleView
                
                // 游戏系统图标
                systemIconsView
                
                Spacer()
                
                // 加载指示器
                loadingIndicator
                    .padding(.bottom, 60)
            }
            
            // 偶尔的故障效果
            if showGlitch {
                glitchOverlay
            }
        }
        .onAppear {
            startAnimationSequence()
        }
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            // 主背景渐变
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.14),
                    Color(red: 0.04, green: 0.03, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // 像素网格背景
            GeometryReader { geometry in
                Canvas { context, size in
                    let gridSize: CGFloat = 20
                    let rows = Int(size.height / gridSize) + 1
                    let cols = Int(size.width / gridSize) + 1
                    
                    for row in 0..<rows {
                        for col in 0..<cols {
                            let x = CGFloat(col) * gridSize
                            let y = CGFloat(row) * gridSize + pixelOffset
                            
                            // 随机亮度的像素点
                            let brightness = Double.random(in: 0.01...0.03)
                            context.fill(
                                Path(CGRect(x: x, y: y, width: 1, height: 1)),
                                with: .color(.white.opacity(brightness))
                            )
                        }
                    }
                }
            }
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Scanline Effect
    
    private var scanlineEffect: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for i in stride(from: 0, to: size.height, by: 3) {
                    context.fill(
                        Path(CGRect(x: 0, y: i + scanlineOffset.truncatingRemainder(dividingBy: 3), width: size.width, height: 1)),
                        with: .color(.black.opacity(0.15))
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    // MARK: - Logo View
    
    private var logoView: some View {
        ZStack {
            // 外层光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.purple.opacity(0.4),
                            Color.blue.opacity(0.2),
                            .clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .blur(radius: 30)
                .scaleEffect(phase == .initial ? 0.5 : 1.0)
                .opacity(phase == .initial ? 0 : 1)
            
            // 发光环
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.purple, .blue, .cyan, .purple],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 140, height: 140)
                .blur(radius: 4)
                .rotationEffect(.degrees(phase == .ready ? 360 : 0))
                .opacity(phase == .initial ? 0 : 0.8)
            
            // 主 Logo 背景
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.6, green: 0.3, blue: 0.9),
                            Color(red: 0.3, green: 0.2, blue: 0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 110, height: 110)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .purple.opacity(0.6), radius: 30, y: 10)
                .scaleEffect(phase == .initial ? 0.3 : 1.0)
                .opacity(phase == .initial ? 0 : 1)
            
            // 游戏手柄图标
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 50, weight: .medium))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
                .scaleEffect(phase == .initial ? 0.3 : 1.0)
                .opacity(phase == .initial ? 0 : 1)
        }
        .offset(x: showGlitch ? glitchOffset : 0)
    }
    
    // MARK: - Title View
    
    private var titleView: some View {
        VStack(spacing: 8) {
            // 主标题
            Text("Yearn")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .purple.opacity(0.5), radius: 10, y: 4)
            
            // 副标题 - 像素风格
            Text("RETRO GAMING REIMAGINED")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .opacity(phase == .initial || phase == .logoAppear ? 0 : 1)
        .offset(y: phase == .initial || phase == .logoAppear ? 20 : 0)
        .offset(x: showGlitch ? -glitchOffset : 0)
    }
    
    // MARK: - System Icons View
    
    private var systemIconsView: some View {
        HStack(spacing: 16) {
            ForEach(Array(systemIcons.enumerated()), id: \.offset) { index, system in
                Image(systemName: system.0)
                    .font(.system(size: 22))
                    .foregroundStyle(system.1)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(system.1.opacity(0.15))
                    )
                    .opacity(phase == .systemsAppear || phase == .ready ? 1 : 0)
                    .scaleEffect(phase == .systemsAppear || phase == .ready ? 1 : 0.5)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.7)
                        .delay(Double(index) * 0.08),
                        value: phase
                    )
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Loading Indicator
    
    private var loadingIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.purple)
                    .frame(width: 8, height: 8)
                    .scaleEffect(phase == .ready ? 1.0 : 0.5)
                    .opacity(phase == .ready ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: phase
                    )
            }
        }
        .opacity(phase == .ready ? 1 : 0)
    }
    
    // MARK: - Glitch Overlay
    
    private var glitchOverlay: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // RGB 偏移效果
                Color.red.opacity(0.1)
                    .frame(height: geometry.size.height * 0.1)
                    .offset(x: glitchOffset)
                
                Color.clear
                    .frame(height: geometry.size.height * 0.3)
                
                Color.cyan.opacity(0.1)
                    .frame(height: geometry.size.height * 0.05)
                    .offset(x: -glitchOffset)
                
                Spacer()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    // MARK: - Animation Sequence
    
    private func startAnimationSequence() {
        // 像素背景动画
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            pixelOffset = 100
        }
        
        // 扫描线动画
        withAnimation(.linear(duration: 0.1).repeatForever(autoreverses: false)) {
            scanlineOffset = 3
        }
        
        // Logo 出现
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                phase = .logoAppear
            }
        }
        
        // 标题出现
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.4)) {
                phase = .titleAppear
            }
        }
        
        // 系统图标出现
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                phase = .systemsAppear
            }
        }
        
        // 准备完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.3)) {
                phase = .ready
            }
        }
        
        // 发光环旋转
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                // 触发旋转动画（通过 phase 状态）
            }
        }
        
        // 随机故障效果
        startGlitchEffect()
    }
    
    private func startGlitchEffect() {
        // 随机间隔触发故障效果
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 2...4)) {
            glitchOffset = CGFloat.random(in: -5...5)
            showGlitch = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                glitchOffset = CGFloat.random(in: -3...3)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showGlitch = false
                glitchOffset = 0
            }
            
            // 继续下一次故障
            startGlitchEffect()
        }
    }
}

// MARK: - Preview

#Preview {
    LaunchScreenView()
}
