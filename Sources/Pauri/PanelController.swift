import AppKit
import SwiftUI

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let panel: FloatingPanel

    init(hotKey: HotKey, chat: Chat, updater: Updater) {
        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 680),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
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
        let content = NSHostingView(rootView: PanelView(hotKey: hotKey, chat: chat, updater: updater))
        content.frame = glass.bounds
        content.autoresizingMask = [.width, .height]
        glass.addSubview(content)
        panel.minSize = PanelSize.minimum
        let saved = PanelSize.saved(in: .standard)
        panel.setFrame(NSRect(origin: .zero, size: PanelSize.clamped(saved, to: NSScreen.main?.visibleFrame.size ?? saved)),
                       display: false)
        panel.center()
        super.init()
        // Set last, so the launch sizing above is not saved.
        panel.delegate = self
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        PanelSize.clamped(frameSize, to: sender.screen?.visibleFrame.size ?? frameSize)
    }

    /// Saves a drag and a Cmd+ / Cmd- step alike: `setFrame` posts this too.
    func windowDidResize(_ notification: Notification) {
        PanelSize.save(panel.frame.size, to: .standard)
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

    /// `.resizable` turns on the zoom button and a title-bar double-click; a zoom would move the panel.
    override func zoom(_ sender: Any?) {}

    /// Checked before `super`, so `=` and `-` never reach a focused text field.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let direction = PanelSize.direction(characters: event.charactersIgnoringModifiers, flags: event.modifierFlags)
        else { return super.performKeyEquivalent(with: event) }
        guard let visible = (screen ?? NSScreen.main)?.visibleFrame else { return true }
        let size = PanelSize.stepped(frame.size, by: direction, screen: visible.size)
        setFrame(PanelSize.frame(frame, resizedTo: size, within: visible), display: true)
        return true
    }
}
