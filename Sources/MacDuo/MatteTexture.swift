import CoreGraphics
import Foundation

/// Neutral, stationary surface grain. No blur, screen capture or animation is involved.
enum MatteTexture {
    static func intensity(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0.15), 1) : 0.6
    }
    static func makeTile(pixelSize: Int) -> CGImage? {
        guard (16...512).contains(pixelSize) else { return nil }
        var pixels = [UInt8](repeating: 0, count: pixelSize * pixelSize * 4)
        var seed: UInt64 = 0x535449584D415454
        for i in stride(from: 0, to: pixels.count, by: 4) {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let noise = Double((seed >> 32) & 0xFFFF) / 65535
            let alpha: UInt8 = 28
            let grey = UInt8(((0.28 + noise * 0.40) * Double(alpha)).rounded())
            pixels[i] = grey
            pixels[i + 1] = grey
            pixels[i + 2] = grey
            pixels[i + 3] = alpha
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: pixelSize, height: pixelSize, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: pixelSize * 4, space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
