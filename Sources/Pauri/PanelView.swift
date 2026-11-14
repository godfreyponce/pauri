import AppKit
import SwiftUI

struct PanelView: View {
    let hotKey: HotKey
    let chat: Chat
    @State private var draft = ""
    @State private var showsSettings = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button { chat.newChat() } label: { Image(systemName: "square.and.pencil") }
                    .buttonStyle(.borderless)
                    .help("New chat")
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(!chat.canStartNewChat)
                Button { showsSettings = true } label: { Image(systemName: "gearshape") }
                    .buttonStyle(.borderless)
                    .help("Settings")
                    .popover(isPresented: $showsSettings) { SettingsView(hotKey: hotKey) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(chat.exchanges.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chat.exchanges[index].question).bold()
                            Text(chat.exchanges[index].answer)
                        }
                    }
                }
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .defaultScrollAnchor(.bottom)
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
        // The panel becomes key on every show. The settings popover is a window that also becomes
        // key, and moving focus to the text field then would close the popover.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            if note.object is FloatingPanel { focused = true }
        }
    }
}
