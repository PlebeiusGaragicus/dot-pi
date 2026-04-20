/**
 * Bash Guardrails Extension
 *
 * Blocks unsafe bash commands and file writes at the tool level using the
 * tool_call hook. Prevents agents from installing packages, writing scripts,
 * or executing arbitrary code — steering them toward pre-installed CLI tools.
 *
 * Modeled on the permission-gate.ts example extension.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

interface BlockedPattern {
	regex: RegExp;
	message: string;
}

const BLOCKED_BASH: BlockedPattern[] = [
	{
		regex: /\bnpm\s+(install|i|add|ci)\b/i,
		message: "npm install is not allowed. Use pre-installed CLI tools directly (e.g. playwright-cli, curl).",
	},
	{
		regex: /\bnpx\s+/i,
		message: "npx is not allowed. Use pre-installed CLI tools directly instead of fetching packages at runtime.",
	},
	{
		regex: /\byarn\s+(add|install)\b/i,
		message: "yarn install is not allowed. Use pre-installed CLI tools directly.",
	},
	{
		regex: /\bpnpm\s+(add|install|i)\b/i,
		message: "pnpm install is not allowed. Use pre-installed CLI tools directly.",
	},
	{
		regex: /\bpip3?\s+install\b/i,
		message: "pip install is not allowed. Use pre-installed CLI tools directly.",
	},
	{
		regex: /\bbrew\s+install\b/i,
		message: "brew install is not allowed. Use pre-installed CLI tools directly.",
	},
	{
		regex: /\bapt(-get)?\s+install\b/i,
		message: "apt install is not allowed. Use pre-installed CLI tools directly.",
	},
	{
		regex: /\bnode\s+\S+\.(m?js|ts)\b/i,
		message:
			"Running script files with node is not allowed. Use pre-installed CLI tools directly (e.g. playwright-cli for browser automation).",
	},
	{
		regex: /\bbun\s+(run|exec)\s+\S+\.(m?js|ts)\b/i,
		message: "Running script files with bun is not allowed. Use pre-installed CLI tools directly.",
	},
	{
		regex: /\bpython3?\s+\S+\.py\b/i,
		message: "Running Python scripts is not allowed. Use pre-installed CLI tools directly.",
	},
	{
		regex: /\bcurl\s+.*\|\s*(ba)?sh\b/i,
		message: "Piping downloads to a shell is not allowed. Use pre-installed CLI tools directly.",
	},
	{
		regex: /\bwget\s+.*\|\s*(ba)?sh\b/i,
		message: "Piping downloads to a shell is not allowed. Use pre-installed CLI tools directly.",
	},
];

const BLOCKED_WRITE_EXTENSIONS = [".mjs", ".cjs", ".js", ".ts", ".py", ".sh", ".bash", ".rb", ".pl"];

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event) => {
		if (event.toolName === "bash") {
			const command = event.input.command as string;
			if (!command) return undefined;

			const match = BLOCKED_BASH.find((p) => p.regex.test(command));
			if (match) {
				return { block: true, reason: match.message };
			}
		}

		if (event.toolName === "write") {
			const filePath = (event.input.file_path || event.input.path) as string;
			if (!filePath) return undefined;

			const blocked = BLOCKED_WRITE_EXTENSIONS.find((ext) => filePath.endsWith(ext));
			if (blocked) {
				return {
					block: true,
					reason: `Writing ${blocked} files is not allowed. Use pre-installed CLI tools directly instead of writing scripts.`,
				};
			}
		}

		return undefined;
	});
}
