import AppKit
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let blur = ManualBlurController()
    private let manualEffect = ManualEffectController()
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
        blur.onStateChange = { [weak self] _ in self?.updateManualSuppression() }
        manualEffect.onStateChange = { [weak self] in self?.updateManualSuppression() }
        shortcut.action = { [weak self] in
            guard let self, !self.manualEffect.isActive else { return }
            self.blur.toggle()
        }
        shortcut.effectAction = { [weak self] in self?.toggleManualEffect() }
        shortcut.register()
        effectsWindow = EffectsWindowController(preferences: preferences, controller: controller, blur: blur, manualEffect: manualEffect, startup: startup, shortcutError: shortcut.error, canUseManualEffect: shortcut.effectAvailable, onToggleEffect: { [weak self] in self?.toggleManualEffect() })
        statusItemController?.onShowPanel = { [weak self] in self?.effectsWindow?.show() }
        controller.start()
        if !UserDefaults.standard.bool(forKey: "didConfigureStartup") {
            startup.setEnabled(true)
            UserDefaults.standard.set(true, forKey: "didConfigureStartup")
        }
        if !CommandLine.arguments.contains("--background") { effectsWindow?.show() }
    }

    private func updateManualSuppression() {
        controller?.manuallySuppressed = blur.isActive || blur.isPreparing || manualEffect.isActive
    }
    private func toggleManualEffect() {
        guard shortcut.effectAvailable else { return }
        if !manualEffect.isActive { blur.dismiss() }
        manualEffect.toggle(preferences: Preferences.shared)
    }

    func applicationWillTerminate(_ notification: Notification) {
        blur.dismiss()
        manualEffect.dismiss()
        shortcut.stop()
        controller?.stop()
    }
}
