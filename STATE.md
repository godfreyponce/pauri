---
glass: pauri
status: in-progress
last_worked_on: 2026-11-15
next_action: "#22"
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
- The app is ad-hoc signed, so every rebuild loses the Accessibility grant (System Settings still shows it on). Reset: tccutil reset Accessibility io.github.godfreyponce.pauri && defaults delete io.github.godfreyponce.pauri askedForSelectionAccess, then press the shortcut and click Allow.
