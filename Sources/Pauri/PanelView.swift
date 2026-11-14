import AppKit
import SwiftUI

struct PanelView: View {
    let hotKey: HotKey
    let chat: Chat
    @State private var draft = ""
    @State private var showsSettings = false
    @State private var sends = 0
    @FocusState private var focused: Bool

    private func submit() {
        if chat.send(draft) {
            draft = ""
            sends += 1
        }
    }

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button { showsSettings = true } label: { Image(systemName: "gearshape") }
                    .buttonStyle(.borderless)
                    .help("Settings")
                    .popover(isPresented: $showsSettings) { SettingsView(hotKey: hotKey) }
            }
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
            HStack {
                TextField("Ask Pauri", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit(submit)
                SendOrb(sends: sends,
                        isEnabled: !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chat.isAnswering,
                        isAnswering: chat.isAnswering,
                        action: submit)
            }
        }
        .padding()
        // The panel becomes key on every show. The settings popover is a window that also becomes
        // key, and moving focus to the text field then would close the popover.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            if note.object is FloatingPanel { focused = true }
        }
    }
}
