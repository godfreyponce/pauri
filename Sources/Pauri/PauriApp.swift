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
        let hotKey = HotKey { [weak self] in self?.panel?.toggle() }
        self.hotKey = hotKey
        panel = PanelController(hotKey: hotKey, chat: chat)
    }

    /// Opening Pauri again shows the panel: the way back in when a new shortcut never arrives.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel?.show()
        return false
    }
}
