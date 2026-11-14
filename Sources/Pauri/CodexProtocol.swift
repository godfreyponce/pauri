import Foundation

/// A JSON-RPC id. The server's own requests may use either form.
enum RPCID: Equatable, Sendable {
    case int(Int)
    case string(String)
}

enum CodexNotification: Equatable, Sendable {
    case agentMessageDelta(String)
    case turnCompleted(errorMessage: String?)
    case error(message: String, willRetry: Bool)
    case ignored
}

struct CodexProtocolError: Error {
    let line: Data
}

/// One line from `codex app-server` stdout.
enum CodexIncoming: Equatable, Sendable {
    /// `result` is the response's `result` object, written back to JSON for the caller to decode.
    case response(id: Int, result: Data)
    case failure(id: Int, message: String)
    case request(id: RPCID)
    case notification(CodexNotification)

    init(line: Data) throws {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else {
            throw CodexProtocolError(line: line)
        }
        let method = object["method"] as? String
        if let rawID = object["id"] {
            if method != nil {
                if let id = rawID as? Int {
                    self = .request(id: .int(id))
                } else if let id = rawID as? String {
                    self = .request(id: .string(id))
                } else {
                    throw CodexProtocolError(line: line)
                }
                return
            }
            guard let id = rawID as? Int else { throw CodexProtocolError(line: line) }
            if let error = object["error"] as? [String: Any] {
                self = .failure(id: id, message: error["message"] as? String ?? "Codex returned an error.")
            } else {
                let result = object["result"] ?? NSNull()
                self = .response(id: id, result: try JSONSerialization.data(withJSONObject: result, options: .fragmentsAllowed))
            }
            return
        }
        guard let method else { throw CodexProtocolError(line: line) }
        self = .notification(CodexNotification(method: method, params: object["params"] as? [String: Any] ?? [:]))
    }
}

extension CodexNotification {
    init(method: String, params: [String: Any]) {
        switch method {
        case "item/agentMessage/delta":
            self = .agentMessageDelta(params["delta"] as? String ?? "")
        case "turn/completed":
            let turn = params["turn"] as? [String: Any] ?? [:]
            let status = turn["status"] as? String ?? "unknown"
            if status == "completed" {
                self = .turnCompleted(errorMessage: nil)
            } else {
                let message = (turn["error"] as? [String: Any])?["message"] as? String
                self = .turnCompleted(errorMessage: message ?? "Codex ended the answer (\(status)).")
            }
        case "error":
            let message = (params["error"] as? [String: Any])?["message"] as? String ?? "Codex reported an error."
            self = .error(message: message, willRetry: params["willRetry"] as? Bool ?? false)
        default:
            self = .ignored
        }
    }
}

/// Decodes only whether `account` is null; the account object carries the user's email.
struct AccountReadResult: Decodable {
    private struct Account: Decodable {
        let type: String
    }

    private let account: Account?

    var isLoggedIn: Bool { account != nil }
}

struct ThreadStartResult: Decodable {
    let thread: ThreadRef
}

struct ThreadRef: Decodable {
    let id: String
}

/// Each message is one JSON object plus a newline.
enum CodexOutgoing {
    static func request(id: Int, method: String, params: [String: Any]) -> Data {
        line(["id": id, "method": method, "params": params])
    }

    static func notification(method: String) -> Data {
        line(["method": method])
    }

    /// Pauri answers no server request yet, so a turn never waits on Pauri.
    static func unsupported(id: RPCID) -> Data {
        let rawID: Any = switch id {
        case .int(let value): value
        case .string(let value): value
        }
        return line(["id": rawID, "error": ["code": -32601, "message": "Pauri does not handle this request."]])
    }

    private static func line(_ object: [String: Any]) -> Data {
        // Every value passed in is a JSON type, so serialization cannot fail.
        var data = try! JSONSerialization.data(withJSONObject: object)
        data.append(UInt8(ascii: "\n"))
        return data
    }
}

struct CodexLocation: Equatable, Sendable {
    let executable: String
    /// The login shell's `PATH`; the npm `codex` is a node script and needs `node` on it.
    let path: String
}

/// Separates the lookup's output from whatever the user's rc files print first.
let codexLookupMarker = "__PAURI__"
let codexLookupScript = #"printf '%s\n' __PAURI__ "$(command -v codex)" "$PATH""#

func parseCodexLookup(_ output: String) -> CodexLocation? {
    let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    guard let marker = lines.firstIndex(of: codexLookupMarker), marker + 2 < lines.count else { return nil }
    let executable = lines[marker + 1]
    guard executable.hasPrefix("/") else { return nil }
    return CodexLocation(executable: executable, path: lines[marker + 2])
}
