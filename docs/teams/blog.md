# Blog Team

Blog post research, writing, and editing.

## Agents

### researcher

| Field | Value |
|-------|-------|
| Tools | read, grep, find, ls, bash |
| Skills | searxng, playwright |

Gathers comprehensive background material on a topic -- key facts, code examples, sources, and angle suggestions -- so the writer can produce a well-informed post.

### writer

| Field | Value |
|-------|-------|
| Tools | all defaults |
| Skills | none (`no-skills: true`) |

Drafts blog posts from research material. Produces conversational but authoritative prose with clear structure, concrete examples, and scannable sections. Targets 800-1500 words by default.

### editor

| Field | Value |
|-------|-------|
| Tools | read, grep, find, ls |
| Skills | none (`no-skills: true`) |

Reviews drafts for accuracy, structure, clarity, engagement, completeness, and length. Can verify code snippets against the actual codebase. Returns a verdict, required changes, and optionally a revised draft.

## Prompts

### `/research-write-edit`

Full blog workflow:

1. **researcher** gathers material on the topic
2. **writer** drafts the post from the research
3. **editor** reviews and polishes the draft

```
/research-write-edit how we built our agent team system with pi
```

### `/write-and-edit`

Iterative writing workflow (skips research):

1. **writer** drafts the post
2. **editor** reviews it
3. **writer** applies editorial feedback

```
/write-and-edit 5 tips for effective code review
```

## Usage

```bash
# Via p
p blog "Write a post about our migration to TypeScript"

# With research workflow
p blog
> /research-write-edit the architecture of this project
```
