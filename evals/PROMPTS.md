# TEST PROMPTS

## `coder` agent

```txt
review this repo to determine next steps for its implementation
```

```txt
Before this project matures any further, our security team is working on an audit. We need to review security issues throughout this repo in order to plan for their remedies before we invest further into development.

Our frontend is client-side code, and connects to our payment backend which advertises a LangSmith Deployment whose middleware uses NIP-98 authentication and bitcoin micropayments to gate the costly usage of our agents (this is our business model).

Do a thorough review of this project with a red-team mineset in order to surface potential security vulnerabilities.
```

use in the `pi-mono` repo

```txt
When the user invokes a skill with /skill-name - does it have input arguments like prompts do?
```

## `deep research` team

### Tavily API

```txt
Explain the ongoing investigations in Minnesota regarding fraud related to day care centers run by the Somali community.
```

```txt
Tell me all about legal observers or "green hats"
```

```txt
Provide detailed information about the operation and context surrounding Maduro's capture.
```

```txt
Provide updates to the war with Iran and the situation in the straight of hormuz
```

```txt
tell me about hydrogen storage and energy technology - there seems to be a few companies working on it - but I thought it was all hype not likely to work vs electric batteries
```

### arXiv

```txt
I want to know where positional encoding came from - how it was discovered, and what the state of the art is.
```

```txt
What recent papers discuss multi-agent architecture or mention harness engineering?
```

## `talk` agent