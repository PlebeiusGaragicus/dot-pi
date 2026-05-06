This `mas` agent will be our "top level orchestrator" and act as the "dispatcher" for our multi-agent system.  Our `dot-pi` system has several "core" simple agents:

- ask - no tools (chat only - Q/A, semantic evaluation, used as a judge for PASS/FAIL, etc)
- scout - read, ls, find, grep (read only)
- writer - read, ls, find, grep, write, edit (read and edit)
- coder - read, ls, find, grep, write, edit, bash (read, edit and run commands)
- web - read, ls, find, bash (read files + web search and browser-control skills)

These agents will be used as subagents in our MAS, each given specific instructions that fit their capabilities and tool access.  This divergest from our earlier design where each MAS was independently defined and included a curated list of botique subagents.  To simplify this system and create maximize re-use of our core agents, MAS workflows like `deepresearch` are now reduced to a prompt template.  This allows the user to invoke our `mas` agent and use a `/deepresearch` prompt template injection into the chat which will start instruct our `mas` agent to begin dispatching subagents, as needed.
