import AppKit
import Carbon

/// Carbon reserves only Option+B; no key logging or Accessibility access.
@MainActor
final class GlobalShortcut {
    private var handler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    var action: (() -> Void)?
    private(set) var error: String?

    func register() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard status == noErr, identifier.signature == 0x53544958, identifier.id == 1 else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated {
                Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue().action?()
            }
            return noErr
        }, 1, &type, context, &handler)
        guard installed == noErr else {
            error = "Не удалось подключить горячую клавишу (\(installed))."
            return
        }
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_B), UInt32(optionKey), EventHotKeyID(signature: 0x53544958, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        if result != noErr {
            error = "⌥B занято другим приложением (\(result))."
        }
    }

    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
    }
}
