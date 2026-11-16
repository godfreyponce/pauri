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
}
