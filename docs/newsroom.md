# Newsroom Agent Team

The newsroom team produces automated news briefings by orchestrating specialist agents through a five-phase editorial workflow. It models the hierarchy of a real newsroom: an editor makes editorial decisions, beat reporters do the legwork, a fact-checker verifies claims, and a copy editor assembles the final report.

## Agents

| Agent | Role | Tools | Dispatched by |
|-------|------|-------|---------------|
| `newsroom-editor` | Managing editor / dispatcher | `dispatch_agent` only | User (top-level) |
| `desk-geopolitics` | Beat reporter, geopolitics | `read,bash,write` | Editor |
| `desk-scitech` | Beat reporter, science & tech | `read,bash,write` | Editor |
| `newsroom-researcher` | Investigative deep dives | `read,bash,write` | Editor |
| `newsroom-fact-checker` | Claim verification | `read,bash,write` | Editor |
| `newsroom-copy-editor` | Assembly and polish | `read,bash,write,edit` | Editor |

All agents are dispatched directly by the editor. There is no nested dispatch -- the architecture is flat.

## The Five Phases

### Phase 1: Reconnaissance

The editor dispatches both desk agents in **scan mode**. Each desk runs 5-8 broad headline-only SearXNG queries across its beat, producing a ranked list of ~10 story candidates. This phase is deliberately cheap: only `{title, url}` are pulled from search results, keeping context small.

Output: `wire-geopolitics.md` and `wire-scitech.md` in the workspace.

### Phase 2: Editorial Selection

The editor reads the wire scans returned by both desks and **makes the editorial decision** about which 5-8 stories to pursue. For each selected story, the editor writes a one-sentence assignment specifying the angle and expected sourcing. Stories that look important but under-sourced get flagged for a researcher deep dive.

This phase happens entirely within the editor's context -- no agents are dispatched.

### Phase 3: Deep Reporting

The editor dispatches both desk agents in **investigate mode** with their specific story assignments. Each desk agent:
- Runs targeted deep searches on each assigned story
- Hunts primary sources (government press releases, research papers, official statements)
- Saves raw source material to `sources/`
- Writes one file per story to `stories/[slug].md`
- Returns a brief summary to the editor (not the full story -- the editor reads files from disk if needed)

If the editor flagged stories for deep investigation, the `newsroom-researcher` is dispatched with specific questions.

### Phase 4: Verification

The editor dispatches the `newsroom-fact-checker` to read all story files in `stories/`. The fact-checker:
- Cross-references key claims against independent sources via SearXNG
- Spot-checks every primary source URL (HTTP status)
- Searches for retractions or corrections
- Writes `fact-check.md` with a per-story verdict (VERIFIED / FLAGGED / UNVERIFIABLE)

If critical issues are flagged, the editor can dispatch the relevant desk agent to fix the story before proceeding.

### Phase 5: Final Edit

The editor dispatches the `newsroom-copy-editor` to:
- Read all story files from `stories/`
- Read `fact-check.md` for flagged claims
- Assemble stories into a single briefing document
- Handle flagged claims (add caveats, drop contradicted claims, annotate unverified ones)
- Polish prose, deduplicate, ensure consistent structure
- Write the final report to `newsreport-[DATE].md`

## Workspace Structure

Each run creates a date-stamped workspace under `workspaces/newsroom/`:

```
workspaces/newsroom/2026-04-08/
  wire-geopolitics.md          # Phase 1 output
  wire-scitech.md              # Phase 1 output
  stories/                     # Phase 3 output (one file per story)
    us-china-tariffs.md
    artemis-ii-mission.md
    ...
  research/                    # Deep-dive briefs (optional)
    tariff-supply-chain.md
  sources/                     # Raw source material
    state-dept-briefing.html
  fact-check.md                # Phase 4 output
  newsreport-2026-04-08.md     # Final report
  sessions/                    # Sub-agent session logs (JSONL)
```

## Running

**Interactive** (uses the `pnews` alias):

```bash
pnews
# Then in the pi session:
/news-report
```

**Headless** (for cron or scheduled runs):

```bash
~/dot-pi/scripts/newsroom.sh
```

Both methods set `AGENT_TEAM=newsroom` and `AGENT_WORKSPACE` automatically, create the workspace directories, and inject the workspace path into the editor's system prompt via `agent-team-2.ts`.

## Design Rationale

### Why two modes per desk agent?

Scanning headlines and investigating a story are fundamentally different cognitive tasks with different context budgets. A scan uses ~2K tokens (just titles and URLs). An investigation can use 20K+ tokens per story (full article content, source pages, raw HTML). Combining them in one dispatch bloats the context window and degrades quality.

By splitting into two dispatches, each starts with a clean context and a focused task.

### Why flat dispatch?

The editor dispatches every agent directly. Desk agents do not dispatch researchers -- they flag stories for deep dives in their "Notes for Editor" section, and the editor decides whether to approve. This avoids:

- Invisible sub-processes the editor can't track
- The fragile `pi -p` bash hack for nested dispatch
- Loss of editorial control over resource allocation

### Why a separate fact-checker?

Fact-checking requires adversarial skepticism (trying to break claims). Copy editing requires cooperative craft (making text read well). These are cognitively opposed. Separating them also creates a quality gate: if the fact-checker finds problems, the editor can dispatch corrections before the copy editor runs.

### Why SearXNG?

SearXNG is a self-hosted metasearch engine. It aggregates results from multiple search engines without tracking, and exposes a JSON API. Key parameters used by the desk agents:

- `categories=news` for current reporting
- `categories=general` for primary sources (government sites, press releases)
- `categories=science` for academic content
- `time_range=month` for 96-hour coverage window
- `format=json` for structured output
- `pageno=N` for pagination
