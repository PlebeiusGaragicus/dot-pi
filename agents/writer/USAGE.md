WRITER(1)                          dot-pi                          WRITER(1)

NAME
       writer — writing and documentation assistant (in-situ)

SYNOPSIS
       writer help | usage | -h | --help

       writer
       writer - prompt words...
       writer -p prompt words...
       writer -p -v prompt words...

DESCRIPTION
       writer launches pi with this agent’s config in your current working
       directory.  It is intended for long-form prose, docs, and revisions;
       it may load project context such as AGENTS.md depending on pi-args.

OPTIONS
       -p, --print
              Non-interactive run.  Print the final assistant reply and exit.
              Accepts prompt words or piped stdin.

       -v, --verbose
              With -p/--print, also show turn/tool progress on stderr.

COMMANDS
       help, usage, -h, --help
              Show this page on standard output.

FILES
       agents/writer/
              Agent config root (APPEND_SYSTEM.md, pi-args, extensions, skills).

EXAMPLES
       writer
       writer - tighten the README introduction
       writer -p summarize docs/README.md in three bullets
       writer -p -v draft a changelog entry for the last commit

SEE ALSO
       agents/writer/README.md, agents/writer/APPEND_SYSTEM.md, agents/writer/pi-args
