import SwiftUI

/// Above the input: the one-time Accessibility request, or the chip of the attached selection.
struct SelectionBar: View {
    let chat: Chat
    @AppStorage("askedForSelectionAccess") private var asked = false

    var body: some View {
        // Read in every branch, so a selection set while the access row shows still re-renders this view.
        let selection = chat.selection
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
        } else if let text = selection {
            HStack(spacing: 6) {
                Image(systemName: "text.quote")
                Text(text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .modifier(HoverLabel(text: text, above: true))
                Button { chat.selection = nil } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless)
                    .modifier(HoverLabel(text: "Remove", above: true))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
