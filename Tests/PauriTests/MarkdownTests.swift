import AppKit
import Testing
@testable import Pauri

struct MarkdownTests {
    struct Block: Equatable {
        let kind: MarkdownBlock.Kind
        let text: String
        init(_ kind: MarkdownBlock.Kind, _ text: String) { self.kind = kind; self.text = text }
    }

    func blocks(_ markdown: String) -> [Block] {
        Markdown.blocks(markdown).map { Block($0.kind, String($0.text.characters)) }
    }

    func item(_ depth: Int, _ marker: String?, _ text: String) -> Block {
        Block(.listItem(depth: depth, marker: marker), text)
    }

    @Test func blocksOfAMixedAnswer() {
        #expect(blocks("# Title\n\nSome **bold** text.\n\n- one\n- two\n\n```swift\nlet x = 1\n```") == [
            Block(.heading(level: 1), "Title"),
            Block(.paragraph, "Some bold text."),
            item(0, "•", "one"),
            item(0, "•", "two"),
            Block(.code(language: "swift"), "let x = 1"),
        ])
    }

    @Test func inlineStylesSurvive() throws {
        let parsed = Markdown.blocks("Some **bold**, *it*, `code` and [link](https://example.com).")
        #expect(parsed.count == 1)
        let text = try #require(parsed.first).text
        #expect(String(text.characters) == "Some bold, it, code and link.")
        func run(_ word: String) throws -> AttributedString.Runs.Run {
            let range = try #require(text.range(of: word))
            return try #require(text[range].runs.first)
        }
        #expect(try run("bold").inlinePresentationIntent == .stronglyEmphasized)
        #expect(try run("it").inlinePresentationIntent == .emphasized)
        #expect(try run("code").inlinePresentationIntent == .code)
        #expect(try run("link").link == URL(string: "https://example.com"))
    }

    @Test func orderedAndNestedLists() {
        #expect(blocks("1. a\n2. b\n   - c") == [item(0, "1.", "a"), item(0, "2.", "b"), item(1, "•", "c")])
    }

    @Test func laterParagraphInItemHasNoMarker() {
        #expect(blocks("- one\n\n  more") == [item(0, "•", "one"), item(0, nil, "more")])
    }

    @Test func quoteRuleAndTable() {
        #expect(blocks("> quoted\n\n---\n\n| h1 | h2 |\n|---|---|\n| 1 | 2 |") == [
            Block(.quote, "quoted"),
            Block(.rule, ""),
            Block(.tableRow(isHeader: true), "h1 | h2"),
            Block(.tableRow(isHeader: false), "1 | 2"),
        ])
    }

    @Test func codeBlockKeepsInnerBlankLines() {
        #expect(blocks("```\na\n\nb\n```") == [Block(.code(language: nil), "a\n\nb")])
    }

    @Test func plainAndEmpty() {
        #expect(blocks("Hello") == [Block(.paragraph, "Hello")])
        #expect(blocks("") == [])
    }

    @Test func imageShowsAltText() {
        #expect(blocks("![a chart](https://example.com/a.png)") == [Block(.paragraph, "a chart")])
    }

    @Test func streamingHidesDanglingBold() {
        #expect(Markdown.streamingSafe("Hello **bol") == "Hello bol")
        #expect(Markdown.streamingSafe("**bold** and **op") == "**bold** and op")
    }

    @Test func streamingHidesDanglingBacktick() {
        #expect(Markdown.streamingSafe("Run `git sta") == "Run git sta")
    }

    @Test func streamingHidesHalfLink() {
        #expect(Markdown.streamingSafe("see [the docs](https://exa") == "see the docs")
        #expect(Markdown.streamingSafe("see [the do") == "see the do")
    }

    @Test func streamingLeavesOpenFenceAlone() {
        #expect(Markdown.streamingSafe("x\n\n```swift\nlet a = `b") == "x\n\n```swift\nlet a = `b")
    }

    @Test func streamingCountsIndentedAndTildeFences() {
        #expect(Markdown.streamingSafe("1. Install:\n   ```bash\n   npm i") == "1. Install:\n   ```bash\n   npm i")
        #expect(Markdown.streamingSafe("~~~\nlet a = `b") == "~~~\nlet a = `b")
    }

    @Test func streamingIgnoresBoldMarksInsideCode() {
        #expect(Markdown.streamingSafe("Use `a**b` and the") == "Use `a**b` and the")
        #expect(Markdown.streamingSafe("Use `x**2` and **bold") == "Use `x**2` and bold")
    }

    @Test func streamingLooksAtLastParagraphOnly() {
        #expect(Markdown.streamingSafe("a ** b\n\nfine") == "a ** b\n\nfine")
        #expect(Markdown.streamingSafe("- [ ] task") == "- [ ] task")
    }
}
