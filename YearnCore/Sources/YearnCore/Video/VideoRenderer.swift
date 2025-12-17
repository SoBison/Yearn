//
//  VideoRenderer.swift
//  YearnCore
//
//  Metal-based video rendering
//

import Foundation
import Metal
import MetalKit
import simd

/// Metal-based video renderer for emulator output
public final class VideoRenderer: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var texture: MTLTexture?
    private var sampler: MTLSamplerState?
    
    private var videoFormat: VideoFormat?
    private var videoBuffer: VideoBuffer?
    
    public weak var metalView: MTKView? {
        didSet {
            setupMetalView()
        }
    }
    
    // MARK: - Public Properties
    
    /// Aspect ratio mode
    public var aspectRatioMode: AspectRatioMode = .fit
    
    /// Enable integer scaling
    public var integerScaling: Bool = false
    
    /// Current frame texture (for screenshots)
    public var currentTexture: MTLTexture? {
        return texture
    }
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        setupMetal()
    }
    
    // MARK: - Configuration
    
    /// Configure the renderer with the specified video format
    public func configure(format: VideoFormat) {
        self.videoFormat = format
        self.videoBuffer = VideoBuffer(width: format.width, height: format.height, pixelFormat: format.pixelFormat)
        
        createTexture()
    }
    
    // MARK: - Frame Updates
    
    /// Update the frame buffer with new pixel data
    public func updateFrame(_ pixels: UnsafeRawPointer, bytesPerRow: Int) {
        guard let texture = texture,
              let format = videoFormat else {
            return
        }
        
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: format.width, height: format.height, depth: 1)
        )
        
        texture.replace(region: region, mipmapLevel: 0, withBytes: pixels, bytesPerRow: bytesPerRow)
    }
    
    /// Update frame from video buffer
    public func updateFrame(from buffer: VideoBuffer) {
        buffer.withUnsafeBytes { pointer in
            updateFrame(pointer, bytesPerRow: buffer.bytesPerRow)
        }
    }
    
    /// Get the video buffer for direct writing
    public func getVideoBuffer() -> VideoBuffer? {
        return videoBuffer
    }
    
    // MARK: - Private Methods
    
    private func setupMetal() {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()
        
        createPipelineState()
        createSampler()
    }
    
    private func setupMetalView() {
        guard let view = metalView,
              let device = device else {
            return
        }
        
        view.device = device
        view.delegate = self
        view.framebufferOnly = true
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    }
    
    private func createTexture() {
        guard let device = device,
              let format = videoFormat else {
            return
        }
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: format.metalPixelFormat,
            width: format.width,
            height: format.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        
        texture = device.makeTexture(descriptor: descriptor)
    }
    
    private func createPipelineState() {
        guard let device = device else { return }
        
        let library = device.makeDefaultLibrary()
        
        // Use built-in shaders or create simple vertex/fragment shaders
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // For now, we'll use a simple passthrough
        // In production, you'd load proper shaders
        
        do {
            // pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Failed to create pipeline state: \(error)")
        }
    }
    
    private func createSampler() {
        guard let device = device else { return }
        
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .nearest
        descriptor.magFilter = .nearest
        descriptor.sAddressMode = .clampToEdge
        descriptor.tAddressMode = .clampToEdge
        
        sampler = device.makeSamplerState(descriptor: descriptor)
    }
}

// MARK: - MTKViewDelegate

extension VideoRenderer: MTKViewDelegate {
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle size change
    }
    
    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let texture = texture,
              let commandBuffer = commandQueue?.makeCommandBuffer() else {
            return
        }
        
        // Simple blit for now
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        
        // Calculate destination rect based on aspect ratio
        let sourceSize = MTLSize(width: texture.width, height: texture.height, depth: 1)
        let destSize = MTLSize(width: drawable.texture.width, height: drawable.texture.height, depth: 1)
        
        // For now, just copy the texture
        // In production, you'd use a proper render pass with shaders
        
        blitEncoder?.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - Supporting Types

public enum AspectRatioMode {
    case fit      // Maintain aspect ratio, fit within bounds
    case fill     // Maintain aspect ratio, fill bounds (may crop)
    case stretch  // Stretch to fill bounds
}

