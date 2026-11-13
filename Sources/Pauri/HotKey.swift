import Carbon.HIToolbox

/// A Carbon virtual key code (`kVK_*`) plus a Carbon modifier mask (`cmdKey`, `shiftKey`, ...).
struct Shortcut: Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32

    /// Cmd+Shift+Space. Option+Space is banned by #1; Ctrl+Space and Cmd+Space are macOS defaults.
    static let `default` = Shortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | shiftKey))
}
