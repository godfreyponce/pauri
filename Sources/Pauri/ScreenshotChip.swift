import SwiftUI

/// Above the input: the attached screenshot, which goes with the next question.
struct ScreenshotChip: View {
    let url: URL
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)
            }
            Text("Screenshot")
            Button(action: remove) { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.borderless)
                .modifier(HoverLabel(text: "Remove", above: true))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
