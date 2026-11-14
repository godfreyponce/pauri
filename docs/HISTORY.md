# pauri — Build History

Accepted-work archive. One section per accepted ticket, appended at the accept-time docs commit.
Newest first.

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
