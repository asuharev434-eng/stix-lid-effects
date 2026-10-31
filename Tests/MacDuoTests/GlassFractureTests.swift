import Testing
@testable import MacDuo

struct GlassFractureTests {
    @Test func shardsCoverScreenWithoutGridHolesAndHaveVariedSizes() {
        let shards = GlassFracture.shards(aspect: 1.6)
        #expect(shards.count > 45)
        let area = shards.reduce(0.0) { $0 + $1.area }
        #expect(abs(area - 1.6) < 0.00001)
        let areas = shards.map(\.area)
        #expect((areas.max() ?? 0) > (areas.min() ?? 1) * 20)
        let near = shards.filter { $0.impactDistance < 0.12 }
        let far = shards.filter { $0.impactDistance > 0.5 }
        #expect(!near.isEmpty && !far.isEmpty)
        #expect(near.reduce(0.0) { $0 + $1.area } / Double(near.count) < far.reduce(0.0) { $0 + $1.area } / Double(far.count))
    }
    @Test func stableGeometryHasIndependentReleaseTimesAndSpin() {
        let first = GlassFracture.vertices(aspect: 1.6)
        let second = GlassFracture.vertices(aspect: 1.6)
        #expect(first.count == second.count && first.count % 3 == 0)
        #expect(first.count < 6000)
        #expect(zip(first, second).allSatisfy { $0.source == $1.source && $0.motion == $1.motion })
        #expect(first.allSatisfy { $0.source.x.isFinite && $0.source.y.isFinite && $0.edge.x >= 0 })
        #expect(Set(first.map { Int($0.motion.x * 1000) }).count > 12)
        #expect(first.contains { $0.motion.w < 0 } && first.contains { $0.motion.w > 0 })
    }
}
