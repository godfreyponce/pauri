import SwiftUI

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

/// Variant A of `design-directions/issue-8.html`, in variant B's yellow.
struct ContextBanner: View {
    let isWriting: Bool
    let writeHandoff: () -> Void
    let newChat: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16)
        VStack(alignment: .leading, spacing: 10) {
            Text("This chat is getting long. Codex may start to lose track of earlier parts.")
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(action: writeHandoff) {
                    if isWriting {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini)
                            Text("Writing draft...")
                        }
                    } else {
                        Text("Write a handoff draft")
                    }
                }
                .buttonStyle(.borderedProminent)
                Button("New chat", action: newChat)
            }
            .disabled(isWriting)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.15), in: shape)
        .background(.regularMaterial, in: shape)
        .overlay(shape.strokeBorder(Color.yellow.opacity(0.45)))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
    }
}
