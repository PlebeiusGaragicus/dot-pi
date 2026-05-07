# Deep Research Workflow

Use top-level capability agents to produce a citation-backed research artifact for the user's topic.

## Goal

Create a focused research report from live sources. Prefer a saved artifact over a long chat answer unless the user explicitly asks for an inline summary.

## Worker Strategy

1. Use `web` to find source candidates.
   - Ask for authoritative, diverse sources relevant to the user's topic.
   - Request URLs, titles, relevance notes, and gaps.
   - If the user provides constraints such as date range, geography, source type, or number of sources, include them.

2. Use `web` to inspect the most relevant sources.
   - Ask for targeted extraction, not broad browsing.
   - Save source notes under `sources/` when an artifact will be produced.
   - Save screenshots under `screenshots/` only when visual evidence matters.
   - Require source URLs in the worker reply.

3. Use `writer` to synthesize the report.
   - Provide the source notes or extracted findings from earlier steps.
   - Ask it to write `reports/report.md` unless the user requested another path.
   - Require citations in the report body.
   - Ask for a concise worker reply with changed paths and any unresolved gaps.

4. Use `ask` with persona `judge` for the quality gate.
   - Ask it to evaluate whether the report satisfies the user's goal.
   - Include criteria: source coverage, citation presence, factual support, and unresolved uncertainty.
   - Require only `PASS: <one sentence>` or `FAIL: <one sentence>`.

5. If the judge fails, repair once.
   - Use `web` or `writer` depending on the failure reason.
   - Run the `ask` judge check again.
   - If it still fails, stop and report the blocker with artifact paths.

## Artifact Conventions

- `sources/` for source notes and extracted facts.
- `drafts/` for intermediate writing when needed.
- `reports/report.md` for the final report unless the user specifies another path.
- `screenshots/` for browser evidence only when relevant.

## Stop Conditions

- Stop early if search providers, browser-control, or source access fail in a way that blocks the research.
- Stop early if the topic is too ambiguous to research without a user choice; return a concise clarification need instead of guessing.
- Do not ask workers to write files unless their structural permissions allow it and the task explicitly needs an artifact.

## Final Response

Keep the final response short. Prefer:

`Research completed. Report saved to ./reports/report.md.`

If the workflow stopped early, mention the blocker and any partial artifact paths. Do not paste the full report into chat unless the user requested it.

## User Request

Treat the text below as the user's research request, including topic, constraints, desired output path, source preferences, and any scope limits. If no request was provided, or if it is too ambiguous to research responsibly, ask the user for the missing topic or constraints before invoking workers.

**User prompt:**
`$@`
