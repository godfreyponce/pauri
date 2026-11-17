import AppKit
import Testing
@testable import Pauri

struct PanelSizeTests {
    private let screen = CGSize(width: 1440, height: 875)

    private func withScratchDefaults(_ body: (String) -> Void) {
        let name = "PauriTests-\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: name) }
        body(name)
    }

    @Test func clampedKeepsSizeInRange() {
        #expect(PanelSize.clamped(CGSize(width: 600, height: 700), to: screen) == CGSize(width: 600, height: 700))
    }

    @Test func clampedRaisesToMinimum() {
        #expect(PanelSize.clamped(CGSize(width: 100, height: 50), to: screen) == PanelSize.minimum)
    }

    @Test func clampedRaisesToGivenMinimum() {
        #expect(PanelSize.clamped(CGSize(width: 300, height: 300), to: screen, minimum: CGSize(width: 420, height: 420))
            == CGSize(width: 420, height: 420))
    }

    @Test func clampedCapsAtScreen() {
        #expect(PanelSize.clamped(CGSize(width: 3000, height: 2000), to: screen) == screen)
    }

    @Test func nothingSavedGivesDefaultSize() {
        withScratchDefaults { name in
            #expect(PanelSize.saved(in: UserDefaults(suiteName: name)!) == PanelSize.default)
        }
    }

    @Test func savedSizeSurvivesRelaunch() {
        withScratchDefaults { name in
            PanelSize.save(CGSize(width: 600, height: 700), to: UserDefaults(suiteName: name)!)
            #expect(PanelSize.saved(in: UserDefaults(suiteName: name)!) == CGSize(width: 600, height: 700))
        }
    }

    @Test func badSavedSizeGivesDefault() {
        withScratchDefaults { name in
            let defaults = UserDefaults(suiteName: name)!
            defaults.set("big", forKey: PanelSize.key)
            #expect(PanelSize.saved(in: defaults) == PanelSize.default)
            defaults.set(["width": 600.0], forKey: PanelSize.key)
            #expect(PanelSize.saved(in: defaults) == PanelSize.default)
        }
    }

    @MainActor
    @Test func zoomLeavesPanelFrameAlone() {
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 680),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false)
        let before = NSRect(x: 100, y: 100, width: 520, height: 680)
        panel.setFrame(before, display: false)
        panel.zoom(nil)
        #expect(panel.frame == before)
    }
}
