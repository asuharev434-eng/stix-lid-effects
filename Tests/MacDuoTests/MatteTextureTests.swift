import CoreGraphics
import Foundation
import Testing
@testable import MacDuo

struct MatteTextureTests {
    @Test func textureIsSubtleNeutralAndDeterministic() throws {
        let tile = try #require(MatteTexture.makeTile(pixelSize: 128))
        let second = try #require(MatteTexture.makeTile(pixelSize: 128))
        let bytes = try #require(tile.dataProvider?.data) as Data
        let repeated = try #require(second.dataProvider?.data) as Data
        #expect(bytes == repeated)
        #expect(tile.width == 128 && tile.height == 128)
        var shades: Set<UInt8> = []
        for i in stride(from: 0, to: bytes.count, by: 4) {
            #expect(bytes[i] == bytes[i + 1] && bytes[i + 1] == bytes[i + 2])
            #expect(bytes[i + 3] <= 32 && bytes[i + 3] > 0)
            #expect(bytes[i] <= bytes[i + 3]) // Premultiplied colour, never a white wash.
            shades.insert(bytes[i])
        }
        #expect(shades.count >= 8)
    }
    @Test func settingsRejectInvalidIntensityAndUnsafeTextureSizes() {
        #expect(MatteTexture.intensity(.nan) == 0.6)
        #expect(MatteTexture.intensity(.infinity) == 0.6)
        #expect(MatteTexture.intensity(-1) == 0.15)
        #expect(MatteTexture.intensity(3) == 1)
        #expect(MatteTexture.makeTile(pixelSize: 0) == nil)
        #expect(MatteTexture.makeTile(pixelSize: 4096) == nil)
    }
}
