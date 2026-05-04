import * as fs from 'fs';
import * as path from 'path';
import { spawnSync } from 'child_process';
import type { RuntimeConfig } from './config';

export interface BrowserSkill {
  name: string;
  tier: 'project' | 'global' | 'bundled';
  dir: string;
  description: string;
  host: string;
}

interface SkillTiers {
  project: string;
  global: string;
  bundled: string;
}

export function skillTiers(config: RuntimeConfig): SkillTiers {
  return {
    project: path.join(config.stateDir, 'browser-skills'),
    global: path.join(process.env.HOME || '', '.dot-pi', 'browser-skills'),
    bundled: path.resolve(import.meta.dir, '..', 'browser-skills'),
  };
}

export function listSkills(config: RuntimeConfig): BrowserSkill[] {
  const tiers = skillTiers(config);
  const seen = new Set<string>();
  const out: BrowserSkill[] = [];
  for (const tier of ['project', 'global', 'bundled'] as const) {
    const root = tiers[tier];
    if (!fs.existsSync(root)) continue;
    for (const name of fs.readdirSync(root)) {
      if (seen.has(name)) continue;
      const dir = path.join(root, name);
      if (!fs.statSync(dir).isDirectory()) continue;
      const skillFile = path.join(dir, 'SKILL.md');
      const scriptFile = path.join(dir, 'script.ts');
      if (!fs.existsSync(skillFile) || !fs.existsSync(scriptFile)) continue;
      const frontmatter = parseFrontmatter(fs.readFileSync(skillFile, 'utf-8'));
      seen.add(name);
      out.push({
        name,
        tier,
        dir,
        description: frontmatter.description || '',
        host: frontmatter.host || '',
      });
    }
  }
  return out;
}

export function readSkill(config: RuntimeConfig, name: string): BrowserSkill | null {
  return listSkills(config).find(skill => skill.name === name) ?? null;
}

export function formatSkillList(config: RuntimeConfig): string {
  const skills = listSkills(config);
  if (skills.length === 0) return 'No browser skills found.\n';
  const lines = ['NAME                          TIER     HOST                         DESC'];
  for (const skill of skills) {
    lines.push([
      skill.name.padEnd(30),
      skill.tier.padEnd(8),
      skill.host.slice(0, 28).padEnd(28),
      skill.description.slice(0, 60),
    ].join(' '));
  }
  return `${lines.join('\n')}\n`;
}

export async function runSkill(config: RuntimeConfig, name: string, args: string[], port: number, token: string): Promise<string> {
  const skill = readSkill(config, name);
  if (!skill) throw new Error(`Skill "${name}" not found`);
  const script = path.join(skill.dir, 'script.ts');
  const proc = Bun.spawn(['bun', 'run', script, ...args], {
    cwd: skill.dir,
    env: {
      LANG: process.env.LANG || 'en_US.UTF-8',
      LC_ALL: process.env.LC_ALL || '',
      TERM: process.env.TERM || 'xterm-256color',
      TZ: process.env.TZ || '',
      BROWSER_CONTROL_PORT: String(port),
      BROWSER_CONTROL_TOKEN: token,
      BROWSER_CONTROL_STATE_FILE: config.stateFile,
    },
    stdout: 'pipe',
    stderr: 'pipe',
  });
  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
    proc.exited,
  ]);
  if (exitCode !== 0) {
    throw new Error(`Skill "${name}" failed (${exitCode}).\n${stderr || stdout}`);
  }
  return stdout.trim();
}

export function testSkill(config: RuntimeConfig, name: string): string {
  const skill = readSkill(config, name);
  if (!skill) throw new Error(`Skill "${name}" not found`);
  const testFile = path.join(skill.dir, 'script.test.ts');
  if (!fs.existsSync(testFile)) throw new Error(`Skill "${name}" has no script.test.ts`);
  const proc = spawnSync('bun', ['test', testFile], {
    cwd: skill.dir,
    encoding: 'utf-8',
    timeout: 60_000,
  });
  if (proc.status !== 0) {
    throw new Error(proc.stderr || proc.stdout || `Skill test failed with exit ${proc.status}`);
  }
  return proc.stdout || `Skill "${name}" tests passed`;
}

function parseFrontmatter(markdown: string): Record<string, string> {
  if (!markdown.startsWith('---')) return {};
  const end = markdown.indexOf('\n---', 3);
  if (end === -1) return {};
  const block = markdown.slice(3, end).trim();
  const result: Record<string, string> = {};
  for (const line of block.split('\n')) {
    const match = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (match) result[match[1]] = match[2].replace(/^['"]|['"]$/g, '');
  }
  return result;
}
