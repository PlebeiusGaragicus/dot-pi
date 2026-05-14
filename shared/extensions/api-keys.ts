/**
 * `/api-keys` — view or edit Exa, Tavily, and ntfy credentials under `$DOT_PI_OVERLAY`.
 * CLI equivalent: `dotpi keys`.
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import * as fs from "node:fs";
import { ensureOverlayDir, overlayFile } from "./lib/dotpi-paths.js";

const EXA_NAME = "env.exa";
const TAVILY_NAME = "env.tavily";
const NTFY_NAME = "env.ntfy";

/**
 * The Tavily extension refreshes its usage footer on `session_start` only; after changing the
 * Tavily key, `/reload` re-runs that path. Pi: `/reload` aligns with `ctx.reload()` — see
 * docs/reference/extensions.md.
 */
const RELOAD_AFTER_TAVILY_KEY_HINT =
	"Run /reload in pi to refresh the Tavily usage bar.";

/** Labels for `ctx.ui.select` (arrow keys + Enter); must match dispatch below. */
const API_KEYS_MENU_ITEMS = [
	"Exa API key",
	"Tavily API key",
	"ntfy (push)",
	"Show status",
	"Close",
] as const;

function maskKey(key: string): string {
	if (!key) return "(not set)";
	if (key.length <= 6) return "****";
	return `${key.slice(0, 4)}****${key.slice(-2)}`;
}

function loadExaKey(): string | null {
	const envKey = process.env.EXA_API_KEY?.trim();
	if (envKey && envKey !== "$EXA_API_KEY") return envKey;
	const keyPath = overlayFile(EXA_NAME);
	if (!fs.existsSync(keyPath)) return null;
	const content = fs.readFileSync(keyPath, "utf-8").trim();
	const match = content.match(/^(?:EXA_API_KEY\s*=\s*)?(.+)$/m);
	return match?.[1]?.trim() || null;
}

function saveExaKey(key: string): string {
	ensureOverlayDir();
	const keyPath = overlayFile(EXA_NAME);
	fs.writeFileSync(keyPath, `EXA_API_KEY=${key}\n`, "utf-8");
	return keyPath;
}

function loadTavilyKey(): string | null {
	const envKey = process.env.TAVILY_API_KEY?.trim();
	if (envKey && envKey !== "$TAVILY_API_KEY") return envKey;
	const keyPath = overlayFile(TAVILY_NAME);
	if (!fs.existsSync(keyPath)) return null;
	const content = fs.readFileSync(keyPath, "utf-8").trim();
	const match = content.match(/^(?:TAVILY_API_KEY\s*=\s*)?(.+)$/m);
	return match?.[1]?.trim() || null;
}

function saveTavilyKey(key: string): string {
	ensureOverlayDir();
	const keyPath = overlayFile(TAVILY_NAME);
	fs.writeFileSync(keyPath, `TAVILY_API_KEY=${key}\n`, "utf-8");
	return keyPath;
}

function parseEnvFile(envPath: string): Record<string, string> {
	const out: Record<string, string> = {};
	if (!fs.existsSync(envPath)) return out;
	const content = fs.readFileSync(envPath, "utf-8");
	for (const line of content.split("\n")) {
		const trimmed = line.trim();
		if (!trimmed || trimmed.startsWith("#")) continue;
		const eq = trimmed.indexOf("=");
		if (eq <= 0) continue;
		const k = trimmed.slice(0, eq).trim();
		let v = trimmed.slice(eq + 1).trim();
		if (
			(v.startsWith('"') && v.endsWith('"')) ||
			(v.startsWith("'") && v.endsWith("'"))
		) {
			v = v.slice(1, -1);
		}
		out[k] = v;
	}
	return out;
}

function loadNtfyFromDisk(): { baseUrl: string; user: string; password: string } {
	const p = overlayFile(NTFY_NAME);
	const f = parseEnvFile(p);
	function pick(key: string): string {
		const envVal = process.env[key]?.trim();
		if (envVal && envVal !== `$${key}`) return envVal;
		return f[key]?.trim() ?? "";
	}
	return {
		baseUrl: pick("NTFY_BASE_URL").replace(/\/+$/, ""),
		user: pick("NTFY_USER"),
		password: pick("NTFY_PASSWORD"),
	};
}

function saveNtfyFile(baseUrl: string, user: string, password: string): string {
	ensureOverlayDir();
	const keyPath = overlayFile(NTFY_NAME);
	const body =
		`# dot-pi ntfy (written by /api-keys)\n` +
		`NTFY_BASE_URL=${baseUrl}\n` +
		`NTFY_USER=${user}\n` +
		`NTFY_PASSWORD=${password}\n`;
	fs.writeFileSync(keyPath, body, "utf-8");
	return keyPath;
}

async function optionalNtfyProbe(baseUrl: string, ctx: ExtensionContext): Promise<void> {
	const normalized = baseUrl.replace(/\/+$/, "");
	const yn = await ctx.ui.input(`Test server GET ${normalized}/version? [y/N]`);
	if (!yn?.trim().toLowerCase().startsWith("y")) return;
	try {
		const res = await fetch(`${normalized}/version`, { signal: AbortSignal.timeout(8000) });
		if (res.ok) ctx.ui.notify("ntfy probe: OK", "info");
		else ctx.ui.notify(`ntfy probe: HTTP ${res.status}`, "warning");
	} catch (e) {
		const msg = e instanceof Error ? e.message : String(e);
		ctx.ui.notify(`ntfy probe failed: ${msg}`, "warning");
	}
}

async function showStatus(ctx: ExtensionContext): Promise<void> {
	const exa = loadExaKey();
	const tav = loadTavilyKey();
	const n = loadNtfyFromDisk();
	const lines = [
		`Exa: ${maskKey(exa ?? "")}`,
		`Tavily: ${maskKey(tav ?? "")}`,
		n.baseUrl ? `ntfy URL: ${n.baseUrl}` : "ntfy URL: (not set)",
	];
	if (n.user || n.password) {
		lines.push(`ntfy user: ${maskKey(n.user)}`, `ntfy password: ${maskKey(n.password)}`);
	}
	ctx.ui.notify(lines.join("\n"), "info");
}

async function editExa(ctx: ExtensionContext): Promise<void> {
	const cur = loadExaKey();
	ctx.ui.notify(`Current Exa key: ${maskKey(cur ?? "")}`, "info");
	const input = await ctx.ui.input("New Exa API key [empty=cancel, -=clear file]");
	if (input == null) return;
	const t = input.trim();
	if (!t) {
		ctx.ui.notify("Cancelled", "info");
		return;
	}
	if (t === "-") {
		const p = overlayFile(EXA_NAME);
		fs.rmSync(p, { force: true });
		ctx.ui.notify("Cleared env.exa", "info");
		return;
	}
	const path = saveExaKey(t);
	ctx.ui.notify(`Saved to ${path}`, "info");
}

async function editTavily(ctx: ExtensionContext): Promise<void> {
	const cur = loadTavilyKey();
	ctx.ui.notify(`Current Tavily key: ${maskKey(cur ?? "")}`, "info");
	const input = await ctx.ui.input("New Tavily API key [empty=cancel, -=clear file]");
	if (input == null) return;
	const t = input.trim();
	if (!t) {
		ctx.ui.notify("Cancelled", "info");
		return;
	}
	if (t === "-") {
		const p = overlayFile(TAVILY_NAME);
		fs.rmSync(p, { force: true });
		ctx.ui.notify("Cleared env.tavily", "info");
		ctx.ui.notify(RELOAD_AFTER_TAVILY_KEY_HINT, "info");
		return;
	}
	const path = saveTavilyKey(t);
	ctx.ui.notify(`Saved to ${path}`, "info");
	ctx.ui.notify(RELOAD_AFTER_TAVILY_KEY_HINT, "info");
}

async function editNtfy(ctx: ExtensionContext): Promise<void> {
	const cur = loadNtfyFromDisk();
	ctx.ui.notify(
		`Current ntfy:\nURL: ${cur.baseUrl || "(not set)"}\nuser: ${maskKey(cur.user)}\npassword: ${maskKey(cur.password)}`,
		"info",
	);
	const urlIn = await ctx.ui.input("NTFY_BASE_URL [empty=keep, -=clear entire env.ntfy]");
	if (urlIn == null) return;
	const urlT = urlIn.trim();
	if (urlT === "-") {
		fs.rmSync(overlayFile(NTFY_NAME), { force: true });
		ctx.ui.notify("Cleared env.ntfy", "info");
		return;
	}
	const baseUrl = (urlT || cur.baseUrl).replace(/\/+$/, "");
	if (!baseUrl) {
		ctx.ui.notify("NTFY_BASE_URL required. Cancelled.", "info");
		return;
	}

	const userIn = await ctx.ui.input("NTFY_USER [empty=keep, -=clear]");
	if (userIn == null) return;
	let user = cur.user;
	if (userIn.trim() === "-") user = "";
	else if (userIn.trim() !== "") user = userIn.trim();

	const passIn = await ctx.ui.input("NTFY_PASSWORD [empty=keep, -=clear]");
	if (passIn == null) return;
	let password = cur.password;
	if (passIn.trim() === "-") password = "";
	else if (passIn.trim() !== "") password = passIn.trim();

	const path = saveNtfyFile(baseUrl, user, password);
	ctx.ui.notify(`Saved to ${path}`, "info");
	await optionalNtfyProbe(baseUrl, ctx);
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("api-keys", {
		description: "View or set Exa, Tavily, and ntfy API keys (overlay)",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;

			const choice = await ctx.ui.select("API keys", [...API_KEYS_MENU_ITEMS]);
			if (!choice) {
				ctx.ui.notify("Cancelled", "info");
				return;
			}
			switch (choice) {
				case "Exa API key":
					await editExa(ctx);
					return;
				case "Tavily API key":
					await editTavily(ctx);
					return;
				case "ntfy (push)":
					await editNtfy(ctx);
					return;
				case "Show status":
					await showStatus(ctx);
					return;
				case "Close":
					return;
				default:
					return;
			}
		},
	});
}
