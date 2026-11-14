import SwiftUI

/// Above the input: the one-time Accessibility request, or the chip of the attached selection.
struct SelectionBar: View {
    let chat: Chat
    @AppStorage("askedForSelectionAccess") private var asked = false

    var body: some View {
        if !asked && !SelectionGrabber.isAllowed {
            HStack {
                Text("To attach the text you select, Pauri needs Accessibility access.")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Allow") {
                    asked = true
                    SelectionGrabber.requestAccess()
                }
                .buttonStyle(.borderless)
                Button("Not now") { asked = true }
                    .buttonStyle(.borderless)
            }
        } else if let text = chat.selection {
            HStack(spacing: 6) {
                Image(systemName: "text.quote")
                Text(text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Button { chat.selection = nil } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless)
                    .help("Remove")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
            .help(text)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
