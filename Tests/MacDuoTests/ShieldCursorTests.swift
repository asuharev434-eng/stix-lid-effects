import AppKit
import CoreImage
import Testing
@testable import MacDuo

struct ShieldCursorTests {
    @MainActor @Test func shieldCursorHasNoVisiblePixels() throws {
        var rect = CGRect(x: 0, y: 0, width: 16, height: 16)
        let image = try #require(ShieldCursor.invisible.image.cgImage(forProposedRect: &rect, context: nil, hints: nil))
        let source = CIImage(cgImage: image)
        var pixels = [UInt8](repeating: 255, count: 16 * 16 * 4)
        pixels.withUnsafeMutableBytes {
            CIContext().render(source, toBitmap: $0.baseAddress!, rowBytes: 64, bounds: rect, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        }
        #expect(pixels.enumerated().filter { $0.offset % 4 == 3 }.allSatisfy { $0.element == 0 })
    }
}
