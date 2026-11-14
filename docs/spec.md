# Pauri: design seed

*Spec seed from /idea intake, 2026-11-13. Four question rounds. Nothing built yet.*

## What it is

A floating quick-chat window for macOS that stays on top of everything, opens on a global hotkey, and looks like the ChatGPT classic app's companion window. It talks to OpenAI through the owner's own Codex subscription, not Claude usage, by driving the local `codex app-server` the way T3 Code does. Unlike the ChatGPT window, it can act on the Mac: read files, run commands, see selected text. Open source.

**Name:** Pauri. P from *Proxima*, ending from *Centauri*: the nearest star, always close.

**Why now:** the ChatGPT classic Mac app shows a banner saying it retires on January 30, 2027. The companion window the owner uses every day goes with it.

Reference screenshots (the owner's, from the intake thread), in `docs/reference/`:
- [chatgpt-window.png](reference/chatgpt-window.png): the ChatGPT window being recreated.
- [retirement-banner.png](reference/retirement-banner.png): the retirement banner; target simplicity.
- [send-orb.png](reference/send-orb.png): the send button to copy (purple starry glowing orb).
- [floating-over-apps.png](reference/floating-over-apps.png): the window floating over other apps; Pauri should be see-through here.

## Decisions

### Scope
1. **Core reason to exist:** it can act on the Mac (Codex tools), not just chat. Rejected: a reskin of ChatGPT; one window for both Codex and Claude.
2. **Platform:** macOS only for v1.
3. **Stack:** native Swift, SwiftUI inside an `NSPanel` (always on top, works over fullscreen apps, global hotkey). Tauri is the fallback only if the web UI route is wanted later.
4. **Hotkey:** user-configurable, default is not Option+Space so it does not clash with the ChatGPT app. The owner can move it to Option+Space after ChatGPT classic is gone.

### Backend
5. **Auth:** Pauri never handles OpenAI credentials. It spawns the user's installed and logged-in `codex` CLI (`codex app-server`), like T3 Code. Requirement for users: Codex CLI installed and `codex login` done.
6. **Speed:** first tokens in about a second. One Codex process stays warm in the background. Quick questions go to a fast model at low reasoning effort; bigger models come from the in-window picker. No direct OpenAI API calls (the subscription does not cover them).
7. **Default model:** the model that `codex app-server`'s `model/list` marks `isDefault`, at low reasoning effort on Codex's Fast service tier (`priority`). Pauri asks for low effort only when the model lists it in `supportedReasoningEfforts`, else it uses the model's default effort; it asks for the Fast tier only when the model lists `priority` in `serviceTiers`, else it sends no tier and the label has no "Fast". No model id is written into Pauri. The picker lists that default entry first, then each model `model/list` reports that is not `hidden`, at its default effort and standard speed; a default entry without the Fast tier takes the place of its model's line (checked on codex-cli 0.169.0). With a model, Pauri sends `model` and `effort` on every `turn/start`, because the user's own Codex config can set a higher effort, plus `serviceTierForTurn` when the entry has a tier. When `model/list` fails or lists no model, Pauri sends no `model`, and Codex uses its own default.
8. **Web search:** on by default. Codex has no per-turn flag; it is the `web_search` config key (`live` when on, `disabled` when off), set per thread through `config` on `thread/start` and `thread/resume`. A change mid-chat reloads the thread (`thread/unsubscribe`, then `thread/resume`) before the next message. Off turns off Codex's search tool only: Codex can still try a shell command such as `curl`, which the read-only sandbox blocks and which then asks for approval. Checked on codex-cli 0.169.0.

### Safety
9. **Permissions:** reads without asking; asks before every file write or command, with an "allow for this chat" option. Codex read-only sandbox plus its approval prompts.
10. **Context from the frontmost app:** v1 takes the selected text, plus a screenshot only when the user presses a button. Needs Accessibility and Screen Recording, requested on first use. Never watches the screen continuously.

### Chat behavior
11. **History:** reopens the last chat; Cmd+N starts a new one. A history list comes later.
12. **Context-full handoff:** when the chat gets long, a banner says so and offers two buttons: "Write a handoff draft" (new chat seeded with a summary of the old one) and "New chat" (blank). The trigger threshold is a guess, labeled as one, and tunable; base it on Codex's reported token usage against the model's context window.
13. **Tool activity in the chat:** one small gray line per step ("Read 2 files", "Ran `git status`"), expandable for details; a full approval card when it needs an OK. These lines are UI only and cost the model no context. Context stays lean because quick questions use no tools and context capture is single-item (decision 10).

### Look
14. **Overall:** as simple as the ChatGPT window and T3 Code. Input bar holds a model picker, web search toggle (on), dictation button, send button.
15. **Send button:** a purple starry glowing orb (reference screenshot), small animation on send.
16. **Window:** macOS glass material so what's behind shows through, one transparency slider.
17. **Dictation:** Apple's on-device speech recognition (free, private, no subscription use). Fallback: a local Whisper model if Apple's struggles with code words.

### Repo
18. **Visibility and license:** public from the first commit, MIT. Lives at `~/Developer/pauri`. **Check at bootstrap** that the name is free on GitHub and Homebrew.
19. **Protocol:** bootstrap onto the ticket protocol with `/port-protocol` so it gets STATE.md and the issue queue. Add a PROJECTS.md row.

## Fog

- History list design (decision 11 defers it).
- Distribution: signed and notarized build, Homebrew cask, auto-update.
- Whether the owner moves the hotkey to Option+Space after January 30, 2027.
- Visual polish past the send button and glass: a design-directions pass (4 variants, owner's rule) once the bones work.
- Whether T3 Code's dictation approach is worth matching exactly (not checked).
- Later platforms (Windows, Linux) and a Claude backend: both out of v1, not ruled out forever.

Next: the tickets cut from this spec, in GitHub Issues.
