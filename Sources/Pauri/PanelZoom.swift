import AppKit

/// The panel content's zoom, as a whole-number percent of the content's size.
/// `minimumFrame` keeps the content's room at least `PanelSize.minimum` (plan for #38, decision 3).
enum PanelZoom {
    static let key = "panelZoom"
    static let `default` = 100
    static let range = 80...200
    static let step = 10

    enum Command { case zoomIn, zoomOut, reset }

    /// `.zoomIn` for Cmd+ or Cmd=, `.zoomOut` for Cmd-, `.reset` for Cmd+0, `nil` for any other key or modifier mix.
    static func command(characters: String?, flags: NSEvent.ModifierFlags) -> Command? {
        guard flags.intersection(.deviceIndependentFlagsMask).subtracting([.shift, .capsLock, .numericPad]) == .command
        else { return nil }
        switch characters {
        case "=", "+": return .zoomIn
        case "-": return .zoomOut
        case "0": return .reset
        default: return nil
        }
    }

    static func minimumFrame(at percent: Int) -> CGSize {
        let factor = CGFloat(max(percent, 100)) / 100
        return CGSize(width: PanelSize.minimum.width * factor, height: PanelSize.minimum.height * factor)
    }

    /// A zoom in that would need a bigger window than `frame` leaves `percent` as it is.
    static func applied(_ command: Command, to percent: Int, frame: CGSize) -> Int {
        switch command {
        case .zoomIn:
            let next = min(percent + step, range.upperBound)
            let needed = minimumFrame(at: next)
            return frame.width >= needed.width && frame.height >= needed.height ? next : percent
        case .zoomOut:
            return max(percent - step, range.lowerBound)
        case .reset:
            return `default`
        }
    }

    static func scale(_ percent: Int) -> CGFloat {
        CGFloat(percent) / 100
    }

    static func saved(in defaults: UserDefaults) -> Int {
        guard let saved = defaults.object(forKey: key) as? Int else { return `default` }
        return min(max(saved, range.lowerBound), range.upperBound)
    }

    static func save(_ percent: Int, to defaults: UserDefaults) {
        defaults.set(percent, forKey: key)
    }
}
