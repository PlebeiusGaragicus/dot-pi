/**
 * Exa API key helper.
 *
 * Search itself lives in the `exa-search` skill scripts. This extension only
 * provides `/exa-api-key` so users can configure a repo-local key like Tavily.
 *
 * API key resolution (in priority order):
 *   1. EXA_API_KEY environment variable
 *   2. repo-root `.exa.env` file (written by /exa-api-key)
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import * as fs from "node:fs";
import * as path from "node:path";

const EXA_KEY_FILE = ".exa.env";

function findDotPiRoot(): string {
	if (!process.env.DOT_PI_DIR) {
		throw new Error("DOT_PI_DIR is not set; run this extension through dispatch-agent.");
	}
	return process.env.DOT_PI_DIR;
}

function loadExaKey(): string | null {
	const envKey = process.env.EXA_API_KEY?.trim();
	if (envKey && envKey !== "$EXA_API_KEY") return envKey;

	const keyPath = path.join(findDotPiRoot(), EXA_KEY_FILE);
	if (!fs.existsSync(keyPath)) return null;

	const content = fs.readFileSync(keyPath, "utf-8").trim();
	const match = content.match(/^(?:EXA_API_KEY\s*=\s*)?(.+)$/m);
	return match?.[1]?.trim() || null;
}

function saveExaKey(key: string): string {
	const keyPath = path.join(findDotPiRoot(), EXA_KEY_FILE);
	fs.writeFileSync(keyPath, `EXA_API_KEY=${key}\n`, "utf-8");
	return keyPath;
}

function maskKey(key: string): string {
	if (key.length <= 6) return "****";
	return `${key.slice(0, 4)}****${key.slice(-2)}`;
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("exa-api-key", {
		description: "Set or update your Exa API key",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;

			const current = loadExaKey();
			ctx.ui.notify(`Current key: ${current ? maskKey(current) : "(not set)"}`, "info");

			const input = await ctx.ui.input("Paste your Exa API key (from https://dashboard.exa.ai/api-keys)");
			if (!input?.trim()) {
				ctx.ui.notify("Cancelled", "info");
				return;
			}

			const keyPath = saveExaKey(input.trim());
			ctx.ui.notify(`Saved to ${keyPath}`, "info");
		},
	});
}
