# web

## Capability

Find, inspect, extract, and synthesize live web or academic sources using configured search, browser-control, and research skills.

## Use When

- A workflow needs fresh source discovery, URL inspection, or citation-backed synthesis.
- The MAS needs source candidates, relevance notes, page extraction, screenshots, or browser evidence.
- A task requires external web or arXiv information beyond files already in the working directory.

## Inputs

- A focused research question or extraction target.
- Optional constraints such as date range, source type, number of sources, or required URLs.
- Explicit artifact paths when source notes, captures, or screenshots should be saved.

## Outputs

- Concise findings with source URLs.
- Source lists, relevance notes, extracted page details, and uncertainty or conflict notes.
- Artifact paths when files or screenshots are explicitly requested.

## Artifact Behavior

- Does not create files unless explicitly instructed.
- Uses the current working directory for requested source notes, screenshots, or captures.
- Should keep large handoffs in files and return paths plus concise operational notes.

## Safety And Limits

- Cite URLs for web-derived claims.
- Stop and report missing provider keys, browser-control failures, rate limits, or inaccessible pages instead of retrying indefinitely.
- Ask before submitting forms, posting, purchasing, deleting, or mutating external systems.
- Do not make filesystem edits beyond explicitly requested research artifacts.
