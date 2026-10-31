import Foundation

/// Shared Metal shaders: full-screen effects and a depth-tested glass mesh.
/// Source images sit on a black margin with a Gaussian pyramid for blur.
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
        float4 effect;           // style, progress, manual blackout, unused
    };

    struct GlassVertex {
        float2 source;
        float2 pivot;
        float4 motion;
        float4 axis;
        float4 edge;
    };
    struct GlassVarying {
        float4 position [[position]];
        float2 source;
        float edge;
        float3 normal;
        float seed;
        float time;
    };
    float3 glassRotate(float3 v, float3 axis, float angle) {
        float s = sin(angle), c = cos(angle);
        return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
    }
    vertex GlassVarying glassVertex(uint id [[vertex_id]],
                                    constant GlassVertex *vertices [[buffer(0)]],
                                    constant Uniforms &u [[buffer(1)]]) {
        GlassVertex v = vertices[id];
        float aspect = u.screenAndOrigin.x / u.screenAndOrigin.y;
        float p = clamp(u.effect.y, 0.0, 1.0);
        float t = max(p - v.motion.x, 0.0) * 3.2;
        float3 local = float3((v.source - v.pivot) * float2(aspect, 1.0), 0.0);
        float3 rotated = glassRotate(local, v.axis.xyz, v.motion.w * t);
        float3 world = float3(v.pivot * float2(aspect, 1.0), 0.0) + rotated;
        // Ballistic motion, with separate release, lateral impulse and angular momentum per shard.
        world += float3(v.motion.y * t, v.motion.z * t + 1.18 * t * t,
                        (0.08 + v.axis.w * 0.18) * t + 0.04 * t * t);
        float perspective = 2.8 / max(2.8 + world.z, 0.5);
        float2 ndc = float2(world.x / aspect * 2.0 - 1.0, 1.0 - world.y * 2.0) * perspective;
        GlassVarying out;
        out.position = float4(ndc, clamp(0.4 + world.z * 0.18, 0.01, 0.98), 1.0);
        out.source = v.source;
        out.edge = v.edge.x;
        out.normal = glassRotate(float3(0, 0, 1), v.axis.xyz, v.motion.w * t);
        out.seed = v.axis.w;
        out.time = t;
        return out;
    }
    fragment float4 glassFragment(GlassVarying in [[stage_in]],
                                  constant Uniforms &u [[buffer(0)]],
                                  texture2d<float> picture [[texture(0)]]) {
        constexpr sampler linearSampler(filter::linear, mip_filter::linear, address::clamp_to_edge);
        float p = clamp(u.effect.y, 0.0, 1.0);
        float2 size = u.screenAndOrigin.xy;
        float aspect = size.x / size.y;
        float2 world = in.source * float2(aspect, 1.0);
        float2 hit = float2(aspect * 0.54, 0.38);
        float distanceFromHit = distance(world, hit);
        float arrival = smoothstep(distanceFromHit - 0.035, distanceFromHit + 0.035, p * 7.0);
        arrival *= smoothstep(0.001, 0.025, p);
        float pixel = 1.0 / size.y;
        float width = pixel * (0.55 + in.seed * 0.65);
        float split = (1.0 - smoothstep(width * 0.4, width * 1.7, in.edge)) * arrival;
        // Refraction is tiny and only appears as a shard tilts, preserving the desktop at p=0.
        float2 offset = in.normal.xy * min(in.time, 1.0) * 0.002;
        float2 point = float2((in.source.x + offset.x) * size.x, (1.0 - in.source.y - offset.y) * size.y);
        float2 tex = (point - u.screenAndOrigin.zw) / u.paddedAndBlur.xy;
        tex.y = 1.0 - tex.y;
        float3 colour = picture.sample(linearSampler, tex, level(0.0)).rgb;
        float front = smoothstep(-0.12, 0.18, in.normal.z);
        float diffuse = 0.35 + 0.65 * abs(in.normal.z);
        float facing = mix(1.0, mix(0.12, diffuse, front), min(in.time * 3.0, 1.0));
        colour *= facing;
        colour = mix(colour, float3(0.005, 0.008, 0.012), split * 0.88);
        float bevel = exp(-pow((in.edge - width * 2.0) / max(width * 0.65, 0.00001), 2.0)) * arrival;
        float specular = pow(max(dot(normalize(in.normal), normalize(float3(-0.35, -0.55, 1))), 0.0), 36.0);
        colour += bevel * float3(0.23, 0.29, 0.33) * (0.35 + specular);
        colour += float3(0.12, 0.16, 0.19) * specular * min(in.time, 1.0) * 0.25;
        // Tiny branching fissures close to the impact, independent of polygon triangulation.
        float2 relative = world - hit;
        float angle = atan2(relative.y, relative.x);
        float branch = abs(sin(angle * 13.0 + sin(distanceFromHit * 92.0) * 0.22));
        float branchDistance = branch * distanceFromHit / 13.0;
        float micro = (1.0 - smoothstep(pixel * 0.2, pixel * 0.65, branchDistance))
                    * (1.0 - smoothstep(0.045, 0.18, distanceFromHit)) * arrival;
        colour *= 1.0 - micro * 0.6;
        colour *= 1.0 - smoothstep(0.97, 1.0, p);
        return float4(colour, 1.0);
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
