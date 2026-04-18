/**
 * Tavily Web Search Extension - Direct access to Tavily's REST API
 *
 * Provides a structured `tavily_search` tool for web searches without
 * requiring agents to construct bash commands or parse jq output.
 * Also displays plan usage in the footer status bar.
 * 
 * TODO: https://docs.tavily.com/documentation/best-practices/best-practices-search
 * TODO: https://docs.tavily.com/sdk/javascript/reference
 * TODO: https://docs.tavily.com/documentation/api-reference/introduction
 * TODO: https://docs.tavily.com/documentation/api-reference/endpoint/search
 *
 * Requires: TAVILY_API_KEY environment variable
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { Container, Markdown, Spacer, Text, getMarkdownTheme } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";

const API_URL = "https://api.tavily.com/search";
const USAGE_API_URL = "https://api.tavily.com/usage";
const STATUS_KEY = "tavily-usage";

/** Cached footer state: `searchUsed` is always a number for per-search increments. */
interface FooterUsageState {
    used: number;
    limit: number | null;
    plan: string;
    searchUsed: number;
    /** Shown from bootstrap only; we do not increment PAYG per search (allocation ambiguous). */
    paygo?: { used: number; limit: number };
}

/** Last snapshot for heuristic “quota may have reset” messaging (bootstrap / API only). */
let lastUsageSnapshot: { used: number; limit: number | null } | null = null;

/**
 * Footer totals after GET /usage at session start, then advanced by each search’s
 * `usage.credits` (search does not return full quota — see plan). External API
 * usage outside this process is not reflected until the next bootstrap.
 */
let cachedUsage: FooterUsageState | null = null;

/** 
 * Calculate dynamic bar length based on terminal width.
 * Uses 80% of terminal width, clamped between 10-60 columns for readability.
 */
function getBarLength(): number {
    const termWidth = process.stdout.columns || 80;
    // Use 80% of terminal width, clamped between 10-60 for readability
    return Math.min(60, Math.max(10, Math.floor(termWidth * 0.8)));
}

interface TavilyResult {
    title: string;
    url: string;
    content: string;
    score?: number;
    raw_content?: string;
}

/** Per-request credit usage when `include_usage` is true on /search. */
interface TavilySearchRequestUsage {
    credits?: number;
    [key: string]: unknown;
}

interface TavilyResponse {
    answer?: string;
    results: TavilyResult[];
    usage?: TavilySearchRequestUsage;
}

interface SearchParams {
    query: string;
    max_results?: number;
    search_depth?: "basic" | "fast" | "advanced" | "ultra-fast";
    topic?: "general" | "news" | "finance";
    include_answer?: boolean | "advanced";
    time_range?: "day" | "week" | "month" | "year";
    include_raw_content?: boolean;
    include_domains?: string[];
    exclude_domains?: string[];
}

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

function formatResults(results: TavilyResult[], answer?: string): string {
    const lines: string[] = [];
    
    if (answer) {
        lines.push("## Answer");
        lines.push(answer);
        lines.push("");
    }
    
    lines.push(`## Results (${results.length})`);
    
    for (const result of results) {
        lines.push("");
        lines.push(`### ${result.title}`);
        lines.push(result.url);
        lines.push("");
        lines.push(result.content);
        
        // Include raw content if available
        if (result.raw_content) {
            lines.push("");
            lines.push("---");
            lines.push("Raw excerpt:");
            const truncated = result.raw_content.slice(0, 2000);
            lines.push(truncated + (result.raw_content.length > 2000 ? "…" : ""));
        }
    }
    
    return lines.join("\n");
}

function buildBar(used: number, limit: number | null): string {
    if (limit != null && limit > 0) {
        const barLen = getBarLength();
        const frac = Math.min(1, Math.max(0, used / limit));
        const filled = Math.round(frac * barLen);
        return "#".repeat(filled) + "-".repeat(barLen - filled);
    }
    const barLen = getBarLength();
    return "?".repeat(barLen);
}

interface PickedUsage {
    used: number;
    limit: number | null;
    plan: string;
    /** Search endpoint credits this billing cycle, when the API reports them. */
    searchUsed?: number;
    /** Pay-as-you-go bucket when `paygo_limit` is present. */
    paygo?: { used: number; limit: number };
}

function usageStateFromApiPick(p: PickedUsage): FooterUsageState {
    return {
        used: p.used,
        limit: p.limit,
        plan: p.plan,
        searchUsed: p.searchUsed ?? 0,
        paygo: p.paygo,
    };
}

function pickUsage(data: TavilyUsageResponse): PickedUsage {
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

    const searchUsed =
        typeof acc?.search_usage === "number"
            ? acc.search_usage
            : typeof keyBucket?.search_usage === "number"
                ? keyBucket.search_usage
                : undefined;

    let paygo: { used: number; limit: number } | undefined;
    if (typeof acc?.paygo_limit === "number" && acc.paygo_limit > 0) {
        paygo = {
            used: typeof acc.paygo_usage === "number" ? acc.paygo_usage : 0,
            limit: acc.paygo_limit,
        };
    }

    return { used, limit, plan, searchUsed, paygo };
}

function formatRetryAfter(response: Response): string {
    const raw = response.headers.get("retry-after")?.trim();
    if (!raw) return "";
    const sec = parseInt(raw, 10);
    if (Number.isFinite(sec) && sec >= 0) {
        return ` Retry after ${sec}s.`;
    }
    return ` Retry-After: ${raw}.`;
}

function formatFooterLine(state: FooterUsageState, checkResetHeuristic: boolean): string {
    const { used, limit, plan, searchUsed, paygo } = state;
    const bar = buildBar(used, limit);
    const pct =
        limit != null && limit > 0 ? `${((100 * used) / limit).toFixed(1)}%` : "";
    const nums = limit != null ? `${used}/${limit}` : `${used} used`;
    const pctPart = pct ? ` ${pct}` : "";

    const extras: string[] = [];
    extras.push(`srch ${searchUsed}`);
    if (paygo) {
        extras.push(`PAYG ${paygo.used}/${paygo.limit}`);
    }
    const extraPart = extras.length ? ` · ${extras.join(" · ")}` : "";

    let resetHint = "";
    if (
        checkResetHeuristic &&
        lastUsageSnapshot &&
        limit != null &&
        lastUsageSnapshot.limit === limit &&
        lastUsageSnapshot.used >= 30 &&
        used < lastUsageSnapshot.used * 0.35
    ) {
        resetHint = " · usage may have reset — verify at https://app.tavily.com";
    }
    if (checkResetHeuristic) {
        lastUsageSnapshot = { used, limit };
    }

    const staticHint = " · app.tavily.com";

    return `Tavily · ${plan} [${bar}] ${nums}${pctPart}${extraPart}${resetHint}${staticHint}`;
}

/** GET /usage once; sets `cachedUsage` on success. Returns the status line to show. */
async function fetchUsageBootstrapLine(): Promise<string> {
    const apiKey = process.env.TAVILY_API_KEY?.trim();
    if (!apiKey) {
        cachedUsage = null;
        return "Tavily: set TAVILY_API_KEY to show plan usage";
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

    const picked = pickUsage(data);
    cachedUsage = usageStateFromApiPick(picked);
    return formatFooterLine(cachedUsage, true);
}

async function refreshFooterBootstrap(ctx: ExtensionContext): Promise<void> {
    if (!ctx.hasUI) return;
    const line = await fetchUsageBootstrapLine();
    ctx.ui.setStatus(STATUS_KEY, line);
}

async function ensureFooterCache(ctx: ExtensionContext): Promise<void> {
    if (!ctx.hasUI || cachedUsage) return;
    await refreshFooterBootstrap(ctx);
}

function applySearchCreditsToFooter(credits: number): void {
    if (!cachedUsage) return;
    cachedUsage.used += credits;
    cachedUsage.searchUsed += credits;
}

function syncFooterFromCache(ctx: ExtensionContext): void {
    if (!ctx.hasUI || !cachedUsage) return;
    ctx.ui.setStatus(STATUS_KEY, formatFooterLine(cachedUsage, false));
    lastUsageSnapshot = { used: cachedUsage.used, limit: cachedUsage.limit };
}

export default function (pi: ExtensionAPI) {
    const SearchParamsSchema = Type.Object({
        query: Type.String({ 
            description: "Search query to look up on the web"
        }),
        max_results: Type.Optional(
            Type.Number({
                description: "Maximum number of results to return (1-20). Default: 5",
                minimum: 1,
                maximum: 20
            })
        ),
        search_depth: Type.Optional(
            Type.String({
                // enum: ["basic", "fast", "advanced", "ultra-fast"], // discourage fast and ultra-fast by excluding them
                enum: ["basic", "advanced"],
                description: "Search depth. 'advanced' uses more resources and costs 2 credits."
            })
        ),
        topic: Type.Optional(
            Type.String({
                enum: ["general", "news", "finance"],
                description: "Topic category for the search"
            })
        ),
        include_answer: Type.Optional(
            Type.Union([
                Type.Boolean(),
                Type.Literal("advanced")
            ], {
                description: "Include an LLM-generated answer summary. Set to 'advanced' for better quality."
            })
        ),
        time_range: Type.Optional(
            Type.String({
                enum: ["day", "week", "month", "year"],
                description: "Time range for results"
            })
        ),
        include_raw_content: Type.Optional(
            Type.Boolean({
                description: "Include raw cleaned page content in results (highly encouraged)"
            })
        ),
        include_domains: Type.Optional(
            Type.Array(Type.String(), {
                description: "Array of domains to include in search"
            })
        ),
        exclude_domains: Type.Optional(
            Type.Array(Type.String(), {
                description: "Array of domains to exclude from search"
            })
        )
    });

    pi.registerTool({
        name: "tavily_search",
        label: "Tavily Web Search",
        description: [
            "Search the web using Tavily's API.",
            "Returns structured results with titles, URLs, content snippets, and optionally an LLM-generated answer.",
            "Use this tool whenever you need to look up current information or research topics online."
        ].join(" "),
        parameters: SearchParamsSchema,

        async execute(toolCallId, params, signal, onUpdate, ctx) {
            const apiKey = process.env.TAVILY_API_KEY;

            if (!apiKey || apiKey === "$TAVILY_API_KEY") {
                return {
                    content: [{ 
                        type: "text", 
                        text: "Error: TAVILY_API_KEY environment variable is not set or invalid.\n\n" +
                              "Please ensure TAVILY_API_KEY is exported in your shell before launching pi." 
                    }],
                    isError: true
                };
            }

            const requestParams: SearchParams = {
                query: params.query,
                max_results: params.max_results ?? 5,
                search_depth: params.search_depth,
                topic: params.topic,
                include_answer: params.include_answer,
                time_range: params.time_range,
                include_raw_content: params.include_raw_content,
                include_domains: params.include_domains,
                exclude_domains: params.exclude_domains
            };

            // Filter out undefined values for cleaner request
            const filteredParams = Object.fromEntries(
                Object.entries(requestParams).filter(([_, v]) => v !== undefined)
            );

            try {
                const response = await fetch(API_URL, {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json",
                        "Authorization": `Bearer ${apiKey}`
                    },
                    body: JSON.stringify({ ...filteredParams, include_usage: true }),
                    signal
                });

                if (response.status === 401) {
                    return {
                        content: [{
                            type: "text",
                            text: "Error: Authentication failed. Please check your TAVILY_API_KEY.\n" +
                                  "You can verify your key at https://app.tavily.com"
                        }],
                        isError: true
                    };
                }

                if (response.status === 429) {
                    const ra = formatRetryAfter(response);
                    return {
                        content: [{
                            type: "text",
                            text: `Error: Rate limit exceeded (HTTP 429).${ra}\n` +
                                  "See https://docs.tavily.com/documentation/rate-limits — check usage at https://app.tavily.com"
                        }],
                        isError: true
                    };
                }

                if (response.status === 432 || response.status === 433) {
                    return {
                        content: [{
                            type: "text",
                            text: `Error: Plan or credit limit exceeded (HTTP ${response.status}).\n` +
                                  "Check your usage at https://app.tavily.com or contact support@tavily.com"
                        }],
                        isError: true
                    };
                }

                if (!response.ok) {
                    const errorText = await response.text().catch(() => "");
                    return {
                        content: [{
                            type: "text",
                            text: `Error: API request failed with status ${response.status}.\n` +
                                  `${errorText || "(No additional details)"}` 
                        }],
                        isError: true
                    };
                }

                const data: TavilyResponse = await response.json();

                if (ctx.hasUI) {
                    await ensureFooterCache(ctx);
                    if (typeof data.usage?.credits === "number") {
                        applySearchCreditsToFooter(data.usage.credits);
                        syncFooterFromCache(ctx);
                    }
                }

                if (!data.results || data.results.length === 0) {
                    return {
                        content: [{ 
                            type: "text", 
                            text: "No results found for this query." 
                        }]
                    };
                }

                // Render call
                if (onUpdate) {
                    onUpdate({
                        content: [{ 
                            type: "text", 
                            text: `Searching Tavily for: "${params.query}"` 
                        }],
                        details: {
                            query: params.query,
                            maxResults: params.max_results ?? 5
                        }
                    });
                }

                const formatted = formatResults(data.results, data.answer);
                
                return {
                    content: [{ type: "text", text: formatted }],
                    details: {
                        query: params.query,
                        resultCount: data.results.length,
                        hasAnswer: !!data.answer,
                        usage: data.usage
                    }
                };
            } catch (error) {
                if ((error as Error).name === "AbortError") {
                    return {
                        content: [{
                            type: "text",
                            text: "Search was cancelled."
                        }],
                        isError: true
                    };
                }

                return {
                    content: [{
                        type: "text",
                        text: `Error performing search: ${(error as Error).message}`
                    }],
                    isError: true
                };
            }
        },

        renderCall(args, theme, _context) {
            const queryPreview = (args.query as string).length > 50 
                ? `${(args.query as string).slice(0, 47)}...` 
                : args.query;
            
            let text = theme.fg("toolTitle", theme.bold("tavily_search ")) + theme.fg("accent", `"${queryPreview}"`);
            
            const maxResults = (args.max_results ?? 5) as number;
            if (maxResults !== 5) {
                text += theme.fg("dim", ` (${maxResults} results)`);
            }
            
            const topic = args.topic as string | undefined;
            if (topic && topic !== "general") {
                text += theme.fg("warning", ` [${topic}]`);
            }
            
            return new Text(text, 0, 0);
        },

        renderResult(result, { expanded }, theme, _context) {
            const details = result.details as {
                query?: string;
                resultCount?: number;
                hasAnswer?: boolean;
                usage?: TavilySearchRequestUsage;
            } | undefined;
            
            if (!details || !result.content[0]?.text) {
                return new Text(theme.fg("muted", "(no output)"), 0, 0);
            }

            if (expanded) {
                const container = new Container();
                
                // Header
                let header = theme.fg("success", "✓ ") + theme.fg("toolTitle", theme.bold("tavily_search"));
                if (details.hasAnswer) {
                    header += theme.fg("accent", " (with answer)");
                }
                header += ` — ${details.resultCount} result(s)`;
                if (details.usage && typeof details.usage.credits === "number") {
                    header += theme.fg("dim", ` · ${details.usage.credits} credit(s) this request`);
                }

                container.addChild(new Text(header, 0, 0));
                container.addChild(new Spacer(1));

                // Render content as markdown
                container.addChild(new Markdown(result.content[0].text, 0, 0, getMarkdownTheme()));
                
                return container;
            }

            const lines = result.content[0].text.split("\n");
            let preview = "";
            
            if (details.hasAnswer) {
                preview += theme.fg("accent", "## Answer\n") + 
                          lines.slice(1, Math.min(lines.length, 4)).join("\n") + "\n";
            }
            
            const resultsStart = details.hasAnswer ? lines.findIndex(l => l.startsWith("## Results")) : 0;
            if (resultsStart > 0 && !details.hasAnswer) {
                preview += theme.fg("muted", "(no answer)\n");
            }
            
            // Get first few result titles
            const resultLines = lines.slice(resultsStart + 1).filter(l => l.startsWith("### "));
            for (let i = 0; i < Math.min(3, resultLines.length); i++) {
                preview += theme.fg("dim", "• ") + resultLines[i].replace(/^### /, "") + "\n";
            }
            
            if (resultLines.length > 3) {
                preview += theme.fg("muted", `... and ${resultLines.length - 3} more\n`);
            }

            return new Text(preview.trimEnd(), 0, 0);
        }
    });

    // Usage status footer: bootstrap from GET /usage once per session; increments on each search.
    pi.on("session_start", async (_event, ctx) => {
        await refreshFooterBootstrap(ctx);
    });

    pi.on("session_shutdown", async (_event, ctx) => {
        cachedUsage = null;
        lastUsageSnapshot = null;
        if (ctx.hasUI) {
            ctx.ui.setStatus(STATUS_KEY, undefined);
        }
    });
}