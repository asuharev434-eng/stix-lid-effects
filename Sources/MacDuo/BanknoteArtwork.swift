import CoreGraphics
import Foundation
import ImageIO

enum BanknoteCurrency: String, CaseIterable {
    case rubles, dollars

    /// Common canvas per pair, matching the downloaded source proportions.
    var imageSize: (width: Int, height: Int) {
        switch self {
        case .rubles: return (1236, 544)
        case .dollars: return (1400, 600)
        }
    }
    var aspect: Float { Float(imageSize.width) / Float(imageSize.height) }
}

/// Bundled official banknote images. Source URLs and checksums: docs/banknote-assets.md.
/// Decode once to a known RGBA8 layout for safe upload to the Metal texture cache.
enum BanknoteArtwork {
    static func makeImage(currency: BanknoteCurrency, reverse: Bool) -> CGImage? {
        let name = "\(currency.rawValue)-\(reverse ? "back" : "front")"
        guard let url = Bundle.module.url(forResource: name, withExtension: "jpg"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0,
                [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let size = currency.imageSize
        guard let context = CGContext(data: nil, width: size.width, height: size.height,
            bitsPerComponent: 8, bytesPerRow: size.width * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        return context.makeImage()
    }
}
