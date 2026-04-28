/**
 * Run Timer — live elapsed time for each agent turn.
 *
 * Shows a status segment while the agent is running, then leaves the final
 * trajectory time visible after the turn completes.
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

const STATUS_KEY = "run-timer";
const UPDATE_INTERVAL_MS = 1000;

function pad(value: number): string {
	return value.toString().padStart(2, "0");
}

function formatElapsed(ms: number): string {
	const totalSeconds = Math.max(0, Math.floor(ms / 1000));
	const seconds = totalSeconds % 60;
	const totalMinutes = Math.floor(totalSeconds / 60);
	const minutes = totalMinutes % 60;
	const hours = Math.floor(totalMinutes / 60);

	if (hours > 0) return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
	return `${pad(minutes)}:${pad(seconds)}`;
}

export default function (pi: ExtensionAPI) {
	let startedAt: number | undefined;
	let timer: ReturnType<typeof setInterval> | undefined;
	let generation = 0;

	function clearTimer(): void {
		if (!timer) return;
		clearInterval(timer);
		timer = undefined;
	}

	function renderRunning(ctx: ExtensionContext, currentGeneration: number): void {
		if (!ctx.hasUI || startedAt === undefined || currentGeneration !== generation) return;
		ctx.ui.setStatus(STATUS_KEY, ctx.ui.theme.fg("warning", `Running: ${formatElapsed(Date.now() - startedAt)}`));
	}

	pi.on("before_agent_start", async (_event, ctx) => {
		if (!ctx.hasUI) return;

		clearTimer();
		startedAt = Date.now();
		const currentGeneration = ++generation;

		renderRunning(ctx, currentGeneration);
		timer = setInterval(() => renderRunning(ctx, currentGeneration), UPDATE_INTERVAL_MS);
	});

	pi.on("agent_end", async (_event, ctx) => {
		if (!ctx.hasUI || startedAt === undefined) return;

		clearTimer();
		generation++;
		const elapsed = Date.now() - startedAt;
		startedAt = undefined;

		ctx.ui.setStatus(STATUS_KEY, ctx.ui.theme.fg("success", `Trajectory time: ${formatElapsed(elapsed)}`));
	});
}
