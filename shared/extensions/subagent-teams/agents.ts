/**
 * Agent discovery and configuration with team support.
 *
 * Teams are derived from the filename convention: `team-agentname.md`
 * (the first `-` separates team from agent name).
 * A `team` field in frontmatter overrides the filename-derived team.
 * Files without a `-` in the name have no team (visible to all).
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { getAgentDir, parseFrontmatter } from "@mariozechner/pi-coding-agent";

export type AgentScope = "user" | "project" | "both";

export interface AgentConfig {
	name: string;
	description: string;
	team?: string;
	tools?: string[];
	skills?: string[];
	noSkills?: boolean;
	model?: string;
	systemPrompt: string;
	source: "user" | "project";
	filePath: string;
}

export interface AgentDiscoveryResult {
	agents: AgentConfig[];
	projectAgentsDir: string | null;
}

/**
 * Parse team and agent name from a filename.
 * `recon-scout.md` -> { team: "recon", agentName: "scout" }
 * `scout.md` -> { team: undefined, agentName: "scout" }
 */
function parseFilenameTeam(filename: string): { team: string | undefined; agentName: string } {
	const base = filename.replace(/\.md$/, "");
	const idx = base.indexOf("-");
	if (idx === -1 || idx === 0 || idx === base.length - 1) {
		return { team: undefined, agentName: base };
	}
	return { team: base.slice(0, idx), agentName: base.slice(idx + 1) };
}

function loadAgentsFromDir(dir: string, source: "user" | "project"): AgentConfig[] {
	const agents: AgentConfig[] = [];

	if (!fs.existsSync(dir)) {
		return agents;
	}

	let entries: fs.Dirent[];
	try {
		entries = fs.readdirSync(dir, { withFileTypes: true });
	} catch {
		return agents;
	}

	for (const entry of entries) {
		if (!entry.name.endsWith(".md")) continue;
		if (!entry.isFile() && !entry.isSymbolicLink()) continue;

		const filePath = path.join(dir, entry.name);
		let content: string;
		try {
			content = fs.readFileSync(filePath, "utf-8");
		} catch {
			continue;
		}

		const { frontmatter, body } = parseFrontmatter<Record<string, string>>(content);

		if (!frontmatter.description) {
			continue;
		}

		const { team: filenameTeam, agentName: filenameAgentName } = parseFilenameTeam(entry.name);

		const name = frontmatter.name || filenameAgentName;
		const team = frontmatter.team || filenameTeam;

		const tools = frontmatter.tools
			?.split(",")
			.map((t: string) => t.trim())
			.filter(Boolean);

		const skills = frontmatter.skills
			?.split(",")
			.map((s: string) => s.trim())
			.filter(Boolean);

		const noSkills = frontmatter["no-skills"] === "true" || frontmatter["no-skills"] === true;

		agents.push({
			name,
			description: frontmatter.description,
			team,
			tools: tools && tools.length > 0 ? tools : undefined,
			skills: skills && skills.length > 0 ? skills : undefined,
			noSkills: noSkills || undefined,
			model: frontmatter.model,
			systemPrompt: body,
			source,
			filePath,
		});
	}

	return agents;
}

function isDirectory(p: string): boolean {
	try {
		return fs.statSync(p).isDirectory();
	} catch {
		return false;
	}
}

function findNearestProjectAgentsDir(cwd: string): string | null {
	let currentDir = cwd;
	while (true) {
		const candidate = path.join(currentDir, ".pi", "agents");
		if (isDirectory(candidate)) return candidate;

		const parentDir = path.dirname(currentDir);
		if (parentDir === currentDir) return null;
		currentDir = parentDir;
	}
}

export interface DiscoverAgentsOptions {
	cwd: string;
	scope: AgentScope;
	team?: string;
}

export function discoverAgents(options: DiscoverAgentsOptions): AgentDiscoveryResult {
	const { cwd, scope, team } = options;
	const userDir = path.join(getAgentDir(), "agents");
	const projectAgentsDir = findNearestProjectAgentsDir(cwd);

	const userAgents = scope === "project" ? [] : loadAgentsFromDir(userDir, "user");
	const projectAgents = scope === "user" || !projectAgentsDir ? [] : loadAgentsFromDir(projectAgentsDir, "project");

	const agentMap = new Map<string, AgentConfig>();

	if (scope === "both") {
		for (const agent of userAgents) agentMap.set(agent.name, agent);
		for (const agent of projectAgents) agentMap.set(agent.name, agent);
	} else if (scope === "user") {
		for (const agent of userAgents) agentMap.set(agent.name, agent);
	} else {
		for (const agent of projectAgents) agentMap.set(agent.name, agent);
	}

	let agents = Array.from(agentMap.values());

	if (team) {
		agents = agents.filter((a) => a.team === team);
	}

	return { agents, projectAgentsDir };
}

export function getAvailableTeams(options: { cwd: string; scope: AgentScope }): string[] {
	const result = discoverAgents({ ...options });
	const teams = new Set<string>();
	for (const agent of result.agents) {
		if (agent.team) teams.add(agent.team);
	}
	return Array.from(teams).sort();
}

export function formatAgentList(agents: AgentConfig[], maxItems: number): { text: string; remaining: number } {
	if (agents.length === 0) return { text: "none", remaining: 0 };
	const listed = agents.slice(0, maxItems);
	const remaining = agents.length - listed.length;
	return {
		text: listed.map((a) => `${a.name}${a.team ? ` [${a.team}]` : ""} (${a.source}): ${a.description}`).join("; "),
		remaining,
	};
}
