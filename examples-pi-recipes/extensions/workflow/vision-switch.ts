/**
 * Vision Switch — Auto-swap to a vision model when reading images
 *
 * When the agent reads an image file (.png, .jpg, etc.) and the current
 * model doesn't support image input, this extension temporarily switches
 * to a vision-capable model for that turn, then restores the original
 * model afterward.
 *
 * LM Studio (and many OpenAI-compatible servers) don't support image
 * content blocks inside tool_result messages. This extension works around
 * that by stripping images from tool results and re-injecting them as
 * user messages via the context event — which all APIs support.
 *
 * Usage: pi -e extensions/workflow/vision-switch.ts
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { isToolCallEventType } from "@mariozechner/pi-coding-agent";

const VISION_MODEL = { provider: "plebchat", id: "deepseek-ocr-mlx" };
const IMAGE_EXTS = [".png", ".jpg", ".jpeg", ".gif", ".webp"];

function isImagePath(path: string): boolean {
	const lower = path.toLowerCase();
	return IMAGE_EXTS.some((ext) => lower.endsWith(ext));
}

interface SavedImage {
	data: string;
	mimeType: string;
}

export default function (pi: ExtensionAPI) {
	let savedModel: any | undefined;
	let awaitingVisionResponse = false;
	let pendingImages: SavedImage[] = [];
	let lastImagePath = "";

	pi.on("tool_call", async (event, ctx) => {
		if (!isToolCallEventType("read", event)) return;
		if (!isImagePath(event.input.path)) return;

		const currentModel = ctx.model;
		if (!currentModel) return;

		const supportsImages = Array.isArray((currentModel as any).input)
			&& (currentModel as any).input.includes("image");
		if (supportsImages) return;

		if (savedModel) return;

		const visionModel = ctx.modelRegistry.find(VISION_MODEL.provider, VISION_MODEL.id);
		if (!visionModel) {
			if (ctx.hasUI) {
				ctx.ui.notify(`Vision model ${VISION_MODEL.provider}/${VISION_MODEL.id} not found`, "warning");
			}
			return;
		}

		savedModel = currentModel;
		awaitingVisionResponse = true;
		lastImagePath = event.input.path;
		const success = await pi.setModel(visionModel);
		if (success && ctx.hasUI) {
			ctx.ui.notify(`Switched to vision model for image processing`, "info");
		}
	});

	// Strip image blocks from tool results so providers that don't support
	// multimodal tool_result won't 400. Save the image data so we can
	// re-inject it as a user message in the context event.
	pi.on("tool_result", async (event) => {
		if (event.toolName !== "read") return;
		if (!Array.isArray(event.content)) return;

		const imageBlocks = event.content.filter((b: any) => b.type === "image");
		if (!imageBlocks.length) return;

		pendingImages = imageBlocks.map((b: any) => ({
			data: b.data,
			mimeType: b.mimeType,
		}));

		const filtered = event.content
			.filter((b: any) => b.type !== "image")
			.concat({
				type: "text" as const,
				text: `[Image read from ${lastImagePath} — content provided below for vision analysis]`,
			});

		return { content: filtered };
	});

	// Before each LLM call, if we have pending images, inject them as a
	// user message. Images in user messages are supported by all APIs,
	// unlike images in tool_result blocks.
	pi.on("context", async (event) => {
		if (!pendingImages.length) return;

		const images = pendingImages;
		pendingImages = [];

		const imageContent: any[] = images.map((img) => ({
			type: "image",
			data: img.data,
			mimeType: img.mimeType,
		}));

		imageContent.push({
			type: "text",
			text: `Analyze the image${images.length > 1 ? "s" : ""} above (read from ${lastImagePath}).`,
		});

		const newMessages = [...event.messages];
		newMessages.push({
			role: "user",
			content: imageContent,
			timestamp: Date.now(),
		} as any);

		return { messages: newMessages };
	});

	pi.on("turn_end", async (_event, _ctx) => {
		if (!savedModel) return;

		if (awaitingVisionResponse) {
			awaitingVisionResponse = false;
			return;
		}

		const restored = await pi.setModel(savedModel);
		if (restored && _ctx.hasUI) {
			_ctx.ui.notify(`Restored ${(savedModel as any).id}`, "info");
		}
		savedModel = undefined;
	});
}
