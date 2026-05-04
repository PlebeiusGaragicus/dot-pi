import * as fs from 'fs';
import * as path from 'path';
import * as cp from 'child_process';

export interface BrowseClientOptions {
  port?: number;
  token?: string;
  stateFile?: string;
  timeoutMs?: number;
}

interface Auth {
  port: number;
  token: string;
}

export function resolveAuth(opts: BrowseClientOptions = {}): Auth {
  const envPort = process.env.BROWSER_CONTROL_PORT;
  const envToken = process.env.BROWSER_CONTROL_TOKEN;
  if ((opts.port || envPort) && (opts.token || envToken)) {
    return {
      port: opts.port ?? Number(envPort),
      token: opts.token ?? envToken!,
    };
  }

  const stateFile = opts.stateFile ?? process.env.BROWSER_CONTROL_STATE_FILE ?? defaultStateFile();
  const state = JSON.parse(fs.readFileSync(stateFile, 'utf-8'));
  return { port: opts.port ?? state.port, token: opts.token ?? state.token };
}

export class BrowseClient {
  private readonly port: number;
  private readonly token: string;
  private readonly timeoutMs: number;

  constructor(opts: BrowseClientOptions = {}) {
    const auth = resolveAuth(opts);
    this.port = auth.port;
    this.token = auth.token;
    this.timeoutMs = opts.timeoutMs ?? 30_000;
  }

  async command(command: string, args: string[] = []): Promise<string> {
    const resp = await fetch(`http://127.0.0.1:${this.port}/command`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${this.token}`,
      },
      body: JSON.stringify({ command, args }),
      signal: AbortSignal.timeout(this.timeoutMs),
    });
    const text = await resp.text();
    if (!resp.ok) throw new Error(text);
    return text.trim();
  }

  goto(url: string): Promise<string> { return this.command('goto', [url]); }
  text(selector?: string): Promise<string> { return this.command('text', selector ? [selector] : []); }
  html(selector?: string): Promise<string> { return this.command('html', selector ? [selector] : []); }
  links(): Promise<string> { return this.command('links'); }
  snapshot(interactive = false): Promise<string> { return this.command('snapshot', interactive ? ['-i'] : []); }
  click(selector: string): Promise<string> { return this.command('click', [selector]); }
  fill(selector: string, value: string): Promise<string> { return this.command('fill', [selector, value]); }
  press(key: string): Promise<string> { return this.command('press', [key]); }
  screenshot(path?: string): Promise<string> { return this.command('screenshot', path ? [path] : []); }
}

export const browse = new BrowseClient();

function defaultStateFile(): string {
  try {
    const proc = cp.spawnSync('git', ['rev-parse', '--show-toplevel'], {
      encoding: 'utf-8',
      timeout: 2000,
    });
    const root = proc.status === 0 ? proc.stdout.trim() : process.cwd();
    return path.join(root, '.browser-control', 'browse.json');
  } catch {
    return path.join(process.cwd(), '.browser-control', 'browse.json');
  }
}
