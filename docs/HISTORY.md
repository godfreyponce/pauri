# pauri — Build History

Accepted-work archive. One section per accepted ticket, appended at the accept-time docs commit.
Newest first.

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
