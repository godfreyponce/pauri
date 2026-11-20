import os

extension Logger {
    /// User content (questions, answers, selections) never gets `privacy: .public`.
    static let pauri = Logger(subsystem: "io.github.godfreyponce.pauri", category: "app")
}
