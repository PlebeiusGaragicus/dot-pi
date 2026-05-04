SEARCH(1)                         dot-pi                         SEARCH(1)

NAME
       search - script-backed Tavily and Exa research agent (in-situ)

SYNOPSIS
       search help | usage | -h | --help

       search
       search - prompt words...
       search -p prompt words...
       search -p -v prompt words...

DESCRIPTION
       search uses CLI skills for Tavily and Exa web research. It runs in your
       current directory and cites source URLs in final answers.

OPTIONS
       -p, --print
              Non-interactive run. Print the final assistant reply and exit.
              Accepts prompt words or piped stdin.

       -v, --verbose
              With -p/--print, also show turn/tool progress on stderr.

COMMANDS
       help, usage, -h, --help
              Show this page on standard output.

       /exa-api-key
              Configure the repo-local Exa API key.

       /tavily-api-key
              Configure the repo-local Tavily API key.

EXAMPLES
       search
       search - latest AI search API pricing
       search -p current RISC-V laptop options > answer.md
       search -p -v compare Tavily and Exa
       echo summarize today's AI regulation news | search -p

SEE ALSO
       agents/search/README.md, agents/search/SYSTEM.md, agents/search/skills/
