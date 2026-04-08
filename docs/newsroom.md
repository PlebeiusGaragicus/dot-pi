# Newsroom Agent Team

The newsroom team produces automated news briefings by orchestrating specialist agents through a six-phase editorial workflow. It models the hierarchy of a real newsroom: an editor makes editorial decisions, beat reporters do the legwork, a VLM agent processes images and PDFs, a fact-checker verifies claims, and a copy editor assembles the final BLUF-structured report.

## Agents

| Agent | Role | Tools | Model | Dispatched by |
|-------|------|-------|-------|---------------|
| `newsroom-editor` | Managing editor / dispatcher | `dispatch_agent` only (top-level) | Inherited | User |
| `desk-geopolitics` | Beat reporter — geopolitics | `read,bash,write` | Inherited | Editor |
| `desk-scitech` | Beat reporter — science & tech | `read,bash,write` | Inherited | Editor |
| `newsroom-researcher` | Investigative deep dives | `read,bash,write` | Inherited | Editor |
| `newsroom-vlm` | VLM source processor (images, PDFs) | `read,bash,write` | `lmstudio/qwen3.5-122b-a10b` | Editor |
| `newsroom-fact-checker` | Claim verification | `read,bash,write` | Inherited | Editor |
| `newsroom-copy-editor` | Assembly, BLUF writing, polish | `read,bash,write,edit` | Inherited | Editor |

All agents are dispatched directly by the editor. There is no nested dispatch — the architecture is flat. See [Design Rationale](#why-flat-dispatch) for why.

### Tool override for the editor

The `newsroom-editor.md` frontmatter specifies `tools: read,write`. However, when the editor runs as the **top-level dispatcher**, `agent-team-2.ts` overrides its tools to `["dispatch_agent"]` only. The editor **cannot** read files, write files, or run bash.

### Per-agent model override

The `newsroom-vlm` agent specifies `model: lmstudio/qwen3.5-122b-a10b` in its frontmatter. When dispatched, `agent-team-2.ts` uses this model instead of inheriting the dispatcher's model. All other agents inherit the dispatcher's model (typically `qwen3-coder-next`).

### Editor system prompt

The editor's `.md` body (which describes the six phases, team roster, and rules) is **not used** when the editor is the top-level dispatcher. The extension replaces it with a generated system prompt containing the team name, member list, workspace path, agent catalog, and generic dispatcher rules. The actual workflow instructions come from the **prompt template** (`/news-report`) or the inlined prompt in `newsroom.sh`.

## The Six Phases

### Phase 1: Reconnaissance

The editor dispatches both desk agents in **SCAN MODE**. Each desk:
- Runs 5-8 broad headline-only SearXNG queries across its beat
- Uses ONLY `{title, url}` jq filter — no article content is pulled
- Produces a ranked list of ~10 story candidates with freshness and sourcing potential ratings
- Writes the list to `wire-[beat].md` with YAML frontmatter in the workspace
- Returns the list to the editor

This phase is deliberately cheap: headline-only queries keep context small (~2K tokens per desk).

**Wire file format:** YAML frontmatter with beat, date, queries_run, candidates count. Each candidate includes headline, URL, sourcing potential (high/medium/low), and freshness (breaking/24h/48h/older).

### Phase 2: Editorial Selection

The editor reads the wire scans returned by both desks and **makes the editorial decision** about which 5-8 stories to pursue. For each selected story, the editor writes:
- A one-sentence assignment specifying the angle and expected sourcing
- A **slug** for the filename (e.g., `us-iran-ceasefire`)
- Whether a researcher deep dive is warranted

This phase happens entirely within the editor's context — no agents are dispatched.

### Phase 3: Deep Reporting

The editor dispatches both desk agents in **INVESTIGATE MODE** with their specific story assignments including slugs. Each desk agent:

1. Runs targeted deep searches pulling full `{title, url, content}` for each assigned story
2. Hunts primary sources using `categories=general` and `categories=science`
3. Fetches key source pages with `curl -sL "URL" | sed 's/<[^>]*>//g' | sed '/^$/d' | head -c 8000`
4. **Saves source files** to `sources/<slug>.md` with YAML frontmatter (title, url, retrieved, source_type, publication, http_status, content_quality, has_images, has_pdf), an overview, key quotations, and sanitized extracted content
5. Flags PDFs and image-heavy sources with `has_pdf: true` or `has_images: true` in the source frontmatter
6. **Writes story files** to `stories/<slug>.md` with YAML frontmatter and a **BLUF** sentence
7. Returns a brief summary to the editor (3 lines max per story)

If the editor flagged stories for deep investigation, `newsroom-researcher` is dispatched with specific questions, a slug, and an output path.

**Source file format:** YAML frontmatter with metadata, then Overview, Key Quotations, Extracted Content, Images, and Notes sections. See [docs/formats.md](formats.md) for the full template.

**Story file format:** YAML frontmatter (title, slug, beat, date, significance, source counts), then a bold BLUF sentence, Report section, Primary Sources, Secondary Sources, and Notes for Editor. See [docs/formats.md](formats.md) for the full template.

### Phase 4: Source Enrichment

The editor dispatches `newsroom-vlm` (running on `lmstudio/qwen3.5-122b-a10b`, a vision-capable model) to process media that text-only agents flagged but couldn't handle:

- Scans source files in `sources/` for `has_images: true` or `has_pdf: true`
- Downloads images to `sources/images/` and describes their content (charts, maps, photos, infographics)
- Attempts PDF text extraction and adds content to the source file
- Updates source files with enriched content

This phase is optional — if no sources are flagged for media processing, the VLM agent returns quickly with nothing to process.

### Phase 5: Verification

The editor dispatches `newsroom-fact-checker` to read all story files in `stories/`. The fact-checker:

- Checks every primary source URL for HTTP status
- Cross-references key claims against independent sources via SearXNG
- Searches for retractions or corrections
- Verifies that each story's BLUF accurately reflects the supporting evidence
- Reads saved source files to verify extracted content supports claims
- Writes `fact-check.md` with YAML frontmatter (date, stories_checked, stories_verified, stories_flagged, stories_unverifiable) and per-story verdicts

If critical issues are flagged, the editor can dispatch the relevant desk agent to fix the story before proceeding.

### Phase 6: Final Edit

The editor dispatches `newsroom-copy-editor` to assemble the final **BLUF-structured report**:

- Reads all story files from `stories/` and their frontmatter
- Reads `fact-check.md` for flagged claims
- Writes a **report-level BLUF**: 2-3 sentences capturing the most important developments for a busy reader who will read nothing else
- Writes **per-story BLUFs**: one bold sentence before supporting paragraphs
- Groups stories by beat, leads with highest significance
- Handles flagged claims (caveats, annotations, demotion to Developing Stories)
- Builds a **consolidated Source Index** table at the bottom with numbered references
- Writes the final report to `newsreport-[DATE].md` with YAML frontmatter

## Output Formats

All newsroom artifacts use YAML frontmatter and follow BLUF structure where applicable. The canonical format reference is [docs/formats.md](formats.md). Formats are embedded inline in each agent's prompt — agents do not read the reference file.

| Artifact | Location | BLUF? | Frontmatter? |
|----------|----------|-------|-------------|
| Wire scan | `wire-<beat>.md` | No | Yes (beat, date, queries, candidates) |
| Source file | `sources/<slug>.md` | No (has Overview) | Yes (title, url, source_type, quality, media flags) |
| Story file | `stories/<slug>.md` | Yes | Yes (title, slug, beat, significance, source counts) |
| Fact-check | `fact-check.md` | No | Yes (date, counts by verdict) |
| Final report | `newsreport-YYYY-MM-DD.md` | Yes (report + per-story) | Yes (title, date, run_id, stories, sources, beats) |

### Content Sanitization

Text-only agents (desk reporters, researcher) use best-effort HTML extraction:
```bash
curl -sL URL | sed 's/<[^>]*>//g' | sed '/^$/d' | head -c 8000
```
Each source file includes a `content_quality` field (clean/partial/raw/failed) so downstream agents know how much to trust the extraction.

### Media Processing

The VLM agent handles images and PDFs flagged by desk agents:
- Images are downloaded to `sources/images/` and described with natural-language captions
- PDFs are fetched and text-extracted where possible
- Source files are updated with the enriched content

### Prompt Injection Defense

All agents that fetch web content include an adversarial content warning in their system prompt. Source files include a `Prompt injection risk` field in the Notes section.

## Workspace Structure

Each run creates a timestamped workspace under `workspaces/newsroom/`:

```
workspaces/newsroom/2026-04-08_1430/
  wire-geopolitics.md          # Phase 1 — scan results
  wire-scitech.md              # Phase 1 — scan results
  stories/                     # Phase 3 — one BLUF-structured file per story
    us-iran-ceasefire.md
    artemis-ii-mission.md
    ...
  sources/                     # Phase 3 — one file per key source
    wh-ceasefire.md
    nasa-artemis-press.md
    images/                    # Phase 4 — downloaded images
      hormuz-map.jpg
  research/                    # Phase 3 — deep-dive briefs (optional)
    tariff-supply-chain.md
  fact-check.md                # Phase 5 — verification report
  newsreport-2026-04-08.md     # Phase 6 — final BLUF-structured report
  session.jsonl                # Dispatcher session log (co-located)
  sessions/                    # Sub-agent session logs
    desk-geopolitics.json      # JSONL despite .json extension
    desk-scitech.json
    newsroom-vlm.json
    newsroom-fact-checker.json
    newsroom-copy-editor.json
```

## Running

### Interactive (pnews alias)

```bash
pnews
# Pi starts with the newsroom team active
# Type the command:
/news-report
```

The `/news-report` prompt template provides the six-phase workflow instructions. The editor gets the workspace path from its system prompt (injected by the extension).

You can append extra instructions: `/news-report Focus on semiconductor supply chains today`

### Headless (newsroom.sh script)

```bash
~/dot-pi/scripts/newsroom.sh
```

The prompt text in `newsroom.sh` must be kept in sync with `prompts/news-report.md` manually — they describe the same six-phase workflow but are maintained separately. See [docs/architecture.md](architecture.md) for the design rationale.

## SearXNG Usage

All desk agents and the researcher query a local SearXNG instance at `http://localhost:8080`. Key parameters:

| Parameter | Values used | Purpose |
|-----------|------------|---------|
| `q` | Dynamic per query | Search terms, spaces encoded as `+` |
| `format` | `json` | Always JSON for programmatic parsing |
| `categories` | `news`, `general`, `science` | `news` for reporting, `general` for primary sources, `science` for academic |
| `time_range` | `month` | Covers the 96-hour story window with margin |
| `language` | `en` | English results only |
| `pageno` | `1,2,3,...` | Pagination for deeper results |

### Two-pass search strategy

- **Scan mode** pulls only `{title, url}` — minimal context, fast survey
- **Investigate mode** pulls `{title, url, content}` — full context, deep dive

This two-pass approach prevents context overflow on smaller models.

## Design Rationale

### Why BLUF?

BLUF (Bottom Line Up Front) is a military communication standard that places the most important information first. For an automated briefing consumed by busy humans, this means:
- A reader can scan the report-level BLUF and stop if nothing is urgent
- Per-story BLUFs let readers skip to stories that matter to them
- The inverted pyramid structure naturally prioritizes the most newsworthy facts

### Why flat dispatch?

The editor dispatches every agent directly. Desk agents do not dispatch researchers — they flag stories for deep dives in their "Notes for Editor" section, and the editor decides whether to approve. This avoids invisible sub-processes, fragile nested dispatch hacks, and loss of editorial control.

### Why a separate VLM agent?

Vision-capable models (like `qwen3.5-122b-a10b`) have different strengths than coding models (like `qwen3-coder-next`). By isolating vision tasks in a dedicated agent with a model override, the text-only agents keep their stronger model, and the VLM agent only runs when there's media to process. The per-agent `model` field in the frontmatter makes this possible through `agent-team-2.ts`.

### Why a separate fact-checker?

Fact-checking requires adversarial skepticism (trying to break claims). Copy editing requires cooperative craft (making text read well). These are cognitively opposed modes. Separating them creates a quality gate: if the fact-checker finds problems, the editor can dispatch corrections before the copy editor runs.

### Why source files?

Saving sanitized source content to disk serves multiple purposes:
- The fact-checker can verify claims against the original text without re-fetching
- The copy editor can check source content without network access
- The retro team can assess source quality after the run
- Future runs can reference historical sources

### Why `time_range=month`?

The target coverage window is 96 hours. SearXNG's `time_range` parameter accepts `day`, `week`, `month`, and `year`. There is no `4days` option. `month` provides margin. The desk agent prompts specify 96 hours to the agent, but the SearXNG query uses `month`.
