These repositories are **optional local-only context** for agents working in this repo. Clone any of them into `REFERENCES/` so agents (Cursor, pi, etc.) can read their source while answering questions about dot-pi internals or related tools. Nothing here is required, nothing is tracked, and these are **not git submodules** — just sibling checkouts that happen to live under a gitignored directory.

```sh
cd ./REFERENCES/

## pi-mono itself
git clone https://github.com/PlebeiusGaragicus/pi-mono.git

## agent specifications and skill libraries
git clone https://github.com/PlebeiusGaragicus/gstack.git

## pi packages / add-ons
git clone https://github.com/PlebeiusGaragicus/plannotator.git
git clone https://github.com/PlebeiusGaragicus/pi-portal.git
git clone https://github.com/PlebeiusGaragicus/pi-subagents.git

## CLI utilities that extend a computer and tools which enhance agents
git clone https://github.com/tobi/qmd
# git clone `nak`
# git clone `searxng`

## example packaged pi products (pi-included)

git clone https://github.com/PlebeiusGaragicus/feynman.git

git clone https://github.com/PlebeiusGaragicus/piclaw.git
```