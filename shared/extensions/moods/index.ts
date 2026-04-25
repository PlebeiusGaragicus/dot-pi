/**
 * Moods Extension
 *
 * One slash command, markdown files in `<agentDir>/moods/`:
 * - `/mood <name>` — replaces the system prompt with the body of
 *   `<agentDir>/moods/<name>.md` (one active at a time).
 * - `/mood off|none|clear` — revert to the agent's default `SYSTEM.md`.
 *
 * Optional YAML frontmatter in each mood file:
 *   tools: comma-separated tool names to activate (others deactivated)
 *   skills: comma-separated skill paths (relative to agent dir)
 *   theme: theme name to switch to
 *
 * State is persisted via `pi.appendEntry` and restored on `session_start`,
 * so the active mood survives `--resume`.
 *
 * If `moods/` is missing or empty, the extension silently no-ops.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { getAgentDir, parseFrontmatter } from "@mariozechner/pi-coding-agent";

interface MoodConfig {
	description?: string;
	emoji?: string;
	tools?: string[];
	skills?: string[];
	theme?: string;
}

interface MoodFile {
	body: string;
	config: MoodConfig;
}

const CLEAR_TOKENS = new Set(["none", "clear", "off"]);

function splitCsv(value: unknown): string[] | undefined {
	if (typeof value !== "string" || !value.trim()) return undefined;
	return value
		.split(",")
		.map((s) => s.trim())
		.filter(Boolean);
}

function loadMoods(dir: string): Map<string, MoodFile> {
	const out = new Map<string, MoodFile>();
	if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) return out;
	for (const file of fs.readdirSync(dir)) {
		if (!file.endsWith(".md")) continue;
		const name = path.basename(file, ".md").toLowerCase();
		try {
			const raw = fs.readFileSync(path.join(dir, file), "utf-8");
			const { frontmatter, body } = parseFrontmatter<Record<string, string>>(raw);
			const trimmed = body.trim();
			if (!trimmed) continue;
			const config: MoodConfig = {
				description: typeof frontmatter?.description === "string" ? frontmatter.description.trim() || undefined : undefined,
				emoji: typeof frontmatter?.emoji === "string" ? frontmatter.emoji.trim() || undefined : undefined,
				tools: splitCsv(frontmatter?.tools),
				skills: splitCsv(frontmatter?.skills),
				theme: typeof frontmatter?.theme === "string" ? frontmatter.theme.trim() || undefined : undefined,
			};
			out.set(name, { body: trimmed, config });
		} catch {
			/* skip unreadable files */
		}
	}
	return out;
}

export default function moodsExtension(pi: ExtensionAPI): void {
	const agentDir = getAgentDir();
	const moods = loadMoods(path.join(agentDir, "moods"));

	if (moods.size === 0) return;

	let activeMood: string | null = null;
	let baselineTools: string[] | null = null;
	let baselineTheme: string | null = null;

	function listNames(): string {
		return [...moods.keys()].sort().join(", ") || "(none)";
	}

	function updateStatus(ctx: ExtensionContext): void {
		if (!activeMood) {
			ctx.ui.setStatus("moods", ctx.ui.theme.fg("muted", "🥧 default pi system prompt"));
			return;
		}
		const m = moods.get(activeMood);
		const emoji = m?.config.emoji ?? "🎭";
		ctx.ui.setStatus("moods", ctx.ui.theme.fg("accent", `${emoji} ${activeMood}`));
	}

	function persist(): void {
		pi.appendEntry("moods", { mood: activeMood });
	}

	function captureBaseline(ctx: ExtensionContext): void {
		if (baselineTools === null) baselineTools = pi.getActiveTools();
		if (baselineTheme === null) baselineTheme = ctx.ui.theme.name ?? null;
	}

	function previousMoodHasSkills(): boolean {
		if (!activeMood) return false;
		const m = moods.get(activeMood);
		return !!m?.config.skills?.length;
	}

	function applyMoodConfig(config: MoodConfig, ctx: ExtensionContext): void {
		if (config.tools) {
			pi.setActiveTools(config.tools);
		} else if (baselineTools) {
			pi.setActiveTools(baselineTools);
		}

		if (config.theme) {
			ctx.ui.setTheme(config.theme);
		} else if (baselineTheme) {
			ctx.ui.setTheme(baselineTheme);
		}
	}

	function clearMoodConfig(ctx: ExtensionContext): void {
		if (baselineTools) pi.setActiveTools(baselineTools);
		if (baselineTheme) ctx.ui.setTheme(baselineTheme);
	}

	async function switchMood(name: string | null, ctx: ExtensionCommandContext): Promise<void> {
		const hadSkills = previousMoodHasSkills();
		activeMood = name;

		if (name) {
			const m = moods.get(name);
			if (m) applyMoodConfig(m.config, ctx);
			const needsReload = !!m?.config.skills?.length || hadSkills;
			if (needsReload) await ctx.reload();
		} else {
			clearMoodConfig(ctx);
			if (hadSkills) await ctx.reload();
		}

		updateStatus(ctx);
		persist();
	}

	// --- Slash command ---

	pi.registerCommand("mood", {
		description: "Switch mood: /mood <name> (off to clear)",
		handler: async (args, ctx) => {
			captureBaseline(ctx);
			const name = args.trim().toLowerCase();

			if (!name) {
				const names = [...moods.keys()].sort();
				const maxLen = Math.max(...names.map((n) => n.length), 3);
				const pad = (s: string) => s.padEnd(maxLen);

				const items = names.map((m) => {
					const mood = moods.get(m)!;
					const label = m === activeMood ? `${pad(m)} (active)` : pad(m);
					const bold = ctx.ui.theme.bold(label);
					const desc = mood.config.description ? `  ${ctx.ui.theme.fg("muted", mood.config.description)}` : "";
					return `${bold}${desc}`;
				});
				if (activeMood) {
					const label = ctx.ui.theme.bold(pad("off"));
					items.push(`${label}  ${ctx.ui.theme.fg("muted", "revert to default")}`);
				}

				const selected = await ctx.ui.select("Select Mood", items);
				if (!selected) return;

				const idx = items.indexOf(selected);
				if (activeMood && idx === items.length - 1) {
					await switchMood(null, ctx);
					ctx.ui.notify("Mood cleared (default SYSTEM.md)", "info");
					return;
				}
				const picked = names[idx];
				if (!picked) return;
				await switchMood(picked, ctx);
				ctx.ui.notify(`Mood: ${picked}`, "info");
				return;
			}

			if (CLEAR_TOKENS.has(name)) {
				await switchMood(null, ctx);
				ctx.ui.notify("Mood cleared (default SYSTEM.md)", "info");
				return;
			}
			if (!moods.has(name)) {
				ctx.ui.notify(`Unknown mood "${name}". Available: ${listNames()}, off.`, "error");
				return;
			}
			await switchMood(name, ctx);
			ctx.ui.notify(`Mood: ${name}`, "info");
		},
	});

	// --- System prompt replacement ---

	pi.on("before_agent_start", async (event) => {
		if (!activeMood) return;
		const m = moods.get(activeMood);
		if (!m) return;
		if (m.body === event.systemPrompt) return;
		return { systemPrompt: m.body };
	});

	// --- Dynamic skill discovery ---

	pi.on("resources_discover", async () => {
		if (!activeMood) return;
		const m = moods.get(activeMood);
		if (!m?.config.skills?.length) return;
		const skillPaths = m.config.skills.map((s) => (path.isAbsolute(s) ? s : path.join(agentDir, s)));
		return { skillPaths };
	});

	// --- Session restore ---

	pi.on("session_start", async (_event, ctx) => {
		captureBaseline(ctx);

		const entries = ctx.sessionManager.getEntries();
		const last = entries
			.filter(
				(e: { type: string; customType?: string }) =>
					e.type === "custom" && e.customType === "moods",
			)
			.pop() as { data?: { mood?: string | null } } | undefined;

		if (last?.data?.mood && moods.has(last.data.mood)) {
			activeMood = last.data.mood;
			const m = moods.get(activeMood!);
			if (m) applyMoodConfig(m.config, ctx);
		}

		updateStatus(ctx);
	});
}
