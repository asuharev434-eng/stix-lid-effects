import Foundation
import simd

/// Shared with the Metal GlassVertex layout (64 bytes, float4 aligned).
struct GlassVertex {
    var source: SIMD2<Float>
    var pivot: SIMD2<Float>
    var motion: SIMD4<Float>
    var axis: SIMD4<Float>
    var edge: SIMD4<Float>
}

enum GlassFracture {
    struct Shard {
        let polygon: [SIMD2<Double>]
        let pivot: SIMD2<Double>
        let area: Double
        let impactDistance: Double
        let seed: Double
    }
    private struct Generator {
        var state: UInt64 = 0x53544958474C4153
        mutating func next() -> Double {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return Double((z ^ (z >> 31)) >> 11) / 9_007_199_254_740_992.0
        }
    }

    /// Impact-biased Voronoi cells: fine chips at the hit, large plates at the edges.
    static func shards(aspect: Double) -> [Shard] {
        guard aspect.isFinite, aspect > 0 else { return [] }
        let impact = SIMD2(aspect * 0.54, 0.38)
        var random = Generator()
        var sites = [impact]
        let rays = (0..<19).map { index in
            (Double(index) + (random.next() - 0.5) * 0.55) * 2 * .pi / 19
        }
        for radius in [0.018, 0.043, 0.09, 0.17, 0.30, 0.50, 0.79, 1.18, 1.75, 2.5, 3.6] {
            for angle in rays {
                let r = radius * (0.82 + random.next() * 0.36)
                let a = angle + (random.next() - 0.5) * 0.13
                let site = impact + SIMD2(cos(a) * r, sin(a) * r)
                if site.x >= -0.2 && site.x <= aspect + 0.2 && site.y >= -0.2 && site.y <= 1.2 {
                    sites.append(site)
                }
            }
        }
        let rectangle = [SIMD2(0.0, 0.0), SIMD2(aspect, 0), SIMD2(aspect, 1), SIMD2(0, 1)]
        return sites.enumerated().compactMap { index, site in
            var polygon = rectangle
            for (otherIndex, other) in sites.enumerated() where otherIndex != index {
                let normal = other - site
                let limit = (simd_length_squared(other) - simd_length_squared(site)) / 2
                polygon = clip(polygon, normal: normal, limit: limit)
                if polygon.count < 3 { return nil }
            }
            var twiceArea = 0.0
            var weighted = SIMD2<Double>.zero
            for i in polygon.indices {
                let a = polygon[i], b = polygon[(i + 1) % polygon.count]
                let cross = a.x * b.y - b.x * a.y
                twiceArea += cross
                weighted += (a + b) * cross
            }
            guard abs(twiceArea) > 1e-9 else { return nil }
            let pivot = weighted / (3 * twiceArea)
            return Shard(polygon: polygon, pivot: pivot, area: abs(twiceArea) / 2,
                         impactDistance: simd_distance(pivot, impact), seed: random.next())
        }
    }

    static func vertices(aspect: Double) -> [GlassVertex] {
        var result: [GlassVertex] = []
        for shard in shards(aspect: aspect) {
            let seed = Float(shard.seed)
            let pivot = SIMD2(Float(shard.pivot.x / aspect), Float(shard.pivot.y))
            let delay = 0.20 + seed * 0.17 + Float(min(shard.impactDistance * 0.10, 0.10))
            let sideways = Float(shard.pivot.x - aspect * 0.54) * 0.15 + (seed - 0.5) * 0.18
            let spin = (seed - 0.5) * (4 + 1 / max(Float(sqrt(shard.area)) * 10, 0.4))
            let motion = SIMD4(delay, sideways, -0.16 - seed * 0.13, spin)
            let axis3 = simd_normalize(SIMD3(sin(seed * 71), cos(seed * 53), sin(seed * 39) * 0.7 + 0.2))
            let axis = SIMD4(axis3.x, axis3.y, axis3.z, seed)
            for i in shard.polygon.indices {
                let a = shard.polygon[i], b = shard.polygon[(i + 1) % shard.polygon.count]
                let delta = b - a
                let altitude = abs(delta.x * (shard.pivot.y - a.y) - delta.y * (shard.pivot.x - a.x)) / max(simd_length(delta), 1e-12)
                for (point, distance) in [(shard.pivot, altitude), (a, 0.0), (b, 0.0)] {
                    result.append(GlassVertex(source: SIMD2(Float(point.x / aspect), Float(point.y)),
                                              pivot: pivot, motion: motion, axis: axis,
                                              edge: SIMD4(Float(distance), 0, 0, 0)))
                }
            }
        }
        return result
    }

    private static func clip(_ polygon: [SIMD2<Double>], normal: SIMD2<Double>, limit: Double) -> [SIMD2<Double>] {
        guard let last = polygon.last else { return [] }
        var result: [SIMD2<Double>] = []
        var previous = last
        var previousDistance = simd_dot(previous, normal) - limit
        for point in polygon {
            let distance = simd_dot(point, normal) - limit
            if (distance <= 0) != (previousDistance <= 0) {
                let t = previousDistance / (previousDistance - distance)
                result.append(previous + (point - previous) * t)
            }
            if distance <= 0 { result.append(point) }
            previous = point
            previousDistance = distance
        }
        return result
    }
}
