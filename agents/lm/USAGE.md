LM(1)                             dot-pi                             LM(1)

NAME
       lm — general-purpose conversational agent (in-situ)

SYNOPSIS
       lm help | usage | -h | --help

       lm
       lm - prompt words...
       lm -p prompt words...
       lm -p -v prompt words...

DESCRIPTION
       lm is a lightweight in-situ pi session for questions and chat in your
       current working directory.

OPTIONS
       -p, --print
              Non-interactive run.  Print the final assistant reply and exit.
              Accepts prompt words or piped stdin.

       -v, --verbose
              With -p/--print, also show turn/tool progress on stderr.

       --batch
              Compatibility alias for -p.  Prefer -p in new scripts.

COMMANDS
       help, usage, -h, --help
              Show this page on standard output.

EXAMPLES
       lm
       lm - explain this Makefile
       lm -p explain this Makefile > answer.txt
       lm -p -v explain this Makefile
       echo what is in . | lm -p

SEE ALSO
       agents/lm/README.md, agents/lm/SYSTEM.md
