import AppKit
import Carbon

/// Carbon reserves Option+B and Option+M; no key logging or Accessibility access.
@MainActor
final class GlobalShortcut {
    private var handler: EventHandlerRef?
    private var hotKeys: [EventHotKeyRef] = []
    private var pressedIDs: Set<UInt32> = []
    private(set) var effectAvailable = false
    var action: (() -> Void)?
    var effectAction: (() -> Void)?
    private(set) var error: String?

    func register() {
        var types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard status == noErr, identifier.signature == 0x53544958, (identifier.id == 1 || identifier.id == 2) else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated {
                let owner = Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue()
                if GetEventKind(event) == UInt32(kEventHotKeyReleased) {
                    owner.pressedIDs.remove(identifier.id)
                    return
                }
                guard owner.pressedIDs.insert(identifier.id).inserted else { return }
                if identifier.id == 1 { owner.action?() }
                else { owner.effectAction?() }
            }
            return noErr
        }, 2, &types, context, &handler)
        guard installed == noErr else {
            error = "Не удалось подключить горячую клавишу (\(installed))."
            return
        }
        for (key, id, label) in [(kVK_ANSI_B, UInt32(1), "⌥B"), (kVK_ANSI_M, UInt32(2), "⌥M")] {
            var reference: EventHotKeyRef?
            let result = RegisterEventHotKey(UInt32(key), UInt32(optionKey), EventHotKeyID(signature: 0x53544958, id: id), GetApplicationEventTarget(), 0, &reference)
            if result == noErr, let reference {
                hotKeys.append(reference)
                if id == 2 { effectAvailable = true }
            }
            else { error = [error, "\(label) занято другим приложением (\(result))."].compactMap { $0 }.joined(separator: "\n") }
        }
    }

    func stop() {
        for hotKey in hotKeys { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKeys.removeAll()
        pressedIDs.removeAll()
        effectAvailable = false
        handler = nil
    }
}
