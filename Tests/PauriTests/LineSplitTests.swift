import AppKit
import Testing
@testable import Pauri

struct LineSplitTests {
    /// Codex writes U+2028 raw inside JSON strings; a split there loses the message.
    @Test func linesSplitOnlyOnNewline() async throws {
        let pipe = Pipe()
        let delta = "{\"method\":\"item/agentMessage/delta\",\"params\":{\"delta\":\"a\u{2028}b\u{85}c\"}}"
        try pipe.fileHandleForWriting.write(contentsOf: Data((delta + "\n{\"method\":\"turn/completed\",\"params\":{\"turn\":{\"status\":\"completed\"}}}\n").utf8))
        try pipe.fileHandleForWriting.close()

        var lines: [Data] = []
        try await forEachLine(in: pipe.fileHandleForReading.bytes) { lines.append($0) }

        try #require(lines.count == 2)
        #expect(try lines.map(CodexIncoming.init(line:)) == [
            .notification(.agentMessageDelta("a\u{2028}b\u{85}c")),
            .notification(.turnCompleted(errorMessage: nil)),
        ])
    }
}
