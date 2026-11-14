import AppKit
import Testing
@testable import Pauri

struct ContextLimitTests {
    /// The probe's one short question: 16,243 of 475,000 tokens.
    let oneShortQuestion = ContextUsage(tokens: 16_243, window: 475_000)

    @Test func oneShortQuestionIsNotFull() { #expect(!ContextLimit.isFull(oneShortQuestion, debug: false)) }
    @Test func debugTripsAfterOneShortQuestion() { #expect(ContextLimit.isFull(oneShortQuestion, debug: true)) }
    @Test func fullFromTheGuessOn() {
        #expect(!ContextLimit.isFull(ContextUsage(tokens: 332_499, window: 475_000), debug: false))
        #expect(ContextLimit.isFull(ContextUsage(tokens: 332_500, window: 475_000), debug: false))
    }
}
