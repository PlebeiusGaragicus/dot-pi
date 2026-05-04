#!/usr/bin/env bun
import * as fs from 'fs';
import * as path from 'path';
import { readState, removeState, resolveConfig, type ServerState } from './config';

const config = resolveConfig();
const maxStartWaitMs = process.env.CI ? 30_000 : 8_000;

async function main(): Promise<void> {
  const [command, ...args] = process.argv.slice(2);
  if (!command || command === 'help' || command === '--help' || command === '-h') {
    printHelp();
    return;
  }

  let state = readState(config);
  if (!state || !(await isHealthy(state))) {
    if (state) removeState(config);
    await startServer();
    state = readState(config);
  }
  if (!state) throw new Error('browser-control daemon did not write a state file');

  const resp = await fetch(`http://127.0.0.1:${state.port}/command`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${state.token}`,
    },
    body: JSON.stringify({ command, args }),
  });
  const text = await resp.text();
  if (!resp.ok) {
    process.stderr.write(text);
    process.exit(1);
  }
  process.stdout.write(text);
}

async function isHealthy(state: ServerState): Promise<boolean> {
  try {
    const resp = await fetch(`http://127.0.0.1:${state.port}/health`, {
      signal: AbortSignal.timeout(1500),
    });
    if (!resp.ok) return false;
    const body = await resp.json() as { status?: string };
    return body.status === 'healthy';
  } catch {
    return false;
  }
}

async function startServer(): Promise<void> {
  const serverScript = resolveServerScript();
  fs.mkdirSync(config.stateDir, { recursive: true, mode: 0o700 });
  const logFile = path.join(config.stateDir, 'daemon.log');
  const proc = Bun.spawn(['bun', 'run', serverScript], {
    cwd: config.projectRoot,
    env: {
      ...process.env,
      BROWSER_CONTROL_STATE_FILE: config.stateFile,
      BROWSER_CONTROL_STATE_DIR: config.stateDir,
    },
    stdout: Bun.file(logFile),
    stderr: Bun.file(logFile),
  });
  proc.unref();

  const deadline = Date.now() + maxStartWaitMs;
  while (Date.now() < deadline) {
    const state = readState(config);
    if (state && await isHealthy(state)) return;
    await Bun.sleep(100);
  }
  throw new Error(`Timed out waiting for browser-control daemon. See ${logFile}`);
}

function resolveServerScript(): string {
  if (process.env.BROWSER_CONTROL_SERVER_SCRIPT) {
    return path.resolve(process.env.BROWSER_CONTROL_SERVER_SCRIPT);
  }
  const dev = path.resolve(import.meta.dir, 'server.ts');
  if (fs.existsSync(dev)) return dev;
  const compiledAdjacent = path.resolve(path.dirname(process.execPath), '..', 'src', 'server.ts');
  if (fs.existsSync(compiledAdjacent)) return compiledAdjacent;
  throw new Error('Cannot find server.ts; set BROWSER_CONTROL_SERVER_SCRIPT');
}

function printHelp(): void {
  process.stdout.write(`browser-control — persistent Playwright Chromium for dot-pi

Usage:
  browser-control goto <url>
  browser-control snapshot [-i]
  browser-control click <@e-ref|css>
  browser-control fill <@e-ref|css> <text>
  browser-control text [css]
  browser-control screenshot [path]
  browser-control skill list|show|run|test ...
  browser-control status|stop|restart

State:
  ${config.stateFile}
`);
}

main().catch((err) => {
  process.stderr.write(`${err?.message || String(err)}\n`);
  process.exit(1);
});
