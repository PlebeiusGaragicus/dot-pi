---
name: tavily-search
description: Search the web with for primary sources, news, events and information.
disable-model-invocation: false
---

# Tavily Web Search

This skill teaches you how to use the `tavily_search` tool effectively. Use it whenever the user's question needs information from the live web - non-academic sources, current events, vendor or product docs, blog posts, or cross-checking a claim from a paper against the broader internet.

## Tool Capabilities

`tavily_search` accepts these parameters:

| Parameter | Use When |
|-----------|----------|
| `query` (required) | Your search phrase - be specific, include key terms, prefer noun phrases over questions |
| `max_results` | 3-5 for quick answers, 10-20 for comprehensive research (default 5, max 20) |
| `topic: "general"` | Default, broad coverage across all topics |
| `topic: "news"` | Recent events and trending topics |
| `topic: "finance"` | Stock prices, financial data, market info |
| `time_range: "day"` | Very recent events (past 24 hours) |
| `time_range: "week"` | Recent developments (past week) |
| `time_range: "month"` | Monthly trends, recent history |
| `time_range: "year"` | Annual patterns, yearly context |

The tool always requests full raw page content and never asks Tavily for a pre-synthesized answer - you do the synthesis yourself from the raw excerpts.

## Search Strategy

### For Simple Questions

One direct query is usually enough:

```ts
tavily_search({ query: "What is the capital of France?" })
```

Extract the answer from the cited sources in the result.

### For Research Topics

1. **First search**: broad query to map the territory.
2. **Follow-up searches**: refine based on what the first batch surfaced - narrow phrasing, add a topic, or constrain by time.
3. **Stop when you have consensus**: 2-4 searches are usually enough; further searches mostly cost credits without changing your synthesis.

### For Time-Sensitive Information

Always pair the query with a `time_range`:

- Breaking news / today's events: `time_range: "day"` and `topic: "news"`
- Recent developments: `time_range: "week"` or `"month"`
- Historical context: omit `time_range`, broaden the query

## Output Format

The tool returns:

```
## Results (N)     # Array of search results
  ### [Title]      # Result title
  [URL]            # Source URL
  [Content]        # Snippet content
  ---
  Raw excerpt:     # Full page content - this is what you analyze and quote from
  [text...]
```

Raw excerpts are truncated to ~2000 chars per result; if you need more from a specific page, fetch it directly with `bash` + `curl` rather than re-searching.

## Workflow

### Step-by-Step Search Process

1. **Analyze the query**: identify key concepts, intent, and any time-sensitive elements.

2. **Plan searches**: decide how many targeted searches you need (usually 2-4 for research, 1 for simple lookups). Break complex topics into focused subqueries.

3. **Execute searches**:
   - Start broad, then narrow.
   - Add `time_range` when freshness matters.
   - Pick the right `topic` (news vs general vs finance) up front - changing it mid-thread wastes credits.

4. **Refine based on results**:
   - If results are off-topic, rephrase rather than re-searching the same thing.
   - If results are stale, add or tighten `time_range`.
   - If results are sparse, broaden phrasing or drop a topic constraint.

5. **Synthesize**: combine raw excerpts from multiple sources, look for consensus, flag disagreements.

6. **Cite sources**: include URLs from results and quote directly from raw excerpts where it matters.

### Advanced Search Patterns

**Pattern 1: Multi-Query Research**

```ts
// Query 1: broad overview
tavily_search({ query: "topic X" })

// Query 2: specific angle, refined from what Query 1 surfaced
tavily_search({ query: "topic X specific aspect" })
```

**Pattern 2: Time-Sensitive News**

```ts
tavily_search({
  query: "breaking event",
  topic: "news",
  time_range: "week"
})
```

**Pattern 3: Triangulating a Paper Claim**

When the user is reading a paper and you want to check whether a claim has held up or been contested:

```ts
tavily_search({
  query: "<paper title or specific claim> critique replication",
  time_range: "year"
})
```

## Quality Checklist

- [ ] At least 2-4 searches for multi-faceted questions; 1 is fine for simple lookups
- [ ] Source URLs included in your final answer, with direct quotes from raw excerpts where relevant
- [ ] Conflicting information across sources is called out, not silently averaged
- [ ] When freshness matters, `time_range` was set
- [ ] You did the synthesis - you did not parrot a summary from a single source

## Standard Workflow

When the user asks a question that warrants web search:

1. Search 1-4 times depending on complexity.
2. Synthesize results into a clear answer.
3. Quote directly from raw excerpts when precision matters.
4. Cite source URLs.
