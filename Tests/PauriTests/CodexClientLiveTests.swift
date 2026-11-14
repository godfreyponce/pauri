import AppKit
import Testing
@testable import Pauri

@MainActor private func freshDefaults(_ name: String) -> UserDefaults {
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

/// Ends the client's app-server, as quitting Pauri does, and waits until the client sees it end.
@MainActor private func quit(_ client: CodexClient) async throws {
    kill(try #require(client.processIdentifier), SIGTERM)
    while client.processIdentifier != nil { try await Task.sleep(for: .milliseconds(50)) }
}

@MainActor private func answer(_ client: CodexClient, _ question: String) async throws -> String {
    var answer = ""
    for try await delta in client.ask(question) { answer += delta }
    return answer
}

@Suite struct CodexClientLiveTests {
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
        try await quit(afterNewChat)
    }

    /// No `warmUp()` call: the chat is in the state a failed start at launch leaves it in.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"))
    @MainActor func liveChatShowsOldTurnsAfterAFailedStart() async throws {
        let defaults = freshDefaults("pauri-live-failed-start")
        let first = CodexClient(defaults: defaults)
        _ = try await answer(first, "what is 2+2")
        try await quit(first)

        let client = CodexClient(defaults: defaults)
        let chat = Chat(client: client)
        #expect(chat.send("times 3"))
        while chat.isAnswering { try await Task.sleep(for: .milliseconds(50)) }
        #expect(chat.exchanges.map(\.question) == ["what is 2+2", "times 3"])
        #expect(chat.notice == nil)
        try await quit(client)
    }

    /// Before #13, the second start hung: its reader waited behind the first app-server's idle one.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"))
    @MainActor func liveTwoClientsAnswerSideBySide() async throws {
        let first = CodexClient(defaults: freshDefaults("pauri-live-two-clients-first"))
        let second = CodexClient(defaults: freshDefaults("pauri-live-two-clients-second"))
        try await first.start()
        try await second.start()
        #expect(first.processIdentifier != second.processIdentifier)
        #expect(!(try await answer(first, "Reply with just the word hi.")).isEmpty)
        #expect(!(try await answer(second, "Reply with just the word bye.")).isEmpty)
        try await quit(first)
        try await quit(second)
    }
}
