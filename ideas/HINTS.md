# Commands

Each MAS and standalone agent is available as a direct command on PATH (via symlinks in `bin/` pointing to `dispatch-agent`). Run `dotpi list` to see all available commands.

```sh
# interactive (tty)
recon
deepresearch

# non-interactive with -p flag (batch mode)
recon -p "map the auth flow"
deepresearch -p "creatine cognitive effects"

# pipe stdin as prompt (batch mode)
echo "explain the caching layer" | recon

# batch mode output: progress on stderr, final text on stdout
deepresearch -p "WebTransport protocol" > report.md      # progress visible, report saved
deepresearch -p "WebTransport protocol" 2>/dev/null       # silent, stdout only
recon -p "map the auth flow" > /dev/null                  # progress only, discard result

# workspace management (workspace MAS only)
deepresearch --list
deepresearch --resume
deepresearch --resume 2026-04-10
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

# list available LM Studio models

```sh
curl -s -H "Authorization: Bearer $LM_STUDIO_API_KEY" "${LM_STUDIO_BASE_URL%/}/v1/models" | jq
```

## see all details
```sh
curl -s -H "Authorization: Bearer $LM_STUDIO_API_KEY" "${LM_STUDIO_BASE_URL%/}/api/v1/models" | jq
```
