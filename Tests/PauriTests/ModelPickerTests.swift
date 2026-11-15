import Testing
@testable import Pauri

struct ModelPickerTests {
    @Test func labelDropsALeadingGPT() {
        #expect(ModelPicker.label("GPT-6.1-Sol Fast") == "6.1-Sol Fast")
        #expect(ModelPicker.label("GPT 5") == "5")
    }

    @Test func labelDropsGPTInAnyCase() {
        #expect(ModelPicker.label("gpt-5.1-codex") == "5.1-codex")
    }

    @Test func labelKeepsNamesWithoutALeadingGPT() {
        #expect(ModelPicker.label("Codex Mini") == "Codex Mini")
        #expect(ModelPicker.label("ChatGPT-5") == "ChatGPT-5")
    }

    @Test func labelKeepsANameWithNothingAfterGPT() {
        #expect(ModelPicker.label("GPT") == "GPT")
        #expect(ModelPicker.label("GPT-") == "GPT-")
    }

    @Test func labelWithNoModelIsCodexDefault() {
        #expect(ModelPicker.label(nil) == "Codex default")
    }
}
