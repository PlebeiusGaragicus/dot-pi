import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

export function dotPiRoot(): string {
	if (!process.env.DOT_PI_DIR) {
		throw new Error("DOT_PI_DIR is not set; run this extension through dispatch-agent.");
	}
	return process.env.DOT_PI_DIR;
}

export function dotPiOverlay(): string {
	return process.env.DOT_PI_OVERLAY || path.join(os.homedir(), ".pi", "dot-pi");
}

export function overlayFile(name: string): string {
	return path.join(dotPiOverlay(), name);
}

export function overlayFirstFile(name: string): string {
	const overlayPath = overlayFile(name);
	if (fs.existsSync(overlayPath)) return overlayPath;
	return path.join(dotPiRoot(), name);
}

export function ensureOverlayDir(): string {
	const overlay = dotPiOverlay();
	fs.mkdirSync(overlay, { recursive: true });
	return overlay;
}

export function agentOverlayDir(agentDir: string): string {
	const root = dotPiRoot();
	const relative = path.relative(root, agentDir);
	const parts = relative.split(path.sep).filter(Boolean);
	if (parts[0] === "agents" && parts.length === 2) {
		return path.join(dotPiOverlay(), parts[1] ?? path.basename(agentDir));
	}
	if (parts[0] === "agents" && parts.length > 2) {
		return path.join(dotPiOverlay(), parts.slice(1).join(path.sep));
	}
	if (parts[0] === "subagents" && parts[1]) {
		return path.join(dotPiOverlay(), "subagents", parts[1]);
	}
	return path.join(dotPiOverlay(), path.basename(agentDir));
}

export function agentOverlayFile(agentDir: string, fileName: string): string {
	return path.join(agentOverlayDir(agentDir), fileName);
}

export function agentOverlayFirstFile(agentDir: string, fileName: string): string {
	const overlayPath = agentOverlayFile(agentDir, fileName);
	if (fs.existsSync(overlayPath)) return overlayPath;
	return path.join(agentDir, fileName);
}
