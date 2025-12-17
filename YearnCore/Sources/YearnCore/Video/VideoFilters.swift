//
//  VideoFilters.swift
//  YearnCore
//
//  Video filter shaders for retro effects
//

import Foundation
import Metal
import simd

// MARK: - Video Filter Type

public enum VideoFilterType: String, CaseIterable, Identifiable {
    case nearest = "Pixel Perfect"
    case bilinear = "Smooth"
    case crt = "CRT"
    case lcd = "LCD"
    case scanlines = "Scanlines"
    case hq2x = "HQ2x"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .nearest:
            return "Sharp pixels with no filtering"
        case .bilinear:
            return "Smooth scaling with bilinear interpolation"
        case .crt:
            return "Classic CRT monitor effect with curvature and scanlines"
        case .lcd:
            return "LCD screen effect with visible subpixels"
        case .scanlines:
            return "Simple scanline overlay"
        case .hq2x:
            return "High quality 2x upscaling"
        }
    }
}

// MARK: - Video Filter Manager

public class VideoFilterManager {
    private let device: MTLDevice
    private var pipelineStates: [VideoFilterType: MTLRenderPipelineState] = [:]
    private var samplerStates: [VideoFilterType: MTLSamplerState] = [:]
    
    public init?(device: MTLDevice) {
        self.device = device
        setupFilters()
    }
    
    private func setupFilters() {
        // Create sampler states
        for filter in VideoFilterType.allCases {
            let samplerDescriptor = MTLSamplerDescriptor()
            
            switch filter {
            case .nearest, .crt, .lcd, .scanlines:
                samplerDescriptor.minFilter = .nearest
                samplerDescriptor.magFilter = .nearest
            case .bilinear, .hq2x:
                samplerDescriptor.minFilter = .linear
                samplerDescriptor.magFilter = .linear
            }
            
            samplerDescriptor.sAddressMode = .clampToEdge
            samplerDescriptor.tAddressMode = .clampToEdge
            
            if let sampler = device.makeSamplerState(descriptor: samplerDescriptor) {
                samplerStates[filter] = sampler
            }
        }
    }
    
    public func getSamplerState(for filter: VideoFilterType) -> MTLSamplerState? {
        return samplerStates[filter]
    }
    
    public func getPipelineState(for filter: VideoFilterType) -> MTLRenderPipelineState? {
        return pipelineStates[filter]
    }
}

// MARK: - Filter Parameters

public struct CRTFilterParams {
    public var curvature: Float = 0.1
    public var scanlineIntensity: Float = 0.3
    public var scanlineCount: Float = 240
    public var brightness: Float = 1.1
    public var contrast: Float = 1.0
    public var vignetteIntensity: Float = 0.2
    public var bloomIntensity: Float = 0.1
    
    public init() {}
}

public struct LCDFilterParams {
    public var subpixelSize: Float = 3.0
    public var brightness: Float = 1.0
    public var gridIntensity: Float = 0.15
    
    public init() {}
}

public struct ScanlineFilterParams {
    public var intensity: Float = 0.25
    public var count: Float = 240
    public var thickness: Float = 0.5
    
    public init() {}
}

// MARK: - Shader Source

public let videoFilterShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Simple passthrough vertex shader
vertex VertexOut videoFilterVertex(
    uint vertexID [[vertex_id]],
    constant float2* positions [[buffer(0)]],
    constant float2* texCoords [[buffer(1)]]
) {
    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];
    return out;
}

// Nearest neighbor (pixel perfect)
fragment float4 nearestFragment(
    VertexOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    sampler texSampler [[sampler(0)]]
) {
    return texture.sample(texSampler, in.texCoord);
}

// Bilinear filtering
fragment float4 bilinearFragment(
    VertexOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    sampler texSampler [[sampler(0)]]
) {
    return texture.sample(texSampler, in.texCoord);
}

// CRT effect parameters
struct CRTParams {
    float curvature;
    float scanlineIntensity;
    float scanlineCount;
    float brightness;
    float contrast;
    float vignetteIntensity;
    float bloomIntensity;
};

// CRT shader
fragment float4 crtFragment(
    VertexOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    sampler texSampler [[sampler(0)]],
    constant CRTParams& params [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    
    // Apply barrel distortion for CRT curvature
    float2 centered = uv - 0.5;
    float dist = dot(centered, centered);
    float2 curved = uv + centered * dist * params.curvature;
    
    // Check bounds
    if (curved.x < 0.0 || curved.x > 1.0 || curved.y < 0.0 || curved.y > 1.0) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }
    
    // Sample texture
    float4 color = texture.sample(texSampler, curved);
    
    // Apply scanlines
    float scanline = sin(curved.y * params.scanlineCount * 3.14159) * 0.5 + 0.5;
    scanline = mix(1.0, scanline, params.scanlineIntensity);
    color.rgb *= scanline;
    
    // Apply vignette
    float vignette = 1.0 - dist * params.vignetteIntensity * 4.0;
    color.rgb *= vignette;
    
    // Apply brightness and contrast
    color.rgb = (color.rgb - 0.5) * params.contrast + 0.5;
    color.rgb *= params.brightness;
    
    return color;
}

// LCD effect parameters
struct LCDParams {
    float subpixelSize;
    float brightness;
    float gridIntensity;
};

// LCD shader
fragment float4 lcdFragment(
    VertexOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    sampler texSampler [[sampler(0)]],
    constant LCDParams& params [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    float4 color = texture.sample(texSampler, uv);
    
    // Get pixel position
    float2 texSize = float2(texture.get_width(), texture.get_height());
    float2 pixelPos = uv * texSize * params.subpixelSize;
    
    // Create subpixel pattern
    float subpixel = fmod(pixelPos.x, 3.0);
    float3 mask = float3(
        subpixel < 1.0 ? 1.0 : 0.3,
        subpixel >= 1.0 && subpixel < 2.0 ? 1.0 : 0.3,
        subpixel >= 2.0 ? 1.0 : 0.3
    );
    
    // Apply grid
    float gridX = abs(sin(pixelPos.x * 3.14159)) * params.gridIntensity;
    float gridY = abs(sin(pixelPos.y * 3.14159)) * params.gridIntensity;
    float grid = 1.0 - max(gridX, gridY);
    
    color.rgb *= mask * grid * params.brightness;
    
    return color;
}

// Scanline parameters
struct ScanlineParams {
    float intensity;
    float count;
    float thickness;
};

// Simple scanlines shader
fragment float4 scanlinesFragment(
    VertexOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    sampler texSampler [[sampler(0)]],
    constant ScanlineParams& params [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    float4 color = texture.sample(texSampler, uv);
    
    // Calculate scanline
    float scanline = sin(uv.y * params.count * 3.14159 * 2.0);
    scanline = smoothstep(-params.thickness, params.thickness, scanline);
    scanline = mix(1.0, scanline, params.intensity);
    
    color.rgb *= scanline;
    
    return color;
}
"""

// MARK: - Filter Preset

public struct VideoFilterPreset: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var filterType: String
    public var parameters: [String: Float]
    
    public init(id: UUID = UUID(), name: String, filterType: VideoFilterType, parameters: [String: Float] = [:]) {
        self.id = id
        self.name = name
        self.filterType = filterType.rawValue
        self.parameters = parameters
    }
    
    public static let defaults: [VideoFilterPreset] = [
        VideoFilterPreset(name: "Sharp", filterType: .nearest),
        VideoFilterPreset(name: "Smooth", filterType: .bilinear),
        VideoFilterPreset(name: "CRT Classic", filterType: .crt, parameters: [
            "curvature": 0.1,
            "scanlineIntensity": 0.3,
            "brightness": 1.1
        ]),
        VideoFilterPreset(name: "CRT Flat", filterType: .crt, parameters: [
            "curvature": 0.0,
            "scanlineIntensity": 0.2,
            "brightness": 1.0
        ]),
        VideoFilterPreset(name: "LCD", filterType: .lcd),
        VideoFilterPreset(name: "Light Scanlines", filterType: .scanlines, parameters: [
            "intensity": 0.15
        ]),
        VideoFilterPreset(name: "Heavy Scanlines", filterType: .scanlines, parameters: [
            "intensity": 0.4
        ])
    ]
}

