# pauri — Build History

Accepted-work archive. One section per accepted ticket, appended at the accept-time docs commit.
Newest first.

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
