# 7. Cost and usage

> Last verified: 2026-10-20 against the Claude Code docs (v2.1.304).

Every request re-sends the conversation. Cost is driven by **how much context you carry, how many agents carry it, and which model reads it**. Typing less matters very little.

## Measure first

| Command | Tells you |
|---|---|
| `/usage` | Plan bars (5-hour and weekly windows), attribution to skills, subagents, MCP servers and loops, and recommendations. Press `f` to apply the ones Claude can. |
| `/context` | What fills the current context window: system, CLAUDE.md, MCP tools, files, messages. |
| `/insights` | An HTML report on how you work: friction points and suggestions, across up to 200 recent sessions. Run it monthly. |
| Status line | Context % live (the playbook's shows model, branch, context %, cost when relevant, and plan windows when reported). |

## The big levers, in order of impact

1. **`/clear` between unrelated tasks.** Stale context is paid for on every later message. `/clear` costs nothing. `/compact` is itself a large request, so use it only when you need continuity.
2. **Lean always-loaded context.** Keep CLAUDE.md files under ~80–200 lines, and move occasional procedures to skills. `/usage` flags oversized CLAUDE.md files.
3. **Right model for the job.** Opus for architecture, planning and review; Sonnet for most implementation; Haiku for high-volume simple subagent work. Switching model mid-session rebuilds the prompt cache, so pick at the start.
4. **Effort.** `/effort` lower for routine tasks. Thinking tokens are billed as output.
5. **Subagents for verbose work.** Test runs and log analysis in a subagent keep the main context small. Give cheap subagents a cheap `model:`.
6. **CLI over MCP.** `gh`, `aws` and other CLIs add nothing to context until used. Disable MCP servers you aren't using (`/mcp`).
7. **Specific prompts.** "Add input validation to `login()` in `auth.ts`" reads two files; "improve auth" reads fifty.

## Prompt caching, briefly

Claude Code caches the stable prefix of each request automatically. You keep the cache warm by not changing that prefix mid-session: same model, same MCP servers, same tools. Coming back after the cache lifetime has expired re-processes the whole context, so after a long break, a `/handoff` plus `/clear` can be cheaper than resuming a huge session. `/usage` shows cache hit rate and misses.

## Things that quietly burn usage

- Long sessions left open, where each question re-reads everything.
- `/loop` and scheduled tasks firing with nothing to do.
- Many parallel sessions or agent teams (an agent team in plan mode uses about 7× the tokens).
- Idle check-ins from an active `/goal` while background work runs.

## For organizations

Enterprise admins see spend and adoption in org analytics and can cap usage-credit spend per member. If your figures need to match a negotiated price, ask for the `modelPricing` managed setting. Developers can't set it themselves.

## Sources
- [Manage costs effectively](https://code.claude.com/docs/en/costs)
- [Prompt caching](https://code.claude.com/docs/en/prompt-caching)
- [Model configuration](https://code.claude.com/docs/en/model-config)
