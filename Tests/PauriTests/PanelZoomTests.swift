import AppKit
import Testing
@testable import Pauri

struct PanelZoomTests {
    private let frame = CGSize(width: 520, height: 680)

    private func withScratchDefaults(_ body: (String) -> Void) {
        let name = "PauriTests-\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: name) }
        body(name)
    }

    @Test func keyCommand() {
        #expect(PanelZoom.command(characters: "=", flags: .command) == .zoomIn)
        #expect(PanelZoom.command(characters: "+", flags: [.command, .shift]) == .zoomIn)
        #expect(PanelZoom.command(characters: "+", flags: [.command, .numericPad]) == .zoomIn)
        #expect(PanelZoom.command(characters: "-", flags: .command) == .zoomOut)
        #expect(PanelZoom.command(characters: "-", flags: [.command, .numericPad]) == .zoomOut)
        #expect(PanelZoom.command(characters: "0", flags: .command) == .reset)
        #expect(PanelZoom.command(characters: "0", flags: [.command, .numericPad]) == .reset)
        #expect(PanelZoom.command(characters: "=", flags: []) == nil)
        #expect(PanelZoom.command(characters: "=", flags: [.command, .option]) == nil)
        #expect(PanelZoom.command(characters: "0", flags: []) == nil)
        #expect(PanelZoom.command(characters: "k", flags: .command) == nil)
        #expect(PanelZoom.command(characters: nil, flags: .command) == nil)
    }

    @Test func stepInAndOut() {
        #expect(PanelZoom.applied(.zoomIn, to: 100, frame: frame) == 110)
        #expect(PanelZoom.applied(.zoomOut, to: 100, frame: frame) == 90)
    }

    @Test func stopsAtLimits() {
        #expect(PanelZoom.applied(.zoomIn, to: 200, frame: CGSize(width: 1440, height: 875)) == 200)
        #expect(PanelZoom.applied(.zoomOut, to: 80, frame: frame) == 80)
    }

    @Test func resetGoesToDefault() {
        #expect(PanelZoom.applied(.reset, to: 150, frame: frame) == 100)
    }

    @Test func zoomInNeedsRoom() {
        #expect(PanelZoom.applied(.zoomIn, to: 100, frame: CGSize(width: 280, height: 280)) == 100)
        #expect(PanelZoom.applied(.zoomIn, to: 180, frame: frame) == 180)
        #expect(PanelZoom.applied(.zoomIn, to: 170, frame: frame) == 180)
    }

    @Test func zoomOutAndResetNeedNoRoom() {
        let small = CGSize(width: 280, height: 280)
        #expect(PanelZoom.applied(.zoomOut, to: 200, frame: small) == 190)
        #expect(PanelZoom.applied(.reset, to: 200, frame: small) == 100)
    }

    @Test func minimumFrameGrowsWithZoom() {
        #expect(PanelZoom.minimumFrame(at: 80) == CGSize(width: 280, height: 280))
        #expect(PanelZoom.minimumFrame(at: 100) == CGSize(width: 280, height: 280))
        #expect(PanelZoom.minimumFrame(at: 150) == CGSize(width: 420, height: 420))
        #expect(PanelZoom.minimumFrame(at: 200) == CGSize(width: 560, height: 560))
    }

    @Test func nothingSavedGivesDefaultZoom() {
        withScratchDefaults { name in
            #expect(PanelZoom.saved(in: UserDefaults(suiteName: name)!) == 100)
        }
    }

    @Test func savedZoomSurvivesRelaunch() {
        withScratchDefaults { name in
            PanelZoom.save(150, to: UserDefaults(suiteName: name)!)
            #expect(PanelZoom.saved(in: UserDefaults(suiteName: name)!) == 150)
        }
    }

    @Test func badSavedZoomGivesDefault() {
        withScratchDefaults { name in
            let defaults = UserDefaults(suiteName: name)!
            defaults.set("big", forKey: PanelZoom.key)
            #expect(PanelZoom.saved(in: defaults) == 100)
            defaults.set(1.5, forKey: PanelZoom.key)
            #expect(PanelZoom.saved(in: defaults) == 100)
        }
    }

    @Test func outOfRangeSavedZoomIsClamped() {
        withScratchDefaults { name in
            let defaults = UserDefaults(suiteName: name)!
            defaults.set(500, forKey: PanelZoom.key)
            #expect(PanelZoom.saved(in: defaults) == 200)
            defaults.set(10, forKey: PanelZoom.key)
            #expect(PanelZoom.saved(in: defaults) == 80)
        }
    }
}
