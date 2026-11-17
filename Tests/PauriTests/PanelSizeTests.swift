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

    @Test func clampedCapsAtScreen() {
        #expect(PanelSize.clamped(CGSize(width: 3000, height: 2000), to: screen) == screen)
    }

    @Test func stepGrowsAndShrinksByOneStep() {
        #expect(PanelSize.stepped(PanelSize.default, by: 1, screen: screen) == CGSize(width: 572, height: 748))
        #expect(PanelSize.stepped(PanelSize.default, by: -1, screen: screen) == CGSize(width: 468, height: 612))
    }

    @Test func stepStopsAtMinimum() {
        #expect(PanelSize.stepped(PanelSize.minimum, by: -1, screen: screen) == PanelSize.minimum)
    }

    @Test func stepStopsAtScreen() {
        #expect(PanelSize.stepped(screen, by: 1, screen: screen) == screen)
    }

    @Test func resizedFrameKeepsTopLeft() {
        let visible = NSRect(x: 0, y: 25, width: 1440, height: 875)
        let current = NSRect(x: 100, y: 100, width: 520, height: 680)
        #expect(PanelSize.frame(current, resizedTo: CGSize(width: 572, height: 748), within: visible)
            == NSRect(x: 100, y: 32, width: 572, height: 748))
    }

    @Test func resizedFrameStaysOnScreen() {
        let visible = NSRect(x: 0, y: 25, width: 1440, height: 875)
        let nearCorner = NSRect(x: 900, y: 25, width: 520, height: 680)
        #expect(PanelSize.frame(nearCorner, resizedTo: CGSize(width: 572, height: 748), within: visible)
            == NSRect(x: 868, y: 25, width: 572, height: 748))
    }

    @Test func keyDirection() {
        #expect(PanelSize.direction(characters: "=", flags: .command) == 1)
        #expect(PanelSize.direction(characters: "+", flags: [.command, .shift]) == 1)
        #expect(PanelSize.direction(characters: "+", flags: [.command, .numericPad]) == 1)
        #expect(PanelSize.direction(characters: "-", flags: .command) == -1)
        #expect(PanelSize.direction(characters: "-", flags: [.command, .numericPad]) == -1)
        #expect(PanelSize.direction(characters: "=", flags: []) == nil)
        #expect(PanelSize.direction(characters: "=", flags: [.command, .option]) == nil)
        #expect(PanelSize.direction(characters: "k", flags: .command) == nil)
        #expect(PanelSize.direction(characters: nil, flags: .command) == nil)
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
