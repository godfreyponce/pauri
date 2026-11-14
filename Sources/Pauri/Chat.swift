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
    /// The text selected in the front app when the hotkey opened the panel; goes with the next question.
    var selection: String?

    /// Off during the start at launch, which would set the resumed thread after a new chat
    /// forgot it, and during an answer, which would stream into the blank chat.
    var canStartNewChat: Bool { !isAnswering && !isStarting }

    private let client: CodexClient
    /// Set once the resumed thread's old turns are shown, so a later restart never shows them twice.
    private var didRestore = false

    init(client: CodexClient) {
        self.client = client
    }

    func warmUp() {
        Task {
            do {
                try await client.start()
                showRestoredTurns()
            } catch {
                notice = Self.message(for: error)
            }
            isStarting = false
        }
    }

    /// A question asked during the start is already in `exchanges`; the old turns go above it.
    /// A failed start at launch leaves this to the first answer, which starts Codex again.
    private func showRestoredTurns() {
        guard !didRestore else { return }
        didRestore = true
        exchanges.insert(contentsOf: client.restoredExchanges, at: 0)
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
        let prompt = Self.prompt(question, selection: selection)
        selection = nil
        exchanges.append(Exchange(question: prompt, answer: ""))
        notice = nil
        isAnswering = true
        let sent = ContinuousClock.now
        Task {
            do {
                for try await delta in client.ask(prompt) {
                    showRestoredTurns()
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

    /// The selection as a Markdown quote above the question. `"\r\n"` is one `Character`, so one line break.
    nonisolated static func prompt(_ question: String, selection: String?) -> String {
        guard let selection else { return question }
        let quote = selection.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { "> " + $0 }
            .joined(separator: "\n")
        return quote + "\n\n" + question
    }

    private static func message(for error: Error) -> String {
        (error as? CodexProblem)?.message ?? error.localizedDescription
    }
}
