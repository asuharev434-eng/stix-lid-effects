import AppKit
import Combine
import QuartzCore
import ScreenCaptureKit

/// Plays the selected GPU effect, then replaces it with idle black windows.
@MainActor
final class ManualEffectController: ObservableObject {
    @Published private(set) var playback = ManualEffectPlayback()
    @Published private(set) var error: String?
    var isActive: Bool { playback.isActive }
    var onStateChange: (() -> Void)?

    private struct Target {
        let screen: NSScreen
        let overlay: DepthOverlay
    }
    private var targets: [Target] = []
    private var blackWindows: [NSWindow] = []
    private var captureTask: Task<Void, Never>?
    private var timer: Timer?
    private var token = 0
    private var tuning = DepthTuning()
    private var duration: TimeInterval = 1.6
    private var observers: [NSObjectProtocol] = []
    private var sleepObserver: NSObjectProtocol?

    init() {
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isActive else { return }
                self.holdBlack()
            }
        })
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isActive else { return }
                self.holdBlack()
            }
        }
    }

    func toggle(preferences: Preferences) {
        guard !isActive else { dismiss(); return }
        guard CGPreflightScreenCaptureAccess() else {
            error = "Разрешите запись экрана для анимации по ⌥M."
            return
        }
        _ = playback.toggle()
        error = nil
        token += 1
        let run = token
        duration = preferences.effectStyle == .shatter ? 3.0 : 1.6
        tuning = DepthTuning(effectStyle: preferences.effectStyle, isManualBlackout: true,
                            viewingDistance: preferences.viewingDistance, recession: preferences.recession,
                            blurEvenness: preferences.blurEvenness, dimReach: preferences.dimReach,
                            maxBlurRadius: preferences.maxBlurRadius, maxDim: preferences.maxDim)
        onStateChange?()
        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                try Task.checkCancellation()
                guard token == run else { return }
                let overlayIDs = Set(NSApp.windows.compactMap { $0 is OverlayWindow ? CGWindowID($0.windowNumber) : nil })
                let excluded = content.windows.filter { overlayIDs.contains($0.windowID) }
                var images: [(NSScreen, CGImage)] = []
                for screen in NSScreen.screens {
                    guard let display = content.displays.first(where: { $0.displayID == screen.displayID }) else {
                        throw PlaybackError.displayUnavailable
                    }
                    let config = SCStreamConfiguration()
                    config.width = max(1, Int(screen.frame.width * screen.backingScaleFactor))
                    config.height = max(1, Int(screen.frame.height * screen.backingScaleFactor))
                    config.showsCursor = false
                    config.colorSpaceName = CGColorSpace.sRGB
                    let filter = SCContentFilter(display: display, excludingWindows: excluded)
                    let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                    try Task.checkCancellation()
                    guard token == run else { return }
                    images.append((screen, image))
                }
                guard !images.isEmpty else { throw PlaybackError.displayUnavailable }
                for (screen, image) in images {
                    let overlay = DepthOverlay()
                    guard overlay.warmUp() else { throw PlaybackError.rendererUnavailable }
                    targets.append(Target(screen: screen, overlay: overlay))
                    overlay.show(image: image, on: screen, startAngle: 110, tuning: tuning,
                                 fadeIn: 0, allowExternalDisplay: true)
                }
                let deadline = CACurrentMediaTime() + 5
                while !targets.allSatisfy({ $0.overlay.isPictureReady }) {
                    try await Task.sleep(nanoseconds: 16_000_000)
                    try Task.checkCancellation()
                    guard token == run else { return }
                    guard CACurrentMediaTime() < deadline else { throw PlaybackError.rendererUnavailable }
                }
                guard token == run else { return }
                playback.start(at: CACurrentMediaTime())
                let clock = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated { self?.step() }
                }
                RunLoop.main.add(clock, forMode: .common)
                timer = clock
                captureTask = nil
                Diagnostics.geometry.notice("manual effect started, style \(self.tuning.effectStyle.rawValue)")
            } catch {
                guard token == run else { return }
                dismiss()
                if !(error is CancellationError) {
                    self.error = "Не удалось запустить эффект: \(error.localizedDescription)"
                    Diagnostics.geometry.error("manual effect failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func step() {
        let progress = playback.progress(at: CACurrentMediaTime(), duration: duration)
        if playback.phase == .black { holdBlack(); return }
        for target in targets {
            target.overlay.update(progress: progress, currentAngle: 110 - 100 * progress, tuning: tuning)
        }
    }

    /// No captures, timers or GPU work remain while the screen is black.
    private func holdBlack() {
        token += 1
        captureTask?.cancel()
        captureTask = nil
        timer?.invalidate()
        timer = nil
        var replacements: [NSWindow] = []
        for screen in NSScreen.screens {
            let window = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            // Consume clicks while black, so hidden controls cannot be clicked.
            window.ignoresMouseEvents = false
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 2)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            window.orderFrontRegardless()
            replacements.append(window)
        }
        clearTargets()
        for window in blackWindows { window.orderOut(nil); window.close() }
        blackWindows = replacements
        playback.holdBlack()
        onStateChange?()
        Diagnostics.geometry.notice("manual effect holding black until Option+M")
    }

    func dismiss() {
        token += 1
        captureTask?.cancel()
        captureTask = nil
        timer?.invalidate()
        timer = nil
        clearTargets()
        for window in blackWindows { window.orderOut(nil); window.close() }
        blackWindows.removeAll()
        playback.cancel()
        onStateChange?()
    }
    private func clearTargets() {
        for target in targets { target.overlay.shutdown() }
        targets.removeAll()
    }

    private enum PlaybackError: LocalizedError {
        case displayUnavailable, rendererUnavailable
        var errorDescription: String? {
            switch self {
            case .displayUnavailable: return "Экран недоступен."
            case .rendererUnavailable: return "Не удалось подготовить GPU-анимацию."
            }
        }
    }
}
