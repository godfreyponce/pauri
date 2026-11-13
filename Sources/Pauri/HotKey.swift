import Carbon.HIToolbox

/// A Carbon virtual key code (`kVK_*`) plus a Carbon modifier mask (`cmdKey`, `shiftKey`, ...).
struct Shortcut: Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32

    /// Cmd+Shift+Space. Option+Space is banned by #1; Ctrl+Space and Cmd+Space are macOS defaults.
    static let `default` = Shortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | shiftKey))
}

/// A system-wide hotkey, registered through Carbon for the app's lifetime.
@MainActor
final class HotKey {
    fileprivate let action: @MainActor () -> Void
    private var handler: EventHandlerRef?
    private var ref: EventHotKeyRef?

    init(shortcut: Shortcut, action: @escaping @MainActor () -> Void) {
        self.action = action
        let target = GetApplicationEventTarget()
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var status = InstallEventHandler(
            target, hotKeyPressed, 1, &pressed, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else {
            NSLog("Pauri: hotkey registration failed, OSStatus %d", status)
            return
        }
        let id = EventHotKeyID(signature: "PAUR".utf8.reduce(0) { $0 << 8 | FourCharCode($1) }, id: 1)
        status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id, target, 0, &ref)
        guard status == noErr else {
            NSLog("Pauri: hotkey registration failed, OSStatus %d", status)
            return
        }
    }
}

private func hotKeyPressed(_: EventHandlerCallRef?, _: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
    // Carbon delivers application-target events on the main thread.
    MainActor.assumeIsolated { hotKey.action() }
    return noErr
}
