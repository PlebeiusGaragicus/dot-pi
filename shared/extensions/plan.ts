/**
 * Plan mode — read-only exploration with human-in-the-loop approval.
 *
 * /plan toggles plan mode. During planning the agent can only use read, grep,
 * find, and ls. The agent drafts a plan in its response and calls plan_submit
 * to request approval. The user chooses: approve (compact + implement), revise
 * (typed feedback), or stop.
 */

import { type ExtensionAPI, getMarkdownTheme } from "@mariozechner/pi-coding-agent";
import { Container, Markdown, Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";

const PLAN_SUBMIT = "plan_submit";
const PLANNING_TOOLS = new Set(["read", "grep", "find", "ls", PLAN_SUBMIT]);
const BLOCKED_TOOLS = new Set(["write", "edit", "bash"]);

function notifySystem(title: string, body: string): void {
	if (process.stdout.isTTY) {
		process.stdout.write(`\x1b]777;notify;${title};${body}\x07`);
	}
}

export default function plan(pi: ExtensionAPI): void {
	let phase: "idle" | "planning" = "idle";
	let savedTools: string[] = [];

	function enterPlanning(ctx: { ui: { setStatus: (k: string, v: string | undefined) => void; notify: (m: string, t?: string) => void }; hasUI: boolean }, theme: { fg: (c: string, t: string) => string }) {
		savedTools = pi.getActiveTools();
		phase = "planning";
		const tools = [...new Set([...savedTools.filter((t) => !BLOCKED_TOOLS.has(t)), PLAN_SUBMIT])];
		pi.setActiveTools(tools);
		ctx.ui.setStatus("plan", theme.fg("warning", "PLAN"));
		ctx.ui.notify("Plan mode enabled. Read-only tools + plan_submit.");
	}

	function exitToIdle(ctx: { ui: { setStatus: (k: string, v: string | undefined) => void; notify: (m: string, t?: string) => void } }) {
		phase = "idle";
		pi.setActiveTools(savedTools);
		savedTools = [];
		ctx.ui.setStatus("plan", undefined);
		ctx.ui.notify("Plan mode disabled. Full tool access restored.");
	}

	pi.registerCommand("plan", {
		description: "Toggle plan mode (read-only exploration + plan approval)",
		handler: async (_args, ctx) => {
			if (phase === "planning") {
				exitToIdle(ctx);
			} else {
				enterPlanning(ctx, ctx.ui.theme);
			}
		},
	});

	pi.registerTool({
		name: PLAN_SUBMIT,
		label: "Submit Plan",
		description:
			"Submit your plan for user review. " +
			"Pass the full plan text in the 'plan' parameter. " +
			"The user will approve, request revisions, or stop planning.",
		parameters: Type.Object({
			plan: Type.String({ description: "The full implementation plan" }),
		}) as any,

		renderCall(args, theme) {
			const container = new Container();
			container.addChild(new Text(theme.fg("toolTitle", theme.bold("Submit Plan"))));
			container.addChild(new Markdown(args.plan, 0, 0, getMarkdownTheme()));
			return container;
		},

		async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
			if (phase !== "planning") {
				return {
					content: [{ type: "text", text: "Error: not in plan mode. Use /plan first." }],
				};
			}

			if (!ctx.hasUI) {
				exitToIdle(ctx);
				ctx.compact();
				return {
					content: [{ type: "text", text: "Plan auto-approved (non-interactive). Context compacted. Proceed with implementation." }],
				};
			}

			notifySystem("Plan Review", "A plan is ready for your review");

			const choice = await ctx.ui.select("Plan Review", [
				"Approve and implement",
				"Revise plan",
				"Stop planning",
			]);

			if (choice === "Approve and implement") {
				exitToIdle(ctx);
				ctx.compact();
				return {
					content: [{ type: "text", text: "Plan approved. Context compacted. Proceed with implementation." }],
				};
			}

			if (choice === "Revise plan") {
				const feedback = await ctx.ui.input("What should change?");
				if (!feedback) {
					return {
						content: [{ type: "text", text: "No feedback provided. Revise your plan and call plan_submit again." }],
					};
				}
				return {
					content: [{ type: "text", text: `User feedback:\n\n${feedback}\n\nRevise your plan accordingly, then call plan_submit again.` }],
				};
			}

			// "Stop planning" or cancelled
			exitToIdle(ctx);
			return {
				content: [{ type: "text", text: "Planning cancelled. Full tool access restored." }],
			};
		},
	});

	// Block write, edit, bash during planning
	pi.on("tool_call", async (event) => {
		if (phase !== "planning") return;
		if (BLOCKED_TOOLS.has(event.toolName)) {
			return {
				block: true,
				reason: `Blocked during plan mode. Only read, grep, find, ls are available. Use /plan to exit plan mode.`,
			};
		}
	});

	// Inject planning instructions
	pi.on("before_agent_start", async () => {
		if (phase !== "planning") return;
		return {
			message: {
				customType: "plan-context",
				content: `PLAN MODE ACTIVE.

Constraints:
- Read-only tools only: read, grep, find, ls. write/edit/bash are blocked.
- Do NOT write the plan as a chat reply. The plan body MUST be passed as the \`plan\` parameter to the ${PLAN_SUBMIT} tool. The user only sees what is inside that parameter, rendered as markdown.
- Do not narrate "let me check" / "now I will" between tool calls.

Each turn ends with EITHER:
  (a) a question to the user (only for things the code cannot answer), OR
  (b) a ${PLAN_SUBMIT} tool call.

The \`plan\` parameter must be markdown with these sections:
  ## Context
  ## Approach
  ## Files to change
  ## Steps
  ## Verification

When the user denies and provides feedback, revise the plan and call ${PLAN_SUBMIT} again. Do not rewrite from scratch unless asked.`,
				display: false,
			},
		};
	});

	// Strip stale plan-context messages when idle
	pi.on("context", async (event) => {
		if (phase !== "idle") return;
		return {
			messages: event.messages.filter((m) => {
				const msg = m as { customType?: string; role?: string; content?: unknown };
				if (msg.customType === "plan-context") return false;
				if (msg.role !== "user") return true;
				const content = msg.content;
				if (typeof content === "string") return !content.includes("[PLAN MODE]");
				if (Array.isArray(content)) {
					return !content.some(
						(c) => c.type === "text" && (c as { text?: string }).text?.includes("[PLAN MODE]"),
					);
				}
				return true;
			}),
		};
	});

	// Strip plan_submit from tools on fresh idle sessions
	pi.on("session_start", async () => {
		if (phase === "idle") {
			const tools = pi.getActiveTools().filter((t) => t !== PLAN_SUBMIT);
			pi.setActiveTools(tools);
		}
	});
}
