import AppKit
import Testing
@testable import Pauri

@Suite struct HistoryTests {
    @Test @MainActor func rememberKeepsEachThreadOnceAndOutlivesNewChat() {
        let defaults = UserDefaults(suiteName: "pauri-test-remember")!
        defaults.removePersistentDomain(forName: "pauri-test-remember")
        let client = CodexClient(defaults: defaults)
        client.remember("a")
        client.remember("b")
        client.remember("a")
        #expect(client.rememberedThreadIDs == ["a", "b"])
        client.forgetThread()
        #expect(CodexClient(defaults: defaults).rememberedThreadIDs == ["a", "b"])
    }

    @Test func historyKeepsOnlyRememberedThreadsInReplyOrder() throws {
        // T3 Code's thread, a Pauri thread this list never recorded (a live test's), then two remembered ones.
        let reply = #"{"data":[{"id":"t3","name":null,"preview":"fix the build","updatedAt":1794720600,"createdAt":1794720000,"originator":"T3 Code","source":"vscode","cwd":"/","turns":[]},{"id":"test","name":null,"preview":"Reply with just the word hi.","updatedAt":1794720550,"createdAt":1794720000,"originator":"pauri","source":"vscode","cwd":"/","turns":[]},{"id":"b","name":null,"preview":"what is 3+3","updatedAt":1794720526,"createdAt":1794720000,"originator":"pauri","source":"vscode","cwd":"/","turns":[]},{"id":"a","name":null,"preview":"what is 2+2","updatedAt":1794720400,"createdAt":1794720000,"originator":"pauri","source":"vscode","cwd":"/","turns":[]}],"nextCursor":"next","backwardsCursor":null}"#
        let page = try JSONDecoder().decode(ThreadListResult.self, from: Data(reply.utf8))
        // "gone" is remembered but Codex no longer lists it.
        #expect(page.entries(remembered: ["a", "b", "gone"]).map(\.id) == ["b", "a"])
        #expect(page.nextCursor == "next")
    }

    @Test func historyTitleIsTheNameOrElseThePreview() throws {
        let reply = #"{"data":[{"id":"n","name":"Trip plan","preview":"plan a trip","updatedAt":1794720526},{"id":"x","name":null,"preview":"what is 2+2","updatedAt":1794720526},{"id":"e","name":"","preview":"hello","updatedAt":1794720526}],"nextCursor":null}"#
        let page = try JSONDecoder().decode(ThreadListResult.self, from: Data(reply.utf8))
        let entries = page.entries(remembered: ["n", "x", "e"])
        #expect(entries.map(\.title) == ["Trip plan", "what is 2+2", "hello"])
        #expect(entries.map(\.preview) == ["plan a trip", "what is 2+2", "hello"])
        #expect(entries[0].updatedAt == Date(timeIntervalSince1970: 1794720526))
        #expect(page.nextCursor == nil)
    }

    @Test @MainActor func forgetDropsOnlyThatThread() {
        let defaults = UserDefaults(suiteName: "pauri-test-forget")!
        defaults.removePersistentDomain(forName: "pauri-test-forget")
        let client = CodexClient(defaults: defaults)
        client.remember("a"); client.remember("b"); client.remember("c")
        client.forget("b")
        client.forget("never")
        #expect(client.rememberedThreadIDs == ["a", "c"])
        #expect(CodexClient(defaults: defaults).rememberedThreadIDs == ["a", "c"])
    }

    @Test func searchMatchesTitleOrText() {
        let date = Date(timeIntervalSince1970: 1794720526)
        let entries = [
            HistoryEntry(id: "n", title: "Trip plan", preview: "plan a trip", updatedAt: date),
            HistoryEntry(id: "x", title: "what is 2+2", preview: "what is 2+2", updatedAt: date),
            HistoryEntry(id: "c", title: "Café hours", preview: "when does it open", updatedAt: date),
        ]
        func ids(_ query: String) -> [String] { entries.filter { $0.matches(query) }.map(\.id) }
        #expect(ids("") == ["n", "x", "c"])
        #expect(ids("  ") == ["n", "x", "c"])
        #expect(ids("TRIP") == ["n"])
        #expect(ids("2+2") == ["x"])
        #expect(ids("cafe") == ["c"])
        #expect(ids("open") == ["c"])
        #expect(ids("zzz") == [])
    }
}
