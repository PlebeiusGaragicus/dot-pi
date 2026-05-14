/**
 * `/model-default` — view or override model aliases for this agent.
 *
 * Commands: `/model-default` (menu), `/model-default agentic|fast|vlm`, `/model-default global …`,
 * `/model-default show`, `/model-default reset`.
 *
 * Agent-local overrides live in **`env.model`** under **`$DOT_PI_OVERLAY/<agent>/`** (gitignored).
 * Global fallbacks live in **`$DOT_PI_OVERLAY/model-defaults`**.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { getAgentDir } from "@mariozechner/pi-coding-agent";
import * as fs from "node:fs";
import * as path from "node:path";
import { agentOverlayFile, agentOverlayFirstFile, ensureOverlayDir, overlayFile, overlayFirstFile } from "./lib/dotpi-paths.js";

const MODEL_FILE = "env.model";
const DEFAULTS_FILE = "model-defaults";
const ROLES = [
	{ id: "agentic", env: "DEFAULT_AGENTIC_MODEL", label: "Agentic" },
	{ id: "fast", env: "DEFAULT_FAST_MODEL", label: "Fast" },
	{ id: "vlm", env: "DEFAULT_VLM_MODEL", label: "Vision" },
] as const;

type Role = (typeof ROLES)[number];

type CommandContext = Parameters<Parameters<ExtensionAPI["registerCommand"]>[1]["handler"]>[1];

function readModels(): string[] {
	const modelsPath = path.join(getAgentDir(), "models.json");
	try {
		const config = JSON.parse(fs.readFileSync(modelsPath, "utf-8")) as {
			providers?: Record<string, { models?: Array<{ id?: string }> }>;
		};
		const ids: string[] = [];
		for (const [providerName, provider] of Object.entries(config.providers ?? {})) {
			for (const model of provider.models ?? []) {
				if (model.id) ids.push(`${providerName}/${model.id}`);
			}
		}
		return ids.sort();
	} catch {
		return [];
	}
}

function parseExports(filePath: string): Record<string, string> {
	const env: Record<string, string> = {};
	if (!fs.existsSync(filePath)) return env;
	for (const rawLine of fs.readFileSync(filePath, "utf-8").split(/\r?\n/)) {
		const line = rawLine.trim();
		if (!line || line.startsWith("#")) continue;
		const match = line.match(/^export\s+([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
		if (!match) continue;
		const [, name, rawValue] = match;
		if (!name) continue;
		const fallback = rawValue.match(/^"\$\{([A-Za-z_][A-Za-z0-9_]*):-([^}]*)\}"$/);
		if (fallback) {
			env[name] = fallback[2] ?? "";
			continue;
		}
		env[name] = rawValue.replace(/^"(.*)"$/, "$1");
	}
	return env;
}

function readAgentModel(): string {
	const filePath = agentOverlayFirstFile(getAgentDir(), MODEL_FILE);
	if (!fs.existsSync(filePath)) return "";
	for (const rawLine of fs.readFileSync(filePath, "utf-8").split(/\r?\n/)) {
		const line = rawLine.trim();
		if (!line || line.startsWith("#")) continue;
		return line;
	}
	return "";
}

function readResolvedDefaults(): Record<string, string> {
	const defaults = parseExports(overlayFirstFile(DEFAULTS_FILE));
	const agentModel = readAgentModel();
	const currentRole = detectCurrentAgentRole();
	const resolved = {
		...(process.env as Record<string, string>),
		...defaults,
	};
	if (agentModel && currentRole) resolved[currentRole.env] = agentModel;
	return {
		...resolved,
	};
}

function writeExports(filePath: string, values: Record<string, string>, header: string[], removeWhenEmpty = true): string {
	const lines = [
		...header,
	];
	for (const role of ROLES) {
		const value = values[role.env];
		if (value) lines.push(`export ${role.env}="\${${role.env}:-${value}}"`);
	}
	if (lines.length === 2 && removeWhenEmpty) {
		if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
		return filePath;
	}
	fs.writeFileSync(filePath, `${lines.join("\n")}\n`, "utf-8");
	return filePath;
}

function writeAgentModel(value: string): string {
	const filePath = agentOverlayFile(getAgentDir(), MODEL_FILE);
	fs.mkdirSync(path.dirname(filePath), { recursive: true });
	if (!value) {
		if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
		return filePath;
	}
	fs.writeFileSync(filePath, `${value}\n`, "utf-8");
	return filePath;
}

function writeGlobalDefaults(values: Record<string, string>): string {
	ensureOverlayDir();
	return writeExports(overlayFile(DEFAULTS_FILE), values, [
		"# Local fallback model aliases used by pi-args files.",
		"# Leave a value empty to let pi fall back to its settings.json default.",
	], false);
}

function detectCurrentAgentRole(): Role | undefined {
	const piArgsPath = path.join(getAgentDir(), "pi-args");
	if (!fs.existsSync(piArgsPath)) return undefined;
	const lines = fs.readFileSync(piArgsPath, "utf-8").split(/\r?\n/);
	for (let i = 0; i < lines.length; i++) {
		const line = lines[i]?.trim();
		if (!line || line.startsWith("#")) continue;
		const parts = line.split(/\s+/);
		let value: string | undefined;
		const modelIndex = parts.indexOf("--model");
		if (modelIndex !== -1) {
			value = parts[modelIndex + 1] || lines[i + 1]?.trim();
		} else if (line === "--model") {
			value = lines[i + 1]?.trim();
		}
		if (!value || value.startsWith("#")) continue;
		const envName = value.replace(/^\$?\{?([A-Za-z_][A-Za-z0-9_]*)\}?$/, "$1");
		const role = ROLES.find((r) => r.env === envName);
		if (role) return role;
	}
	return undefined;
}

function formatReport(): string {
	const defaultsPath = overlayFirstFile(DEFAULTS_FILE);
	const defaults = parseExports(defaultsPath);
	const agentModel = readAgentModel();
	const currentRole = detectCurrentAgentRole();
	const resolved = readResolvedDefaults();
	const lines = [
		`model-defaults: ${defaultsPath}`,
		`agent env.model: ${agentOverlayFile(getAgentDir(), MODEL_FILE)}`,
		`current agent model: ${agentModel || "(unset)"}`,
		"",
	];
	for (const role of ROLES) {
		const source = agentModel && currentRole?.env === role.env ? "agent env.model" : defaults[role.env] ? "model-defaults" : process.env[role.env] ? "env" : "pi settings";
		lines.push(`${role.env}: ${resolved[role.env] || "(unset)"} [${source}]`);
	}
	lines.push("", "Commands:", "/model-default agentic", "/model-default fast", "/model-default vlm", "/model-default reset");
	return lines.join("\n");
}

function roleFromArg(arg: string): Role | undefined {
	return ROLES.find((role) => role.id === arg || role.env === arg);
}

async function selectModelForRole(role: Role, ctx: CommandContext, scope: "agent" | "global"): Promise<void> {
	const models = readModels();
	if (models.length === 0) {
		ctx.ui.notify("No models found in models.json. Run dotpi setup first.", "warning");
		return;
	}

	const current = scope === "agent" ? readAgentModel() : readResolvedDefaults()[role.env] ?? "";
	const unsetLabel = scope === "agent" ? "(unset: use model-defaults)" : "(unset: use pi settings default)";
	const choices = [unsetLabel, ...models.map((model) => (model === current ? `${model} (current)` : model))];
	const selected = await ctx.ui.select(scope === "agent" ? "Select current agent model" : `Select ${role.label} model`, choices);
	if (!selected) return;

	const targetPath = scope === "agent" ? agentOverlayFile(getAgentDir(), MODEL_FILE) : overlayFirstFile(DEFAULTS_FILE);
	const selectedModel = selected.startsWith("(unset") ? "" : selected.replace(/ \(current\)$/, "");
	const overrides = scope === "agent" ? {} : parseExports(targetPath);
	if (scope === "global") {
		if (selectedModel) overrides[role.env] = selectedModel;
		else delete overrides[role.env];
	}
	const filePath = scope === "agent" ? writeAgentModel(selectedModel) : writeGlobalDefaults(overrides);
	ctx.ui.notify(`Updated ${scope === "agent" ? "agent model override" : "global model defaults"}\n\n${filePath}\n\n${formatReport()}`, "info");
}

async function showDefaultMenu(ctx: CommandContext): Promise<void> {
	const currentRole = detectCurrentAgentRole();
	const choices: string[] = [];
	if (currentRole) choices.push("Set current agent model");
	choices.push("Set global agentic default", "Set global fast default", "Set global vision default", "Show current defaults", "Reset current agent override");

	const selected = await ctx.ui.select("Model defaults", choices);
	if (!selected) return;

	if (selected.startsWith("Set current agent model") && currentRole) {
		await selectModelForRole(currentRole, ctx, "agent");
		return;
	}
	if (selected === "Set global agentic default") {
		await selectModelForRole(ROLES[0], ctx, "global");
		return;
	}
	if (selected === "Set global fast default") {
		await selectModelForRole(ROLES[1], ctx, "global");
		return;
	}
	if (selected === "Set global vision default") {
		await selectModelForRole(ROLES[2], ctx, "global");
		return;
	}
	if (selected === "Show current defaults") {
		ctx.ui.notify(formatReport(), "info");
		return;
	}
	if (selected === "Reset current agent override") {
		const filePath = writeAgentModel("");
		ctx.ui.notify(`Removed current agent model override\n\n${filePath}`, "info");
	}
}

function registerModelDefaultCommand(pi: ExtensionAPI): void {
	pi.registerCommand("model-default", {
		description: "View or override repo-local default model aliases",
		handler: async (args, ctx) => {
			if (!ctx.hasUI) return;
			const action = args.trim();

			if (!action) {
				await showDefaultMenu(ctx);
				return;
			}

			if (action === "show") {
				ctx.ui.notify(formatReport(), "info");
				return;
			}

			if (action === "reset") {
				const filePath = writeAgentModel("");
				ctx.ui.notify(`Removed current agent model override\n\n${filePath}`, "info");
				return;
			}

			const parts = action.split(/\s+/);
			const isGlobal = parts[0] === "global";
			const role = roleFromArg(isGlobal ? parts[1] ?? "" : action);
			if (!role) {
				ctx.ui.notify("Usage: /model-default [agentic|fast|vlm|global agentic|global fast|global vlm|show|reset]", "warning");
				return;
			}

			await selectModelForRole(role, ctx, isGlobal ? "global" : "agent");
		},
	});
}

export default function (pi: ExtensionAPI) {
	registerModelDefaultCommand(pi);
}
