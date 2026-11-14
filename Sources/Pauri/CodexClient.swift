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

/// Keeps one `codex app-server` child warm and speaks its newline-delimited JSON-RPC.
@MainActor
final class CodexClient {
    private(set) var processIdentifier: Int32?
    /// The turns of the thread the last `launch()` resumed; empty when it started a new thread.
    private(set) var restoredExchanges: [Exchange] = []

    private var starting: Task<Void, Error>?
    private var process: Process?
    private var input: FileHandle?
    private var threadID: String?
    private var nextID = 1
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
    private var active: AsyncThrowingStream<String, Error>.Continuation?
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

    func ask(_ question: String) -> AsyncThrowingStream<String, Error> {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        Task {
            do {
                try await start()
                if threadID == nil { threadID = try await startThread() }
                guard let threadID else { throw CodexProblem.stopped }
                active = continuation
                _ = try await send("turn/start", [
                    "threadId": threadID,
                    "input": [["type": "text", "text": question, "text_elements": [Any]()]],
                ])
                // Codex writes a thread to disk only at its first turn; an id saved before that
                // cannot be resumed.
                defaults.set(threadID, forKey: Self.threadKey)
            } catch {
                active = nil
                continuation.finish(throwing: error)
            }
        }
        return stream
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
            do {
                let resumed: ThreadResumeResult = try decode(await send("thread/resume", [
                    "threadId": saved, "cwd": home.path, "sandbox": "read-only", "approvalPolicy": "never",
                ]))
                threadID = saved
                restoredExchanges = resumed.exchanges
                return
            } catch CodexProblem.failed {
                // The saved chat is gone (deleted session file, or a codex update dropped it).
                defaults.removeObject(forKey: Self.threadKey)
            }
        }
        threadID = try await startThread()
        restoredExchanges = []
    }

    private func startThread() async throws -> String {
        let started: ThreadStartResult = try decode(await send("thread/start", [
            "cwd": FileManager.default.homeDirectoryForCurrentUser.path, "sandbox": "read-only", "approvalPolicy": "never",
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
        case .request(let id, _):
            write(CodexOutgoing.unsupported(id: id))
        case .notification(.agentMessageDelta(let text)):
            active?.yield(text)
        case .notification(.turnCompleted(nil)):
            active?.finish()
            active = nil
        case .notification(.turnCompleted(let text?)), .notification(.error(let text, willRetry: false)):
            active?.finish(throwing: CodexProblem.failed(text))
            active = nil
        case .notification(.error(_, willRetry: true)), .notification(.step), .notification(.ignored):
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
