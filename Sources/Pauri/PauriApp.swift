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

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = PanelController()
        hotKey = HotKey(shortcut: .default) { [weak self] in self?.panel?.toggle() }
    }
}
