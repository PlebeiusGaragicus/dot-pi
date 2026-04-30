BROWSER(1)                          dot-pi                          BROWSER(1)

NAME
       browser — headless browser automation agent (workspace mode)

SYNOPSIS
       browser help | usage | -h | --help

       browser
       browser [--batch] [-n name | --name name] - prompt words...

       browser ls

       browser resume [workspace-prefix]
       browser resume [workspace-prefix] [--batch] - prompt words...

       Leading --batch is accepted before any subcommand (e.g. for a
       one-shot JSON run with a prompt).

DESCRIPTION
       browser launches pi with this agent’s config inside a dated
       workspace under workspaces/browser/.  Bootstrap prepares state,
       exports $B (browser-runtime binary or source fallback), sets
       BROWSER_CONTROL_STATE_DIR, runs $B status, and logs to
       bootstrap.log.

       Pi and bash tool calls inherit $B; the agent should run
       $B <subcommand> without re-exporting the path each time unless
       $B is unset.  The name browser-control is not on PATH; invoke
       the CLI only as $B.  See agents/browser/SYSTEM.md and
       shared/skills/browser-control/SKILL.md.

       Inside the session, automation follows the browser-control skill
       and $B.  Use browser ls and browser resume to reuse workspaces;
       resume re-runs bootstrap so daemons can recover after a reboot.

OPTIONS
       --batch
              Non-interactive run: pi JSON mode and closed stdin for the
              launcher path that expects a prompt.  Requires a prompt
              after - (or piped stdin where supported).

       -n name, --name name
              Suffix the new workspace directory with a slug from name
              (workspace agents only).  Example: .../2026-04-29-120000--
              my-audit/.

COMMANDS
       help, usage, -h, --help
              Show this page on standard output.

       ls     List workspaces under workspaces/browser/.

       resume [workspace-prefix]
              Continue the latest workspace, or the newest workspace
              whose directory name matches the given prefix (timestamp
              or slug).  Optional [--batch] - prompt continues that
              workspace with a new instruction.

FILES
       workspaces/browser/<timestamp>[--<slug>]/
              Workspace root: drafts, sessions/, bootstrap.log, and
              agent output as configured.

       .browser-control/ (under workspace)
              Playwright state, daemon logs, screenshots.

       sessions/
              Pi session JSONL when the launcher passes --session-dir.

ENVIRONMENT
       $B     Set by bootstrap before pi starts: path to the compiled
              browser-control binary, or bun run …/cli.ts fallback.
              Inherited by the agent; use $B in bash as-is.

       BROWSER_CONTROL_STATE_DIR
              Set by bootstrap to <workspace>/.browser-control/.
              Writable state directory for browser-control.

EXAMPLES
       browser - open https://example.org and summarize it

       browser -n docs-audit - open https://example.org and summarize

       browser --batch - open https://example.org and return JSON

       browser ls

       browser resume
       browser resume docs-audit
       browser resume 2026-04-29 --batch - list open tabs

SEE ALSO
       agents/browser/SYSTEM.md, agents/browser/bootstrap.sh,
       shared/skills/browser-control/SKILL.md, utilities/browser-runtime
