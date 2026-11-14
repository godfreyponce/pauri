import AppKit
import Carbon.HIToolbox

/// A Carbon virtual key code (`kVK_*`) plus a Carbon modifier mask (`cmdKey`, `shiftKey`, ...).
struct Shortcut: Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32

    /// Cmd+Shift+Space. Option+Space is banned by #1; Ctrl+Space and Cmd+Space are macOS defaults.
    static let `default` = Shortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | shiftKey))

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// A key press as a shortcut; nil without Command, Option, or Control, which would swallow typing.
    init?(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        guard !flags.isDisjoint(with: [.command, .option, .control]) else { return nil }
        let carbon: [(NSEvent.ModifierFlags, Int)] =
            [(.command, cmdKey), (.option, optionKey), (.control, controlKey), (.shift, shiftKey)]
        self.init(
            keyCode: UInt32(keyCode),
            modifiers: carbon.reduce(0) { flags.contains($1.0) ? $0 | UInt32($1.1) : $0 })
    }

    /// Modifier symbols in macOS menu order, then the key: `⌥Space`, `⌃⌥⇧⌘F5`.
    var displayName: String {
        let symbols: [(Int, String)] = [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
        return symbols.filter { modifiers & UInt32($0.0) != 0 }.map(\.1).joined() + keyName
    }

    private static let keyNames: [Int: String] = {
        var names = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
            kVK_Escape: "⎋", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        ]
        let functionKeys = [
            kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
            kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
        ]
        for (index, code) in functionKeys.enumerated() { names[code] = "F\(index + 1)" }
        return names
    }()

    private var keyName: String {
        if let name = Self.keyNames[Int(keyCode)] { return name }
        let typed = Self.typedCharacter(keyCode: UInt16(keyCode)).uppercased()
        return typed.isEmpty ? "Key \(keyCode)" : typed
    }

    /// What the key types on the current keyboard layout, with no modifiers held.
    private static func typedCharacter(keyCode: UInt16) -> String {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return "" }
        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = data.withUnsafeBytes { layout in
            UCKeyTranslate(
                layout.bindMemory(to: UCKeyboardLayout.self).baseAddress, keyCode, UInt16(kUCKeyActionDisplay),
                0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeys,
                chars.count, &length, &chars)
        }
        return status == noErr ? String(utf16CodeUnits: chars, count: length) : ""
    }

    private static let defaultsKey = "hotKey"

    /// The shortcut saved under `hotKey`, or `.default` when none is saved or it is malformed.
    static func saved(in defaults: UserDefaults) -> Shortcut {
        guard let saved = defaults.dictionary(forKey: defaultsKey),
              let keyCode = saved["keyCode"] as? Int, let modifiers = saved["modifiers"] as? Int,
              let code = UInt32(exactly: keyCode), let mask = UInt32(exactly: modifiers)
        else { return .default }
        return Shortcut(keyCode: code, modifiers: mask)
    }

    func save(to defaults: UserDefaults) {
        defaults.set(["keyCode": Int(keyCode), "modifiers": Int(modifiers)], forKey: Self.defaultsKey)
    }
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
