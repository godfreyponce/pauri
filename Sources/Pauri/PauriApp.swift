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
    private let updater = Updater()
    private var statusItem: NSStatusItem?
    private let statusMenu: NSMenu = {
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit Pauri", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let chat = Chat(client: CodexClient())
        chat.warmUp()
        self.chat = chat
        let hotKey = HotKey { [weak self] in self?.togglePanel() }
        self.hotKey = hotKey
        updater.start()
        panel = PanelController(hotKey: hotKey, chat: chat, updater: updater)
        if Updater.takeRelaunchedFromUpdate(.standard) {
            panel?.show()
        }
        statusItem = makeStatusItem()
    }

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let image = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "svg").flatMap(NSImage.init(contentsOf:))
        image?.size = NSSize(width: 16.0 * 96 / 102, height: 16)
        image?.isTemplate = true
        image?.accessibilityDescription = "Pauri"
        item.button?.image = image
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        return item
    }

    /// The menu is attached only for this one click; left attached, every left click would open it.
    /// A VoiceOver press arrives with no mouse event and toggles, like a left click.
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp
            || (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true)
        if wantsMenu {
            statusItem?.menu = statusMenu
            sender.performClick(nil)
            statusItem?.menu = nil
        } else {
            togglePanel()
        }
    }

    /// Hides only when the panel has focus; a press while another app has focus brings it back,
    /// with that app's selection. The only place the selection is read.
    func togglePanel() {
        guard let panel, let chat else { return }
        if panel.isKey {
            panel.hide()
        } else {
            chat.selection = SelectionGrabber.selectedText()
            panel.show()
        }
    }

    /// Opening Pauri again shows the panel: the way back in when a new shortcut never arrives.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel?.show()
        return false
    }
}
