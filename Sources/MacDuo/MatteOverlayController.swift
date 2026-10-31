import AppKit
import Combine

/// A click-through coating beneath all manual effects. The WindowServer composites it normally.
@MainActor
final class MatteOverlayController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var error: String?
    @Published var intensity: Double {
        didSet {
            let clean = MatteTexture.intensity(intensity)
            if clean != intensity { intensity = clean }
            defaults.set(clean, forKey: "matteIntensity")
            for window in windows { window.alphaValue = clean }
        }
    }
    private let defaults: UserDefaults
    private var windows: [NSWindow] = []
    private var observer: NSObjectProtocol?
    private var layout: [Layout] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.object(forKey: "matteIntensity") as? Double ?? 0.6
        intensity = MatteTexture.intensity(saved)
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                          object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isEnabled else { return }
                let current = NSScreen.screens.map { Layout(displayID: $0.displayID, frame: $0.frame) }
                if current != self.layout { self.rebuild() }
            }
        }
    }
    func restore() {
        if defaults.bool(forKey: "matteEnabled") { enable() }
    }
    func toggle() {
        if isEnabled {
            stop()
            defaults.set(false, forKey: "matteEnabled")
        } else { enable() }
    }
    /// Termination drops windows, but retains the user's saved choice for the next launch.
    func stop() {
        for window in windows { window.orderOut(nil); window.close() }
        windows.removeAll()
        isEnabled = false
    }
    private func enable() {
        error = nil
        guard rebuild() else { return }
        isEnabled = true
        defaults.set(true, forKey: "matteEnabled")
    }
    @discardableResult
    private func rebuild() -> Bool {
        var replacement: [NSWindow] = []
        for screen in NSScreen.screens {
            let tileSize = Int((64 * screen.backingScaleFactor).rounded())
            guard let tile = MatteTexture.makeTile(pixelSize: tileSize) else {
                for window in replacement { window.orderOut(nil); window.close() }
                error = "Не удалось подготовить матовую текстуру."
                return false
            }
            let view = MatteSurfaceView(frame: NSRect(origin: .zero, size: screen.frame.size), tile: tile)
            view.autoresizingMask = [.width, .height]
            let window = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = view
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) - 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            window.alphaValue = intensity
            window.orderFrontRegardless()
            replacement.append(window)
        }
        for window in windows { window.orderOut(nil); window.close() }
        windows = replacement
        layout = NSScreen.screens.map { Layout(displayID: $0.displayID, frame: $0.frame) }
        return true
    }
}

private final class MatteSurfaceView: NSView {
    private let pattern: NSColor
    override var isOpaque: Bool { false }
    init(frame: NSRect, tile: CGImage) {
        pattern = NSColor(patternImage: NSImage(cgImage: tile, size: NSSize(width: 64, height: 64)))
        super.init(frame: frame)
        wantsLayer = true
        layer?.isOpaque = false
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill(using: .copy)
        pattern.setFill()
        dirtyRect.fill(using: .sourceOver)
    }
}
