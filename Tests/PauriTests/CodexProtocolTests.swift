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
