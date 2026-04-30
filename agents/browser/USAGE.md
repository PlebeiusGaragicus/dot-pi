BROWSER(1)                          dot-pi                          BROWSER(1)

NAME
       browser — headless browser automation agent (workspace mode)

SYNOPSIS
       browser help | usage | -h | --help

       browser
       browser [-n name | --name name] - prompt words...
       browser -p [-n name | --name name] prompt words...
       browser -p -v [-n name | --name name] prompt words...

       browser ls

       browser resume [workspace-prefix]
       browser resume [workspace-prefix] - prompt words...
       browser resume [workspace-prefix] -p prompt words...

       --batch remains accepted as a compatibility alias for -p.

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
       -p, --print
              Non-interactive run.  Print the final assistant reply and exit.
              Accepts prompt words or piped stdin.

       -v, --verbose
              With -p/--print, also show turn/tool progress on stderr.

       --batch
              Compatibility alias for -p.  Prefer -p in new scripts.

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
              or slug).  Add - prompt to continue interactively with an
              initial instruction, or -p prompt to print a final reply.

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

       browser -p open https://example.org and return text
       browser -p -v open https://example.org and show progress

       browser ls

       browser resume
       browser resume docs-audit
       browser resume 2026-04-29 - list open tabs
       browser resume 2026-04-29 -p list open tabs

SEE ALSO
       agents/browser/SYSTEM.md, agents/browser/bootstrap.sh,
       shared/skills/browser-control/SKILL.md, utilities/browser-runtime
