import CoreGraphics
import Foundation
import Testing
@testable import MacDuo

struct BanknoteTests {
    @Test func separateFacesAreWideOpaqueAndDistinct() throws {
        var images: [Data] = []
        for currency in BanknoteCurrency.allCases {
            for reverse in [false, true] {
                let image = try #require(BanknoteArtwork.makeImage(currency: currency, reverse: reverse))
                #expect(image.width == currency.imageSize.width && image.height == currency.imageSize.height)
                let data = try #require(image.dataProvider?.data) as Data
                #expect(stride(from: 3, to: data.count, by: 4).allSatisfy { data[$0] == 255 })
                #expect(!images.contains(data))
                images.append(data)
            }
        }
    }

    @Test func screenNotesTileExactlyWithIndependentRearLayers() {
        let vertices = CardDeckMesh.vertices(aspect: 1.6, columns: 8, rows: 6)
        #expect(vertices.count == 192 * 6)
        #expect(vertices.filter { $0.motion.z == 0 }.count == 48 * 6)
        #expect(vertices.filter { $0.motion.z > 0 }.count == 144 * 6)
        #expect(vertices.allSatisfy { $0.edge.z == 8 && $0.edge.w == 6 })
        var area: Float = 0
        for i in stride(from: 0, to: vertices.count, by: 3) where vertices[i].motion.z == 0 {
            let a = vertices[i + 1].source - vertices[i].source
            let b = vertices[i + 2].source - vertices[i].source
            area += abs(a.x * b.y - a.y * b.x) / 2
        }
        #expect(abs(area - 1) < 0.00001)
        #expect(CardDeckMesh.vertices(aspect: 1.6, columns: 0, rows: 6).isEmpty)
        #expect(CardDeckMesh.vertices(aspect: 1.6, columns: 8, rows: -1).isEmpty)
        #expect(EffectStyle.cards.rawValue == 9 && EffectStyle.paintRoller.rawValue == 10)
        for style in [EffectStyle.rubles, .dollars] {
            #expect(style.isFlyingPaper && style.banknoteCurrency != nil)
            #expect(style.manualDuration == 3.4)
        }
    }
}
