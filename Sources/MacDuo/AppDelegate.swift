import AppKit
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let blur = ManualBlurController()
    private let shortcut = GlobalShortcut()
    private let startup = LoginStartup()
    private var effectsWindow: EffectsWindowController?
    private var controller: LidController?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Diagnostics.geometry.notice("launched, screen recording granted: \(CGPreflightScreenCaptureAccess())")
        let preferences = Preferences.shared
        let controller = LidController(preferences: preferences)
        self.controller = controller
        statusItemController = StatusItemController(controller: controller, preferences: preferences)
        blur.onStateChange = { [weak controller] active in controller?.manuallySuppressed = active }
        shortcut.action = { [weak self] in self?.blur.toggle() }
        shortcut.register()
        effectsWindow = EffectsWindowController(preferences: preferences, controller: controller, blur: blur, startup: startup, shortcutError: shortcut.error)
        statusItemController?.onShowPanel = { [weak self] in self?.effectsWindow?.show() }
        controller.start()
        if !UserDefaults.standard.bool(forKey: "didConfigureStartup") {
            startup.setEnabled(true)
            UserDefaults.standard.set(true, forKey: "didConfigureStartup")
        }
        if !CommandLine.arguments.contains("--background") { effectsWindow?.show() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        blur.dismiss()
        shortcut.stop()
        controller?.stop()
    }
}
