import SwiftUI

/// Pauri's past chats, last updated first. Plain on purpose; #22 restyles it and adds search and delete.
struct HistoryList: View {
    let chat: Chat
    let close: () -> Void
    @State private var entries: [HistoryEntry]?
    @State private var problem: String?

    var body: some View {
        Group {
            if let problem {
                Text(problem).foregroundStyle(.secondary)
            } else if let entries {
                if entries.isEmpty {
                    Text("No chats yet.").foregroundStyle(.secondary)
                } else {
                    List(entries) { entry in
                        Button {
                            chat.open(entry.id)
                            close()
                        } label: {
                            HStack {
                                Text(entry.title).lineLimit(1)
                                Spacer()
                                Text(entry.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!chat.canStartNewChat)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .frame(width: 320, height: 360)
        .padding()
        .task {
            do {
                entries = try await chat.history()
            } catch {
                problem = Chat.message(for: error)
            }
        }
    }
}
