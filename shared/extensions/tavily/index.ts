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
 * API key resolution (in priority order):
 *   1. TAVILY_API_KEY environment variable
 *   2. `$DOT_PI_OVERLAY/.tavily.env`, falling back to repo-root `.tavily.env`
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { getMarkdownTheme } from "@mariozechner/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@mariozechner/pi-tui";
import { Type } from "typebox";
import * as fs from "node:fs";
import { ensureOverlayDir, overlayFile, overlayFirstFile } from "../lib/dotpi-paths.js";

const API_URL = "https://api.tavily.com/search";
const USAGE_API_URL = "https://api.tavily.com/usage";
const STATUS_KEY = "tavily-usage";
const TAVILY_KEY_FILE = ".tavily.env";

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
    topic?: "general" | "news" | "finance";
    time_range?: "day" | "week" | "month" | "year";
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

function formatRetryAfter(response: Response): string {
    const raw = response.headers.get("retry-after")?.trim();
    if (!raw) return "";
    const sec = parseInt(raw, 10);
    if (Number.isFinite(sec) && sec >= 0) {
        return ` Retry after ${sec}s.`;
    }
    return ` Retry-After: ${raw}.`;
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

async function ensureFooterCache(ctx: ExtensionContext): Promise<void> {
    if (!ctx.hasUI || cachedUsage) return;
    await refreshFooterBootstrap(ctx);
}

function applySearchCreditsToFooter(credits: number): void {
    if (!cachedUsage) return;
    cachedUsage.used += credits;
}

function syncFooterFromCache(ctx: ExtensionContext): void {
    if (!ctx.hasUI || !cachedUsage) return;
    ctx.ui.setStatus(STATUS_KEY, formatFooterLine(cachedUsage));
}

export default function (pi: ExtensionAPI) {
    const SearchParamsSchema = Type.Object({
        query: Type.String({
            description: "Internet search query"
        }),
        max_results: Type.Optional(
            Type.Number({
                description: "Maximum number of results to return (1-20). Default: 10",
                minimum: 1,
                maximum: 20
            })
        ),
        topic: Type.Optional(
            Type.String({
                enum: ["general", "news", "finance"],
                description: "Topic category for the search"
            })
        ),
        time_range: Type.Optional(
            Type.String({
                enum: ["day", "week", "month", "year"],
                description: "Time range for results"
            })
        )
    });

    pi.registerTool({
        name: "tavily_search",
        label: "Tavily Web Search",
        description: [
            "Search the live web via Tavily for sources, news, and other information.",
            "Read the `tavily-search` skill before first use this session for parameter guidance."
        ].join(" "),
        parameters: SearchParamsSchema,

        async execute(toolCallId, params, signal, onUpdate, ctx) {
            const apiKey = loadTavilyKey();

            if (!apiKey) {
                return {
                    content: [{ 
                        type: "text", 
                        text: "Error: Tavily API key is not configured.\n\n" +
                              "Run /tavily-api-key to set it, or export TAVILY_API_KEY in your shell." 
                    }],
                    isError: true,
                    details: undefined,
                };
            }

            const requestParams: SearchParams = {
                query: params.query,
                max_results: params.max_results ?? 10,
                topic: params.topic as SearchParams["topic"],
                time_range: params.time_range as SearchParams["time_range"],
            };

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
                    body: JSON.stringify({
                        ...filteredParams,
                        search_depth: "basic",
                        include_raw_content: true,
                        include_answer: false,
                        include_usage: true
                    }),
                    signal
                });

                if (response.status === 401) {
                    return {
                        content: [{
                            type: "text",
                            text: "Error: Authentication failed. Please check your TAVILY_API_KEY.\n" +
                                  "You can verify your key at https://app.tavily.com"
                        }],
                        isError: true,
                        details: undefined,
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
                        isError: true,
                        details: undefined,
                    };
                }

                if (response.status === 432 || response.status === 433) {
                    return {
                        content: [{
                            type: "text",
                            text: `Error: Plan or credit limit exceeded (HTTP ${response.status}).\n` +
                                  "Check your usage at https://app.tavily.com or contact support@tavily.com"
                        }],
                        isError: true,
                        details: undefined,
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
                        isError: true,
                        details: undefined,
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
                        }],
                        details: undefined,
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
                        isError: true,
                        details: undefined,
                    };
                }

                return {
                    content: [{
                        type: "text",
                        text: `Error performing search: ${(error as Error).message}`
                    }],
                    isError: true,
                    details: undefined,
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

            const firstContent = result.content[0];
            const contentText = firstContent?.type === "text" ? firstContent.text : undefined;
            
            if (!details || !contentText) {
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

                container.addChild(new Markdown(contentText, 0, 0, getMarkdownTheme()));
                
                return container;
            }

            const lines = contentText.split("\n");
            let preview = "";
            
            if (details.hasAnswer) {
                preview += theme.fg("accent", "## Answer\n") + 
                          lines.slice(1, Math.min(lines.length, 4)).join("\n") + "\n";
            }
            
            const resultsStart = details.hasAnswer ? lines.findIndex((l: string) => l.startsWith("## Results")) : 0;
            if (resultsStart > 0 && !details.hasAnswer) {
                preview += theme.fg("muted", "(no answer)\n");
            }
            
            // Get first few result titles
            const resultLines = lines.slice(resultsStart + 1).filter((l: string) => l.startsWith("### "));
            for (let i = 0; i < Math.min(3, resultLines.length); i++) {
                preview += theme.fg("dim", "• ") + resultLines[i].replace(/^### /, "") + "\n";
            }
            
            if (resultLines.length > 3) {
                preview += theme.fg("muted", `... and ${resultLines.length - 3} more\n`);
            }

            return new Text(preview.trimEnd(), 0, 0);
        }
    });

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