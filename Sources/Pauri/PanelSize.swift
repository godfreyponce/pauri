import AppKit

/// The panel's size rules. Every size here is the window's frame size.
/// `minimum` is the measured smallest `PanelView` (251 x 156) plus the Blossom logo's width,
/// an 8-line draft's height, and the title bar's top inset (plan for #37, decision 1).
enum PanelSize {
    static let key = "panelSize"
    static let `default` = CGSize(width: 520, height: 680)
    static let minimum = CGSize(width: 280, height: 280)

    /// Each side raised to `minimum`, then cut to `screen`: the screen wins when it is smaller than the minimum.
    static func clamped(_ size: CGSize, to screen: CGSize, minimum: CGSize = PanelSize.minimum) -> CGSize {
        CGSize(width: min(max(size.width, minimum.width), screen.width),
               height: min(max(size.height, minimum.height), screen.height))
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
