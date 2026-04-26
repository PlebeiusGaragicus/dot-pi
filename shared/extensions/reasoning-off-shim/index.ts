/**
 * Reasoning Off Shim
 *
 * Some OpenAI-compatible chat-completions backends treat a missing
 * reasoning_effort as "use the server default" instead of "disable reasoning".
 * When Pi's thinking level is off, pi-agent-core omits reasoning controls, so
 * this shim makes that disable request explicit for affected backends.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

type ProviderPayload = Record<string, unknown>;

const REASONING_CONTROL_FIELDS = [
	"reasoning_effort",
	"reasoning",
	"thinking",
	"enable_thinking",
	"chat_template_kwargs",
] as const;

function isObject(value: unknown): value is ProviderPayload {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isChatCompletionsPayload(payload: ProviderPayload): boolean {
	return typeof payload.model === "string" && Array.isArray(payload.messages);
}

function hasReasoningControl(payload: ProviderPayload): boolean {
	return REASONING_CONTROL_FIELDS.some((field) => Object.prototype.hasOwnProperty.call(payload, field));
}

export default function reasoningOffShim(pi: ExtensionAPI): void {
	pi.on("before_provider_request", async (event) => {
		const payload = event.payload;
		if (!isObject(payload)) return;
		if (!isChatCompletionsPayload(payload)) return;
		if (hasReasoningControl(payload)) return;

		return {
			...payload,
			reasoning_effort: "none",
		};
	});
}
