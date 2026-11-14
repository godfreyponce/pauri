import AVFoundation
import Observation
import Speech

/// Why the mic cannot dictate, as the panel says it.
enum DictationProblem: Equatable {
    case microphone, speechRecognition, noOnDeviceModel, couldNotStart

    var message: String {
        switch self {
        case .microphone:
            "Pauri needs Microphone access to dictate. Turn on Pauri in System Settings > Privacy & Security > Microphone."
        case .speechRecognition:
            "Pauri needs Speech Recognition access to dictate. Turn on Pauri in System Settings > Privacy & Security > Speech Recognition."
        case .noOnDeviceModel:
            "This Mac cannot recognize speech on-device for your language, so Pauri does not dictate."
        case .couldNotStart:
            "Pauri could not start the microphone."
        }
    }

    var settingsURL: URL? {
        switch self {
        case .microphone:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        case .speechRecognition:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")
        case .noOnDeviceModel, .couldNotStart:
            nil
        }
    }
}

/// Speech to text on this Mac, between a press that starts it and a stop.
@Observable @MainActor
final class Dictation {
    private(set) var isListening = false
    private(set) var problem: DictationProblem?

    /// True while the access dialogs are up, so a second press cannot start a second engine.
    @ObservationIgnored private var isStarting = false
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognizer: SFSpeechRecognizer?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var onText: (@MainActor (String) -> Void)?
    /// Bumped on each listen, so a result from an earlier listen writes nothing.
    @ObservationIgnored private var run = 0

    func start(onText: @escaping @MainActor (String) -> Void) {
        guard !isStarting, !isListening else { return }
        isStarting = true
        problem = nil
        Task {
            defer { isStarting = false }
            let micAllowed = await AVCaptureDevice.requestAccess(for: .audio)
            let speechAllowed = await Self.requestSpeechAccess()
            let onDevice = SFSpeechRecognizer()?.supportsOnDeviceRecognition ?? false
            if let problem = Self.problem(micAllowed: micAllowed, speechAllowed: speechAllowed, onDevice: onDevice) {
                self.problem = problem
                return
            }
            listen(onText)
        }
    }

    func stop() {
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        engine = nil
        request = nil
        recognizer = nil
        task = nil
        onText = nil
        isListening = false
    }

    private func listen(_ onText: @escaping @MainActor (String) -> Void) {
        guard let recognizer = SFSpeechRecognizer() else {
            problem = .noOnDeviceModel
            return
        }
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // A zero rate means no input device; installTap would raise an exception Swift cannot catch.
        guard format.sampleRate > 0 else {
            problem = .couldNotStart
            return
        }
        let request = Self.makeRequest()
        input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.tapBlock(request))
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            problem = .couldNotStart
            return
        }
        run += 1
        self.engine = engine
        self.request = request
        self.recognizer = recognizer
        self.onText = onText
        task = recognizer.recognitionTask(with: request, resultHandler: Self.resultHandler(self, run: run))
        isListening = true
    }

    private func received(_ spoken: String?, ended: Bool, run: Int) {
        guard run == self.run, isListening else { return }
        if let spoken { onText?(spoken) }
        if ended { stop() }
    }

    // The SDK's tap block and Speech handlers are not @Sendable and run off the main thread. Made
    // inside a main-actor method, Swift 6 would treat them as main-actor closures and crash at runtime.

    nonisolated static func requestSpeechAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
    }

    nonisolated static func tapBlock(_ request: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        { buffer, _ in request.append(buffer) }
    }

    nonisolated static func resultHandler(_ dictation: Dictation, run: Int)
        -> (SFSpeechRecognitionResult?, (any Error)?) -> Void {
        { result, error in
            let spoken = result?.bestTranscription.formattedString
            let ended = error != nil || result?.isFinal == true
            Task { @MainActor in dictation.received(spoken, ended: ended, run: run) }
        }
    }

    nonisolated static func joined(_ prefix: String, _ spoken: String) -> String {
        if spoken.isEmpty { return prefix }
        if prefix.isEmpty || prefix.last!.isWhitespace { return prefix + spoken }
        return prefix + " " + spoken
    }

    nonisolated static func problem(micAllowed: Bool, speechAllowed: Bool, onDevice: Bool) -> DictationProblem? {
        if !micAllowed { return .microphone }
        if !speechAllowed { return .speechRecognition }
        if !onDevice { return .noOnDeviceModel }
        return nil
    }

    nonisolated static func makeRequest() -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        return request
    }
}
