import Foundation

/// Stateless scene: reversing progress restores the same three paint strokes.
/// Coordinates use screen height for a consistent tool shape on any display.
enum PaintRollerShader {
    static let source = """
    float rollerSegment(float2 p, float2 a, float2 b) {
        float2 ab = b - a;
        return length(p - a - ab * clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0));
    }
    float rollerBox(float2 p, float2 halfSize, float radius) {
        float2 d = abs(p) - halfSize + radius;
        return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
    }
    float rollerInk(float distance, float aa) {
        return 1.0 - smoothstep(-aa, aa, distance);
    }
    float rollerX(float phase, int row, float aspect) {
        float sweep = smoothstep(0.0, 0.88, phase);
        return (row == 1) ? mix(aspect + 0.28, -0.28, sweep)
                          : mix(-0.28, aspect + 0.28, sweep);
    }
    float3 paintRoller(float2 uv, float progress, float aspect, float aa, float3 desktop) {
        if (progress <= 0.0) return desktop;
        if (progress >= 1.0) return float3(0.0);
        float time = progress * 3.0;
        float2 point = uv * float2(aspect, 1.0);
        float coverage = 0.0;
        float wetEdge = 0.0;
        for (int row = 0; row < 3; ++row) {
            float phase = clamp(time - float(row), 0.0, 1.0);
            if (phase <= 0.0) continue;
            float center = (float(row) + 0.5) / 3.0;
            // Overlap removes seams; fibres make the advancing edge organic.
            float fibre = sin(point.y * 1753.0) * 0.0007 + sin(point.y * 4391.0) * 0.00035;
            float band = 1.0 - smoothstep(0.1735, 0.1755, abs(uv.y - center));
            float x = rollerX(phase, row, aspect);
            float behind = (row == 1) ? point.x - x : x - point.x;
            float stroke = smoothstep(-aa, aa, behind + fibre);
            coverage = max(coverage, band * stroke);
            // Only the thin fresh edge catches light; dry paint is true black.
            wetEdge = max(wetEdge, band * stroke * exp(-max(behind, 0.0) * 240.0) * 0.022);
        }
        float3 colour = desktop * (1.0 - coverage) + float3(wetEdge);
        int row = min(int(time), 2);
        float phase = fract(time);
        float x = rollerX(phase, row, aspect);
        float y = (float(row) + 0.5) / 3.0;
        if (row < 2) y += smoothstep(0.88, 1.0, phase) / 3.0;
        float2 local = point - float2(x, y);
        const float halfWidth = 0.032;
        const float halfHeight = 0.178;
        // Soft contact shadow below the raised tool, over both paint and desktop.
        float shadow = exp(-max(rollerBox(local - float2(0.014, 0.013), float2(halfWidth, halfHeight), 0.012), 0.0) * 100.0);
        colour *= 1.0 - shadow * 0.28;

        // Bent chrome arm, connected to the upper cylinder spindle.
        float2 a = float2(0.0, -0.184);
        float2 b = float2(0.070, -0.184);
        float2 c = float2(0.092, 0.050);
        float2 d = float2(0.151, 0.111);
        float armDistance = min(min(rollerSegment(local, a, b), rollerSegment(local, b, c)), rollerSegment(local, c, d));
        float arm = rollerInk(armDistance - 0.0042, aa);
        float shine = exp(-armDistance * 340.0);
        colour = mix(colour, mix(float3(0.18, 0.20, 0.24), float3(0.83, 0.87, 0.92), shine), arm);

        // Moulded navy handle with metal collar and inset grip ribs.
        float2 gripStart = float2(0.140, 0.100), gripEnd = float2(0.222, 0.184);
        float handleDistance = rollerSegment(local, gripStart, gripEnd);
        float handle = rollerInk(handleDistance - 0.015, aa);
        float axial = dot(local - gripStart, normalize(gripEnd - gripStart));
        float ribs = pow(0.5 + 0.5 * cos(axial * 570.0), 7.0);
        float3 gripColour = float3(0.006, 0.020, 0.115) + exp(-handleDistance * 160.0) * float3(0.015, 0.035, 0.095);
        gripColour *= 1.0 - ribs * 0.30;
        colour = mix(colour, gripColour, handle);
        float collar = rollerInk(rollerSegment(local, float2(0.135, 0.094), float2(0.148, 0.107)) - 0.016, aa);
        colour = mix(colour, float3(0.50, 0.55, 0.62), collar);

        // Rounded end caps behind a cylindrical, paint-loaded nap sleeve.
        float caps = rollerInk(rollerBox(local, float2(0.030, 0.184), 0.009), aa);
        colour = mix(colour, float3(0.52, 0.55, 0.57), caps);
        float bodyDistance = rollerBox(local, float2(halfWidth, halfHeight), 0.010);
        float body = rollerInk(bodyDistance, aa);
        float cylinder = sqrt(max(1.0 - pow(local.x / halfWidth, 2.0), 0.0));
        float nap = fract(sin(dot(floor((local + float2(phase * 0.4, 0.0)) * 2200.0), float2(12.9898, 78.233))) * 43758.5453);
        float highlight = exp(-pow((local.x + 0.011) / 0.012, 2.0));
        float sleeve = 0.008 + cylinder * 0.017 + highlight * 0.045 + nap * 0.013;
        colour = mix(colour, float3(sleeve), body);
        return colour;
    }
    """
}
