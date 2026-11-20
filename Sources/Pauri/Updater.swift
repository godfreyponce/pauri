import AppKit
import os
import Sparkle

enum UpdateStatus: Equatable {
    case off, checking, upToDate(checkedAt: Date), couldNotCheck
}

/// Sparkle's user driver: it gets every "show the user X" call and shows nothing.
/// The header's up-arrow and status icon are the only UI; Sparkle's "install?" reply waits for its click.
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

    /// Sparkle ends every check with an error; `SUNoUpdateError` is the "nothing newer" one, whatever its reason.
    nonisolated static func status(afterCycleError error: (any Error)?, at now: Date) -> UpdateStatus? {
        guard let error = error as NSError? else { return nil }
        if error.domain == SUSparkleErrorDomain && error.code == Int(SUError.noUpdateError.rawValue) {
            return .upToDate(checkedAt: now)
        }
        return .couldNotCheck
    }

    /// A local feed answers in milliseconds: hold Checking this long after a click so the spinner shows and a
    /// second click lands on it and is ignored. A guess, not measured.
    nonisolated static let minimumCheckingTime: Duration = .seconds(1)

    let installedVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    private(set) var status: UpdateStatus = .off
    private(set) var readyVersion: String?
    private(set) var isInstalling = false

    @ObservationIgnored private var updater: SPUUpdater?
    @ObservationIgnored private var feed: String?
    @ObservationIgnored private var installReply: ((SPUUserUpdateChoice) -> Void)?
    @ObservationIgnored private var checkNowStarted: ContinuousClock.Instant?

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
            Logger.pauri.error("Pauri: updater did not start: \(String(describing: error), privacy: .public)")
            return
        }
        if updater.automaticallyChecksForUpdates {
            status = .checking
            updater.checkForUpdatesInBackground()
        }
    }

    func checkNow() {
        guard let updater, readyVersion == nil, status != .checking else { return }
        status = .checking
        checkNowStarted = .now
        updater.checkForUpdates()
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

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        guard let status = Self.status(afterCycleError: error, at: .now) else { return }
        let started = checkNowStarted
        checkNowStarted = nil
        guard let started, started.duration(to: .now) < Self.minimumCheckingTime else {
            self.status = status
            return
        }
        Task {
            try? await Task.sleep(until: started + Self.minimumCheckingTime)
            self.status = status
        }
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
        Logger.pauri.error("Pauri: update failed: \(String(describing: error), privacy: .public)")
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
