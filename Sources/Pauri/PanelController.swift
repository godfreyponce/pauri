import AppKit
import SwiftUI

@MainActor
final class PanelController {
    private let panel: FloatingPanel

    init(hotKey: HotKey, chat: Chat) {
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
        let glass = NSVisualEffectView()
        glass.material = .popover
        glass.blendingMode = .behindWindow
        // Pauri never becomes the active app; following the active state would draw the flat inactive look.
        glass.state = .active
        panel.contentView = glass
        let content = NSHostingView(rootView: PanelView(hotKey: hotKey, chat: chat))
        content.frame = glass.bounds
        content.autoresizingMask = [.width, .height]
        glass.addSubview(content)
        panel.center()
    }

    var isKey: Bool { panel.isKeyWindow }

    /// No `NSApp.activate`: the app behind stays the active app.
    func show() {
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
    }
}

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}
