import * as fs from 'fs';
import * as path from 'path';
import * as cp from 'child_process';

export interface RuntimeConfig {
  projectRoot: string;
  stateDir: string;
  stateFile: string;
  screenshotsDir: string;
}

export interface ServerState {
  pid: number;
  port: number;
  token: string;
  startedAt: string;
  serverPath: string;
}

function resolveGitRoot(cwd: string): string | null {
  try {
    const proc = cp.spawnSync('git', ['rev-parse', '--show-toplevel'], {
      cwd,
      encoding: 'utf-8',
      timeout: 2000,
    });
    if (proc.status === 0) {
      const root = proc.stdout.trim();
      if (root) return root;
    }
  } catch {
    // Fall back to cwd below.
  }
  return null;
}

export function resolveProjectRoot(cwd = process.cwd()): string {
  return resolveGitRoot(cwd) ?? cwd;
}

export function resolveConfig(cwd = process.cwd()): RuntimeConfig {
  const projectRoot = resolveProjectRoot(cwd);
  const stateDir = process.env.BROWSER_CONTROL_STATE_DIR
    ? path.resolve(process.env.BROWSER_CONTROL_STATE_DIR)
    : path.join(projectRoot, '.browser-control');
  return {
    projectRoot,
    stateDir,
    stateFile: process.env.BROWSER_CONTROL_STATE_FILE
      ? path.resolve(process.env.BROWSER_CONTROL_STATE_FILE)
      : path.join(stateDir, 'browse.json'),
    screenshotsDir: path.join(stateDir, 'screenshots'),
  };
}

export function ensureStateDirs(config: RuntimeConfig): void {
  fs.mkdirSync(config.stateDir, { recursive: true, mode: 0o700 });
  fs.mkdirSync(config.screenshotsDir, { recursive: true, mode: 0o700 });
}

export function readState(config: RuntimeConfig): ServerState | null {
  try {
    return JSON.parse(fs.readFileSync(config.stateFile, 'utf-8')) as ServerState;
  } catch {
    return null;
  }
}

export function writeState(config: RuntimeConfig, state: ServerState): void {
  ensureStateDirs(config);
  const tmp = `${config.stateFile}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(state, null, 2), { mode: 0o600 });
  fs.renameSync(tmp, config.stateFile);
}

export function removeState(config: RuntimeConfig): void {
  try {
    fs.unlinkSync(config.stateFile);
  } catch (err: any) {
    if (err?.code !== 'ENOENT') throw err;
  }
}

export function isPathWithin(child: string, parent: string): boolean {
  const rel = path.relative(path.resolve(parent), path.resolve(child));
  return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel));
}

export function validateOutputPath(rawPath: string, config: RuntimeConfig): string {
  const resolved = path.resolve(config.projectRoot, rawPath);
  const tmp = path.resolve(process.env.TMPDIR || '/tmp');
  if (!isPathWithin(resolved, config.projectRoot) && !isPathWithin(resolved, tmp)) {
    throw new Error(`Refusing to write outside project root or temp dir: ${rawPath}`);
  }
  fs.mkdirSync(path.dirname(resolved), { recursive: true });
  return resolved;
}
