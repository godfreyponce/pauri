# Pauri

A floating quick-chat window for macOS. Press a hotkey, ask a question, and get an answer from Codex in a small glass panel that stays on top of everything. It can also act on your Mac: read files, run commands (with your OK), and see the text you selected.

The name: P from *Proxima*, the rest from *Centauri*. The nearest star, always close.

## Status

The panel opens on a hotkey. Type a question and press Return: the answer streams in from your own `codex app-server`. A chat keeps going across questions, comes back when you reopen the panel or relaunch Pauri, and Cmd+N starts a new one. The model picker and tool steps come next. The design is in [docs/spec.md](docs/spec.md) and the work queue is in GitHub Issues.

## Requirements

- macOS
- [Codex CLI](https://github.com/openai/codex) installed and logged in (`codex login`). Pauri runs your own `codex app-server` and never touches your OpenAI credentials.

## Build

You need Command Line Tools (`xcode-select --install`) or Xcode.

- Build: `./scripts/build-app.sh`. It writes `build/Pauri.app`.
- Run: `open build/Pauri.app`.
- Show the panel: Cmd+Shift+Space. Press it again, or Esc, to hide the panel.
- New chat: Cmd+N, or the pencil button at the top right of the panel.
- Change the shortcut: click the gear at the top right of the panel, click the shortcut, and press the new one. Esc cancels.
- Change the transparency: click the gear and drag the Transparency slider between Solid and Glass. Reset it with `defaults delete io.github.godfreyponce.pauri transparency`.
- If the shortcut stops working: run `open build/Pauri.app` again to show the panel, or reset the shortcut with `defaults delete io.github.godfreyponce.pauri hotKey`.
- Quit: `pkill -x Pauri`. Pauri has no Dock icon and no menu.
- Test: `./scripts/test.sh`.

## License

MIT
