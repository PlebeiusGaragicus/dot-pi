/**
 * Personas Extension
 *
 * Persona files live in `<agentDir>/personas/`.
 * - `/persona <name>` selects a persona interactively for future turns.
 * - `--persona <name>` selects a persona at process startup, including for subagents.
 * - `helpful` is used as the default persona when present.
 *
 * Optional YAML frontmatter in each persona file:
 *   description: short description shown in the picker
 *   mode: append | prepend | replace (default: append)
 *   tools: comma-separated tool names to activate
 *   skills: comma-separated skill paths, relative to the agent dir unless absolute
 *   theme: theme name to switch to in interactive sessions
 *
 * In subagent processes, the slash command is not registered, but `--persona`
 * remains available so orchestrators can select prompt overlays non-interactively.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { getAgentDir, parseFrontmatter } from "@mariozechner/pi-coding-agent";

type PersonaMode = "append" | "prepend" | "replace";

interface PersonaConfig {
	description?: string;
	mode: PersonaMode;
	tools?: string[];
	skills?: string[];
	theme?: string;
}

interface PersonaFile {
	body: string;
	config: PersonaConfig;
}

const PERSONA_ENTRY = "personas";

function splitCsv(value: unknown): string[] | undefined {
	if (typeof value !== "string" || !value.trim()) return undefined;
	return value
		.split(",")
		.map((s) => s.trim())
		.filter(Boolean);
}

function parseMode(value: unknown): PersonaMode {
	if (value === "append" || value === "prepend" || value === "replace") return value;
	return "append";
}

function loadPersonas(dir: string): Map<string, PersonaFile> {
	const out = new Map<string, PersonaFile>();
	if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) return out;
	for (const file of fs.readdirSync(dir)) {
		if (!file.endsWith(".md")) continue;
		const name = path.basename(file, ".md").toLowerCase();
		try {
			const raw = fs.readFileSync(path.join(dir, file), "utf-8");
			const { frontmatter, body } = parseFrontmatter<Record<string, string>>(raw);
			const trimmed = body.trim();
			if (!trimmed) continue;
			const config: PersonaConfig = {
				description: typeof frontmatter?.description === "string" ? frontmatter.description.trim() || undefined : undefined,
				mode: parseMode(frontmatter?.mode),
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

function normalizePersonaName(value: unknown): string | null {
	if (typeof value !== "string") return null;
	const name = value.trim().toLowerCase();
	return name || null;
}

function composeSystemPrompt(basePrompt: string, name: string, persona: PersonaFile): string {
	if (persona.config.mode === "replace") return persona.body;

	const block = [`## Persona: ${name}`, "", persona.body].join("\n");
	if (persona.config.mode === "prepend") return `${block}\n\n${basePrompt}`;
	return `${basePrompt}\n\n${block}`;
}

export default function personasExtension(pi: ExtensionAPI): void {
	const agentDir = getAgentDir();
	const personas = loadPersonas(path.join(agentDir, "personas"));

	pi.registerFlag("persona", {
		description: "Select a persona from <agentDir>/personas by name",
		type: "string",
		default: "",
	});

	if (personas.size === 0) return;

	const isSubagent = process.env.PI_IS_SUBAGENT === "1";
	const defaultPersona = personas.has("helpful") ? "helpful" : null;
	let activePersona: string | null = defaultPersona;
	let baselineTools: string[] | null = null;
	let baselineTheme: string | null = null;

	function listNames(): string {
		return [...personas.keys()].sort().join(", ") || "(none)";
	}

	function updateStatus(ctx: ExtensionContext): void {
		if (!ctx.hasUI) return;
		ctx.ui.setStatus("personas", activePersona ? `persona: ${activePersona}` : undefined);
	}

	function persist(): void {
		pi.appendEntry(PERSONA_ENTRY, { persona: activePersona });
	}

	function captureBaseline(ctx: ExtensionContext): void {
		if (baselineTools === null) baselineTools = pi.getActiveTools();
		if (ctx.hasUI && baselineTheme === null) baselineTheme = ctx.ui.theme.name ?? null;
	}

	function previousPersonaHasSkills(): boolean {
		if (!activePersona) return false;
		const persona = personas.get(activePersona);
		return !!persona?.config.skills?.length;
	}

	function applyPersonaConfig(config: PersonaConfig, ctx: ExtensionContext): void {
		if (config.tools) {
			pi.setActiveTools(config.tools);
		} else if (baselineTools) {
			pi.setActiveTools(baselineTools);
		}

		if (!ctx.hasUI) return;
		if (config.theme) {
			ctx.ui.setTheme(config.theme);
		} else if (baselineTheme) {
			ctx.ui.setTheme(baselineTheme);
		}
	}

	async function switchPersona(name: string, ctx: ExtensionCommandContext): Promise<void> {
		const hadSkills = previousPersonaHasSkills();
		activePersona = name;

		const persona = personas.get(name);
		if (persona) applyPersonaConfig(persona.config, ctx);
		const needsReload = !!persona?.config.skills?.length || hadSkills;
		if (needsReload) await ctx.reload();

		updateStatus(ctx);
		persist();
	}

	if (!isSubagent) {
		pi.registerCommand("persona", {
			description: "Switch persona: /persona <name>",
			handler: async (args, ctx) => {
				captureBaseline(ctx);
				const name = normalizePersonaName(args);

				if (!name) {
					if (!ctx.hasUI) return;
					const names = [...personas.keys()].sort();
					const maxLen = Math.max(...names.map((n) => n.length), 7);
					const pad = (s: string) => s.padEnd(maxLen);

					const items = names.map((personaName) => {
						const persona = personas.get(personaName)!;
						const label = personaName === activePersona ? `${pad(personaName)} (active)` : pad(personaName);
						const bold = ctx.ui.theme.bold(label);
						const desc = persona.config.description ? `  ${ctx.ui.theme.fg("muted", persona.config.description)}` : "";
						return `${bold}${desc}`;
					});
					const selected = await ctx.ui.select("Select Persona", items);
					if (!selected) return;

					const idx = items.indexOf(selected);
					const picked = names[idx];
					if (!picked) return;
					await switchPersona(picked, ctx);
					ctx.ui.notify(`Persona: ${picked}`, "info");
					return;
				}

				if (!personas.has(name)) {
					if (ctx.hasUI) ctx.ui.notify(`Unknown persona "${name}". Available: ${listNames()}.`, "error");
					return;
				}
				await switchPersona(name, ctx);
				if (ctx.hasUI) ctx.ui.notify(`Persona: ${name}`, "info");
			},
		});
	}

	pi.on("before_agent_start", async (event) => {
		if (!activePersona) return;
		const persona = personas.get(activePersona);
		if (!persona) return;
		const nextPrompt = composeSystemPrompt(event.systemPrompt, activePersona, persona);
		if (nextPrompt === event.systemPrompt) return;
		return { systemPrompt: nextPrompt };
	});

	pi.on("resources_discover", async () => {
		if (!activePersona) return;
		const persona = personas.get(activePersona);
		if (!persona?.config.skills?.length) return;
		const skillPaths = persona.config.skills.map((s) => (path.isAbsolute(s) ? s : path.join(agentDir, s)));
		return { skillPaths };
	});

	pi.on("session_start", async (_event, ctx) => {
		captureBaseline(ctx);

		const cliPersona = normalizePersonaName(pi.getFlag("persona"));
		if (cliPersona) {
			if (personas.has(cliPersona)) {
				activePersona = cliPersona;
				const persona = personas.get(activePersona);
				if (persona) applyPersonaConfig(persona.config, ctx);
			} else if (ctx.hasUI) {
				ctx.ui.notify(`Unknown persona "${cliPersona}". Available: ${listNames()}.`, "error");
				if (activePersona) {
					const persona = personas.get(activePersona);
					if (persona) applyPersonaConfig(persona.config, ctx);
				}
			}
			updateStatus(ctx);
			return;
		}

		const entries = ctx.sessionManager.getEntries();
		const last = entries
			.filter(
				(e: { type: string; customType?: string }) =>
					e.type === "custom" && e.customType === PERSONA_ENTRY,
			)
			.pop() as { data?: { persona?: string | null } } | undefined;

		if (last?.data?.persona && personas.has(last.data.persona)) {
			activePersona = last.data.persona;
			const persona = personas.get(activePersona);
			if (persona) applyPersonaConfig(persona.config, ctx);
		} else if (activePersona) {
			const persona = personas.get(activePersona);
			if (persona) applyPersonaConfig(persona.config, ctx);
		}

		updateStatus(ctx);
	});
}
