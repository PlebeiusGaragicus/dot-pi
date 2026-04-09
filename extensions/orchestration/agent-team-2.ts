/**
 * Agent Team 2 — Dispatcher orchestrator with inline agent output
 *
 * Loads agent definitions from agents/*.md, .claude/agents/*.md, .pi/agents/*.md.
 *
 * Team definitions are loaded from (in priority order):
 *   1. Rich YAML files in agents/teams/*.yaml (per-team files with orchestrator
 *      prompts, welcome messages, and workflow definitions)
 *   2. Flat teams.yaml in .pi/agents/teams.yaml or ~/dot-pi/agents/teams.yaml
 *      (simple name-to-member-list mapping, used as fallback)
 *
 * Environment variables:
 *   AGENT_TEAM       — select the active team at startup
 *   AGENT_WORKSPACE  — workspace directory for agent output
 *   AGENT_WORKFLOW   — auto-inject a named workflow's prompt into the system prompt
 *   AGENT_ROLE       — "orchestrator" (default) or "lead" (for nested dispatch)
 *   RETRO_TARGET     — target workspace for retro analysis
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
import { readdirSync, readFileSync, existsSync, mkdirSync, unlinkSync, mkdtempSync, writeFileSync, rmdirSync } from "fs";
import { join, resolve, dirname } from "path";
import { homedir, tmpdir } from "os";


// ── Types ────────────────────────────────────────

interface AgentDef {
	name: string;
	description: string;
	tools: string;
	model: string;
	role: string;
	skills: string;
	systemPrompt: string;
	file: string;
}

interface AgentState {
	def: AgentDef;
	activeDispatches: number;
	runCount: number;
}

interface TopicDef {
	name: string;
	slug: string;
	active: boolean;
	priority: string;
	raw: string;
}

interface WorkflowDef {
	description: string;
	prompt_file: string;
	requires_workspace: boolean;
	requires_topics: boolean;
}

interface TeamDef {
	name: string;
	description: string;
	mode: string;
	members: string[];
	welcome: string;
	orchestrator_prompt: string;
	workflows: Record<string, WorkflowDef>;
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

// ── Rich Team YAML Parser ───────────────────────

function parseTeamFile(raw: string): TeamDef | null {
	const def: TeamDef = {
		name: "", description: "", mode: "interactive",
		members: [], welcome: "", orchestrator_prompt: "",
		workflows: {},
	};
	const lines = raw.split("\n");
	let i = 0;

	function indent(line: string): number {
		const m = line.match(/^(\s*)/);
		return m ? m[1].length : 0;
	}

	function stripComment(val: string): string {
		const m = val.match(/^([^#]*?)(\s+#.*)?$/);
		return m ? m[1].trim() : val.trim();
	}

	function unquote(val: string): string {
		return val.replace(/^["']|["']$/g, "").trim();
	}

	function readBlockScalar(): string {
		const result: string[] = [];
		while (i < lines.length) {
			const line = lines[i];
			if (line.trim() === "" || indent(line) >= 2) {
				result.push(line.length >= 2 ? line.slice(2) : "");
				i++;
			} else {
				break;
			}
		}
		while (result.length > 0 && result[result.length - 1].trim() === "") result.pop();
		return result.join("\n");
	}

	function readList(): string[] {
		const result: string[] = [];
		while (i < lines.length) {
			const m = lines[i].match(/^\s+-\s+(.+)$/);
			if (m) {
				result.push(stripComment(m[1]));
				i++;
			} else if (lines[i].trim() === "" || lines[i].match(/^\s+#/)) {
				i++;
			} else {
				break;
			}
		}
		return result;
	}

	function readWorkflows(): Record<string, WorkflowDef> {
		const workflows: Record<string, WorkflowDef> = {};
		while (i < lines.length) {
			const line = lines[i];
			if (line.trim() === "" || line.match(/^\s+#/)) { i++; continue; }
			if (indent(line) < 2) break;
			const nameMatch = line.match(/^\s{2}(\S[^:]*):$/);
			if (nameMatch) {
				const wfName = nameMatch[1].trim();
				i++;
				const wf: WorkflowDef = { description: "", prompt_file: "", requires_workspace: false, requires_topics: false };
				while (i < lines.length) {
					const wfLine = lines[i];
					if (wfLine.trim() === "") { i++; continue; }
					if (indent(wfLine) < 4) break;
					const kvMatch = wfLine.match(/^\s{4}(\w[\w_]*):\s*(.+)$/);
					if (kvMatch) {
						const val = unquote(kvMatch[2]);
						if (kvMatch[1] === "description") wf.description = val;
						else if (kvMatch[1] === "prompt_file") wf.prompt_file = val;
						else if (kvMatch[1] === "requires_workspace") wf.requires_workspace = val === "true";
						else if (kvMatch[1] === "requires_topics") wf.requires_topics = val === "true";
					}
					i++;
				}
				workflows[wfName] = wf;
			} else {
				i++;
			}
		}
		return workflows;
	}

	while (i < lines.length) {
		const line = lines[i];
		if (line.trim() === "" || line.match(/^#/)) { i++; continue; }
		const kvMatch = line.match(/^(\w[\w_]*)\s*:\s*(.*)$/);
		if (kvMatch) {
			const [, key, rawVal] = kvMatch;
			const val = unquote(rawVal);
			i++;
			if (key === "name") def.name = val;
			else if (key === "description") def.description = val;
			else if (key === "mode") def.mode = val;
			else if (key === "members") def.members = readList();
			else if (key === "welcome" && rawVal.trim() === "|") def.welcome = readBlockScalar();
			else if (key === "orchestrator_prompt" && rawVal.trim() === "|") def.orchestrator_prompt = readBlockScalar();
			else if (key === "workflows") {
				if (rawVal.trim() === "{}" || rawVal.trim() === "") {
					def.workflows = {};
				} else {
					def.workflows = readWorkflows();
				}
			}
		} else {
			i++;
		}
	}

	if (!def.name) return null;
	return def;
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
			role: frontmatter.role || "",
			skills: frontmatter.skills || "",
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
	let teamDefs: Map<string, TeamDef> = new Map();
	let activeTeamName = "";
	let activeTeamDef: TeamDef | null = null;
	let sessionDir = "";
	let contextWindow = 0;
	let loadedTopics: TopicDef[] = [];
	let storyIndexRaw = "";

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
		teamDefs = new Map();

		const richTeamDirs = [
			join(cwd, ".pi", "agents", "teams"),
			join(homedir(), "dot-pi", "agents", "teams"),
		];
		for (const teamDir of richTeamDirs) {
			if (!existsSync(teamDir)) continue;
			try {
				for (const file of readdirSync(teamDir)) {
					if (!file.endsWith(".yaml")) continue;
					try {
						const def = parseTeamFile(readFileSync(join(teamDir, file), "utf-8"));
						if (def && !teamDefs.has(def.name)) {
							teamDefs.set(def.name, def);
							teams[def.name] = def.members;
						}
					} catch {}
				}
			} catch {}
		}

		const flatTeamsPaths = [
			join(cwd, ".pi", "agents", "teams.yaml"),
			join(homedir(), "dot-pi", "agents", "teams.yaml"),
		];
		for (const teamsPath of flatTeamsPaths) {
			if (existsSync(teamsPath)) {
				try {
					const parsed = parseTeamsYaml(readFileSync(teamsPath, "utf-8"));
					for (const [name, members] of Object.entries(parsed)) {
						if (!teams[name]) {
							teams[name] = members;
						}
					}
				} catch {}
			}
		}

		if (Object.keys(teams).length === 0) {
			teams = { all: allAgentDefs.map(d => d.name) };
		}
	}

	function loadTopics() {
		loadedTopics = [];
		storyIndexRaw = "";

		const workspace = process.env.AGENT_WORKSPACE;
		if (!workspace) return;

		// Topics live at the team workspace root (parent of the per-run directory)
		const topicDir = join(dirname(workspace), "topics");
		if (!existsSync(topicDir)) return;

		try {
			for (const file of readdirSync(topicDir)) {
				if (!file.endsWith(".yaml") || file === "story-index.yaml") continue;
				const fullPath = join(topicDir, file);
				try {
					const raw = readFileSync(fullPath, "utf-8");
					const nameMatch = raw.match(/^name:\s*(.+)$/m);
					const slugMatch = raw.match(/^slug:\s*(.+)$/m);
					const activeMatch = raw.match(/^active:\s*(.+)$/m);
					const priorityMatch = raw.match(/^priority:\s*(.+)$/m);
					if (!slugMatch) continue;
					loadedTopics.push({
						name: nameMatch?.[1]?.trim() || slugMatch[1].trim(),
						slug: slugMatch[1].trim(),
						active: activeMatch ? activeMatch[1].trim() !== "false" : true,
						priority: priorityMatch?.[1]?.trim() || "medium",
						raw: raw.trim(),
					});
				} catch {}
			}
		} catch {}

		const indexPath = join(topicDir, "story-index.yaml");
		if (existsSync(indexPath)) {
			try {
				storyIndexRaw = readFileSync(indexPath, "utf-8").trim();
			} catch {}
		}
	}

	function activateTeam(teamName: string) {
		activeTeamName = teamName;
		activeTeamDef = teamDefs.get(teamName) || null;
		const members = teams[teamName] || [];
		const defsByName = new Map(allAgentDefs.map(d => [d.name.toLowerCase(), d]));

		agentStates.clear();
		for (const member of members) {
			const def = defsByName.get(member.toLowerCase());
			if (!def) continue;
			agentStates.set(def.name.toLowerCase(), {
				def,
				activeDispatches: 0,
				runCount: 0,
			});
		}
	}

	// ── Dispatch Agent ──────────────────────────

	function dispatchAgent(
		agentName: string,
		task: string,
		ctx: any,
		onUpdate?: (data: any) => void,
		signal?: AbortSignal,
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

		state.activeDispatches++;
		state.runCount++;

		const startTime = Date.now();

		const model = state.def.model
			|| (ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "openrouter/google/gemini-3-flash-preview");

		const agentKey = state.def.name.toLowerCase().replace(/\s+/g, "-");
		const dispatcher = process.env.AGENT_DISPATCHER || "";
		const prefix = dispatcher ? `${dispatcher}.` : "";
		const agentSessionFile = join(sessionDir, `${prefix}${agentKey}_${state.runCount}.jsonl`);
		const isLead = state.def.role === "lead";

		const promptTmpDir = mkdtempSync(join(tmpdir(), "pi-agent-"));
		const promptFile = join(promptTmpDir, `${agentKey}.md`);
		writeFileSync(promptFile, state.def.systemPrompt, { mode: 0o600 });

		const args = [
			"--mode", "json",
			"-p",
			"--model", model,
			"--tools", state.def.tools,
			"--thinking", "off",
			"--append-system-prompt", promptFile,
			"--session", agentSessionFile,
		];

		if (isLead) {
			const extPath = resolve(join(homedir(), "dot-pi", "extensions", "orchestration", "agent-team-2.ts"));
			args.push("-e", extPath);
		} else {
			args.push("--no-extensions");
		}

		if (state.def.skills) {
			const skillsDir = join(homedir(), "dot-pi", "skills");
			for (const skill of state.def.skills.split(",").map(s => s.trim()).filter(Boolean)) {
				const skillPath = join(skillsDir, skill);
				if (existsSync(skillPath)) {
					args.push("--skill", skillPath);
				}
			}
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
		const childEnv = { ...process.env };
		if (isLead) {
			childEnv.AGENT_ROLE = "lead";
			childEnv.AGENT_TEAM = activeTeamName;
			childEnv.AGENT_DISPATCHER = agentKey;
			if (process.env.AGENT_WORKSPACE) {
				childEnv.AGENT_WORKSPACE = process.env.AGENT_WORKSPACE;
			}
		}

			const proc = spawn("pi", args, {
				stdio: ["ignore", "pipe", "pipe"],
				env: childEnv,
			});

			if (signal) {
				const killProc = () => {
					proc.kill("SIGTERM");
					setTimeout(() => { if (!proc.killed) proc.kill("SIGKILL"); }, 5000);
				};
				if (signal.aborted) killProc();
				else signal.addEventListener("abort", killProc, { once: true });
			}

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

			function cleanupPromptFile() {
				try { unlinkSync(promptFile); } catch {}
				try { rmdirSync(promptTmpDir); } catch {}
			}

			proc.on("close", (code) => {
				cleanupPromptFile();

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
				state.activeDispatches = Math.max(0, state.activeDispatches - 1);

				const doneStatus = code === 0 ? "done" : "error";
				ctx.ui.notify(
					`${displayName(state.def.name)} ${doneStatus} in ${Math.round(elapsed / 1000)}s`,
					doneStatus === "done" ? "success" : "error"
				);

				resolve({
					output: JSON.stringify(entries),
					exitCode: code ?? 1,
					elapsed,
				});
			});

			proc.on("error", (err) => {
				cleanupPromptFile();
				state.activeDispatches = Math.max(0, state.activeDispatches - 1);
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

		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			const { agent, task } = params as { agent: string; task: string };

			try {
				if (onUpdate) {
					onUpdate({
						content: [{ type: "text", text: `Dispatching to ${agent}...` }],
						details: { agent, task, status: "dispatching" },
					});
				}

				const result = await dispatchAgent(agent, task, ctx, onUpdate, signal);

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
			const switchedDef = teamDefs.get(name);
			if (switchedDef?.welcome) {
				ctx.ui.notify(switchedDef.welcome.trim(), "info");
			} else {
				ctx.ui.notify(`Team: ${name} — ${Array.from(agentStates.values()).map(s => displayName(s.def.name)).join(", ")}`, "info");
			}
		},
	});

	pi.registerCommand("agents-list", {
		description: "List all loaded agents",
		handler: async (_args, ctx) => {
			const names = Array.from(agentStates.values())
				.map(s => {
					const status = s.activeDispatches > 0 ? `running (${s.activeDispatches})` : "idle";
					return `${displayName(s.def.name)} (${status}, runs: ${s.runCount}): ${s.def.description}`;
				})
				.join("\n");
			ctx.ui.notify(names || "No agents loaded", "info");
		},
	});

	// ── System Prompt Override ───────────────────

	pi.on("before_agent_start", async (_event, _ctx) => {
		const agentRole = process.env.AGENT_ROLE || "orchestrator";

		const agentCatalog = Array.from(agentStates.values())
			.map(s => {
				const roleTag = s.def.role === "lead" ? " (lead)" : "";
				const skillsTag = s.def.skills ? `\n**Skills:** ${s.def.skills}` : "";
				return `### ${displayName(s.def.name)}${roleTag}\n**Dispatch as:** \`${s.def.name}\`\n${s.def.description}\n**Tools:** ${s.def.tools}${skillsTag}`;
			})
			.join("\n\n");

		const teamMembers = Array.from(agentStates.values()).map(s => displayName(s.def.name)).join(", ");

		const workspace = process.env.AGENT_WORKSPACE;
		const workspaceBlock = workspace
			? `\n## Workspace\n\nAll agent output for this run goes to:\n\`\`\`\n${workspace}\n\`\`\`\n`
			: "";

		const retroTarget = process.env.RETRO_TARGET;
		const retroTargetBlock = retroTarget
			? `\n## Retro Target\n\nThe workspace to analyze:\n\`\`\`\n${retroTarget}\n\`\`\`\n`
			: "";

		let topicsBlock = "";
		if (agentRole === "orchestrator" && loadedTopics.length > 0) {
			const activeTopics = loadedTopics.filter(t => t.active);
			if (activeTopics.length > 0) {
				const topicEntries = activeTopics.map(t => {
					return `### ${t.name} (slug: ${t.slug}, priority: ${t.priority})\n\`\`\`yaml\n${t.raw}\n\`\`\``;
				}).join("\n\n");
				topicsBlock = `\n## Saved Topics\n\n${topicEntries}\n`;
			}
			if (storyIndexRaw && storyIndexRaw !== "[]") {
				topicsBlock += `\n## Developing Stories (Story Index)\n\n\`\`\`yaml\n${storyIndexRaw}\n\`\`\`\n`;
			}
		}

		if (agentRole === "lead") {
			const currentPrompt = (_event as any).systemPrompt || _ctx.getSystemPrompt?.() || "";
			return {
				systemPrompt: `${currentPrompt}

## Agents Available for Dispatch

You have \`dispatch_agent\` available alongside your regular tools. Use it to delegate sub-tasks to specialist agents when isolation or specialization is needed. You can also do work directly with your own tools.

**Team:** ${activeTeamName}
${workspaceBlock}
**Do not dispatch yourself.**

${agentCatalog}`,
			};
		}

		const basePrompt = activeTeamDef?.orchestrator_prompt
			? activeTeamDef.orchestrator_prompt
			: `You are a dispatcher agent. You coordinate specialist agents to accomplish tasks.
You do NOT have direct access to the codebase. You MUST delegate all work through
agents using the dispatch_agent tool.

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
- Keep tasks focused — one clear objective per dispatch`;

		let workflowBlock = "";
		const workflowName = process.env.AGENT_WORKFLOW;
		if (workflowName && activeTeamDef?.workflows[workflowName]) {
			const wf = activeTeamDef.workflows[workflowName];
			const promptPath = resolve(join(homedir(), "dot-pi", wf.prompt_file));
			if (existsSync(promptPath)) {
				try {
					let promptContent = readFileSync(promptPath, "utf-8");
					const fmMatch = promptContent.match(/^---\n[\s\S]*?\n---\n([\s\S]*)$/);
					if (fmMatch) promptContent = fmMatch[1].trim();
					workflowBlock = `\n## Active Workflow: ${workflowName}\n\n${promptContent}\n`;
				} catch {}
			}
		}

		return {
			systemPrompt: `${basePrompt}

## Active Team: ${activeTeamName}
Members: ${teamMembers}
You can ONLY dispatch to agents listed below. Do not attempt to dispatch to agents outside this team.
${workspaceBlock}${retroTargetBlock}${topicsBlock}
## Agents

${agentCatalog}
${workflowBlock}`,
		};
	});

	// ── Session Start ────────────────────────────

	pi.on("session_start", async (_event, _ctx) => {
		setTimeout(() => _ctx.ui.setTitle("π - agent-team-2"), 150);
		contextWindow = _ctx.model?.contextWindow || 0;

		loadAgents(_ctx.cwd);
		loadTopics();

		const teamNames = Object.keys(teams);
		if (teamNames.length > 0) {
			const envTeam = process.env.AGENT_TEAM;
			const startTeam = envTeam && teamNames.includes(envTeam) ? envTeam : teamNames[0];
			activateTeam(startTeam);
		}

		const agentRole = process.env.AGENT_ROLE || "orchestrator";
		if (agentRole === "orchestrator") {
			pi.setActiveTools(["dispatch_agent"]);
		}

		_ctx.ui.setStatus("agent-team", `Team: ${activeTeamName} (${agentStates.size})`);
		const members = Array.from(agentStates.values()).map(s => displayName(s.def.name)).join(", ");

		let welcomeText: string;
		if (activeTeamDef?.welcome) {
			welcomeText = activeTeamDef.welcome.trim();
		} else {
			welcomeText = `Team: ${activeTeamName} (${members})`;
			const wfs = activeTeamDef?.workflows;
			if (wfs && Object.keys(wfs).length > 0) {
				welcomeText += "\n\nAvailable workflows:";
				for (const [name, wf] of Object.entries(wfs)) {
					welcomeText += `\n  /${name}  — ${wf.description}`;
				}
			}
		}
		welcomeText += `\n\n/agents-team          Select a team\n/agents-list          List active agents`;
		_ctx.ui.notify(welcomeText, "info");

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
