# Say Extension (macOS TTS)

Speaks streaming assistant output through macOS `say(1)`. Supports auto-TTS, manual replay, mid-stream cancel, and code-block stripping.

## Files

- `index.ts` -- Streaming line buffer, child-process queue, commands, and shortcuts

## Behavior

- **Auto TTS** -- off by default. Enable per-agent by adding `--tts-enable` to the agent's `pi-args`. Re-read on every `session_start` so the CLI flag wins after `/new`, `/resume`, etc.
- **Streaming** -- splits assistant output on newlines (not punctuation). Each completed line is queued and spoken as soon as it arrives, keeping multi-sentence paragraphs gap-free while still starting speech before generation finishes.
- **Pre-warm** -- the next `say` child is spawned in `SIGSTOP` while the current one is playing, then `SIGCONT`'d on transition to avoid fork/exec/voice-load gaps.
- **Manual** -- `/say` speaks the last assistant reply; `/stop-speaking` halts playback.
- **Toggle** -- `/tts-toggle [on|off]` flips auto TTS until the next `session_start` (when the CLI flag re-wins).
- **Sanitization** -- URLs become "URL redacted"; Markdown `*`, `#`, blockquote `>`, and Unicode box-drawing/tree characters are stripped. Fenced code blocks are skipped (exception: ` ```txt ` and ` ```markdown ` content is read aloud, fence lines never).
- **Cancellation** -- new user prompt, `/stop-speaking`, `/tts-toggle off`, or pi exit all kill the current and pending `say` children.
- **Gating** -- only runs on macOS in an interactive TUI (`ctx.hasUI`).

## Tunables

- `SAY_RATE_WPM` -- words per minute passed to `say -r` (default 320)
- `MAX_CHARS` -- per-utterance character cap (default 32_000)

## Commands

- `/say` -- speak the last assistant reply
- `/stop-speaking` -- cancel current and queued speech
- `/tts-toggle [on|off]` -- toggle or set auto-TTS for the current session

## CLI Flag

- `--tts-enable` -- start the session with auto-TTS on (typically set in `pi-args`)

## Hooks Registered

- `session_start` -- syncs `autoTtsEnabled` from the CLI flag, installs exit handlers
- `assistant_text` (streaming) -- buffers and queues lines as they arrive
- `agent_end` -- fallback to speak anything not yet streamed for the turn
- `before_agent_start` -- cancel speech on a new user prompt

## Related Docs

- [Writing Extensions](https://PlebeiusGaragicus.github.io/dot-pi/reference/extensions/)
