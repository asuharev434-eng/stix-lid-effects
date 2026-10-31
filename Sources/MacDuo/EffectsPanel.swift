import AppKit
import SwiftUI

struct EffectsPanel: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var controller: LidController
    @ObservedObject var manualEffect: ManualEffectController
    @ObservedObject var blur: ManualBlurController
    @ObservedObject var startup: LoginStartup
    let shortcutError: String?
    let canUseManualEffect: Bool
    let onToggleEffect: () -> Void
    let onAdvanced: () -> Void
    @State private var permission = CGPreflightScreenCaptureAccess()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "laptopcomputer").font(.system(size: 27)).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("STIX Lid Effects").font(.title3.bold())
                    Text(controller.isSensorAvailable ? String(format: "Угол крышки %.0f°", controller.currentAngle) : "Датчик крышки недоступен")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("ЭФФЕКТ КРЫШКИ").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Picker("Эффект", selection: $preferences.effectStyle) {
                    ForEach(EffectStyle.allCases) { effect in
                        Label(effect.title, systemImage: effect.symbol).tag(effect)
                    }
                }.labelsHidden().frame(maxWidth: .infinity)
                HStack {
                    Toggle("Анимация крышки", isOn: $preferences.isEnabled).toggleStyle(.switch).controlSize(.small)
                    Spacer()
                    Button { controller.runPreview() } label: { Image(systemName: "play.fill"); Text("Показать") }
                        .disabled(!permission || !preferences.isEnabled || blur.isActive || blur.isPreparing || manualEffect.isActive || !controller.isSensorAvailable)
                }
            }
            Divider()
            Button {
                blur.toggle()
            } label: {
                HStack {
                    Image(systemName: "drop.halffull")
                    Text(blur.isPreparing ? "Подготовка размытия…" : blur.isActive ? "Снять размытие" : "Размыть все экраны")
                    Spacer()
                    Text("⌥B").font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
                }.padding(.vertical, 5)
            }.buttonStyle(.bordered).disabled(manualEffect.isActive)
            Button(action: onToggleEffect) {
                HStack {
                    Image(systemName: "moon.fill")
                    Text(manualEffect.isActive ? "Вернуть изображение" : "Эффект и чёрный экран")
                    Spacer()
                    Text("⌥M").font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
                }.padding(.vertical, 5)
            }.buttonStyle(.bordered).disabled(!canUseManualEffect)
            Text("⌥M проигрывает выбранный эффект и оставляет экран чёрным до повторного ⌥M.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("Живое размытие окон. Повторное ⌥B возвращает резкость. Это не блокировка Mac.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Toggle("Запускать при входе", isOn: Binding(get: { startup.enabled }, set: { startup.setEnabled($0) }))
                .toggleStyle(.switch).controlSize(.small)
            if !permission {
                Button("Разрешить запись экрана…") {
                    CGRequestScreenCaptureAccess()
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") { NSWorkspace.shared.open(url) }
                }
            }
            if let message = manualEffect.error ?? blur.error ?? shortcutError ?? startup.message {
                Text(message).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            HStack {
                Button("Настройки…", action: onAdvanced)
                Spacer()
                Button("Выйти") { NSApp.terminate(nil) }
            }.controlSize(.small)
            Text("На основе Mac Duo · Makito · Apache 2.0").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(width: 360)
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
    }
    private func refresh() { permission = CGPreflightScreenCaptureAccess(); startup.refresh() }
}

@MainActor
final class EffectsWindowController {
    private let window: NSWindow
    private var advanced: NSWindow?
    init(preferences: Preferences, controller: LidController, blur: ManualBlurController, manualEffect: ManualEffectController, startup: LoginStartup, shortcutError: String?, canUseManualEffect: Bool, onToggleEffect: @escaping () -> Void) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 480), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "STIX Lid Effects"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: EffectsPanel(preferences: preferences, controller: controller, manualEffect: manualEffect, blur: blur, startup: startup, shortcutError: shortcutError, canUseManualEffect: canUseManualEffect, onToggleEffect: onToggleEffect, onAdvanced: { [weak self] in
            self?.showAdvanced(preferences: preferences, controller: controller)
        }))
        window.center()
    }
    func show() { NSApp.activate(); window.makeKeyAndOrderFront(nil) }
    private func showAdvanced(preferences: Preferences, controller: LidController) {
        if advanced == nil {
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 640), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            panel.title = "Дополнительные настройки"
            panel.contentView = NSHostingView(rootView: SettingsView(preferences: preferences, controller: controller, onQuit: { NSApp.terminate(nil) }))
            panel.isReleasedWhenClosed = false
            panel.center()
            advanced = panel
        }
        advanced?.makeKeyAndOrderFront(nil)
    }
}
