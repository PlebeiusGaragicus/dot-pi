/**
 * Agent discovery and configuration
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { getAgentDir } from "@mariozechner/pi-coding-agent";

export type AgentScope = "user" | "project" | "both";

export interface AgentConfig {
	name: string;
	description: string;
	usage?: string;
	resourcePool: string;
	source: "user" | "project";
	dir: string;
	linkPath: string;
}

export interface AgentDiscoveryResult {
	agents: AgentConfig[];
	projectAgentsDir: string | null;
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
		if (!entry.isDirectory() && !entry.isSymbolicLink()) continue;

		const linkPath = path.join(dir, entry.name);
		let resolvedDir: string;
		try {
			resolvedDir = fs.realpathSync(linkPath);
		} catch {
			continue;
		}

		if (!isDirectory(resolvedDir)) {
			continue;
		}

		const hasSystem = fs.existsSync(path.join(resolvedDir, "SYSTEM.md"));
		const hasAppendSystem = fs.existsSync(path.join(resolvedDir, "APPEND_SYSTEM.md"));
		if (!hasSystem && !hasAppendSystem) continue;

		agents.push({
			name: entry.name,
			description: readDescription(resolvedDir, entry.name),
			usage: readUsage(resolvedDir),
			resourcePool: readResourcePool(resolvedDir),
			source,
			dir: resolvedDir,
			linkPath,
		});
	}

	return agents;
}

function readDescription(dir: string, fallbackName: string): string {
	const readme = path.join(dir, "README.md");
	if (!fs.existsSync(readme)) return fallbackName;

	try {
		const lines = fs.readFileSync(readme, "utf-8").split(/\r?\n/);
		for (const rawLine of lines) {
			const line = rawLine.trim();
			if (!line) continue;
			if (line.startsWith("#")) continue;
			if (line.startsWith("Source:")) continue;
			if (line.startsWith("This subagent config")) continue;
			return line;
		}
	} catch {
		/* ignore */
	}

	return fallbackName;
}

function readUsage(dir: string): string | undefined {
	const usagePath = path.join(dir, "USAGE.md");
	if (!fs.existsSync(usagePath)) return undefined;

	try {
		const usage = fs.readFileSync(usagePath, "utf-8").trim();
		return usage || undefined;
	} catch {
		return undefined;
	}
}

function readResourcePool(dir: string): string {
	const poolPath = path.join(dir, "resource-pool.conf");
	if (!fs.existsSync(poolPath)) return "local";

	try {
		const lines = fs.readFileSync(poolPath, "utf-8").split(/\r?\n/);
		for (const rawLine of lines) {
			const line = rawLine.trim();
			if (!line || line.startsWith("#")) continue;
			return line.replace(/[^A-Za-z0-9_.-]/g, "") || "local";
		}
	} catch {
		return "local";
	}

	return "local";
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

export function discoverAgents(cwd: string, scope: AgentScope): AgentDiscoveryResult {
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

	return { agents: Array.from(agentMap.values()), projectAgentsDir };
}

export function formatAgentList(agents: AgentConfig[], maxItems: number): { text: string; remaining: number } {
	if (agents.length === 0) return { text: "none", remaining: 0 };
	const listed = agents.slice(0, maxItems);
	const remaining = agents.length - listed.length;
	return {
		text: listed.map((a) => `${a.name} (${a.source}, ${a.resourcePool}): ${a.description}`).join("; "),
		remaining,
	};
}
