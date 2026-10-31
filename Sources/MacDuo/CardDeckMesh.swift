import Foundation
import simd

/// The 52 screen tiles become poker-sized cards after lifting off the display.
enum CardDeckMesh {
    static func vertices(aspect: Double) -> [GlassVertex] {
        guard aspect.isFinite, aspect > 0 else { return [] }
        var result: [GlassVertex] = []
        let corners: [SIMD2<Float>] = [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1), SIMD2(0, 0), SIMD2(1, 1), SIMD2(0, 1)]
        for id in 0..<52 {
            let column = Float(id % 13), row = Float(id / 13)
            let pivot = SIMD2((column + 0.5) / 13, (row + 0.5) / 4)
            let seed = Float((id * 37 + 11) % 101) / 100
            let distance = simd_length((pivot - SIMD2(0.5, 0.5)) * SIMD2(Float(aspect), 1))
            let motion = SIMD4(0.025 + distance * 0.10 + seed * 0.055, seed, 0, 2.5 + seed * 3.5)
            let axis = SIMD4((seed - 0.5) * 0.7, 1, (Float(id % 7) - 3) * 0.13, Float(id))
            for uv in corners {
                result.append(GlassVertex(source: SIMD2((column + uv.x) / 13, (row + uv.y) / 4),
                                          pivot: pivot, motion: motion, axis: axis, edge: SIMD4(uv.x, uv.y, 0, 0)))
            }
        }
        return result
    }
}
