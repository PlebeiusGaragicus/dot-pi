# p command

`p` is the unified entry point for all teams and standalone agents. Run `p` with no arguments to print a table of names with `kind` (team vs agent) and `mode` (workspace vs in-situ).

```sh
# interactive (tty)
p recon
p deepresearch

# non-interactive with -p flag (batch mode)
p recon -p "map the auth flow"
p deepresearch -p "creatine cognitive effects"

# pipe stdin as prompt (batch mode)
echo "explain the caching layer" | p recon

# batch mode output: progress on stderr, final text on stdout
p deepresearch -p "WebTransport protocol" > report.md      # progress visible, report saved
p deepresearch -p "WebTransport protocol" 2>/dev/null       # silent, stdout only
p recon -p "map the auth flow" > /dev/null                  # progress only, discard result

# workspace management (workspace teams only)
p deepresearch --list
p deepresearch --resume
p deepresearch --resume 2026-04-10
```

---

# run-retro

Non-interactive retrospective analysis of workspace runs.
Progress on stderr, final report text on stdout.

```sh
run-retro deepresearch                            # latest workspace
run-retro deepresearch 2026-04-12                 # by date prefix
run-retro deepresearch --list                     # list workspaces
run-retro deepresearch --pick                     # interactive menu
run-retro deepresearch -- "focus on citations"    # with steering hint
run-retro deepresearch > retro.md                 # save report to file
```

---

# run evals

```sh
./evals/run-eval.sh deepresearch evals/deepresearch-short.txt
./evals/run-eval.sh --with-retro deepresearch evals/deepresearch-short.txt
```

---

# list available PlebChat models

```sh
curl -s -H "Authorization: Bearer $PLEBCHAT_API_KEY" "https://api.plebchat.me/v1/models" | jq
```

## see all details
```sh
curl -s -H "Authorization: Bearer $PLEBCHAT_API_KEY" "https://api.plebchat.me/api/v1/models" | jq
```
