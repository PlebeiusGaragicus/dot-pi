/**
 * Tavily TUI helper.
 *
 * Provides repo-local API key management and a footer usage status for agents
 * that use the script-backed `tavily-cli` skill. This extension intentionally
 * does not register a Tavily search tool.
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import * as fs from "node:fs";
import { ensureOverlayDir, overlayFile, overlayFirstFile } from "../lib/dotpi-paths.js";

const USAGE_API_URL = "https://api.tavily.com/usage";
const STATUS_KEY = "tavily-usage";
const TAVILY_KEY_FILE = "env.tavily";

/** Cached footer state for the simplified usage bar. */
interface FooterUsageState {
	used: number;
	limit: number | null;
}

/**
 * Footer totals after GET /usage at session start, then advanced by each search's
 * `usage.credits` (search does not return full quota — see plan). External API
 * usage outside this process is not reflected until the next bootstrap.
 */
let cachedUsage: FooterUsageState | null = null;

const BAR_LEN = 10;

interface TavilyAccount {
	current_plan?: string;
	plan_usage?: number;
	plan_limit?: number;
	paygo_usage?: number;
	paygo_limit?: number;
	search_usage?: number;
	extract_usage?: number;
	crawl_usage?: number;
	map_usage?: number;
	research_usage?: number;
}

interface TavilyKeyBucket {
	usage?: number;
	limit?: number | null;
	search_usage?: number;
	extract_usage?: number;
	crawl_usage?: number;
	map_usage?: number;
	research_usage?: number;
}

interface TavilyUsageResponse {
	account?: TavilyAccount;
	key?: TavilyKeyBucket;
	detail?: unknown;
}

function loadTavilyKey(): string | null {
	const envKey = process.env.TAVILY_API_KEY?.trim();
	if (envKey && envKey !== "$TAVILY_API_KEY") return envKey;

	const keyPath = overlayFirstFile(TAVILY_KEY_FILE);
	if (!fs.existsSync(keyPath)) return null;

	const content = fs.readFileSync(keyPath, "utf-8").trim();
	const match = content.match(/^(?:TAVILY_API_KEY\s*=\s*)?(.+)$/m);
	return match?.[1]?.trim() || null;
}

function saveTavilyKey(key: string): string {
	ensureOverlayDir();
	const keyPath = overlayFile(TAVILY_KEY_FILE);
	fs.writeFileSync(keyPath, `TAVILY_API_KEY=${key}\n`, "utf-8");
	return keyPath;
}

function buildBar(used: number, limit: number | null): string {
	if (limit == null || limit <= 0) return "░".repeat(BAR_LEN);
	const frac = Math.min(1, Math.max(0, used / limit));
	const filled = Math.round(frac * BAR_LEN);
	return "█".repeat(filled) + "░".repeat(BAR_LEN - filled);
}

function pickUsage(data: TavilyUsageResponse): FooterUsageState {
	const acc = data.account;
	const keyBucket = data.key;
	const used =
		typeof acc?.plan_usage === "number"
			? acc.plan_usage
			: typeof keyBucket?.usage === "number"
				? keyBucket.usage
				: 0;
	const limit: number | null =
		typeof acc?.plan_limit === "number"
			? acc.plan_limit
			: typeof keyBucket?.limit === "number"
				? keyBucket.limit
				: null;
	return { used, limit };
}

function formatFooterLine(state: FooterUsageState): string {
	const { used, limit } = state;
	const bar = buildBar(used, limit);
	if (limit == null || limit <= 0) return `Tavily [${bar}] ${used} used`;
	const pct = Math.round((100 * used) / limit);
	return `Tavily [${bar}] ${used}/${limit} ${pct}%`;
}

/** GET /usage once; sets `cachedUsage` on success. Returns the status line to show. */
async function fetchUsageBootstrapLine(): Promise<string> {
	const apiKey = loadTavilyKey();
	if (!apiKey) {
		cachedUsage = null;
		return "Tavily: run /tavily-api-key to configure";
	}

	let res: Response;
	try {
		res = await fetch(USAGE_API_URL, {
			method: "GET",
			headers: { Authorization: `Bearer ${apiKey}` },
		});
	} catch (e) {
		cachedUsage = null;
		const msg = e instanceof Error ? e.message : String(e);
		return `Tavily: request failed (${msg})`;
	}

	let data: TavilyUsageResponse;
	try {
		data = (await res.json()) as TavilyUsageResponse;
	} catch {
		cachedUsage = null;
		return `Tavily: invalid JSON (HTTP ${res.status})`;
	}

	if (!res.ok) {
		cachedUsage = null;
		const err =
			data.detail !== undefined
				? JSON.stringify(data.detail)
				: JSON.stringify(data);
		return `Tavily: HTTP ${res.status} ${err}`;
	}

	cachedUsage = pickUsage(data);
	return formatFooterLine(cachedUsage);
}

async function refreshFooterBootstrap(ctx: ExtensionContext): Promise<void> {
	if (!ctx.hasUI) return;
	const line = await fetchUsageBootstrapLine();
	ctx.ui.setStatus(STATUS_KEY, line);
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("tavily-api-key", {
		description: "Set or update your Tavily API key",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;
			const current = loadTavilyKey();
			const masked = current
				? `${current.slice(0, 4)}****${current.slice(-2)}`
				: "(not set)";
			ctx.ui.notify(`Current key: ${masked}`, "info");
			const input = await ctx.ui.input("Paste your Tavily API key (from https://app.tavily.com)");
			if (!input?.trim()) {
				ctx.ui.notify("Cancelled", "info");
				return;
			}

			const keyPath = saveTavilyKey(input.trim());
			ctx.ui.notify(`Saved to ${keyPath}`, "info");
			await refreshFooterBootstrap(ctx);
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		await refreshFooterBootstrap(ctx);
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		cachedUsage = null;
		if (ctx.hasUI) {
			ctx.ui.setStatus(STATUS_KEY, undefined);
		}
	});
}
