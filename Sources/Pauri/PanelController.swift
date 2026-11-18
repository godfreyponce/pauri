import AppKit
import SwiftUI

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let panel: FloatingPanel
    private let zoomScale: ZoomScale
    private var zoom: Int

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
        zoom = PanelZoom.saved(in: .standard)
        zoomScale = ZoomScale(PanelZoom.scale(zoom))
        let host = NSHostingView(rootView: ZoomedContent(zoom: zoomScale) {
            PanelView(hotKey: hotKey, chat: chat, updater: updater)
        })
        host.frame = glass.bounds
        host.autoresizingMask = [.width, .height]
        glass.addSubview(host)
        let minimum = PanelZoom.minimumFrame(at: zoom)
        panel.minSize = minimum
        let saved = PanelSize.saved(in: .standard)
        panel.setFrame(NSRect(origin: .zero,
                              size: PanelSize.clamped(saved, to: NSScreen.main?.visibleFrame.size ?? saved, minimum: minimum)),
                       display: false)
        panel.center()
        super.init()
        panel.onZoomKey = { [weak self] command in self?.applyZoom(command) }
        // Set last, so the launch sizing above is not saved.
        panel.delegate = self
    }

    private func applyZoom(_ command: PanelZoom.Command) {
        let next = PanelZoom.applied(command, to: zoom, frame: panel.frame.size)
        guard next != zoom else { return }
        zoom = next
        zoomScale.value = PanelZoom.scale(next)
        panel.minSize = PanelZoom.minimumFrame(at: next)
        PanelZoom.save(next, to: .standard)
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        PanelSize.clamped(frameSize, to: sender.screen?.visibleFrame.size ?? frameSize, minimum: PanelZoom.minimumFrame(at: zoom))
    }

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
    var onZoomKey: ((PanelZoom.Command) -> Void)?

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }

    /// `.resizable` turns on the zoom button and a title-bar double-click; a zoom would move the panel.
    override func zoom(_ sender: Any?) {}

    /// Checked before `super`, so `=`, `-`, and `0` never reach a focused text field.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let command = PanelZoom.command(characters: event.charactersIgnoringModifiers, flags: event.modifierFlags)
        else { return super.performKeyEquivalent(with: event) }
        onZoomKey?(command)
        return true
    }
}

@MainActor @Observable
final class ZoomScale {
    var value: CGFloat
    init(_ value: CGFloat) { self.value = value }
}

/// The zoom lives in SwiftUI so the hosting view's bounds always equal its frame: AppKit bounds
/// scaling (#38's `ZoomView`) drew the buttons in one place and hit-tested them in another (#41).
struct ZoomedContent<Content: View>: View {
    let zoom: ZoomScale
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            content
                .frame(width: proxy.size.width / zoom.value, height: proxy.size.height / zoom.value)
                .scaleEffect(zoom.value, anchor: .topLeading)
        }
    }
}
