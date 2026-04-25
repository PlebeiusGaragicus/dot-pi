---
name: check-github-ci
description: >-
  Queries GitHub Actions CI status with gh, pulls failed logs, diagnoses root
  causes, and suggests concrete fixes. Use when the user asks to check CI,
  diagnose workflow failures, review GitHub Actions, or says gh / CI / workflow
  is red or failing.
---

# Check GitHub Actions CI

## Preconditions

- `gh` installed and authenticated (`gh auth status`).
- Run from the repo root (or `cd` there first) so `gh` targets the correct remote.

## Workflow

1. **Recent runs**
   ```bash
   gh run list --limit 20
   ```
   Optionally filter: `gh run list --workflow=ci.yml --limit 10` (or the workflow `name:` from the YAML; adjust per repo under `.github/workflows/`).

2. **Latest failure (quick)**
   ```bash
   gh run list --workflow=ci.yml --status failure --limit 1
   ```
   Or pick a run ID from the list.

3. **Failed logs only**
   ```bash
   gh run view <RUN_ID> --log-failed
   ```
   For full logs: `gh run view <RUN_ID> --log` (large).

4. **Open in browser** (optional): `gh run view <RUN_ID> --web`

5. **Diagnose**
   - Map each failing step to the file or job that owns it (workflow YAML vs application code).
   - Prefer the **first** substantive error in a step; ignore cascading noise when obvious.
   - Note whether **Deploy Docs** (or other workflows) passed while **CI** failed — narrows scope.

6. **Suggest fixes**
   - For each root cause: file path, what to change, and why (one or two sentences).
   - If unsure, say what to verify locally (e.g. `shellcheck …`, `mkdocs build --strict`) before pushing.

## dot-pi CI jobs (reference)

When working in this repo, `.github/workflows/ci.yml` defines roughly:

| Job | Typical failures |
|-----|------------------|
| `shellcheck` | SC#### in `dotpi`, `install`, `dispatch-agent`, `env.sh`, `commands/*.sh` |
| `typecheck` | `npx tsc --noEmit` / extension TS errors |
| `smoke` | `dotpi --help`, `install --help`, `pi-args` parsing smoke, `bash -n` on shell scripts |
| `gitignore-guard` | Tracked files that match ignore rules (after negations) |
| `docs` | `mkdocs build --strict` |

Other workflows (e.g. docs deploy) may exist under `.github/workflows/`; list with `ls .github/workflows`.

## Output format

Respond with:

1. **Status** — latest relevant run(s): conclusion, branch, short title, run ID, link from `gh run view <id> --web` if useful.
2. **Failures** — job / step name and the key log lines (or summarized error).
3. **Root causes** — bullet list tied to code or workflow.
4. **Suggested fixes** — ordered by impact; mention files and specific changes. Offer to implement if the user wants Agent mode.

## Notes

- Do not assume CI state without running `gh` (or the user pasting logs).
- If `gh` errors (auth, no remote), say so and give the minimum fix (e.g. `gh auth login`, check `git remote -v`).
