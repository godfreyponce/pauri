import Foundation
import Observation

/// The one question in flight and its answer, for `PanelView`.
@Observable
@MainActor
final class Chat {
    private(set) var answer = ""
    private(set) var notice: String?
    private(set) var isAnswering = false

    private let client: CodexClient

    init(client: CodexClient) {
        self.client = client
    }

    func warmUp() {
        Task {
            do {
                try await client.start()
            } catch {
                notice = Self.message(for: error)
            }
        }
    }

    @discardableResult
    func send(_ question: String) -> Bool {
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isAnswering else { return false }
        answer = ""
        notice = nil
        isAnswering = true
        let sent = ContinuousClock.now
        Task {
            do {
                for try await delta in client.ask(question) {
                    if answer.isEmpty {
                        NSLog("Pauri: first token after %d ms", Int((ContinuousClock.now - sent) / .milliseconds(1)))
                    }
                    answer += delta
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
