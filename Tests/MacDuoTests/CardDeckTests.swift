import CoreGraphics
import Testing
@testable import MacDuo

struct CardDeckTests {
    @Test func largeScreenCardsAndIndependentRearDeckCoverTheDesktopExactly() {
        let vertices = CardDeckMesh.vertices(aspect: 1.6)
        #expect(vertices.count == 208 * 6)
        #expect(Set(vertices.map { Int($0.axis.w) }) == Set(0..<208))
        let starts = vertices.map { $0.motion.x }
        #expect((starts.max() ?? 0) - (starts.min() ?? 0) > 0.5)
        #expect(Set(vertices.map { Int($0.axis.w) % 52 }) == Set(0..<52))
        #expect(vertices.allSatisfy { (0...1).contains($0.source.x) && (0...1).contains($0.source.y) })
        let primary = vertices.filter { $0.motion.z == 0 }
        let rear = vertices.filter { $0.motion.z > 0 }
        #expect(primary.count == 52 * 6)
        #expect(rear.count == 156 * 6)
        #expect(vertices.allSatisfy { $0.edge.z == 13 && $0.edge.w == 4 })
        var area: Float = 0
        for i in stride(from: 0, to: vertices.count, by: 3) {
            if vertices[i].motion.z > 0 { continue }
            let a = vertices[i + 1].source - vertices[i].source
            let b = vertices[i + 2].source - vertices[i].source
            area += abs(a.x * b.y - a.y * b.x) / 2
        }
        #expect(abs(area - 1) < 0.00001)
        #expect(CardDeckMesh.vertices(aspect: .nan).isEmpty)
    }
    @Test func artworkHasAllFacesAndOpaquePaper() throws {
        let atlas = try #require(CardArtwork.makeAtlas())
        #expect(atlas.width == CardArtwork.cardWidth * 13)
        #expect(atlas.height == CardArtwork.cardHeight * 4)
        #expect(MemoryLayout<GlassVertex>.stride == 64)
    }
    @Test func brandedBackUsesOpaqueSTIXNavyAndWhiteMasterMark() throws {
        let image = try #require(CardBackArtwork.makeImage())
        #expect(image.width == 560 && image.height == 784)
        let data = try #require(image.dataProvider?.data)
        let bytes = try #require(CFDataGetBytePtr(data))
        for y in 0..<image.height {
            for x in 0..<image.width {
                #expect(bytes[y * image.bytesPerRow + x * 4 + 3] == 255)
            }
        }
        let navy = 50 * image.bytesPerRow + 280 * 4
        #expect(Array(UnsafeBufferPointer(start: bytes + navy, count: 4)) == [0, 17, 103, 255])
        // The I in the original central white wordmark must remain visible.
        let mark = 390 * image.bytesPerRow + 337 * 4
        #expect(Array(UnsafeBufferPointer(start: bytes + mark, count: 4)) == [255, 255, 255, 255])
    }

}
