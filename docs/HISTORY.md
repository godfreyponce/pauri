# pauri — Build History

Accepted-work archive. One section per accepted ticket, appended at the accept-time docs commit.
Newest first.

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
