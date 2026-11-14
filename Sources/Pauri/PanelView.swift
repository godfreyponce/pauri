import AppKit
import SwiftUI

struct PanelView: View {
    let chat: Chat
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack {
            ScrollView {
                Text(chat.answer)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
            if let notice = chat.notice {
                Text(notice)
                    .foregroundStyle(.secondary)
            }
            TextField("Ask Pauri", text: $draft)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { if chat.send(draft) { draft = "" } }
        }
        .padding()
        // The panel is the app's only window that can become key, and it does so on every show.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            focused = true
        }
    }
}
