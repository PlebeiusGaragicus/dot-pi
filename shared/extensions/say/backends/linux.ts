import type { TtsBackend } from "./types.js";
import { spawn, spawnSync } from "node:child_process";

function hasEspeakNg(): boolean {
	try {
		return spawnSync("which", ["espeak-ng"], { stdio: "ignore" }).status === 0;
	} catch {
		return false;
	}
}

const backend: TtsBackend | null =
	process.platform === "linux" && hasEspeakNg()
		? {
				name: "linux-espeak-ng",
				spawn(text: string, rateWpm: number, paused: boolean) {
					const child = spawn("espeak-ng", ["-s", String(rateWpm), "-f", "-"], {
						stdio: ["pipe", "ignore", "inherit"],
					});
					try {
						child.stdin?.end(text);
					} catch {
						/* child may have died before we could write */
					}
					if (paused) {
						try {
							child.kill("SIGSTOP");
						} catch {
							/* ignore */
						}
					}
					return child;
				},
			}
		: null;

export default backend;
