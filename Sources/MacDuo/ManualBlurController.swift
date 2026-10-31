import AppKit
import Combine
import CoreImage
import ScreenCaptureKit

/// A held blurred frame on every screen. Images live only in memory.
@MainActor
final class ManualBlurController: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var isPreparing = false
    @Published private(set) var error: String?
    var onStateChange: ((Bool) -> Void)?
    private var windows: [NSWindow] = []
    private var captureTask: Task<Void, Never>?
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var observers: [NSObjectProtocol] = []
    private var sleepObserver: NSObjectProtocol?
    private var generation = 0

    init() {
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss() }
        })
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss() }
        }
    }

    func toggle() {
        if isActive || isPreparing { dismiss(); return }
        guard CGPreflightScreenCaptureAccess() else {
            error = "Разрешите запись экрана для STIX Lid Effects в Системных настройках."
            return
        }
        error = nil
        generation += 1
        let token = generation
        isPreparing = true
        onStateChange?(true)
        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                let own = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
                let screens = NSScreen.screens
                var pictures: [(NSScreen, CGImage)] = []
                for screen in screens {
                    try Task.checkCancellation()
                    guard let display = content.displays.first(where: { $0.displayID == screen.displayID }) else {
                        throw BlurError.displayUnavailable
                    }
                    let filter = SCContentFilter(display: display, excludingApplications: own, exceptingWindows: [])
                    let configuration = SCStreamConfiguration()
                    // Blur needs no retina-sized source. One capture, no idle rendering.
                    configuration.width = max(1, Int(screen.frame.width))
                    configuration.height = max(1, Int(screen.frame.height))
                    configuration.showsCursor = false
                    let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
                    try Task.checkCancellation()
                    let source = CIImage(cgImage: image)
                    let blurred = source.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 55.0]).cropped(to: source.extent)
                    guard let result = context.createCGImage(blurred, from: source.extent) else { throw BlurError.renderFailed }
                    pictures.append((screen, result))
                }
                guard !pictures.isEmpty else { throw BlurError.displayUnavailable }
                try Task.checkCancellation()
                guard generation == token else { return }
                for (screen, image) in pictures { show(image, on: screen) }
                isPreparing = false
                isActive = true
                captureTask = nil
            } catch {
                guard generation == token else { return }
                dismiss()
                if !(error is CancellationError) {
                    self.error = "Не удалось размыть экран: \(error.localizedDescription)"
                    Diagnostics.geometry.error("manual blur failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    func dismiss() {
        generation += 1
        captureTask?.cancel()
        captureTask = nil
        for window in windows { window.orderOut(nil); window.close() }
        windows.removeAll()
        isActive = false
        isPreparing = false
        onStateChange?(false)
    }

    private func show(_ image: CGImage, on screen: NSScreen) {
        let window = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        let view = NSImageView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.image = NSImage(cgImage: image, size: screen.frame.size)
        view.imageScaling = .scaleAxesIndependently
        window.contentView = view
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.orderFrontRegardless()
        windows.append(window)
    }

    private enum BlurError: LocalizedError {
        case displayUnavailable, renderFailed
        var errorDescription: String? {
            switch self {
            case .displayUnavailable: return "Экран недоступен. Попробуйте ещё раз."
            case .renderFailed: return "Не удалось обработать изображение."
            }
        }
    }
}
