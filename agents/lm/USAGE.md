LM(1)                             dot-pi                             LM(1)

NAME
       lm — general-purpose conversational agent (in-situ)

SYNOPSIS
       lm help | usage | -h | --help

       lm
       lm [--batch] - prompt words...

DESCRIPTION
       lm is a lightweight in-situ pi session for questions and chat in your
       current working directory.

OPTIONS
       --batch
              Non-interactive run.  Requires a prompt after - or piped stdin.

COMMANDS
       help, usage, -h, --help
              Show this page on standard output.

EXAMPLES
       lm
       lm - explain this Makefile
       echo what is in . | lm

SEE ALSO
       agents/lm/README.md, agents/lm/SYSTEM.md
