/**
 * Exa API key helper.
 *
 * Search itself lives in the `exa-search` skill scripts. This extension only
 * provides `/exa-api-key` so users can configure a repo-local key like Tavily.
 *
 * API key resolution (in priority order):
 *   1. EXA_API_KEY environment variable
 *   2. `$DOT_PI_OVERLAY/env.exa` (overlay only)
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import * as fs from "node:fs";
import { ensureOverlayDir, overlayFile, overlayFirstFile } from "../lib/dotpi-paths.js";

const EXA_KEY_FILE = "env.exa";

function loadExaKey(): string | null {
	const envKey = process.env.EXA_API_KEY?.trim();
	if (envKey && envKey !== "$EXA_API_KEY") return envKey;

	const keyPath = overlayFirstFile(EXA_KEY_FILE);
	if (!fs.existsSync(keyPath)) return null;

	const content = fs.readFileSync(keyPath, "utf-8").trim();
	const match = content.match(/^(?:EXA_API_KEY\s*=\s*)?(.+)$/m);
	return match?.[1]?.trim() || null;
}

function saveExaKey(key: string): string {
	ensureOverlayDir();
	const keyPath = overlayFile(EXA_KEY_FILE);
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
