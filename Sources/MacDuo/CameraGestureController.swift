import AppKit
import AVFoundation
import Combine

@MainActor
final class CameraGestureController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var status = "Камера выключена"
    @Published private(set) var progress: Double = 0
    @Published private(set) var error: String?
    var onGesture: ((HandGesture) -> Void)?
    private var capture: CameraGestureCapture?
    private var generation = 0
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.pause() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isEnabled else { return }
                self.startAuthorized()
            }
        })
    }
    func restore() {
        if UserDefaults.standard.bool(forKey: "cameraGesturesEnabled"), AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            setEnabled(true)
        }
    }
    func setEnabled(_ enabled: Bool) {
        if !enabled { stop(); return }
        guard !isEnabled else { return }
        isEnabled = true
        error = nil
        progress = 0
        generation += 1
        let token = generation
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: startAuthorized()
        case .notDetermined:
            status = "Ожидание разрешения на камеру…"
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self, self.generation == token, self.isEnabled else { return }
                    if granted { self.startAuthorized() }
                    else { self.fail("Разрешите доступ к камере в Системных настройках.") }
                }
            }
        default: fail("Разрешите доступ к камере в Системных настройках.")
        }
    }
    func stop() {
        pause()
        isEnabled = false
        UserDefaults.standard.set(false, forKey: "cameraGesturesEnabled")
        status = "Камера выключена"
    }
    func shutdown() { pause() }
    private func pause() {
        generation += 1
        capture?.stop()
        capture = nil
        progress = 0
        if isEnabled { status = "Камера приостановлена" }
    }
    private func startAuthorized() {
        pause()
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            fail("Доступ к камере отозван.")
            return
        }
        status = "Запуск камеры…"
        error = nil
        UserDefaults.standard.set(true, forKey: "cameraGesturesEnabled")
        let token = generation
        let worker = CameraGestureCapture(onSample: { [weak self] update in
            guard let self, self.generation == token, self.isEnabled else { return }
            self.progress = update.progress
            if update.latched { self.status = "Жест принят. Уберите руку из кадра." }
            else if let gesture = update.gesture { self.status = "\(gesture.title): удерживайте…" }
            else if update.handCount > 1 { self.status = "Покажите только одну руку" }
            else { self.status = "Покажите щипок или раскрытую ладонь" }
            if let action = update.action { self.onGesture?(action) }
        }, onError: { [weak self] message in
            guard let self, self.generation == token else { return }
            self.fail(message)
        })
        capture = worker
        worker.start()
    }
    private func fail(_ message: String) {
        stop()
        error = message
        status = message
        Diagnostics.geometry.error("camera gestures stopped: \(message, privacy: .public)")
    }
}
