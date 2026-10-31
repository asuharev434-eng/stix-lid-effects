import CoreImage
import Testing
@testable import MacDuo

struct WindowBlurTests {
    @Test func preservesWindowColourAndSoftensEdgesWithoutWhiteVeil() throws {
        // Red window over a blue desktop, with a sharp vertical edge.
        let size = 256
        let desktop = CIImage(color: CIColor(red: 0.05, green: 0.1, blue: 0.8)).cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
        let window = CIImage(color: CIColor(red: 0.8, green: 0.05, blue: 0.1)).cropped(to: CGRect(x: 64, y: 40, width: 128, height: 176))
        let source = window.composited(over: desktop)
        let renderer = WindowBlurRenderer()
        let result = try #require(renderer.render(source))
        let image = CIImage(cgImage: result)
        let context = CIContext()
        func pixel(_ x: Int, _ y: Int) -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: 4)
            bytes.withUnsafeMutableBytes {
                context.render(image, toBitmap: $0.baseAddress!, rowBytes: 4, bounds: CGRect(x: x, y: y, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
            }
            return bytes
        }
        let center = pixel(128, 128)
        let desktopPixel = pixel(8, 128)
        let edge = pixel(64, 128)
        #expect(center[0] > 170 && center[1] < 60 && center[2] < 70)
        #expect(desktopPixel[2] > 170 && desktopPixel[0] < 60)
        #expect(edge[0] > desktopPixel[0] + 30)
        #expect(edge[2] > center[2] + 30)
        #expect(center[3] == 255 && edge[3] == 255)
        #expect(result.width == size && result.height == size)
    }
}
