import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ScreenCapture {
    nonisolated static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CodexProblem.failed("Pauri could not take the screenshot.")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CodexProblem.failed("Pauri could not take the screenshot.")
        }
    }
}
