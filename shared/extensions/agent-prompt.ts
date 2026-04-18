/**
 * Agent Prompt — standalone agent equivalent of team-prompt.md.
 *
 * Reads AGENT.md from PI_CODING_AGENT_DIR at startup.
 * YAML frontmatter: tools (comma list), model (provider/id).
 * Markdown body: appended to the system prompt.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { getAgentDir, parseFrontmatter } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	const agentDir = getAgentDir();
	const agentMdPath = path.join(agentDir, "AGENT.md");

	let body: string | null = null;
	let tools: string[] | null = null;
	let model: string | null = null;

	try {
		if (fs.existsSync(agentMdPath)) {
			const raw = fs.readFileSync(agentMdPath, "utf-8").trim();
			const { frontmatter, body: mdBody } = parseFrontmatter<Record<string, string>>(raw);
			body = mdBody.trim() || null;
			model = frontmatter.model || null;
			if (frontmatter.tools) {
				tools = frontmatter.tools
					.split(",")
					.map((t: string) => t.trim())
					.filter(Boolean);
			}
		}
	} catch {
		/* ignore — AGENT.md is optional */
	}

	if (tools) {
		pi.on("session_start", async () => {
			pi.setActiveTools(tools!);
		});
	}

	if (model) {
		pi.on("session_start", async (_event, ctx) => {
			const sep = model!.indexOf("/");
			if (sep > 0) {
				const provider = model!.slice(0, sep);
				const modelId = model!.slice(sep + 1);
				const m = ctx.modelRegistry.find(provider, modelId);
				if (m) await pi.setModel(m);
			}
		});
	}

	if (body) {
		pi.on("before_agent_start", async (event) => {
			return { systemPrompt: event.systemPrompt + "\n\n" + body };
		});
	}
}
