import AppKit
import Testing
@testable import Pauri

struct SelectionTests {
    @Test func promptWithoutSelectionIsTheQuestion() {
        #expect(Chat.prompt("What is this?", selection: nil) == "What is this?")
    }

    @Test func promptQuotesEveryLineAboveTheQuestion() {
        #expect(Chat.prompt("Explain", selection: "let a = 1\r\n\nlet b = 2")
            == "> let a = 1\n> \n> let b = 2\n\nExplain")
    }

    @Test func selectionIsTrimmed() {
        #expect(SelectionGrabber.cleaned("  \n hello world \n") == "hello world")
    }

    @Test func blankSelectionIsNothing() {
        #expect(SelectionGrabber.cleaned(nil) == nil)
        #expect(SelectionGrabber.cleaned(" \n\t ") == nil)
    }
}
