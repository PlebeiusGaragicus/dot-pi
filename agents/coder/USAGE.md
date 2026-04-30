CODER(1)                          dot-pi                          CODER(1)

NAME
       coder — general-purpose coding assistant (in-situ)

SYNOPSIS
       coder help | usage | -h | --help

       coder
       coder [--batch] - prompt words...

DESCRIPTION
       coder launches pi with this agent’s config in your current working
       directory.  It is intended for repository work; it may load
       project context such as AGENTS.md depending on pi-args.

OPTIONS
       --batch
              Non-interactive run (JSON mode where applicable).  Requires a
              prompt after -, or non-empty stdin as the prompt when the
              launcher reads piped input.

COMMANDS
       help, usage, -h, --help
              Show this page on standard output.

FILES
       agents/coder/
              Agent config root (SYSTEM.md, pi-args, extensions, skills).

EXAMPLES
       coder
       coder - refactor src/auth.ts for clarity
       coder --batch - list files in the current directory

SEE ALSO
       agents/coder/README.md, agents/coder/SYSTEM.md, agents/coder/pi-args
