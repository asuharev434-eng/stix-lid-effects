import AppKit
import CoreImage

/// Immutable cursor image, stamped into the source before Gaussian blur.
struct BlurCursorStamp {
    let image: CGImage
    let rect: CGRect

    @MainActor
    static func capture(on screen: NSScreen) -> BlurCursorStamp? {
        guard let location = CGEvent(source: nil)?.location,
              let primary = NSScreen.screens.first(where: { $0.displayID == CGMainDisplayID() }) else { return nil }
        let point = CGPoint(x: location.x, y: primary.frame.maxY - location.y)
        guard screen.frame.contains(point) else { return nil }
        let cursor = NSCursor.current
        var imageRect = CGRect(origin: .zero, size: cursor.image.size)
        guard let image = cursor.image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil) else { return nil }
        let size = cursor.image.size
        let rect = CGRect(x: point.x - screen.frame.minX - cursor.hotSpot.x,
                          y: point.y - screen.frame.minY - (size.height - cursor.hotSpot.y),
                          width: size.width, height: size.height)
        return BlurCursorStamp(image: image, rect: rect)
    }
    func composite(over source: CIImage) -> CIImage {
        let cursor = CIImage(cgImage: image)
            .transformed(by: CGAffineTransform(scaleX: rect.width / CGFloat(image.width), y: rect.height / CGFloat(image.height)))
            .transformed(by: CGAffineTransform(translationX: rect.minX, y: rect.minY))
        return cursor.composited(over: source).cropped(to: source.extent)
    }
}
