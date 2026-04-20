/**
 * Startup Branding — render a custom header from banner.txt.
 *
 * On session start, reads <agentDir>/banner.txt and replaces the
 * built-in header via ctx.ui.setHeader(). Works with quietStartup
 * (the empty built-in header gets swapped for the branded one).
 *
 * File format (plain text, optional --- separator):
 *   - Everything above the first "---" line renders in accent color (bold).
 *   - Everything below renders in dim color.
 *   - If no separator exists, the entire file renders in accent color.
 *
 * Generate banner.txt with: figlet -f small "<name>" > banner.txt
 * Then append usage/description text below a "---" line.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { getAgentDir } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";
import * as fs from "node:fs";
import * as path from "node:path";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		if (!ctx.hasUI) return;

		const bannerPath = path.join(getAgentDir(), "banner.txt");
		if (!fs.existsSync(bannerPath)) return;

		const raw = fs.readFileSync(bannerPath, "utf-8").trimEnd();
		if (!raw) return;

		const sepIndex = raw.search(/^---$/m);
		const art = sepIndex !== -1 ? raw.slice(0, sepIndex).trimEnd() : raw;
		const usage = sepIndex !== -1 ? raw.slice(sepIndex + 3).trim() : "";

		ctx.ui.setHeader((_tui, theme) => {
			const styledArt = theme.bold(theme.fg("accent", art));
			const styledUsage = usage ? "\n" + theme.fg("dim", usage) : "";
			return new Text(styledArt + styledUsage, 1, 1);
		});
	});
}
