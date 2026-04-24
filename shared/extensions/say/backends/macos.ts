import type { TtsBackend } from "./types.js";
import { spawn } from "node:child_process";

const backend: TtsBackend | null =
	process.platform === "darwin"
		? {
				name: "macos-say",
				spawn(text: string, rateWpm: number, paused: boolean) {
					const child = spawn("say", ["-r", String(rateWpm), "-f", "-"], {
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
