import type { ChildProcess } from "node:child_process";

export interface TtsBackend {
	name: string;
	spawn(text: string, rateWpm: number, paused: boolean): ChildProcess;
}
