/**
 * Chart — Inline chart display with dual-mode rendering
 *
 * After each bash execution, scans charts/ for new PNGs and displays
 * them inline. Rendering mode is chosen by terminal capability:
 *
 *   - Image protocol terminals (iTerm2, Kitty, Ghostty, WezTerm):
 *     pi-tui Image component with native protocol rendering
 *
 *   - Terminal.app / unknown: ANSI true-color half-block art via a
 *     Python helper script (Pillow, bundled with matplotlib)
 *
 * Also intercepts `read` tool results to strip image content blocks
 * that cause API errors with providers that don't support multimodal
 * tool results.
 *
 * Usage: pi -e extensions/ui/chart.ts
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { isToolCallEventType } from "@mariozechner/pi-coding-agent";
import { Image, Box, Text } from "@mariozechner/pi-tui";
import { readdir, readFile } from "node:fs/promises";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ANSI_SCRIPT = join(__dirname, "..", "..", "scripts", "png_to_ansi.py");

const IMAGE_EXTS = [".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg"];
const IMAGE_CAPABLE_TERMINALS = new Set(["iTerm.app", "WezTerm", "ghostty"]);

function isImagePath(path: string): boolean {
	const lower = path.toLowerCase();
	return IMAGE_EXTS.some((ext) => lower.endsWith(ext));
}

function hasImageProtocol(): boolean {
	if (process.env.KITTY_PID) return true;
	const term = process.env.TERM_PROGRAM ?? "";
	return IMAGE_CAPABLE_TERMINALS.has(term);
}

export default function (pi: ExtensionAPI) {
	const displayedCharts = new Set<string>();
	const useImageProtocol = hasImageProtocol();

	pi.on("session_start", async (_event, ctx) => {
		const chartsDir = join(ctx.cwd, "charts");
		try {
			const files = await readdir(chartsDir);
			for (const file of files) {
				if (file.endsWith(".png")) {
					displayedCharts.add(join(chartsDir, file));
				}
			}
		} catch {}
	});

	pi.registerMessageRenderer("chart-image", (message, _options, theme) => {
		const { filename } = message.details;
		const box = new Box(1, 1, (t: string) => theme.bg("customMessageBg", t));
		box.addChild(new Text(theme.fg("success", "Chart ") + theme.fg("dim", filename), 0, 0));

		if (useImageProtocol) {
			const imageTheme = { fallbackColor: (s: string) => theme.fg("dim", s) };
			box.addChild(new Image(message.details.base64, "image/png", imageTheme, { maxWidthCells: 80, maxHeightCells: 24 }));
		} else if (message.details.ansi) {
			box.addChild(new Text(message.details.ansi, 0, 0));
		}

		return box;
	});

	// Block `read` on image files — they're already displayed inline and
	// image content blocks in tool results crash non-multimodal APIs.
	pi.on("tool_call", async (event, _ctx) => {
		if (isToolCallEventType("read", event) && isImagePath(event.input.path)) {
			return {
				block: true,
				reason:
					"Image files are displayed inline automatically by the chart extension. " +
					"Do not read image files — describe the chart based on the data and script that generated it.",
			};
		}
	});

	// Safety net: strip image content blocks from any tool result so
	// providers that don't support multimodal tool_result won't 400.
	pi.on("tool_result", async (event, _ctx) => {
		if (!Array.isArray(event.content)) return;
		const hasImage = event.content.some((block: any) => block.type === "image");
		if (!hasImage) return;

		const filtered = event.content
			.filter((block: any) => block.type !== "image")
			.concat({
				type: "text" as const,
				text: "[Image content stripped — displayed inline in terminal]",
			});

		return { content: filtered };
	});

	pi.on("tool_execution_end", async (event, ctx) => {
		if (event.toolName !== "bash") return;

		const chartsDir = join(ctx.cwd, "charts");
		let files: string[];
		try {
			files = await readdir(chartsDir);
		} catch {
			return;
		}

		for (const file of files.sort()) {
			if (!file.endsWith(".png")) continue;
			const fullPath = join(chartsDir, file);
			if (displayedCharts.has(fullPath)) continue;
			displayedCharts.add(fullPath);

			try {
				const details: Record<string, any> = { filename: file };

				if (useImageProtocol) {
					const data = await readFile(fullPath);
					details.base64 = data.toString("base64");
				} else {
					const cols = String(Math.max(20, (process.stdout.columns || 80) - 2));
					const result = await pi.exec(
						"uv",
						["run", "--with", "Pillow", "python", ANSI_SCRIPT, fullPath, cols],
						{ timeout: 15000 },
					);
					if (result.code === 0 && result.stdout) {
						details.ansi = result.stdout;
					}
				}

				pi.sendMessage({
					customType: "chart-image",
					content:
						`Chart ${file} is now displayed inline. ` +
						"Do not read this file. Describe what the chart shows based on the data and script.",
					display: true,
					details,
				});
			} catch {}
		}
	});
}
