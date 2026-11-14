import Foundation
import Observation

struct Exchange: Equatable, Sendable {
    let question: String
    var answer: String
    /// Shown in the panel only; nothing sends them back to the model.
    var steps: [ToolStep] = []
}

enum ApprovalChoice {
    case allow, deny, allowForChat
}

/// The questions and answers of the current Codex thread, for `PanelView`.
@Observable
@MainActor
final class Chat {
    private(set) var exchanges: [Exchange] = []
    private(set) var notice: String?
    private(set) var isAnswering = false
    private(set) var isStarting = true
    /// The card shows the first; the rest wait their turn.
    private(set) var approvals: [ApprovalRequest] = []

    /// Off during the start at launch, which would set the resumed thread after a new chat
    /// forgot it, and during an answer, which would stream into the blank chat.
    var canStartNewChat: Bool { !isAnswering && !isStarting }

    private let client: CodexClient
    /// Set once the resumed thread's old turns are shown, so a later restart never shows them twice.
    private var didRestore = false
    /// Only in memory, so a relaunch asks again in the resumed chat.
    private var allowsEverythingInThisChat = false

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
        allowsEverythingInThisChat = false
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
                for try await event in client.ask(question) {
                    showRestoredTurns()
                    let last = exchanges.count - 1
                    switch event {
                    case .text(let delta):
                        if exchanges[last].answer.isEmpty {
                            NSLog("Pauri: first token after %d ms", Int((ContinuousClock.now - sent) / .milliseconds(1)))
                        }
                        exchanges[last].answer += delta
                    case .step(let step):
                        if let index = exchanges[last].steps.firstIndex(where: { $0.id == step.id }) {
                            exchanges[last].steps[index] = step
                        } else {
                            exchanges[last].steps.append(step)
                        }
                    case .approval(let request):
                        if allowsEverythingInThisChat {
                            client.decide(request, .accept)
                        } else {
                            approvals.append(request)
                        }
                    }
                }
            } catch {
                notice = Self.message(for: error)
            }
            // Codex no longer waits on these, so a click on one must be impossible.
            approvals = []
            isAnswering = false
        }
        return true
    }

    func decide(_ request: ApprovalRequest, _ choice: ApprovalChoice) {
        guard let index = approvals.firstIndex(of: request) else { return }
        approvals.remove(at: index)
        switch choice {
        case .allow:
            client.decide(request, .accept)
        case .deny:
            client.decide(request, .decline)
        case .allowForChat:
            allowsEverythingInThisChat = true
            client.decide(request, .accept)
            for queued in approvals {
                client.decide(queued, .accept)
            }
            approvals = []
        }
    }

    private static func message(for error: Error) -> String {
        (error as? CodexProblem)?.message ?? error.localizedDescription
    }
}
