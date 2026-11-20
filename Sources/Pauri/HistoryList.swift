import AppKit
import SwiftUI

/// Pauri's past chats as a palette over the whole panel: variant C of
/// `design-directions/issue-21.html`. Search, open, and delete, all from the keyboard.
struct HistoryList: View {
    let chat: Chat
    let close: () -> Void
    @State private var entries: [HistoryEntry]?
    @State private var problem: String?
    @State private var deleteProblem: String?
    @State private var query = ""
    @State private var selected = 0
    /// The row that asks "Delete for good?". One press never deletes; Codex deletes for good.
    @State private var confirming: String?
    @State private var isDeleting = false
    @FocusState private var searchFocused: Bool
    /// Where the pointer was when it last selected a row. A row that scrolls under a still pointer
    /// must not take the selection from the arrow keys.
    @State private var pointer = NSEvent.mouseLocation

    private var shown: [HistoryEntry] {
        (entries ?? []).filter { $0.matches(query) }
    }

    private var selectedEntry: HistoryEntry? {
        shown.indices.contains(selected) ? shown[selected] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search past chats", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
            }
            .font(.system(size: 15))
            .padding(14)
            if let deleteProblem {
                Text(deleteProblem)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }
            Divider()
            list
                .frame(maxHeight: .infinity, alignment: .top)
            Divider()
            footer
        }
        .background {
            Color(nsColor: .windowBackgroundColor).opacity(0.97).ignoresSafeArea()
        }
        .onAppear { searchFocused = true }
        .onChange(of: query) {
            selected = 0
            confirming = nil
        }
        .onChange(of: selected) { confirming = nil }
        .task {
            do {
                entries = try await chat.history()
            } catch {
                problem = Chat.message(for: error)
            }
        }
    }

    @ViewBuilder private var list: some View {
        if let problem {
            note(problem)
        } else if let entries {
            if entries.isEmpty {
                note("No chats yet.")
            } else if shown.isEmpty {
                note("No chat matches \"\(query.trimmingCharacters(in: .whitespacesAndNewlines))\".")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(shown.enumerated()), id: \.element.id) { index, entry in
                                row(entry, index: index)
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: selected) {
                        if let selectedEntry { proxy.scrollTo(selectedEntry.id) }
                    }
                }
            }
        } else {
            ProgressView()
                .controlSize(.small)
                .padding(16)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
    }

    private func row(_ entry: HistoryEntry, index: Int) -> some View {
        let isSelected = index == selected
        return Group {
            if confirming == entry.id {
                HStack(spacing: 8) {
                    Text("Delete for good?").font(.system(size: 12.5))
                    Spacer()
                    Button("Delete") { delete() }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                        .disabled(isDeleting)
                    Button("Cancel") { confirming = nil }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.title).lineLimit(1).truncationMode(.tail)
                        // Codex never names Pauri's chats, so the title already is the first message.
                        if entry.preview != entry.title {
                            Text(entry.preview)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    Text(Self.dateLabel(entry.updatedAt))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TrashButton { confirming = entry.id }
                        .opacity(isSelected ? 1 : 0)
                        .allowsHitTesting(isSelected)
                }
                .disabled(!chat.canStartNewChat)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isSelected ? AnyShapeStyle(.primary.opacity(0.08)) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 6))
        .zIndex(isSelected ? 1 : 0)
        .contentShape(Rectangle())
        .id(entry.id)
        .onHover { inside in
            guard inside, NSEvent.mouseLocation != pointer else { return }
            pointer = NSEvent.mouseLocation
            selected = index
        }
        .onTapGesture { open() }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            HStack(spacing: 4) {
                keyButton("↑", KeyboardShortcut(.upArrow, modifiers: [])) { move(-1) }
                keyButton("↓", KeyboardShortcut(.downArrow, modifiers: [])) { move(1) }
                Text("move")
            }
            HStack(spacing: 4) {
                keyButton("↩", .defaultAction, action: open)
                    .disabled(!chat.canStartNewChat)
                Text("open")
            }
            HStack(spacing: 4) {
                KeyCap(key: "⌘")
                keyButton("⌫", KeyboardShortcut(.delete, modifiers: .command), action: pressDelete)
                Text("delete")
            }
            .disabled(!chat.canStartNewChat)
            HStack(spacing: 4) {
                keyButton("esc", .cancelAction, action: back)
                Text("back")
            }
            Spacer()
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
    }

    /// Footer key caps are buttons with key equivalents, which AppKit runs before the search field
    /// sees the key: Esc never reaches the panel's cancelOperation, which would hide it.
    private func keyButton(_ cap: String, _ shortcut: KeyboardShortcut,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) { KeyCap(key: cap) }
            .buttonStyle(.plain)
            .keyboardShortcut(shortcut)
    }

    private func move(_ step: Int) {
        guard !shown.isEmpty else { return }
        selected = min(max(selected + step, 0), shown.count - 1)
    }

    private func open() {
        guard confirming == nil, !isDeleting, chat.canStartNewChat, let entry = selectedEntry else { return }
        chat.open(entry.id)
        close()
    }

    private func back() {
        if confirming != nil {
            confirming = nil
        } else {
            close()
        }
    }

    /// The first press asks; a second press on the same row deletes.
    private func pressDelete() {
        // A held Cmd+Delete repeats; one physical press must never both ask and delete.
        // isARepeat raises on a mouse event, such as a click on the key cap.
        if let event = NSApp.currentEvent, event.type == .keyDown, event.isARepeat { return }
        guard chat.canStartNewChat, let entry = selectedEntry else { return }
        if confirming == entry.id {
            delete()
        } else {
            confirming = entry.id
        }
    }

    private func delete() {
        guard let id = confirming, !isDeleting, chat.canStartNewChat else { return }
        isDeleting = true
        deleteProblem = nil
        Task {
            do {
                try await chat.delete(id)
                entries?.removeAll { $0.id == id }
                confirming = nil
                selected = min(selected, max(shown.count - 1, 0))
            } catch {
                deleteProblem = Chat.message(for: error)
            }
            isDeleting = false
        }
    }

    /// Today's time, `Yesterday`, or the month and day, with the year when it is not this year.
    private static func dateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return date.formatted(date: .omitted, time: .shortened) }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if calendar.isDate(date, equalTo: .now, toGranularity: .year) {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}

private struct TrashButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(.system(size: 14))
                .foregroundStyle(isHovered ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                .padding(2)
                .background(isHovered ? AnyShapeStyle(.primary.opacity(0.08)) : AnyShapeStyle(.clear),
                            in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .modifier(HoverLabel(text: "Delete chat"))
        .onHover { isHovered = $0 }
    }
}
