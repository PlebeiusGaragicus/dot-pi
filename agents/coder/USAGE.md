CODER(1)                          dot-pi                          CODER(1)

NAME
       coder — general-purpose coding assistant (in-situ)

SYNOPSIS
       coder help | usage | -h | --help

       coder
       coder - prompt words...
       coder -p prompt words...
       coder -p -v prompt words...

DESCRIPTION
       coder launches pi with this agent’s config in your current working
       directory.  It is intended for repository work; it may load
       project context such as AGENTS.md depending on pi-args.

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
       agents/coder/
              Agent config root (SYSTEM.md, pi-args, extensions, skills).

EXAMPLES
       coder
       coder - refactor src/auth.ts for clarity
       coder -p list files in the current directory
       coder -p -v list files in the current directory

SEE ALSO
       agents/coder/README.md, agents/coder/SYSTEM.md, agents/coder/pi-args
