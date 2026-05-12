MAS(1)                            dot-pi                            MAS(1)

NAME
       mas - top-level multi-agent orchestrator (in-situ)

SYNOPSIS
       mas help | usage | -h | --help

       mas
       mas - prompt words...
       mas -p prompt words...
       mas -p -v prompt words...

DESCRIPTION
       mas launches pi with a top-level-agent orchestrator. It delegates
       bounded tasks to the curated top-level capability agents ask, scout,
       writer, coder, and web through the subagent tool.

       The agent runs in the current working directory. Worker traces are
       grouped under $DOT_PI_OVERLAY/mas/subagent-traces/<run-id>/ (default
       ~/.pi/dot-pi/mas/subagent-traces/), not under the Pi-managed dot-pi
       git checkout.

OPTIONS
       -p, --print
              Non-interactive run. Print the final assistant reply and exit.
              Accepts prompt words or piped stdin.

       -v, --verbose
              With -p/--print, also show turn/tool progress on stderr.

COMMANDS
       help, usage, -h, --help
              Show this page on standard output.

EXAMPLES
       mas
       mas - plan a documentation update for this repository
       mas -p use scout to summarize this repo layout

SEE ALSO
       agents/mas/README.md, agents/mas/SYSTEM.md, agents/mas/prompts/
