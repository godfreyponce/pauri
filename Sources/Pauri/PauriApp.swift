import AppKit
import SwiftUI

@main
struct PauriApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: PanelController?
    private var hotKey: HotKey?
    private var chat: Chat?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let chat = Chat(client: CodexClient())
        chat.warmUp()
        self.chat = chat
        panel = PanelController(chat: chat)
        hotKey = HotKey(shortcut: .default) { [weak self] in self?.panel?.toggle() }
    }
}
