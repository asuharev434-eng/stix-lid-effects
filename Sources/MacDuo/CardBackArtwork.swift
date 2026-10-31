import CoreGraphics

/// Cached print artwork for the independent rear decks. No desktop pixels.
enum CardBackArtwork {
    static let width = 560
    static let height = 784

    static func makeImage() -> CGImage? {
        guard let context = CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.setFillColor(CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                                     components: [0, 17.0 / 255, 103.0 / 255, 1])!)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.85))
        context.setLineWidth(2)
        context.addPath(CGPath(roundedRect: CGRect(x: 24, y: 24, width: 512, height: 736), cornerWidth: 18, cornerHeight: 18, transform: nil))
        context.strokePath()
        // Quiet flowing lines leave clear space around the master wordmark.
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.16))
        context.setLineWidth(1.5)
        for offset in stride(from: 0, through: 100, by: 20) {
            let shift = CGFloat(offset)
            context.move(to: CGPoint(x: 48, y: 100 + shift))
            context.addCurve(to: CGPoint(x: 512, y: 190 + shift), control1: CGPoint(x: 200, y: 10 + shift), control2: CGPoint(x: 340, y: 280 + shift))
            context.move(to: CGPoint(x: 48, y: 594 - shift))
            context.addCurve(to: CGPoint(x: 512, y: 684 - shift), control1: CGPoint(x: 200, y: 504 - shift), control2: CGPoint(x: 340, y: 774 - shift))
        }
        context.strokePath()
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        let logoWidth: CGFloat = 400
        let logoHeight = logoWidth * 251.6 / 689.5
        STIXWordmark.draw(in: context, rect: CGRect(x: 80, y: (784 - logoHeight) / 2, width: logoWidth, height: logoHeight))
        return context.makeImage()
    }
}
