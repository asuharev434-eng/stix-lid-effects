import CoreGraphics
import CoreText
import Foundation

enum BanknoteCurrency: CaseIterable {
    case rubles, dollars
}

/// Original illustrative artwork for animation, generated locally without downloads.
/// A single wide sheet per side keeps note texture coordinates independent of cards.
enum BanknoteArtwork {
    static let width = 1024
    static let height = 448

    static func makeImage(currency: BanknoteCurrency, reverse: Bool) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let c = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
        func colour(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
            CGColor(colorSpace: space, components: [r, g, b, alpha])!
        }
        let rubles = currency == .rubles
        let ink = rubles ? colour(0.42, 0.19, 0.12) : colour(0.12, 0.25, 0.19)
        let paleInk = rubles ? colour(0.63, 0.32, 0.19, 0.23) : colour(0.20, 0.39, 0.29, 0.23)
        let paper = rubles ? colour(0.96, 0.85, 0.72) : colour(0.88, 0.92, 0.83)
        c.translateBy(x: 0, y: CGFloat(height)); c.scaleBy(x: 1, y: -1)
        c.setFillColor(paper); c.fill(CGRect(x: 0, y: 0, width: width, height: height))
        c.setStrokeColor(paleInk); c.setLineWidth(0.7)
        // Engraved flowing lines and rosettes suggest banknote printing at flight scale.
        for line in 0..<94 {
            let y = CGFloat(line) * 4.7
            c.move(to: CGPoint(x: 15, y: y))
            for step in 1...128 {
                let x = CGFloat(step) * 8
                c.addLine(to: CGPoint(x: x, y: y + sin(x * 0.022 + CGFloat(line) * 0.23) * 9))
            }
        }
        c.strokePath()
        for center in [CGPoint(x: 145, y: 222), CGPoint(x: 867, y: 222)] {
            for ring in 0..<28 {
                let radius = CGFloat(26 + ring * 2)
                c.move(to: CGPoint(x: center.x + radius, y: center.y))
                for step in 1...180 {
                    let a = CGFloat(step) * .pi / 90
                    let r = radius + sin(a * 17 + CGFloat(ring) * 0.14) * 9
                    c.addLine(to: CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r * 1.25))
                }
            }
        }
        c.strokePath()
        c.setStrokeColor(ink); c.setLineWidth(3)
        c.stroke(CGRect(x: 18, y: 18, width: 988, height: 412))
        c.setLineWidth(0.9); c.stroke(CGRect(x: 26, y: 26, width: 972, height: 396))
        let denomination = rubles ? "5000" : "100"
        text(c, rubles ? "БИЛЕТ БАНКА РОССИИ" : "THE UNITED STATES OF AMERICA", x: 512, y: 52, size: rubles ? 24 : 23, ink: ink)
        text(c, rubles ? "ПЯТЬ ТЫСЯЧ РУБЛЕЙ" : "ONE HUNDRED DOLLARS", x: 512, y: 399, size: 25, ink: ink)
        text(c, denomination, x: 121, y: 82, size: 55, ink: ink)
        text(c, denomination, x: 890, y: 362, size: 61, ink: ink)
        if rubles {
            if reverse { bridge(c, ink: ink) }
            else {
                // Monument and riverside silhouette, deliberately drawn as an illustration.
                c.setFillColor(colour(0.62, 0.32, 0.20, 0.15))
                c.fillEllipse(in: CGRect(x: 280, y: 90, width: 420, height: 280))
                bridge(c, ink: paleInk)
                c.setFillColor(ink)
                c.fill(CGRect(x: 431, y: 234, width: 59, height: 108))
                c.fill(CGRect(x: 415, y: 330, width: 92, height: 15))
                c.fill(CGRect(x: 440, y: 145, width: 37, height: 89))
                c.fillEllipse(in: CGRect(x: 447, y: 124, width: 23, height: 27))
                c.move(to: CGPoint(x: 444, y: 155)); c.addLine(to: CGPoint(x: 422, y: 197))
                c.addLine(to: CGPoint(x: 437, y: 205)); c.addLine(to: CGPoint(x: 463, y: 166)); c.fillPath()
                c.move(to: CGPoint(x: 473, y: 158)); c.addLine(to: CGPoint(x: 502, y: 183))
                c.addLine(to: CGPoint(x: 500, y: 196)); c.addLine(to: CGPoint(x: 467, y: 180)); c.fillPath()
            }
            text(c, "5000", x: 840, y: 216, size: 86, ink: ink)
            text(c, "ХАБАРОВСК", x: 493, y: 367, size: 14, ink: ink)
        } else {
            if reverse { hall(c, ink: ink) }
            else {
                portrait(c, ink: ink, paper: paper)
                // Blue security-ribbon accent and copper denomination.
                c.setFillColor(colour(0.11, 0.35, 0.63, 0.75))
                c.fill(CGRect(x: 650, y: 79, width: 21, height: 285))
                for y in stride(from: 90, through: 350, by: 26) {
                    text(c, "100", x: 660, y: CGFloat(y), size: 8, ink: colour(0.84, 0.91, 0.95))
                }
                text(c, "100", x: 818, y: 251, size: 93, ink: colour(0.57, 0.32, 0.12))
                text(c, "FRANKLIN", x: 451, y: 367, size: 13, ink: ink)
            }
            text(c, "FEDERAL RESERVE NOTE", x: 511, y: 79, size: 13, ink: ink)
            text(c, "100", x: 125, y: 342, size: 76, ink: ink)
        }
        // Clearly identify this as original illustrative animation artwork.
        text(c, "STIX • MOTION ART", x: 166, y: 405, size: 9, ink: ink)
        return c.makeImage()
    }

    private static func text(_ c: CGContext, _ value: String, x: CGFloat, y: CGFloat, size: CGFloat, ink: CGColor) {
        let font = CTFontCreateWithName("Georgia-Bold" as CFString, size, nil)
        let attributes = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: ink] as CFDictionary
        guard let string = CFAttributedStringCreate(nil, value as CFString, attributes) else { return }
        let line = CTLineCreateWithAttributedString(string)
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        c.saveGState(); c.translateBy(x: x, y: y); c.scaleBy(x: 1, y: -1)
        c.textMatrix = .identity; c.textPosition = CGPoint(x: -bounds.midX, y: -bounds.midY)
        CTLineDraw(line, c); c.restoreGState()
    }

    private static func bridge(_ c: CGContext, ink: CGColor) {
        c.setStrokeColor(ink); c.setLineWidth(2)
        c.move(to: CGPoint(x: 240, y: 302)); c.addLine(to: CGPoint(x: 751, y: 302))
        c.move(to: CGPoint(x: 240, y: 312)); c.addLine(to: CGPoint(x: 751, y: 312))
        for x in stride(from: 260, through: 720, by: 92) {
            let a = CGFloat(x)
            c.move(to: CGPoint(x: a, y: 345)); c.addLine(to: CGPoint(x: a, y: 305))
            c.move(to: CGPoint(x: a - 43, y: 298))
            c.addQuadCurve(to: CGPoint(x: a + 43, y: 298), control: CGPoint(x: a, y: 197))
            for i in stride(from: -35, through: 35, by: 10) {
                let offset = CGFloat(i)
                c.move(to: CGPoint(x: a + offset, y: 302))
                c.addLine(to: CGPoint(x: a + offset, y: 248 + offset * offset / 35))
            }
        }
        for i in 0..<12 {
            let y = CGFloat(332 + i * 3)
            c.move(to: CGPoint(x: 270, y: y)); c.addLine(to: CGPoint(x: 730, y: y + 4))
        }
        c.strokePath()
    }

    private static func hall(_ c: CGContext, ink: CGColor) {
        c.setStrokeColor(ink); c.setLineWidth(2.3)
        c.stroke(CGRect(x: 280, y: 213, width: 464, height: 116))
        c.stroke(CGRect(x: 474, y: 167, width: 76, height: 162))
        c.stroke(CGRect(x: 492, y: 135, width: 40, height: 33))
        c.move(to: CGPoint(x: 489, y: 134)); c.addLine(to: CGPoint(x: 512, y: 107)); c.addLine(to: CGPoint(x: 536, y: 134))
        c.move(to: CGPoint(x: 512, y: 107)); c.addLine(to: CGPoint(x: 512, y: 94))
        c.move(to: CGPoint(x: 268, y: 212)); c.addLine(to: CGPoint(x: 512, y: 179)); c.addLine(to: CGPoint(x: 756, y: 212))
        for x in stride(from: 295, through: 734, by: 29) {
            for y in [230, 273] { c.stroke(CGRect(x: x, y: y, width: 13, height: 26)) }
        }
        c.strokeEllipse(in: CGRect(x: 500, y: 143, width: 24, height: 24)); c.strokePath()
        text(c, "INDEPENDENCE HALL", x: 512, y: 358, size: 14, ink: ink)
    }

    private static func portrait(_ c: CGContext, ink: CGColor, paper: CGColor) {
        c.saveGState()
        c.setStrokeColor(ink); c.setLineWidth(1)
        c.strokeEllipse(in: CGRect(x: 325, y: 99, width: 250, height: 258))
        c.setFillColor(ink)
        c.move(to: CGPoint(x: 345, y: 347)); c.addCurve(to: CGPoint(x: 553, y: 347), control1: CGPoint(x: 355, y: 277), control2: CGPoint(x: 535, y: 277))
        c.addLine(to: CGPoint(x: 533, y: 332)); c.addLine(to: CGPoint(x: 367, y: 332)); c.fillPath()
        c.setFillColor(paper); c.fillEllipse(in: CGRect(x: 397, y: 142, width: 113, height: 151))
        // Long wavy hair framing a high forehead; etched lines rather than a photo.
        c.setStrokeColor(ink)
        for side in [-1.0, 1.0] {
            for n in 0..<16 {
                let x = 452 + CGFloat(side) * CGFloat(58 + n)
                c.move(to: CGPoint(x: x, y: 160 + CGFloat(n)))
                c.addCurve(to: CGPoint(x: x + CGFloat(side) * 8, y: 292), control1: CGPoint(x: x + CGFloat(side) * 23, y: 194), control2: CGPoint(x: x - CGFloat(side) * 13, y: 263))
            }
        }
        c.strokePath()
        c.setLineWidth(1.8)
        c.addArc(center: CGPoint(x: 453, y: 197), radius: 57, startAngle: .pi * 1.1, endAngle: .pi * 1.85, clockwise: false)
        c.move(to: CGPoint(x: 411, y: 209)); c.addQuadCurve(to: CGPoint(x: 440, y: 207), control: CGPoint(x: 424, y: 201))
        c.move(to: CGPoint(x: 467, y: 207)); c.addQuadCurve(to: CGPoint(x: 493, y: 210), control: CGPoint(x: 481, y: 202))
        c.move(to: CGPoint(x: 453, y: 211)); c.addLine(to: CGPoint(x: 445, y: 242)); c.addLine(to: CGPoint(x: 460, y: 244))
        c.move(to: CGPoint(x: 430, y: 263)); c.addQuadCurve(to: CGPoint(x: 475, y: 263), control: CGPoint(x: 451, y: 271))
        c.move(to: CGPoint(x: 402, y: 224)); c.addQuadCurve(to: CGPoint(x: 427, y: 285), control: CGPoint(x: 408, y: 270))
        c.move(to: CGPoint(x: 500, y: 224)); c.addQuadCurve(to: CGPoint(x: 477, y: 285), control: CGPoint(x: 495, y: 270))
        c.strokePath()
        for n in 0..<16 {
            let y = CGFloat(177 + n * 7)
            c.move(to: CGPoint(x: 406, y: y)); c.addLine(to: CGPoint(x: 416, y: y + 4))
        }
        c.strokePath(); c.restoreGState()
    }
}
