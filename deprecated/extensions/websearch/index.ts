/**
 * Websearch extension — Tavily Search API as a native tool.
 *
 * Registers a `websearch` tool. Reusable: symlink into any agent that needs
 * web search. Agent-specific prompt and tool restrictions belong in AGENT.md
 * (loaded by the agent-prompt extension) or SYSTEM.md (pi-native).
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { getMarkdownTheme } from "@mariozechner/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@mariozechner/pi-tui";
import { StringEnum } from "@mariozechner/pi-ai";
import { Type } from "@sinclair/typebox";

const SearchDepthSchema = StringEnum(["basic", "fast", "advanced", "ultra-fast"] as const, {
	description: "Latency vs relevance. advanced uses 2 API credits.",
	default: "basic",
});

const TopicSchema = StringEnum(["general", "news", "finance"] as const, {
	description: "Search category.",
	default: "general",
});

const TimeRangeSchema = StringEnum(["day", "week", "month", "year"] as const, {
	description: "Filter by recency (optional).",
});

const WebsearchParams = Type.Object({
	query: Type.String({ description: "Search query" }),
	max_results: Type.Optional(
		Type.Integer({ minimum: 0, maximum: 20, description: "Max results (default 5)", default: 5 }),
	),
	search_depth: Type.Optional(SearchDepthSchema),
	topic: Type.Optional(TopicSchema),
	include_answer: Type.Optional(
		Type.Union([Type.Boolean(), Type.Literal("basic"), Type.Literal("advanced")], {
			description: "Include an LLM summary: true/basic (quick) or advanced (detailed).",
		}),
	),
	time_range: Type.Optional(TimeRangeSchema),
	include_raw_content: Type.Optional(Type.Boolean({ description: "Include cleaned page body per result", default: false })),
	include_domains: Type.Optional(Type.Array(Type.String(), { description: "Only these domains (max 300)" })),
	exclude_domains: Type.Optional(Type.Array(Type.String(), { description: "Exclude these domains (max 150)" })),
});

interface TavilyResult {
	title?: string;
	url?: string;
	content?: string;
	score?: number;
	raw_content?: string;
}

interface TavilyResponse {
	query?: string;
	answer?: string;
	results?: TavilyResult[];
	detail?: { error?: string };
}

function buildBody(params: Record<string, unknown>): Record<string, unknown> {
	const body: Record<string, unknown> = { query: params.query };
	const max = params.max_results;
	if (typeof max === "number") body.max_results = max;
	else body.max_results = 5;

	if (params.search_depth) body.search_depth = params.search_depth;
	if (params.topic) body.topic = params.topic;
	if (params.include_answer !== undefined) body.include_answer = params.include_answer;
	if (params.time_range) body.time_range = params.time_range;
	if (params.include_raw_content === true) body.include_raw_content = true;
	const inc = params.include_domains as string[] | undefined;
	const exc = params.exclude_domains as string[] | undefined;
	if (inc?.length) body.include_domains = inc;
	if (exc?.length) body.exclude_domains = exc;
	return body;
}

function formatResponse(data: TavilyResponse): string {
	const parts: string[] = [];
	if (data.answer) parts.push(`## Answer\n\n${data.answer}\n`);
	if (data.results?.length) {
		parts.push("## Results\n");
		for (let i = 0; i < data.results.length; i++) {
			const r = data.results[i];
			const title = r.title ?? "(no title)";
			const url = r.url ?? "";
			const score = r.score != null ? ` (score: ${r.score.toFixed(4)})` : "";
			parts.push(`### ${i + 1}. ${title}${score}\n${url}\n\n${r.content ?? ""}\n`);
			if (r.raw_content)
				parts.push(
					`\n---\nRaw excerpt:\n${r.raw_content.slice(0, 2000)}${r.raw_content.length > 2000 ? "\u2026" : ""}\n`,
				);
		}
	}
	if (!parts.length) return "(no results)";
	return parts.join("\n");
}

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "websearch",
		label: "Web search",
		description:
			"Search the web via Tavily (https://api.tavily.com). Uses TAVILY_API_KEY from the environment. Returns titles, URLs, and snippets.",
		parameters: WebsearchParams,

		async execute(_toolCallId, params, signal) {
			const key = process.env.TAVILY_API_KEY;
			if (!key?.trim()) {
				return {
					content: [
						{
							type: "text",
							text: "TAVILY_API_KEY is not set. Export it in the shell that launches pi (e.g. in dot-pi/.env).",
						},
					],
					isError: true,
				};
			}

			const body = buildBody(params as Record<string, unknown>);
			let res: Response;
			try {
				res = await fetch("https://api.tavily.com/search", {
					method: "POST",
					headers: {
						"Content-Type": "application/json",
						Authorization: `Bearer ${key}`,
					},
					body: JSON.stringify(body),
					signal,
				});
			} catch (e) {
				const msg = e instanceof Error ? e.message : String(e);
				return { content: [{ type: "text", text: `Request failed: ${msg}` }], isError: true };
			}

			let data: TavilyResponse;
			try {
				data = (await res.json()) as TavilyResponse;
			} catch {
				return {
					content: [{ type: "text", text: `Invalid JSON from Tavily (HTTP ${res.status})` }],
					isError: true,
				};
			}

			if (!res.ok) {
				const err =
					(typeof data.detail === "object" && data.detail?.error) ||
					JSON.stringify(data.detail ?? data);
				return {
					content: [{ type: "text", text: `Tavily error (${res.status}): ${err}` }],
					isError: true,
				};
			}

			return { content: [{ type: "text", text: formatResponse(data) }] };
		},

		renderCall(args, theme) {
			const q = (args.query as string) || "";
			const preview = q.length > 72 ? `${q.slice(0, 72)}\u2026` : q;
			let line =
				theme.fg("toolTitle", theme.bold("websearch ")) + theme.fg("accent", preview);
			if (args.topic && args.topic !== "general") line += theme.fg("muted", ` topic:${args.topic}`);
			if (args.search_depth && args.search_depth !== "basic")
				line += theme.fg("muted", ` depth:${args.search_depth}`);
			return new Text(line, 0, 0);
		},

		renderResult(result, { expanded }, theme) {
			const text = result.content[0]?.type === "text" ? result.content[0].text : "";
			if (!text) return new Text(theme.fg("muted", "(empty)"), 0, 0);
			if (expanded) {
				const mdTheme = getMarkdownTheme();
				const c = new Container();
				c.addChild(new Markdown(text, 0, 0, mdTheme));
				return c;
			}
			const head = text.split("\n").slice(0, 12).join("\n");
			return new Container().addChild(new Text(theme.fg("toolOutput", head), 0, 0)).addChild(new Spacer(1));
		},
	});
}
