import Foundation
import Testing
@testable import Pauri

@Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"))
@MainActor func liveTwoQuestionsOneProcess() async throws {
    let client = CodexClient()
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
}
