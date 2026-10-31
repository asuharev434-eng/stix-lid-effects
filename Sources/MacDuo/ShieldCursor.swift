import AppKit

/// A real transparent cursor image, also used by overlay cursor rectangles.
@MainActor
enum ShieldCursor {
    static let invisible: NSCursor = {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { _ in true }
        return NSCursor(image: image, hotSpot: .zero)
    }()
}

final class PointerShieldView: NSView {
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: ShieldCursor.invisible)
    }
    override func cursorUpdate(with event: NSEvent) { ShieldCursor.invisible.set() }
}

final class PointerShieldImageView: NSImageView {
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: ShieldCursor.invisible)
    }
    override func cursorUpdate(with event: NSEvent) { ShieldCursor.invisible.set() }
}
