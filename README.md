# Pauri

A floating quick-chat window for macOS. Press a hotkey, ask a question, and get an answer from Codex in a small glass panel that stays on top of everything. It can also act on your Mac: read files, run commands (with your OK), and see the text you selected.

The name: P from *Proxima*, the rest from *Centauri*. The nearest star, always close.

## Status

The panel opens on a hotkey. Type a question and press Return: the answer streams in from your own `codex app-server`. A chat keeps going across questions, comes back when you reopen the panel or relaunch Pauri, and Cmd+N starts a new one. When a chat gets long, a banner offers a handoff draft (a new chat with a summary of the old one in the box) or a blank new chat. The text selected in the front app comes along with the question. A mic button turns speech into text in the input box, on-device. A camera button attaches one screenshot to the next question. The model picker and tool steps come next. The design is in [docs/spec.md](docs/spec.md) and the work queue is in GitHub Issues.

## Requirements

- macOS
- [Codex CLI](https://github.com/openai/codex) installed and logged in (`codex login`). Pauri runs your own `codex app-server` and never touches your OpenAI credentials.

## Build

You need Command Line Tools (`xcode-select --install`) or Xcode.

- Build: `./scripts/build-app.sh`. It writes `build/Pauri.app`.
- Run: `open build/Pauri.app`.
- Show the panel: Cmd+Shift+Space. Press it again, or Esc, to hide the panel.
- New chat: Cmd+N, or the pencil button at the top right of the panel.
- See the context banner in a short chat: `defaults write io.github.godfreyponce.pauri contextBannerDebug -bool YES`, then ask one question. Turn it off with `defaults delete io.github.godfreyponce.pauri contextBannerDebug`.
- Change the shortcut: click the gear at the top right of the panel, click the shortcut, and press the new one. Esc cancels.
- Change the transparency: click the gear and drag the Transparency slider between Solid and Glass. Reset it with `defaults delete io.github.godfreyponce.pauri transparency`.
- Attach selected text: select text in any app, then press the shortcut. A chip above the input shows it, and the x removes it. The first time, Pauri asks for Accessibility access. Turn it on or off in System Settings > Privacy & Security > Accessibility. After a rebuild, macOS forgets the grant: run `tccutil reset Accessibility io.github.godfreyponce.pauri && defaults delete io.github.godfreyponce.pauri askedForSelectionAccess`, then press the shortcut and click Allow again.
- Dictate: click the mic left of the send button and speak; the words show in the box. Click it again to stop. Speech is recognized on this Mac only and works offline. The first time, macOS asks for Microphone and Speech Recognition access. Turn them on or off in System Settings > Privacy & Security. After a rebuild, reset them with `tccutil reset Microphone io.github.godfreyponce.pauri && tccutil reset SpeechRecognition io.github.godfreyponce.pauri`.
- Attach a screenshot: click the camera button left of the mic. Pauri takes one picture of the screen it is on, without its own window, and shows it as a chip above the input; the x removes it. It goes with your next question, and the file is deleted when the answer ends. The first time, macOS asks for Screen Recording access. Turn it on in System Settings > Privacy & Security > Screen & System Audio Recording, then quit and reopen Pauri. After a rebuild, reset it with `tccutil reset ScreenCapture io.github.godfreyponce.pauri`.
- If the shortcut stops working: run `open build/Pauri.app` again to show the panel, or reset the shortcut with `defaults delete io.github.godfreyponce.pauri hotKey`.
- Quit: `pkill -x Pauri`. Pauri has no Dock icon and no menu.
- Test: `./scripts/test.sh`.

## License

MIT
