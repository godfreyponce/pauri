import AppKit
import Testing
@testable import Pauri

private func incoming(_ line: String) throws -> CodexIncoming { try CodexIncoming(line: Data(line.utf8)) }

private let listCommand = #"/bin/zsh -lc "rg --files --hidden -g '"'!.git'"' -g '*.swift' | wc -l""#

private func step(_ line: String) throws -> ToolStep {
    guard case .notification(.step(let step)) = try incoming(line) else {
        Issue.record("not a step: \(line)")
        throw CodexProtocolError(line: Data(line.utf8))
    }
    return step
}

private func commandStep(_ actions: String, status: String = "completed", output: String = "null") throws -> ToolStep {
    try step(#"{"method":"item/completed","params":{"item":{"type":"commandExecution","id":"c","command":"/bin/zsh -lc x","cwd":"/Users/u","status":"\#(status)","commandActions":\#(actions),"aggregatedOutput":\#(output),"exitCode":0},"threadId":"t","turnId":"u"}}"#)
}

private func fileStep(_ changes: String) throws -> ToolStep {
    try step(#"{"method":"item/completed","params":{"item":{"type":"fileChange","id":"f","changes":\#(changes),"status":"completed"},"threadId":"t","turnId":"u"}}"#)
}

struct CodexProtocolTests {
    @Test func agentDeltaCarriesItsText() throws {
        #expect(try incoming(#"{"method":"item/agentMessage/delta","params":{"threadId":"t","turnId":"u","itemId":"i","delta":"hi"},"emittedAtMs":1}"#)
            == .notification(.agentMessageDelta("hi")))
    }

    @Test func completedTurnHasNoError() throws {
        #expect(try incoming(#"{"method":"turn/completed","params":{"threadId":"t","turn":{"id":"u","items":[],"status":"completed","error":null}}}"#)
            == .notification(.turnCompleted(errorMessage: nil)))
    }

    @Test func failedTurnCarriesCodexMessage() throws {
        #expect(try incoming(#"{"method":"turn/completed","params":{"threadId":"t","turn":{"id":"u","items":[],"status":"failed","error":{"message":"Model overloaded","codexErrorInfo":null,"additionalDetails":null}}}}"#)
            == .notification(.turnCompleted(errorMessage: "Model overloaded")))
    }

    @Test func turnStartedCarriesTheTurnID() throws {
        #expect(try incoming(#"{"method":"turn/started","params":{"threadId":"t","turn":{"id":"u","items":[],"status":"inProgress","error":null}}}"#)
            == .notification(.turnStarted(threadID: "t", turnID: "u")))
    }

    @Test func interruptedTurnEndsWithoutAnError() throws {
        #expect(try incoming(#"{"method":"turn/completed","params":{"threadId":"t","turn":{"id":"u","items":[],"status":"interrupted","error":null}}}"#)
            == .notification(.turnCompleted(errorMessage: nil)))
    }

    @Test func errorNotificationCarriesRetryFlag() throws {
        #expect(try incoming(#"{"method":"error","params":{"error":{"message":"Reconnecting","codexErrorInfo":null,"additionalDetails":null},"willRetry":true,"threadId":"t","turnId":"u"}}"#)
            == .notification(.error(message: "Reconnecting", willRetry: true)))
    }

    @Test func otherNotificationsAreIgnored() throws {
        #expect(try incoming(#"{"method":"mcpServer/startupStatus/updated","params":{"threadId":"t","name":"node_repl","status":"ready"}}"#)
            == .notification(.ignored))
    }

    @Test func tokenUsageReadsLastNotTotal() throws {
        #expect(try incoming(#"{"method":"thread/tokenUsage/updated","params":{"threadId":"t","turnId":"u","tokenUsage":{"total":{"totalTokens":34249,"inputTokens":34239,"cachedInputTokens":29440,"cacheWriteInputTokens":0,"outputTokens":10,"reasoningOutputTokens":0},"last":{"totalTokens":18006,"inputTokens":18001,"cachedInputTokens":16128,"cacheWriteInputTokens":0,"outputTokens":5,"reasoningOutputTokens":0},"modelContextWindow":475000}},"emittedAtMs":1}"#)
            == .notification(.contextUsage(threadID: "t", ContextUsage(tokens: 18006, window: 475000))))
    }

    @Test func tokenUsageWithoutAWindowIsIgnored() throws {
        #expect(try incoming(#"{"method":"thread/tokenUsage/updated","params":{"threadId":"t","turnId":"u","tokenUsage":{"total":{"totalTokens":5},"last":{"totalTokens":5},"modelContextWindow":null}}}"#)
            == .notification(.ignored))
    }

    @Test func otherServerRequestsAreRefused() throws {
        #expect(try incoming(#"{"id":7,"method":"item/tool/requestUserInput","params":{}}"#) == .request(id: .int(7), .other))
        #expect(try incoming(#"{"id":"a1","method":"item/permissions/requestApproval","params":{}}"#) == .request(id: .string("a1"), .other))
    }

    @Test func commandApprovalCarriesItemAndReason() throws {
        let line = #"{"id":0,"method":"item/commandExecution/requestApproval","params":{"kind":"command","threadId":"t","turnId":"u","itemId":"exec-2","startedAtMs":1,"environmentId":"local","reason":"Allow creating the requested out.txt file outside the read-only sandbox?","command":"/bin/zsh -lc \"printf 'hi\\\\n' > out.txt\"","cwd":"/Users/u","commandActions":[{"type":"unknown","command":"printf 'hi\\n' > out.txt"}],"availableDecisions":["accept","cancel"]}}"#
        #expect(try incoming(line) == .request(id: .int(0), .approval(
            itemID: "exec-2", reason: "Allow creating the requested out.txt file outside the read-only sandbox?")))
    }

    @Test func fileChangeApprovalCarriesItem() throws {
        let line = #"{"id":1,"method":"item/fileChange/requestApproval","params":{"threadId":"t","turnId":"u","itemId":"exec-3","startedAtMs":1,"reason":null,"grantRoot":null}}"#
        #expect(try incoming(line) == .request(id: .int(1), .approval(itemID: "exec-3", reason: nil)))
    }

    @Test func decisionReplyCarriesTheDecision() throws {
        let line = CodexOutgoing.decision(id: .string("a1"), .decline)
        #expect(line.last == UInt8(ascii: "\n"))
        let object = try #require(JSONSerialization.jsonObject(with: line) as? [String: Any])
        #expect(object["id"] as? String == "a1")
        #expect((object["result"] as? [String: Any])?["decision"] as? String == "decline")
    }

    @Test func commandStepStartsAsListedFiles() throws {
        let line = #"{"method":"item/started","params":{"item":{"type":"commandExecution","id":"exec-1","command":"/bin/zsh -lc \"rg --files --hidden -g '\"'!.git'\"' -g '*.swift' | wc -l\"","cwd":"/Users/u/repo","processId":null,"source":"agent","status":"inProgress","commandActions":[{"type":"listFiles","command":"rg --files --hidden -g '!.git' -g '*.swift'","path":null}],"aggregatedOutput":null,"exitCode":null,"durationMs":null},"threadId":"t","turnId":"u","startedAtMs":1}}"#
        #expect(try incoming(line) == .notification(.step(ToolStep(
            id: "exec-1", label: "Listed files", detail: listCommand, output: "", status: .inProgress))))
    }

    @Test func completedCommandStepCarriesItsOutput() throws {
        let step = try commandStep(#"[{"type":"listFiles","command":"rg --files","path":null}]"#, output: #""      17\n""#)
        #expect(step.output == "      17\n")
        #expect(step.status == .completed)
    }

    @Test func readActionsNameOneFileOrCountMany() throws {
        #expect(try commandStep(#"[{"type":"read","command":"cat Package.swift","name":"Package.swift","path":"/Users/u/repo/Package.swift"}]"#).label
            == "Read Package.swift")
        #expect(try commandStep(#"[{"type":"read","command":"cat a","name":"a","path":"/Users/u/a"},{"type":"read","command":"cat b","name":"b","path":"/Users/u/b"}]"#).label
            == "Read 2 files")
    }

    @Test func searchActionNamesItsQuery() throws {
        #expect(try commandStep(#"[{"type":"search","command":"rg CodexClient","query":"CodexClient","path":null}]"#).label
            == "Searched for CodexClient")
    }

    @Test func otherCommandShowsItsCommand() throws {
        let actions = #"[{"type":"unknown","command":"git status"}]"#
        #expect(try commandStep(actions).label == "Ran `git status`")
        #expect(try commandStep(actions, status: "declined").label == "Ran `git status` (denied)")
    }

    @Test func fileChangeNamesTheFile() throws {
        let one = try fileStep(#"[{"path":"/Users/u/out.txt","kind":{"type":"add"},"diff":"+hi\n"}]"#)
        #expect(one.label == "Created out.txt")
        #expect(one.detail == "/Users/u/out.txt")
        #expect(one.output == "+hi\n")
        let two = try fileStep(#"[{"path":"/Users/u/a","kind":{"type":"add"},"diff":""},{"path":"/Users/u/b","kind":{"type":"delete"},"diff":""}]"#)
        #expect(two.label == "Changed 2 files")
    }

    @Test func aStepStillRunningWhenTheTurnEndsReadsAsFailed() {
        let running = ToolStep(id: "c", label: "Ran `git status`", detail: "d", output: "", status: .inProgress)
        #expect(running.endedWithTurn == ToolStep(id: "c", label: "Ran `git status` (failed)", detail: "d", output: "", status: .failed))
        let done = ToolStep(id: "c", label: "Listed files", detail: "d", output: "17", status: .completed)
        #expect(done.endedWithTurn == done)
    }

    @Test func otherItemTypesAreIgnored() throws {
        #expect(try incoming(#"{"method":"item/started","params":{"item":{"type":"agentMessage","id":"m","text":""},"threadId":"t","turnId":"u"}}"#)
            == .notification(.ignored))
    }

    @Test func serverRequestReplyIsMethodNotFound() throws {
        let line = CodexOutgoing.unsupported(id: .int(7))
        #expect(line.last == UInt8(ascii: "\n"))
        let object = try #require(JSONSerialization.jsonObject(with: line) as? [String: Any])
        #expect(object["id"] as? Int == 7)
        #expect((object["error"] as? [String: Any])?["code"] as? Int == -32601)
    }

    @Test func errorResponseCarriesMessage() throws {
        #expect(try incoming(#"{"id":4,"error":{"code":-32600,"message":"thread not found"}}"#)
            == .failure(id: 4, message: "thread not found"))
    }

    @Test func threadStartResultGivesThreadID() throws {
        guard case .response(3, let result) = try incoming(#"{"id":3,"result":{"thread":{"id":"th-1","ephemeral":false},"model":"m","reasoningEffort":"medium"}}"#)
        else { Issue.record("not a response"); return }
        #expect(try JSONDecoder().decode(ThreadStartResult.self, from: result).thread.id == "th-1")
    }

    @Test func accountReadTellsLoggedInFromLoggedOut() throws {
        let out = Data(#"{"account":null,"requiresOpenaiAuth":true,"workspaceRouting":null}"#.utf8)
        let inn = Data(#"{"account":{"type":"chatgpt","planType":"plus","workspaceName":null},"requiresOpenaiAuth":true}"#.utf8)
        #expect(try JSONDecoder().decode(AccountReadResult.self, from: out).isLoggedIn == false)
        #expect(try JSONDecoder().decode(AccountReadResult.self, from: inn).isLoggedIn == true)
    }

    @Test func resumeReplyGivesOneExchangePerTurn() throws {
        let reply = #"{"thread":{"id":"t","turns":[{"id":"u1","status":"completed","items":[{"type":"userMessage","id":"a","content":[{"type":"text","text":"what is 2+2","text_elements":[]}]},{"type":"reasoning","id":"b","summary":[],"content":[]},{"type":"agentMessage","id":"c","text":"4"}]},{"id":"u2","status":"completed","items":[{"type":"userMessage","id":"d","content":[{"type":"text","text":"times 3","text_elements":[]}]},{"type":"agentMessage","id":"e","text":"1"},{"type":"agentMessage","id":"f","text":"2"}]}]},"model":"m"}"#
        let result = try JSONDecoder().decode(ThreadResumeResult.self, from: Data(reply.utf8))
        #expect(result.exchanges == [
            Exchange(question: "what is 2+2", answer: "4"),
            Exchange(question: "times 3", answer: "12"),
        ])
    }

    @Test func resumeReplyKeepsAFailedTurnWithNoAnswer() throws {
        let reply = #"{"thread":{"id":"t","turns":[{"id":"u","status":"failed","items":[{"type":"userMessage","id":"a","content":[{"type":"text","text":"hi","text_elements":[]},{"type":"localImage","path":"/x.png"}]}]}]}}"#
        let result = try JSONDecoder().decode(ThreadResumeResult.self, from: Data(reply.utf8))
        #expect(result.exchanges == [Exchange(question: "hi", answer: "")])
    }

    @Test func lookupSkipsShellNoise() {
        let output = "Welcome back!\n__PAURI__\n/Users/u/.nvm/versions/node/v24/bin/codex\n/Users/u/.nvm/versions/node/v24/bin:/usr/bin:/bin\n"
        #expect(parseCodexLookup(output) == CodexLocation(
            executable: "/Users/u/.nvm/versions/node/v24/bin/codex", path: "/Users/u/.nvm/versions/node/v24/bin:/usr/bin:/bin"))
    }

    @Test func lookupWithoutCodexIsNil() {
        #expect(parseCodexLookup("__PAURI__\n\n/usr/bin:/bin\n") == nil)
        #expect(parseCodexLookup("__PAURI__\nalias codex=foo\n/usr/bin:/bin\n") == nil)
        #expect(parseCodexLookup("") == nil)
    }

    @Test func turnInputPutsTheImageAfterTheText() throws {
        func json(_ input: [[String: Any]]) throws -> String {
            String(decoding: try JSONSerialization.data(withJSONObject: input, options: [.sortedKeys]), as: UTF8.self)
        }
        #expect(try json(CodexClient.turnInput("hi", image: nil))
            == #"[{"text":"hi","text_elements":[],"type":"text"}]"#)
        #expect(try json(CodexClient.turnInput("hi", image: URL(fileURLWithPath: "/tmp/shot.png")))
            == #"[{"text":"hi","text_elements":[],"type":"text"},{"path":"\/tmp\/shot.png","type":"localImage"}]"#)
    }
}
