WEB(1)                            dot-pi                            WEB(1)

NAME
       web — web and arXiv research agent (in-situ)

SYNOPSIS
       web help | usage | -h | --help

       web
       web - prompt words...
       web -p prompt words...
       web -p -v prompt words...

DESCRIPTION
       web searches the open web and academic sources (e.g. Tavily, arXiv
       skills) and returns answers with citations.  Runs in your current
       directory.

OPTIONS
       -p, --print
              Non-interactive run.  Print the final assistant reply and exit.
              Accepts prompt words or piped stdin.

       -v, --verbose
              With -p/--print, also show turn/tool progress on stderr.

COMMANDS
       help, usage, -h, --help
              Show this page on standard output.

EXAMPLES
       web
       web - latest advances in RISC-V
       web -p latest advances in RISC-V > answer.md
       web -p -v compare two papers
       echo compare two papers | web -p

SEE ALSO
       agents/web/README.md, agents/web/SYSTEM.md, agents/web/skills/
