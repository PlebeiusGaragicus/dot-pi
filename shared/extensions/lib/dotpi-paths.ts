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

/**
 * Resolves the first existing path among `names` under **`$DOT_PI_OVERLAY`** only (in order).
 * User-owned config must not live in the Pi-managed package tree, which **`pi update`** can reset.
 * If none exist, returns the overlay path for `names[0]` (canonical write target).
 */
export function overlayFirstFile(...names: string[]): string {
	if (names.length === 0) {
		throw new Error("overlayFirstFile requires at least one filename");
	}
	for (const name of names) {
		const overlayPath = overlayFile(name);
		if (fs.existsSync(overlayPath)) return overlayPath;
	}
	return overlayFile(names[0]!);
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
	return path.join(dotPiOverlay(), path.basename(agentDir));
}

export function agentOverlayFile(agentDir: string, fileName: string): string {
	return path.join(agentOverlayDir(agentDir), fileName);
}

/**
 * Like {@link overlayFirstFile} but under the agent’s overlay directory only (no reads from `agentDir` in the clone).
 */
export function agentOverlayFirstFile(agentDir: string, ...names: string[]): string {
	if (names.length === 0) {
		throw new Error("agentOverlayFirstFile requires at least one filename");
	}
	for (const name of names) {
		const overlayPath = agentOverlayFile(agentDir, name);
		if (fs.existsSync(overlayPath)) return overlayPath;
	}
	return agentOverlayFile(agentDir, names[0]!);
}
