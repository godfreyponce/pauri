import AppKit
import Sparkle

/// Sparkle's user driver: it gets every "show the user X" call and shows nothing.
/// The header button is the only UI; Sparkle's "install?" reply waits for its click.
@MainActor
@Observable
final class Updater: NSObject, SPUUserDriver, SPUUpdaterDelegate {
    nonisolated static let releaseKey = "PauriChecksForUpdates"
    nonisolated static let testFeedKey = "PauriTestFeedURL"
    nonisolated static let showPanelAfterUpdateKey = "PauriShowPanelAfterUpdate"

    nonisolated static func feed(infoPlist: [String: Any], testFeed: String?) -> String? {
        if let testFeed { return testFeed }
        guard infoPlist[releaseKey] as? Bool == true else { return nil }
        return infoPlist["SUFeedURL"] as? String
    }

    /// Sparkle relaunches with a plain `open`, so the new process knows it came from an update only through this note.
    nonisolated static func markRelaunching(_ defaults: UserDefaults) {
        defaults.set(true, forKey: showPanelAfterUpdateKey)
    }

    nonisolated static func takeRelaunchedFromUpdate(_ defaults: UserDefaults) -> Bool {
        let relaunched = defaults.bool(forKey: showPanelAfterUpdateKey)
        defaults.removeObject(forKey: showPanelAfterUpdateKey)
        return relaunched
    }

    private(set) var readyVersion: String?
    private(set) var isInstalling = false

    @ObservationIgnored private var updater: SPUUpdater?
    @ObservationIgnored private var feed: String?
    @ObservationIgnored private var installReply: ((SPUUserUpdateChoice) -> Void)?

    func start() {
        feed = Self.feed(
            infoPlist: Bundle.main.infoDictionary ?? [:],
            testFeed: UserDefaults.standard.string(forKey: Self.testFeedKey))
        guard feed != nil else { return }
        let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: self, delegate: self)
        self.updater = updater
        do {
            try updater.start()
        } catch {
            NSLog("Pauri: updater did not start: %@", "\(error)")
            return
        }
        if updater.automaticallyChecksForUpdates {
            updater.checkForUpdatesInBackground()
        }
    }

    func install() {
        guard let reply = installReply else { return }
        installReply = nil
        isInstalling = true
        reply(.install)
    }

    // MARK: SPUUpdaterDelegate

    func feedURLString(for updater: SPUUpdater) -> String? { feed }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        Self.markRelaunching(.standard)
    }

    // MARK: SPUUserDriver

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        installReply = reply
        readyVersion = appcastItem.displayVersionString
    }

    /// The user already clicked the header button.
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        reply(.install)
    }

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        NSLog("Pauri: update failed: %@", "\(error)")
        acknowledgement()
    }

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    func dismissUpdateInstallation() {
        installReply = nil
        readyVersion = nil
        isInstalling = false
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {}
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {}
    func showDownloadInitiated(cancellation: @escaping () -> Void) {}
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}
    func showDownloadDidReceiveData(ofLength length: UInt64) {}
    func showDownloadDidStartExtractingUpdate() {}
    func showExtractionReceivedProgress(_ progress: Double) {}
    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {}
}
