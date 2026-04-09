/**
 * Chat Mode — Pure conversational agent with no tools
 *
 * Disables all tools so the model can only converse using its
 * parametric knowledge. Useful for quick questions, brainstorming,
 * and discussions where file access is unnecessary.
 *
 * Usage: pi -e extensions/workflow/chat.ts
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { applyExtensionDefaults } from "../themeMap.ts";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		applyExtensionDefaults(import.meta.url, ctx);
		pi.setActiveTools([]);
		if (ctx.hasUI) {
			ctx.ui.setStatus("mode", ctx.ui.theme.fg("accent", "chat"));
		}
	});

	pi.on("before_agent_start", async (event) => {
		return {
			systemPrompt: event.systemPrompt + `\n\n` +
				`You are in CHAT MODE. You have no tools — no file access, no shell, no code execution. ` +
				`Answer questions directly from your knowledge. Be concise and conversational. ` +
				`Do not attempt to read files, run commands, or use any tools.`,
		};
	});
}
