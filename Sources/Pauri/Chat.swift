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
    private(set) var contextUsage: ContextUsage?
    private(set) var isWritingHandoff = false

    var isContextFull: Bool {
        guard let contextUsage else { return false }
        return ContextLimit.isFull(contextUsage, debug: UserDefaults.standard.bool(forKey: ContextLimit.debugKey))
    }

    /// Off during the start at launch, which would set the resumed thread after a new chat
    /// forgot it, during an answer, which would stream into the blank chat, and while the
    /// handoff note is written, which ends in a new chat of its own.
    var canStartNewChat: Bool { !isAnswering && !isStarting && !isWritingHandoff }

    private let client: CodexClient
    /// Set once the resumed thread's old turns are shown, so a later restart never shows them twice.
    private var didRestore = false

    init(client: CodexClient) {
        self.client = client
        client.onContextUsage = { [weak self] usage in self?.contextUsage = usage }
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
        contextUsage = nil
        client.forgetThread()
    }

    /// On success the chat is already new and the note is for the input box; it is never sent here.
    /// On failure the old chat stays, with the error as the notice.
    func writeHandoff() async -> String? {
        guard canStartNewChat else { return nil }
        isWritingHandoff = true
        notice = nil
        do {
            let note = try await client.writeHandoff()
            isWritingHandoff = false
            newChat()
            return note
        } catch {
            isWritingHandoff = false
            notice = Self.message(for: error)
            return nil
        }
    }

    @discardableResult
    func send(_ question: String) -> Bool {
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isAnswering, !isWritingHandoff else { return false }
        exchanges.append(Exchange(question: question, answer: ""))
        notice = nil
        isAnswering = true
        let sent = ContinuousClock.now
        Task {
            do {
                for try await delta in client.ask(question) {
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

    private static func message(for error: Error) -> String {
        (error as? CodexProblem)?.message ?? error.localizedDescription
    }
}
