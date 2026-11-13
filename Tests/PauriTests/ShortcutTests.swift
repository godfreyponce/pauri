import Carbon.HIToolbox
import Testing
@testable import Pauri

@Test func defaultShortcutIsNotOptionSpace() {
    let optionSpace = Shortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))
    #expect(Shortcut.default != optionSpace)
}
