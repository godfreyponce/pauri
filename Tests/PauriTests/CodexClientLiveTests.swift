import AppKit
import Testing
@testable import Pauri

@MainActor private func freshDefaults(_ name: String) -> UserDefaults {
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

/// Ends the client's app-server, as quitting Pauri does, and waits until the client sees it end.
@MainActor private func quit(_ client: CodexClient) async throws {
    kill(try #require(client.processIdentifier), SIGTERM)
    while client.processIdentifier != nil { try await Task.sleep(for: .milliseconds(50)) }
}

@MainActor private func answer(_ client: CodexClient, _ question: String) async throws -> String {
    var answer = ""
    for try await case .text(let delta) in client.ask(question, model: nil) { answer += delta }
    return answer
}

/// The text and steps of one answer. Declines every approval, so no card can leave a test waiting.
@MainActor private func run(
    _ client: CodexClient, _ question: String, image: URL? = nil, model: ModelChoice? = nil
) async throws -> (text: String, steps: [ToolStep]) {
    var text = ""
    var steps: [ToolStep] = []
    for try await event in client.ask(question, image: image, model: model) {
        switch event {
        case .text(let delta): text += delta
        case .step(let step): steps.append(step)
        case .approval(let request): client.decide(request, .decline)
        }
    }
    return (text, steps)
}

private func searched(_ steps: [ToolStep]) -> Bool {
    steps.contains { $0.label.hasPrefix("Searched the web") }
}

@MainActor private func waitUntil(_ condition: () -> Bool) async throws {
    while !condition() { try await Task.sleep(for: .milliseconds(50)) }
}

/// 512x512, left half red, right half blue. At 64x64 the low-effort default swapped the halves (#18).
private func redBlueImage() throws -> CGImage {
    let sRGB = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(CGContext(
        data: nil, width: 512, height: 512, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 256, height: 512))
    context.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
    context.fill(CGRect(x: 256, y: 0, width: 256, height: 512))
    return try #require(context.makeImage())
}

@Suite struct CodexClientLiveTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"))
    @MainActor func liveTwoQuestionsOneProcess() async throws {
        let client = CodexClient(defaults: freshDefaults("pauri-live-two-questions"))
        async let first: Void = client.start()
        async let second: Void = client.start()
        _ = try await (first, second)
        let pid = try #require(client.processIdentifier)

        for question in ["Reply with just the word hi.", "Reply with just the word bye."] {
            let sent = ContinuousClock.now
            var answer = ""
            for try await case .text(let delta) in client.ask(question, model: nil) {
                if answer.isEmpty { print("first token after \(ContinuousClock.now - sent)") }
                answer += delta
            }
            #expect(!answer.isEmpty)
            #expect(client.processIdentifier == pid)
        }
        try await quit(client)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"))
    @MainActor func liveFollowUpSurvivesRelaunch() async throws {
        let defaults = freshDefaults("pauri-live-relaunch")
        let first = CodexClient(defaults: defaults)
        try await first.start()
        #expect(first.restoredExchanges.isEmpty)
        _ = try await answer(first, "what is 2+2")
        #expect(try await answer(first, "times 3").contains("12"))
        try await quit(first)

        let relaunched = CodexClient(defaults: defaults)
        try await relaunched.start()
        #expect(relaunched.restoredExchanges.map(\.question) == ["what is 2+2", "times 3"])

        relaunched.forgetThread()
        try await quit(relaunched)
        let afterNewChat = CodexClient(defaults: defaults)
        try await afterNewChat.start()
        #expect(afterNewChat.restoredExchanges.isEmpty)
        try await quit(afterNewChat)
    }

    /// No `warmUp()` call: the chat is in the state a failed start at launch leaves it in.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"))
    @MainActor func liveChatShowsOldTurnsAfterAFailedStart() async throws {
        let defaults = freshDefaults("pauri-live-failed-start")
        let first = CodexClient(defaults: defaults)
        _ = try await answer(first, "what is 2+2")
        try await quit(first)

        let client = CodexClient(defaults: defaults)
        let chat = Chat(client: client)
        #expect(chat.send("times 3"))
        while chat.isAnswering { try await Task.sleep(for: .milliseconds(50)) }
        #expect(chat.exchanges.map(\.question) == ["what is 2+2", "times 3"])
        #expect(chat.notice == nil)
        try await quit(client)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"))
    @MainActor func liveHandoffNoteLeavesTheChatAlone() async throws {
        let defaults = freshDefaults("pauri-live-handoff")
        let client = CodexClient(defaults: defaults)
        var usage: ContextUsage?
        client.onContextUsage = { usage = $0 }
        _ = try await answer(client, "My favorite color is teal. Reply with just ok.")
        let seen = try #require(usage)
        #expect(seen.tokens > 0 && seen.window > seen.tokens)

        let note = try await client.writeHandoff()
        #expect(note.localizedCaseInsensitiveContains("teal"))
        #expect(usage == seen)  // the fork's usage carries the fork's id and is dropped
        try await quit(client)

        let relaunched = CodexClient(defaults: defaults)
        var resumed: ContextUsage?
        relaunched.onContextUsage = { resumed = $0 }
        try await relaunched.start()
        #expect(relaunched.restoredExchanges.count == 1)  // the fork added no turn
        let deadline = ContinuousClock.now + .seconds(5)
        while resumed == nil, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(50)) }
        #expect(resumed == seen)
        try await quit(relaunched)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"), .timeLimit(.minutes(3)))
    @MainActor func liveModelListGivesADefaultThatAnswers() async throws {
        let client = CodexClient(defaults: freshDefaults("pauri-live-model-list"))
        try await client.start()
        let models = try #require(client.models)
        let choice = try #require(ModelChoice.menu(models).first)
        #expect(!(try await run(client, "Reply with just the word hi.", model: choice)).text.isEmpty)
        try await quit(client)
    }

    /// The turn Pauri sends when `model/list` failed.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"), .timeLimit(.minutes(3)))
    @MainActor func liveAnswerWithNoModelSent() async throws {
        let client = CodexClient(defaults: freshDefaults("pauri-live-no-model"))
        #expect(!(try await run(client, "Reply with just the word hi.", model: nil)).text.isEmpty)
        try await quit(client)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"), .timeLimit(.minutes(3)))
    @MainActor func liveWebSearchIsAlwaysOn() async throws {
        let client = CodexClient(defaults: freshDefaults("pauri-live-web-search"))
        let question = "Look up today's top headline on bbc.com/news and give it in one line."
        let on = try await run(client, question)
        print("web search:", on.steps.map(\.label), on.text)
        #expect(searched(on.steps))
        try await quit(client)
    }

    /// Before #13, the second start hung: its reader waited behind the first app-server's idle one.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"))
    @MainActor func liveTwoClientsAnswerSideBySide() async throws {
        let first = CodexClient(defaults: freshDefaults("pauri-live-two-clients-first"))
        let second = CodexClient(defaults: freshDefaults("pauri-live-two-clients-second"))
        try await first.start()
        try await second.start()
        #expect(first.processIdentifier != second.processIdentifier)
        #expect(!(try await answer(first, "Reply with just the word hi.")).isEmpty)
        #expect(!(try await answer(second, "Reply with just the word bye.")).isEmpty)
        try await quit(first)
        try await quit(second)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"))
    @MainActor func liveStopKeepsTheTextAndTheNextQuestionAnswers() async throws {
        let client = CodexClient(defaults: freshDefaults("pauri-live-stop"))
        var text = ""
        for try await case .text(let delta) in client.ask("Count from 1 to 300, one number per line, nothing else.", model: nil) {
            if text.isEmpty { client.stopAnswer() }
            text += delta
        }
        #expect(!text.isEmpty)
        #expect(!text.contains("300"))
        #expect(try await answer(client, "Reply with just the word hi.").lowercased().contains("hi"))
        try await quit(client)
    }

    /// The click during the launch start, before `turn/start` has replied with the turn's id.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"))
    @MainActor func liveStopBeforeTheTurnStartsEndsTheAnswer() async throws {
        let client = CodexClient(defaults: freshDefaults("pauri-live-stop-early"))
        let stream = client.ask("Count from 1 to 300, one number per line, nothing else.", model: nil)
        client.stopAnswer()
        var text = ""
        for try await case .text(let delta) in stream { text += delta }
        #expect(!text.contains("300"))
        try await quit(client)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"))
    @MainActor func liveHandoffAfterAStopWritesTheNote() async throws {
        let client = CodexClient(defaults: freshDefaults("pauri-live-stop-handoff"))
        var text = ""
        for try await case .text(let delta) in client.ask("My favorite color is teal. Then count from 1 to 300, one number per line.", model: nil) {
            if text.isEmpty { client.stopAnswer() }
            text += delta
        }
        #expect(try await client.writeHandoff().localizedCaseInsensitiveContains("teal"))
        try await quit(client)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"))
    @MainActor func liveReadRunsWithNoApproval() async throws {
        let client = CodexClient(defaults: freshDefaults("pauri-live-read"))
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        var events: [TurnEvent] = []
        for try await event in client.ask("How many Swift files are in \(repo.path)? Use a shell command to count them.", model: nil) {
            events.append(event)
        }
        #expect(!events.contains { if case .approval = $0 { true } else { false } })
        #expect(events.contains { if case .step(let step) = $0 { step.status == .completed } else { false } })
        try await quit(client)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"))
    @MainActor func liveAllowForThisChatCoversOnlyThisChat() async throws {
        let client = CodexClient(defaults: freshDefaults("pauri-live-allow-for-chat"))
        let chat = Chat(client: client)
        chat.warmUp()
        try await waitUntil { !chat.isStarting }
        let files = (0..<3).map { _ in FileManager.default.temporaryDirectory.appendingPathComponent("pauri-\(UUID().uuidString).txt") }
        defer { for file in files { try? FileManager.default.removeItem(at: file) } }
        func create(_ file: URL) -> String { "Create the file \(file.path) containing hi. Use a shell command." }

        chat.send(create(files[0]))
        try await waitUntil { !chat.approvals.isEmpty || !chat.isAnswering }
        let first = try #require(chat.approvals.first)
        chat.decide(first, .allowForChat)
        try await waitUntil { !chat.isAnswering }
        #expect(FileManager.default.fileExists(atPath: files[0].path))

        chat.send(create(files[1]))
        while chat.isAnswering {
            #expect(chat.approvals.isEmpty)
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(FileManager.default.fileExists(atPath: files[1].path))

        chat.newChat()
        chat.send(create(files[2]))
        try await waitUntil { !chat.approvals.isEmpty || !chat.isAnswering }
        let third = try #require(chat.approvals.first)
        chat.decide(third, .deny)
        try await waitUntil { !chat.isAnswering }
        #expect(!FileManager.default.fileExists(atPath: files[2].path))
        #expect(chat.notice == nil)
        #expect(!(chat.exchanges.last?.answer.isEmpty ?? true))
        try await quit(client)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"))
    @MainActor func liveImageIsDescribedAndOutlivesItsFile() async throws {
        let client = CodexClient(defaults: freshDefaults("pauri-live-image"))
        try await client.start()
        let models = try #require(client.models)
        let choice = try #require(ModelChoice.menu(models).first)
        let file = FileManager.default.temporaryDirectory.appending(path: "pauri-live-\(UUID()).png")
        try ScreenCapture.writePNG(redBlueImage(), to: file)
        let left = try await run(
            client, "What color is the left half of the attached image? One word.", image: file, model: choice
        ).text.lowercased()
        #expect(left.contains("red") && !left.contains("blue"))
        try FileManager.default.removeItem(at: file)
        let right = try await run(client, "What color is the right half of that image? One word.", model: choice).text.lowercased()
        #expect(right.contains("blue") && !right.contains("red"))
        try await quit(client)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"))
    @MainActor func liveHistoryListsOnlyThisListsChatsAndReopensOne() async throws {
        let defaults = freshDefaults("pauri-live-history")
        let client = CodexClient(defaults: defaults)
        try await client.start()
        _ = try await answer(client, "what is 2+2")
        client.forgetThread()
        _ = try await answer(client, "what is 3+3")
        #expect(client.rememberedThreadIDs.count == 2)

        let history = try await client.history()
        #expect(history.map(\.id) == Array(client.rememberedThreadIDs.reversed()))
        #expect(history.map(\.title) == ["what is 3+3", "what is 2+2"])

        #expect(try await client.resume(history[1].id).map(\.question) == ["what is 2+2"])
        await #expect(throws: CodexProblem.self) { try await client.resume("01a1ddad-0000-7563-b4eb-097d99638604") }
        #expect(try await answer(client, "times 3").contains("12"))
        try await quit(client)

        let relaunched = CodexClient(defaults: defaults)
        try await relaunched.start()
        #expect(relaunched.restoredExchanges.map(\.question) == ["what is 2+2", "times 3"])
        try await quit(relaunched)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PAURI_LIVE"] == "1"))
    @MainActor func liveDeleteDropsTheChatAndTheOpenOneStartsNew() async throws {
        let client = CodexClient(defaults: freshDefaults("pauri-live-delete"))
        let chat = Chat(client: client)
        chat.warmUp()
        try await waitUntil { !chat.isStarting }
        #expect(chat.send("what is 2+2"))
        try await waitUntil { !chat.isAnswering }
        let other = try #require(client.threadID)
        chat.newChat()
        #expect(chat.send("what is 3+3"))
        try await waitUntil { !chat.isAnswering }
        let open = try #require(client.threadID)

        try await chat.delete(other)
        #expect(chat.exchanges.count == 1)
        #expect(client.rememberedThreadIDs == [open])

        try await chat.delete(open)
        #expect(chat.exchanges.isEmpty)
        #expect(chat.title == "New chat")
        #expect(client.threadID == nil)
        #expect(client.rememberedThreadIDs.isEmpty)
        #expect(try await client.history().isEmpty)
        await #expect(throws: CodexProblem.self) { try await client.resume(other) }
        // The process still answers after its loaded thread was deleted.
        #expect(try await answer(client, "what is 5+5").contains("10"))
        try await quit(client)
    }
}
