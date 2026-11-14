import Foundation

enum CodexProblem: Error, Equatable {
    case notInstalled
    case notLoggedIn
    case stopped
    case failed(String)

    var message: String {
        switch self {
        case .notInstalled: "Pauri can't find Codex. Install it with npm install -g @openai/codex, then ask again."
        case .notLoggedIn: "Codex isn't logged in. Run codex login in Terminal, then ask again."
        case .stopped: "Codex stopped. Ask again to restart it."
        case .failed(let text): text
        }
    }
}

/// A request from Codex that waits on Allow or Deny.
struct ApprovalRequest: Equatable, Sendable, Identifiable {
    let id: RPCID
    let itemID: String
    let reason: String?
}

enum TurnEvent: Equatable, Sendable {
    case text(String)
    case step(ToolStep)
    case approval(ApprovalRequest)
}

/// Keeps one `codex app-server` child warm and speaks its newline-delimited JSON-RPC.
@MainActor
final class CodexClient {
    private(set) var processIdentifier: Int32?
    /// The turns of the thread the last `launch()` resumed; empty when it started a new thread.
    private(set) var restoredExchanges: [Exchange] = []
    /// Called with the current thread's usage only, never another thread's (such as a fork's).
    var onContextUsage: ((ContextUsage) -> Void)?

    static let handoffPrompt = "Write a handoff note that lets a new chat continue where this one leaves off. Say what we are working on, what is decided, and what is still open. Write it to the assistant of the new chat, in plain text, with no preamble."

    private var starting: Task<Void, Error>?
    private var process: Process?
    private var input: FileHandle?
    private var threadID: String?
    private var nextID = 1
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
    private var active: AsyncThrowingStream<TurnEvent, Error>.Continuation?
    /// The chat's running turn, from `turn/started`. The `turn/start` reply carries the id too, but
    /// an interrupt sent right after it got "no active turn to interrupt" (codex-cli 0.169.0).
    private var turn: (threadID: String, id: String)?
    /// A stop that came before `turn/started`.
    private var stopRequested = false
    private let defaults: UserDefaults
    private static let threadKey = "lastThreadID"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // A write to the pipe of a child that just died must fail, not kill Pauri.
        signal(SIGPIPE, SIG_IGN)
    }

    /// Joins a start in flight, so a Return during warm-up never spawns a second process.
    func start() async throws {
        if let starting {
            return try await starting.value
        }
        let task = Task { try await launch() }
        starting = task
        do {
            try await task.value
        } catch {
            if starting == task {
                process?.terminate()
                reset(failing: error)
            }
            throw error
        }
    }

    /// The next `ask` starts a new thread on the same process.
    func forgetThread() {
        threadID = nil
        defaults.removeObject(forKey: Self.threadKey)
    }

    func ask(_ question: String) -> AsyncThrowingStream<TurnEvent, Error> {
        let (stream, continuation) = AsyncThrowingStream<TurnEvent, Error>.makeStream()
        turn = nil
        stopRequested = false
        Task {
            do {
                try await start()
                if threadID == nil { threadID = try await startThread() }
                guard let threadID else { throw CodexProblem.stopped }
                try await startTurn(question, on: threadID, into: continuation)
                // Codex writes a thread to disk only at its first turn; an id saved before that
                // cannot be resumed.
                defaults.set(threadID, forKey: Self.threadKey)
            } catch {
                continuation.finish(throwing: error)
            }
        }
        return stream
    }

    /// Codex ends the turn with status "interrupted", which finishes the stream without an error.
    func stopAnswer() {
        stopRequested = true
        guard let turn else { return }
        Task {
            // The reply is `{}`; an error only means the turn had already ended.
            _ = try? await send("turn/interrupt", ["threadId": turn.threadID, "turnId": turn.id])
        }
    }

    func decide(_ request: ApprovalRequest, _ decision: ApprovalDecision) {
        write(CodexOutgoing.decision(id: request.id, decision))
    }

    /// Codex writes the note on an ephemeral fork of the current thread, so the thread itself
    /// gets no extra turn and the fork is never saved.
    func writeHandoff() async throws -> String {
        try await start()
        guard let threadID else { throw CodexProblem.stopped }
        let fork: ThreadStartResult = try decode(await send("thread/fork", [
            "threadId": threadID, "ephemeral": true, "excludeTurns": true,
            "cwd": FileManager.default.homeDirectoryForCurrentUser.path, "sandbox": "read-only", "approvalPolicy": "never",
        ]))
        let (stream, continuation) = AsyncThrowingStream<TurnEvent, Error>.makeStream()
        try await startTurn(Self.handoffPrompt, on: fork.thread.id, into: continuation)
        var answer = ""
        // The fork runs with approvalPolicy "never", so no approval waits on this loop.
        for try await case .text(let delta) in stream { answer += delta }
        return try Self.handoffNote(from: answer)
    }

    /// An empty note is an error: on success the old chat ends.
    nonisolated static func handoffNote(from answer: String) throws -> String {
        let note = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { throw CodexProblem.failed("Codex wrote an empty handoff draft. Try again.") }
        return note
    }

    private func startTurn(
        _ text: String, on threadID: String, into continuation: AsyncThrowingStream<TurnEvent, Error>.Continuation
    ) async throws {
        active = continuation
        do {
            _ = try await send("turn/start", [
                "threadId": threadID,
                "input": [["type": "text", "text": text, "text_elements": [Any]()]],
            ])
        } catch {
            active = nil
            throw error
        }
    }

    private func launch() async throws {
        let location = try await Self.lookUpCodex()
        let home = FileManager.default.homeDirectoryForCurrentUser
        try spawn(location, in: home)

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        _ = try await send("initialize", [
            "clientInfo": ["name": "pauri", "title": "Pauri", "version": version],
            "capabilities": NSNull(),
        ])
        write(CodexOutgoing.notification(method: "initialized"))

        let account: AccountReadResult = try decode(await send("account/read", [:]))
        guard account.isLoggedIn else { throw CodexProblem.notLoggedIn }

        if let saved = defaults.string(forKey: Self.threadKey) {
            // Set before the resume: the usage Codex sends right after its reply can arrive
            // first, and would be dropped as another thread's.
            threadID = saved
            do {
                let resumed: ThreadResumeResult = try decode(await send("thread/resume", [
                    "threadId": saved, "cwd": home.path, "sandbox": "read-only", "approvalPolicy": "on-request",
                ]))
                restoredExchanges = resumed.exchanges
                return
            } catch CodexProblem.failed {
                threadID = nil
                // The saved chat is gone (deleted session file, or a codex update dropped it).
                defaults.removeObject(forKey: Self.threadKey)
            }
        }
        threadID = try await startThread()
        restoredExchanges = []
    }

    private func startThread() async throws -> String {
        let started: ThreadStartResult = try decode(await send("thread/start", [
            "cwd": FileManager.default.homeDirectoryForCurrentUser.path, "sandbox": "read-only", "approvalPolicy": "on-request",
        ]))
        return started.thread.id
    }

    /// Runs the user's interactive login shell, where nvm, Homebrew, and Volta set up `PATH`.
    private nonisolated static func lookUpCodex() async throws -> CodexLocation {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let shell = Process()
                shell.executableURL = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh")
                shell.arguments = ["-l", "-i", "-c", codexLookupScript]
                let output = Pipe()
                // stdin from /dev/null keeps an rc file that waits for input from hanging the lookup.
                shell.standardInput = FileHandle.nullDevice
                shell.standardOutput = output
                shell.standardError = FileHandle.nullDevice
                do {
                    try shell.run()
                } catch {
                    continuation.resume(throwing: CodexProblem.notInstalled)
                    return
                }
                // Reading to the end before the wait keeps a chatty rc file from filling the pipe.
                let data = output.fileHandleForReading.readDataToEndOfFile()
                shell.waitUntilExit()
                if let location = parseCodexLookup(String(decoding: data, as: UTF8.self)) {
                    continuation.resume(returning: location)
                } else {
                    continuation.resume(throwing: CodexProblem.notInstalled)
                }
            }
        }
    }

    private func spawn(_ location: CodexLocation, in home: URL) throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: location.executable)
        child.arguments = ["app-server"]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = location.path
        child.environment = environment
        child.currentDirectoryURL = home
        let stdin = Pipe()
        let stdout = Pipe()
        child.standardInput = stdin
        child.standardOutput = stdout
        // A pipe nobody reads fills up and blocks the child.
        child.standardError = FileHandle.nullDevice
        let owner = ObjectIdentifier(child)
        child.terminationHandler = { [weak self] _ in
            Task { @MainActor in self?.processEnded(owner) }
        }
        do {
            try child.run()
        } catch {
            throw CodexProblem.notInstalled
        }
        process = child
        input = stdin.fileHandleForWriting
        processIdentifier = child.processIdentifier

        let reading = stdout.fileHandleForReading
        Task.detached { [weak self] in
            await forEachLine(in: chunks(of: reading)) { line in
                guard let message = try? CodexIncoming(line: line) else { return }
                await self?.receive(message, from: owner)
            }
        }
    }

    private func receive(_ message: CodexIncoming, from owner: ObjectIdentifier) {
        guard let process, ObjectIdentifier(process) == owner else { return }
        switch message {
        case .response(let id, let result):
            pending.removeValue(forKey: id)?.resume(returning: result)
        case .failure(let id, let text):
            pending.removeValue(forKey: id)?.resume(throwing: CodexProblem.failed(text))
        case .request(let id, .approval(let itemID, let reason)):
            if let active {
                active.yield(.approval(ApprovalRequest(id: id, itemID: itemID, reason: reason)))
            } else {
                // No card can show this request, so nothing runs.
                write(CodexOutgoing.decision(id: id, .decline))
            }
        case .request(let id, .other):
            write(CodexOutgoing.unsupported(id: id))
        case .notification(.agentMessageDelta(let text)):
            active?.yield(.text(text))
        case .notification(.step(let step)):
            active?.yield(.step(step))
        case .notification(.turnStarted(let threadID, let id)):
            // A handoff fork's turn is never the user's to stop, and `stopRequested` may be left
            // from the turn before it.
            guard active != nil, threadID == self.threadID else { return }
            turn = (threadID, id)
            if stopRequested { stopAnswer() }
        case .notification(.turnCompleted(nil)):
            active?.finish()
            active = nil
        case .notification(.turnCompleted(let text?)), .notification(.error(let text, willRetry: false)):
            active?.finish(throwing: CodexProblem.failed(text))
            active = nil
        case .notification(.contextUsage(let id, let usage)):
            if id == threadID { onContextUsage?(usage) }
        case .notification(.error(_, willRetry: true)), .notification(.ignored):
            break
        }
    }

    private func processEnded(_ owner: ObjectIdentifier) {
        guard let process, ObjectIdentifier(process) == owner else { return }
        reset(failing: CodexProblem.stopped)
    }

    private func reset(failing error: Error) {
        for continuation in pending.values {
            continuation.resume(throwing: error)
        }
        pending = [:]
        active?.finish(throwing: error)
        active = nil
        process = nil
        input = nil
        processIdentifier = nil
        threadID = nil
        starting = nil
    }

    private func send(_ method: String, _ params: [String: Any]) async throws -> Data {
        let id = nextID
        nextID += 1
        let line = CodexOutgoing.request(id: id, method: method, params: params)
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            if !write(line) {
                pending[id] = nil
                continuation.resume(throwing: CodexProblem.stopped)
            }
        }
    }

    @discardableResult
    private func write(_ line: Data) -> Bool {
        guard let input else { return false }
        do {
            try input.write(contentsOf: line)
            return true
        } catch {
            return false
        }
    }

    private func decode<Result: Decodable>(_ data: Data) throws -> Result {
        do {
            return try JSONDecoder().decode(Result.self, from: data)
        } catch {
            throw CodexProblem.failed("Codex sent a reply Pauri can't read.")
        }
    }
}

/// `FileHandle.bytes` reads every handle in the process one at a time, so an idle app-server
/// stalls another one's reader (#13). A readability handler gets its own dispatch source.
func chunks(of handle: FileHandle) -> AsyncStream<Data> {
    AsyncStream { continuation in
        handle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                continuation.finish()
            } else {
                continuation.yield(data)
            }
        }
    }
}

/// Splits on "\n" only. `AsyncLineSequence` also splits on U+2028, U+2029, and U+0085, which
/// Codex writes raw inside JSON strings.
func forEachLine(in chunks: AsyncStream<Data>, _ body: (Data) async -> Void) async {
    var line = Data()
    for await chunk in chunks {
        var rest = chunk[...]
        while let newline = rest.firstIndex(of: UInt8(ascii: "\n")) {
            line.append(rest[..<newline])
            await body(line)
            line = Data()
            rest = rest[rest.index(after: newline)...]
        }
        line.append(rest)
    }
}
