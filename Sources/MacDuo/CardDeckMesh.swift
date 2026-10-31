import Foundation
import simd

/// Four interleaved decks produce a fast, continuous stream over the same animation duration.
enum CardDeckMesh {
    static let columns = 26
    static let rows = 8
    static let count = columns * rows
    static func vertices(aspect: Double) -> [GlassVertex] {
        guard aspect.isFinite, aspect > 0 else { return [] }
        var result: [GlassVertex] = []
        let corners: [SIMD2<Float>] = [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1), SIMD2(0, 0), SIMD2(1, 1), SIMD2(0, 1)]
        for id in 0..<count {
            let column = Float(id % columns), row = Float(id / columns)
            let pivot = SIMD2((column + 0.5) / Float(columns), (row + 0.5) / Float(rows))
            let seed = Float((id * 37 + 11) % 101) / 100
            let distance = simd_length((pivot - SIMD2(0.5, 0.5)) * SIMD2(Float(aspect), 1))
            // 73 is coprime with 208: every tile gets a unique, spatially interleaved start.
            let order = Float((id * 73) % count) / Float(count - 1)
            let motion = SIMD4(0.025 + order * 0.62 + distance * 0.025, seed, 0, 2.5 + seed * 3.5)
            let axis = SIMD4((seed - 0.5) * 0.7, 1, (Float(id % 7) - 3) * 0.13, Float(id))
            for uv in corners {
                result.append(GlassVertex(source: SIMD2((column + uv.x) / Float(columns), (row + uv.y) / Float(rows)),
                                          pivot: pivot, motion: motion, axis: axis, edge: SIMD4(uv.x, uv.y, Float(columns), Float(rows))))
            }
        }
        return result
    }
}
