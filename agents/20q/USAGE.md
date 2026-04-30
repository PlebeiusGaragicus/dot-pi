20Q(1)                            dot-pi                            20Q(1)

NAME
       20q — twenty-questions game agent (in-situ, no tools)

SYNOPSIS
       20q help | usage | -h | --help

       20q
       20q [--batch] - prompt words...

DESCRIPTION
       20q runs the twenty-questions game using the agent’s own knowledge
       only (no file or web tools).  Sessions use the current directory as
       cwd unless you change pi defaults.

OPTIONS
       --batch
              Non-interactive run when a prompt is supplied.  See dispatch-
              agent for exact behavior.

COMMANDS
       help, usage, -h, --help
              Show this page on standard output.

EXAMPLES
       20q
       20q - start a new game

SEE ALSO
       agents/20q/README.md, agents/20q/SYSTEM.md
