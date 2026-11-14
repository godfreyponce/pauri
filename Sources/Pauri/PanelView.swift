import AppKit
import SwiftUI

struct PanelView: View {
    let hotKey: HotKey
    let chat: Chat
    @State private var draft = ""
    @State private var showsSettings = false
    @State private var sends = 0
    @FocusState private var focused: Bool
    @AppStorage(Transparency.key) private var transparency = Transparency.default

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
                        let exchange = chat.exchanges[index]
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exchange.question).bold()
                            ForEach(exchange.steps) { ToolStepRow(step: $0) }
                            if index == chat.exchanges.count - 1, let request = chat.approvals.first {
                                ApprovalCard(request: request,
                                             step: exchange.steps.first { $0.id == request.itemID },
                                             decide: { chat.decide(request, $0) })
                                    .padding(.leading, 15)
                            }
                            Text(exchange.answer)
                        }
                    }
                }
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .defaultScrollAnchor(.bottom)
            .frame(maxHeight: .infinity)
            // An inset, not an overlay: the first exchange can still scroll out from under the card.
            .safeAreaInset(edge: .top) {
                if chat.isContextFull {
                    ContextBanner(isWriting: chat.isWritingHandoff, isEnabled: chat.canStartNewChat) {
                        Task {
                            if let note = await chat.writeHandoff() {
                                draft = note
                                focused = true
                            }
                        }
                    } newChat: {
                        chat.newChat()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
            }
            if let notice = chat.notice {
                Text(notice)
                    .foregroundStyle(.secondary)
            }
            SelectionBar(chat: chat)
            HStack {
                TextField("Ask Pauri", text: $draft, axis: .vertical)
                    .lineLimit(1...8)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit(submit)
                SendOrb(sends: sends,
                        isEnabled: !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && !chat.isAnswering && !chat.isWritingHandoff,
                        isAnswering: chat.isAnswering,
                        action: submit)
            }
        }
        .padding()
        .background {
            Color(nsColor: .windowBackgroundColor).opacity(1 - transparency).ignoresSafeArea()
        }
        // The panel becomes key on every show. The settings popover is a window that also becomes
        // key, and moving focus to the text field then would close the popover.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            if note.object is FloatingPanel { focused = true }
        }
    }
}
