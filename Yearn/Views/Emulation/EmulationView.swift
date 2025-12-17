//
//  EmulationView.swift
//  Yearn
//
//  Emulation view for playing games
//

import SwiftUI
import MetalKit
import GameController
import CoreHaptics
import UIKit
import YearnCore

// MARK: - Color Helpers

private extension Color {
    func blended(with color: Color, amount: CGFloat) -> Color {
        let clamped = max(0, min(1, amount))
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        UIColor(self).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(color).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let r = r1 + (r2 - r1) * clamped
        let g = g1 + (g2 - g1) * clamped
        let b = b1 + (b2 - b1) * clamped
        let a = a1 + (a2 - a1) * clamped
        
        return Color(red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
    }
}

struct EmulationView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: EmulationViewModel
    @State private var showingPauseMenu = false
    @State private var showingController = true
    @State private var showingSaveStates = false
    @State private var isLoadingState = false
    
    @AppStorage("controllerOpacity") private var controllerOpacity: Double = 0.8
    @AppStorage("gameScreenScale") private var gameScreenScale: Double = 1.0
    @ObservedObject private var skinManager = ControllerSkinManager.shared
    
    init(game: Game) {
        _viewModel = StateObject(wrappedValue: EmulationViewModel(game: game))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let isIPad = geometry.size.width > 700 && geometry.size.height > 500
            
            ZStack {
                // 背景 - 使用皮肤背景色
                skinManager.currentSkin.backgroundColor.color
                    .ignoresSafeArea()
                
                if isLandscape {
                    // 横屏布局：游戏画面居中，控制器在两侧
                    landscapeLayout(geometry: geometry, isIPad: isIPad)
                } else {
                    // 竖屏布局：游戏画面在上，控制器在下
                    portraitLayout(geometry: geometry, isIPad: isIPad)
                }
                
                // FPS 计数器 (调试)
                #if DEBUG
                fpsOverlay
                #endif
                
                // 快进指示器
                if viewModel.isFastForwarding {
                    fastForwardIndicator
                }
                
                // 暂停菜单
                if showingPauseMenu {
                    PauseMenuView(
                        game: viewModel.game,
                        viewModel: viewModel,
                        onResume: {
                            withAnimation(.spring(response: 0.3)) {
                                showingPauseMenu = false
                            }
                            viewModel.resume()
                        },
                        onQuit: {
                            viewModel.stop()
                            appState.isEmulating = false
                        },
                        onSaveStates: {
                            showingSaveStates = true
                        }
                    )
                    .transition(.opacity)
                }
                
                // 加载指示器
                if !viewModel.isRunning && viewModel.errorMessage == nil {
                    loadingOverlay
                }
                
                // 错误信息
                if let error = viewModel.errorMessage {
                    errorOverlay(error: error)
                }
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .ignoresSafeArea()
        .onAppear {
            viewModel.start()
            setupGameController()
        }
        .onDisappear {
            viewModel.stop()
        }
        .sheet(isPresented: $showingSaveStates) {
            SaveStatesSheet(
                viewModel: viewModel,
                isLoading: $isLoadingState
            )
        }
    }
    
    // MARK: - Delta Handheld Components
    
    private struct DeltaConsoleMetrics {
        let width: CGFloat
        let aspectRatio: CGFloat
        let hasShoulderButtons: Bool
        
        let displayHeight: CGFloat
        let controllerHeight: CGFloat
        let shellCornerRadius: CGFloat
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let displayToControllerSpacing: CGFloat = 30 // 游戏画面和控制器之间的间距
        
        init(width: CGFloat, aspectRatio: CGFloat, hasShoulderButtons: Bool) {
            self.width = width
            self.aspectRatio = aspectRatio
            self.hasShoulderButtons = hasShoulderButtons
            
            displayHeight = min(width / aspectRatio, width * 0.78)
            controllerHeight = width * (hasShoulderButtons ? 0.9 : 0.82)
            shellCornerRadius = width * 0.18
            horizontalPadding = width * 0.06
            verticalPadding = width * 0.04
        }
        
        var totalHeight: CGFloat {
            displayHeight + displayToControllerSpacing + controllerHeight + (verticalPadding * 2)
        }
    }
    
    struct DeltaHandheldConsoleView: View {
        let width: CGFloat
        let aspectRatio: CGFloat
        let isIPad: Bool
        let skin: ControllerSkin
        let system: GameSystem
        let viewModel: EmulationViewModel
        let onInput: (GameInput, Bool) -> Void
        let onFastForward: (Bool) -> Void
        let onMenuTapped: () -> Void
        
        private var theme: DeltaControllerTheme {
            DeltaControllerTheme.fromSkin(skin, isIPad: isIPad)
        }
        
        var body: some View {
            let metrics = DeltaConsoleMetrics(
                width: width,
                aspectRatio: aspectRatio,
                hasShoulderButtons: system.hasShoulderButtons
            )
            
            ZStack {
                RoundedRectangle(cornerRadius: metrics.shellCornerRadius, style: .continuous)
                    .fill(theme.shellGradient)
                    .shadow(color: .black.opacity(0.35), radius: 25, y: 18)
                
                VStack(spacing: 0) {
                    DeltaDisplayArea(
                        viewModel: viewModel,
                        theme: theme
                    )
                    .frame(height: metrics.displayHeight)
                    
                    // L/R 肩键区域 - 位于屏幕和控制器之间的过渡带
                    if system.hasShoulderButtons {
                        DeltaShoulderButtonBar(
                            theme: theme,
                            width: width - metrics.horizontalPadding * 2,
                            onInput: onInput
                        )
                        .padding(.top, 8)
                    }
                    
                    // 游戏画面和控制器之间的间距
                    Spacer()
                        .frame(height: system.hasShoulderButtons ? 12 : metrics.displayToControllerSpacing)
                    
                    DeltaControllerDeckView(
                        system: system,
                        theme: theme,
                        height: metrics.controllerHeight, bottomOffset: 130,
                        onInput: onInput,
                        onFastForward: onFastForward,
                        onMenuTapped: onMenuTapped
                    )
                }
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.vertical, metrics.verticalPadding)
            }
            .frame(width: width, height: metrics.totalHeight)
        }
        
        static func estimatedHeight(forWidth width: CGFloat, aspectRatio: CGFloat, hasShoulderButtons: Bool) -> CGFloat {
            DeltaConsoleMetrics(
                width: width,
                aspectRatio: aspectRatio,
                hasShoulderButtons: hasShoulderButtons
            ).totalHeight
        }
    }
    
    struct DeltaDisplayArea: View {
        let viewModel: EmulationViewModel
        let theme: DeltaControllerTheme
        
        var body: some View {
            // 游戏画面 - 简洁无边框设计
            GameDisplayView(viewModel: viewModel)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        }
    }
    
    struct DeltaControllerDeckView: View {
        let system: GameSystem
        let theme: DeltaControllerTheme
        let height: CGFloat
        let bottomOffset: CGFloat // 底部偏移（安全区域 + 20）
        let onInput: (GameInput, Bool) -> Void
        let onFastForward: (Bool) -> Void
        let onMenuTapped: () -> Void
        
        private var controlAreaHeight: CGFloat {
            height - bottomOffset
        }
        
        private var dpadSize: CGFloat {
            min(controlAreaHeight * 0.50, 130)
        }
        
        private var actionSize: CGFloat {
            dpadSize
        }
        
        private var shoulderButtonWidth: CGFloat {
            dpadSize * 0.85
        }
        
        var body: some View {
            VStack(spacing: 8) {
                // 主控制区域：D-Pad / MENU / 动作按钮（L/R已移至屏幕下方的过渡区域）
                HStack(alignment: .center, spacing: 0) {
                    // 左侧区域：D-Pad
                    DeltaDPad(
                        theme: theme,
                        size: dpadSize,
                        onInput: onInput
                    )
                    .padding(.leading, 16)
                    
                    Spacer()
                    
                    // 中间：MENU 按钮
                    VStack {
                        Spacer()
                        DeltaMenuButton(theme: theme, action: onMenuTapped)
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // 右侧区域：动作按钮
                    DeltaActionCluster(
                        system: system,
                        theme: theme,
                        size: actionSize,
                        onInput: onInput
                    )
                    .padding(.trailing, 16)
                }
                
                // 底部功能按钮：SELECT / 快进 / START
                HStack(spacing: 20) {
                    Spacer()
                    
                    DeltaAuxButton(
                        label: "SELECT",
                        theme: theme,
                        onPressed: { onInput(.select, $0) }
                    )
                    
                    DeltaFastForwardButton(theme: theme, onFastForward: onFastForward)
                    
                    DeltaAuxButton(
                        label: "START",
                        theme: theme,
                        onPressed: { onInput(.start, $0) }
                    )
                    
                    Spacer()
                }
                .padding(.top, 2)
                
                // 底部留白（安全区域）
                Spacer()
                    .frame(height: bottomOffset)
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - 肩键条（L/R）- Delta风格，位于屏幕和控制器之间
    struct DeltaShoulderButtonBar: View {
        let theme: DeltaControllerTheme
        let width: CGFloat
        let onInput: (GameInput, Bool) -> Void
        
        // 按钮宽度占总宽度的比例
        private var buttonWidth: CGFloat {
            width * 0.22
        }
        
        var body: some View {
            HStack {
                // L 按钮 - 左侧
                DeltaShoulderButtonFlat(
                    label: "L",
                    theme: theme,
                    width: buttonWidth,
                    isLeft: true,
                    onPressed: { onInput(.l, $0) }
                )
                
                Spacer()
                
                // R 按钮 - 右侧
                DeltaShoulderButtonFlat(
                    label: "R",
                    theme: theme,
                    width: buttonWidth,
                    isLeft: false,
                    onPressed: { onInput(.r, $0) }
                )
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - 扁平肩键 - Delta风格
    struct DeltaShoulderButtonFlat: View {
        let label: String
        let theme: DeltaControllerTheme
        let width: CGFloat
        let isLeft: Bool
        let onPressed: (Bool) -> Void
        
        @State private var isPressed = false
        
        // 扁平圆角矩形
        private var buttonShape: some Shape {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
        }
        
        // 按钮颜色 - 使用肩键专用颜色
        private var buttonColor: Color {
            theme.shoulderColor
        }
        
        var body: some View {
            ZStack {
                // 按钮阴影/底部 - 制造立体感
                buttonShape
                    .fill(buttonColor.blended(with: .black, amount: 0.4))
                    .frame(width: width, height: 26)
                    .offset(y: isPressed ? 0 : 2)
                
                // 按钮主体
                buttonShape
                    .fill(
                        LinearGradient(
                            colors: [
                                buttonColor.blended(with: .white, amount: isPressed ? 0.0 : 0.08),
                                buttonColor.blended(with: .black, amount: isPressed ? 0.15 : 0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width, height: 26)
                    .overlay {
                        // 边框高光
                        buttonShape
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.15),
                                        Color.black.opacity(0.2)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    }
                    .overlay {
                        // 按钮标签
                        Text(label)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.shoulderLabelColor.opacity(isPressed ? 0.6 : 0.9))
                    }
                    .offset(y: isPressed ? 1 : 0)
            }
            .frame(width: width, height: 28)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        onPressed(true)
                    }
                    .onEnded { _ in
                        isPressed = false
                        onPressed(false)
                    }
            )
            .animation(.easeOut(duration: 0.06), value: isPressed)
        }
    }
    
    // MARK: - 肩键（L/R）- 掌机风格（保留用于其他布局）
    struct DeltaShoulderButton: View {
        let label: String
        let theme: DeltaControllerTheme
        let width: CGFloat
        let isLeft: Bool
        let onPressed: (Bool) -> Void
        
        @State private var isPressed = false
        
        private var buttonShape: some Shape {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
        }
        
        var body: some View {
            ZStack {
                // 按钮阴影/底部
                buttonShape
                    .fill(theme.shoulderColor.blended(with: .black, amount: 0.4))
                    .frame(width: width, height: 32)
                    .offset(y: isPressed ? 1 : 3)
                
                // 按钮主体
                buttonShape
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.shoulderColor.blended(with: .white, amount: isPressed ? 0.0 : 0.15),
                                theme.shoulderColor.blended(with: .black, amount: isPressed ? 0.1 : 0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width, height: 32)
                    .overlay {
                        buttonShape
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.black.opacity(0.2)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    }
                    .overlay {
                        Text(label)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.shoulderLabelColor.opacity(isPressed ? 0.7 : 1.0))
                    }
                    .offset(y: isPressed ? 2 : 0)
            }
            .frame(width: width, height: 36)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        onPressed(true)
                    }
                    .onEnded { _ in
                        isPressed = false
                        onPressed(false)
                    }
            )
            .animation(.easeOut(duration: 0.08), value: isPressed)
        }
    }
    
    struct DeltaDPad: View {
        let theme: DeltaControllerTheme
        let size: CGFloat
        let onInput: (GameInput, Bool) -> Void
        
        // 当前按下的方向（支持多个方向同时按下）
        @State private var pressedDirections: Set<GameInput> = []
        
        var body: some View {
            ZStack {
                // D-Pad 底座
                Circle()
                    .fill(theme.dpadBaseColor)
                    .frame(width: size * 1.05, height: size * 1.05)
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
                
                // 十字形状
                DPadCrossShape()
                    .fill(theme.dpadCrossGradient)
                    .frame(width: size, height: size)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                
                // 方向指示高亮
                ForEach(Array(pressedDirections), id: \.self) { dir in
                    directionHighlight(for: dir)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let location = value.location
                        let center = CGPoint(x: size / 2, y: size / 2)
                        let dx = location.x - center.x
                        let dy = location.y - center.y
                        
                        // 计算距离中心的距离
                        let distance = sqrt(dx * dx + dy * dy)
                        
                        // 如果在中心死区内，释放所有方向
                        let deadZone = size * 0.12
                        guard distance > deadZone else {
                            releaseAllDirections()
                            return
                        }
                        
                        // 计算新的方向组合（支持斜向 - 8方向）
                        var newDirections: Set<GameInput> = []
                        
                        // 使用阈值来判断是否激活某个方向
                        // 这样可以支持斜向输入
                        let threshold = size * 0.1  // 激活阈值
                        
                        // 水平方向
                        if dx > threshold {
                            newDirections.insert(.right)
                        } else if dx < -threshold {
                            newDirections.insert(.left)
                        }
                        
                        // 垂直方向
                        if dy > threshold {
                            newDirections.insert(.down)
                        } else if dy < -threshold {
                            newDirections.insert(.up)
                        }
                        
                        // 更新方向状态
                        updateDirections(newDirections)
                    }
                    .onEnded { _ in
                        releaseAllDirections()
                    }
            )
        }
        
        private func updateDirections(_ newDirections: Set<GameInput>) {
            // 找出需要释放的方向
            let toRelease = pressedDirections.subtracting(newDirections)
            for dir in toRelease {
                print("🎯 DeltaDPad: \(dir) released")
                onInput(dir, false)
            }
            
            // 找出需要按下的方向
            let toPress = newDirections.subtracting(pressedDirections)
            for dir in toPress {
                print("🎯 DeltaDPad: \(dir) pressed")
                onInput(dir, true)
            }
            
            pressedDirections = newDirections
        }
        
        private func releaseAllDirections() {
            for dir in pressedDirections {
                print("🎯 DeltaDPad: \(dir) released")
                onInput(dir, false)
            }
            pressedDirections.removeAll()
        }
        
        @ViewBuilder
        private func directionHighlight(for direction: GameInput) -> some View {
            let offset: CGFloat = size * 0.25
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: size * 0.25, height: size * 0.25)
                .offset(
                    x: direction == .right ? offset : (direction == .left ? -offset : 0),
                    y: direction == .down ? offset : (direction == .up ? -offset : 0)
                )
        }
    }
    
    struct DeltaActionCluster: View {
        let system: GameSystem
        let theme: DeltaControllerTheme
        let size: CGFloat
        let onInput: (GameInput, Bool) -> Void
        
        var body: some View {
            ZStack {
                Circle()
                    .fill(theme.actionBaseColor)
                    .frame(width: size * 1.1, height: size * 1.1)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                
                if system.hasXYButtons {
                    DeltaActionButton(label: "Y", color: theme.actionColors[.y] ?? .green) { onInput(.y, $0) }
                        .frame(width: size * 0.4, height: size * 0.4)
                        .offset(x: -size * 0.35)
                    
                    DeltaActionButton(label: "X", color: theme.actionColors[.x] ?? .blue) { onInput(.x, $0) }
                        .frame(width: size * 0.4, height: size * 0.4)
                        .offset(y: -size * 0.35)
                    
                    DeltaActionButton(label: "A", color: theme.actionColors[.a] ?? .red) { onInput(.a, $0) }
                        .frame(width: size * 0.4, height: size * 0.4)
                        .offset(x: size * 0.35)
                    
                    DeltaActionButton(label: "B", color: theme.actionColors[.b] ?? .yellow) { onInput(.b, $0) }
                        .frame(width: size * 0.4, height: size * 0.4)
                        .offset(y: size * 0.35)
                } else {
                    DeltaActionButton(label: "B", color: theme.actionColors[.b] ?? .yellow) { onInput(.b, $0) }
                        .frame(width: size * 0.45, height: size * 0.45)
                        .offset(x: -size * 0.15, y: size * 0.2)
                    
                    DeltaActionButton(label: "A", color: theme.actionColors[.a] ?? .red) { onInput(.a, $0) }
                        .frame(width: size * 0.45, height: size * 0.45)
                        .offset(x: size * 0.25, y: -size * 0.2)
                }
            }
        }
    }
    
    struct DeltaActionButton: View {
        let label: String
        let color: Color
        let onPressed: (Bool) -> Void
        
        @State private var isPressed = false
        
        var body: some View {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            color.blended(with: .white, amount: 0.2),
                            color.blended(with: .black, amount: 0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Circle()
                        .stroke(Color.black.opacity(0.25), lineWidth: 1)
                }
                .overlay {
                    Text(label)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                }
                .scaleEffect(isPressed ? 0.92 : 1)
                .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !isPressed else { return }
                            isPressed = true
                            onPressed(true)
                        }
                        .onEnded { _ in
                            isPressed = false
                            onPressed(false)
                        }
                )
        }
    }
    
    struct DeltaMenuButton: View {
        let theme: DeltaControllerTheme
        let action: () -> Void
        
        var body: some View {
            VStack(spacing: 4) {
                Circle()
                    .fill(theme.menuButtonColor)
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 3)
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    }
                    .onTapGesture {
                        action()
                    }
                
                Text("MENU")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.menuLabelColor)
            }
        }
    }
    
    struct DeltaAuxButton: View {
        let label: String
        let theme: DeltaControllerTheme
        let onPressed: (Bool) -> Void
        
        @State private var isPressed = false
        
        var body: some View {
            VStack(spacing: 2) {
                Circle()
                    .fill(theme.auxButtonColor)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    }
                    .overlay {
                        Text(label.prefix(1))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(theme.auxLabelColor)
                    }
                    .scaleEffect(isPressed ? 0.93 : 1)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                guard !isPressed else { return }
                                isPressed = true
                                onPressed(true)
                            }
                            .onEnded { _ in
                                isPressed = false
                                onPressed(false)
                            }
                    )
                
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.auxLabelColor)
            }
        }
    }
    
    struct DeltaFastForwardButton: View {
        let theme: DeltaControllerTheme
        let onFastForward: (Bool) -> Void
        
        @State private var isPressed = false
        
        var body: some View {
            Circle()
                .fill(theme.fastForwardButtonColor)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white)
                }
                .overlay {
                    Circle()
                        .stroke(Color.black.opacity(0.2), lineWidth: 1)
                }
                .scaleEffect(isPressed ? 0.93 : 1)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !isPressed else { return }
                            isPressed = true
                            onFastForward(true)
                        }
                        .onEnded { _ in
                            isPressed = false
                            onFastForward(false)
                        }
                )
        }
    }
    
    struct DeltaControllerTheme {
        let shellTopColor: Color
        let shellBottomColor: Color
        let displayBezelColor: Color
        let brandBarColor: Color
        let brandTextColor: Color
        let brandText: String
        let controllerSurfaceTop: Color
        let controllerSurfaceBottom: Color
        let shoulderColor: Color
        let shoulderOutlineColor: Color
        let shoulderLabelColor: Color
        let dpadBaseColor: Color
        let dpadCrossLight: Color
        let dpadCrossDark: Color
        let actionBaseColor: Color
        let actionColors: [GameInput: Color]
        let menuButtonColor: Color
        let menuLabelColor: Color
        let auxButtonColor: Color
        let auxLabelColor: Color
        let fastForwardButtonColor: Color
        
        var shellGradient: LinearGradient {
            LinearGradient(
                colors: [shellTopColor, shellBottomColor],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        
        var controllerSurfaceGradient: LinearGradient {
            LinearGradient(
                colors: [controllerSurfaceTop, controllerSurfaceBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        
        var dpadCrossGradient: LinearGradient {
            LinearGradient(
                colors: [dpadCrossLight, dpadCrossDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        static func fromSkin(_ skin: ControllerSkin, isIPad: Bool) -> DeltaControllerTheme {
            // 使用皮肤的背景色和按钮色
            let bgColor = skin.backgroundColor.color
            let btnColor = skin.buttonColor.color
            
            // 判断背景是否为深色
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            UIColor(bgColor).getRed(&r, green: &g, blue: &b, alpha: nil)
            let isDarkBackground = (r + g + b) / 3 < 0.5
            
            // 控制器表面颜色 - 基于背景色调整
            let controllerTop = isDarkBackground 
                ? bgColor.blended(with: .white, amount: 0.15)
                : bgColor.blended(with: .white, amount: 0.3)
            let controllerBottom = controllerTop.blended(with: .black, amount: 0.1)
            
            // D-Pad 颜色 - 使用按钮色
            let dpadBase = btnColor.blended(with: .black, amount: 0.3)
            
            // 动作按钮颜色 - 根据皮肤名称决定是否使用经典 SNES 颜色
            let useClassicColors = skin.name == "Classic Nintendo" || skin.name == "经典任天堂"
            let actionColors: [GameInput: Color] = useClassicColors ? [
                .a: Color(red: 0.91, green: 0.26, blue: 0.27),  // 红
                .b: Color(red: 0.98, green: 0.82, blue: 0.24),  // 黄
                .x: Color(red: 0.17, green: 0.45, blue: 0.89),  // 蓝
                .y: Color(red: 0.24, green: 0.69, blue: 0.38)   // 绿
            ] : [
                .a: btnColor,
                .b: btnColor.blended(with: .black, amount: 0.1),
                .x: btnColor.blended(with: .white, amount: 0.1),
                .y: btnColor.blended(with: .black, amount: 0.05)
            ]
            
            // 文字/标签颜色 - 根据背景亮度调整
            let labelColor = isDarkBackground ? Color.white.opacity(0.9) : Color.black.opacity(0.85)
            let outlineColor = isDarkBackground ? Color.white.opacity(0.3) : Color.black.opacity(0.3)
            
            return DeltaControllerTheme(
                shellTopColor: bgColor.blended(with: .white, amount: 0.1),
                shellBottomColor: bgColor.blended(with: .black, amount: 0.1),
                displayBezelColor: Color(red: 0.05, green: 0.05, blue: 0.08),
                brandBarColor: Color.black.opacity(0.95),
                brandTextColor: Color.white,
                brandText: isIPad ? "YEARN PRO" : "YEARN",
                controllerSurfaceTop: controllerTop,
                controllerSurfaceBottom: controllerBottom,
                shoulderColor: btnColor.blended(with: isDarkBackground ? .white : .black, amount: 0.1),
                shoulderOutlineColor: outlineColor,
                shoulderLabelColor: labelColor,
                dpadBaseColor: dpadBase,
                dpadCrossLight: dpadBase.blended(with: .white, amount: 0.25),
                dpadCrossDark: dpadBase.blended(with: .black, amount: 0.2),
                actionBaseColor: controllerTop.blended(with: .black, amount: 0.1),
                actionColors: actionColors,
                menuButtonColor: btnColor.blended(with: isDarkBackground ? .white : .black, amount: 0.15),
                menuLabelColor: labelColor,
                auxButtonColor: btnColor,
                auxLabelColor: labelColor,
                fastForwardButtonColor: btnColor
            )
        }
    }
    
    // MARK: - 横屏布局（使用 Delta 主题设计）
    
    @ViewBuilder
    private func landscapeLayout(geometry: GeometryProxy, isIPad: Bool) -> some View {
        let safeArea = geometry.safeAreaInsets
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height
        let skin = skinManager.currentSkin
        let theme = DeltaControllerTheme.fromSkin(skin, isIPad: isIPad)
        
        // 计算可用屏幕宽度（排除刘海安全区域）
        let availableWidth = screenWidth - safeArea.leading - safeArea.trailing
        
        // 计算控制区域宽度（紧凑布局，基于可用宽度计算）
        let controlAreaWidth: CGFloat = availableWidth * (isIPad ? 0.22 : 0.24)
        
        // 计算游戏画面尺寸，应用用户缩放设置
        // 游戏宽高比：宽度/高度，例如 4:3 = 1.33，表示宽度是高度的 1.33 倍
        let gameAspectRatio = getAspectRatio()
        // 最小化边距，让游戏画面尽可能大（基于可用宽度）
        let maxGameWidth = availableWidth - (controlAreaWidth * 2)
        let maxGameHeight = screenHeight - safeArea.top - safeArea.bottom - 16
        
        // 根据可用空间和宽高比计算游戏画面尺寸
        // 尝试以高度为基准，如果宽度超限则以宽度为基准
        let heightBasedWidth = maxGameHeight * gameAspectRatio
        let (baseGameWidth, baseGameHeight): (CGFloat, CGFloat) = heightBasedWidth > maxGameWidth
            ? (maxGameWidth, maxGameWidth / gameAspectRatio)
            : (heightBasedWidth, maxGameHeight)
        
        // 应用用户缩放设置
        let gameWidth = min(baseGameWidth * gameScreenScale, maxGameWidth)
        let gameHeight = min(baseGameHeight * gameScreenScale, maxGameHeight)
        
        // 控制器按钮尺寸 - 根据控制区域宽度和屏幕高度动态计算
        let availableHeight = screenHeight - safeArea.top - safeArea.bottom - 40
        let dpadSize: CGFloat = min(controlAreaWidth * 0.72, min(availableHeight * 0.45, isIPad ? 140 : 120))
        let actionSize: CGFloat = dpadSize
        let shoulderWidth: CGFloat = min(controlAreaWidth * 0.65, isIPad ? 100 : 85)
        
        ZStack {
            // 背景渐变 - 使用主题色
            theme.shellGradient
                .ignoresSafeArea()
            
            HStack(spacing: 0) {
                // 左侧控制区域
                LandscapeControlPanel(
                    theme: theme,
                    system: viewModel.game.system,
                    dpadSize: dpadSize,
                    shoulderWidth: shoulderWidth,
                    safeArea: safeArea,
                    isLeftSide: true,
                    onInput: { input, pressed in
                        viewModel.handleInput(input, pressed: pressed)
                    },
                    onMenuTapped: {
                        viewModel.pause()
                        withAnimation(.spring(response: 0.3)) {
                            showingPauseMenu = true
                        }
                    },
                    onFastForward: nil
                )
                .frame(width: controlAreaWidth)
                .padding(.leading, safeArea.leading)
                
                // 中央游戏画面 - 简洁布局，最大化游戏画面
                LandscapeDisplayArea(
                    viewModel: viewModel,
                    theme: theme,
                    width: gameWidth,
                    height: gameHeight
                )
                
                // 右侧控制区域（包含快进、SELECT、START）
                LandscapeControlPanel(
                    theme: theme,
                    system: viewModel.game.system,
                    dpadSize: actionSize,
                    shoulderWidth: shoulderWidth,
                    safeArea: safeArea,
                    isLeftSide: false,
                    onInput: { input, pressed in
                        viewModel.handleInput(input, pressed: pressed)
                    },
                    onMenuTapped: {},
                    onFastForward: { active in
                        if active {
                            viewModel.startFastForward()
                        } else {
                            viewModel.stopFastForward()
                        }
                    }
                )
                .frame(width: controlAreaWidth)
                .padding(.trailing, safeArea.trailing)
            }
        }
    }
    
    // MARK: - 横屏控制面板
    
    struct LandscapeControlPanel: View {
        let theme: DeltaControllerTheme
        let system: GameSystem
        let dpadSize: CGFloat
        let shoulderWidth: CGFloat
        let safeArea: EdgeInsets
        let isLeftSide: Bool
        let onInput: (GameInput, Bool) -> Void
        let onMenuTapped: () -> Void
        let onFastForward: ((Bool) -> Void)?
        
        var body: some View {
            VStack(spacing: 0) {
                // 肩键
                if system.hasShoulderButtons {
                    DeltaShoulderButtonHorizontal(
                        label: isLeftSide ? "L" : "R",
                        theme: theme,
                        width: shoulderWidth,
                        onPressed: { onInput(isLeftSide ? .l : .r, $0) }
                    )
                    .padding(.top, safeArea.top + 10)
                } else {
                    Spacer().frame(height: safeArea.top + 10)
                }
                
                Spacer()
                
                // 主控制器（D-Pad 或动作按钮）
                if isLeftSide {
                    DeltaDPad(
                        theme: theme,
                        size: dpadSize,
                        onInput: onInput
                    )
                } else {
                    DeltaActionCluster(
                        system: system,
                        theme: theme,
                        size: dpadSize,
                        onInput: onInput
                    )
                }
                
                Spacer()
                
                // 底部按钮区域
                if isLeftSide {
                    // 左侧：菜单按钮
                    DeltaMenuButton(theme: theme, action: onMenuTapped)
                        .padding(.bottom, safeArea.bottom + 10)
                } else {
                    // 右侧：快进 + SELECT/START 按钮
                    VStack(spacing: 8) {
                        // 快进按钮
                        if let fastForward = onFastForward {
                            DeltaFastForwardButton(theme: theme, onFastForward: fastForward)
                        }
                        
                        // SELECT/START 按钮 - 水平排列
                        HStack(spacing: 8) {
                            DeltaAuxButton(
                                label: "SEL",
                                theme: theme,
                                onPressed: { onInput(.select, $0) }
                            )
                            
                            DeltaAuxButton(
                                label: "STA",
                                theme: theme,
                                onPressed: { onInput(.start, $0) }
                            )
                        }
                    }
                    .padding(.bottom, safeArea.bottom + 10)
                }
            }
        }
    }
    
    // MARK: - 横屏显示区域（无边框简洁风格）
    
    struct LandscapeDisplayArea: View {
        let viewModel: EmulationViewModel
        let theme: DeltaControllerTheme
        let width: CGFloat
        let height: CGFloat
        
        var body: some View {
            // 游戏画面 - 简洁无边框，仅添加轻微阴影增加层次感
            GameDisplayView(viewModel: viewModel)
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        }
    }
    
    // MARK: - 横屏肩键
    
    struct DeltaShoulderButtonHorizontal: View {
        let label: String
        let theme: DeltaControllerTheme
        let width: CGFloat
        let onPressed: (Bool) -> Void
        
        @State private var isPressed = false
        
        private var buttonShape: some Shape {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
        }
        
        var body: some View {
            ZStack {
                // 阴影层
                buttonShape
                    .fill(Color.black.opacity(0.35))
                    .frame(width: width, height: 36)
                    .offset(y: isPressed ? 1 : 3)
                
                // 按钮主体
                buttonShape
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.shoulderColor.blended(with: .white, amount: isPressed ? 0.0 : 0.15),
                                theme.shoulderColor.blended(with: .black, amount: isPressed ? 0.1 : 0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width, height: 36)
                    .overlay {
                        buttonShape
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.black.opacity(0.2)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    }
                    .overlay {
                        Text(label)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.shoulderLabelColor.opacity(isPressed ? 0.7 : 1.0))
                    }
                    .offset(y: isPressed ? 2 : 0)
            }
            .frame(width: width, height: 40)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        onPressed(true)
                    }
                    .onEnded { _ in
                        isPressed = false
                        onPressed(false)
                    }
            )
            .animation(.easeOut(duration: 0.08), value: isPressed)
        }
    }
    
    // MARK: - 竖屏布局 - Delta 掌机风格
    
    @ViewBuilder
    private func portraitLayout(geometry: GeometryProxy, isIPad: Bool) -> some View {
        let safeArea = geometry.safeAreaInsets
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height
        let skin = skinManager.currentSkin
        let theme = DeltaControllerTheme.fromSkin(skin, isIPad: isIPad)
        
        // 底部按钮上移距离
        let bottomOffset = safeArea.bottom + 20
        
        // 控制器高度（包含底部偏移）
        let controllerBaseHeight: CGFloat = isIPad ? 280 : 240
        let controllerHeight = controllerBaseHeight + bottomOffset
        
        // 游戏画面可用区域高度 = 屏幕高度 - 控制器高度
        let gameAreaHeight = screenHeight - controllerHeight
        
        // 计算游戏画面尺寸，应用用户缩放设置
        let gameAspectRatio = getAspectRatio()
        // 应用用户缩放设置（限制最大不超过可用空间）
        let gameWidth = min(screenWidth * gameScreenScale, screenWidth)
        let gameHeight = min(gameWidth / gameAspectRatio, gameAreaHeight - 20)
        
        ZStack {
            // 背景色
            skin.backgroundColor.color
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 游戏画面区域 - 在上半部分居中
                ZStack {
                    DeltaDisplayArea(
                        viewModel: viewModel,
                        theme: theme
                    )
                    .frame(width: gameWidth, height: gameHeight)
                }
                .frame(width: screenWidth, height: gameAreaHeight - (viewModel.game.system.hasShoulderButtons ? 36 : 0))
                
                // L/R 肩键区域 - 位于屏幕和控制器之间的过渡带
                if viewModel.game.system.hasShoulderButtons {
                    DeltaShoulderButtonBar(
                        theme: theme,
                        width: screenWidth - 32,
                        onInput: { input, pressed in
                            viewModel.handleInput(input, pressed: pressed)
                        }
                    )
                    .frame(height: 36)
                    .background(theme.controllerSurfaceGradient)
                }
                
                // 控制器区域 - 固定在底部，铺满左右
                DeltaControllerDeckView(
                    system: viewModel.game.system,
                    theme: theme,
                    height: controllerHeight,
                    bottomOffset: bottomOffset,
                    onInput: { input, pressed in
                        viewModel.handleInput(input, pressed: pressed)
                    },
                    onFastForward: { active in
                        if active {
                            viewModel.startFastForward()
                        } else {
                            viewModel.stopFastForward()
                        }
                    },
                    onMenuTapped: {
                        viewModel.pause()
                        withAnimation(.spring(response: 0.3)) {
                            showingPauseMenu = true
                        }
                    }
                )
                .frame(width: screenWidth, height: controllerHeight)
                .background(theme.controllerSurfaceGradient)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    // MARK: - 辅助视图
    
    private var fpsOverlay: some View {
        VStack {
            HStack {
                Spacer()
                Text(String(format: "%.1f FPS", viewModel.currentFPS))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.green)
                    .padding(6)
                    .background(.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(.trailing, 8)
                    .padding(.top, 8)
            }
            Spacer()
        }
    }
    
    private var fastForwardIndicator: some View {
                    VStack {
                        HStack {
                            Image(systemName: "forward.fill")
                            Text("\(viewModel.emulationSpeed.rawValue)")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.blue.opacity(0.8), in: Capsule())
                        .padding(.top, 50)
                        Spacer()
                    }
                }
                
    private var loadingOverlay: some View {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Loading...")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                
    private func errorOverlay(error: String) -> some View {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.yellow)
                        Text(error)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Button("Dismiss") {
                            appState.isEmulating = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
    }
    
    private func getAspectRatio() -> CGFloat {
        switch viewModel.game.system {
        case .gbc:
            return 10.0 / 9.0
        case .gba:
            return 3.0 / 2.0
        case .nds:
            return 256.0 / 384.0
        default:
            return 4.0 / 3.0
        }
    }
    
    private func setupGameController() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { _ in
            configureConnectedControllers()
        }
        
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { _ in
            showingController = GCController.controllers().isEmpty
        }
        
        configureConnectedControllers()
    }
    
    private func configureConnectedControllers() {
        for controller in GCController.controllers() {
            controller.extendedGamepad?.valueChangedHandler = { [weak viewModel] gamepad, element in
                guard let viewModel = viewModel else { return }
                
                viewModel.handleInput(.up, pressed: gamepad.dpad.up.isPressed)
                viewModel.handleInput(.down, pressed: gamepad.dpad.down.isPressed)
                viewModel.handleInput(.left, pressed: gamepad.dpad.left.isPressed)
                viewModel.handleInput(.right, pressed: gamepad.dpad.right.isPressed)
                viewModel.handleInput(.a, pressed: gamepad.buttonA.isPressed)
                viewModel.handleInput(.b, pressed: gamepad.buttonB.isPressed)
                viewModel.handleInput(.x, pressed: gamepad.buttonX.isPressed)
                viewModel.handleInput(.y, pressed: gamepad.buttonY.isPressed)
                viewModel.handleInput(.l, pressed: gamepad.leftShoulder.isPressed)
                viewModel.handleInput(.r, pressed: gamepad.rightShoulder.isPressed)
                viewModel.handleInput(.start, pressed: gamepad.buttonMenu.isPressed)
                viewModel.handleInput(.select, pressed: gamepad.buttonOptions?.isPressed ?? false)
            }
        }
        
        showingController = GCController.controllers().isEmpty
    }
}

// MARK: - Game Display View

struct GameDisplayView: View {
    @ObservedObject var viewModel: EmulationViewModel
    
    var body: some View {
        MetalGameView(viewModel: viewModel)
            .background(Color.black)
    }
}

// MARK: - Metal Game View

struct MetalGameView: UIViewRepresentable {
    @ObservedObject var viewModel: EmulationViewModel
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("❌ Failed to create Metal device")
            return mtkView
        }
        print("✅ Metal device created: \(device.name)")
        
        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 60
        mtkView.delegate = context.coordinator
        context.coordinator.setupMetal(device: device)
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.viewModel = viewModel
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var viewModel: EmulationViewModel
        private var commandQueue: MTLCommandQueue?
        private var pipelineState: MTLRenderPipelineState?
        private var texture: MTLTexture?
        private var vertexBuffer: MTLBuffer?
        private var samplerState: MTLSamplerState?
        
        init(viewModel: EmulationViewModel) {
            self.viewModel = viewModel
            super.init()
        }
        
        func setupMetal(device: MTLDevice) {
            print("🔧 Setting up Metal resources...")
            
            commandQueue = device.makeCommandQueue()
            if commandQueue == nil {
                print("❌ Failed to create command queue")
                return
            }
            print("✅ Command queue created")
            
            // Create sampler state
            let samplerDescriptor = MTLSamplerDescriptor()
            samplerDescriptor.minFilter = .nearest
            samplerDescriptor.magFilter = .nearest
            samplerDescriptor.sAddressMode = .clampToEdge
            samplerDescriptor.tAddressMode = .clampToEdge
            samplerState = device.makeSamplerState(descriptor: samplerDescriptor)
            if samplerState == nil {
                print("❌ Failed to create sampler state")
                return
            }
            print("✅ Sampler state created")
            
            // Create vertex buffer for a full-screen quad
            let vertices: [Float] = [
                // Position (x, y), TexCoord (u, v)
                -1.0, -1.0, 0.0, 1.0,  // bottom-left
                 1.0, -1.0, 1.0, 1.0,  // bottom-right
                -1.0,  1.0, 0.0, 0.0,  // top-left
                 1.0,  1.0, 1.0, 0.0,  // top-right
            ]
            vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: [])
            if vertexBuffer == nil {
                print("❌ Failed to create vertex buffer")
                return
            }
            print("✅ Vertex buffer created")
            
            // Create shader library and pipeline
            let shaderSource = """
            #include <metal_stdlib>
            using namespace metal;
            
            struct VertexOut {
                float4 position [[position]];
                float2 texCoord;
            };
            
            vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                                          constant float4 *vertexData [[buffer(0)]]) {
                VertexOut out;
                float4 vtx = vertexData[vertexID];
                out.position = float4(vtx.xy, 0.0, 1.0);
                out.texCoord = vtx.zw;
                return out;
            }
            
            fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                           texture2d<float> tex [[texture(0)]],
                                           sampler texSampler [[sampler(0)]]) {
                return tex.sample(texSampler, in.texCoord);
            }
            """
            
            do {
                let library = try device.makeLibrary(source: shaderSource, options: nil)
                print("✅ Shader library created")
                
                guard let vertexFunction = library.makeFunction(name: "vertexShader") else {
                    print("❌ Failed to find vertexShader function")
                    return
                }
                guard let fragmentFunction = library.makeFunction(name: "fragmentShader") else {
                    print("❌ Failed to find fragmentShader function")
                    return
                }
                print("✅ Shader functions loaded")
                
                let pipelineDescriptor = MTLRenderPipelineDescriptor()
                pipelineDescriptor.vertexFunction = vertexFunction
                pipelineDescriptor.fragmentFunction = fragmentFunction
                pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
                
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
                print("✅ Pipeline state created")
                print("✅ Metal setup complete!")
            } catch {
                print("❌ Failed to create Metal pipeline: \(error)")
            }
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        private var drawCount = 0
        
        func draw(in view: MTKView) {
            drawCount += 1
            
            guard let drawable = view.currentDrawable,
                  let commandQueue = commandQueue,
                  let pipelineState = pipelineState,
                  let vertexBuffer = vertexBuffer,
                  let samplerState = samplerState else {
                if drawCount <= 3 {
                    print("⚠️ Metal draw: missing resources")
                }
                return
            }
            
            // Get video frame data from view model
            guard let videoData = viewModel.getVideoBuffer(),
                  videoData.width > 0 && videoData.height > 0 else {
                if drawCount <= 10 || drawCount % 60 == 0 {
                    print("⚠️ Metal draw #\(drawCount): no video data, videoFrameCount=\(viewModel.videoFrameCount)")
                }
                // No video data, just clear the screen
                guard let commandBuffer = commandQueue.makeCommandBuffer(),
                      let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
                
                if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                    renderEncoder.endEncoding()
                }
                commandBuffer.present(drawable)
                commandBuffer.commit()
                return
            }
            
            #if DEBUG
            if drawCount <= 3 {
                print("🖼️ Rendering: \(videoData.width)x\(videoData.height), format: \(videoData.pixelFormat)")
            }
            #endif
            
            // Create or update texture
            if texture == nil || texture!.width != videoData.width || texture!.height != videoData.height {
                let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .bgra8Unorm,
                    width: videoData.width,
                    height: videoData.height,
                    mipmapped: false
                )
                textureDescriptor.usage = [.shaderRead]
                texture = view.device?.makeTexture(descriptor: textureDescriptor)
                #if DEBUG
                print("🖼️ Texture created: \(videoData.width)x\(videoData.height)")
                #endif
            }
            
            guard let texture = texture else {
                print("⚠️ Metal draw: texture is nil")
                return
            }
            
            // Convert to BGRA8888 based on pixel format
            // Note: pitch is in bytes, and may include padding
            let width = videoData.width
            let height = videoData.height
            let srcPitch = videoData.pitch  // Source pitch in bytes
            var bgraData = [UInt8](repeating: 0, count: width * height * 4)
            
            videoData.data.withUnsafeBytes { srcBuffer in
                let srcBytes = srcBuffer.bindMemory(to: UInt8.self)
                
                switch videoData.pixelFormat {
                case .xrgb8888:
                    // XRGB8888: 4 bytes per pixel (X, R, G, B in memory as little-endian)
                    // Memory layout: B, G, R, X (little-endian)
                    for y in 0..<height {
                        let srcRowStart = y * srcPitch
                        let dstRowStart = y * width * 4
                        
                        for x in 0..<width {
                            let srcOffset = srcRowStart + x * 4
                            let dstOffset = dstRowStart + x * 4
                            
                            // XRGB8888 little-endian: memory is [B, G, R, X]
                            // We need BGRA, so just copy and set alpha
                            bgraData[dstOffset + 0] = srcBytes[srcOffset + 0]  // B
                            bgraData[dstOffset + 1] = srcBytes[srcOffset + 1]  // G
                            bgraData[dstOffset + 2] = srcBytes[srcOffset + 2]  // R
                            bgraData[dstOffset + 3] = 255  // A (replace X with full alpha)
                        }
                    }
                    
                case .rgb565:
                    // RGB565: 2 bytes per pixel
                    for y in 0..<height {
                        let srcRowStart = y * srcPitch
                        let dstRowStart = y * width * 4
                        
                        for x in 0..<width {
                            let srcOffset = srcRowStart + x * 2
                            let lo = UInt16(srcBytes[srcOffset])
                            let hi = UInt16(srcBytes[srcOffset + 1])
                            let pixel = lo | (hi << 8)
                            
                            // RGB565: RRRRRGGGGGGBBBBB
                            let r = UInt8((pixel >> 11) & 0x1F) << 3
                            let g = UInt8((pixel >> 5) & 0x3F) << 2
                            let b = UInt8(pixel & 0x1F) << 3
                            
                            let dstOffset = dstRowStart + x * 4
                            bgraData[dstOffset + 0] = b  // B
                            bgraData[dstOffset + 1] = g  // G
                            bgraData[dstOffset + 2] = r  // R
                            bgraData[dstOffset + 3] = 255  // A
                        }
                    }
                    
                case .rgb1555:
                    // RGB1555 (0RGB1555): 2 bytes per pixel
                    for y in 0..<height {
                        let srcRowStart = y * srcPitch
                        let dstRowStart = y * width * 4
                        
                        for x in 0..<width {
                            let srcOffset = srcRowStart + x * 2
                            let lo = UInt16(srcBytes[srcOffset])
                            let hi = UInt16(srcBytes[srcOffset + 1])
                            let pixel = lo | (hi << 8)
                            
                            // 0RGB1555: 0RRRRRGGGGGBBBBB
                            let r = UInt8((pixel >> 10) & 0x1F) << 3
                            let g = UInt8((pixel >> 5) & 0x1F) << 3
                            let b = UInt8(pixel & 0x1F) << 3
                            
                            let dstOffset = dstRowStart + x * 4
                            bgraData[dstOffset + 0] = b  // B
                            bgraData[dstOffset + 1] = g  // G
                            bgraData[dstOffset + 2] = r  // R
                            bgraData[dstOffset + 3] = 255  // A
                        }
                    }
                }
            }
            
            let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                   size: MTLSize(width: width, height: height, depth: 1))
            texture.replace(region: region, mipmapLevel: 0, withBytes: bgraData, bytesPerRow: width * 4)
            
            // Debug: Check if we have non-zero pixel data (only log if all black)
            #if DEBUG
            if drawCount <= 5 || drawCount % 300 == 0 {
                var nonZeroCount = 0
                for i in stride(from: 0, to: min(1000, bgraData.count), by: 4) {
                    if bgraData[i] != 0 || bgraData[i+1] != 0 || bgraData[i+2] != 0 {
                        nonZeroCount += 1
                        break
                    }
                }
                if nonZeroCount == 0 {
                    print("⚠️ Frame #\(drawCount): All pixels are black (game may be loading or needs input)")
                }
            }
            #endif
            
            // Render
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                if drawCount <= 5 {
                    print("⚠️ Failed to create render resources")
                }
                return
            }
            
            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.setFragmentTexture(texture, index: 0)
            renderEncoder.setFragmentSamplerState(samplerState, index: 0)
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
            
        }
    }
}

// MARK: - Virtual Controller View

struct VirtualControllerView: View {
    let system: GameSystem
    let screenSize: CGSize
    let safeAreaInsets: EdgeInsets
    let isLandscape: Bool
    let isIPad: Bool
    let skin: ControllerSkin
    let opacity: Double
    let onInput: (GameInput, Bool) -> Void
    let onFastForward: (Bool) -> Void
    let onMenuTapped: () -> Void
    
    @State private var hapticEngine: CHHapticEngine?
    @AppStorage("controllerSize") private var controllerSizeMultiplier = 1.0
    @AppStorage("controllerHaptics") private var hapticsEnabled = true
    
    var body: some View {
        let layout = ControllerLayoutCalculator(
            screenSize: screenSize,
            safeAreaInsets: safeAreaInsets,
            isLandscape: isLandscape,
            isIPad: isIPad,
            sizeMultiplier: controllerSizeMultiplier
            )
            
            ZStack {
            if isLandscape {
                // 横屏布局
                landscapeControllerLayout(layout: layout)
            } else {
                // 竖屏布局 - 控制器填满整个区域
                portraitControllerLayout(layout: layout)
            }
        }
        .onAppear {
            setupHaptics()
        }
    }
    
    // MARK: - 横屏控制器布局
    
    @ViewBuilder
    private func landscapeControllerLayout(layout: ControllerLayoutCalculator) -> some View {
        HStack(spacing: 0) {
            // 左侧区域 - D-Pad + L肩键
            VStack {
                // L 肩键
                if system.hasShoulderButtons {
                    SkinnedShoulderButton(
                        label: "L",
                        skin: skin,
                        size: layout.shoulderButtonSize,
                        onPressed: { onInput(.l, $0) },
                        hapticEngine: hapticsEnabled ? hapticEngine : nil
                    )
                    .padding(.top, layout.shoulderTopPadding)
                }
            
            Spacer()
            
                // D-Pad
                SkinnedDPad(
                    skin: skin,
                    size: layout.dpadSize,
                    onInput: onInput,
                    hapticEngine: hapticsEnabled ? hapticEngine : nil
                )
                .padding(.bottom, layout.controlsBottomPadding)
            }
            .frame(width: layout.sideAreaWidth)
            .padding(.leading, layout.sidePadding)
            
            Spacer()
            
            // 右侧区域 - 动作按钮 + R肩键
            VStack {
                // R 肩键
                if system.hasShoulderButtons {
                    SkinnedShoulderButton(
                        label: "R",
                        skin: skin,
                        size: layout.shoulderButtonSize,
                        onPressed: { onInput(.r, $0) },
                        hapticEngine: hapticsEnabled ? hapticEngine : nil
                    )
                    .padding(.top, layout.shoulderTopPadding)
                }
                
                Spacer()
                
                // 动作按钮
                SkinnedActionButtons(
                    system: system,
                    skin: skin,
                    size: layout.actionButtonsSize,
                    onInput: onInput,
                    hapticEngine: hapticsEnabled ? hapticEngine : nil
                )
                .padding(.bottom, layout.controlsBottomPadding)
            }
            .frame(width: layout.sideAreaWidth)
            .padding(.trailing, layout.sidePadding)
        }
        
        // 中央系统按钮 (叠加层)
        VStack {
            // 顶部工具栏
            HStack {
                // 快进按钮
                SkinnedToolButton(
                    icon: "forward.fill",
                    skin: skin,
                    onFastForward: onFastForward,
                    hapticEngine: hapticsEnabled ? hapticEngine : nil
                )
                
                Spacer()
                
                // 菜单按钮
                SkinnedMenuButton(
                    skin: skin,
                    onTapped: onMenuTapped,
                    hapticEngine: hapticsEnabled ? hapticEngine : nil
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, safeAreaInsets.top + 8)
                
                Spacer()
                
            // 底部 SELECT/START
            HStack(spacing: layout.systemButtonSpacing) {
                SkinnedSystemButton(
                    label: "SELECT",
                    skin: skin,
                    size: layout.systemButtonSize,
                    onPressed: { onInput(.select, $0) },
                    hapticEngine: hapticsEnabled ? hapticEngine : nil
                )
                
                SkinnedSystemButton(
                    label: "START",
                    skin: skin,
                    size: layout.systemButtonSize,
                    onPressed: { onInput(.start, $0) },
                    hapticEngine: hapticsEnabled ? hapticEngine : nil
                )
            }
            .padding(.bottom, safeAreaInsets.bottom + 12)
        }
    }
    
    // MARK: - 竖屏控制器布局
    
    @ViewBuilder
    private func portraitControllerLayout(layout: ControllerLayoutCalculator) -> some View {
        VStack(spacing: 0) {
            // 肩键区域 (放在最顶部)
            if system.hasShoulderButtons {
        HStack {
                    SkinnedShoulderButton(
                        label: "L",
                        skin: skin,
                        size: layout.shoulderButtonSize,
                        onPressed: { onInput(.l, $0) },
                        hapticEngine: hapticsEnabled ? hapticEngine : nil
                    )
                    
                    Spacer()
                    
                    SkinnedShoulderButton(
                        label: "R",
                        skin: skin,
                        size: layout.shoulderButtonSize,
                        onPressed: { onInput(.r, $0) },
                        hapticEngine: hapticsEnabled ? hapticEngine : nil
                    )
                }
                .padding(.horizontal, layout.sidePadding + 8)
                .padding(.top, 12)
            }
            
            // 中间功能栏 - SELECT/MENU/START
            HStack(spacing: 16) {
                // 快进按钮
                SkinnedToolButton(
                    icon: "forward.fill",
                    skin: skin,
                    onFastForward: onFastForward,
                    hapticEngine: hapticsEnabled ? hapticEngine : nil
                )
                
                Spacer()
                
                // SELECT
                SkinnedSystemButton(
                    label: "SELECT",
                    skin: skin,
                    size: layout.systemButtonSize,
                    onPressed: { onInput(.select, $0) },
                    hapticEngine: hapticsEnabled ? hapticEngine : nil
                )
                
                // 菜单按钮
                SkinnedMenuButton(
                    skin: skin,
                    onTapped: onMenuTapped,
                    hapticEngine: hapticsEnabled ? hapticEngine : nil
                )
                
                // START
                SkinnedSystemButton(
                    label: "START",
                    skin: skin,
                    size: layout.systemButtonSize,
                    onPressed: { onInput(.start, $0) },
                    hapticEngine: hapticsEnabled ? hapticEngine : nil
                )
                
                Spacer()
                
                // 占位保持平衡
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            .padding(.top, system.hasShoulderButtons ? 16 : 12)
            
            Spacer(minLength: 20)
            
            // 主控制区域 - D-Pad 和动作按钮
            HStack(alignment: .center) {
            // D-Pad
                SkinnedDPad(
                    skin: skin,
                    size: layout.dpadSize,
                    onInput: onInput,
                    hapticEngine: hapticsEnabled ? hapticEngine : nil
                )
                .padding(.leading, layout.sidePadding)
            
            Spacer()
            
                // 动作按钮
                SkinnedActionButtons(
                    system: system,
                    skin: skin,
                    size: layout.actionButtonsSize,
                    onInput: onInput,
                    hapticEngine: hapticsEnabled ? hapticEngine : nil
                )
                .padding(.trailing, layout.sidePadding)
            }
            .padding(.bottom, layout.controllerBottomPadding)
        }
    }
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine failed: \(error)")
        }
    }
}

// MARK: - Controller Layout Calculator

struct ControllerLayoutCalculator {
    let screenSize: CGSize
    let safeAreaInsets: EdgeInsets
    let isLandscape: Bool
    let isIPad: Bool
    let sizeMultiplier: Double
    
    // D-Pad 尺寸 - 横屏时根据屏幕高度动态计算
    var dpadSize: CGFloat {
        let base: CGFloat
        if isIPad {
            base = isLandscape ? 140 : 160
        } else {
            if isLandscape {
                // 横屏时根据屏幕高度动态计算，确保有足够空间
                let availableHeight = screenSize.height - safeAreaInsets.top - safeAreaInsets.bottom - 80
                let calculated = min(availableHeight * 0.55, screenSize.width * 0.18)
                base = max(110, min(calculated, 140))
            } else {
                // 竖屏时 D-Pad 占屏幕宽度的 38%，更大更易操作
                let calculated = screenSize.width * 0.38
                base = max(130, min(calculated, 170))
            }
        }
        return base * sizeMultiplier
    }
    
    // 动作按钮区域尺寸 - 横屏时根据屏幕高度动态计算
    var actionButtonsSize: CGFloat {
        let base: CGFloat
        if isIPad {
            base = isLandscape ? 140 : 160
        } else {
            if isLandscape {
                // 横屏时根据屏幕高度动态计算，确保有足够空间放置4个按钮
                let availableHeight = screenSize.height - safeAreaInsets.top - safeAreaInsets.bottom - 80
                let calculated = min(availableHeight * 0.55, screenSize.width * 0.18)
                base = max(110, min(calculated, 140))
            } else {
                // 竖屏时动作按钮区域占屏幕宽度的 38%，更大更易操作
                let calculated = screenSize.width * 0.38
                base = max(130, min(calculated, 170))
            }
        }
        return base * sizeMultiplier
    }
    
    // 肩键尺寸 - 竖屏时更大
    var shoulderButtonSize: CGSize {
        let width: CGFloat
        let height: CGFloat
        if isIPad {
            width = isLandscape ? 85 : 100
            height = isLandscape ? 42 : 48
        } else {
            if isLandscape {
                width = 70
                height = 34
            } else {
                // 竖屏时肩键更大更易触摸
                width = 85
                height = 40
            }
        }
        return CGSize(width: width * sizeMultiplier, height: height * sizeMultiplier)
    }
    
    // 系统按钮尺寸
    var systemButtonSize: CGSize {
        let width: CGFloat
        let height: CGFloat
        if isIPad {
            width = 70
            height = 28
        } else {
            width = isLandscape ? 52 : 58
            height = isLandscape ? 22 : 24
        }
        return CGSize(width: width, height: height)
    }
    
    // 系统按钮间距
    var systemButtonSpacing: CGFloat {
        isIPad ? 24 : (isLandscape ? 16 : 10)
    }
    
    // 侧边区域宽度 (横屏) - 根据屏幕宽度动态计算
    var sideAreaWidth: CGFloat {
        if isIPad {
            return isLandscape ? 200 : 160
        }
        if isLandscape {
            // 横屏时根据屏幕宽度动态计算，确保有足够空间放置控制器
            let calculated = screenSize.width * 0.20
            return max(150, min(calculated, 180))
        }
        return 120
    }
    
    // 侧边内边距 - 竖屏时更小以给按钮更多空间
    var sidePadding: CGFloat {
        if isIPad {
            return isLandscape ? 30 : 12
        }
        return isLandscape ? 16 : 4
    }
    
    // 底部安全区域高度
    var bottomSafeArea: CGFloat {
        // 确保底部有足够空间，至少 34pt（iPhone X 系列的 Home Indicator 高度）
        max(safeAreaInsets.bottom, 20)
    }
    
    // 控制器底部边距（考虑安全区域）
    var controllerBottomPadding: CGFloat {
        // 在安全区域基础上额外增加一些间距
        bottomSafeArea + 8
    }
    
    // 肩键顶部边距
    var shoulderTopPadding: CGFloat {
        safeAreaInsets.top + (isIPad ? 20 : 12)
    }
    
    // 控制区域底部边距
    var controlsBottomPadding: CGFloat {
        safeAreaInsets.bottom + (isIPad ? 30 : 20)
    }
}

// MARK: - 皮肤化 D-Pad 组件（支持八方向输入）

struct SkinnedDPad: View {
    let skin: ControllerSkin
    let size: CGFloat
    let onInput: (GameInput, Bool) -> Void
    let hapticEngine: CHHapticEngine?
    
    // 当前按下的方向集合（支持多个方向同时按下，实现斜向输入）
    @State private var pressedDirections: Set<GameInput> = []
    
    var body: some View {
        ZStack {
            // D-Pad 底座 - 使用皮肤颜色
            Circle()
                .fill(skin.backgroundColor.color.opacity(0.9))
                .frame(width: size, height: size)
                .shadow(color: skin.dpadColor.color.opacity(0.3), radius: 8, y: 4)
            
            // 十字键背景
            DPadCrossShape()
                .fill(skin.dpadColor.color.opacity(0.8))
                .frame(width: size * 0.85, height: size * 0.85)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
            
            // 十字键边框
            DPadCrossShape()
                .stroke(skin.dpadColor.color.opacity(0.3), lineWidth: 1)
                .frame(width: size * 0.85, height: size * 0.85)
            
            // 方向高亮指示
            ForEach([GameInput.up, .down, .left, .right], id: \.self) { direction in
                if pressedDirections.contains(direction) {
                    directionHighlight(for: direction)
                }
            }
            
            // 方向箭头图标
            ForEach([GameInput.up, .down, .left, .right], id: \.self) { direction in
                directionIcon(for: direction)
            }
            
            // 中心圆点装饰
            Circle()
                .fill(skin.dpadColor.color.opacity(0.5))
                .frame(width: size * 0.12, height: size * 0.12)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDrag(at: value.location)
                }
                .onEnded { _ in
                    releaseAllDirections()
                }
        )
    }
    
    // 处理拖拽手势，计算八方向输入
    private func handleDrag(at location: CGPoint) {
        let center = CGPoint(x: size / 2, y: size / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        
        // 计算距离中心的距离
        let distance = sqrt(dx * dx + dy * dy)
        
        // 如果在中心死区内，释放所有方向
        let deadZone = size * 0.12
        guard distance > deadZone else {
            releaseAllDirections()
            return
        }
        
        // 计算新的方向组合（支持斜向 - 8方向）
        var newDirections: Set<GameInput> = []
        
        // 使用阈值来判断是否激活某个方向
        let threshold = size * 0.1
        
        // 水平方向
        if dx > threshold {
            newDirections.insert(.right)
        } else if dx < -threshold {
            newDirections.insert(.left)
        }
        
        // 垂直方向
        if dy > threshold {
            newDirections.insert(.down)
        } else if dy < -threshold {
            newDirections.insert(.up)
        }
        
        // 更新方向状态
        updateDirections(newDirections)
    }
    
    // 更新方向状态，处理按下和释放事件
    private func updateDirections(_ newDirections: Set<GameInput>) {
        // 找出需要释放的方向
        let toRelease = pressedDirections.subtracting(newDirections)
        for dir in toRelease {
            onInput(dir, false)
        }
        
        // 找出需要按下的方向
        let toPress = newDirections.subtracting(pressedDirections)
        for dir in toPress {
            onInput(dir, true)
            playHaptic()
        }
        
        pressedDirections = newDirections
    }
    
    // 释放所有方向
    private func releaseAllDirections() {
        for dir in pressedDirections {
            onInput(dir, false)
        }
        pressedDirections.removeAll()
    }
    
    // 方向高亮效果
    @ViewBuilder
    private func directionHighlight(for direction: GameInput) -> some View {
        let offset: CGFloat = size * 0.28
        Circle()
            .fill(skin.buttonPressedColor.color.opacity(0.4))
            .frame(width: size * 0.25, height: size * 0.25)
            .offset(
                x: direction == .right ? offset : (direction == .left ? -offset : 0),
                y: direction == .down ? offset : (direction == .up ? -offset : 0)
            )
    }
    
    // 方向图标
    @ViewBuilder
    private func directionIcon(for direction: GameInput) -> some View {
        let offset: CGFloat = size * 0.28
        let isPressed = pressedDirections.contains(direction)
        
        Image(systemName: iconName(for: direction))
            .font(.system(size: size * 0.15, weight: .bold))
            .foregroundStyle(isPressed ? .white : skin.dpadColor.color.opacity(0.6))
            .offset(
                x: direction == .right ? offset : (direction == .left ? -offset : 0),
                y: direction == .down ? offset : (direction == .up ? -offset : 0)
            )
    }
    
    private func iconName(for direction: GameInput) -> String {
        switch direction {
        case .up: return "chevron.up"
        case .down: return "chevron.down"
        case .left: return "chevron.left"
        case .right: return "chevron.right"
        default: return ""
        }
    }
    
    private func playHaptic() {
        guard let engine = hapticEngine else { return }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {}
    }
}

struct DPadCrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let armWidth = width * 0.38
        let cornerRadius = armWidth * 0.15
        let centerX = width / 2
        let centerY = height / 2
        let halfArm = armWidth / 2
        
        path.addRoundedRect(in: CGRect(x: centerX - halfArm, y: 0, width: armWidth, height: centerY + halfArm), cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        path.addRoundedRect(in: CGRect(x: centerX - halfArm, y: centerY - halfArm, width: armWidth, height: centerY + halfArm), cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        path.addRoundedRect(in: CGRect(x: 0, y: centerY - halfArm, width: centerX + halfArm, height: armWidth), cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        path.addRoundedRect(in: CGRect(x: centerX - halfArm, y: centerY - halfArm, width: centerX + halfArm, height: armWidth), cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        
        return path
    }
}

// MARK: - 皮肤化动作按钮组（Delta 风格设计）

struct SkinnedActionButtons: View {
    let system: GameSystem
    let skin: ControllerSkin
    let size: CGFloat
    let onInput: (GameInput, Bool) -> Void
    let hapticEngine: CHHapticEngine?
    
    // 按钮尺寸：有XY按钮时稍小一点，避免重叠
    private var buttonSize: CGFloat {
        system.hasXYButtons ? size * 0.35 : size * 0.40
    }
    
    // 按钮偏移量：有XY按钮时增大间距，避免挤在一起
    private var buttonOffset: CGFloat {
        system.hasXYButtons ? size * 0.32 : size * 0.28
    }
    
    // 按钮颜色配置（SNES 风格彩色按钮）
    private func buttonColor(for input: GameInput) -> Color {
        switch input {
        case .a: return Color(red: 0.9, green: 0.2, blue: 0.2)   // 红色
        case .b: return Color(red: 0.95, green: 0.75, blue: 0.1) // 黄色
        case .x: return Color(red: 0.2, green: 0.5, blue: 0.9)   // 蓝色
        case .y: return Color(red: 0.2, green: 0.75, blue: 0.3)  // 绿色
        default: return skin.buttonColor.color
        }
    }
    
    var body: some View {
        ZStack {
            // 按钮区域底座 - 深色圆形背景
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            skin.backgroundColor.color.blended(with: .black, amount: 0.15),
                            skin.backgroundColor.color.blended(with: .black, amount: 0.25)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 1.1, height: size * 1.1)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
            
            if system.hasXYButtons {
                // 四按钮布局 (XYAB)
                // Y 按钮 (左)
                ColoredActionButton(
                    label: "Y",
                    color: buttonColor(for: .y),
                    size: buttonSize,
                    onPressed: { onInput(.y, $0) },
                    hapticEngine: hapticEngine
                )
                .offset(x: -buttonOffset, y: 0)
                
                // X 按钮 (上)
                ColoredActionButton(
                    label: "X",
                    color: buttonColor(for: .x),
                    size: buttonSize,
                    onPressed: { onInput(.x, $0) },
                    hapticEngine: hapticEngine
                )
                .offset(x: 0, y: -buttonOffset)
                
                // A 按钮 (右)
                ColoredActionButton(
                    label: "A",
                    color: buttonColor(for: .a),
                    size: buttonSize,
                    onPressed: { onInput(.a, $0) },
                    hapticEngine: hapticEngine
                )
                .offset(x: buttonOffset, y: 0)
                
                // B 按钮 (下)
                ColoredActionButton(
                    label: "B",
                    color: buttonColor(for: .b),
                    size: buttonSize,
                    onPressed: { onInput(.b, $0) },
                    hapticEngine: hapticEngine
                )
                .offset(x: 0, y: buttonOffset)
            } else {
                // 两按钮布局 (AB)
                // B 按钮 (左下)
                ColoredActionButton(
                    label: "B",
                    color: buttonColor(for: .b),
                    size: buttonSize,
                    onPressed: { onInput(.b, $0) },
                    hapticEngine: hapticEngine
                )
                .offset(x: -buttonOffset * 0.5, y: buttonOffset * 0.3)
                
                // A 按钮 (右上)
                ColoredActionButton(
                    label: "A",
                    color: buttonColor(for: .a),
                    size: buttonSize,
                    onPressed: { onInput(.a, $0) },
                    hapticEngine: hapticEngine
                )
                .offset(x: buttonOffset * 0.5, y: -buttonOffset * 0.3)
            }
        }
    }
}

// MARK: - 彩色动作按钮（Delta 风格）

struct ColoredActionButton: View {
    let label: String
    let color: Color
    let size: CGFloat
    let onPressed: (Bool) -> Void
    let hapticEngine: CHHapticEngine?
    
    @State private var isPressed = false
    
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        color.blended(with: .white, amount: isPressed ? 0.0 : 0.2),
                        color.blended(with: .black, amount: isPressed ? 0.1 : 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .stroke(Color.black.opacity(0.25), lineWidth: 1)
            }
            .overlay {
                // 高光效果
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(isPressed ? 0.1 : 0.3), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .frame(width: size * 0.85, height: size * 0.85)
                    .offset(x: -size * 0.05, y: -size * 0.05)
            }
            .overlay {
                Text(label)
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
            }
            .scaleEffect(isPressed ? 0.92 : 1)
            .shadow(color: .black.opacity(0.3), radius: isPressed ? 3 : 6, y: isPressed ? 2 : 4)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        onPressed(true)
                        playHaptic()
                    }
                    .onEnded { _ in
                        isPressed = false
                        onPressed(false)
                    }
            )
            .animation(.easeOut(duration: 0.08), value: isPressed)
    }
    
    private func playHaptic() {
        guard let engine = hapticEngine else { return }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {}
    }
}

struct SkinnedActionButton: View {
    let label: String
    let skin: ControllerSkin
    let size: CGFloat
    let onPressed: (Bool) -> Void
    let hapticEngine: CHHapticEngine?
    
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            // 按钮阴影
            buttonShape
                .fill(skin.buttonColor.color.opacity(0.3))
                .frame(width: size, height: size)
                .offset(y: isPressed ? 1 : 3)
            
            // 按钮主体
            buttonShape
                .fill(
                    LinearGradient(
                        colors: [
                            isPressed ? skin.buttonPressedColor.color : skin.buttonColor.color,
                            isPressed ? skin.buttonPressedColor.color.opacity(0.8) : skin.buttonColor.color.opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)
                .overlay {
                    // 高光
                    buttonShape
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(isPressed ? 0.1 : 0.25), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .frame(width: size * 0.9, height: size * 0.9)
                }
                .overlay {
                    Text(label)
                        .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                }
                .offset(y: isPressed ? 2 : 0)
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeOut(duration: 0.08), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        onPressed(true)
                        playHaptic()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    onPressed(false)
                }
        )
    }
    
    private var buttonShape: AnyShape {
        switch skin.buttonStyle {
        case .circle:
            return AnyShape(Circle())
        case .rounded:
            return AnyShape(RoundedRectangle(cornerRadius: size * 0.2))
        case .square:
            return AnyShape(RoundedRectangle(cornerRadius: size * 0.05))
        }
    }
    
    private func playHaptic() {
        guard let engine = hapticEngine else { return }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {}
    }
}

// MARK: - 皮肤化系统按钮 (SELECT/START)

struct SkinnedSystemButton: View {
    let label: String
    let skin: ControllerSkin
    let size: CGSize
    let onPressed: (Bool) -> Void
    let hapticEngine: CHHapticEngine?
    
    @State private var isPressed = false
    
    var body: some View {
        Capsule()
            .fill(isPressed ? skin.buttonPressedColor.color.opacity(0.8) : skin.buttonColor.color.opacity(0.6))
            .frame(width: size.width, height: size.height)
        .overlay {
            Text(label)
                    .font(.system(size: size.height * 0.4, weight: .bold, design: .rounded))
                    .foregroundStyle(isPressed ? .white : .white.opacity(0.8))
        }
            .shadow(color: skin.buttonColor.color.opacity(0.3), radius: 2, y: 1)
        .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.08), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                            isPressed = true
                            onPressed(true)
                        playHaptic()
                    }
                }
                .onEnded { _ in
                        isPressed = false
                        onPressed(false)
                }
        )
    }
    
    private func playHaptic() {
        guard let engine = hapticEngine else { return }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {}
    }
}

// MARK: - 皮肤化菜单按钮

struct SkinnedMenuButton: View {
    let skin: ControllerSkin
    let onTapped: () -> Void
    let hapticEngine: CHHapticEngine?
    
    @State private var isPressed = false
    
    var body: some View {
        Circle()
            .fill(isPressed ? skin.buttonPressedColor.color : skin.buttonColor.color.opacity(0.7))
            .frame(width: 44, height: 44)
            .overlay {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: skin.buttonColor.color.opacity(0.4), radius: 4, y: 2)
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            playHaptic()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        onTapped()
                    }
            )
    }
    
    private func playHaptic() {
        guard let engine = hapticEngine else { return }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {}
    }
}

// MARK: - 皮肤化肩键

struct SkinnedShoulderButton: View {
    let label: String
    let skin: ControllerSkin
    let size: CGSize
    let onPressed: (Bool) -> Void
    let hapticEngine: CHHapticEngine?
    
    @State private var isPressed = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: size.height * 0.3)
            .fill(
                LinearGradient(
                    colors: [
                        isPressed ? skin.buttonPressedColor.color : skin.buttonColor.color,
                        isPressed ? skin.buttonPressedColor.color.opacity(0.8) : skin.buttonColor.color.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size.width, height: size.height)
            .overlay {
                Text(label)
                    .font(.system(size: size.height * 0.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .shadow(color: skin.buttonColor.color.opacity(0.4), radius: 3, y: 2)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .offset(y: isPressed ? 2 : 0)
            .animation(.easeOut(duration: 0.08), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            onPressed(true)
                            playHaptic()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        onPressed(false)
                    }
            )
    }
    
    private func playHaptic() {
        guard let engine = hapticEngine else { return }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {}
    }
}

// MARK: - 皮肤化工具按钮 (快进)

struct SkinnedToolButton: View {
    let icon: String
    let skin: ControllerSkin
    let onFastForward: (Bool) -> Void
    let hapticEngine: CHHapticEngine?
    
    @State private var isPressed = false
    
    var body: some View {
        Circle()
            .fill(isPressed ? skin.buttonPressedColor.color.opacity(0.8) : skin.buttonColor.color.opacity(0.5))
            .frame(width: 40, height: 40)
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isPressed ? .white : .white.opacity(0.8))
            }
            .shadow(color: skin.buttonColor.color.opacity(0.3), radius: 2, y: 1)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.08), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            onFastForward(true)
                            playHaptic()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        onFastForward(false)
                    }
            )
    }
    
    private func playHaptic() {
        guard let engine = hapticEngine else { return }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {}
    }
}

// MARK: - Pause Menu View

struct PauseMenuView: View {
    let game: Game
    @ObservedObject var viewModel: EmulationViewModel
    let onResume: () -> Void
    let onQuit: () -> Void
    let onSaveStates: () -> Void
    
    @State private var showingSpeedPicker = false
    @State private var showingScreenshotSaved = false
    @State private var showingCheats = false
    @State private var showingGameInfo = false
    @State private var showingSkinPicker = false
    
    @ObservedObject private var skinManager = ControllerSkinManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isPortrait = geometry.size.height > geometry.size.width
            let useCompactLayout = isCompact && isPortrait
            
        ZStack {
                Color.black.opacity(0.85)
                .ignoresSafeArea()
                    .onTapGesture {
                        onResume()
                    }
                
                if useCompactLayout {
                    // 竖屏紧凑布局 - 滚动视图
                    compactMenuLayout
                } else {
                    // 横屏/iPad 布局 - 两列
                    regularMenuLayout
                }
                
                // 截图保存提示
                if showingScreenshotSaved {
                    screenshotToast
                }
            }
        }
        .sheet(isPresented: $showingSpeedPicker) {
            SpeedPickerSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingCheats) {
            CheatManagerView(game: game)
        }
        .sheet(isPresented: $showingGameInfo) {
            GameInfoView(game: game)
        }
        .sheet(isPresented: $showingSkinPicker) {
            SkinPickerSheet(onSkinSelected: {
                // 选择皮肤后关闭暂停菜单，恢复游戏
                onResume()
            })
                .presentationDetents([.medium, .large])
        }
    }
    
    // MARK: - 紧凑布局 (竖屏 iPhone)
    
    private var compactMenuLayout: some View {
        VStack(spacing: 0) {
            // 顶部标题
            VStack(spacing: 4) {
                Text(game.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(game.system.displayName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // 按钮网格 - 2x4 布局
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                CompactMenuButton(title: "pause.resume".localized, icon: "play.fill", color: .green) {
                    onResume()
                }
                
                CompactMenuButton(title: "pause.save".localized, icon: "square.stack.3d.up", color: .blue) {
                    onSaveStates()
                }
                
                CompactMenuButton(title: "pause.screenshot".localized, icon: "camera.fill", color: .orange) {
                    Task {
                        _ = try? await viewModel.saveScreenshot()
                        showingScreenshotSaved = true
                    }
                }
                
                CompactMenuButton(title: "pause.speed".localized, icon: "speedometer", color: .purple) {
                    showingSpeedPicker = true
                }
                
                CompactMenuButton(title: "pause.cheats".localized, icon: "wand.and.stars", color: .pink) {
                    showingCheats = true
                }
                
                CompactMenuButton(title: "pause.reset".localized, icon: "arrow.counterclockwise", color: .yellow) {
                    viewModel.reset()
                    onResume()
                }
                
                CompactMenuButton(title: "pause.info".localized, icon: "info.circle", color: .cyan) {
                    showingGameInfo = true
                }
                
                CompactMenuButton(title: "pause.skin".localized, icon: "paintpalette.fill", color: .indigo) {
                    showingSkinPicker = true
                }
                
                CompactMenuButton(title: "pause.quit".localized, icon: "xmark.circle", color: .red) {
                    onQuit()
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
    
    // MARK: - 常规布局 (横屏/iPad)
    
    private var regularMenuLayout: some View {
        VStack(spacing: 20) {
            // 游戏标题
            VStack(spacing: 6) {
                    Text(game.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text(game.system.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
            // 菜单按钮 - 两列
                HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 10) {
                        PauseMenuButton(title: "pause.resume".localized, systemImage: "play.fill") {
                            onResume()
                        }
                        
                        PauseMenuButton(title: "pause.saveStates".localized, systemImage: "square.stack.3d.up") {
                            onSaveStates()
                        }
                        
                        PauseMenuButton(title: "pause.screenshot".localized, systemImage: "camera.fill") {
                            Task {
                            _ = try? await viewModel.saveScreenshot()
                                showingScreenshotSaved = true
                            }
                        }
                        
                        PauseMenuButton(title: "pause.cheats".localized, systemImage: "wand.and.stars") {
                            showingCheats = true
                        }
                    }
                    
                VStack(spacing: 10) {
                        PauseMenuButton(
                            title: "pause.speed.current".localized(viewModel.emulationSpeed.rawValue),
                            systemImage: "speedometer"
                        ) {
                            showingSpeedPicker = true
                        }
                        
                        PauseMenuButton(title: "pause.controllerSkin".localized, systemImage: "paintpalette.fill") {
                            showingSkinPicker = true
                        }
                        
                        PauseMenuButton(title: "pause.gameInfo".localized, systemImage: "info.circle") {
                            showingGameInfo = true
                        }
                        
                        PauseMenuButton(title: "pause.reset".localized, systemImage: "arrow.counterclockwise") {
                            viewModel.reset()
                            onResume()
                        }
                        
                        PauseMenuButton(title: "pause.quit".localized, systemImage: "xmark.circle", isDestructive: true) {
                            onQuit()
                        }
                    }
                }
            }
        .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
            
    private var screenshotToast: some View {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("pause.screenshot.saved".localized)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 80)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showingScreenshotSaved = false
                        }
                    }
                }
            }
        }

// MARK: - 紧凑菜单按钮

struct CompactMenuButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Speed Picker Sheet

struct SpeedPickerSheet: View {
    @ObservedObject var viewModel: EmulationViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(EmulationSpeed.allCases) { speed in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(speed.displayName)
                                .font(.headline)
                            Text("\(Int(speed.multiplier * 100))% speed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if viewModel.emulationSpeed == speed {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.setSpeed(speed)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Emulation Speed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 皮肤选择器

struct SkinPickerSheet: View {
    @ObservedObject private var skinManager = ControllerSkinManager.shared
    @Environment(\.dismiss) var dismiss
    
    /// 选择皮肤后的回调（用于关闭暂停菜单）
    var onSkinSelected: (() -> Void)? = nil
    
    // MARK: - 皮肤名称国际化
    private func localizedName(for skin: ControllerSkin) -> String {
        switch skin.name {
        case "Default": return "skin.default".localized
        case "Minimal": return "skin.minimal".localized
        case "Retro": return "skin.retro".localized
        case "Neon": return "skin.neon".localized
        case "Classic Nintendo": return "skin.classicNintendo".localized
        case "PlayStation": return "skin.playStation".localized
        case "Xbox": return "skin.xbox".localized
        case "Transparent": return "skin.transparent".localized
        case "Dark Mode": return "skin.darkMode".localized
        default: return skin.name
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // 标准皮肤
                Section("skin.category.standard".localized) {
                    ForEach([ControllerSkin.default, .minimal, .retro]) { skin in
                        skinRow(for: skin)
                    }
                }
                
                // 主题皮肤
                Section("skin.category.themed".localized) {
                    ForEach([ControllerSkin.neon, .classicNintendo, .playStation, .xbox]) { skin in
                        skinRow(for: skin)
                    }
                }
                
                // 特殊皮肤
                Section("skin.category.special".localized) {
                    ForEach([ControllerSkin.transparent, .darkMode]) { skin in
                        skinRow(for: skin)
                    }
                }
            }
            .navigationTitle("settings.controls.skin".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func skinRow(for skin: ControllerSkin) -> some View {
        Button {
            skinManager.setCurrentSkin(skin)
            HapticManager.shared.selectionChanged()
            // 选择皮肤后自动关闭弹窗
            dismiss()
            // 通知外部关闭暂停菜单
            onSkinSelected?()
        } label: {
            HStack(spacing: 12) {
                // 皮肤预览色块
                RoundedRectangle(cornerRadius: 8)
                    .fill(skin.backgroundColor.color)
                    .frame(width: 50, height: 36)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                    }
                    .overlay {
                        Circle()
                            .fill(skin.buttonColor.color)
                            .frame(width: 16, height: 16)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizedName(for: skin))
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                if skinManager.currentSkin.id == skin.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct PauseMenuButton: View {
    let title: String
    let systemImage: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .frame(width: 24)
                Text(title)
                Spacer()
            }
            .padding()
            .frame(width: 220)
            .background(isDestructive ? Color.red.opacity(0.2) : Color.white.opacity(0.1))
            .foregroundStyle(isDestructive ? .red : .white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Save States Sheet

struct SaveStatesSheet: View {
    @ObservedObject var viewModel: EmulationViewModel
    @Binding var isLoading: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.getSaveStateSlots()) { slot in
                    SaveStateRow(
                        slot: slot,
                        onSave: {
                            Task {
                                isLoading = true
                                try? await viewModel.saveState(to: slot.index)
                                isLoading = false
                            }
                        },
                        onLoad: {
                            Task {
                                isLoading = true
                                try? await viewModel.loadState(from: slot.index)
                                isLoading = false
                                dismiss()
                            }
                        }
                    )
                }
            }
            .navigationTitle("Save States")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }
}

struct SaveStateRow: View {
    let slot: SaveStateSlot
    let onSave: () -> Void
    let onLoad: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Slot \(slot.index + 1)")
                    .font(.headline)
                
                if slot.exists, let date = slot.date {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Empty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Save") {
                    onSave()
                }
                .buttonStyle(.bordered)
                
                Button("Load") {
                    onLoad()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!slot.exists)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Game Input

enum GameInput: String, CaseIterable {
    case up, down, left, right
    case a, b, x, y
    case start, select
    case l, r
    case l2, r2
    case l3, r3
    
    var displayName: String {
        switch self {
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .a: return "A"
        case .b: return "B"
        case .x: return "X"
        case .y: return "Y"
        case .start: return "Start"
        case .select: return "Select"
        case .l: return "L1"
        case .r: return "R1"
        case .l2: return "L2"
        case .r2: return "R2"
        case .l3: return "L3"
        case .r3: return "R3"
        }
    }
    
    var libretroValue: Int {
        switch self {
        case .up: return 4
        case .down: return 5
        case .left: return 6
        case .right: return 7
        case .a: return 8
        case .b: return 0
        case .x: return 9
        case .y: return 1
        case .start: return 3
        case .select: return 2
        case .l: return 10
        case .r: return 11
        case .l2: return 12
        case .r2: return 13
        case .l3: return 14
        case .r3: return 15
        }
    }
}

// Note: GameSystem.hasXYButtons and hasShoulderButtons are defined in SettingsView.swift

// MARK: - 掌机外壳形状

struct ConsoleBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 40
        
        // 简单的圆角矩形，模拟掌机外壳
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        
        return path
    }
}

// MARK: - 掌机风格控制器区域视图（参考 Delta 设计）

struct ConsoleControllerAreaView: View {
    let system: GameSystem
    let skin: ControllerSkin
    let areaWidth: CGFloat
    let areaHeight: CGFloat
    let safeAreaBottom: CGFloat
    let onInput: (GameInput, Bool) -> Void
    let onFastForward: (Bool) -> Void
    let onMenuTapped: () -> Void
    
    @State private var hapticEngine: CHHapticEngine?
    @AppStorage("controllerHaptics") private var hapticsEnabled = true
    
    // 计算按钮尺寸 - 紧凑布局
    private var dpadSize: CGFloat {
        // D-Pad 占控制器高度的 50-55%
        let size = areaHeight * 0.52
        return min(max(size, 90), 130)
    }
    
    private var actionButtonSize: CGFloat {
        dpadSize
    }
    
    private var shoulderButtonWidth: CGFloat {
        areaWidth * 0.22
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // 肩键区域
            if system.hasShoulderButtons {
                HStack {
                    ConsoleShoulderButtonLarge(
                        label: "L",
                        skin: skin,
                        width: shoulderButtonWidth,
                        onPressed: { onInput(.l, $0) },
                        hapticEngine: hapticsEnabled ? hapticEngine : nil
                    )
                    
                    Spacer()
                    
                    ConsoleShoulderButtonLarge(
                        label: "R",
                        skin: skin,
                        width: shoulderButtonWidth,
                        onPressed: { onInput(.r, $0) },
                        hapticEngine: hapticsEnabled ? hapticEngine : nil
                    )
                }
                .padding(.horizontal, 16)
            }
            
            // 主控制区域 - D-Pad 和动作按钮（占据主要空间）
            HStack(alignment: .center, spacing: 0) {
                // 左侧 - D-Pad
                ConsoleDPad(
                    skin: skin,
                    size: dpadSize,
                    onInput: onInput,
                    hapticEngine: hapticsEnabled ? hapticEngine : nil
                )
                .frame(maxWidth: .infinity)
                
                // 右侧 - 动作按钮
                ConsoleActionButtons(
                    system: system,
                    skin: skin,
                    size: actionButtonSize,
                    onInput: onInput,
                    hapticEngine: hapticsEnabled ? hapticEngine : nil
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 4)
            
            // 底部功能按钮区域
            HStack {
                // MENU 按钮（左侧）
                ConsoleMenuButton(
                    skin: skin,
                    onTapped: onMenuTapped,
                    hapticEngine: hapticsEnabled ? hapticEngine : nil
                )
                .padding(.leading, 12)
                
                Spacer()
                
                // 中间：SELECT / 快进 / START
                HStack(spacing: 8) {
                    ConsoleSystemButtonPill(
                        label: "SELECT",
                        skin: skin,
                        onPressed: { onInput(.select, $0) },
                        hapticEngine: hapticsEnabled ? hapticEngine : nil
                    )
                    
                    ConsoleFastForwardButton(
                        skin: skin,
                        onFastForward: onFastForward,
                        hapticEngine: hapticsEnabled ? hapticEngine : nil
                    )
                    
                    ConsoleSystemButtonPill(
                        label: "START",
                        skin: skin,
                        onPressed: { onInput(.start, $0) },
                        hapticEngine: hapticsEnabled ? hapticEngine : nil
                    )
                }
                
                Spacer()
                
                // 右侧占位
                Color.clear.frame(width: 40, height: 32)
                    .padding(.trailing, 12)
            }
        }
        .onAppear {
            setupHaptics()
        }
    }
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine failed: \(error)")
        }
    }
}

// MARK: - 大号肩键（参考 Delta）

struct ConsoleShoulderButtonLarge: View {
    let label: String
    let skin: ControllerSkin
    let width: CGFloat
    let onPressed: (Bool) -> Void
    let hapticEngine: CHHapticEngine?
    
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            // 阴影
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
                .frame(width: width, height: 36)
                .offset(y: isPressed ? 1 : 2)
            
            // 主体
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            isPressed ? skin.buttonPressedColor.color : skin.buttonColor.color,
                            isPressed ? skin.buttonPressedColor.color.opacity(0.85) : skin.buttonColor.color.opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width, height: 36)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(isPressed ? 0.05 : 0.15), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
                .overlay {
                    Text(label)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
                .offset(y: isPressed ? 1 : 0)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        onPressed(true)
                        triggerHaptic()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    onPressed(false)
                }
        )
    }
    
    private func triggerHaptic() {
        guard let engine = hapticEngine else { return }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {}
    }
}

// MARK: - 菜单按钮（圆形带标签）

struct ConsoleMenuButton: View {
    let skin: ControllerSkin
    let onTapped: () -> Void
    let hapticEngine: CHHapticEngine?
    
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // 阴影
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .offset(y: isPressed ? 1 : 2)
                
                // 主体
                Circle()
                    .fill(
                        isPressed ?
                        skin.buttonPressedColor.color.opacity(0.8) :
                        skin.buttonColor.color.opacity(0.7)
                    )
                    .frame(width: 40, height: 40)
                    .overlay {
                        Circle()
                            .strokeBorder(skin.buttonColor.color.opacity(0.3), lineWidth: 1)
                    }
                    .offset(y: isPressed ? 1 : 0)
            }
            
            Text("MENU")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(skin.buttonColor.color.opacity(0.8))
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        triggerHaptic()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    onTapped()
                }
        )
    }
    
    private func triggerHaptic() {
        guard let engine = hapticEngine else { return }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {}
    }
}

// MARK: - 药丸形系统按钮

struct ConsoleSystemButtonPill: View {
    let label: String
    let skin: ControllerSkin
    let onPressed: (Bool) -> Void
    let hapticEngine: CHHapticEngine?
    
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            // 阴影
            Capsule()
                .fill(Color.black.opacity(0.25))
                .frame(width: 65, height: 26)
                .offset(y: isPressed ? 0 : 1)
            
            // 主体
            Capsule()
                .fill(
                    isPressed ?
                    skin.buttonPressedColor.color.opacity(0.7) :
                    skin.buttonColor.color.opacity(0.5)
                )
                .frame(width: 65, height: 26)
                .overlay {
                    Capsule()
                        .strokeBorder(skin.buttonColor.color.opacity(0.2), lineWidth: 1)
                }
                .overlay {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        onPressed(true)
                        triggerHaptic()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    onPressed(false)
                }
        )
    }
    
    private func triggerHaptic() {
        guard let engine = hapticEngine else { return }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {}
    }
}

// MARK: - 掌机风格 D-Pad（支持八方向输入）

struct ConsoleDPad: View {
    let skin: ControllerSkin
    let size: CGFloat
    let onInput: (GameInput, Bool) -> Void
    let hapticEngine: CHHapticEngine?
    
    // 当前按下的方向集合（支持多个方向同时按下，实现斜向输入）
    @State private var pressedDirections: Set<GameInput> = []
    
    private var buttonColor: Color { skin.buttonColor.color }
    private var pressedColor: Color { skin.buttonPressedColor.color }
    
    var body: some View {
        ZStack {
            // D-Pad 底座阴影
            DPadCrossShape()
                .fill(Color.black.opacity(0.4))
                .frame(width: size, height: size)
                .offset(y: 4)
            
            // D-Pad 底座
            DPadCrossShape()
                .fill(
                    LinearGradient(
                        colors: [
                            buttonColor.opacity(0.7),
                            buttonColor.opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)
            
            // D-Pad 主体
            DPadCrossShape()
                .fill(
                    LinearGradient(
                        colors: [
                            buttonColor,
                            buttonColor.opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.95, height: size * 0.95)
                .overlay {
                    // 高光效果
                    DPadCrossShape()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .frame(width: size * 0.9, height: size * 0.9)
                }
            
            // 方向高亮指示
            ForEach([GameInput.up, .down, .left, .right], id: \.self) { direction in
                if pressedDirections.contains(direction) {
                    directionHighlight(for: direction)
                }
            }
            
            // 方向箭头图标
            ForEach([GameInput.up, .down, .left, .right], id: \.self) { direction in
                directionIcon(for: direction)
            }
            
            // 中心圆点
            Circle()
                .fill(buttonColor.opacity(0.3))
                .frame(width: size * 0.15, height: size * 0.15)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDrag(at: value.location)
                }
                .onEnded { _ in
                    releaseAllDirections()
                }
        )
    }
    
    // 处理拖拽手势，计算八方向输入
    private func handleDrag(at location: CGPoint) {
        let center = CGPoint(x: size / 2, y: size / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        
        // 计算距离中心的距离
        let distance = sqrt(dx * dx + dy * dy)
        
        // 如果在中心死区内，释放所有方向
        let deadZone = size * 0.12
        guard distance > deadZone else {
            releaseAllDirections()
            return
        }
        
        // 计算新的方向组合（支持斜向 - 8方向）
        var newDirections: Set<GameInput> = []
        
        // 使用阈值来判断是否激活某个方向
        let threshold = size * 0.1
        
        // 水平方向
        if dx > threshold {
            newDirections.insert(.right)
        } else if dx < -threshold {
            newDirections.insert(.left)
        }
        
        // 垂直方向
        if dy > threshold {
            newDirections.insert(.down)
        } else if dy < -threshold {
            newDirections.insert(.up)
        }
        
        // 更新方向状态
        updateDirections(newDirections)
    }
    
    // 更新方向状态，处理按下和释放事件
    private func updateDirections(_ newDirections: Set<GameInput>) {
        // 找出需要释放的方向
        let toRelease = pressedDirections.subtracting(newDirections)
        for dir in toRelease {
            onInput(dir, false)
        }
        
        // 找出需要按下的方向
        let toPress = newDirections.subtracting(pressedDirections)
        for dir in toPress {
            onInput(dir, true)
            triggerHaptic()
        }
        
        pressedDirections = newDirections
    }
    
    // 释放所有方向
    private func releaseAllDirections() {
        for dir in pressedDirections {
            onInput(dir, false)
        }
        pressedDirections.removeAll()
    }
    
    // 方向高亮效果
    @ViewBuilder
    private func directionHighlight(for direction: GameInput) -> some View {
        let offset: CGFloat = size * 0.28
        Circle()
            .fill(pressedColor.opacity(0.4))
            .frame(width: size * 0.25, height: size * 0.25)
            .offset(
                x: direction == .right ? offset : (direction == .left ? -offset : 0),
                y: direction == .down ? offset : (direction == .up ? -offset : 0)
            )
    }
    
    // 方向图标
    @ViewBuilder
    private func directionIcon(for direction: GameInput) -> some View {
        let offset: CGFloat = size * 0.28
        let isPressed = pressedDirections.contains(direction)
        
        Image(systemName: "arrowtriangle.\(directionName(direction)).fill")
            .font(.system(size: size * 0.12, weight: .bold))
            .foregroundStyle(isPressed ? pressedColor : buttonColor.opacity(0.6))
            .offset(
                x: direction == .right ? offset : (direction == .left ? -offset : 0),
                y: direction == .down ? offset : (direction == .up ? -offset : 0)
            )
    }
    
    private func directionName(_ direction: GameInput) -> String {
        switch direction {
        case .up: return "up"
        case .down: return "down"
        case .left: return "left"
        case .right: return "right"
        default: return "up"
        }
    }
    
    private func triggerHaptic() {
        guard let engine = hapticEngine else { return }
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // 静默处理
        }
    }
}

// MARK: - 掌机风格动作按钮

struct ConsoleActionButtons: View {
    let system: GameSystem
    let skin: ControllerSkin
    let size: CGFloat
    let onInput: (GameInput, Bool) -> Void
    let hapticEngine: CHHapticEngine?
    
    // 按钮尺寸：有XY按钮时稍小一点，避免重叠
    private var buttonSize: CGFloat {
        system.hasXYButtons ? size * 0.30 : size * 0.38
    }
    
    // 按钮偏移量：有XY按钮时增大间距，避免挤在一起
    private var buttonOffset: CGFloat {
        system.hasXYButtons ? size * 0.35 : size * 0.26
    }
    
    private var spacing: CGFloat {
        system.hasXYButtons ? size * 0.08 : size * 0.15
    }
    
    var body: some View {
        ZStack {
            if system.hasXYButtons {
                // SNES/N64 风格 - 菱形布局
                fourButtonLayout
            } else {
                // NES/GB 风格 - 斜对角布局
                twoButtonLayout
            }
        }
        .frame(width: size, height: size)
    }
    
    // 两键布局 (A/B)
    private var twoButtonLayout: some View {
        HStack(spacing: spacing) {
            // B 按钮 (左下)
            ConsoleActionButton(
                label: "B",
                color: skin.buttonColor.color,
                pressedColor: skin.buttonPressedColor.color,
                size: buttonSize,
                onPressed: { onInput(.b, $0) },
                hapticEngine: hapticEngine
            )
            .offset(y: buttonSize * 0.3)
            
            // A 按钮 (右上)
            ConsoleActionButton(
                label: "A",
                color: skin.buttonColor.color,
                pressedColor: skin.buttonPressedColor.color,
                size: buttonSize,
                onPressed: { onInput(.a, $0) },
                hapticEngine: hapticEngine
            )
            .offset(y: -buttonSize * 0.3)
        }
    }
    
    // 四键布局 (X/Y/A/B) - 菱形布局，增大间距避免挤在一起
    private var fourButtonLayout: some View {
        ZStack {
            // Y 按钮 (左)
            ConsoleActionButton(
                label: "Y",
                color: getButtonColor(for: .y),
                pressedColor: skin.buttonPressedColor.color,
                size: buttonSize,
                onPressed: { onInput(.y, $0) },
                hapticEngine: hapticEngine
            )
            .offset(x: -buttonOffset, y: 0)
            
            // X 按钮 (上)
            ConsoleActionButton(
                label: "X",
                color: getButtonColor(for: .x),
                pressedColor: skin.buttonPressedColor.color,
                size: buttonSize,
                onPressed: { onInput(.x, $0) },
                hapticEngine: hapticEngine
            )
            .offset(x: 0, y: -buttonOffset)
            
            // A 按钮 (右)
            ConsoleActionButton(
                label: "A",
                color: getButtonColor(for: .a),
                pressedColor: skin.buttonPressedColor.color,
                size: buttonSize,
                onPressed: { onInput(.a, $0) },
                hapticEngine: hapticEngine
            )
            .offset(x: buttonOffset, y: 0)
            
            // B 按钮 (下)
            ConsoleActionButton(
                label: "B",
                color: getButtonColor(for: .b),
                pressedColor: skin.buttonPressedColor.color,
                size: buttonSize,
                onPressed: { onInput(.b, $0) },
                hapticEngine: hapticEngine
            )
            .offset(x: 0, y: buttonOffset)
        }
    }
    
    // 根据皮肤风格获取按钮颜色
    private func getButtonColor(for button: GameInput) -> Color {
        // 如果是 SNES 风格皮肤，使用经典颜色
        if skin.name == "Classic Nintendo" || skin.name == "经典任天堂" {
            switch button {
            case .a: return Color.red
            case .b: return Color.yellow
            case .x: return Color.blue
            case .y: return Color.green
            default: return skin.buttonColor.color
            }
        }
        return skin.buttonColor.color
    }
}

// MARK: - 单个动作按钮

struct ConsoleActionButton: View {
    let label: String
    let color: Color
    let pressedColor: Color
    let size: CGFloat
    let onPressed: (Bool) -> Void
    let hapticEngine: CHHapticEngine?
    
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            // 按钮阴影
            Circle()
                .fill(Color.black.opacity(0.4))
                .frame(width: size, height: size)
                .offset(y: isPressed ? 1 : 3)
            
            // 按钮主体
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            isPressed ? pressedColor : color,
                            isPressed ? pressedColor.opacity(0.8) : color.opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)
                .overlay {
                    // 高光
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(isPressed ? 0.1 : 0.25), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .frame(width: size * 0.9, height: size * 0.9)
                }
                .overlay {
                    // 按钮标签
                    Text(label)
                        .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
                .offset(y: isPressed ? 1 : 0)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        onPressed(true)
                        triggerHaptic()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    onPressed(false)
                }
        )
    }
    
    private func triggerHaptic() {
        guard let engine = hapticEngine else { return }
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // 静默处理
        }
    }
}

// MARK: - 掌机风格肩键

struct ConsoleShoulderButton: View {
    let label: String
    let skin: ControllerSkin
    let onPressed: (Bool) -> Void
    
    @State private var isPressed = false
    
    private var buttonColor: Color { skin.buttonColor.color }
    
    var body: some View {
        ZStack {
            // 阴影
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 80, height: 32)
                .offset(y: isPressed ? 1 : 2)
            
            // 主体
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            isPressed ? skin.buttonPressedColor.color : buttonColor,
                            isPressed ? skin.buttonPressedColor.color.opacity(0.8) : buttonColor.opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 80, height: 32)
                .overlay {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(isPressed ? 0.05 : 0.15), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .frame(width: 76, height: 28)
                }
                .overlay {
                    Text(label)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
                .offset(y: isPressed ? 1 : 0)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        onPressed(true)
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    onPressed(false)
                }
        )
    }
}

// MARK: - 掌机风格系统按钮 (SELECT/START/MENU)

struct ConsoleSystemButton: View {
    let label: String
    let skin: ControllerSkin
    var isMenu: Bool = false
    let onPressed: (Bool) -> Void
    let hapticEngine: CHHapticEngine?
    
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            // 按钮形状 - 椭圆形
            Capsule()
                .fill(
                    isPressed ?
                    skin.buttonPressedColor.color.opacity(0.8) :
                    skin.buttonColor.color.opacity(0.6)
                )
                .frame(width: isMenu ? 50 : 60, height: 24)
                .overlay {
                    Capsule()
                        .strokeBorder(skin.buttonColor.color.opacity(0.3), lineWidth: 1)
                }
            
            // 标签或图标
            if isMenu {
                Circle()
                    .fill(skin.buttonColor.color.opacity(0.8))
                    .frame(width: 18, height: 18)
            } else {
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.8))
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        onPressed(true)
                        triggerHaptic()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    onPressed(false)
                }
        )
    }
    
    private func triggerHaptic() {
        guard let engine = hapticEngine else { return }
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // 静默处理
        }
    }
}

// MARK: - 快进按钮

struct ConsoleFastForwardButton: View {
    let skin: ControllerSkin
    let onFastForward: (Bool) -> Void
    let hapticEngine: CHHapticEngine?
    
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    isPressed ?
                    skin.buttonPressedColor.color.opacity(0.8) :
                    skin.buttonColor.color.opacity(0.6)
                )
                .frame(width: 36, height: 36)
                .overlay {
                    Circle()
                        .strokeBorder(skin.buttonColor.color.opacity(0.3), lineWidth: 1)
                }
            
            Image(systemName: "forward.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.8))
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        onFastForward(true)
                        triggerHaptic()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    onFastForward(false)
                }
        )
    }
    
    private func triggerHaptic() {
        guard let engine = hapticEngine else { return }
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // 静默处理
        }
    }
}

#Preview {
    EmulationView(game: Game(
        name: "Test Game",
        fileURL: URL(fileURLWithPath: "/test.nes"),
        system: .nes
    ))
    .environmentObject(AppState())
}
