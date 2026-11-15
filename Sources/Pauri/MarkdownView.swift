import SwiftUI

/// An answer drawn as Markdown with native text, one `Text` per block.
/// Variant A of `design-directions/issue-16.html`.
struct MarkdownView: View, Equatable {
    let markdown: String
    let isStreaming: Bool

    @Environment(\.colorScheme) private var colorScheme

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.markdown == rhs.markdown && lhs.isStreaming == rhs.isStreaming
    }

    var body: some View {
        let blocks = Markdown.blocks(isStreaming ? Markdown.streamingSafe(markdown) : markdown)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(blocks.indices, id: \.self) { index in
                block(blocks[index])
                    .padding(.top, index == 0 ? 0 : gap(blocks[index - 1].kind, blocks[index].kind))
            }
        }
        .tint(colorScheme == .dark ? Color(hex: 0x8F86FF) : Color(hex: 0x4A3DB8))
    }

    private func gap(_ previous: MarkdownBlock.Kind, _ next: MarkdownBlock.Kind) -> CGFloat {
        switch (previous, next) {
        case (.listItem, .listItem), (.tableRow, .tableRow): 3
        default: 8
        }
    }

    @ViewBuilder
    private func block(_ block: MarkdownBlock) -> some View {
        let text = Text(tintingInlineCode(block.text))
        switch block.kind {
        case .paragraph:
            text
        case .heading(let level):
            text.font(.system(size: level == 1 ? 19 : level == 2 ? 16 : 14, weight: .bold))
                .padding(.top, 4)
        case .listItem(let depth, let marker):
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(marker ?? "").frame(width: 18, alignment: .leading)
                text
            }
            .padding(.leading, 18 * CGFloat(depth))
        case .code:
            ScrollView(.horizontal) {
                text.font(.system(size: 11.5, design: .monospaced))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        case .quote:
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5).fill(.quaternary).frame(width: 3)
                text.foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        case .rule:
            Divider()
        case .tableRow(let isHeader):
            text.bold(isHeader)
        }
    }

    private func tintingInlineCode(_ text: AttributedString) -> AttributedString {
        var text = text
        for run in text.runs where run.inlinePresentationIntent?.contains(.code) == true {
            text[run.range].backgroundColor = .primary.opacity(0.08)
        }
        return text
    }
}
