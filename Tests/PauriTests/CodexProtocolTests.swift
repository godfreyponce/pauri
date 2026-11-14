import AppKit
import Testing
@testable import Pauri

private func incoming(_ line: String) throws -> CodexIncoming { try CodexIncoming(line: Data(line.utf8)) }

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

    @Test func serverRequestKeepsItsID() throws {
        #expect(try incoming(#"{"id":7,"method":"item/tool/requestUserInput","params":{}}"#) == .request(id: .int(7)))
        #expect(try incoming(#"{"id":"a1","method":"item/tool/requestUserInput","params":{}}"#) == .request(id: .string("a1")))
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
}
