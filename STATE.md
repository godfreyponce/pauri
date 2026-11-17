---
glass: pauri
status: in-progress
last_worked_on: 2026-11-16
next_action: "#30"
blocked_on: ""
phase: "Bootstrapped 2026-11-13. Tickets #1-#12 cut from docs/spec.md, none green-lit."
---

# pauri — Project State

A floating Codex quick-chat window for macOS: native Swift, driven by the user's own `codex app-server`. Public, MIT (spec decision 18).

*Thin snapshot. `next_action` above names the ticket that is up now — start there.
Archive: `docs/HISTORY.md`. Queue: GitHub Issues (`gh issue list`). Protocol: `AGENTS.md`.*

## Now

## Run / verify

- Build: `./scripts/build-app.sh` (writes `build/Pauri.app`).
- Run: `open build/Pauri.app`. Quit: `pkill -x Pauri`.
- Test: `./scripts/test.sh`.
- Live test: `PAURI_LIVE=1 ./scripts/test.sh --filter liveTwoQuestionsOneProcess` (needs a logged-in Codex, spends a few tokens).
- Full check: `./scripts/test.sh && ./scripts/build-app.sh`.

## Gotchas

- A GUI app does not get the shell's `PATH`. On the owner's Mac `codex` lives under `~/.nvm`.
- `codex app-server` protocol types: `codex app-server generate-ts --out <dir>`. They change between codex versions.
- Public repo: no env values, credentials, or owner personal data in commits or issues.
- Builds signed with the `Pauri Self-Signed` certificate keep the four permissions across rebuilds; the build prints which signing it used. An ad-hoc build loses them; reset: tccutil reset All io.github.godfreyponce.pauri && defaults delete io.github.godfreyponce.pauri askedForSelectionAccess, then press the shortcut and click Allow. The certificate's backup and restore steps: `docs/superpowers/plans/2026-11-16-issue-27.md`.
- Sparkle's update key lives in the login keychain (default account `ed25519`); its public half is `SUPublicEDKey` in `Support/Info.plist`. Losing it breaks updates for every installed copy. Backup and restore: `docs/superpowers/plans/2026-11-16-issue-28.md`. A dev build never checks for updates; the test hook is `defaults write io.github.godfreyponce.pauri PauriTestFeedURL <url>`.
- Right after a release, GitHub's `releases/latest/download/appcast.xml` can still serve the old appcast (v0.1.1: old for 63 s or more). A check in that window finds nothing, and a running Pauri checks again only at relaunch or after 24 hours. Wait a few minutes before an update proof.
