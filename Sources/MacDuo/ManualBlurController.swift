import AppKit
import Combine
import CoreImage
import ScreenCaptureKit

/// Live, neutrally blurred windows on every display. Images stay in memory.
@MainActor
final class ManualBlurController: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var isPreparing = false
    @Published private(set) var error: String?
    var onStateChange: ((Bool) -> Void)?
    private var windows: [NSWindow] = []
    private var captureTask: Task<Void, Never>?
    private var streams: [WindowBlurStream] = []
    private var views: [CGDirectDisplayID: NSImageView] = [:]
    private var readyDisplays: Set<CGDirectDisplayID> = []
    private var startupTimeout: Timer?
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
                let screens = NSScreen.screens
                guard !screens.isEmpty else { throw BlurError.displayUnavailable }
                // Put transparent windows on screen first, so SCK can exclude their IDs.
                for screen in screens { try makeWindow(on: screen) }
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                try Task.checkCancellation()
                guard generation == token else { return }
                let overlayIDs = Set(windows.map { CGWindowID($0.windowNumber) })
                let excluded = content.windows.filter { overlayIDs.contains($0.windowID) }
                // Do not start a stream unless all overlays can be excluded: avoids feedback.
                guard excluded.count == overlayIDs.count else { throw BlurError.overlayUnavailable }
                for screen in screens {
                    try Task.checkCancellation()
                    guard let id = screen.displayID,
                          let display = content.displays.first(where: { $0.displayID == id }) else {
                        throw BlurError.displayUnavailable
                    }
                    let session = try WindowBlurStream(display: display, excluding: excluded, size: screen.frame.size,
                        onFrame: { [weak self] image in
                            guard let self, generation == token, let view = views[id] else { return }
                            view.image = NSImage(cgImage: image, size: screen.frame.size)
                            view.window?.alphaValue = 1
                            readyDisplays.insert(id)
                            if readyDisplays.count == views.count, isPreparing {
                                Diagnostics.geometry.notice("live window blur ready on \(self.views.count) display(s)")
                                isPreparing = false
                                isActive = true
                                startupTimeout?.invalidate()
                                startupTimeout = nil
                            }
                        }, onError: { [weak self] message in
                            guard let self, generation == token else { return }
                            dismiss()
                            error = "Захват экрана остановлен: \(message)"
                        })
                    streams.append(session)
                    try await session.start()
                    try Task.checkCancellation()
                }
                guard generation == token else { return }
                captureTask = nil
                if isPreparing {
                    startupTimeout = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
                        MainActor.assumeIsolated {
                            guard let self, self.generation == token, self.isPreparing else { return }
                            self.dismiss()
                            self.error = "Экран не передал изображение. Попробуйте включить размытие ещё раз."
                        }
                    }
                }
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
        startupTimeout?.invalidate()
        startupTimeout = nil
        for stream in streams { stream.stop() }
        streams.removeAll()
        views.removeAll()
        readyDisplays.removeAll()
        for window in windows { window.orderOut(nil); window.close() }
        windows.removeAll()
        isActive = false
        isPreparing = false
        onStateChange?(false)
    }

    private func makeWindow(on screen: NSScreen) throws {
        guard let id = screen.displayID else { throw BlurError.displayUnavailable }
        let window = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        let view = NSImageView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.imageScaling = .scaleAxesIndependently
        window.contentView = view
        window.isReleasedWhenClosed = false
        // Non-opaque backing keeps apps behind the overlay rendering live content.
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.alphaValue = 0.004
        window.orderFrontRegardless()
        windows.append(window)
        views[id] = view
    }

    private enum BlurError: LocalizedError {
        case displayUnavailable, overlayUnavailable
        var errorDescription: String? {
            switch self {
            case .displayUnavailable: return "Экран недоступен. Попробуйте ещё раз."
            case .overlayUnavailable: return "Не удалось исключить слой размытия из захвата."
            }
        }
    }
}
