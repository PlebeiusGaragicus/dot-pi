import { chromium, type Browser, type BrowserContext, type Locator, type Page } from 'playwright';
import * as path from 'path';
import type { RuntimeConfig } from './config';
import { validateOutputPath } from './config';

interface RefEntry {
  ref: string;
  role: string;
  name: string;
  selector: string;
}

interface TabEntry {
  id: number;
  page: Page;
  refs: Map<string, RefEntry>;
}

export class BrowserManager {
  private browser: Browser | null = null;
  private context: BrowserContext | null = null;
  private tabs = new Map<number, TabEntry>();
  private activeTabId = 0;
  private nextTabId = 1;

  constructor(private readonly config: RuntimeConfig) {}

  async launch(): Promise<void> {
    if (this.browser) return;
    const args = process.env.CI || process.env.CONTAINER ? ['--no-sandbox'] : [];
    this.browser = await chromium.launch({
      headless: process.env.BROWSER_CONTROL_HEADED !== '1',
      chromiumSandbox: process.platform !== 'win32',
      args,
    });
    this.browser.on('disconnected', () => {
      console.error('[browser-control] Chromium disconnected; daemon exiting.');
      process.exit(1);
    });
    this.context = await this.browser.newContext({
      viewport: { width: 1440, height: 900 },
    });
    await this.newTab();
  }

  async close(): Promise<void> {
    await this.browser?.close().catch(() => {});
    this.browser = null;
    this.context = null;
    this.tabs.clear();
    this.activeTabId = 0;
  }

  status(): string {
    return [
      'browser-control daemon healthy',
      `Mode: ${process.env.BROWSER_CONTROL_HEADED === '1' ? 'headed' : 'headless'}`,
      `Tabs: ${this.tabs.size}`,
      `Active tab: ${this.activeTabId || 'none'}`,
      `State dir: ${this.config.stateDir}`,
    ].join('\n');
  }

  async goto(url: string): Promise<string> {
    const page = this.page();
    await page.goto(normalizeUrl(url), { waitUntil: 'domcontentloaded' });
    this.clearRefs();
    return page.url();
  }

  async text(selector?: string): Promise<string> {
    const target = selector ? await this.resolveLocator(selector) : this.page().locator('body');
    return (await target.innerText({ timeout: 5000 })).trim();
  }

  async html(selector?: string): Promise<string> {
    if (!selector) return this.page().content();
    return this.resolveLocator(selector).then(locator => locator.innerHTML({ timeout: 5000 }));
  }

  async links(): Promise<string> {
    const links = await this.page().locator('a').evaluateAll((nodes) => nodes.map((node) => {
      const a = node as HTMLAnchorElement;
      return { text: (a.innerText || a.getAttribute('aria-label') || '').trim(), href: a.href };
    }).filter(link => link.href));
    return JSON.stringify(links, null, 2);
  }

  currentUrl(): string {
    return this.page().url() || 'about:blank';
  }

  async snapshot(interactiveOnly = false): Promise<string> {
    const page = this.page();
    const refs = await page.evaluate((interactive) => {
      const isVisible = (el: Element) => {
        const rect = el.getBoundingClientRect();
        const style = window.getComputedStyle(el);
        return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none';
      };
      const cssPath = (el: Element) => {
        const parts: string[] = [];
        let cur: Element | null = el;
        while (cur && cur.nodeType === Node.ELEMENT_NODE && cur !== document.body) {
          const parent: Element | null = cur.parentElement;
          if (!parent) break;
          const tag = cur.tagName.toLowerCase();
          const siblings = Array.from(parent.children).filter(child => child.tagName === cur!.tagName);
          const idx = siblings.indexOf(cur) + 1;
          parts.unshift(`${tag}:nth-of-type(${idx})`);
          cur = parent;
        }
        return `body${parts.length ? ' > ' + parts.join(' > ') : ''}`;
      };
      const roleFor = (el: Element) => {
        const explicit = el.getAttribute('role');
        if (explicit) return explicit;
        const tag = el.tagName.toLowerCase();
        if (tag === 'a') return 'link';
        if (tag === 'button') return 'button';
        if (tag === 'input' || tag === 'textarea') return 'textbox';
        if (tag === 'select') return 'combobox';
        if (/^h[1-6]$/.test(tag)) return 'heading';
        return tag;
      };
      const nameFor = (el: Element) => {
        if (el instanceof HTMLInputElement && el.value) return el.value.trim();
        return (el.getAttribute('aria-label') || el.textContent || '').replace(/\s+/g, ' ').trim();
      };
      const interactiveSelector = 'a,button,input,textarea,select,[role],[tabindex],summary';
      const selector = interactive ? interactiveSelector : 'a,button,input,textarea,select,[role],[tabindex],summary,h1,h2,h3,h4,h5,h6,p,li';
      return Array.from(document.querySelectorAll(selector))
        .filter(isVisible)
        .map((el, index) => ({
          ref: `@e${index + 1}`,
          role: roleFor(el),
          name: nameFor(el).slice(0, 160),
          selector: cssPath(el),
        }))
        .filter(item => item.name || ['textbox', 'combobox'].includes(item.role));
    }, interactiveOnly);

    const tab = this.activeTab();
    tab.refs.clear();
    for (const entry of refs) tab.refs.set(entry.ref, entry);
    if (refs.length === 0) return '(no visible elements found)';
    return refs.map(entry => `${entry.ref} ${entry.role}${entry.name ? ` "${entry.name}"` : ''}`).join('\n');
  }

  async click(selector: string): Promise<string> {
    await (await this.resolveLocator(selector)).click({ timeout: 5000 });
    return 'clicked';
  }

  async fill(selector: string, value: string): Promise<string> {
    await (await this.resolveLocator(selector)).fill(value, { timeout: 5000 });
    return 'filled';
  }

  async press(key: string): Promise<string> {
    await this.page().keyboard.press(key);
    return `pressed ${key}`;
  }

  async scroll(selector?: string): Promise<string> {
    if (selector) {
      await (await this.resolveLocator(selector)).scrollIntoViewIfNeeded({ timeout: 5000 });
      return 'scrolled element into view';
    }
    await this.page().mouse.wheel(0, 900);
    return 'scrolled page';
  }

  async screenshot(rawPath?: string): Promise<string> {
    const out = rawPath
      ? validateOutputPath(rawPath, this.config)
      : path.join(this.config.screenshotsDir, `screenshot-${Date.now()}.png`);
    await this.page().screenshot({ path: out, fullPage: true });
    return out;
  }

  async newTab(url?: string): Promise<string> {
    if (!this.context) throw new Error('Browser context is not ready');
    const page = await this.context.newPage();
    const id = this.nextTabId++;
    this.tabs.set(id, { id, page, refs: new Map() });
    this.activeTabId = id;
    page.on('framenavigated', frame => {
      if (frame === page.mainFrame()) this.tabs.get(id)?.refs.clear();
    });
    if (url) await page.goto(normalizeUrl(url), { waitUntil: 'domcontentloaded' });
    return JSON.stringify({ tabId: id, url: page.url() || 'about:blank' });
  }

  tabsList(): string {
    return JSON.stringify(Array.from(this.tabs.values()).map(tab => ({
      id: tab.id,
      active: tab.id === this.activeTabId,
      url: tab.page.url() || 'about:blank',
    })), null, 2);
  }

  async closeTab(idArg?: string): Promise<string> {
    const id = idArg ? Number(idArg) : this.activeTabId;
    const tab = this.tabs.get(id);
    if (!tab) throw new Error(`No tab ${id}`);
    await tab.page.close().catch(() => {});
    this.tabs.delete(id);
    if (this.activeTabId === id) {
      this.activeTabId = this.tabs.keys().next().value ?? 0;
    }
    if (this.tabs.size === 0) await this.newTab();
    return `closed tab ${id}`;
  }

  private page(): Page {
    return this.activeTab().page;
  }

  private activeTab(): TabEntry {
    const tab = this.tabs.get(this.activeTabId);
    if (!tab) throw new Error('No active tab');
    return tab;
  }

  private clearRefs(): void {
    this.activeTab().refs.clear();
  }

  private async resolveLocator(selector: string): Promise<Locator> {
    if (selector.startsWith('@e')) {
      const entry = this.activeTab().refs.get(selector);
      if (!entry) throw new Error(`Unknown or stale ref ${selector}. Run snapshot again.`);
      const locator = this.page().locator(entry.selector);
      if (await locator.count() === 0) {
        this.activeTab().refs.delete(selector);
        throw new Error(`Stale ref ${selector}. Run snapshot again.`);
      }
      return locator.first();
    }
    return this.page().locator(selector).first();
  }
}

function normalizeUrl(raw: string): string {
  if (/^https?:\/\//.test(raw) || raw.startsWith('file://')) return raw;
  return `https://${raw}`;
}
