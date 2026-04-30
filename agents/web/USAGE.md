WEB(1)                            dot-pi                            WEB(1)

NAME
       web — web and arXiv research agent (in-situ)

SYNOPSIS
       web help | usage | -h | --help

       web
       web [--batch] - prompt words...

DESCRIPTION
       web searches the open web and academic sources (e.g. Tavily, arXiv
       skills) and returns answers with citations.  Runs in your current
       directory.

OPTIONS
       --batch
              Non-interactive run.  Requires a prompt after - or piped stdin.

COMMANDS
       help, usage, -h, --help
              Show this page on standard output.

EXAMPLES
       web
       web - latest advances in RISC-V
       echo compare two papers | web

SEE ALSO
       agents/web/README.md, agents/web/SYSTEM.md, agents/web/skills/
