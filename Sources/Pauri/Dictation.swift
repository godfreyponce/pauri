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
