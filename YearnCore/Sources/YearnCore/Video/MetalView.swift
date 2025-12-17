//
//  MetalView.swift
//  YearnCore
//
//  SwiftUI wrapper for Metal rendering view
//

import SwiftUI
import MetalKit

#if canImport(UIKit)
import UIKit

/// SwiftUI wrapper for MTKView (iOS)
public struct MetalView: UIViewRepresentable {
    
    @ObservedObject var renderer: VideoRenderer
    
    public init(renderer: VideoRenderer) {
        self.renderer = renderer
    }
    
    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = true
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 60
        
        renderer.metalView = mtkView
        
        return mtkView
    }
    
    public func updateUIView(_ uiView: MTKView, context: Context) {
        // Updates handled by renderer
    }
}

#elseif canImport(AppKit)
import AppKit

/// SwiftUI wrapper for MTKView (macOS)
public struct MetalView: NSViewRepresentable {
    
    @ObservedObject var renderer: VideoRenderer
    
    public init(renderer: VideoRenderer) {
        self.renderer = renderer
    }
    
    public func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = true
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        
        renderer.metalView = mtkView
        
        return mtkView
    }
    
    public func updateNSView(_ nsView: MTKView, context: Context) {
        // Updates handled by renderer
    }
}

#endif

// MARK: - Enhanced Video Renderer

extension VideoRenderer {
    
    /// Filter type for rendering
    public enum FilterType: String, CaseIterable, Identifiable {
        case nearest = "Pixel Perfect"
        case bilinear = "Smooth"
        case sharpBilinear = "Sharp"
        case crt = "CRT"
        case lcd = "LCD"
        
        public var id: String { rawValue }
    }
    
    /// Set the rendering filter
    public func setFilter(_ filter: FilterType) {
        // This would select the appropriate fragment shader
        // Implementation depends on pipeline state management
    }
}
