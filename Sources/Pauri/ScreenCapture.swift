import AppKit
import CoreGraphics
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

enum ScreenCaptureProblem: Equatable {
    case screenRecording, couldNotCapture

    var message: String {
        switch self {
        case .screenRecording:
            "Pauri needs Screen Recording access to attach a screenshot. Turn on Pauri in System Settings > Privacy & Security > Screen & System Audio Recording, then quit and reopen Pauri."
        case .couldNotCapture:
            "Pauri could not take the screenshot."
        }
    }

    var settingsURL: URL? {
        switch self {
        case .screenRecording:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        case .couldNotCapture:
            nil
        }
    }
}

enum ScreenCapture {
    /// Checked before any ScreenCaptureKit call: on recent macOS the first one can itself prompt.
    static var isAllowed: Bool { CGPreflightScreenCaptureAccess() }

    /// Shows the macOS dialog the first time only; a grant applies after Pauri relaunches.
    static func requestAccess() { _ = CGRequestScreenCaptureAccess() }

    @MainActor static func displayID(of screen: NSScreen?) -> CGDirectDisplayID {
        screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()
    }

    /// The whole call stays off the main actor and only the URL crosses back: not every
    /// ScreenCaptureKit type is Sendable, and SDK callbacks on the main actor crashed in #11.
    nonisolated static func capture(displayID: CGDirectDisplayID) async throws -> URL {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
            throw CodexProblem.failed(ScreenCaptureProblem.couldNotCapture.message)
        }
        let pauri = content.applications.filter { $0.processID == getpid() }
        let filter = SCContentFilter(display: display, excludingApplications: pauri, exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        // Points, not Retina pixels: the model downsizes the image anyway.
        configuration.width = display.width
        configuration.height = display.height
        configuration.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        let url = FileManager.default.temporaryDirectory.appending(path: "pauri-screenshot-\(UUID()).png")
        try writePNG(image, to: url)
        return url
    }

    nonisolated static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CodexProblem.failed(ScreenCaptureProblem.couldNotCapture.message)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CodexProblem.failed(ScreenCaptureProblem.couldNotCapture.message)
        }
    }
}
