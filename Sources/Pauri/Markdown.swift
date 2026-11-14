import Foundation

/// One drawable block of an answer: a paragraph, a heading, one list item's paragraph, and so on.
struct MarkdownBlock: Equatable {
    enum Kind: Equatable {
        case paragraph
        case heading(level: Int)
        /// `marker` is "•" or "N."; nil for a later paragraph in the same item.
        case listItem(depth: Int, marker: String?)
        case code(language: String?)
        case quote
        case rule
        case tableRow(isHeader: Bool)
    }
    var kind: Kind
    var text: AttributedString
}

enum Markdown {
    static func blocks(_ markdown: String) -> [MarkdownBlock] {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible)
        guard let parsed = try? AttributedString(markdown: markdown, options: options) else {
            return markdown.isEmpty ? [] : [MarkdownBlock(kind: .paragraph, text: AttributedString(markdown))]
        }
        var blocks: [MarkdownBlock] = []
        var markedItems = Set<Int>()
        var lastBlockID: Int?
        var lastLeafID: Int?
        for run in parsed.runs {
            // Innermost first: the leaf block, then its ancestors.
            let components = run.presentationIntent?.components ?? []
            let leafID = components.first?.identity
            let row = components.first { $0.kind == .tableHeaderRow || isTableRow($0.kind) }
            // A table row is one block, so its cells share the row's identity.
            let blockID = (row ?? components.first)?.identity
            let piece = AttributedString(parsed[run.range])
            if blockID == lastBlockID, !blocks.isEmpty {
                if row != nil, leafID != lastLeafID { blocks[blocks.count - 1].text += AttributedString(" | ") }
                blocks[blocks.count - 1].text += piece
            } else {
                blocks.append(MarkdownBlock(kind: kind(of: components, markedItems: &markedItems), text: piece))
            }
            lastBlockID = blockID
            lastLeafID = leafID
        }
        return blocks.map { block in
            var block = block
            switch block.kind {
            case .rule:
                block.text = AttributedString()
            case .code where block.text.characters.last == "\n":
                block.text.characters.removeLast()
            default:
                break
            }
            return block
        }
    }

    private static func kind(of components: [PresentationIntent.IntentType],
                             markedItems: inout Set<Int>) -> MarkdownBlock.Kind {
        guard let leaf = components.first else { return .paragraph }
        switch leaf.kind {
        case .header(let level):
            return .heading(level: level)
        case .codeBlock(let hint):
            return .code(language: hint?.isEmpty == false ? hint : nil)
        case .thematicBreak:
            return .rule
        case .tableCell:
            return .tableRow(isHeader: components.contains { $0.kind == .tableHeaderRow })
        default:
            break
        }
        if let itemIndex = components.firstIndex(where: { isListItem($0.kind) }) {
            let item = components[itemIndex]
            let depth = components.filter { isList($0.kind) }.count - 1
            guard markedItems.insert(item.identity).inserted else { return .listItem(depth: depth, marker: nil) }
            let list = components[(itemIndex + 1)...].first { isList($0.kind) }
            if case .listItem(let ordinal) = item.kind, list?.kind == .orderedList {
                return .listItem(depth: depth, marker: "\(ordinal).")
            }
            return .listItem(depth: depth, marker: "•")
        }
        if components.contains(where: { $0.kind == .blockQuote }) { return .quote }
        return .paragraph
    }

    private static func isListItem(_ kind: PresentationIntent.Kind) -> Bool {
        if case .listItem = kind { return true }
        return false
    }

    private static func isList(_ kind: PresentationIntent.Kind) -> Bool {
        kind == .orderedList || kind == .unorderedList
    }

    private static func isTableRow(_ kind: PresentationIntent.Kind) -> Bool {
        if case .tableRow = kind { return true }
        return false
    }

    /// Hides a half-typed `**`, `` ` ``, or link in the last paragraph of a streaming answer,
    /// so the marks do not flash raw before their closing half arrives.
    static func streamingSafe(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        let isFence = { (line: String) in line.hasPrefix("```") }
        guard lines.filter(isFence).count.isMultiple(of: 2) else { return markdown }
        let tailStart = (lines.lastIndex { isFence($0) || $0.trimmingCharacters(in: .whitespaces).isEmpty } ?? -1) + 1
        guard tailStart < lines.count else { return markdown }
        var tail = lines[tailStart...].joined(separator: "\n")

        for mark in ["**", "`"] where !(tail.components(separatedBy: mark).count - 1).isMultiple(of: 2) {
            if let last = tail.range(of: mark, options: .backwards) { tail.removeSubrange(last) }
        }
        if let open = tail.range(of: "[", options: .backwards) {
            let after = tail[open.upperBound...]
            if !after.contains("]") {
                tail.removeSubrange(open)
            } else if let target = after.range(of: "]("), !after[target.upperBound...].contains(")") {
                tail = String(tail[..<open.lowerBound]) + after[..<target.lowerBound]
            }
        }
        return (lines[..<tailStart] + [tail]).joined(separator: "\n")
    }
}
