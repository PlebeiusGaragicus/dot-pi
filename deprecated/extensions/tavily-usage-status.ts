/**
 * Tavily usage footer line — plan credits as a long progress bar in the stock footer.
 *
 * Uses ctx.ui.setStatus() so the built-in footer (tokens, cwd, etc.) stays intact.
 * Refreshes after each agent run so usage reflects recent websearch calls.
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

const STATUS_KEY = "tavily-usage";
/** Horizontal bar length (filled + empty segments), before footer truncation. */
const BAR_LEN = 40;

interface TavilyAccount {
	current_plan?: string;
	plan_usage?: number;
	plan_limit?: number;
}

interface TavilyKeyBucket {
	usage?: number;
	limit?: number;
}

interface TavilyUsageResponse {
	account?: TavilyAccount;
	key?: TavilyKeyBucket;
	detail?: unknown;
}

function buildBar(used: number, limit: number | null): string {
	if (limit != null && limit > 0) {
		const frac = Math.min(1, Math.max(0, used / limit));
		const filled = Math.round(frac * BAR_LEN);
		return "#".repeat(filled) + "-".repeat(BAR_LEN - filled);
	}
	return "?".repeat(BAR_LEN);
}

function pickUsage(data: TavilyUsageResponse): { used: number; limit: number | null; plan: string } {
	const acc = data.account;
	const keyBucket = data.key;
	const used =
		typeof acc?.plan_usage === "number"
			? acc.plan_usage
			: typeof keyBucket?.usage === "number"
				? keyBucket.usage
				: 0;
	let limit: number | null =
		typeof acc?.plan_limit === "number"
			? acc.plan_limit
			: typeof keyBucket?.limit === "number"
				? keyBucket.limit
				: null;
	const plan = (acc?.current_plan && String(acc.current_plan).trim()) || "Tavily";
	return { used, limit, plan };
}

async function formatUsageLine(): Promise<string> {
	const apiKey = process.env.TAVILY_API_KEY?.trim();
	if (!apiKey) {
		return "Tavily: set TAVILY_API_KEY to show plan usage";
	}

	let res: Response;
	try {
		res = await fetch("https://api.tavily.com/usage", {
			method: "GET",
			headers: { Authorization: `Bearer ${apiKey}` },
		});
	} catch (e) {
		const msg = e instanceof Error ? e.message : String(e);
		return `Tavily: request failed (${msg})`;
	}

	let data: TavilyUsageResponse;
	try {
		data = (await res.json()) as TavilyUsageResponse;
	} catch {
		return `Tavily: invalid JSON (HTTP ${res.status})`;
	}

	if (!res.ok) {
		const err =
			data.detail !== undefined
				? JSON.stringify(data.detail)
				: JSON.stringify(data);
		return `Tavily: HTTP ${res.status} ${err}`;
	}

	const { used, limit, plan } = pickUsage(data);
	const bar = buildBar(used, limit);
	const pct =
		limit != null && limit > 0 ? `${((100 * used) / limit).toFixed(1)}%` : "";
	const nums = limit != null ? `${used}/${limit}` : `${used} used`;
	const pctPart = pct ? ` ${pct}` : "";
	return `Tavily · ${plan} [${bar}] ${nums}${pctPart}`;
}

async function refreshFooter(ctx: ExtensionContext): Promise<void> {
	if (!ctx.hasUI) return;
	const line = await formatUsageLine();
	ctx.ui.setStatus(STATUS_KEY, line);
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		await refreshFooter(ctx);
	});

	pi.on("agent_end", async (_event, ctx) => {
		await refreshFooter(ctx);
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		if (ctx.hasUI) {
			ctx.ui.setStatus(STATUS_KEY, undefined);
		}
	});
}
