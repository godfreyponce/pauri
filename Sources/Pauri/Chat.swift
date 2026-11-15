import Foundation
import Observation

struct Exchange: Equatable, Sendable, Identifiable {
    let id = UUID()
    let question: String
    var answer: String
    /// Shown in the panel only; nothing sends them back to the model.
    var steps: [ToolStep] = []
    var hasScreenshot = false
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
    /// The text selected in the front app when the hotkey opened the panel; goes with the next question.
    var selection: String?
    /// The PNG the screenshot button wrote; goes with the next question, then is deleted.
    private(set) var screenshot: URL?
    private(set) var contextUsage: ContextUsage?
    private(set) var isWritingHandoff = false
    /// A chat from the list is being reopened.
    private(set) var isOpening = false
    /// The open chat is being deleted; a question now would go to the deleted thread.
    private(set) var isDeletingOpenChat = false
    /// Read when a question is sent, so a pick applies from the next message on. nil sends no
    /// model, so Codex uses its own default.
    var model: ModelChoice?
    private(set) var modelChoices: [ModelChoice] = []

    /// The first line of the chat's first question. Codex never names Pauri's chats, so this is
    /// also the chat's title in the list.
    var title: String {
        exchanges.first?.question
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? "New chat"
    }

    var isContextFull: Bool {
        guard let contextUsage else { return false }
        return ContextLimit.isFull(contextUsage, debug: UserDefaults.standard.bool(forKey: ContextLimit.debugKey))
    }

    /// Off during the start at launch, which would set the resumed thread after a new chat
    /// forgot it, during an answer, which would stream into the blank chat, and while the
    /// handoff note is written, which ends in a new chat of its own, and while a chat from the
    /// list opens, whose turns would replace the new one.
    var canStartNewChat: Bool { !isAnswering && !isStarting && !isWritingHandoff && !isOpening }

    private let client: CodexClient
    /// Set once the resumed thread's old turns are shown, so a later restart never shows them twice.
    private var didRestore = false
    /// Only in memory, so a relaunch asks again in the resumed chat.
    private var allowsEverythingInThisChat = false

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
    /// The picker's models come from the same start.
    private func showRestoredTurns() {
        guard !didRestore else { return }
        didRestore = true
        exchanges.insert(contentsOf: client.restoredExchanges, at: 0)
        modelChoices = client.models.map(ModelChoice.menu) ?? []
        if !modelChoices.contains(where: { $0 == model }) { model = modelChoices.first }
    }

    func newChat() {
        guard canStartNewChat else { return }
        exchanges = []
        notice = nil
        allowsEverythingInThisChat = false
        contextUsage = nil
        model = modelChoices.first
        client.forgetThread()
    }

    func history() async throws -> [HistoryEntry] {
        try await client.history()
    }

    /// On failure the current chat stays, with the error as the notice.
    func open(_ threadID: String) {
        guard canStartNewChat else { return }
        isOpening = true
        notice = nil
        // Cleared before the resume: the reopened thread's usage can arrive before its reply.
        contextUsage = nil
        Task {
            do {
                let turns = try await client.resume(threadID)
                // A start that failed at launch must never insert its turns later.
                showRestoredTurns()
                exchanges = turns
                allowsEverythingInThisChat = false
                model = modelChoices.first
            } catch {
                notice = Self.message(for: error)
            }
            isOpening = false
        }
    }

    /// Deleting the open chat starts a new one, and no question can be sent until it ends. On
    /// failure nothing changes.
    func delete(_ threadID: String) async throws {
        let wasOpen = client.threadID == threadID
        if wasOpen { isDeletingOpenChat = true }
        defer { if wasOpen { isDeletingOpenChat = false } }
        try await client.delete(threadID)
        if wasOpen { newChat() }
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

    /// Replaces the one already attached, and deletes its file.
    func attachScreenshot(_ url: URL) {
        removeScreenshot()
        screenshot = url
    }

    func removeScreenshot() {
        if let screenshot { try? FileManager.default.removeItem(at: screenshot) }
        screenshot = nil
    }

    @discardableResult
    func send(_ question: String) -> Bool {
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isAnswering, !isWritingHandoff, !isOpening, !isDeletingOpenChat else { return false }
        let prompt = Self.prompt(question, selection: selection)
        selection = nil
        let image = screenshot
        screenshot = nil
        exchanges.append(Exchange(question: prompt, answer: "", hasScreenshot: image != nil))
        notice = nil
        isAnswering = true
        let sent = ContinuousClock.now
        Task {
            do {
                for try await event in client.ask(prompt, image: image, model: model) {
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
            exchanges[exchanges.count - 1].steps = exchanges[exchanges.count - 1].steps.map(\.endedWithTurn)
            isAnswering = false
            // Codex keeps its own copy in the session file.
            if let image { try? FileManager.default.removeItem(at: image) }
        }
        return true
    }

    /// The end of the stream in `send` then clears the approvals and sets `isAnswering` back.
    func stop() {
        guard isAnswering else { return }
        client.stopAnswer()
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

    /// The selection as a Markdown quote above the question. `"\r\n"` is one `Character`, so one line break.
    nonisolated static func prompt(_ question: String, selection: String?) -> String {
        guard let selection else { return question }
        let quote = selection.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { "> " + $0 }
            .joined(separator: "\n")
        return quote + "\n\n" + question
    }

    static func message(for error: Error) -> String {
        (error as? CodexProblem)?.message ?? error.localizedDescription
    }
}
