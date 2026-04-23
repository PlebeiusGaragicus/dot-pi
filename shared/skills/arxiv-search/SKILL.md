---
name: arxiv-search
description: Search papers via arXiv
disable-model-invocation: false
---

## Step 1 - search arXiv

URL-encode the user's query into `<Q>` (spaces -> `+`, `:` -> `%3A`). Default `<SORT>=relevance`; use `submittedDate` or `lastUpdatedDate` instead if the user asks for "recent" or "latest".

Run this command verbatim. Substitute only `<Q>` and `<SORT>`. Do not modify the User-Agent, the URL, the flags, or the output paths:

```bash
curl -fsSL -A "pi-search-agent" \
  "http://export.arxiv.org/api/query?search_query=<Q>&start=0&max_results=25&sortBy=<SORT>&sortOrder=descending" \
  -o /tmp/arxiv-search.xml
python3 - <<'PY' > /tmp/arxiv-search.txt
import xml.etree.ElementTree as ET
ns = {"a": "http://www.w3.org/2005/Atom"}
root = ET.parse("/tmp/arxiv-search.xml").getroot()
entries = root.findall("a:entry", ns)
if not entries:
    print("NO_RESULTS")
for e in entries:
    aid = e.find("a:id", ns).text.rsplit("/", 1)[-1]
    title = " ".join(e.find("a:title", ns).text.split())
    authors = ", ".join(a.find("a:name", ns).text for a in e.findall("a:author", ns))
    pub = e.find("a:published", ns).text[:10]
    summ = " ".join(e.find("a:summary", ns).text.split())
    print(f"[{aid}] {pub} - {title}\n  {authors}\n  {summ}\n")
PY
```

## Step 1b - tool output

The bash block above writes results to `/tmp/arxiv-search.txt` and prints **nothing on stdout**. If the shell tool reports `(no output)` or empty stdout, **treat that as success** and proceed to Step 2 by reading `/tmp/arxiv-search.txt`. **Do not** re-run Step 1 with the same `<Q>` to "fix" the empty stdout - that just repeats work and risks rate limiting.

The only failure signal is a non-zero exit from `curl` or `python3` (e.g. network error, malformed XML). In that case, surface the error to the user and stop.

## Step 2 - present results

Use the `Read` tool on `/tmp/arxiv-search.txt` (preferred over piping through bash). If it contains `NO_RESULTS`, tell the user no papers matched and suggest broadening the query (drop field prefixes, remove `AND` clauses, try synonyms).

Otherwise show the user a numbered list of candidates with:

- arXiv id
- publication date
- title
- first 1-2 authors et al.
- a 1-sentence gloss of the abstract

Then **answer the user's actual question in the same turn**, using the candidates as evidence. If the user asked "where did X come from?", "what is the SOTA?", or any comparative/historical question, the list alone is not an answer - identify the seminal paper and the most relevant recent ones, and explain in prose. Only stop at the list when the user explicitly asked for a search/listing.

Do not auto-fetch full papers - wait for the user to pick one to dig into. When they do, hand off to the `arxiv-fetch` skill with the chosen id.

## Notes

- arXiv field prefixes for `search_query`: `ti:` (title), `au:` (author), `abs:` (abstract), `cat:` (category, e.g. `cs.LG`, `cs.CL`, `stat.ML`), `all:` (everything). Combine with `AND`, `OR`, `ANDNOT` (URL-encode spaces as `+`).
- **Build precise queries.** Avoid naked `all:` plus wide `OR` for ambiguous tokens - they pull in unrelated domains (e.g. searching for "RoPE" returns lifting ropes, flux ropes, positional games). Prefer `ti:`, `abs:`, and `cat:` combined with `AND`. Concrete patterns:
  - `ti:rotary+AND+abs:position+AND+cat:cs.LG`
  - `abs:%22rotary+position+embedding%22+AND+cat:cs.CL`
- **Acronym trap.** For short tokens (RoPE, MoE, RAG, etc.), restrict to `ti:` or `abs:` - or wrap as a quoted phrase - and constrain by `cat:` so hits stay in the right field.
- **Known id shortcut.** If the user already gave (or you have already identified) an arXiv id, skip broad search and use `id:<id>` once as `<Q>`. Do not loop the same `id:` lookup.
- **One query per user message.** Run Step 1 at most once for the same intent in the same turn; never repeat the same `search_query` URL. If results are already cached in `/tmp/arxiv-search.txt`, reuse them. Only re-search if the user changes the query.
- Be polite: arXiv asks for ~1 req/sec at most; never poll.
- The cached file `/tmp/arxiv-search.xml` is the raw Atom response if you need to re-parse it; `/tmp/arxiv-search.txt` is the rendered list.
