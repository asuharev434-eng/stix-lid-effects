import AppKit
import ApplicationServices
import CoreGraphics

enum InputShieldMode {
    case blackout, blur
    var releaseKey: Int64 { self == .blackout ? 46 : 11 } // physical M / B
}

enum BlackoutInputPolicy {
    static func allows(type: CGEventType, keyCode: Int64, flags: CGEventFlags,
                       mode: InputShieldMode = .blackout) -> Bool {
        if type == .flagsChanged { return keyCode == 58 || keyCode == 61 }
        if type == .keyUp { return keyCode == mode.releaseKey }
        guard type == .keyDown, keyCode == mode.releaseKey else { return false }
        let modifiers: CGEventFlags = [.maskAlternate, .maskCommand, .maskControl, .maskShift, .maskSecondaryFn]
        return flags.intersection(modifiers) == .maskAlternate
    }
}

/// Scoped input suppression, never recording keystrokes. The mode's exit shortcut passes through.
@MainActor
final class BlackoutInputGuard {
    var onFailure: ((String) -> Void)?
    private(set) var error: String?
    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var mode: InputShieldMode?
    private var cursorHidden = false
    private var failurePending = false
    private var generation = 0

    func activate(mode: InputShieldMode) -> Bool {
        stop()
        error = nil
        guard AXIsProcessTrusted() else {
            error = "Разрешите STIX Lid Effects в Универсальном доступе для блокировки ввода."
            return false
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                         options: .defaultTap, eventsOfInterest: CGEventMask.max,
                                         callback: { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            return MainActor.assumeIsolated {
                let owner = Unmanaged<BlackoutInputGuard>.fromOpaque(info).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    owner.failOpen()
                    return Unmanaged.passUnretained(event)
                }
                guard let mode = owner.mode else { return Unmanaged.passUnretained(event) }
                let key = (type == .keyDown || type == .keyUp || type == .flagsChanged)
                    ? event.getIntegerValueField(.keyboardEventKeycode) : -1
                return BlackoutInputPolicy.allows(type: type, keyCode: key, flags: event.flags, mode: mode)
                    ? Unmanaged.passUnretained(event) : nil
            }
        }, userInfo: context), let runSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            error = "macOS не разрешила блокировку ввода. Проверьте Универсальный доступ."
            return false
        }
        port = tap
        source = runSource
        self.mode = mode
        CFRunLoopAddSource(CFRunLoopGetMain(), runSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        guard CGDisplayHideCursor(CGMainDisplayID()) == .success else {
            stop()
            error = "Не удалось скрыть указатель. Эффект отменён."
            return false
        }
        cursorHidden = true
        return true
    }
    func stop() {
        generation += 1
        mode = nil
        if let port { CGEvent.tapEnable(tap: port, enable: false); CFMachPortInvalidate(port) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil
        port = nil
        if cursorHidden { CGDisplayShowCursor(CGMainDisplayID()); cursorHidden = false }
        failurePending = false
    }
    private func failOpen() {
        guard !failurePending else { return }
        failurePending = true
        let ticket = generation
        Task { @MainActor [weak self] in
            guard let self, self.generation == ticket else { return }
            self.stop()
            self.onFailure?("macOS остановила блокировку ввода. Управление восстановлено.")
        }
    }
}
