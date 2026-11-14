import Foundation
import Observation

struct Exchange: Equatable, Sendable {
    let question: String
    var answer: String
}

/// The questions and answers of the current Codex thread, for `PanelView`.
@Observable
@MainActor
final class Chat {
    private(set) var exchanges: [Exchange] = []
    private(set) var notice: String?
    private(set) var isAnswering = false
    private(set) var isStarting = true

    /// Off during the start at launch, which would set the resumed thread after a new chat
    /// forgot it, and during an answer, which would stream into the blank chat.
    var canStartNewChat: Bool { !isAnswering && !isStarting }

    private let client: CodexClient

    init(client: CodexClient) {
        self.client = client
    }

    func warmUp() {
        Task {
            do {
                try await client.start()
                // A question asked during the start is already in `exchanges`; the old turns go above it.
                exchanges.insert(contentsOf: client.restoredExchanges, at: 0)
            } catch {
                notice = Self.message(for: error)
            }
            isStarting = false
        }
    }

    func newChat() {
        guard canStartNewChat else { return }
        exchanges = []
        notice = nil
        client.forgetThread()
    }

    @discardableResult
    func send(_ question: String) -> Bool {
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isAnswering else { return false }
        exchanges.append(Exchange(question: question, answer: ""))
        notice = nil
        isAnswering = true
        let sent = ContinuousClock.now
        Task {
            do {
                for try await delta in client.ask(question) {
                    if exchanges[exchanges.count - 1].answer.isEmpty {
                        NSLog("Pauri: first token after %d ms", Int((ContinuousClock.now - sent) / .milliseconds(1)))
                    }
                    exchanges[exchanges.count - 1].answer += delta
                }
            } catch {
                notice = Self.message(for: error)
            }
            isAnswering = false
        }
        return true
    }

    private static func message(for error: Error) -> String {
        (error as? CodexProblem)?.message ?? error.localizedDescription
    }
}
