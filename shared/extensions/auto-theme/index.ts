/**
 * Auto Theme — Apply the first custom theme from <agentDir>/themes/.
 *
 * On session start, compares each discovered theme's file path against
 * the agent directory's themes/ folder. The first match that isn't
 * already active gets applied.
 *
 * This lets dot-pi MAS configs and agents ship a default theme via symlinks
 * into themes/ without relying on gitignored settings.json.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { getAgentDir } from "@mariozechner/pi-coding-agent";
import * as path from "node:path";
import * as fs from "node:fs";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		if (!ctx.hasUI) return;

		const customDir = path.join(getAgentDir(), "themes");
		if (!fs.existsSync(customDir)) return;

		const customNames = new Set(
			fs.readdirSync(customDir)
				.filter((f) => f.endsWith(".json"))
				.map((f) => f.slice(0, -5)),
		);

		const themes = ctx.ui.getAllThemes();
		const custom = themes.find((t) => customNames.has(t.name));
		if (custom && ctx.ui.theme.name !== custom.name) {
			ctx.ui.setTheme(custom.name);
		}
	});
}
