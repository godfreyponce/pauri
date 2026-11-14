import AppKit
import Testing
@testable import Pauri

struct DictationTests {
    @Test func speechIsAddedAfterTheDraft() {
        #expect(Dictation.joined("Fix the", "login bug") == "Fix the login bug")
        #expect(Dictation.joined("Fix the ", "bug") == "Fix the bug")
        #expect(Dictation.joined("First line\n", "second") == "First line\nsecond")
        #expect(Dictation.joined("", "Hello") == "Hello")
        #expect(Dictation.joined("Fix", "") == "Fix")
    }

    @Test func refusedAccessNamesWhatToTurnOn() {
        #expect(Dictation.problem(micAllowed: false, speechAllowed: false, onDevice: true) == .microphone)
        #expect(Dictation.problem(micAllowed: true, speechAllowed: false, onDevice: true) == .speechRecognition)
        #expect(Dictation.problem(micAllowed: true, speechAllowed: true, onDevice: false) == .noOnDeviceModel)
        #expect(Dictation.problem(micAllowed: true, speechAllowed: true, onDevice: true) == nil)
    }

    @Test func recognitionStaysOnThisMac() {
        #expect(Dictation.makeRequest().requiresOnDeviceRecognition)
    }
}
