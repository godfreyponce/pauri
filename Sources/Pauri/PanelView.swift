import AppKit
import SwiftUI

struct PanelView: View {
    let hotKey: HotKey
    let chat: Chat
    @State private var draft = ""
    @State private var showsSettings = false
    @State private var sends = 0
    @State private var dictation = Dictation()
    /// The draft as it was when the mic started; speech is added after it.
    @State private var dictationPrefix = ""
    /// The last text dictation wrote, so a change that differs from it is the user typing.
    @State private var dictated = ""
    @State private var screenshotProblem: ScreenCaptureProblem?
    @State private var isCapturing = false
    @FocusState private var focused: Bool
    @AppStorage(Transparency.key) private var transparency = Transparency.default

    private func submit() {
        dictation.cancel()
        if chat.send(draft) {
            draft = ""
            sends += 1
        }
    }

    private func captureScreenshot() {
        guard ScreenCapture.isAllowed else {
            ScreenCapture.requestAccess()
            screenshotProblem = .screenRecording
            return
        }
        screenshotProblem = nil
        isCapturing = true
        Task {
            let displayID = ScreenCapture.displayID(of: NSApp.windows.first { $0 is FloatingPanel }?.screen)
            do {
                chat.attachScreenshot(try await ScreenCapture.capture(displayID: displayID))
            } catch {
                screenshotProblem = .couldNotCapture
            }
            isCapturing = false
        }
    }

    var body: some View {
        VStack {
            // Variant C of design-directions/issue-21.html; its chat title and history button come with #20 and #22.
            HStack(spacing: 4) {
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
            .font(.system(size: 12))
            .frame(height: 26)
            ScrollView {
                if chat.exchanges.isEmpty && !chat.isStarting {
                    EmptyState(shortcut: hotKey.shortcut)
                        .containerRelativeFrame(.vertical, alignment: .bottom)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(chat.exchanges.indices, id: \.self) { index in
                            let exchange = chat.exchanges[index]
                            if index > 0 {
                                Divider().padding(.bottom, 12)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                QuestionRow(question: exchange.question, hasScreenshot: exchange.hasScreenshot)
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(exchange.steps) { ToolStepRow(step: $0) }
                                    if index == chat.exchanges.count - 1, let request = chat.approvals.first {
                                        ApprovalCard(request: request,
                                                     step: exchange.steps.first { $0.id == request.itemID },
                                                     decide: { chat.decide(request, $0) })
                                            .padding(.leading, 15)
                                    }
                                    MarkdownView(markdown: exchange.answer,
                                                 isStreaming: chat.isAnswering && index == chat.exchanges.count - 1)
                                        .equatable()
                                }
                                .padding(.leading, QuestionRow.labelWidth)
                            }
                        }
                    }
                    .font(.system(size: 12.5))
                    // The page's line-height 1.4 at 12.5 pt, less SF's own line height of about 1.2.
                    .lineSpacing(2.5)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
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
            if let problem = dictation.problem {
                HStack {
                    Text(problem.message)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let url = problem.settingsURL {
                        Button("Open System Settings") { NSWorkspace.shared.open(url) }
                            .buttonStyle(.borderless)
                    }
                }
            }
            if let problem = screenshotProblem {
                HStack {
                    Text(problem.message)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let url = problem.settingsURL {
                        Button("Open System Settings") { NSWorkspace.shared.open(url) }
                            .buttonStyle(.borderless)
                    }
                }
            }
            if let url = chat.screenshot {
                ScreenshotChip(url: url) { chat.removeScreenshot() }
            }
            SelectionBar(chat: chat)
            // Variant A of design-directions/issue-17.html, with a paperclip for the + menu.
            VStack(alignment: .leading, spacing: 6) {
                TextField("Ask Pauri", text: $draft, axis: .vertical)
                    .lineLimit(2...8)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit(submit)
                HStack(spacing: 6) {
                    Button(action: captureScreenshot) { Image(systemName: "paperclip") }
                        .buttonStyle(.borderless)
                        .disabled(isCapturing)
                        .help(screenshotProblem?.message ?? "Attach a screenshot")
                        .accessibilityLabel("Attach a screenshot")
                    ModelPicker(chat: chat)
                    Spacer()
                    Button {
                        if dictation.isListening {
                            dictation.stop()
                        } else {
                            dictationPrefix = draft
                            dictation.start { spoken in
                                dictated = Dictation.joined(dictationPrefix, spoken)
                                draft = dictated
                            }
                        }
                    } label: {
                        if dictation.isListening {
                            Image(systemName: "mic.fill").foregroundStyle(.red)
                        } else {
                            Image(systemName: dictation.problem == nil ? "mic" : "mic.slash")
                        }
                    }
                    .buttonStyle(.borderless)
                    .help(dictation.isListening ? "Stop dictation" : dictation.problem?.message ?? "Dictate")
                    SendOrb(sends: sends,
                            isEnabled: !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                && !chat.isAnswering && !chat.isWritingHandoff,
                            isAnswering: chat.isAnswering,
                            action: { chat.isAnswering ? chat.stop() : submit() })
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
        }
        .padding(12)
        .background {
            Color(nsColor: .windowBackgroundColor).opacity(1 - transparency).ignoresSafeArea()
        }
        // The panel becomes key on every show. The settings popover is a window that also becomes
        // key, and moving focus to the text field then would close the popover.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            if note.object is FloatingPanel { focused = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
            if note.object is FloatingPanel { dictation.stop() }
        }
        .onChange(of: draft) { _, new in
            if dictation.isListening && new != dictated { dictation.stop() }
        }
    }
}

/// The user's message as a labeled row, not a bubble: variant C of `design-directions/issue-21.html`.
/// Plain text, not Markdown, so `2*3*4` stays as typed.
struct QuestionRow: View {
    static let labelWidth: CGFloat = 44

    let question: String
    let hasScreenshot: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("YOU")
                .font(.system(size: 10.5, weight: .semibold))
                .kerning(0.5)
                .foregroundStyle(.secondary)
                .frame(width: Self.labelWidth, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(question)
                    .fontWeight(.medium)
                if hasScreenshot {
                    Label("Screenshot", systemImage: "photo")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
