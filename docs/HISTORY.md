# pauri — Build History

Accepted-work archive. One section per accepted ticket, appended at the accept-time docs commit.
Newest first.

## #31 Pauri's log lines readable in `log show` (2026-11-19)

- `Sources/Pauri/Log.swift` declares `Logger.pauri` (subsystem `io.github.godfreyponce.pauri`,
  category `app`). The five `NSLog` lines (first token, updater did not start, update failed,
  two hotkey registration failures) now use it, with every value `privacy: .public`. None of
  them carries a question, an answer, or a selection. First token is `notice`; the rest are
  `error`. A Sparkle error's text is public too, so a path with the account name can show.
- Read them with `/usr/bin/log show --last 5m --predicate 'subsystem == "io.github.godfreyponce.pauri"'`.
  In zsh, a bare `log` is a builtin and fails.
- Hand checks (built app, driven through System Events): H1 showed a `Default` line
  `Pauri: first token after 1867 ms`, with no question text and no `<private>`; H2 (test feed
  `http://localhost:9/appcast.xml`, click on the update status icon) showed an `Error` line
  `Pauri: update failed: Error Domain=SUSparkleErrorDomain Code=2001 ...` in readable text. A
  background check at launch logs nothing; only a clicked check reaches `showUpdaterError`.
  The hotkey lines have no hand check. No new unit test (an in-process test cannot see the
  redaction). Tests 145/145 (`./scripts/test.sh && ./scripts/build-app.sh`).

## #42 The Orbit P in the menu bar (2026-11-18)

- `AppDelegate` (`PauriApp.swift`) makes one `NSStatusItem`. Its image is
  `Support/MenuBarIcon.svg` (the owner's Orbit P, `viewBox` cropped to the glyph), loaded by
  `NSImage` as SVG, 16 pt tall and 16 x 96 / 102 pt wide, `isTemplate`. `build-app.sh` copies
  it into the bundle.
- Left click calls `togglePanel()` (was `hotKeyPressed()`), so it hides with focus and
  otherwise shows with the front app's selection, like the hotkey. A VoiceOver press has no
  mouse event and toggles too. Right-click or Control-click opens a menu with Quit Pauri only.
- Hand checks (synthetic clicks on the built app): glyph light on a dark menu bar, no Dock
  icon; clicks 2 s apart toggled show and hide; right-click and Control-click open the menu
  without a toggle; Quit Pauri ends Pauri and its codex child; Cmd+Q quits with the panel
  focused; the relaunch-after-update flag shows the panel at launch. Left to the owner's hand
  check at gate 2, because synthetic focus results were noisy while the Mac was in use: the
  light menu bar, the selection on click, and Esc. 1x renders soft at the stem's edges (3.1 px
  stem); 2x is clean.
- Plan fix: `NSSize(width: 16 * 96 / 102, ...)` picked the `Int` initializer (width 15), so
  the code says `16.0 * 96 / 102`.
- Final review: the VoiceOver press did nothing (a guard on a nil `NSApp.currentEvent`),
  fixed. Deferred minors: README's "Press it again" reads as the hotkey only; no fallback
  image if the SVG is missing.
- No new unit test (AppKit glue only). Tests 145/145, twenty live tests skipped
  (`./scripts/test.sh && ./scripts/build-app.sh`). Commit eb19a8d.

## #41 The up-arrow click installs the update at any zoom (2026-11-18)

- Cause: #38's `ZoomView` scaled the hosting view's bounds in AppKit. At any zoom other than
  100 %, SwiftUI hit-tested in other places than it drew: at 110 % a hover on the up-arrow
  showed the "New chat" label, and no header button reacted to a click. At 100 % the same
  click installed the update. Copies on 0.1.4 and 0.1.5 still have the bug: Cmd+0, then the
  up-arrow, or `brew upgrade --cask pauri`.
- Fix: `ZoomView` is gone. `ZoomedContent` (`PanelController.swift`) lays the panel out in
  `size / zoom` inside a `GeometryReader` and draws it with `.scaleEffect(zoom, anchor:
  .topLeading)`; `ZoomScale` is observed, so a zoom change keeps the panel's state. AppKit now
  sees an unscaled hosting view at every zoom. The zoom's rules (#38) and the resize (#37) are
  unchanged.
- Proof: local feed, 0.1.0 to a fixed 0.9.0. The owner's up-arrow click installed at 110, 150,
  100 and 80 % (four `GET /Pauri-0.9.0.zip`), the check-mark checked at 110 %, and the panel
  checks at 150 % passed (title bar, drag, popovers, clicks, text selection, live zoom with
  state, resize, 80 to 200 %).
- The owner sees softer text when zoomed in; he picked shipping the click fix now. Zoom like
  ChatGPT classic (bigger chat text in a real font, the header and toolbar fixed) is the
  follow-up.
- `zoomViewGivesContentScaledRoom` became `zoomedContentGivesContentScaledRoom`.
- Final review: no Critical or Important findings. Deferred minors: at 80 to 90 % with low
  transparency, a thin strip above the header may show no tint; the unit test pins layout, not
  where a click lands (hand checks only).
- Tests 145/145, twenty live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`).
  Commit 034a29c.

## #39 Your messages stand apart from Pauri's answers (2026-11-17)

- The user's message is now a grey rounded bubble on the right, and Pauri's answer runs the
  full width under it: variant E of `design-directions/issue-39.html`. The owner picked it from a
  screenshot of a chat app after seeing variants A to D (tinted band, accent bar, accent ink, two
  speakers), which stay on the page as the record.
- This replaces #21 variant C's labeled row: the YOU label, the 44 pt label column, the answer's
  indent, and the divider between exchanges are gone. Header, orb, input area, and model picker
  are unchanged.
- `QuestionRow` became `QuestionBubble` (`PanelView.swift`): plain `Text`, regular weight, fill
  `.primary.opacity(0.10)`, padding 9 x 12, radius 16, at most 75 % of the transcript wide (the
  same `containerRelativeFrame` chain as #16's bubble). Gaps: 12 pt question to answer, 20 pt
  between exchanges. All sizes are first guesses judged by eye.
- The owner's screenshot is not in the repo: it held private chat text.
- Final review: no Critical or Important findings. Deferred minors: `docs/spec.md:43` still
  names #16 variant A; the 10 % fill may wash out on the most transparent glass (H3); tool steps
  and the approval card now start at the left edge.
- No new test: look only. Hand check H1 to H6 by the owner at gate 2.
- Tests 145/145, twenty live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`).
  Commits 3010e46, 2baf23c, b6b05ba.

## #35 Header icons show hover labels (2026-11-17)

- The panel header's search, new chat, and settings icons now use #34's `HoverLabel` in place
  of `.help`, which never showed because the nonactivating panel never activates Pauri.
- Words unchanged: "Past chats (⌘K)", "New chat", "Settings". The search label names its
  shortcut again, which the header lost when #34 removed the `⌘K` text.
- The new chat label sits outside `.disabled`, so it shows while an answer streams.
- Final review: no Critical or Important findings. It left one hand check open: whether the
  "Settings" label stays up after the click opens the popover.
- The app's other `.help` calls have the same bug; filed as #40, not touched here.
- No new test: hover has none. Hand check by the owner at gate 2.
- Tests 145/145, twenty live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`).
  Commit abf1e28.

## #38 Cmd+ and Cmd- zoom the panel's content, not its size (2026-11-17)

- Corrects #37: Cmd+ / Cmd= zoom the panel's content in, Cmd- out, Cmd+0 back to 100%, like a
  browser, with focus anywhere in the panel. The window's size does not change. Dragging the
  edges still resizes (#37).
- `ZoomView` (`PanelController.swift`) sits between the glass and the `NSHostingView`: its bounds
  are `frame / zoom` and it sets the host's frame to its bounds, so SwiftUI lays out in the
  smaller room and AppKit draws it `zoom` times as big. Text is a little softer away from 100%
  (SwiftUI's 2x text bitmaps are stretched); symbols stay sharp.
- The rules live in `PanelZoom` (`Sources/Pauri/PanelZoom.swift`): 80% to 200%, step 10%, stored
  as an Int percent under `panelZoom`. Above 100% the smallest window is 280 x 280 times the
  zoom, and Cmd+ does nothing when the window is too small for the next step.
  Reset: `defaults delete io.github.godfreyponce.pauri panelZoom`.
- Removed #37's key-resize code: `PanelSize.step`, `stepped`, `frame(_:resizedTo:within:)`,
  `direction`, and their six tests.
- Final review: no code findings. It asked for one more hand check, the header's gap under the
  title bar at 150% and 200%.
- Hand check: no per-item results reported; the owner accepted at gate 2 ("accepted, land it").
- Deferred minors from the final review: `zoomViewGivesContentScaledRoom` uses a plain `NSView`,
  so it proves the frame math, not that `NSHostingView` lays out again; on a screen smaller than
  the zoom's smallest window, the window opens below that size (Cmd- still works); a saved size
  below the zoom's smallest window is raised at launch but not saved back until the next drag.
- Tests 145/145, twenty live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`).
  Commits 2d2c75e, 2adf08a; merge 53eb7f1.

## #37 Resize the panel by dragging or with Cmd+ and Cmd-, and remember the size (2026-11-17)

- The panel is `.resizable`: drag an edge or a corner. Cmd+ or Cmd= makes it one step bigger,
  Cmd- one step smaller, with focus anywhere in the panel; `FloatingPanel.performKeyEquivalent`
  takes the three keys before a text field sees them. A key step keeps the top-left corner and
  moves the panel only as far as needed to stay on the screen. No animation.
- The rules live in `PanelSize` (`Sources/Pauri/PanelSize.swift`): default 520 x 680, minimum
  280 x 280 (measured `PanelView` 251 x 156, plus the Blossom logo, an 8-line draft, and an
  assumed 28 pt title-bar inset), step 52 x 68 (a tenth of the default, a guess), maximum the
  `visibleFrame` of the panel's screen. All sizes are frame sizes.
- The size is saved under `panelSize` (`{"width", "height"}`) in `windowDidResize`, which covers
  a drag and a key step. Only the size is saved: the panel still opens centered on the main
  screen. At launch a saved size larger than the main screen is cut to fit, and not saved back.
  Reset: `defaults delete io.github.godfreyponce.pauri panelSize`.
- Final review found that `.resizable` turned on zoom (the green button and a title-bar
  double-click), which moved the panel to fill the screen and saved that size.
  `FloatingPanel.zoom(_:)` now does nothing (test `zoomLeavesPanelFrameAlone`).
- Hand check: the owner accepted at gate 2 without reporting the results of plan step 7.
- Deferred minors from the final review: `windowDidResize` writes UserDefaults on every drag
  frame; Cmd+ can shrink the panel on a screen smaller than its size; the `minimum` comment
  reads as fully measured; no test for `frame(...)` above the top or left of the screen, or a
  screen smaller than the minimum.
- Tests 137/137, twenty live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`).
  Commits 6ba200a, 74a41c3, 73f63da; merge 5faf249.

## #34 Show that Pauri is up to date (2026-11-16)

- Variant A1 of `design-directions/issue-34.html` (the owner picked A, then A1 from four ways
  to thin A's header): with no update ready, a status icon takes the up-arrow's slot, and the
  `⌘K` label next to the search icon is gone. Check mark: up to date. Spinner: checking.
  Exclamation mark: couldn't check (offline, feed error, failed download). Dim dash: updates
  off (dev build). A click on the check mark or the exclamation mark checks now. The up-arrow
  still wins over every other state.
- `Updater` gained `status` (`off`, `checking`, `upToDate(checkedAt:)`, `couldNotCheck`),
  `installedVersion` (`CFBundleShortVersionString`) and `checkNow()`. The status comes from
  `updater(_:didFinishUpdateCycleFor:error:)`: Sparkle's `SUNoUpdateError` (1001) is up to date,
  any other error is couldn't check, and `nil` leaves the status alone.
  `showUpdateNotFoundWithError` fires only for user-started checks, so it could not be the hook.
- `.help` tooltips never show in the panel: AppKit draws tooltips only for the active app, and
  the nonactivating panel never activates Pauri. The status words are a `HoverLabel` the panel
  draws under the icon (`PanelView.swift`); the header has `.zIndex(1)` so the label draws over
  the chat. At the owner's request the up-arrow got the same label, pinned while installing:
  `Updating to Pauri X. Pauri will restart.` Search, new chat and settings still use `.help`,
  which never shows.
- After a Check now click, Checking holds for at least 1 s (`Updater.minimumCheckingTime`, a
  guess): a local feed answers in milliseconds, so without it the spinner never showed and
  every click started a new check.
- Hand check on the local test feed, owner looking and clicking: H2 up to date at 0.1.2 on
  hover; H3 one request per click, spinner then check mark; H4 server stopped, exclamation mark
  and couldn't check (Sparkle error 2001); H5 0.1.0 showed the up-arrow and its hover label,
  one click relaunched 0.1.2 with the panel open and up to date; H6 dev build, dim dash and
  `Pauri 0.1.0, updates off`, no request in 30 s.
- Deferred minors from the final review: a `nil`-error cycle end while Checking would leave the
  spinner on; a hover label may stay up after the panel hides while hovered; the delayed status
  write does not check for a newer cycle; a failed install reads "couldn't check for updates".
- Tests 124/124, twenty live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`).
  Commits a6f6b10, 7effe85, a097093, 4ab5bbd; merge 044f30f.

## #32 Show the panel after Pauri relaunches from an update (2026-11-16)

- Just before Sparkle relaunches Pauri, the old process sets the user default
  `PauriShowPanelAfterUpdate` in `updaterWillRelaunchApplication(_:)` (`Updater.markRelaunching`).
  The new process reads and removes it at the end of `applicationDidFinishLaunching`
  (`Updater.takeRelaunchedFromUpdate`) and, if it was set, calls `panel.show()`, the shortcut's
  call, without reading a selection. Every other launch starts hidden, as before.
- `showUpdateInstalledAndRelaunched` stays as it was: Sparkle calls it only in the old process,
  and only if that process is still alive. Sparkle relaunches with a plain `openURL`, so the new
  process cannot tell an update from an `open` without the note.
- D1: the old version writes the note, so updating from 0.1.1 to 0.1.2 still relaunches hidden,
  once. The first public update that shows the panel is 0.1.2 to 0.1.3.
- D3: the flag is cleared at every launch. If an install fails after the relaunch hook, the next
  manual launch shows the panel once.
- Hand check on the local test feed (signed `Pauri Self-Signed`), run by the builder through the
  Accessibility API: a 0.1.0 build showed `Update to Pauri 0.1.2 and restart`; one press quit it,
  and a new process at 0.1.2 started 1 s later with its panel on screen and the input field
  focused, and no shortcut press. The flag was gone after that launch. A later `pkill` and `open`
  started hidden. Typing into the relaunched panel was left to the owner at gate 2.
- Tests 121/121, twenty live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`).
  Commit b2568e9.

## #33 Installed 0.1.0 found no update: GitHub served the old appcast (2026-11-16)

- Cause: no fault in Pauri or Sparkle. At 23:26:44 UTC, 63 seconds after `gh release create
  v0.1.1`, `releases/latest/download/appcast.xml` still redirected to the v0.1.0 appcast.
  Sparkle compared 0.1.0 with 0.1.0, found nothing (`showUpdateNotFoundWithError` swallows it),
  and checks again only at relaunch or after `SUScheduledCheckInterval` (default 86400 s,
  sparkle-project.org/documentation/customization; Pauri does not set it).
- Red command: Pauri's `NSURLCache` (`~/Library/Caches/io.github.godfreyponce.pauri/Cache.db`)
  held the last check's response: `Date` 23:26:45 GMT, `Last-Modified` 23:13:24 GMT (the v0.1.0
  asset), `<sparkle:version>0.1.0</sparkle:version>`. A `curl -sL` of the feed after that served
  0.1.1. CFNetwork logged 302, 302, 200 at each launch; Sparkle logged no error.
- Ruled out: translocation, architecture, `minimumSystemVersion`, a skipped version, a test feed,
  the installed `Info.plist`.
- `scripts/release.sh` prints one line after `Released ...` (not on `--dry-run`): GitHub can serve
  the old appcast for a minute or more; test the update after that; a running Pauri checks again
  only at relaunch or after 24 hours. No app change, no README change: 0.1.0 copies update fine.
- Owner's update proof (H1, also #30's), 2026-11-16: relaunch at 18:03:21 local; the check got the
  0.1.1 appcast (`Date` 00:03:22 GMT, `Last-Modified` 23:25:40). The owner saw the up-arrow and
  clicked it; Pauri quit, and the owner reports opening it again (process start 18:05:45). The
  installed copy is 0.1.1 (`CFBundleShortVersionString` 0.1.1, signed `Pauri Self-Signed`). The next launch checked at 00:05:46 GMT, got 0.1.1, and showed no arrow.
  Sparkle logged nothing.
- Tests 119/119, twenty live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`, on main
  after the merge). Commit 3ced5d5.

## #30 Homebrew tap with a Pauri cask, and the update proof (2026-11-16)

- Homebrew policy, checked 2026-11-16: official casks "must pass Homebrew's Gatekeeper checks"
  (docs.brew.sh/Acceptable-Casks); "Casks without codesigning are deprecated" and
  `--no-quarantine` is deprecated (brew.sh/2025/11/12/homebrew-5.0.0/); taps should be named
  `homebrew-*` with casks in `Casks/` (docs.brew.sh/How-to-Create-and-Maintain-a-Tap);
  "Installing a fully qualified formula or cask name trusts only that item"
  (docs.brew.sh/Tap-Trust). So Pauri ships through the owner's tap, not the main cask list.
- Cask `godfreyponce/homebrew-tap` `Casks/pauri.rb`: `url .../releases/download/v#{version}/Pauri.zip`,
  `auto_updates true`, `depends_on arch: :arm64`, `depends_on macos: :sonoma`, `app "Pauri.app"`.
- `scripts/bump-cask.sh X.Y.Z [--dry-run]` reads the sha256 from GitHub's `digest` for
  `Pauri.zip` on release `vX.Y.Z` (no download), clones the tap into `build/tap/`, writes
  `Casks/pauri.rb` and the tap's `README.md` from heredocs, commits `pauri X.Y.Z` and pushes to
  `main`. With nothing to change it prints `The cask already has X.Y.Z.` and pushes nothing.
  `--dry-run` writes into a fresh `git init` folder instead. Stops (`bump-cask:`, exit 1): usage;
  no 64-hex digest ("Is the release out?"); clone fails.
- `scripts/release.sh` checks `gh repo view godfreyponce/homebrew-tap` before the build (skipped
  by `--dry-run`), and calls `bump-cask.sh` after `gh release create`; if it fails, it stops with
  "vX.Y.Z is released, but the cask was not bumped ... run scripts/bump-cask.sh X.Y.Z".
- README `## Install`: "Or install it with Homebrew" and `brew install --cask godfreyponce/tap/pauri`;
  `brew upgrade` leaves Pauri alone because it updates itself.
- Build-session proof (no v0.1.0 release and no certificate at the time): the stops ran for real;
  the write, push and rerun paths ran with a stub `gh` and a local bare repo as the tap; offline
  `brew audit --cask --strict` on that cask in a scratch tap passed; `--new` named the expected
  "GitHub repository not notable enough" plus 404/livecheck errors from the missing release.
  `release.sh 0.1.1 --dry-run` stopped at the certificate stop.
- Owner's gate 2 steps (tap made, v0.1.0 cask, `brew install`, `--strict --online` audit): not
  run before the accept. At landing, `gh repo view godfreyponce/homebrew-tap` and
  `gh release view v0.1.0` both still failed, so they run with the update proof below.
- Deferred from the final review: `release.sh`'s `git fetch origin tag` (from #29) sits before the
  `bump-cask.sh` call, so a network drop there skips the rerun hint; stop messages in both
  scripts can blame a missing release or repo for an auth or network failure.
- The v0.1.0 to v0.1.1 update proof runs after the accept push; its result is on #30's close comment.
- Update proof passed 2026-11-16. The brew-installed 0.1.0 updated to 0.1.1 in one click (#33's
  run). A second run, from the v0.1.0 release zip, proved Sparkle relaunches it (new process right
  after the click, version 0.1.1). The relaunched app starts hidden, which is #32.
- Tests 119/119, twenty live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`, on main
  after the merge). Commits 53a8459, a2f5d5d, merge 4978c5e.

## #29 Release script and the first GitHub Release (v0.1.0) (2026-11-16)

- `scripts/build-app.sh --release X.Y.Z` builds as usual, then sets
  `CFBundleShortVersionString` and `CFBundleVersion` to `X.Y.Z` and adds
  `PauriChecksForUpdates = YES` in the bundle's Info.plist before it signs. With no
  `Pauri Self-Signed` certificate it stops (exit 1) instead of signing ad-hoc. With no argument
  it builds as before, and `build/Pauri.app` stays the last line.
- `CFBundleVersion` is the version string. `Support/Info.plist` has `0.1.0`, not `1`, so a dev
  build never looks newer than a `0.x` release.
- `scripts/release.sh X.Y.Z [--dry-run]` stops with a `release:` message, in this order: usage;
  working tree has changes (untracked files count); `git fetch --tags`, then tag `vX.Y.Z`
  exists; `X.Y.Z` not newer than the highest `v*` tag (`sort -V`); HEAD is not `origin/main`
  (skipped by `--dry-run`); the release build (certificate stop); `generate_keys -p` fails or
  differs from `SUPublicEDKey`. Then it empties `build/release/`, zips with
  `ditto -c -k --sequesterRsrc --keepParent`, and runs `generate_appcast` with the
  `releases/download/vX.Y.Z/` prefix. `--dry-run` stops there. Otherwise one
  `gh release create vX.Y.Z --target <HEAD sha>` makes the tag and the Release, with
  `Pauri.zip` and a one-item `appcast.xml`; title and notes are the tag name.
- `generate_appcast` with no private key exits 1 and writes no `appcast.xml` (probed with an
  account that has no key), so the script stops before publishing.
- README `## Install`: download `Pauri.zip` from the latest release, move it to Applications,
  Open Anyway in Privacy & Security, Apple Silicon and macOS 14+, Codex CLI needed.
- The certificate was not in the keychain during the build, so the session proved only the
  certificate stop; the signed dry run was not run before the accept (the certificate was still missing).
- Deferred from the final review: the certificate stop leaves an unsigned `build/Pauri.app`
  until the next build; a denied keychain prompt shows "No Sparkle update key"; the Install
  steps name the macOS 15 dialog buttons; a failed upload can leave a draft release.
- v0.1.0 was not published at accept.
- Tests 119/119, twenty live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`).
  Commits ab82511, 0de435e, 39dd382.

## #28 Sparkle and the header update button (2026-11-16)

- Sparkle 2.10.1 is a Swift package dependency (`Package.resolved` committed).
  `scripts/build-app.sh` copies `Sparkle.framework` into `Contents/Frameworks` with `ditto`,
  deletes its XPC services (Pauri is not sandboxed), adds the rpath
  `@executable_path/../Frameworks`, and signs `Autoupdate`, `Updater.app`, the framework, and
  the app, in that order, with the same identity. No `--deep`, no hardened runtime.
  `build/Pauri.app` stays the last line.
- `Support/Info.plist` has `SUFeedURL`
  (`https://github.com/godfreyponce/pauri/releases/latest/download/appcast.xml`),
  `SUEnableAutomaticChecks`, and `SUPublicEDKey`. No `PauriChecksForUpdates`: #29's release
  script sets it, so a dev build never checks.
- `Updater` is Sparkle's user driver and updater delegate. It shows no Sparkle UI. It starts
  only when `PauriChecksForUpdates` is YES or the user default `PauriTestFeedURL` is set (the
  test feed wins). It checks at launch, then on Sparkle's 24-hour schedule, and holds
  Sparkle's "install?" reply until the click.
- The header shows an `arrow.up.circle` button left of `⌘K` when an update is out. One click
  downloads, installs, and restarts Pauri; a spinner shows meanwhile. Disabled while
  `!chat.canStartNewChat`, tooltip `Update after the answer ends`. A failed download logs
  `Pauri: update failed` and the button goes away until the next check.
- The update key lives in the login keychain (account `ed25519`). Make, backup, restore:
  `docs/superpowers/plans/2026-11-16-issue-28.md` ("Owner's one-time steps").
- Deferred from the final review: a question sent during the download is cut off by the
  restart; an information-only appcast item shows the button and a click just dismisses it;
  after a long uptime the button installs the version found at the first check; release notes
  are fetched if the appcast links them, and never shown.
- After an update, Pauri relaunches with its panel hidden, so the click looks like a quit.
- Pauri's `NSLog` lines show as `<private>` in `log show`, so `update failed` is unreadable
  there: #31.
- Tests 119/119, twenty live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`).
  Hand check H1 to H9 passed on ad-hoc builds (0.1.0 to 0.1.1, one `codex app-server` after
  the relaunch); the four permissions surviving an update is unproven until the certificate is
  back. Commits 2fd86c6, e439dbe, f5e929d.

## #27 Rebuilds keep their permissions: one self-signed certificate (2026-11-16)

- `scripts/build-app.sh` signs `build/Pauri.app` after every file is in it: with the
  `Pauri Self-Signed` certificate when `security find-identity -p codesigning` lists it, else
  ad-hoc (`codesign --force --sign -`). It prints which, and `build/Pauri.app` stays the last
  line. The lookup has no `-v`, because macOS never counts a self-signed certificate as valid;
  an expired certificate is still found, and then `codesign` stops the build instead of a silent
  ad-hoc build. No hardened runtime, no entitlements, no `--deep`.
- A signed build's designated requirement is `identifier "io.github.godfreyponce.pauri" and
  certificate leaf = H"..."`, the same on every rebuild, so macOS keeps the four grants. An
  ad-hoc build's is its `cdhash`, new each build.
- Before: `codesign --verify --strict` failed on every build (`code has no resources but
  signature indicates they must be present`). Now it passes for both kinds.
- README `## Build`: the Build bullet says which signing a build uses and gives the one-time
  `tccutil reset All` after the switch to signed builds; the three reset sentences now say
  "After an ad-hoc rebuild".
- The certificate's make, backup, and restore steps: `docs/superpowers/plans/2026-11-16-issue-27.md`
  ("Owner's one-time steps"). Losing the `.p12` makes the next build a new identity.
- Deferred from the final review: two keychain identities with the exact name
  `Pauri Self-Signed` make `codesign` stop as ambiguous (only at certificate rotation).
- Tests 116/116, twenty live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`).
  Ad-hoc path proven by the builder; signed path and the four-permission hand check by the owner
  at gate 2. Commit 581e9f7.

## #25 Handoff and chat open no longer race the open chat's delete (2026-11-15)

- `Chat.writeHandoff()` refuses while `isDeletingOpenChat` (#24), so a handoff never asks the
  deleted thread and never blocks the delete's own `newChat()`. The banner keeps its look; a
  click during the delete does nothing.
- `Chat.delete(_:)` starts a new chat only if the deleted thread is still `client.threadID` when
  the delete ends. A chat opened from a reopened palette during the delete has already moved it
  (`CodexClient.resume` sets it before it awaits), so that chat stays. Open is not blocked: the
  palette closes on open, and dimming its rows would change #22's look.
- Not covered (gate 1 decisions): a resume of another chat that fails after the delete has ended
  puts the deleted thread back as the open one. Reopening the chat that is being deleted ends on
  a new chat only if its resume finished first; if the resume is still waiting when the delete
  ends, `newChat()` is skipped while `isOpening`, as before #25, and the panel stays on the
  deleted thread.
- Deferred from the final review: the same check also starts a new chat when a chat that was
  not open at the delete's start is opened during it, and `isDeletingOpenChat` is not set on
  that path, so a question sent in that window can still go to the deleted thread.
- New live tests `liveHandoffWaitsWhileTheOpenChatIsDeleted` and
  `liveChatOpenedDuringTheOpenChatsDeleteStays` (passed with `PAURI_LIVE=1`). The second was
  never seen red: in three runs before the fix Codex answered the delete first each time.
  Tests 116/116, twenty live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`).
  Hand check by the owner at gate 2. Commit 2098fd5.

## #24 Send waits while the open chat is deleted (2026-11-15)

- New `Chat.isDeletingOpenChat`: `delete(_:)` sets it only for the open chat and clears it in a
  `defer`, so a failed delete leaves sending as it was. `send` refuses while it is set, the
  same way it refuses while `isOpening` (#20), and the send orb is off; the typed text stays.
- A delete of another chat leaves the flag alone, so an overlapping second delete cannot clear
  it early. The palette's own `isDeleting` does not block that: it resets when the palette
  closes and reopens (found in the final review).
- Kept out of `canStartNewChat`, so the palette's rows and keys do not dim during the delete
  (#22's look stays) and the delete's own `newChat()` still runs.
- Deferred from the final review: a handoff written, or a chat opened from a reopened palette,
  during the open chat's delete can still race it.
- New live tests `liveSendWaitsWhileTheOpenChatIsDeleted` and
  `liveDeletingAnotherChatKeepsSendWaiting` (passed with `PAURI_LIVE=1`). No test for a failed
  delete: `CodexClient` has no fake transport. Tests 114/114, eighteen live tests skipped
  (`./scripts/test.sh && ./scripts/build-app.sh`). Hand check by the owner at gate 2.
  Commit 38a6421.

## #22 History palette with search and delete (2026-11-15)

- Cmd+K, the header's search button, or the empty state's new "Open your past chats." row
  opens variant C of `design-directions/issue-21.html`: a palette over the whole panel with a
  search field, one row per Pauri chat (title, date, trash on the selected row), and a footer
  of key caps that are buttons with key equivalents (`↑` `↓` move, `↩` open, `⌘⌫` delete,
  `esc` back). It replaces #20's popover and closes when the panel hides.
- Search runs in Pauri, not Codex: `HistoryEntry.matches(_:)` checks the title or the first
  message (`preview`), case- and accent-blind. Codex's `searchTerm` matches titles only.
- Delete takes two presses: the trash or Cmd+Delete asks `Delete for good?` in the row; the
  row's `Delete` or a second Cmd+Delete sends `thread/delete`. Cancel, Esc, a selection change,
  or a search change drops the ask, and a held Cmd+Delete (key repeat) never confirms.
  `CodexClient.delete(_:)` forgets the ID only after Codex replies, so a failed delete keeps
  the row and shows the error under the search field. Deleting the open chat starts a new one.
  The probe (codex-cli 0.169.0) showed the delete is permanent: `thread/resume` then fails.
- The header shows `Chat.title` (the first line of the first question, or "New chat"), a
  `⌘K` hint, the search button, the pencil, and the gear. The send orb is disabled while a
  chat reopens (carried over from #20).
- The pointer selects a row only when it moves, so a row that scrolls under a still pointer
  does not take the selection from the arrow keys.
- Deferred from the final review: `Chat.delete` can leave a deleted thread open if a question
  starts mid-delete; a delete error stays until the next delete; a finished delete clears an
  ask raised on another row meanwhile; Cmd+N still works under the open palette.
  `history()` still reads every page on each Cmd+K.
- New tests `forgetDropsOnlyThatThread`, `searchMatchesTitleOrText`, and live test
  `liveDeleteDropsTheChatAndTheOpenOneStartsNew` (passed with `PAURI_LIVE=1`). Tests 112/112,
  sixteen live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`). Hand checks by
  the owner at gate 2. Commits 54c27d5, 010ae49, e1c20b5.

## #20 Pauri remembers its chats; Cmd+K opens a plain list (2026-11-15)

- `CodexClient` records every thread it asks in under `threadIDs` in `UserDefaults` (oldest
  first, each once), next to the `lastThreadID` write after `turn/start`. Cmd+N does not
  touch the list. Chats from before this build join it only when you ask in them again.
- `history()` pages `thread/list` (`limit` 100, the server's cap; `sortKey` `updated_at`; no
  `sourceKinds`, because Codex records app-server threads as `vscode`) and keeps only
  remembered IDs, in the reply's order. Title is `name`, else `preview` (Codex never names
  app-server threads). A remembered thread Codex no longer lists is left out.
- `resume(_:)` switches the warm process to another thread with `thread/resume`, saves it as
  `lastThreadID`, and returns its turns; on an error the current thread stays.
- New `HistoryList.swift`: a plain popover list (title, date of last update, newest first),
  "No chats yet." when empty. A clock button in the header, left of the pencil, opens it,
  with Cmd+K. `Chat.open(_:)` reopens a chat; sends and new chats are refused while it runs
  (`isOpening`), and rows are disabled while a new chat could not start. #22 restyles it and
  adds search and delete.
- Deferred from the final review: the send orb stays enabled during a reopen (a press does
  nothing, the draft stays); a failed reopen hides a context-full banner until the next
  answer; reopening the chat already open resets the model pick and allow-for-this-chat;
  `history()` reads every page on each Cmd+K; no progress sign while a reopen runs.
- New live test `liveHistoryListsOnlyThisListsChatsAndReopensOne` passed with `PAURI_LIVE=1`.
  Tests 109/109, fifteen live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`).
  Hand check 1 by the builder; checks 2 to 6 by the owner at gate 2. Commits 23dcbba, eeb3c92.

## #23 Model picker label without "GPT" (2026-11-14)

- New `ModelPicker.label(_:)`: a name that starts with "GPT-" or "GPT " (any case) and has text
  after it loses that prefix, so "GPT-6.1-Sol Fast" next to the Blossom reads "6.1-Sol Fast".
  Any other name, and a bare "GPT" or "GPT-", shows unchanged; no model shows "Codex default".
- The capsule's button and every menu row use it, so the two agree. The menu still checks the
  current model by id. `ModelChoice` is untouched, so `turn/start` still sends the full id.
- New `ModelPickerTests` (5 tests). No visual-rule variants: the owner set the exact text.
- Deferred from the final review: whitespace after the prefix survives ("GPT- 5" shows " 5");
  a model named exactly "GPT" with the fast tier would show "Fast"; VoiceOver now hears the name
  without "GPT" or "OpenAI", since the logo is hidden from it.
- Tests 105/105, fourteen live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`).
  Hand check by the owner at gate 2. Commit 593e31e.

## #21 Whole-panel redesign, variant C (2026-11-14)

- `design-directions/issue-21.html` shows four whole-panel shapes on one data set: A no header
  bar, B toolbar and sidebar, C command palette, D home screen, each with its Cmd+K history
  surface. The owner picked C, with no mix. The page stays as the record.
- The panel is C: a slim 26 pt header with new chat and settings at the top right, the user's
  message as a row with a "YOU" label in a 44 pt column, the steps, approval card, and answer
  indented under it, a divider and 12 pt between exchanges, 12.5 pt answers with 2.5 pt line
  spacing, code at 11 pt, step rows at 11.5 pt, panel padding 12. The orb, input area, and
  model picker are unchanged (#10, #17). `QuestionBubble` is replaced by `QuestionRow`.
- New `EmptyState.swift`: a list of plain rows (quote text, paperclip, the saved hotkey as key
  caps), shown when the chat has no exchanges and Codex has finished starting, so a restored
  chat never flashes it at launch. It takes the `Shortcut`, so a changed hotkey shows.
- Left for #22 (comment on #22): the chat title and the Cmd+K search button in the header, the
  palette that covers the panel, and the "Open your past chats" row, which waits for #20.
- Deferred from the final review: the transcript's 12.5 pt reaches the approval card (the page
  has 13); after a failed Codex start the empty state shows though the old chat is still live;
  `keyCaps`'s doc comment shows `⌘⇧Space` where `displayName` gives `⇧⌘Space`.
- Tests 100/100, fourteen live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`).
  Hand checks by the owner at gate 2. Commits 296f78d, 4ed0036, c26d910.

## #18 Live screenshot test passes at the default effort (2026-11-14)

- The cause was the test, not `CodexClient`. At low effort the model read the 64x64 test image
  with its halves swapped in 2 of 5 probe runs, and the first check did not test order, so the
  swap showed up as a wrong follow-up. A 512x512 image read right 8 of 8 times at low effort.
  The follow-up never lost the image: both turns send the same model, effort, and tier.
- `liveImageIsDescribedAndOutlivesItsFile` now sends Pauri's default entry,
  `ModelChoice.menu(models).first` (the `isDefault` model at low effort), on both turns, on a
  512x512 red-left, blue-right image. Turn 1 asks for the left half and must say red and not
  blue; turn 2, after the file is deleted, asks for the right half and must say blue and not
  red, so it has to read the image, not the first answer. The `run` helper takes an optional
  `image`. `Sources/` is not touched. No effort raise for screenshots (gate 1).
- The plan's nested `#require` did not compile (recursive macro expansion); it is split into
  two lines, as in `liveModelListGivesADefaultThatAnswers`.
- Deferred from the final review: when turn 1 runs shell commands to decode the PNG (1 of 13
  probe runs), their output stays in the thread, so turn 2 could answer from text in that run;
  `contains("red")` also matches words like "colored".
- Live test passed 4 of 4 with `PAURI_LIVE=1`. Tests 100/100, fourteen live tests skipped
  (`./scripts/test.sh && ./scripts/build-app.sh`). Commit 263a01c.

## #17 Roomier input, Blossom model picker with effort bars, web search always on (2026-11-14)

- The input is one rounded box, variant A of `design-directions/issue-17.html` (the owner's
  pick, with a paperclip in place of the + menu): the text across the full width, 2 to 8
  lines, and a row under it with the paperclip (one click takes the screenshot, as the camera
  did), the model picker, the mic, and the send orb. No globe, no camera.
- The picker (`ModelPicker.swift`) shows the official OpenAI Blossom (black file in light
  appearance, white in dark, unmodified, whole 716 canvas) and the model name on a
  `.regularMaterial` capsule, then one bar per level `model/list` reports in
  `supportedReasoningEfforts` (six, or five on Luna). A click on the bars steps to the next
  level and wraps; it applies from the next message. The menu checks by `id`, so the model
  stays checked at any effort. Each menu entry, #15's default entry included, carries its
  model's levels; when `model/list` fails the picker reads "Codex default" with no bars.
- The SVGs ship in `Support/` and `scripts/build-app.sh` copies them to
  `Contents/Resources`; no remote asset. README carries the trademark line and the link to
  https://openai.com/brand/.
- Web search is always on: every `thread/start` and `thread/resume` sends
  `config.web_search = "live"`. `turn/start` has no such field (codex-cli 0.169.0). The globe's
  thread reload (`thread/unsubscribe`, `thread/resume`) is gone.
- A `model/list` entry without levels, or a level without a description, decodes as empty
  instead of failing the whole list (final review finding).
- Main was merged into `issue-17` after #15 and #16 landed: #15's default entry, optional
  model, and optional tier stay; #17 adds the levels to them and keeps #15's
  `turnStartParams` name.
- Spec decisions 7, 8, 14 updated. Tests 100/100, fourteen live tests skipped
  (`./scripts/test.sh && ./scripts/build-app.sh`); live test liveWebSearchIsAlwaysOn passed
  with `PAURI_LIVE=1` before and after the merge. Commits 18953d3, cd9d502, 00ebf59, c051a3b,
  merge 6d3198c, merge 880c615.

## #16 Markdown answers and the user's messages (2026-11-14)

- Answers render Markdown with native SwiftUI `Text`, no web view and no new dependency.
  Foundation's `AttributedString(markdown:)` with `.full` syntax parses the answer, and
  `Markdown.blocks` groups its runs into blocks by each run's `presentationIntent`: headings,
  paragraphs, list items (bullet or "N." marker, indent per depth), code blocks (a tinted
  rounded box that scrolls sideways, monospaced, no copy button or syntax colors), quotes (a
  side bar), rules, and table rows (cells joined by " | ", header bold). Images show their alt
  text and load nothing. Selection now works within one block, not across the whole answer.
- While an answer streams, `Markdown.streamingSafe` hides a dangling `**`, a dangling backtick,
  and a half link in the last paragraph, so the marks do not flash raw. It counts indented and
  `~~~` fences, and it skips `**` inside a code span (`x**2`). After Stop, the answer renders
  from its full text, so an open `**` then shows raw.
- `MarkdownView` is `Equatable` with a hand-written `nonisolated ==` (it reads the color scheme
  from the environment), so finished answers skip their body while the last one streams.
- The user's message is variant A of `design-directions/issue-16.html`, the owner's pick: plain
  text in a right-aligned purple bubble (0x4A3DB8 dark, 0x5B4BD0 light, white text), at most
  three quarters of the transcript's width. The Screenshot label moves to the right with it.
  Links take the purple tint. Spec decision 14 updated.
- Deferred from the final review: a streaming tail that ends in a newline is skipped; the parse
  cost grows with the length of the streaming answer (about 1.4 ms per KB per delta); a code
  block or quote inside a list item loses its indent; raw HTML blocks keep a trailing newline;
  empty table cells are dropped.
- Tests 95/95 on main after the merge, fourteen live tests skipped
  (`./scripts/test.sh && ./scripts/build-app.sh`).
  Commits f6cad66, 49f9c12, a86f996, 42adf92, 796ba63, merge 4903a25.

## #15 Default model from Codex's model list (2026-11-14)

- No model id is written into Pauri any more. The picker's first entry comes from the model
  that `model/list` marks `isDefault` (codex-cli 0.169.0): low effort only if the model lists
  `low` in `supportedReasoningEfforts`, else its default effort; the `priority` tier and the
  word "Fast" only if it lists `priority` in `serviceTiers`, else no `serviceTierForTurn` is
  sent. A default entry without the Fast tier takes the place of its model's standard line.
  `hidden` models are left out. No usable default: the picker lists the visible models and a
  new chat takes the first.
- `Chat.model` is optional. When `model/list` fails or lists nothing, `turn/start` carries no
  `model`, `effort`, or tier, so Codex uses its own default; the picker reads "Codex default"
  and is disabled. A pick no longer in the list falls back to the first entry; New chat goes
  back to it. `turn/start` params are built in `CodexClient.turnStartParams`, which has unit
  tests.
- Known gap (plan decision 6): a question sent before `model/list` returns runs on Codex's own
  default.
- Live tests now send no model, so they run on the user's own Codex config;
  `liveModelListGivesADefaultThatAnswers` runs the real default entry, and
  `liveAnswerWithNoModelSent` is the turn sent after a failed `model/list`.
- Spec decision 7 rewritten. Tests 80/80, fourteen live tests skipped
  (`./scripts/test.sh && ./scripts/build-app.sh`); the two new live tests passed with
  `PAURI_LIVE=1`. Commit 70a2798.

## #4 Model picker, fast default, web search toggle (2026-11-14)

- The input bar has a model picker and a globe, between the text field and the mic. The picker
  uses `codex app-server`'s `model/list` (codex-cli 0.169.0): first "GPT-6.1-Sol Fast"
  (`gpt-6.1-sol`, effort `low`, service tier `priority`), then each listed model at its default
  effort, standard speed. Every `turn/start` sends `model`, `effort`, and `serviceTierForTurn`,
  because the user's own Codex config can set a higher effort. Both controls reset with each
  new chat and are disabled while an answer streams.
- Web search is the `web_search` config key, not a per-turn flag: `live` when the globe is on,
  `disabled` when off, set on `thread/start` and `thread/resume`. A change mid-chat reloads
  the thread (`thread/unsubscribe`, `thread/resume`) before the next message; a thread with
  no turn yet is replaced by a new one. A search shows as a gray "Searched the web for ..."
  step; `item/started` has no query yet, so it reads "Searched the web" until it completes.
- Off turns off only the search tool: in the live test Codex then tried `curl` through the
  shell, which the read-only sandbox blocked and which then asked for approval.
- Merged main into `issue-4` after #7 landed: `ask` and `turn/start` carry both the screenshot
  and the model; the screenshot button sits after the globe.
- At the low-effort default, #7's live image test failed 2 of 4 runs (the follow-up named the
  wrong color); main passed 4 of 4, and the branch at medium effort passed 4 of 4.
- Spec decisions 7 and 8 updated. Tests 76/76, thirteen live tests skipped
  (`./scripts/test.sh && ./scripts/build-app.sh`); the live suite passed 12/13 with
  `PAURI_LIVE=1`, the image test being the miss. Commits 6cb3a44, 3a271b5, merge ebbe4d4.

## #7 Screenshot button (2026-11-14)

- A camera button left of the mic takes one ScreenCaptureKit screenshot of the screen the panel
  is on, at its point size, with no cursor. A filter leaves out Pauri's own app, so the panel
  stays up and is not in the shot. The PNG goes to $TMPDIR/pauri-screenshot-<UUID>.png and
  shows as a thumbnail chip; a second press replaces it.
- Send passes it to Codex as a turn/start `localImage` item after the text (codex-cli 0.169.0
  takes it; the session file stores the image inline, so a follow-up still sees it after the
  file is gone). Chat deletes the file when the answer ends, or on remove or replace. The sent
  turn shows a Screenshot marker; restored turns do not.
- Access: CGPreflightScreenCaptureAccess before any ScreenCaptureKit call; the first press calls
  CGRequestScreenCaptureAccess, and the row names the Privacy pane and the relaunch.
- Tests 70/70 in the worktree, eleven live tests skipped (`./scripts/test.sh &&
  ./scripts/build-app.sh`); live test liveImageIsDescribedAndOutlivesItsFile passed with
  `PAURI_LIVE=1`. Commits bfd05c3, abdf3d8, merge c298cc2.

## #14 Stop an answer from the send orb's square (2026-11-14)

- While an answer streams, a click on the orb's square sends `turn/interrupt` to the running
  `codex app-server` turn, so Codex stops working too. Codex then ends the turn with
  `turn/completed`, status `"interrupted"`, which Pauri reads as a clean end: the text so far
  stays, no notice shows, and the orb goes back to the arrow. Enter in the text field still
  only sends. The orb's tooltip and VoiceOver label read "Stop" while answering.
- The turn id comes from the `turn/started` notification, not the `turn/start` reply (the plan
  said the reply). On codex-cli 0.169.0, an interrupt sent right after the reply on a fresh
  launch got "no active turn to interrupt". A click before `turn/started` is remembered and
  sent when it arrives. Only the chat's own thread counts, so a handoff fork's turn is never
  interrupted by a stop left over from the turn before it.
- Tests 68/68 on main after the merge with #11 (65/65 in the worktree), ten live tests skipped
  (`./scripts/test.sh && ./scripts/build-app.sh`); the live suite passed 10/10 with
  `PAURI_LIVE=1`. Commit 8c1aa69.

## #11 Dictation button (2026-11-14)

- A mic button between the input and the send orb. Press to start, press again to stop. Each
  partial result sets the draft to what was typed before the press plus the spoken text
  (`Dictation.joined`). On-device only: `requiresOnDeviceRecognition = true`, no server
  fallback, and Pauri does not start when the Mac has no on-device model for its language.
  Punctuation on; the Mac's language.
- Stops on: the mic, a send, typing, or the panel losing key. A result after a stop writes
  nothing (run token). While the access dialogs are up, a send drops the pending start, and
  listening never starts behind a hidden panel.
- First use asks macOS for Microphone and Speech Recognition (usage strings in
  Support/Info.plist). After a no, the mic shows mic.slash and a row names the Privacy pane,
  with a button that opens it.
- Swift 6: the tap block, the authorization handler, and the recognition handler are made in
  nonisolated static functions; made on the main actor, they crash at runtime off the main
  thread.
- Tests 63/63, seven live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`).
  Commits 379df81..fb7e9a7, merge 1a66510.

## #5 Tool steps and approval cards (2026-11-14)

- Threads start and resume with `sandbox: "read-only"` and `approvalPolicy: "on-request"`.
  A probe on codex 0.167.2 showed `"untrusted"` asking for a plain `rg --files | wc -l`, while
  `"on-request"` ran reads with no request and asked before each shell or patch write. The
  #8 handoff fork keeps `approvalPolicy: "never"`: it only writes text.
- Each `commandExecution` and `fileChange` item shows as one gray line labeled from its
  `commandActions` ("Read 2 files", "Ran `git status`", "Created out.txt"). A click shows the
  command and its output, capped at 120 pt with a scroll. Steps sit above the answer text and
  stay in the UI; old chats restored at launch show none. A step still running when its turn
  ends turns into "(failed)", so no spinner outlives Codex.
- A write or other command shows a card under the steps: Allow (`accept`), Deny (`decline`,
  the turn goes on), Allow for this chat. That last one is Pauri's own flag, because Codex's
  `acceptForSession` covers only the same command. New chat and a relaunch clear it. Pauri
  never sends `acceptForSession` or an execpolicy amendment. Requests queue; the card shows
  the first, and the queue clears when the turn ends.
- Card and line shape: variant A (flat lines) of `design-directions/issue-5.html`.
- Tests 60/60, seven live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`); the
  live suite passed 7/7 with `PAURI_LIVE=1`. Commits 47c5f07..2232e2c, merge 11697d3.

## #6 Send the selected text (2026-11-13)

- The hotkey reads the selection of the front app before it shows the panel (Accessibility API:
  focused element, `AXSelectedText`, in `SelectionGrabber`). The panel shows it as a chip above
  the input (`SelectionBar`), and the x removes it. Each press that shows the panel replaces the
  chip, with nothing too. The press that hides the panel reads nothing.
- Sending puts the selection above the question as a Markdown quote (`> ` on each line, a blank
  line, then the question). The transcript shows that full text, so a resumed chat looks the same.
- First use shows one line in the panel ("To attach the text you select, Pauri needs Accessibility
  access.") with Allow and Not now. Either sets `UserDefaults` key `askedForSelectionAccess`, so
  the row shows once. Without access Pauri works as before. `SelectionBar` reads `chat.selection`
  in every branch, so a grant made in System Settings while the row shows still brings the chip.
- Known gaps: a hung front app holds the hotkey for up to twice the system Accessibility timeout;
  reopening with `open build/Pauri.app` keeps an earlier chip.
- Merged main (#8) into the branch before landing: `Chat.send` keeps #8's handoff check and adds
  the quote. The selection stays attached across a handoff's new chat, where its chip still shows.
- Tests 47/47 on main after the merge, five live tests skipped (`./scripts/test.sh &&
  ./scripts/build-app.sh`). Commits 6dc2cc1..33fb77a, merge a1002fa.

## #8 Context-full banner and handoff (2026-11-13)

- Pauri reads Codex's `thread/tokenUsage/updated` (sent after each turn and right after
  `thread/resume`) for the current thread only, and compares `tokenUsage.last.totalTokens` with
  `modelContextWindow`. `total` is a running sum of every request, not the context size.
- The banner shows from `ContextLimit.guess = 0.7` (a guess, in `ContextBanner.swift`). Debug:
  `defaults write io.github.godfreyponce.pauri contextBannerDebug -bool YES` lowers it to 0.01,
  which any chat passes after one answer (one short question holds about 16k of 475k tokens on
  gpt-6.1-sol: Codex's own instructions).
- "Write a handoff draft" forks the thread with `ephemeral: true` and asks Codex for the note on
  the fork, so the old chat gets no extra turn and the fork is never written to disk. The note
  goes into the input box of a new chat and is sent only on Return. An empty note is an error,
  and the old chat stays. "New chat" is Cmd+N. While the note is written, both banner buttons,
  the pencil, Cmd+N, Return, and the send orb are off.
- The banner is variant A of `design-directions/issue-8.html` (floating card) in variant B's
  yellow: a yellow tint and border on a material card, text in the primary color so light mode
  stays readable. It sits in a top safe-area inset of the transcript, so the first exchange can
  scroll out from under it. No close button. The input box grows to 8 lines.
- Tests 43/43 on main after the merge, five live tests skipped (`./scripts/test.sh &&
  ./scripts/build-app.sh`; 43/43 on the branch). Commits 30920a9..0c09461 (main merged in at
  cd380d7), merge 2f5a396.

## #10 Send orb that follows the time of day (2026-11-13)

- The send button is a 32 pt painted orb at the right of the text field. Its scene follows the
  clock through ten frames: blue hour, dawn, flower meadow, seaside morning, summer sky, golden
  afternoon, harbor sunset, evening town, dusk forest, midnight moon. Neighbouring frames
  cross-fade over 40 minutes, or 60% of a frame when that is shorter. Original motifs in a
  Studio Ghibli mood, no characters, no image assets.
- The owner moved the design away from the indigo reference orb (`docs/reference/send-orb.png`)
  over six rounds at the Task 1 stop. `design-directions/issue-10.html` is the record: four
  looks, four send animations, and section 5, the dynamic orb that won. The midnight-moon frame
  keeps the reference's indigo starry sphere.
- Place without a permission prompt: the Mac's time zone is looked up in
  `/usr/share/zoneinfo/zone.tab`, and NOAA's sunrise formula places dawn and sunset. A zone that
  zone.tab does not list uses 6:30 and 19:00. The day length is held to 1 to 20 hours, so
  midnight sun, polar night, and a sunset after midnight keep the ten frames in order.
- Enter and a click both go through `PanelView.submit()`; each accepted send plays press and
  ring (the orb dips to 0.88, one glow ring grows and fades). The scene moves only while an
  answer streams and holds its frame otherwise, and the arrow turns into a square. The square
  does nothing yet: #14. The orb dims to 0.4 only for a blank draft; while answering it stays
  bright, and `Chat.send` refuses the send. Reduce Motion: the glow flashes, nothing moves.
- SwiftUI fades each layer of a stack on its own: the scenes and the orb carry
  `.compositingGroup()` so a cross-fade or the dim does not show inner layers.
- Tests 35/35 on main after the merge, four live tests skipped (`./scripts/test.sh &&
  ./scripts/build-app.sh`). Commits 0d88d3e..0ad3bc2, merge e054484.

## #13 Codex stdout reader without a shared blocking read (2026-11-13)

- Pauri reads `codex app-server` stdout through `FileHandle.readabilityHandler`
  (`chunks(of:)` in `CodexClient.swift`), not `FileHandle.bytes`. A `.bytes` read on an idle
  pipe stalled every other `.bytes` reader in the process, so a second live client hung in
  `start()`. Each handle now gets its own dispatch source and holds no thread while it waits.
- `forEachLine` takes `AsyncStream<Data>` chunks, joins a line split across chunks, and still
  splits on "\n" only (U+2028 stays inside JSON strings). Bytes after the last "\n" at
  end-of-file are dropped, as before.
- The live suite is no longer serialized; the four live tests run side by side
  (`PAURI_LIVE=1 ./scripts/test.sh --filter CodexClientLiveTests`, about 10 s).
  `quit` stays: it stands for quitting Pauri before a relaunch and keeps a test from leaving an
  app-server running. The #3 note that live tests stop each app-server because of a stall no
  longer holds.
- Tests 28/28, four live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`). Commit
  e1f8ffa.

## #3 Follow-ups, reopen last chat, Cmd+N (2026-11-13)

- The panel shows the whole chat: each question in bold with its answer under it, scrolled to the
  bottom. Every question goes to the same Codex thread, so a follow-up uses the earlier turns.
- Codex keeps the chat on disk; Pauri stores only the thread id, in `UserDefaults` key
  `lastThreadID`, written after a question's `turn/start` succeeds (a thread with no turns cannot
  be resumed). Each start of the app-server, at launch or after Codex dies, sends
  `thread/resume` with that id and the same overrides as `thread/start`, and the panel shows the
  old turns from the reply's `thread.turns` (userMessage and agentMessage text only). Any failed
  resume removes the id and opens a blank chat with no notice. Reset:
  `defaults delete io.github.godfreyponce.pauri lastThreadID`.
- If the start at launch fails, the old turns appear with the first answer after it, above that
  question.
- Cmd+N, or the pencil button left of the gear, forgets the id; the next question starts a new
  thread on the same warm process. It is off while an answer streams and during the start at
  launch. Shipped as SwiftUI `.keyboardShortcut` on the button.
- `thread/resume` full-turn hydration is deprecated for paginated threads in codex-cli 0.167.2
  (`thread/turns/list` replaces it); it works today.
- Live tests (`PAURI_LIVE=1 ./scripts/test.sh --filter live`) sit in a serialized suite and stop
  each client's app-server before the next client starts: two live app-servers in one process
  stall the second reader (#13).
- Tests 25/25, three live tests skipped (`./scripts/test.sh && ./scripts/build-app.sh`). Commits
  c365bd0..500cf2c, merge df9569d.

## #9 Glass window and transparency slider (2026-11-13)

- The panel is frosted glass: an `NSVisualEffectView` (material `.popover`, blending
  `.behindWindow`, state `.active`) is the panel's content view, with the SwiftUI hosting view
  inside it. `.active` matters: Pauri never becomes the active app, and the default state would
  draw the flat inactive look.
- `PanelView` lays `windowBackgroundColor` over the glass at opacity `1 - transparency`. One
  slider in the gear popover, Solid (0) to Glass (1), default Glass, writes `UserDefaults` key
  `transparency` through `@AppStorage`, so the panel follows it live and it survives a relaunch.
  Reset: `defaults delete io.github.godfreyponce.pauri transparency`.
- At Glass the slider stops at the bare system material. In dark mode `.popover` lets only a
  faint blur of the apps behind through; a clearer look is a one-word material swap in
  `PanelController`.
- With macOS Reduce Transparency on, the glass draws solid, so the slider has almost no effect.
- Main moved under the build (#2 landed); `issue-9` merged main in (4559520), keeping the glass
  and #2's `PanelView(hotKey:chat:)`.
- Tests 21/21, one skipped (`./scripts/test.sh && ./scripts/build-app.sh`). Commits
  9a2bc7a..e1faf74, main merged in 4559520, merge 91ba497.

## #2 Ask one question, get a streamed answer (2026-11-13)

- Pauri finds `codex` through the user's interactive login shell (`$SHELL -l -i -c`, about 0.5 s,
  once per start) and runs the child with that shell's `PATH`. The npm `codex` is a node script.
- One `codex app-server` child, spawned at launch, speaks newline-delimited JSON-RPC:
  `initialize`, `initialized`, `account/read` (null account means logged out), `thread/start`
  (read-only sandbox, approval policy `never`, home folder), then one `turn/start` per question.
  Text arrives in `item/agentMessage/delta` notifications. One thread per launch, reused.
  Pauri answers every server request with a JSON-RPC error. SIGPIPE is ignored, so a write to a
  dead child fails instead of killing Pauri.
- The reader splits the child's output on `\n` bytes only: `FileHandle.bytes.lines` also splits
  on U+2028, U+2029, and U+0085, which Codex writes raw inside JSON strings.
- The panel shows the answer as plain text under #12's gear row, and a notice for not installed,
  not logged in, or stopped. Each Return retries a failed start.
- First token on a short question, live test (`turn/start` to first delta, warm thread): 1.7 to
  4.5 s across ten turns, on Codex's default model and effort. The ~1 s target needs #4's fast
  default.
- `PAURI_LIVE=1 ./scripts/test.sh --filter liveTwoQuestionsOneProcess` drives the real server.
  The full check skips it. To find Pauri's own child among other apps' app-servers:
  `pgrep -P "$(pgrep -x Pauri)" -fl codex`.
- Tests 21/21, one skipped (`./scripts/test.sh && ./scripts/build-app.sh`). Commits
  03b1ffc..cc3a1ca (main merged in at 66bb2f9 to take #12), merge 22592ae.

## #12 Configurable hotkey (2026-11-13)

- A gear button at the top right of the panel opens a popover with one recorder button. Click it,
  press the new shortcut, and it works at once; Esc cancels. A shortcut needs Cmd, Option, or
  Control; Shift alone or no modifier is refused. Option+Space can be chosen.
- `HotKey` owns the live shortcut: it loads it at launch, pauses the Carbon registration while
  the recorder listens (so the current shortcut can be recorded), and on a change saves it to
  `UserDefaults` key `hotKey` as `{keyCode, modifiers}` (Carbon numbers). If Carbon refuses the
  new one, the old one stays and the popover says so. Reset:
  `defaults delete io.github.godfreyponce.pauri hotKey`.
- Way back in: opening Pauri again while it runs (`open build/Pauri.app`) shows the panel
  (`applicationShouldHandleReopen`), for a shortcut that registers but never arrives.
- Test files: Command Line Tools have no `_Testing_Foundation` overlay, so a test file that
  imports both `Testing` and `Foundation` fails to compile; import `AppKit` instead.
- Tests 7/7 (`./scripts/test.sh && ./scripts/build-app.sh`). Commits f2f388d..8729115, merge 2a5941d.

## #1 Hotkey opens a floating panel (2026-11-13)

- Swift package `Pauri` (SwiftPM, Swift 6, macOS 14+), no Xcode project: the owner's Mac has only
  Command Line Tools. `scripts/build-app.sh` wraps the release binary and `Support/Info.plist`
  into `build/Pauri.app`; `scripts/test.sh` adds the Swift Testing framework flags that Command
  Line Tools need.
- Cmd+Shift+Space (Carbon `RegisterEventHotKey`) toggles a 520 x 680 nonactivating `NSPanel` at
  `.floating` level that joins all Spaces and fullscreen apps. The text field takes focus on every
  show; Esc hides; the draft survives a hide. The app behind stays active. `LSUIElement`, so no
  Dock icon and no menu; quit with `pkill -x Pauri`. Bundle id `io.github.godfreyponce.pauri`.
- Known gap: another app holding the same combination does not make the registration fail, so a
  clash is silent. Belongs with #12.
- Tests 1/1 (`./scripts/test.sh && ./scripts/build-app.sh`). Commits 5efd6b7..76b9e7c, merge c6e4b73.
