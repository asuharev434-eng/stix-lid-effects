import Foundation

/// The whole effect in one fragment shader.
///
/// Each screen pixel maps back into the picture through the inverse
/// perspective, then takes one sample from a Gaussian pyramid at a level
/// chosen by the blur wanted there. The texture already holds the picture on
/// black, so the two blur together and the picture edge needs no special
/// handling.
enum DepthShaders {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    // All float4, so the layout cannot drift from the Swift side.
    struct Uniforms {
        float4 column0;          // screen-to-picture matrix, column 0 in xyz
        float4 column1;
        float4 column2;
        float4 screenAndOrigin;  // screen size, padded origin in picture points
        float4 paddedAndBlur;    // padded size, max radius in pixels, blur strength
        float4 shape;            // blur floor, max dim, pixel scale, max level
        float4 light;            // dim floor, dim strength, dim reach, unused
        float4 effect;           // style, progress, reserved, reserved
    };

    float fractureHash(float2 p) {
        return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
    }
    float2 fractureVertex(float2 index, float2 grid) {
        float2 jitter = float2(fractureHash(index), fractureHash(index + 31.7)) - 0.5;
        if (index.x == 0.0 || index.x == grid.x) jitter.x = 0.0;
        if (index.y == 0.0 || index.y == grid.y) jitter.y = 0.0;
        return (index + jitter * 0.5) / grid;
    }
    float3 fractureBarycentric(float2 p, float2 a, float2 b, float2 c) {
        float2 v0 = b - a, v1 = c - a, v2 = p - a;
        float det = v0.x * v1.y - v1.x * v0.y;
        float u = (v2.x * v1.y - v1.x * v2.y) / det;
        float v = (v0.x * v2.y - v2.x * v0.y) / det;
        return float3(1.0 - u - v, u, v);
    }

    vertex float4 depthVertex(uint vertexID [[vertex_id]]) {
        const float2 corners[3] = { float2(-1.0, -3.0), float2(-1.0, 1.0), float2(3.0, 1.0) };
        return float4(corners[vertexID], 0.0, 1.0);
    }

    fragment float4 depthFragment(float4 position [[position]],
                                   constant Uniforms &uniforms [[buffer(0)]],
                                   texture2d<float> picture [[texture(0)]]) {
        constexpr sampler linearSampler(filter::linear, mip_filter::linear, address::clamp_to_edge);

        float2 screenSize = uniforms.screenAndOrigin.xy;
        float2 paddedOrigin = uniforms.screenAndOrigin.zw;
        float2 paddedSize = uniforms.paddedAndBlur.xy;
        float maxRadius = uniforms.paddedAndBlur.z;
        float strength = uniforms.paddedAndBlur.w;
        float blurFloor = uniforms.shape.x;
        float maxDim = uniforms.shape.y;
        float pixelScale = uniforms.shape.z;
        float maxLevel = uniforms.shape.w;
        float dimFloor = uniforms.light.x;
        float dimStrength = uniforms.light.y;
        float dimReach = uniforms.light.z;

        int style = int(uniforms.effect.x);
        float p = clamp(uniforms.effect.y, 0.0, 1.0);
        float blackoutFade = uniforms.effect.z > 0.5 ? 1.0 - smoothstep(0.82, 1.0, p) : 1.0;
        if (style == 8 && p > 0.0001) {
            float2 uv = position.xy / (screenSize * pixelScale);
            float2 grid = float2(10.0, 7.0);
            float drop = smoothstep(0.26, 1.0, p);
            float gravity = drop * drop * 1.65;
            int2 guess = int2(floor((uv - float2(0.0, gravity)) * grid));
            float2 found = float2(-1.0);
            float crack = 0.0;
            float shardLight = 1.0;
            // Jittered shared vertices form contiguous, irregular triangular glass shards.
            for (int y = -1; y <= 1; ++y) {
                for (int x = -1; x <= 1; ++x) {
                    int2 cell = guess + int2(x, y);
                    if (any(cell < int2(0)) || any(cell >= int2(grid))) continue;
                    float2 ij = float2(cell);
                    float2 a = fractureVertex(ij, grid);
                    float2 b = fractureVertex(ij + float2(1, 0), grid);
                    float2 c = fractureVertex(ij + float2(1, 1), grid);
                    float2 d = fractureVertex(ij + float2(0, 1), grid);
                    for (int triangle = 0; triangle < 2; ++triangle) {
                        float2 v0 = a;
                        float2 v1 = triangle == 0 ? b : c;
                        float2 v2 = triangle == 0 ? c : d;
                        float seed = fractureHash(ij + float2(triangle * 17.0, 9.0));
                        float2 pivot = (v0 + v1 + v2) / 3.0;
                        float angle = (seed - 0.5) * drop * 2.4;
                        float cs = cos(angle), sn = sin(angle);
                        float2 displacement = float2((seed - 0.5) * 0.065 * drop, gravity);
                        float2 local = uv - pivot - displacement;
                        float2 source = pivot + float2(cs * local.x + sn * local.y, -sn * local.x + cs * local.y);
                        float3 bary = fractureBarycentric(source, v0, v1, v2);
                        if (all(bary >= float3(-0.00001))) {
                            found = source;
                            float edge = min(bary.x, min(bary.y, bary.z));
                            float propagation = smoothstep(0.0, 0.24, p) * 1.5;
                            float reached = 1.0 - smoothstep(propagation - 0.05, propagation, distance(source, float2(0.52, 0.38)));
                            crack = (1.0 - smoothstep(0.004, 0.022, edge)) * reached;
                            shardLight = 1.0 - drop * (0.15 + seed * 0.35);
                        }
                    }
                }
            }
            if (found.x < 0.0) return float4(0, 0, 0, 1);
            float2 point = float2(found.x * screenSize.x, (1.0 - found.y) * screenSize.y);
            float2 tex = (point - paddedOrigin) / paddedSize;
            tex.y = 1.0 - tex.y;
            float3 rgb = picture.sample(linearSampler, tex, level(0.0)).rgb * shardLight;
            // Dark split with a narrow cool glint, rather than a white screen wash.
            rgb = mix(rgb, float3(0.015, 0.02, 0.03), crack * 0.8);
            rgb += crack * float3(0.12, 0.17, 0.22) * (1.0 - drop * 0.5);
            rgb *= (1.0 - smoothstep(0.93, 1.0, p)) * blackoutFade;
            return float4(rgb, 1.0);
        }
        if (style != 0) {
            float2 uv = position.xy / (screenSize * pixelScale);
            float2 q = uv;
            float opacity = 1.0;
            float glow = 0.0;
            float radius = 0.0;
            float2 centered = uv - 0.5;
            if (style == 1) {
                // CRT: collapse vertically, then squeeze the glowing line.
                float sy = max(1.0 - smoothstep(0.0, 0.82, p), 0.0015);
                float sx = max(1.0 - smoothstep(0.78, 1.0, p), 0.001);
                q = centered / float2(sx, sy) + 0.5;
                glow = exp(-abs(centered.y) * 800.0) * p * (1.0 - p);
                opacity = 1.0 - smoothstep(0.95, 1.0, p);
            } else if (style == 2) {
                radius = 160.0 * pixelScale * p;
                opacity = 1.0 - 0.45 * p;
            } else if (style == 3) {
                q.x += sin(uv.y * 30.0 + p * 12.0) * sin(p * 3.14159) * 0.035;
                q.y += sin(uv.x * 22.0 - p * 10.0) * sin(p * 3.14159) * 0.018;
                radius = 20.0 * pixelScale * p;
                opacity = 1.0 - p * p;
            } else if (style == 4) {
                // Hinged paper sheet: narrow perspective and curved crease.
                float fold = max(1.0 - p, 0.002);
                q.y = 1.0 - (1.0 - uv.y) / fold;
                q.x = centered.x / max(1.0 - p * (1.0 - uv.y) * 0.65, 0.1) + 0.5;
                q.y += sin(uv.x * 3.14159) * p * 0.16;
                opacity = (1.0 - 0.45 * p) * (1.0 - smoothstep(0.92, 1.0, p));
            } else if (style == 5) {
                // Stable cells drift apart while the desktop dissolves.
                float2 cell = floor(uv * float2(160.0, 100.0));
                float noise = fract(sin(dot(cell, float2(127.1, 311.7))) * 43758.5453);
                float drift = p * p;
                q += float2((noise - 0.5) * 0.35, -noise * 0.5) * drift;
                float2 speck = fract(uv * float2(160.0, 100.0));
                float grain = smoothstep(0.06, 0.13, min(min(speck.x, 1.0-speck.x), min(speck.y, 1.0-speck.y)));
                opacity = mix(1.0, grain, p) * (1.0 - smoothstep(noise * 0.65, noise * 0.65 + 0.35, p));
            } else if (style == 6) {
                float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
                glow = exp(-edge * 100.0) * sin(p * 3.14159);
                opacity = 1.0 - smoothstep(0.25, 1.0, p);
            } else if (style == 7) {
                q = centered * (1.0 + 0.08 * p) + 0.5;
                radius = 80.0 * pixelScale * p * p;
                opacity = pow(1.0 - p, 1.8);
            }
            bool inside = all(q >= 0.0) && all(q <= 1.0);
            float2 point = float2(q.x * screenSize.x, (1.0 - q.y) * screenSize.y);
            float2 unit = (point - paddedOrigin) / paddedSize;
            float2 tex = float2(unit.x, 1.0 - unit.y);
            float mip = clamp(log2(max(radius, 1.0)), 0.0, maxLevel);
            float3 rgb = picture.sample(linearSampler, tex, level(mip)).rgb;
            if (!inside) rgb = float3(0.0);
            rgb *= opacity;
            if (style == 2) rgb = mix(rgb, float3(0.4, 0.46, 0.52), p * 0.12);
            rgb += glow * float3(0.45, 0.7, 1.0);
            return float4(rgb * blackoutFade, 1.0);
        }

        // Fragment coordinates are pixels with y down; the geometry is points
        // with y up.
        float2 screenPoint = float2(position.x / pixelScale,
                                    screenSize.y - position.y / pixelScale);

        float3x3 screenToPicture = float3x3(uniforms.column0.xyz,
                                            uniforms.column1.xyz,
                                            uniforms.column2.xyz);
        float3 mapped = screenToPicture * float3(screenPoint, 1.0);
        if (abs(mapped.z) < 1e-6) { return float4(0.0, 0.0, 0.0, 1.0); }
        float2 picturePoint = mapped.xy / mapped.z;

        float2 unit = (picturePoint - paddedOrigin) / paddedSize;
        if (unit.x < 0.0 || unit.x > 1.0 || unit.y < 0.0 || unit.y > 1.0) {
            return float4(0.0, 0.0, 0.0, 1.0);
        }
        float2 texCoord = float2(unit.x, 1.0 - unit.y);

        float height = clamp(picturePoint.y / screenSize.y, 0.0, 1.0);
        float blur = strength * (blurFloor + (1.0 - blurFloor) * height);
        // Naming this `level` would shadow Metal's level() selector.
        float mipLevel = clamp(log2(max(blur * maxRadius, 1.0)), 0.0, maxLevel);

        float4 colour = picture.sample(linearSampler, texCoord, level(mipLevel));
        // smoothstep rather than a clamped ratio, so the height where the
        // dimming reaches full strength leaves no visible edge.
        float spread = smoothstep(0.0, max(dimReach, 0.02), height);
        float fade = dimStrength * (dimFloor + (1.0 - dimFloor) * spread);
        // The sample is linear light. Raising the factor to 2.2 keeps the
        // dimming setting a fraction of the encoded brightness.
        colour.rgb *= pow(1.0 - maxDim * fade, 2.2);
        return float4(colour.rgb * blackoutFade, 1.0);
    }
    """
}
