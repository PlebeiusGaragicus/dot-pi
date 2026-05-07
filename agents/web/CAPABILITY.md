# web

## Capability

Find, inspect, extract, and synthesize live web or academic sources using configured search, browser-control, and research skills. Structural tools are `ls`, `read`, `find`, `grep`, and `bash`; research behavior comes from linked skills such as Tavily search, arXiv search/fetch, and browser-control when available.

## Use When

- A workflow needs fresh source discovery, URL inspection, or citation-backed synthesis.
- The MAS needs source candidates, relevance notes, page extraction, screenshots, or browser evidence.
- A task requires external web or arXiv information beyond files already in the working directory.
- A deep research workflow needs either a source scout or one-source collector behavior.

## Inputs

- A focused research question or extraction target.
- Optional constraints such as date range, source type, number of sources, or required URLs.
- Explicit artifact paths when source notes, captures, or screenshots should be saved.
- For source collection: one URL, title, relevance note, desired `sources/<slug>.md` path, and desired screenshot path.

## Outputs

- Concise findings with source URLs.
- Source lists, relevance notes, extracted page details, and uncertainty or conflict notes.
- Artifact paths when files or screenshots are explicitly requested.
- For source scout tasks: a numbered source list with title, URL, source type, relevance note, access risk, search queries used, and gaps.
- For source collector tasks: a collected source file, optional screenshot, summary, approximate captured content, and issues encountered.

## Artifact Behavior

- Does not create files unless explicitly instructed.
- Uses the current working directory for requested source notes, screenshots, or captures.
- Should keep large handoffs in files and return paths plus concise operational notes.
- For deep research collection, create one `sources/<slug>.md` per URL with YAML frontmatter for `url`, `title`, `date_fetched`, and `screenshot`.
- Do not collapse multiple source captures into a single aggregate notes file unless explicitly asked.

## Safety And Limits

- Cite URLs for web-derived claims.
- Stop and report missing provider keys, browser-control failures, rate limits, or inaccessible pages instead of retrying indefinitely.
- Ask before submitting forms, posting, purchasing, deleting, or mutating external systems.
- Do not make filesystem edits beyond explicitly requested research artifacts.
- If access fails, preserve the failure as an issue note or screenshot when useful; do not invent source content.
- Parallel collector batches should stay small enough for the orchestrator's `tasks[]` limit.
