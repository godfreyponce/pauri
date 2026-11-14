---
glass: pauri
status: in-progress
last_worked_on: 2026-11-13
next_action: "#2"
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
- Full check: `./scripts/test.sh && ./scripts/build-app.sh`.

## Gotchas

- A GUI app does not get the shell's `PATH`. On the owner's Mac `codex` lives under `~/.nvm`.
- Public repo: no env values, credentials, or owner personal data in commits or issues.
