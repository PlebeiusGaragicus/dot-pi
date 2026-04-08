/**
 * Agent Team 2 — Dispatcher orchestrator with inline agent output
 *
 * Same dispatch model as agent-team, but agent output streams directly
 * into the chat instead of a separate grid widget.
 *
 * Loads agent definitions from agents/*.md, .claude/agents/*.md, .pi/agents/*.md.
 * Teams are defined in .pi/agents/teams.yaml or ~/dot-pi/agents/teams.yaml.
 *
 * Commands:
 *   /agents-team          — switch active team
 *   /agents-list          — list loaded agents
 *
 * Usage: pi -e extensions/orchestration/agent-team-2.ts
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { Text, type AutocompleteItem, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";
import { spawn } from "child_process";
import { readdirSync, readFileSync, existsSync, mkdirSync, unlinkSync } from "fs";
import { join, resolve } from "path";
import { homedir } from "os";


// ── Types ────────────────────────────────────────

interface AgentDef {
	name: string;
	description: string;
	tools: string;
	model: string;
	systemPrompt: string;
	file: string;
}

interface AgentState {
	def: AgentDef;
	status: "idle" | "running" | "done" | "error";
	runCount: number;
	sessionFile: string | null;
}

type TranscriptEntry =
	| { kind: "text"; content: string }
	| { kind: "tool_start"; tool: string; args: string }
	| { kind: "tool_result"; tool: string; content: string; isError: boolean };

// ── Display Name Helper ──────────────────────────

function displayName(name: string): string {
	return name.split("-").map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
}

// ── Teams YAML Parser ────────────────────────────

function parseTeamsYaml(raw: string): Record<string, string[]> {
	const teams: Record<string, string[]> = {};
	let current: string | null = null;
	for (const line of raw.split("\n")) {
		const teamMatch = line.match(/^(\S[^:]*):$/);
		if (teamMatch) {
			current = teamMatch[1].trim();
			teams[current] = [];
			continue;
		}
		const itemMatch = line.match(/^\s+-\s+(.+)$/);
		if (itemMatch && current) {
			teams[current].push(itemMatch[1].trim());
		}
	}
	return teams;
}

// ── Frontmatter Parser ───────────────────────────

function parseAgentFile(filePath: string): AgentDef | null {
	try {
		const raw = readFileSync(filePath, "utf-8");
		const match = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
		if (!match) return null;

		const frontmatter: Record<string, string> = {};
		for (const line of match[1].split("\n")) {
			const idx = line.indexOf(":");
			if (idx > 0) {
				frontmatter[line.slice(0, idx).trim()] = line.slice(idx + 1).trim();
			}
		}

		if (!frontmatter.name) return null;

		return {
			name: frontmatter.name,
			description: frontmatter.description || "",
			tools: frontmatter.tools || "read,grep,find,ls",
			model: frontmatter.model || "",
			systemPrompt: match[2].trim(),
			file: filePath,
		};
	} catch {
		return null;
	}
}

function scanAgentDirs(cwd: string): AgentDef[] {
	const dirs = [
		join(homedir(), "dot-pi", "agents"),
		join(cwd, "agents"),
		join(cwd, ".claude", "agents"),
		join(cwd, ".pi", "agents"),
	];

	const agents: AgentDef[] = [];
	const seen = new Set<string>();

	for (const dir of dirs) {
		if (!existsSync(dir)) continue;
		try {
			for (const file of readdirSync(dir)) {
				if (!file.endsWith(".md")) continue;
				const fullPath = resolve(dir, file);
				const def = parseAgentFile(fullPath);
				if (def && !seen.has(def.name.toLowerCase())) {
					seen.add(def.name.toLowerCase());
					agents.push(def);
				}
			}
		} catch {}
	}

	return agents;
}

// ── Extension ────────────────────────────────────

export default function (pi: ExtensionAPI) {
	const agentStates: Map<string, AgentState> = new Map();
	let allAgentDefs: AgentDef[] = [];
	let teams: Record<string, string[]> = {};
	let activeTeamName = "";
	let sessionDir = "";
	let contextWindow = 0;

	function loadAgents(cwd: string) {
		const workspace = process.env.AGENT_WORKSPACE;
		if (workspace) {
			sessionDir = join(workspace, "sessions");
		} else {
			sessionDir = join(cwd, ".pi", "agent-sessions");
		}
		if (!existsSync(sessionDir)) {
			mkdirSync(sessionDir, { recursive: true });
		}

		allAgentDefs = scanAgentDirs(cwd);

		teams = {};
		const teamsPaths = [
			join(cwd, ".pi", "agents", "teams.yaml"),
			join(homedir(), "dot-pi", "agents", "teams.yaml"),
		];
		for (const teamsPath of teamsPaths) {
			if (existsSync(teamsPath)) {
				try {
					const parsed = parseTeamsYaml(readFileSync(teamsPath, "utf-8"));
					teams = { ...parsed, ...teams };
				} catch {}
			}
		}

		if (Object.keys(teams).length === 0) {
			teams = { all: allAgentDefs.map(d => d.name) };
		}
	}

	function activateTeam(teamName: string) {
		activeTeamName = teamName;
		const members = teams[teamName] || [];
		const defsByName = new Map(allAgentDefs.map(d => [d.name.toLowerCase(), d]));

		agentStates.clear();
		for (const member of members) {
			const def = defsByName.get(member.toLowerCase());
			if (!def) continue;
			const key = def.name.toLowerCase().replace(/\s+/g, "-");
			const sessionFile = join(sessionDir, `${key}.json`);
			agentStates.set(def.name.toLowerCase(), {
				def,
				status: "idle",
				runCount: 0,
				sessionFile: existsSync(sessionFile) ? sessionFile : null,
			});
		}
	}

	// ── Dispatch Agent ──────────────────────────

	function dispatchAgent(
		agentName: string,
		task: string,
		ctx: any,
		onUpdate?: (data: any) => void,
	): Promise<{ output: string; exitCode: number; elapsed: number }> {
		const key = agentName.toLowerCase();
		const state = agentStates.get(key);
		if (!state) {
			return Promise.resolve({
				output: `Agent "${agentName}" not found. Available: ${Array.from(agentStates.values()).map(s => displayName(s.def.name)).join(", ")}`,
				exitCode: 1,
				elapsed: 0,
			});
		}

		if (state.status === "running") {
			return Promise.resolve({
				output: `Agent "${displayName(state.def.name)}" is already running. Wait for it to finish.`,
				exitCode: 1,
				elapsed: 0,
			});
		}

		state.status = "running";
		state.runCount++;

		const startTime = Date.now();

		const model = state.def.model
			|| (ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "openrouter/google/gemini-3-flash-preview");

		const agentKey = state.def.name.toLowerCase().replace(/\s+/g, "-");
		const agentSessionFile = join(sessionDir, `${agentKey}.json`);

		const args = [
			"--mode", "json",
			"-p",
			"--no-extensions",
			"--model", model,
			"--tools", state.def.tools,
			"--thinking", "off",
			"--append-system-prompt", state.def.systemPrompt,
			"--session", agentSessionFile,
		];

		if (state.sessionFile) {
			args.push("-c");
		}

		args.push(task);

		const entries: TranscriptEntry[] = [];
		let pendingText = "";
		const activeTools: Map<string, string> = new Map();

		function flushText() {
			if (pendingText) {
				entries.push({ kind: "text", content: pendingText });
				pendingText = "";
			}
		}

		function formatArgs(raw: any): string {
			if (!raw) return "";
			try {
				const a = typeof raw === "string" ? JSON.parse(raw) : raw;
				return Object.entries(a)
					.map(([k, v]) => {
						const vs = typeof v === "string" ? v : JSON.stringify(v);
						return `${k}: ${vs.length > 120 ? vs.slice(0, 117) + "…" : vs}`;
					})
					.join("\n");
			} catch {
				return String(raw);
			}
		}

		function extractResultText(result: any): string {
			if (!result) return "";
			if (typeof result === "string") return result;
			if (result.content) {
				return result.content
					.map((c: any) => c.type === "text" ? c.text : `[${c.type}]`)
					.join("\n");
			}
			return JSON.stringify(result);
		}

		function emitUpdate() {
			if (!onUpdate) return;
			const elapsed = Math.round((Date.now() - startTime) / 1000);
			const snapshot = [...entries];
			if (pendingText) snapshot.push({ kind: "text", content: pendingText });
			onUpdate({
				content: [{ type: "text", text: `running ${elapsed}s` }],
				details: {
					agent: agentName,
					task,
					status: "running",
					elapsed,
					entries: snapshot,
				},
			});
		}

		return new Promise((resolve) => {
			const proc = spawn("pi", args, {
				stdio: ["ignore", "pipe", "pipe"],
				env: { ...process.env },
			});

			let buffer = "";

			proc.stdout!.setEncoding("utf-8");
			proc.stdout!.on("data", (chunk: string) => {
				buffer += chunk;
				const lines = buffer.split("\n");
				buffer = lines.pop() || "";
				for (const line of lines) {
					if (!line.trim()) continue;
					try {
						const event = JSON.parse(line);

						if (event.type === "message_update") {
							const delta = event.assistantMessageEvent;
							if (delta?.type === "text_delta") {
								pendingText += delta.delta || "";
								emitUpdate();
							}
						} else if (event.type === "tool_execution_start") {
							flushText();
							const name = event.toolName || "tool";
							activeTools.set(event.toolCallId, name);
							entries.push({
								kind: "tool_start",
								tool: name,
								args: formatArgs(event.args),
							});
							emitUpdate();
						} else if (event.type === "tool_execution_end") {
							const name = activeTools.get(event.toolCallId) || event.toolName || "tool";
							activeTools.delete(event.toolCallId);
							entries.push({
								kind: "tool_result",
								tool: name,
								content: extractResultText(event.result),
								isError: !!event.isError,
							});
							emitUpdate();
						}
					} catch {}
				}
			});

			proc.stderr!.setEncoding("utf-8");
			proc.stderr!.on("data", () => {});

			proc.on("close", (code) => {
				if (buffer.trim()) {
					try {
						const event = JSON.parse(buffer);
						if (event.type === "message_update") {
							const delta = event.assistantMessageEvent;
							if (delta?.type === "text_delta") pendingText += delta.delta || "";
						}
					} catch {}
				}

				flushText();
				const elapsed = Date.now() - startTime;
				state.status = code === 0 ? "done" : "error";

				if (code === 0) {
					state.sessionFile = agentSessionFile;
				}

				ctx.ui.notify(
					`${displayName(state.def.name)} ${state.status} in ${Math.round(elapsed / 1000)}s`,
					state.status === "done" ? "success" : "error"
				);

				resolve({
					output: JSON.stringify(entries),
					exitCode: code ?? 1,
					elapsed,
				});
			});

			proc.on("error", (err) => {
				state.status = "error";
				resolve({
					output: `Error spawning agent: ${err.message}`,
					exitCode: 1,
					elapsed: Date.now() - startTime,
				});
			});
		});
	}

	// ── dispatch_agent Tool ──────────────────────

	pi.registerTool({
		name: "dispatch_agent",
		label: "Dispatch Agent",
		description: "Dispatch a task to a specialist agent. The agent will execute the task and return the result. Use the system prompt to see available agent names.",
		parameters: Type.Object({
			agent: Type.String({ description: "Agent name (case-insensitive)" }),
			task: Type.String({ description: "Task description for the agent to execute" }),
		}),

		async execute(_toolCallId, params, _signal, onUpdate, ctx) {
			const { agent, task } = params as { agent: string; task: string };

			try {
				if (onUpdate) {
					onUpdate({
						content: [{ type: "text", text: `Dispatching to ${agent}...` }],
						details: { agent, task, status: "dispatching" },
					});
				}

				const result = await dispatchAgent(agent, task, ctx, onUpdate);

				const status = result.exitCode === 0 ? "done" : "error";
				const summary = `[${agent}] ${status} in ${Math.round(result.elapsed / 1000)}s`;

				let entries: TranscriptEntry[] = [];
				try { entries = JSON.parse(result.output); } catch {}

				// Build plain-text version for the orchestrator model
				const agentText = entries
					.filter(e => e.kind === "text")
					.map(e => (e as any).content)
					.join("");
				const truncated = agentText.length > 8000
					? agentText.slice(0, 8000) + "\n\n... [truncated]"
					: agentText;

				return {
					content: [{ type: "text", text: `${summary}\n\n${truncated}` }],
					details: {
						agent,
						task,
						status,
						elapsed: result.elapsed,
						exitCode: result.exitCode,
						entries,
					},
				};
			} catch (err: any) {
				return {
					content: [{ type: "text", text: `Error dispatching to ${agent}: ${err?.message || err}` }],
					details: { agent, task, status: "error", elapsed: 0, exitCode: 1, fullOutput: "" },
				};
			}
		},

		renderCall(args, theme) {
			const agentName = (args as any).agent || "?";
			const task = (args as any).task || "";
			const preview = task.length > 60 ? task.slice(0, 80) + "..." : task;
			return new Text(
				theme.fg("toolTitle", theme.bold("dispatch_agent ")) +
				theme.fg("accent", agentName) +
				theme.fg("dim", " — ") +
				theme.fg("muted", preview),
				0, 0,
			);
		},

		renderResult(result, options, theme) {
			const details = result.details as any;
			if (!details) {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "", 0, 0);
			}

			const TOOL_EMOJI: Record<string, string> = {
				read:  "📖", grep:  "🔍", find:  "🔎", ls:    "📂",
				bash:  "🖥️",  edit:  "✏️",  write: "📝",
			};

			function toolIcon(name: string, isError?: boolean): string {
				if (isError) return "❌";
				return TOOL_EMOJI[name.toLowerCase()] || "⚙️";
			}

			function buildEmojiRow(entries: TranscriptEntry[]): string {
				const icons: string[] = [];
				for (const e of entries) {
					if (e.kind === "tool_start") {
						icons.push(toolIcon(e.tool));
					} else if (e.kind === "tool_result" && e.isError) {
						if (icons.length > 0) icons[icons.length - 1] = "❌";
						else icons.push("❌");
					}
				}
				return icons.join(" ");
			}

			function latestText(entries: TranscriptEntry[]): string {
				let text = "";
				for (const e of entries) {
					if (e.kind === "text") text = e.content;
				}
				return text.trim();
			}

			function renderClean(entries: TranscriptEntry[]): string {
				const emojis = buildEmojiRow(entries);
				const emojiLine = emojis ? "  " + emojis : "";
				const text = latestText(entries);
				return emojiLine + (text ? "\n\n" + text : "");
			}

			if (options.isPartial || details.status === "dispatching") {
				const entries: TranscriptEntry[] = details.entries || [];
				const elapsed = typeof details.elapsed === "number" ? details.elapsed : 0;
				const header = theme.fg("accent", `● ${details.agent || "?"}`) +
					theme.fg("dim", ` ${elapsed}s`);
				if (entries.length === 0) {
					return new Text(header + theme.fg("dim", " working..."), 0, 0);
				}
				return new Text(header + "\n" + renderClean(entries), 0, 0);
			}

			const icon = details.status === "done" ? "✓" : "✗";
			const color = details.status === "done" ? "success" : "error";
			const elapsed = typeof details.elapsed === "number" ? Math.round(details.elapsed / 1000) : 0;
			const header = theme.fg(color, `${icon} ${details.agent}`) +
				theme.fg("dim", ` ${elapsed}s`);

			let entries: TranscriptEntry[] = details.entries || [];
			if (entries.length === 0 && details.fullOutput) {
				try { entries = JSON.parse(details.fullOutput); } catch {}
			}

			if (entries.length > 0) {
				return new Text(header + "\n" + renderClean(entries), 0, 0);
			}
			return new Text(header, 0, 0);
		},
	});

	// ── Commands ─────────────────────────────────

	pi.registerCommand("agents-team", {
		description: "Select a team to work with",
		handler: async (_args, ctx) => {
			const teamNames = Object.keys(teams);
			if (teamNames.length === 0) {
				ctx.ui.notify("No teams defined", "warning");
				return;
			}

			const options = teamNames.map(name => {
				const members = teams[name].map(m => displayName(m));
				return `${name} — ${members.join(", ")}`;
			});

			const choice = await ctx.ui.select("Select Team", options);
			if (choice === undefined) return;

			const idx = options.indexOf(choice);
			const name = teamNames[idx];
			activateTeam(name);
			ctx.ui.setStatus("agent-team", `Team: ${name} (${agentStates.size})`);
			ctx.ui.notify(`Team: ${name} — ${Array.from(agentStates.values()).map(s => displayName(s.def.name)).join(", ")}`, "info");
		},
	});

	pi.registerCommand("agents-list", {
		description: "List all loaded agents",
		handler: async (_args, ctx) => {
			const names = Array.from(agentStates.values())
				.map(s => {
					const session = s.sessionFile ? "resumed" : "new";
					return `${displayName(s.def.name)} (${s.status}, ${session}, runs: ${s.runCount}): ${s.def.description}`;
				})
				.join("\n");
			ctx.ui.notify(names || "No agents loaded", "info");
		},
	});

	// ── System Prompt Override ───────────────────

	pi.on("before_agent_start", async (_event, _ctx) => {
		const agentCatalog = Array.from(agentStates.values())
			.map(s => `### ${displayName(s.def.name)}\n**Dispatch as:** \`${s.def.name}\`\n${s.def.description}\n**Tools:** ${s.def.tools}`)
			.join("\n\n");

		const teamMembers = Array.from(agentStates.values()).map(s => displayName(s.def.name)).join(", ");

		const workspace = process.env.AGENT_WORKSPACE;
		const workspaceBlock = workspace
			? `\n## Workspace\n\nAll agent output for this run goes to:\n\`\`\`\n${workspace}\n\`\`\`\n`
			: "";

		return {
			systemPrompt: `You are a dispatcher agent. You coordinate specialist agents to accomplish tasks.
You do NOT have direct access to the codebase. You MUST delegate all work through
agents using the dispatch_agent tool.

## Active Team: ${activeTeamName}
Members: ${teamMembers}
You can ONLY dispatch to agents listed below. Do not attempt to dispatch to agents outside this team.
${workspaceBlock}
## How to Work
- Analyze the user's request and break it into clear sub-tasks
- Choose the right agent(s) for each sub-task
- Dispatch tasks using the dispatch_agent tool
- Review results and dispatch follow-up agents if needed
- If a task fails, try a different agent or adjust the task description
- Summarize the outcome for the user

## Rules
- NEVER try to read, write, or execute code directly — you have no such tools
- ALWAYS use dispatch_agent to get work done
- You can chain agents: use scout to explore, then builder to implement
- You can dispatch the same agent multiple times with different tasks
- Keep tasks focused — one clear objective per dispatch

## Agents

${agentCatalog}`,
		};
	});

	// ── Session Start ────────────────────────────

	pi.on("session_start", async (_event, _ctx) => {
		setTimeout(() => _ctx.ui.setTitle("π - agent-team-2"), 150);
		contextWindow = _ctx.model?.contextWindow || 0;

		const sessDir = join(_ctx.cwd, ".pi", "agent-sessions");
		if (existsSync(sessDir)) {
			for (const f of readdirSync(sessDir)) {
				if (f.endsWith(".json")) {
					try { unlinkSync(join(sessDir, f)); } catch {}
				}
			}
		}

		loadAgents(_ctx.cwd);

		const teamNames = Object.keys(teams);
		if (teamNames.length > 0) {
			const envTeam = process.env.AGENT_TEAM;
			const startTeam = envTeam && teamNames.includes(envTeam) ? envTeam : teamNames[0];
			activateTeam(startTeam);
		}

		pi.setActiveTools(["dispatch_agent"]);

		_ctx.ui.setStatus("agent-team", `Team: ${activeTeamName} (${agentStates.size})`);
		const members = Array.from(agentStates.values()).map(s => displayName(s.def.name)).join(", ");
		_ctx.ui.notify(
			`Team: ${activeTeamName} (${members})\n\n` +
			`/agents-team          Select a team\n` +
			`/agents-list          List active agents`,
			"info",
		);

		_ctx.ui.setFooter((_tui, theme, _footerData) => ({
			dispose: () => {},
			invalidate() {},
			render(width: number): string[] {
				const model = _ctx.model?.id || "no-model";
				const usage = _ctx.getContextUsage();
				const pct = usage ? usage.percent : 0;
				const filled = Math.round(pct / 10);
				const bar = "#".repeat(filled) + "-".repeat(10 - filled);

				const left = theme.fg("dim", ` ${model}`) +
					theme.fg("muted", " · ") +
					theme.fg("accent", activeTeamName);
				const right = theme.fg("dim", `[${bar}] ${Math.round(pct)}% `);
				const pad = " ".repeat(Math.max(1, width - visibleWidth(left) - visibleWidth(right)));

				return [truncateToWidth(left + pad + right, width)];
			},
		}));
	});
}
