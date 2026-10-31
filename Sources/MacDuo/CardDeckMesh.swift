import Foundation
import simd

/// One screen-backed deck and three ordinary decks behind it, all at the original card size.
enum CardDeckMesh {
    static let columns = 13
    static let rows = 4
    static let screenCount = columns * rows
    static let count = screenCount * 4
    static func vertices(aspect: Double) -> [GlassVertex] {
        guard aspect.isFinite, aspect > 0 else { return [] }
        var result: [GlassVertex] = []
        let corners: [SIMD2<Float>] = [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1), SIMD2(0, 0), SIMD2(1, 1), SIMD2(0, 1)]
        for id in 0..<count {
            let layer = id / screenCount
            let tile = id % screenCount
            let column = Float(tile % columns), row = Float(tile / columns)
            let pivot = SIMD2((column + 0.5) / Float(columns), (row + 0.5) / Float(rows))
            let seed = Float((id * 37 + 11) % 101) / 100
            let distance = simd_length((pivot - SIMD2(0.5, 0.5)) * SIMD2(Float(aspect), 1))
            // Screen fragments leave first; ordinary decks emerge from deeper layers later.
            let order = Float((tile * 17) % screenCount) / Float(screenCount - 1)
            let delay = layer == 0 ? 0.025 + order * 0.12 + distance * 0.02
                                   : 0.09 + Float(layer) * 0.13 + order * 0.18
            let depth = Float(layer) * 0.35
            let motion = SIMD4(delay, seed, depth, 2.5 + seed * 3.5)
            let axis = SIMD4((seed - 0.5) * 0.7, 1, (Float(id % 7) - 3) * 0.13, Float(id))
            for uv in corners {
                result.append(GlassVertex(source: SIMD2((column + uv.x) / Float(columns), (row + uv.y) / Float(rows)),
                                          pivot: pivot, motion: motion, axis: axis, edge: SIMD4(uv.x, uv.y, Float(columns), Float(rows))))
            }
        }
        return result
    }
}
