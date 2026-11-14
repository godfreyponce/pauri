import Foundation

/// The text selected in the front app, read when the hotkey opens Pauri.
enum SelectionGrabber {
    /// Nil for nothing selected, so a selection of only whitespace makes no chip.
    static func cleaned(_ raw: String?) -> String? {
        let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }
}
