# Continuous Integration

This page explains the GitHub Actions workflows that run on every push and pull request.

dot-pi has **two** workflows:

| Workflow | File | When it runs | What it does |
|----------|------|--------------|--------------|
| **CI** | [`.github/workflows/ci.yml`](https://github.com/PlebeiusGaragicus/dot-pi/blob/main/.github/workflows/ci.yml) | Every push to `main`, every PR | Lints shell scripts, runs smoke tests, validates `.gitignore`, builds docs strictly |
| **Deploy Docs** | [`.github/workflows/docs.yml`](https://github.com/PlebeiusGaragicus/dot-pi/blob/main/.github/workflows/docs.yml) | Every push to `main` that touches `docs/` or `mkdocs.yml` | Builds the docs site and publishes to GitHub Pages |

## What is CI?

**Continuous Integration** is a fancy name for "the robot runs your tests every time you push code." For a small project like dot-pi, the goal is simple: catch obvious mistakes before they hit `main`. Things like:

- A typo in a bash script that breaks `dotpi sync` for everyone.
- A `git rm` that you forgot to do, leaving a tracked-but-gitignored file confusing future you.
- A doc page link that points to a file that no longer exists.

GitHub Actions runs the CI workflow in a fresh Ubuntu VM in the cloud. If any job fails, the PR shows a red X and you can click in to see exactly what broke.

## The five CI jobs

### 1. `shellcheck` — bash linter

Runs [shellcheck](https://www.shellcheck.net/) on every shell script in the repo:

- `dotpi`
- `install`
- `dispatch-agent`
- `env.sh`
- `commands/*.sh`

shellcheck catches things bash itself silently accepts but that almost certainly mean a bug:

- Unquoted variables (`rm $foo` when `$foo` has spaces deletes the wrong files).
- Using `==` in `[ ... ]` (POSIX `test` only knows `=`).
- Unused variables.
- `cd "$dir" && rm ...` patterns where the `cd` failure is silently swallowed.

Severity is set to `warning` — only real issues fail the build, not stylistic nits.

### 2. `typecheck` — extension TypeScript

Runs `npm ci` and `npx tsc --noEmit` from `tests/` to type-check the TypeScript extensions under `shared/extensions/`.

### 3. `smoke` — entry-script smoke tests

The cheapest possible "does it even start" tests:

- `./dotpi --version` — must print something and exit 0.
- `./dotpi --help` — must parse and run usage (exit 0 or 1).
- `bash install --help` — must parse and print usage.
- `bash -n` (parse-only check) on every shell script.

This catches the embarrassing case where you push a script with a stray `fi` or unmatched quote — it would crash the moment a user runs it. Now it crashes the CI instead.

### 4. `gitignore-guard` — prevent tracked-but-ignored files

Reads every line of `.gitignore` and checks that no file currently tracked by git matches an ignore pattern. Symlinks are skipped (per-agent `settings.json` symlinks are intentionally tracked even though the underlying `shared/settings.json` is ignored).

Why it matters: if a file is both **tracked** and **gitignored**, every clone gets the tracked copy but local edits are silently ignored by `git status`. This bit us before with `model_roles` and almost bit us with `shared/settings.json`. The guard makes that whole class of mistake impossible to merge.

### 5. `docs` — strict mkdocs build

Runs `mkdocs build --strict`. Strict mode turns warnings into errors, so:

- A broken internal link fails the build.
- A nav entry pointing to a missing file fails the build.
- A page that exists on disk but isn't in `nav` fails the build.

The separate **Deploy Docs** workflow only runs after merge and assumes the build is good. By running the strict build in CI on every PR, we catch breakage at PR time instead of after merge.

## How to read a failing CI run

1. Open the PR on GitHub. Failing jobs show a red X.
2. Click **Details** next to the failing job to open the live log.
3. Find the failing step (it'll have a red X next to it). Expand it for the actual error message.
4. Fix locally, push the fix to the same branch, CI re-runs automatically.

## Running CI checks locally before pushing

You don't need to wait for the cloud. Each job is one command:

```bash
# shellcheck (install with: brew install shellcheck)
shellcheck --shell=bash --severity=warning --external-sources \
  dotpi install dispatch-agent env.sh commands/*.sh

# smoke tests
./dotpi --version
./dotpi --help
bash install --help
bash -n dotpi install dispatch-agent env.sh commands/*.sh

# extension typecheck
(cd tests && npm ci && npx tsc --noEmit)

# docs strict build (install with: pip install mkdocs-material)
mkdocs build --strict
```

If those blocks pass, CI will pass too.

## Adding new checks

Edit [`.github/workflows/ci.yml`](https://github.com/PlebeiusGaragicus/dot-pi/blob/main/.github/workflows/ci.yml). Add a new top-level entry under `jobs:`. Each job runs in its own fresh VM in parallel, so adding a job doesn't slow down the others.

Good candidates for the future:

- **`shfmt --diff`** to enforce consistent bash formatting.
- **Symlink integrity check** (`find . -type l ! -exec test -e {} \; -print` should be empty).
