import SwiftUI

/// A new chat before its first question: variant C of `design-directions/issue-21.html`, a short
/// list of what the panel can do. Only the past-chats row is a button.
struct EmptyState: View {
    let shortcut: Shortcut
    let openHistory: () -> Void
    @State private var isHistoryHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("ASK ABOUT ANYTHING ON YOUR SCREEN.")
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.4)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            row("quote.opening", "Select text first, then press the hotkey to quote it.")
            row("paperclip", "The paperclip attaches a screenshot of this screen.")
            // No shortcut here: the header's search button owns Cmd+K.
            Button(action: openHistory) {
                row("clock.arrow.circlepath", "Open your past chats.", keys: ["⌘", "K"])
                    .background(isHistoryHovered ? AnyShapeStyle(.primary.opacity(0.08)) : AnyShapeStyle(.clear),
                                in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isHistoryHovered = $0 }
            row("return", "Bring Pauri back from any app.", keys: Self.keyCaps(shortcut))
        }
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ symbol: String, _ text: String, keys: [String] = []) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text)
            Spacer()
            HStack(spacing: 2) {
                ForEach(keys, id: \.self) { KeyCap(key: $0) }
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
    }

    /// `⌘⇧Space` as `["⌘", "⇧", "Space"]`: one cap per modifier, then the key.
    static func keyCaps(_ shortcut: Shortcut) -> [String] {
        let name = shortcut.displayName
        let modifiers = name.prefix { "⌃⌥⇧⌘".contains($0) }
        return modifiers.map(String.init) + [String(name.dropFirst(modifiers.count))]
    }
}

struct KeyCap: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 11))
            .padding(.horizontal, 4)
            .frame(minWidth: 16, minHeight: 18)
            .background(.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.primary.opacity(0.16)))
    }
}
