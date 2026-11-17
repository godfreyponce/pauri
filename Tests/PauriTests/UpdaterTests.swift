import AppKit
import Testing
@testable import Pauri

struct UpdaterTests {
    private let supportInfoPlist: [String: Any] = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Support/Info.plist")
        return NSDictionary(contentsOf: url) as! [String: Any]
    }()

    @Test func devBuildNeverChecks() {
        #expect(Updater.feed(infoPlist: supportInfoPlist, testFeed: nil) == nil)
    }

    @Test func releaseBuildChecksTheGitHubFeed() {
        var plist = supportInfoPlist
        plist[Updater.releaseKey] = true
        #expect(Updater.feed(infoPlist: plist, testFeed: nil)
            == "https://github.com/godfreyponce/pauri/releases/latest/download/appcast.xml")
    }

    @Test func testFeedPointsAnyBuildAtIt() {
        #expect(Updater.feed(infoPlist: supportInfoPlist, testFeed: "http://localhost:8123/appcast.xml")
            == "http://localhost:8123/appcast.xml")
    }

    private func scratchDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "PauriTests.\(name)")!
        defaults.removePersistentDomain(forName: "PauriTests.\(name)")
        return defaults
    }

    @Test func ordinaryLaunchStaysHidden() {
        let defaults = scratchDefaults("ordinaryLaunch")
        #expect(Updater.takeRelaunchedFromUpdate(defaults) == false)
    }

    @Test func relaunchFlagShowsOnce() {
        let defaults = scratchDefaults("relaunchOnce")
        Updater.markRelaunching(defaults)
        #expect(Updater.takeRelaunchedFromUpdate(defaults) == true)
        #expect(Updater.takeRelaunchedFromUpdate(defaults) == false)
    }
}
