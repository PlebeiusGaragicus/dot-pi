/**
 * Startup Branding — render a custom header from banner.txt.
 *
 * On session start, reads <agentDir>/banner.txt and replaces the
 * built-in header via ctx.ui.setHeader(). Works with quietStartup
 * (the empty built-in header gets swapped for the branded one).
 * Also sets the terminal title to the first user prompt, trimmed to
 * 30 characters, once that prompt is available.
 *
 * File format (plain text, optional --- separator):
 *   - Everything above the first "---" line renders in accent color (bold).
 *   - Everything below renders in dim color.
 *   - If no separator exists, the entire file renders in accent color.
 *
 * Generate banner.txt with: figlet -f small "<name>" > banner.txt
 * Then append usage/description text below a "---" line.
 */

import type { ExtensionAPI, ExtensionContext, SessionEntry } from "@mariozechner/pi-coding-agent";
import { getAgentDir } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";
import * as fs from "node:fs";
import * as path from "node:path";

const TITLE_MAX_CHARS = 30;

function promptToTitle(prompt: string): string {
	const normalized = prompt.replace(/\s+/g, " ").trim();
	return normalized.length > TITLE_MAX_CHARS ? normalized.slice(0, TITLE_MAX_CHARS) : normalized;
}

function textFromContent(content: unknown): string {
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return "";

	const textParts: string[] = [];
	for (const part of content) {
		if (!part || typeof part !== "object") continue;
		const maybeText = (part as { type?: unknown; text?: unknown });
		if (maybeText.type === "text" && typeof maybeText.text === "string") {
			textParts.push(maybeText.text);
		}
	}

	return textParts.join(" ");
}

function firstUserPromptFromBranch(entries: SessionEntry[]): string {
	for (const entry of entries) {
		if (entry.type !== "message") continue;

		const message = entry.message as { role?: unknown; content?: unknown };
		if (message.role !== "user") continue;

		const prompt = textFromContent(message.content);
		if (prompt.trim()) return prompt;
	}

	return "";
}

function expandEnvVars(value: string): string {
	return value.replace(/\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?/g, (_match, name: string) => process.env[name] ?? "");
}

function readPiArgs(agentDir: string): string[] {
	const piArgsPath = path.join(agentDir, "pi-args");
	if (!fs.existsSync(piArgsPath)) return [];

	const args: string[] = [];
	try {
		const lines = fs.readFileSync(piArgsPath, "utf-8").split(/\r?\n/);
		for (const rawLine of lines) {
			const line = expandEnvVars(rawLine.trim());
			if (!line || line.startsWith("#")) continue;
			args.push(...line.split(/\s+/).filter(Boolean));
		}
	} catch {
		return [];
	}

	return args;
}

function parseConfiguredTools(args: string[]): string[] | null {
	const tools: string[] = [];
	for (let i = 0; i < args.length; i++) {
		const arg = args[i];
		if (arg === "--no-tools") return [];
		if (arg === "--tools") {
			const value = args[i + 1];
			if (value && !value.startsWith("--")) {
				tools.push(...value.split(",").map((tool) => tool.trim()).filter(Boolean));
				i++;
			}
		} else if (arg.startsWith("--tools=")) {
			tools.push(...arg.slice("--tools=".length).split(",").map((tool) => tool.trim()).filter(Boolean));
		}
	}
	return tools.length > 0 ? Array.from(new Set(tools)) : null;
}

function formatToolsReport(agentDir: string): string {
	const args = readPiArgs(agentDir);
	const tools = parseConfiguredTools(args);
	const contextFilesDisabled = args.includes("--no-context-files");

	const lines = [`Agent config: ${agentDir}`, ""];
	if (tools === null) {
		lines.push("Configured tools: not restricted in pi-args");
	} else if (tools.length === 0) {
		lines.push("Configured tools: none (--no-tools)");
	} else {
		lines.push("Configured tools:");
		for (const tool of tools) lines.push(`- ${tool}`);
	}
	lines.push("", `Context files: ${contextFilesDisabled ? "disabled (--no-context-files)" : "enabled"}`);
	return lines.join("\n");
}

export default function (pi: ExtensionAPI) {
	let titleSet = false;
	let sessionGeneration = 0;

	function setTitleFromPrompt(ctx: ExtensionContext, prompt: string): void {
		if (titleSet || !ctx.hasUI) return;

		const title = promptToTitle(prompt);
		if (!title) return;

		ctx.ui.setTitle(title);
		titleSet = true;
	}

	pi.on("session_start", async (_event, ctx) => {
		titleSet = false;
		const generation = ++sessionGeneration;

		if (!ctx.hasUI) return;

		setTimeout(() => {
			if (generation !== sessionGeneration) return;
			const prompt = firstUserPromptFromBranch(ctx.sessionManager.getBranch());
			setTitleFromPrompt(ctx, prompt);
		}, 200);

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

	pi.on("before_agent_start", async (event, ctx) => {
		setTitleFromPrompt(ctx, event.prompt);
	});

	pi.registerCommand("tools", {
		description: "Show configured tools from this agent's pi-args",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;
			ctx.ui.notify(`Configured tools\n\n${formatToolsReport(getAgentDir())}`, "info");
		},
	});
}
