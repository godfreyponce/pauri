import AppKit
import SwiftUI

struct PanelView: View {
    let hotKey: HotKey
    let chat: Chat
    let updater: Updater
    @State private var draft = ""
    @State private var showsSettings = false
    @State private var showsHistory = false
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
            // Variant C of design-directions/issue-21.html: the chat's title, then the past-chats palette.
            HStack(spacing: 4) {
                Text(chat.title)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let version = updater.readyVersion {
                    Button { updater.install() } label: {
                        if updater.isInstalling {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.up.circle").font(.system(size: 12))
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(updater.isInstalling || !chat.canStartNewChat)
                    // Stays up while installing: the click is about to quit and restart Pauri.
                    .modifier(HoverLabel(
                        text: updater.isInstalling ? "Updating to Pauri \(version). Pauri will restart."
                            : chat.canStartNewChat ? "Update to Pauri \(version) and restart"
                            : "Update after the answer ends",
                        pinned: updater.isInstalling))
                } else {
                    UpdateStatusIcon(updater: updater)
                }
                Button { showsHistory.toggle() } label: { Image(systemName: "magnifyingglass").font(.system(size: 12)) }
                    .buttonStyle(.borderless)
                    .modifier(HoverLabel(text: "Past chats (⌘K)"))
                    .keyboardShortcut("k", modifiers: .command)
                Button { chat.newChat() } label: { Image(systemName: "square.and.pencil").font(.system(size: 12)) }
                    .buttonStyle(.borderless)
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(!chat.canStartNewChat)
                    .modifier(HoverLabel(text: "New chat"))
                Button { showsSettings = true } label: { Image(systemName: "gearshape").font(.system(size: 12)) }
                    .buttonStyle(.borderless)
                    .modifier(HoverLabel(text: "Settings"))
                    .popover(isPresented: $showsSettings) { SettingsView(hotKey: hotKey) }
            }
            .frame(height: 26)
            .zIndex(1)
            ScrollView {
                if chat.exchanges.isEmpty && !chat.isStarting {
                    EmptyState(shortcut: hotKey.shortcut) { showsHistory = true }
                        .containerRelativeFrame(.vertical, alignment: .bottom)
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(chat.exchanges.enumerated()), id: \.element.id) { index, exchange in
                            VStack(alignment: .leading, spacing: 12) {
                                QuestionBubble(question: exchange.question, hasScreenshot: exchange.hasScreenshot)
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
                                && !chat.isAnswering && !chat.isWritingHandoff && !chat.isOpening
                                && !chat.isDeletingOpenChat,
                            isAnswering: chat.isAnswering,
                            action: { chat.isAnswering ? chat.stop() : submit() })
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
        }
        .padding(12)
        .overlay {
            if showsHistory {
                HistoryList(chat: chat) { showsHistory = false }
            }
        }
        .background {
            Color(nsColor: .windowBackgroundColor).opacity(1 - transparency).ignoresSafeArea()
        }
        // The panel becomes key on every show. The settings popover is a window that also becomes
        // key, and moving focus to the text field then would close the popover.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            if note.object is FloatingPanel { focused = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
            // Closed on hide, or the next hotkey would focus the input under the palette.
            if note.object is FloatingPanel {
                dictation.stop()
                showsHistory = false
            }
        }
        .onChange(of: showsHistory) { _, shows in
            if !shows { focused = true }
        }
        .onChange(of: draft) { _, new in
            if dictation.isListening && new != dictated { dictation.stop() }
        }
    }
}

/// The user's message as a grey bubble on the right: variant E of `design-directions/issue-39.html`,
/// the owner's pick. Plain text, not Markdown, so `2*3*4` stays as typed.
struct QuestionBubble: View {
    let question: String
    let hasScreenshot: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(question)
            if hasScreenshot {
                Label("Screenshot", systemImage: "photo")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
        .containerRelativeFrame(.horizontal, alignment: .trailing) { width, _ in width * 0.75 }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

/// Variant A1 of `design-directions/issue-34.html`: with no update ready, the up-arrow's slot shows the last
/// check's result. A click on the check or the warning checks now.
struct UpdateStatusIcon: View {
    let updater: Updater

    var body: some View {
        Group {
            switch updater.status {
            case .off: icon("minus.circle").disabled(true)
            case .checking: ProgressView().controlSize(.mini)
            case .upToDate: icon("checkmark.circle")
            case .couldNotCheck: icon("exclamationmark.circle")
            }
        }
        .modifier(HoverLabel(text: words))
    }

    private var words: String {
        let version = updater.installedVersion
        switch updater.status {
        case .off: return "Pauri \(version), updates off"
        case .checking: return "Checking for updates"
        case .upToDate(let checkedAt): return "Pauri \(version) is up to date. Checked \(Self.ago(checkedAt, now: .now))."
        case .couldNotCheck: return "Pauri \(version), couldn't check for updates. Click to try again."
        }
    }

    private func icon(_ symbol: String) -> some View {
        Button { updater.checkNow() } label: { Image(systemName: symbol).font(.system(size: 12)) }
            .buttonStyle(.borderless)
    }

    private static func ago(_ date: Date, now: Date) -> String {
        now.timeIntervalSince(date) < 60 ? "just now" : date.formatted(.relative(presentation: .named))
    }
}

/// A tooltip the panel draws itself, under the view. `.help` never shows here: AppKit draws tooltips only for the
/// active app, and this panel never activates Pauri. `pinned` keeps it up without the pointer.
struct HoverLabel: ViewModifier {
    let text: String
    var pinned = false
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .onHover { isHovered = $0 }
            .overlay(alignment: .topTrailing) {
                if isHovered || pinned {
                    Text(text)
                        .font(.system(size: 11))
                        .fixedSize()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.16)))
                        .offset(y: 22)
                        .allowsHitTesting(false)
                }
            }
    }
}
