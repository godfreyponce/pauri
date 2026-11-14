import AppKit
import Carbon.HIToolbox
import Testing
@testable import Pauri

@Test func defaultShortcutIsNotOptionSpace() {
    let optionSpace = Shortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))
    #expect(Shortcut.default != optionSpace)
}

private let optionSpace = Shortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))

@Test func optionSpaceCanBeRecorded() {
    #expect(Shortcut(keyCode: UInt16(kVK_Space), flags: [.option]) == optionSpace)
}

@Test func shortcutNeedsCommandOptionOrControl() {
    #expect(Shortcut(keyCode: UInt16(kVK_Space), flags: []) == nil)
    #expect(Shortcut(keyCode: UInt16(kVK_ANSI_K), flags: [.shift]) == nil)
    #expect(Shortcut(keyCode: UInt16(kVK_ANSI_K), flags: [.control, .shift])
        == Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(controlKey | shiftKey)))
}

@Test func recordingIgnoresOtherFlags() {
    #expect(Shortcut(keyCode: UInt16(kVK_Space), flags: [.option, .capsLock, .function, .numericPad]) == optionSpace)
}

@Test func shortcutNamesUseMacSymbolOrder() {
    #expect(Shortcut.default.displayName == "⇧⌘Space")
    #expect(optionSpace.displayName == "⌥Space")
    #expect(Shortcut(keyCode: UInt32(kVK_F5), modifiers: UInt32(controlKey | optionKey | shiftKey | cmdKey)).displayName == "⌃⌥⇧⌘F5")
}

@Test func nothingSavedGivesDefault() {
    let name = "PauriTests-\(UUID().uuidString)"
    defer { UserDefaults().removePersistentDomain(forName: name) }
    #expect(Shortcut.saved(in: UserDefaults(suiteName: name)!) == .default)
}

@Test func savedShortcutSurvivesRelaunch() {
    let name = "PauriTests-\(UUID().uuidString)"
    defer { UserDefaults().removePersistentDomain(forName: name) }
    optionSpace.save(to: UserDefaults(suiteName: name)!)
    #expect(Shortcut.saved(in: UserDefaults(suiteName: name)!) == optionSpace)
}
