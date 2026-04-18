# project ideas

### pdf digester

OCR.  likely a team.  breaks down PDFs by page, OCR's each, stores markdown / HTML result

resume a session to avoid re-computing PDF

### Voice memo digest

share sheet in iOS / android

iOS will transcribe

### "thinking" extension

Use a subagent call (spawn itself), and have it plan/think/step-back / "think step by step"

### plannenator extension

it has a webui!  I must reverse engineer and learn to use this

### the big idea

an agent, or team, "agent program", "workflow", "agent workflow" can be used on the CLi like any unix utility.

it will make writing shell programs easier.

The OS itself is the program... it is the product.

We have over-engineered the agent harness... as it's most basic yet fully capable is something like a ReACT agent like `pi`, vs some complex boiletplate library/framework like a LangGraph DAG.

the most pasic was unix, where they `|` pipe'd basic programs together

So if my `p` agents work in a similar fashion... then the most basid "agent program"

--- then I contradict myself

I don't need hundreds of line of boiletplate... I should be able to use a `.sh` script with natural language.  Agentix and unix-like primitives should be able to work well enough in order to build an arbitrary workflow.

What is the "boilerplate" was little more than the linux operating system primitives and natural language prompts.

symlinks all the way down.  Flat files are all you need.

This leads most easily to SELF REFINEMENT.  2026 is the year where we "trust fall into the agents."

---

define the output first, then work your way back from there.

What do you desire?  What do you need?  What are the intended results?  Then figure out how to COMPUTE those... and design your prompt is clear steps.  This is how you make a peanut butter sandwhich.

---

Pass a directory as the context or "environment" or "sandbox" as input.

Local files vs URLs.  URLs can only be accessed via API... curl, et al.  And that API does not always work with agents - CapTCha, ads, spam, page formatting, etc... it's difficult.  But a local file path is easy and deterministic.  A URL will return different results whether it's accessed via ($) tavily, SearXNG, playwright on Chrome vs Firefox... etc.

What if we did an `uv`-of-sorts where any URL was cache'd to the system and retrieved in the future if needed?

---

the webui of observability.. for session files and everything.

Can run a retrospective analysis on any run.. by the push of a button... with easily formatted results and Actions to remedy, rerun, propose prompt enhancement... etc.

---

We need intermediate files, artifacts, tmp files... etc... a type of side effect

An agent workflow is a long prompt (natural language program), with small programs in it for each subagent.

You can draw a flowchart of the natural language prompt's "programmatic flow"

---

a firejail on each agent / subagent!  Although, if an orchestrator

an "unhinged" agent that has full access to bash and disk.  It could take the entire system down.

---

`halp` read-only.  but we can use `bash` for "read only" like `uname -a` ... so this is a hard problem unless we whitelist.

---

how can we resume a workflow session?

---

a piped' `p` agent unix primitives would have a return type.. this is what is pipe'd

they may return a manifest.. they may set env vars, error code, return value, return type, side effects, etc...

---

this is nearly a new computing primitives... "agentic execution"

---

name each session.. but how can we do this automatically?  But when we resume and fork it just shows the human prompt.. so this is fine - we don't need this.

my confustion was about the session.json file... those are just dated without a real name - we don't see that in the UI so it's fine...

---

right click on a PDFs and use a Share Sheet on MacOS as well...!  First, let's integrate all of this into MacOS.

Also... let's use SUNSHINE as we're logged in and all of our Apple Data is sync'd anyways... my iOS phone is handicapped.

---

what if I take the output of a deepresearch agent and send it through a draft_refinement flow?

`echo "creatine" | deepresearch | draft_refinement > report-draft.md`

---

IMPORTANT:

the output of an agentic workflow may just be a directory... so I can shortcut/bookmark that in Finder / file explorer and there's my GUI.. it's just the OS itself.. no need to write my own GUI where flat files are all that I'm working on and the OS itself is already the product.. 'it just needs to be configured'

we already have finder and everything is files...

can't we make a custom icon with colors?  Make it a symlink..?  Put it on the dock or desktop?

Can't I use applescript as well?  Drag and drop a file into a folder... have a script run... then I can see the output with nice and neatly named folders with everything in there?  An inbox of sorts?  I can have mutliple workflows on it... one that cuts up the PDF... another that summarizes... a third that posts it onto nostr for me to consume later.

---

