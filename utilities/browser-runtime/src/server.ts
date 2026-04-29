import * as crypto from 'crypto';
import * as fs from 'fs';
import { BrowserManager } from './browser-manager';
import { ensureStateDirs, readState, removeState, resolveConfig, writeState } from './config';
import { formatSkillList, readSkill, runSkill, testSkill } from './browser-skills';

const config = resolveConfig();
ensureStateDirs(config);

const requestedPort = Number(process.env.BROWSER_CONTROL_PORT || 0);
const idleTimeoutMs = Number(process.env.BROWSER_CONTROL_IDLE_TIMEOUT || 30 * 60 * 1000);
const token = crypto.randomUUID();
const manager = new BrowserManager(config);

let listenPort = 0;
let idleTimer: ReturnType<typeof setTimeout> | null = null;

await manager.launch();

const server = Bun.serve({
  hostname: '127.0.0.1',
  port: requestedPort,
  async fetch(req) {
    touchIdleTimer();
    const url = new URL(req.url);
    try {
      if (req.method === 'GET' && url.pathname === '/health') {
        return json({ status: 'healthy', pid: process.pid, port: listenPort });
      }
      if (url.pathname !== '/command' || req.method !== 'POST') {
        return new Response('not found', { status: 404 });
      }
      if (req.headers.get('authorization') !== `Bearer ${token}`) {
        return json({ error: 'unauthorized' }, 401);
      }
      const body = await req.json() as { command?: string; args?: string[] };
      const result = await dispatch(body.command || '', body.args || []);
      return new Response(result.endsWith('\n') ? result : `${result}\n`);
    } catch (err: any) {
      return json({ error: err?.message || String(err) }, 500);
    }
  },
});

if (!server.port) throw new Error('browser-control server did not bind a port');
listenPort = server.port;
writeState(config, {
  pid: process.pid,
  port: listenPort,
  token,
  startedAt: new Date().toISOString(),
  serverPath: import.meta.path,
});
touchIdleTimer();
console.error(`[browser-control] listening on 127.0.0.1:${listenPort}`);

process.on('SIGTERM', () => shutdown(0));
process.on('SIGINT', () => shutdown(0));

async function dispatch(command: string, args: string[]): Promise<string> {
  switch (command) {
    case 'status':
      return manager.status();
    case 'stop':
      setTimeout(() => shutdown(0), 10);
      return 'stopping browser-control daemon';
    case 'restart':
      setTimeout(() => shutdown(0), 10);
      return 'stopping browser-control daemon; next command will restart it';
    case 'goto':
      requireArgs(command, args, 1);
      return manager.goto(args[0]);
    case 'url':
      return manager.currentUrl();
    case 'text':
      return manager.text(args[0]);
    case 'html':
      return manager.html(args[0]);
    case 'links':
      return manager.links();
    case 'snapshot':
      return manager.snapshot(args.includes('-i') || args.includes('--interactive'));
    case 'click':
      requireArgs(command, args, 1);
      return manager.click(args[0]);
    case 'fill':
      requireArgs(command, args, 2);
      return manager.fill(args[0], args.slice(1).join(' '));
    case 'press':
      requireArgs(command, args, 1);
      return manager.press(args[0]);
    case 'scroll':
      return manager.scroll(args[0]);
    case 'screenshot':
      return manager.screenshot(args[0]);
    case 'tabs':
      return manager.tabsList();
    case 'newtab':
      return manager.newTab(args[0]);
    case 'closetab':
      return manager.closeTab(args[0]);
    case 'skill':
      return handleSkill(args);
    default:
      throw new Error(`Unknown command "${command}"`);
  }
}

async function handleSkill(args: string[]): Promise<string> {
  const subcommand = args[0];
  const rest = args.slice(1);
  switch (subcommand) {
    case undefined:
    case 'help':
    case '--help':
      return [
        'Usage: browser-control skill <subcommand>',
        '  list',
        '  show <name>',
        '  run <name> [args...]',
        '  test <name>',
      ].join('\n');
    case 'list':
      return formatSkillList(config);
    case 'show': {
      requireArgs('skill show', rest, 1);
      const skill = readSkill(config, rest[0]);
      if (!skill) throw new Error(`Skill "${rest[0]}" not found`);
      return fs.readFileSync(`${skill.dir}/SKILL.md`, 'utf-8');
    }
    case 'run':
      requireArgs('skill run', rest, 1);
      return runSkill(config, rest[0], rest.slice(1), listenPort, token);
    case 'test':
      requireArgs('skill test', rest, 1);
      return testSkill(config, rest[0]);
    default:
      throw new Error(`Unknown skill subcommand "${subcommand}"`);
  }
}

function requireArgs(command: string, args: string[], count: number): void {
  if (args.length < count) throw new Error(`Usage error: ${command} requires ${count} argument(s)`);
}

function touchIdleTimer(): void {
  if (idleTimer) clearTimeout(idleTimer);
  idleTimer = setTimeout(() => shutdown(0), idleTimeoutMs);
}

async function shutdown(code: number): Promise<void> {
  if (idleTimer) clearTimeout(idleTimer);
  removeState(config);
  await manager.close();
  server.stop(true);
  process.exit(code);
}

function json(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value, null, 2), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}
