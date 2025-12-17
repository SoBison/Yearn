//
//  Shaders.metal
//  YearnCore
//
//  Metal shaders for video rendering
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex Structures

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// MARK: - Uniforms

struct Uniforms {
    float4x4 projectionMatrix;
    float2 outputSize;
    float2 textureSize;
    float time;
};

// MARK: - Vertex Shader

vertex VertexOut vertexShader(
    VertexIn in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    VertexOut out;
    out.position = uniforms.projectionMatrix * float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

// MARK: - Fragment Shaders

// Basic nearest-neighbor sampling (pixel-perfect)
fragment float4 fragmentShaderNearest(
    VertexOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    sampler textureSampler [[sampler(0)]]
) {
    return texture.sample(textureSampler, in.texCoord);
}

// Bilinear filtering (smooth)
fragment float4 fragmentShaderBilinear(
    VertexOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    constexpr sampler bilinearSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );
    return texture.sample(bilinearSampler, in.texCoord);
}

// CRT scanline effect
fragment float4 fragmentShaderCRT(
    VertexOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    constexpr sampler texSampler(
        mag_filter::nearest,
        min_filter::nearest,
        address::clamp_to_edge
    );
    
    float4 color = texture.sample(texSampler, in.texCoord);
    
    // Scanline effect
    float scanline = sin(in.texCoord.y * uniforms.textureSize.y * 3.14159) * 0.5 + 0.5;
    scanline = pow(scanline, 0.5);
    
    // Apply scanline darkening
    color.rgb *= 0.7 + 0.3 * scanline;
    
    // Slight vignette
    float2 center = in.texCoord - 0.5;
    float vignette = 1.0 - dot(center, center) * 0.5;
    color.rgb *= vignette;
    
    return color;
}

// LCD grid effect (for handheld systems)
fragment float4 fragmentShaderLCD(
    VertexOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    constexpr sampler texSampler(
        mag_filter::nearest,
        min_filter::nearest,
        address::clamp_to_edge
    );
    
    float4 color = texture.sample(texSampler, in.texCoord);
    
    // LCD grid pattern
    float2 pixelPos = in.texCoord * uniforms.outputSize;
    float gridX = fract(pixelPos.x);
    float gridY = fract(pixelPos.y);
    
    // Create subpixel pattern
    float3 subpixel = float3(
        smoothstep(0.0, 0.33, gridX) - smoothstep(0.33, 0.66, gridX),
        smoothstep(0.33, 0.66, gridX) - smoothstep(0.66, 1.0, gridX),
        smoothstep(0.66, 1.0, gridX)
    );
    
    // Apply subtle grid
    float grid = smoothstep(0.0, 0.1, gridY) * smoothstep(1.0, 0.9, gridY);
    color.rgb *= 0.8 + 0.2 * grid;
    
    return color;
}

// Sharp bilinear (good compromise between sharp and smooth)
fragment float4 fragmentShaderSharpBilinear(
    VertexOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    float2 texSize = uniforms.textureSize;
    float2 texelSize = 1.0 / texSize;
    
    float2 texCoord = in.texCoord * texSize;
    float2 texelCenter = floor(texCoord) + 0.5;
    float2 f = texCoord - texelCenter;
    
    // Sharpen the interpolation
    float2 sharpF = f * f * (3.0 - 2.0 * f);
    
    float2 finalCoord = (texelCenter + sharpF) * texelSize;
    
    constexpr sampler bilinearSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );
    
    return texture.sample(bilinearSampler, finalCoord);
}

