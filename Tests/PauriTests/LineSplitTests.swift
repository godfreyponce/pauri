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
        await forEachLine(in: chunks(of: pipe.fileHandleForReading)) { lines.append($0) }

        try #require(lines.count == 2)
        #expect(try lines.map(CodexIncoming.init(line:)) == [
            .notification(.agentMessageDelta("a\u{2028}b\u{85}c")),
            .notification(.turnCompleted(errorMessage: nil)),
        ])
    }

    /// A reply can pass the pipe buffer and arrive in two chunks; two lines can share one chunk.
    @Test func linesJoinAcrossChunks() async {
        let split = AsyncStream<Data> { continuation in
            for part in ["{\"a\":", "1}\n{\"b\"", ":2}\n"] { continuation.yield(Data(part.utf8)) }
            continuation.finish()
        }
        var lines: [Data] = []
        await forEachLine(in: split) { lines.append($0) }
        #expect(lines == [Data("{\"a\":1}".utf8), Data("{\"b\":2}".utf8)])
    }

    /// An app-server that never writes again (#13) must not keep another one's replies from arriving.
    @Test func idlePipeDoesNotStallAnotherReader() async throws {
        let idle = Pipe()
        let idleChunks = chunks(of: idle.fileHandleForReading)
        let idleReader = Task { await forEachLine(in: idleChunks) { _ in } }
        let busy = Pipe()
        try busy.fileHandleForWriting.write(contentsOf: Data("{}\n".utf8))
        try busy.fileHandleForWriting.close()

        var lines: [Data] = []
        await forEachLine(in: chunks(of: busy.fileHandleForReading)) { lines.append($0) }
        #expect(lines == [Data("{}".utf8)])

        try idle.fileHandleForWriting.close()
        await idleReader.value
    }
}
