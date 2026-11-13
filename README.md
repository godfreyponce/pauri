# Pauri

A floating quick-chat window for macOS. Press a hotkey, ask a question, and get an answer from Codex in a small glass panel that stays on top of everything. It can also act on your Mac: read files, run commands (with your OK), and see the text you selected.

The name: P from *Proxima*, the rest from *Centauri*. The nearest star, always close.

## Status

The panel opens on a hotkey and takes text, but it has no backend yet: it does not talk to Codex. The design is in [docs/spec.md](docs/spec.md) and the work queue is in GitHub Issues.

## Requirements

- macOS
- [Codex CLI](https://github.com/openai/codex) installed and logged in (`codex login`). Pauri runs your own `codex app-server` and never touches your OpenAI credentials.

## Build

You need Command Line Tools (`xcode-select --install`) or Xcode.

- Build: `./scripts/build-app.sh`. It writes `build/Pauri.app`.
- Run: `open build/Pauri.app`.
- Show the panel: Cmd+Shift+Space. Press it again, or Esc, to hide the panel.
- Quit: `pkill -x Pauri`. Pauri has no Dock icon and no menu.
- Test: `./scripts/test.sh`.

## License

MIT
