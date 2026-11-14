import Foundation

enum ContextLimit {
    /// A guess, not measured: the share of the context window at which the banner shows.
    /// This is the one value to tune.
    static let guess = 0.7
    /// Low enough that any chat passes it after its first answer.
    static let debugThreshold = 0.01
    /// `defaults write io.github.godfreyponce.pauri contextBannerDebug -bool YES`
    static let debugKey = "contextBannerDebug"

    static func isFull(_ usage: ContextUsage, debug: Bool) -> Bool {
        let threshold = debug ? debugThreshold : guess
        return Double(usage.tokens) >= threshold * Double(usage.window)
    }
}
