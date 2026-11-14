import AppKit
import ApplicationServices

/// The text selected in the front app, read when the hotkey opens Pauri.
enum SelectionGrabber {
    static var isAllowed: Bool { AXIsProcessTrusted() }

    /// The key string, because `kAXTrustedCheckOptionPrompt` is a global `var` that Swift 6 rejects.
    static func requestAccess() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// Asks the front app's focused element through the Accessibility API; nil without access.
    @MainActor
    static func selectedText() -> String? {
        guard isAllowed, let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        let app = AXUIElementCreateApplication(pid)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        var text: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused as! AXUIElement, kAXSelectedTextAttribute as CFString, &text) == .success
        else { return nil }
        return cleaned(text as? String)
    }

    /// Nil for nothing selected, so a selection of only whitespace makes no chip.
    static func cleaned(_ raw: String?) -> String? {
        let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }
}
