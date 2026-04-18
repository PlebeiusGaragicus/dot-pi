/**
 * macOS TTS — speaks assistant text with `say`.
 *
 * - Auto TTS: off by default, or pass `--tts-enable` (e.g. in `pi-args`) for auto TTS on. On every
 *   `session_start` (startup, `/new`, `/resume`, etc.), auto TTS is re-read from that flag so it
 *   stays aligned with the agent’s CLI. `/tts-toggle` (on | off | empty to toggle) applies until
 *   the next `session_start`, when the CLI default wins again.
 * - Streaming: when auto TTS is on, text is split on NEWLINES only (not sentence punctuation) and
 *   each line is queued and spoken as soon as it arrives during assistant streaming. This keeps
 *   multi-sentence paragraphs gap-free (one `say` call per paragraph) while still starting speech
 *   before the full reply is generated. Bullet items, table rows, and paragraph breaks still get
 *   a gap between them because each is its own line in the source text.
 * - Manual: `/say` speaks the last assistant reply in the session; `/stop-speaking` halts it.
 * - Replaces URLs with "URL redacted"; strips Markdown `*` and `#` so `say` does not read them aloud.
 * - Only runs when `ctx.hasUI` (interactive TUI) on macOS.
 * - Speech rate: `say -r` (words per minute), see SAY_RATE_WPM.
 * - A new user prompt, `/stop-speaking`, `/tts-toggle off`, or pi exiting all cancel speech.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { type ChildProcess, spawn } from "node:child_process";

const URL_REDACTED = "URL redacted";
const MAX_CHARS = 32_000;
/** Words per minute for `say -r` */
const SAY_RATE_WPM = 220;

/** In-memory; synced from `--tts-enable` on every session_start; `/tts-toggle` until next session_start */
let autoTtsEnabled = false;

/** Currently-speaking `say` child, or null. Only one plays at a time. */
let currentSay: ChildProcess | null = null;
/** Pre-warmed next `say` child, started while `currentSay` is playing so the next sentence
 *  does not pay a full fork/exec/voice-load on transition. Audio overlap is prevented by
 *  keeping it SIGSTOPped until the current child exits. */
let pendingSay: { child: ChildProcess } | null = null;
const speechQueue: string[] = [];

/** Per-contentIndex buffers of streamed text not yet terminated by a newline */
const pendingByIndex = new Map<number, string>();
/** Set when streaming has already produced at least one spoken line for the current
 *  turn so the `agent_end` fallback does not re-speak the whole reply. */
let streamedThisTurn = false;
/** True once exit/signal handlers have been installed (only once per process). */
let exitHandlersInstalled = false;

function killChild(c: ChildProcess | null | undefined): void {
	if (!c) return;
	try {
		c.kill("SIGKILL");
	} catch {
		/* ignore — process may already be dead */
	}
}

function stopSay(): void {
	const cur = currentSay;
	currentSay = null;
	const pen = pendingSay;
	pendingSay = null;
	// Resume the pending child before killing so SIGKILL actually delivers (SIGSTOPped
	// processes queue signals but our SIGKILL should go through regardless; doing the
	// SIGCONT first is belt-and-suspenders).
	if (pen) {
		try {
			pen.child.kill("SIGCONT");
		} catch {
			/* ignore */
		}
		killChild(pen.child);
	}
	killChild(cur);
}

function resetSpeechState(): void {
	speechQueue.length = 0;
	pendingByIndex.clear();
	streamedThisTurn = false;
	stopSay();
}

/** http(s) URLs and bare www.… tokens */
function redactUrlsForSpeech(text: string): string {
	let s = text.replace(/https?:\/\/\S+/gi, URL_REDACTED);
	s = s.replace(/\bwww\.\S+/gi, URL_REDACTED);
	return s.replace(/\s+/g, " ").trim();
}

/** Remove common Markdown markers the speech synthesizer would speak literally */
function stripMarkdownForSpeech(text: string): string {
	return text.replace(/[*#]/g, "").replace(/\s+/g, " ").trim();
}

type ContentPart = { type: string; text?: string };

function assistantToSpeechText(msg: Record<string, unknown>): string | null {
	if (msg.role !== "assistant" || !Array.isArray(msg.content)) return null;

	const sr = msg.stopReason;
	if (sr === "error" || sr === "aborted") return null;

	const chunks: string[] = [];
	for (const part of msg.content as ContentPart[]) {
		if (part.type === "text" && typeof part.text === "string") chunks.push(part.text);
	}
	const raw = chunks.join("");
	const cleaned = stripMarkdownForSpeech(redactUrlsForSpeech(raw));
	if (cleaned.length === 0) return null;
	return cleaned.length > MAX_CHARS ? cleaned.slice(0, MAX_CHARS) : cleaned;
}

function getLastAssistantSpeechText(messages: unknown[]): string | null {
	for (let i = messages.length - 1; i >= 0; i--) {
		const text = assistantToSpeechText(messages[i] as Record<string, unknown>);
		if (text !== null) return text;
	}
	return null;
}

function getLastAssistantSpeechTextFromSession(entries: unknown[]): string | null {
	for (let i = entries.length - 1; i >= 0; i--) {
		const e = entries[i] as { type?: string; message?: unknown };
		if (e.type !== "message" || e.message === undefined) continue;
		const text = assistantToSpeechText(e.message as Record<string, unknown>);
		if (text !== null) return text;
	}
	return null;
}

/** Split a buffer into complete lines + the remainder. Boundaries are one or more
 *  consecutive newlines; empty lines are dropped. Splitting on newlines (rather than
 *  sentence punctuation) lets a whole paragraph play as one `say` invocation, which is
 *  gap-free internally — the only remaining gaps are where the source text itself has
 *  a line break (bullet items, table rows, paragraph breaks). The trailing remainder
 *  (everything after the last newline) is buffered until either another newline arrives
 *  or `text_end`/`message_end`/`agent_end` flushes it. */
const LINE_END = /\n+/g;
function extractLines(buf: string): { lines: string[]; rest: string } {
	const lines: string[] = [];
	let last = 0;
	LINE_END.lastIndex = 0;
	let m: RegExpExecArray | null = LINE_END.exec(buf);
	while (m !== null) {
		const end = m.index + m[0].length;
		const chunk = buf.slice(last, end).trim();
		if (chunk.length > 0) lines.push(chunk);
		last = end;
		m = LINE_END.exec(buf);
	}
	return { lines, rest: buf.slice(last) };
}

/** Start a `say` child for `text`. Text is fed via stdin (`-f -`) rather than argv so
 *  that messages beginning with `-` or containing `--` aren't mis-parsed as CLI options
 *  by `say`. The pipe is closed immediately so `say` sees EOF and speaks the buffered
 *  text in a single shot. Returns the spawned child.
 *
 *  If `paused` is true, SIGSTOP is sent immediately so the child can initialize in the
 *  background without grabbing the audio device; resume with SIGCONT when ready. The
 *  text is written to the pipe buffer before the SIGSTOP can affect reading, so when
 *  the child is later SIGCONT'd it reads the buffered bytes and starts speaking.
 *
 *  stderr is inherited so any `say` errors (missing voice, audio device busy, etc.) are
 *  visible in the pi log instead of being silently swallowed. */
function spawnSay(text: string, paused: boolean): ChildProcess {
	const child = spawn("say", ["-r", String(SAY_RATE_WPM), "-f", "-"], {
		stdio: ["pipe", "ignore", "inherit"],
	});
	try {
		child.stdin?.end(text);
	} catch {
		/* ignore — child may have died before we could write */
	}
	if (paused) {
		// Fire SIGSTOP immediately. There is a small race where `say` may have already
		// opened the audio device before the signal arrives; in practice the window is
		// short enough that any overlap is a blip, and the parallel fork/exec/voice-load
		// is what we're here to pay for.
		try {
			child.kill("SIGSTOP");
		} catch {
			/* ignore */
		}
	}
	return child;
}

function startSpeaking(text: string): void {
	// Reuse the pre-warmed child if its text matches what we intend to speak next.
	if (pendingSay) {
		const pen = pendingSay.child;
		pendingSay = null;
		currentSay = pen;
		const clear = (): void => {
			if (currentSay === pen) currentSay = null;
			onSayFinished();
		};
		pen.on("exit", clear);
		pen.on("error", clear);
		try {
			pen.kill("SIGCONT");
		} catch {
			/* ignore */
		}
	} else {
		const child = spawnSay(text, false);
		currentSay = child;
		const clear = (): void => {
			if (currentSay === child) currentSay = null;
			onSayFinished();
		};
		child.on("exit", clear);
		child.on("error", clear);
	}
	// Pre-warm the next queued sentence while this one plays.
	prewarmNext();
}

function prewarmNext(): void {
	if (pendingSay) return;
	if (process.platform !== "darwin" || !autoTtsEnabled) return;
	const next = speechQueue[0];
	if (next === undefined) return;
	const child = spawnSay(next, true);
	pendingSay = { child };
	// If the pre-warmed child dies unexpectedly (e.g. SIGKILL from stopSay during a
	// reset), clear the slot so we don't try to SIGCONT a zombie later.
	const clearIfSelf = (): void => {
		if (pendingSay && pendingSay.child === child) pendingSay = null;
	};
	child.on("exit", clearIfSelf);
	child.on("error", clearIfSelf);
}

function onSayFinished(): void {
	if (process.platform !== "darwin" || !autoTtsEnabled) {
		speechQueue.length = 0;
		return;
	}
	const next = speechQueue.shift();
	if (next === undefined) return;
	startSpeaking(next);
}

/** Enqueue `text` for speech. Returns `true` iff text was non-empty after cleaning and
 *  actually made it into the speech pipeline (spawned or queued). Callers use the
 *  return value to decide whether streaming has produced audible output this turn. */
function enqueueSpeech(text: string): boolean {
	const cleaned = stripMarkdownForSpeech(redactUrlsForSpeech(text));
	if (!cleaned) return false;
	const capped = cleaned.length > MAX_CHARS ? cleaned.slice(0, MAX_CHARS) : cleaned;

	if (process.platform !== "darwin" || !autoTtsEnabled) return false;

	if (currentSay === null) {
		// Nothing playing: speak immediately and start pre-warming from the queue head
		// (which is still empty, but `startSpeaking` calls `prewarmNext` which is a
		// no-op when the queue is empty — the next `enqueueSpeech` below pre-warms).
		startSpeaking(capped);
	} else {
		speechQueue.push(capped);
		// If no pre-warm is in flight yet, kick one off for the sentence we just queued.
		prewarmNext();
	}
	return true;
}

/** Speak a full block of text by splitting into lines and enqueueing each.
 *  Used by the manual `/say` command and the `agent_end` fallback. */
function speakBlock(text: string): boolean {
	let any = false;
	const { lines, rest } = extractLines(text);
	for (const line of lines) any = enqueueSpeech(line) || any;
	if (rest.trim()) any = enqueueSpeech(rest) || any;
	return any;
}

function installExitHandlers(): void {
	if (exitHandlersInstalled) return;
	exitHandlersInstalled = true;

	const killOnExit = (): void => {
		// Resume any SIGSTOPped pending child so our SIGKILL definitely takes it down.
		if (pendingSay) {
			try {
				pendingSay.child.kill("SIGCONT");
			} catch {
				/* ignore */
			}
			killChild(pendingSay.child);
			pendingSay = null;
		}
		killChild(currentSay);
		currentSay = null;
	};

	process.once("exit", killOnExit);
	for (const sig of ["SIGINT", "SIGTERM", "SIGHUP"] as const) {
		process.once(sig, () => {
			killOnExit();
		});
	}
}

export default function (pi: ExtensionAPI) {
	installExitHandlers();

	pi.registerFlag("tts-enable", {
		type: "boolean",
		default: false,
		description: "Enable automatic TTS after each assistant reply (macOS say)",
	});

	pi.on("session_start", async () => {
		autoTtsEnabled = pi.getFlag("tts-enable") === true;
	});

	pi.on("before_agent_start", async () => {
		resetSpeechState();
	});

	pi.on("message_update", async (event) => {
		if (process.platform !== "darwin" || !autoTtsEnabled) return;
		const e = event.assistantMessageEvent;
		if (e.type === "text_delta") {
			const prev = pendingByIndex.get(e.contentIndex) ?? "";
			const { lines, rest } = extractLines(prev + e.delta);
			pendingByIndex.set(e.contentIndex, rest);
			for (const line of lines) {
				if (enqueueSpeech(line)) streamedThisTurn = true;
			}
		} else if (e.type === "text_end") {
			const tail = pendingByIndex.get(e.contentIndex) ?? "";
			pendingByIndex.delete(e.contentIndex);
			if (tail.trim() && enqueueSpeech(tail)) streamedThisTurn = true;
		}
	});

	pi.on("message_end", async (event) => {
		const msg = event.message as Record<string, unknown> | undefined;
		const sr = msg?.stopReason;
		if (sr === "error" || sr === "aborted") {
			resetSpeechState();
			return;
		}
		for (const [idx, tail] of pendingByIndex) {
			if (tail.trim() && enqueueSpeech(tail)) streamedThisTurn = true;
			pendingByIndex.delete(idx);
		}
	});

	pi.on("agent_end", async (event, ctx) => {
		if (process.platform !== "darwin" || !ctx.hasUI || !autoTtsEnabled) {
			streamedThisTurn = false;
			return;
		}
		if (streamedThisTurn) {
			streamedThisTurn = false;
			return;
		}

		const text = getLastAssistantSpeechText(event.messages);
		if (text === null) return;
		speakBlock(text);
	});

	pi.on("session_shutdown", async () => {
		resetSpeechState();
	});

	pi.registerCommand("tts-toggle", {
		description: "Toggle or set auto TTS after each reply (on | off | empty to toggle)",
		handler: async (args, ctx) => {
			if (!ctx.hasUI) return;

			const a = args.trim().toLowerCase();

			if (a === "") {
				autoTtsEnabled = !autoTtsEnabled;
			} else if (a === "on") {
				autoTtsEnabled = true;
			} else if (a === "off") {
				autoTtsEnabled = false;
			} else {
				ctx.ui.notify('Usage: /tts-toggle [on|off] — omit args to toggle', "warning");
				return;
			}

			if (!autoTtsEnabled) resetSpeechState();

			ctx.ui.notify(`Auto TTS: ${autoTtsEnabled ? "on" : "off"}`, "info");
		},
	});

	pi.registerCommand("say", {
		description: "Speak the last assistant reply (macOS say)",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;
			if (process.platform !== "darwin") {
				ctx.ui.notify("TTS is only available on macOS", "warning");
				return;
			}

			const text = getLastAssistantSpeechTextFromSession(ctx.sessionManager.getEntries() as unknown[]);
			if (text === null) {
				ctx.ui.notify("No assistant message to speak yet", "info");
				return;
			}

			// Manual replay: stop anything in flight, then enqueue. Temporarily flip auto
			// TTS on so enqueueSpeech will actually start `say`.
			resetSpeechState();
			const wasEnabled = autoTtsEnabled;
			autoTtsEnabled = true;
			try {
				speakBlock(text);
			} finally {
				autoTtsEnabled = wasEnabled;
			}
		},
	});

	pi.registerCommand("stop-speaking", {
		description: "Stop any in-flight macOS `say` speech and clear the TTS queue",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;
			const hadSomething = currentSay !== null || pendingSay !== null || speechQueue.length > 0;
			resetSpeechState();
			ctx.ui.notify(hadSomething ? "Stopped speaking" : "Nothing to stop", "info");
		},
	});
}
