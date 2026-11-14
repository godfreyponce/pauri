import Foundation

/// A JSON-RPC id. The server's own requests may use either form.
enum RPCID: Hashable, Sendable {
    case int(Int)
    case string(String)
}

enum CodexNotification: Equatable, Sendable {
    case agentMessageDelta(String)
    case turnStarted(threadID: String, turnID: String)
    case turnCompleted(errorMessage: String?)
    case error(message: String, willRetry: Bool)
    case contextUsage(threadID: String, ContextUsage)
    case step(ToolStep)
    case ignored
}

/// One command Codex ran or one file change it made, shown as a gray line. Never sent back to the model.
struct ToolStep: Equatable, Sendable, Identifiable {
    enum Status: String, Sendable {
        case inProgress, completed, failed, declined
    }

    let id: String
    /// Carries the " (denied)" or " (failed)" suffix.
    let label: String
    /// The command as Codex ran it, or the changed paths, one per line.
    let detail: String
    /// The command's output, or the file diffs.
    let output: String
    let status: Status
}

extension ToolStep {
    /// Nil for every item type except `commandExecution`, `fileChange`, and `webSearch`.
    init?(item: [String: Any]) {
        guard let id = item["id"] as? String else { return nil }
        // A status this enum lacks reads as completed, so a newer codex never leaves a line spinning.
        let status = (item["status"] as? String).flatMap(Status.init(rawValue:)) ?? .completed
        let label: String
        switch item["type"] as? String {
        case "commandExecution":
            let command = item["command"] as? String ?? ""
            label = Self.commandLabel(actions: item["commandActions"] as? [[String: Any]] ?? [], command: command)
            detail = command
            output = item["aggregatedOutput"] as? String ?? ""
        case "fileChange":
            let changes = item["changes"] as? [[String: Any]] ?? []
            let paths = changes.map { $0["path"] as? String ?? "" }
            label = Self.fileLabel(changes: changes)
            detail = paths.joined(separator: "\n")
            output = changes.map { $0["diff"] as? String ?? "" }.joined(separator: "\n")
        case "webSearch":
            let query = item["query"] as? String ?? ""
            // `item/started` comes before Codex knows the query (codex-cli 0.169.0).
            label = query.isEmpty ? "Searched the web" : "Searched the web for “\(query)”"
            detail = query
            output = ""
        default:
            return nil
        }
        self.id = id
        self.status = status
        self.label = switch status {
        case .declined: label + " (denied)"
        case .failed: label + " (failed)"
        case .inProgress, .completed: label
        }
    }

    /// No `item/completed` comes for a step after its turn ends, so one still running stops spinning.
    var endedWithTurn: ToolStep {
        guard status == .inProgress else { return self }
        return ToolStep(id: id, label: label + " (failed)", detail: detail, output: output, status: .failed)
    }

    private static func commandLabel(actions: [[String: Any]], command: String) -> String {
        let types = Set(actions.map { $0["type"] as? String ?? "" })
        if types == ["read"] {
            let paths = Set(actions.map { $0["path"] as? String ?? "" })
            if paths.count == 1 { return "Read \(actions[0]["name"] as? String ?? "a file")" }
            return "Read \(paths.count) files"
        }
        if types == ["listFiles"] { return "Listed files" }
        if types == ["search"] {
            if actions.count == 1, let query = actions[0]["query"] as? String { return "Searched for \(query)" }
            return "Searched files"
        }
        switch actions.count {
        case 0: return "Ran `\(command)`"
        case 1: return "Ran `\(actions[0]["command"] as? String ?? command)`"
        default: return "Ran \(actions.count) commands"
        }
    }

    private static func fileLabel(changes: [[String: Any]]) -> String {
        guard changes.count == 1 else { return "Changed \(changes.count) files" }
        let name = URL(fileURLWithPath: changes[0]["path"] as? String ?? "").lastPathComponent
        let verb = switch (changes[0]["kind"] as? [String: Any])?["type"] as? String {
        case "add": "Created"
        case "delete": "Deleted"
        default: "Edited"
        }
        return "\(verb) \(name)"
    }
}

/// A request the app-server sends to Pauri and waits on.
enum ServerRequest: Equatable, Sendable {
    /// A command or file change that waits on Allow or Deny.
    case approval(itemID: String, reason: String?)
    /// Answered at once with method-not-found, so a turn never waits on Pauri.
    case other

    init(method: String, params: [String: Any]) {
        switch method {
        case "item/commandExecution/requestApproval", "item/fileChange/requestApproval":
            self = .approval(itemID: params["itemId"] as? String ?? "", reason: params["reason"] as? String)
        default:
            self = .other
        }
    }
}

enum ApprovalDecision: String, Sendable {
    case accept, decline
}

/// How full a thread's context is: what its last request held, against the model's window.
struct ContextUsage: Equatable, Sendable {
    let tokens: Int
    let window: Int
}

struct CodexProtocolError: Error {
    let line: Data
}

/// One line from `codex app-server` stdout.
enum CodexIncoming: Equatable, Sendable {
    /// `result` is the response's `result` object, written back to JSON for the caller to decode.
    case response(id: Int, result: Data)
    case failure(id: Int, message: String)
    case request(id: RPCID, ServerRequest)
    case notification(CodexNotification)

    init(line: Data) throws {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else {
            throw CodexProtocolError(line: line)
        }
        let method = object["method"] as? String
        if let rawID = object["id"] {
            if let method {
                let request = ServerRequest(method: method, params: object["params"] as? [String: Any] ?? [:])
                if let id = rawID as? Int {
                    self = .request(id: .int(id), request)
                } else if let id = rawID as? String {
                    self = .request(id: .string(id), request)
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
        case "turn/started":
            guard let threadID = params["threadId"] as? String,
                  let turnID = (params["turn"] as? [String: Any])?["id"] as? String
            else { self = .ignored; return }
            self = .turnStarted(threadID: threadID, turnID: turnID)
        case "turn/completed":
            let turn = params["turn"] as? [String: Any] ?? [:]
            let status = turn["status"] as? String ?? "unknown"
            // Only Pauri talks to its own app-server, so an interrupted turn is one the user stopped.
            if status == "completed" || status == "interrupted" {
                self = .turnCompleted(errorMessage: nil)
            } else {
                let message = (turn["error"] as? [String: Any])?["message"] as? String
                self = .turnCompleted(errorMessage: message ?? "Codex ended the answer (\(status)).")
            }
        case "error":
            let message = (params["error"] as? [String: Any])?["message"] as? String ?? "Codex reported an error."
            self = .error(message: message, willRetry: params["willRetry"] as? Bool ?? false)
        case "item/started", "item/completed":
            if let step = ToolStep(item: params["item"] as? [String: Any] ?? [:]) {
                self = .step(step)
            } else {
                self = .ignored
            }
        case "thread/tokenUsage/updated":
            // `last` is the last request, the context as it is now; `total` sums every request.
            let usage = params["tokenUsage"] as? [String: Any]
            guard let threadID = params["threadId"] as? String,
                  let tokens = (usage?["last"] as? [String: Any])?["totalTokens"] as? Int,
                  let window = usage?["modelContextWindow"] as? Int
            else { self = .ignored; return }
            self = .contextUsage(threadID: threadID, ContextUsage(tokens: tokens, window: window))
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

/// One reasoning level a model offers, as `model/list` reports it.
struct ReasoningEffortOption: Decodable, Equatable, Sendable {
    let reasoningEffort: String
    let description: String
}

/// One page of `model/list`; Codex sends every model in one page (codex-cli 0.169.0).
struct ModelListResult: Decodable {
    struct Model: Decodable {
        let id: String
        let displayName: String
        let description: String
        let defaultReasoningEffort: String
        /// Lowest level first (codex-cli 0.169.0).
        let supportedReasoningEfforts: [ReasoningEffortOption]
    }

    let data: [Model]
}

/// What a turn runs on: sent as `model`, `effort`, and `serviceTierForTurn` on `turn/start`.
struct ModelChoice: Equatable, Sendable, Identifiable {
    let model: String
    let name: String
    var effort: String
    /// The levels `model/list` reports for `model`, lowest first; empty when it was not loaded.
    let efforts: [ReasoningEffortOption]
    /// "priority" is Codex's Fast tier; "default" is standard speed.
    let serviceTier: String
    let help: String

    var id: String { model + "/" + serviceTier }

    static let quick = ModelChoice(model: "gpt-6.1-sol", name: "GPT-6.1-Sol Fast", effort: "low", efforts: [],
                                   serviceTier: "priority", help: "Fast answers at low reasoning effort.")

    /// `.quick` with its model's levels, followed by each model at its default effort and standard speed.
    static func menu(_ models: ModelListResult) -> [ModelChoice] {
        let quickLevels = models.data.first { $0.id == quick.model }?.supportedReasoningEfforts ?? []
        let fast = ModelChoice(model: quick.model, name: quick.name, effort: quick.effort, efforts: quickLevels,
                               serviceTier: quick.serviceTier, help: quick.help)
        return [fast] + models.data.map {
            ModelChoice(model: $0.id, name: $0.displayName, effort: $0.defaultReasoningEffort,
                        efforts: $0.supportedReasoningEfforts, serviceTier: "default", help: $0.description)
        }
    }

    /// The level after `effort`, wrapping to the lowest; an unlisted `effort` goes to the lowest.
    func nextEffort() -> ModelChoice {
        guard !efforts.isEmpty else { return self }
        let levels = efforts.map(\.reasoningEffort)
        var next = self
        next.effort = levels.firstIndex(of: effort).map { levels[($0 + 1) % levels.count] } ?? levels[0]
        return next
    }
}

/// Reads only the question and answer text of each old turn; every other item type is skipped.
struct ThreadResumeResult: Decodable {
    private struct Thread: Decodable {
        let turns: [Turn]
    }

    private struct Turn: Decodable {
        let items: [Item]
    }

    private struct Item: Decodable {
        let type: String
        let text: String?
        let content: [Part]?
    }

    private struct Part: Decodable {
        let type: String
        let text: String?
    }

    private let thread: Thread

    var exchanges: [Exchange] {
        thread.turns.map { turn in
            let question = turn.items.filter { $0.type == "userMessage" }
                .flatMap { $0.content ?? [] }
                .filter { $0.type == "text" }
                .compactMap(\.text)
                .joined()
            let answer = turn.items.filter { $0.type == "agentMessage" }.compactMap(\.text).joined()
            return Exchange(question: question, answer: answer)
        }
    }
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

    /// The reply to a server request Pauri does not handle, so a turn never waits on Pauri.
    static func unsupported(id: RPCID) -> Data {
        line(["id": json(id), "error": ["code": -32601, "message": "Pauri does not handle this request."]])
    }

    static func decision(id: RPCID, _ decision: ApprovalDecision) -> Data {
        line(["id": json(id), "result": ["decision": decision.rawValue]])
    }

    private static func json(_ id: RPCID) -> Any {
        switch id {
        case .int(let value): value
        case .string(let value): value
        }
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
