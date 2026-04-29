import fs from "node:fs";
import path from "node:path";
import process from "node:process";

export const API_BASE = "https://api.exa.ai";

export function findDotPiRoot() {
	let dir = process.cwd();
	for (let i = 0; i < 8; i++) {
		if (fs.existsSync(path.join(dir, "env.sh"))) return dir;
		const parent = path.dirname(dir);
		if (parent === dir) break;
		dir = parent;
	}

	let scriptDir = path.dirname(new URL(import.meta.url).pathname);
	for (let i = 0; i < 8; i++) {
		if (fs.existsSync(path.join(scriptDir, "env.sh"))) return scriptDir;
		const parent = path.dirname(scriptDir);
		if (parent === scriptDir) break;
		scriptDir = parent;
	}

	return process.cwd();
}

export function loadExaKey() {
	const envKey = process.env.EXA_API_KEY?.trim();
	if (envKey && envKey !== "$EXA_API_KEY") return envKey;

	const keyPath = path.join(findDotPiRoot(), ".exa");
	if (!fs.existsSync(keyPath)) return null;

	const content = fs.readFileSync(keyPath, "utf8").trim();
	const match = content.match(/^(?:EXA_API_KEY\s*=\s*)?(.+)$/m);
	return match?.[1]?.trim() || null;
}

export function requireExaKey() {
	const apiKey = loadExaKey();
	if (apiKey) return apiKey;

	console.error("Error: Exa API key is not configured.");
	console.error("Run /exa-api-key, export EXA_API_KEY, or create repo-root .exa with EXA_API_KEY=<key>.");
	console.error("Get your key from: https://dashboard.exa.ai/api-keys");
	process.exit(1);
}

export function readOption(args, index, optionName) {
	const value = args[index + 1];
	if (!value || value.startsWith("--")) {
		throw new Error(`Missing value for ${optionName}`);
	}
	return value;
}

export function parseNum(value, fallback = 10, max = 10) {
	const parsed = Number.parseInt(value, 10);
	if (!Number.isFinite(parsed) || parsed < 1) return fallback;
	return Math.min(max, parsed);
}

export async function postExa(endpoint, body) {
	const response = await fetch(`${API_BASE}${endpoint}`, {
		method: "POST",
		headers: {
			"Content-Type": "application/json",
			"x-api-key": requireExaKey(),
		},
		body: JSON.stringify(body),
	});

	const text = await response.text();
	let data = null;
	if (text) {
		try {
			data = JSON.parse(text);
		} catch {
			data = { error: text };
		}
	}

	if (!response.ok) {
		const message = data?.error || data?.message || JSON.stringify(data) || "(no response body)";
		throw new Error(`Exa API request failed (HTTP ${response.status}): ${message}`);
	}

	return data ?? {};
}

export function printResultList(results, label = "results") {
	if (!results?.length) {
		console.log(`No ${label} found`);
		return;
	}

	console.log(`Found ${results.length} ${label}:\n`);
	results.forEach((result, index) => {
		console.log(`${index + 1}. ${result.title || "(untitled)"}`);
		console.log(`   URL: ${result.url || result.id || "(no url)"}`);
		if (result.publishedDate) console.log(`   Published: ${result.publishedDate}`);
		if (result.author) console.log(`   Author: ${result.author}`);
		if (typeof result.score === "number") console.log(`   Score: ${result.score.toFixed(3)}`);
		if (result.highlights?.length) {
			console.log("   Highlights:");
			for (const highlight of result.highlights.slice(0, 3)) {
				console.log(`   - ${highlight}`);
			}
		}
		console.log();
	});
}
