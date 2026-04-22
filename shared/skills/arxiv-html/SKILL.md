---
description: Fetch arXiv papers as native HTML via bash+curl from https://arxiv.org/html/<id>
argument-hint: "<URL or paper-id>"
---

## Step 1 - fetch arXiv paper

Get the bare arXiv id from the user's input. Strip `https://arxiv.org/abs/`, `/pdf/`, `/html/`, or `arXiv:` prefixes. Keep the `vN` version suffix if present.

Run this command verbatim. Substitute `<ID>` only. Do not modify the User-Agent, the URL, the flags, or the output path:

```bash
curl -fsSL -A "pi-papers-agent" "https://arxiv.org/html/<ID>" | pandoc -f html -t plain -o /tmp/arxiv-<ID>.txt
```

## Step 2 - Review material and provide valuable feedback

If the command exits non-zero, the paper has no HTML version on arXiv. Tell the user and stop.

Then read `/tmp/arxiv-<ID>.txt` to answer the user's question. That file is your cache for follow-ups about the same paper.

Never fetch the PDF.
