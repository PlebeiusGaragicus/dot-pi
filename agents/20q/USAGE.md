20Q(1)                            dot-pi                            20Q(1)

NAME
       20q — twenty-questions game agent (in-situ, no tools)

SYNOPSIS
       20q help | usage | -h | --help

       20q
       20q - prompt words...
       20q -p prompt words...
       20q -p -v prompt words...

DESCRIPTION
       20q runs the twenty-questions game using the agent’s own knowledge
       only (no file or web tools).  Sessions use the current directory as
       cwd unless you change pi defaults.

OPTIONS
       -p, --print
              Non-interactive run.  Print the final assistant reply and exit.
              Accepts prompt words or piped stdin.

       -v, --verbose
              With -p/--print, also show turn progress on stderr.

COMMANDS
       help, usage, -h, --help
              Show this page on standard output.

EXAMPLES
       20q
       20q - start a new game
       20q -p answer yes or no: is it alive?

SEE ALSO
       agents/20q/README.md, agents/20q/SYSTEM.md
