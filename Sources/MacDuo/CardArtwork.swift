import CoreGraphics
import CoreText
import Foundation

/// Original vector-drawn faces. Reverse sides use desktop fragments or separate STIX artwork.
enum CardArtwork {
    static let cardWidth = 140
    static let cardHeight = 196
    static func makeAtlas() -> CGImage? {
        guard let context = CGContext(data: nil, width: cardWidth * 13, height: cardHeight * 4,
                                      bitsPerComponent: 8, bytesPerRow: cardWidth * 13 * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
        context.translateBy(x: 0, y: CGFloat(cardHeight * 4))
        context.scaleBy(x: 1, y: -1)
        let ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
        for suit in 0..<4 {
            for rank in 0..<13 {
                context.saveGState()
                context.translateBy(x: CGFloat(rank * cardWidth), y: CGFloat(suit * cardHeight))
                let ink = suit < 2 ? CGColor(red: 0.68, green: 0.035, blue: 0.10, alpha: 1)
                                   : CGColor(red: 0.035, green: 0.065, blue: 0.12, alpha: 1)
                context.setFillColor(CGColor(red: 0.99, green: 0.98, blue: 0.95, alpha: 1))
                context.fill(CGRect(x: 0, y: 0, width: cardWidth, height: cardHeight))
                context.setStrokeColor(CGColor(gray: 0.80, alpha: 1))
                context.setLineWidth(0.7)
                context.stroke(CGRect(x: 3, y: 3, width: cardWidth - 6, height: cardHeight - 6))
                for corner in 0..<2 {
                    context.saveGState()
                    if corner == 1 { context.translateBy(x: CGFloat(cardWidth), y: CGFloat(cardHeight)); context.rotate(by: .pi) }
                    label(context, ranks[rank], at: CGPoint(x: 14, y: 17), size: rank == 9 ? 15 : 19, colour: ink)
                    pip(context, suit: suit, at: CGPoint(x: 14, y: 38), size: 15, colour: ink)
                    context.restoreGState()
                }
                if rank >= 10 { royal(context, rank: ranks[rank], suit: suit, ink: ink) }
                else {
                    for point in positions(rank + 1) {
                        context.saveGState()
                        context.translateBy(x: point.x * CGFloat(cardWidth), y: point.y * CGFloat(cardHeight))
                        if point.y > 0.51 { context.rotate(by: .pi) }
                        pip(context, suit: suit, at: .zero, size: rank == 0 ? 43 : 23, colour: ink)
                        context.restoreGState()
                    }
                }
                context.restoreGState()
            }
        }
        return context.makeImage()
    }
    private static func label(_ context: CGContext, _ text: String, at point: CGPoint, size: CGFloat, colour: CGColor) {
        let font = CTFontCreateWithName("Georgia-Bold" as CFString, size, nil)
        let attributes = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: colour] as CFDictionary
        guard let string = CFAttributedStringCreate(kCFAllocatorDefault, text as CFString, attributes) else { return }
        let line = CTLineCreateWithAttributedString(string)
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        context.saveGState()
        context.translateBy(x: point.x, y: point.y)
        context.scaleBy(x: 1, y: -1)
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: -bounds.midX, y: -bounds.midY)
        CTLineDraw(line, context)
        context.restoreGState()
    }
    private static func pip(_ context: CGContext, suit: Int, at point: CGPoint, size: CGFloat, colour: CGColor) {
        context.saveGState()
        context.translateBy(x: point.x, y: point.y)
        context.scaleBy(x: size, y: size)
        context.setFillColor(colour)
        if suit == 1 {
            context.move(to: CGPoint(x: 0, y: -0.48)); context.addLine(to: CGPoint(x: 0.34, y: 0))
            context.addLine(to: CGPoint(x: 0, y: 0.48)); context.addLine(to: CGPoint(x: -0.34, y: 0))
            context.closePath(); context.fillPath()
        } else if suit == 2 {
            for center in [CGPoint(x: 0, y: -0.22), CGPoint(x: -0.22, y: 0.08), CGPoint(x: 0.22, y: 0.08)] {
                context.fillEllipse(in: CGRect(x: center.x - 0.23, y: center.y - 0.23, width: 0.46, height: 0.46))
            }
            stem(context)
        } else {
            context.saveGState()
            if suit == 3 { context.scaleBy(x: 1, y: -1) }
            context.move(to: CGPoint(x: 0, y: 0.46))
            context.addCurve(to: CGPoint(x: -0.50, y: -0.12), control1: CGPoint(x: -0.10, y: 0.30), control2: CGPoint(x: -0.52, y: 0.08))
            context.addCurve(to: CGPoint(x: 0, y: -0.25), control1: CGPoint(x: -0.50, y: -0.55), control2: CGPoint(x: -0.12, y: -0.55))
            context.addCurve(to: CGPoint(x: 0.50, y: -0.12), control1: CGPoint(x: 0.12, y: -0.55), control2: CGPoint(x: 0.50, y: -0.55))
            context.addCurve(to: CGPoint(x: 0, y: 0.46), control1: CGPoint(x: 0.52, y: 0.08), control2: CGPoint(x: 0.10, y: 0.30))
            context.closePath(); context.fillPath()
            context.restoreGState()
            if suit == 3 { stem(context) }
        }
        context.restoreGState()
    }
    private static func stem(_ context: CGContext) {
        context.move(to: CGPoint(x: 0, y: 0.10)); context.addLine(to: CGPoint(x: -0.18, y: 0.48))
        context.addLine(to: CGPoint(x: 0.18, y: 0.48)); context.closePath(); context.fillPath()
    }
    private static func royal(_ context: CGContext, rank: String, suit: Int, ink: CGColor) {
        context.setStrokeColor(ink); context.setLineWidth(1.2)
        context.stroke(CGRect(x: 31, y: 48, width: 78, height: 100))
        let gold = CGColor(red: 0.72, green: 0.49, blue: 0.18, alpha: 1)
        for half in 0..<2 {
            context.saveGState()
            context.translateBy(x: 70, y: 98)
            if half == 1 { context.rotate(by: .pi) }
            context.setFillColor(ink)
            context.move(to: CGPoint(x: -31, y: 0)); context.addLine(to: CGPoint(x: -18, y: -23))
            context.addLine(to: CGPoint(x: 18, y: -23)); context.addLine(to: CGPoint(x: 31, y: 0)); context.closePath(); context.fillPath()
            context.setStrokeColor(gold); context.setLineWidth(3)
            context.move(to: CGPoint(x: -22, y: -2)); context.addLine(to: CGPoint(x: 8, y: -21)); context.strokePath()
            context.setFillColor(CGColor(red: 0.96, green: 0.82, blue: 0.63, alpha: 1))
            context.fillEllipse(in: CGRect(x: -10, y: -40, width: 20, height: 25))
            context.setFillColor(gold)
            context.move(to: CGPoint(x: -13, y: -38)); context.addLine(to: CGPoint(x: -15, y: -47))
            context.addLine(to: CGPoint(x: -5, y: -43)); context.addLine(to: CGPoint(x: 0, y: -50))
            context.addLine(to: CGPoint(x: 5, y: -43)); context.addLine(to: CGPoint(x: 15, y: -47))
            context.addLine(to: CGPoint(x: 13, y: -38)); context.closePath(); context.fillPath()
            label(context, rank, at: CGPoint(x: 1, y: -10), size: 14, colour: gold)
            pip(context, suit: suit, at: CGPoint(x: -23, y: -31), size: 10, colour: ink)
            context.restoreGState()
        }
    }
    private static func positions(_ value: Int) -> [CGPoint] {
        if value == 1 { return [CGPoint(x: 0.5, y: 0.5)] }
        if value <= 3 { return (value == 2 ? [0.28, 0.72] : [0.25, 0.5, 0.75]).map { CGPoint(x: 0.5, y: $0) } }
        let rows: [Double] = value <= 5 ? [0.28, 0.72] : value <= 8 ? [0.26, 0.5, 0.74] : [0.23, 0.41, 0.59, 0.77]
        var result = rows.flatMap { y in [CGPoint(x: 0.32, y: y), CGPoint(x: 0.68, y: y)] }
        if value == 5 || value == 9 { result.append(CGPoint(x: 0.5, y: 0.5)) }
        if value == 7 { result.append(CGPoint(x: 0.5, y: 0.37)) }
        if value == 8 || value == 10 { result += [CGPoint(x: 0.5, y: 0.34), CGPoint(x: 0.5, y: 0.66)] }
        return result
    }
}
