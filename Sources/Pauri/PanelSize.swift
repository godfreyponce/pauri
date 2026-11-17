import AppKit

/// The panel's size rules. Every size here is the window's frame size.
/// `minimum` is the measured smallest `PanelView` (251 x 156) plus the Blossom logo's width,
/// an 8-line draft's height, and the title bar's top inset (plan for #37, decision 1).
enum PanelSize {
    static let key = "panelSize"
    static let `default` = CGSize(width: 520, height: 680)
    static let minimum = CGSize(width: 280, height: 280)
    static let step = CGSize(width: 52, height: 68)

    /// Each side raised to `minimum`, then cut to `screen`: the screen wins when it is smaller than the minimum.
    static func clamped(_ size: CGSize, to screen: CGSize) -> CGSize {
        CGSize(width: min(max(size.width, minimum.width), screen.width),
               height: min(max(size.height, minimum.height), screen.height))
    }

    static func stepped(_ size: CGSize, by direction: Int, screen: CGSize) -> CGSize {
        let d = CGFloat(direction)
        return clamped(CGSize(width: size.width + d * step.width, height: size.height + d * step.height), to: screen)
    }

    /// `current` at `size` with its top-left corner kept, then moved only as far as needed to lie inside `visible`.
    static func frame(_ current: NSRect, resizedTo size: CGSize, within visible: NSRect) -> NSRect {
        let x = max(min(current.minX, visible.maxX - size.width), visible.minX)
        let y = max(min(current.maxY - size.height, visible.maxY - size.height), visible.minY)
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// `1` for Cmd+ or Cmd=, `-1` for Cmd-, `nil` for any other key or modifier mix.
    static func direction(characters: String?, flags: NSEvent.ModifierFlags) -> Int? {
        guard flags.intersection(.deviceIndependentFlagsMask).subtracting([.shift, .capsLock, .numericPad]) == .command
        else { return nil }
        switch characters {
        case "=", "+": return 1
        case "-": return -1
        default: return nil
        }
    }

    /// The size saved under `key`, or `default` when none is saved or it is malformed. Not clamped.
    static func saved(in defaults: UserDefaults) -> CGSize {
        guard let saved = defaults.dictionary(forKey: key),
              let width = saved["width"] as? Double, let height = saved["height"] as? Double
        else { return `default` }
        return CGSize(width: width, height: height)
    }

    static func save(_ size: CGSize, to defaults: UserDefaults) {
        defaults.set(["width": Double(size.width), "height": Double(size.height)], forKey: key)
    }
}
