import AppKit
import SwiftUI

@MainActor
final class PanelController {
    private let panel: FloatingPanel

    init(chat: Chat) {
        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 680),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: PanelView(chat: chat))
        panel.center()
    }

    /// Hides only when the panel has focus; a press while another app has focus brings it back.
    func toggle() {
        panel.isKeyWindow ? hide() : show()
    }

    /// No `NSApp.activate`: the app behind stays the active app.
    func show() {
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
    }
}

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}
