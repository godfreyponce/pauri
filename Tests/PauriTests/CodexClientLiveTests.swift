import AppKit
import Testing
@testable import Pauri

@MainActor private func freshDefaults(_ name: String) -> UserDefaults {
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

/// Ends the client's app-server, as quitting Pauri does, and waits until the client sees it end.
/// A live app-server's stdout reader holds a Swift concurrency thread in a blocking read, and with
/// two of them in one test process the second reader stalls.
@MainActor private func quit(_ client: CodexClient) async throws {
    kill(try #require(client.processIdentifier), SIGTERM)
    while client.processIdentifier != nil { try await Task.sleep(for: .milliseconds(50)) }
}

@MainActor private func answer(_ client: CodexClient, _ question: String) async throws -> String {
    var answer = ""
    for try await delta in client.ask(question) { answer += delta }
    return answer
}

/// Serialized: two live app-servers at once stall the second reader (see `quit`).
@Suite(.serialized) struct CodexClientLiveTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"))
    @MainActor func liveTwoQuestionsOneProcess() async throws {
        let client = CodexClient(defaults: freshDefaults("pauri-live-two-questions"))
        async let first: Void = client.start()
        async let second: Void = client.start()
        _ = try await (first, second)
        let pid = try #require(client.processIdentifier)

        for question in ["Reply with just the word hi.", "Reply with just the word bye."] {
            let sent = ContinuousClock.now
            var answer = ""
            for try await delta in client.ask(question) {
                if answer.isEmpty { print("first token after \(ContinuousClock.now - sent)") }
                answer += delta
            }
            #expect(!answer.isEmpty)
            #expect(client.processIdentifier == pid)
        }
        try await quit(client)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"))
    @MainActor func liveFollowUpSurvivesRelaunch() async throws {
        let defaults = freshDefaults("pauri-live-relaunch")
        let first = CodexClient(defaults: defaults)
        try await first.start()
        #expect(first.restoredExchanges.isEmpty)
        _ = try await answer(first, "what is 2+2")
        #expect(try await answer(first, "times 3").contains("12"))
        try await quit(first)

        let relaunched = CodexClient(defaults: defaults)
        try await relaunched.start()
        #expect(relaunched.restoredExchanges.map(\.question) == ["what is 2+2", "times 3"])

        relaunched.forgetThread()
        try await quit(relaunched)
        let afterNewChat = CodexClient(defaults: defaults)
        try await afterNewChat.start()
        #expect(afterNewChat.restoredExchanges.isEmpty)
    }
}
