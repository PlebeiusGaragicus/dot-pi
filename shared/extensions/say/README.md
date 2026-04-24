# Say Extension (macOS / Linux TTS)

Speaks streaming assistant output through macOS `say(1)` or Linux `espeak-ng`. Supports auto-TTS, manual replay, mid-stream cancel, and code-block stripping.

## Files

- `index.ts` -- Streaming line buffer, child-process queue, platform backend selection, commands, and shortcuts

> **Why single-file?** This extension is symlinked into every agent (`extensions/say -> ../../../shared/extensions/say`). Pi's jiti loader with `moduleCache: false` can fail to resolve cross-file imports through symlinks. Per-agent custom extensions (real directories, not symlinks) are safe for multi-file splits.

## Behavior

- **Auto TTS** -- off by default. Enable per-agent by adding `--tts-enable` to the agent's `pi-args`. Re-read on every `session_start` so the CLI flag wins after `/new`, `/resume`, etc.
- **Streaming** -- splits assistant output on newlines (not punctuation). Each completed line is queued and spoken as soon as it arrives, keeping multi-sentence paragraphs gap-free while still starting speech before generation finishes.
- **Pre-warm** -- the next TTS child is spawned in `SIGSTOP` while the current one is playing, then `SIGCONT`'d on transition to avoid fork/exec/voice-load gaps.
- **Manual** -- `/say` speaks the last assistant reply; `/stop-speaking` halts playback.
- **Toggle** -- `/tts-toggle [on|off]` flips auto TTS until the next `session_start` (when the CLI flag re-wins).
- **Sanitization** -- URLs become "URL redacted"; Markdown `*`, `#`, blockquote `>`, and Unicode box-drawing/tree characters are stripped. Fenced code blocks are skipped (exception: ` ```txt ` and ` ```markdown ` content is read aloud, fence lines never).
- **Cancellation** -- new user prompt, `/stop-speaking`, `/tts-toggle off`, or pi exit all kill the current and pending TTS children.
- **Gating** -- only runs in an interactive TUI (`ctx.hasUI`) when a TTS backend is available (`say` on macOS, `espeak-ng` on Linux).

## Platform Notes

- **macOS**: uses the built-in `say` command. No extra install needed.
- **Linux**: uses `espeak-ng`. Install with `sudo apt install espeak-ng` (Debian/Ubuntu) or the equivalent for your distro. Voice quality is robotic but startup is fast, making it well-suited to the streaming prewarm model. If `espeak-ng` is not on `PATH` the extension loads silently and all TTS hooks no-op.
- **Other platforms**: TTS is unavailable; the extension loads but does nothing.

Future backends (piper, mimic3, etc.) can be added to the `resolveBackend()` function in `index.ts`.

## Tunables

- `SAY_RATE_WPM` -- words per minute passed to the TTS backend (default 320)
- `MAX_CHARS` -- per-utterance character cap (default 32_000)

## Commands

- `/say` -- speak the last assistant reply
- `/stop-speaking` -- cancel current and queued speech
- `/tts-toggle [on|off]` -- toggle or set auto-TTS for the current session

## CLI Flag

- `--tts-enable` -- start the session with auto-TTS on (typically set in `pi-args`)

## Hooks Registered

- `session_start` -- syncs `autoTtsEnabled` from the CLI flag, installs exit handlers
- `message_update` (streaming) -- buffers and queues lines as they arrive
- `agent_end` -- fallback to speak anything not yet streamed for the turn
- `before_agent_start` -- cancel speech on a new user prompt

## Related Docs

- [Writing Extensions](https://PlebeiusGaragicus.github.io/dot-pi/reference/extensions/)
