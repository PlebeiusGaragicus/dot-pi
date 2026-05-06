/**
 * Twenty Questions Extension
 *
 * Game rules and tool policy live in SYSTEM.md and pi-args.
 * TUI: banner.txt (figlet + usage) and a bordered welcome box with dice emoji,
 * plus title bar and footer hints.
 */

import type { ExtensionAPI, Theme } from "@mariozechner/pi-coding-agent";
import { getAgentDir } from "@mariozechner/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";
import * as fs from "node:fs";
import * as path from "node:path";

const FOOTER_LEFT = " Yes/no only";
const FOOTER_RIGHT = "Say when you are ready to start ";

function readBannerParts(agentDir: string): { art: string; usage: string } | null {
	const bannerPath = path.join(agentDir, "banner.txt");
	if (!fs.existsSync(bannerPath)) return null;
	const raw = fs.readFileSync(bannerPath, "utf-8").trimEnd();
	if (!raw) return null;
	const sepIndex = raw.search(/^---$/m);
	const art = sepIndex !== -1 ? raw.slice(0, sepIndex).trimEnd() : raw;
	const usage = sepIndex !== -1 ? raw.slice(sepIndex + 3).trim() : "";
	return { art, usage };
}

function bannerLines(theme: Theme, parts: { art: string; usage: string }): string[] {
	const out: string[] = [];
	for (const line of parts.art.split("\n")) {
		out.push(theme.bold(theme.fg("accent", line)));
	}
	if (parts.usage) {
		for (const line of parts.usage.split("\n")) {
			out.push(theme.fg("dim", line));
		}
	}
	return out;
}

function welcomeBoxLines(theme: Theme, contentInner: number): string[] {
	const b = (c: string) => theme.fg("accent", c);
	const bar = b("─".repeat(contentInner + 2));
	const top = b("\u256D") + bar + b("\u256E");
	const bottom = b("\u2570") + bar + b("\u256F");

	function row(inner: string): string {
		const pad = Math.max(0, contentInner - visibleWidth(inner));
		return b("│") + " " + inner + " ".repeat(pad) + " " + b("│");
	}

	const title = theme.bold(theme.fg("warning", "\u{1F3B2}  20 Questions"));
	return [
		top,
		row(title),
		row(""),
		row(theme.fg("dim", "Think of something — anything at all.")),
		row(theme.fg("dim", "The agent will ask yes/no questions to guess it.")),
		row(""),
		row(theme.fg("muted", 'Say "I\'m ready" to start the game.')),
		bottom,
	];
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		if (!ctx.hasUI) return;

		const agentDir = getAgentDir();
		const banner = readBannerParts(agentDir);

		setTimeout(() => ctx.ui.setTitle("π - 20 Questions"), 150);

		ctx.ui.setHeader((_tui, theme) => ({
			invalidate() {},
			render(width: number): string[] {
				const contentInner = Math.max(28, Math.min(52, width - 8));
				const lines: string[] = [];
				if (banner) {
					lines.push(...bannerLines(theme, banner), "");
				}
				lines.push(...welcomeBoxLines(theme, contentInner));
				return lines;
			},
		}));

		ctx.ui.setFooter((_tui, theme, _footerData) => ({
			dispose: () => {},
			invalidate() {},
			render(width: number): string[] {
				const left = theme.fg("dim", FOOTER_LEFT);
				const right = theme.fg("dim", FOOTER_RIGHT);
				const pad = " ".repeat(Math.max(1, width - visibleWidth(left) - visibleWidth(right)));
				return [truncateToWidth(left + pad + right, width)];
			},
		}));
	});
}
