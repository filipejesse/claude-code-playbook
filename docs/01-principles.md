# 1. Principles

> Last verified: 2026-10-20 against the Claude Code docs (v2.1.304). Sources at the bottom.

Everything else in this playbook follows from six ideas. When a new feature ships, ask which of these it serves; if none, you probably don't need it.

## 1. Context is the scarce resource
Model quality drops as the context window fills, and every message re-sends the whole conversation. A session is cheapest and sharpest when its context holds only what the current task needs.
- `/clear` between unrelated tasks. After two failed corrections, `/clear` and re-prompt with what you learned; a clean session with a better prompt beats a long one full of dead ends.
- Push bulky work (searches, logs, test output) into subagents; they return summaries.
- Keep always-loaded files (CLAUDE.md, rules without `paths:`) short; put occasional knowledge in skills, which load on demand.

## 2. Verification closes the loop
Claude stops when the work *looks* done. A check it can run (tests, build, linter, a screenshot diff) turns "looks done" into pass/fail, which is what lets you walk away from a session. Ask for evidence, not assertions.

Escalate the gate as autonomy grows: a check in the prompt → a `/goal` condition → a Stop hook → an independent reviewer subagent.

## 3. Explore, plan, then code
For multi-file or unfamiliar changes, separate research and planning (plan mode, `Shift+Tab`) from implementation. For a change you could describe in one sentence, skip the plan. For big features, have Claude interview you and write a spec, then implement it in a fresh session.

## 4. Deterministic beats advisory
CLAUDE.md is guidance Claude usually follows. Hooks and permission rules always apply. Anything that must happen every time, or must never happen, belongs in settings and hooks, not in prose.

## 5. Parallelism needs isolation and a queue
Several agents only multiply output if they don't collide (worktrees), don't wait on you for every step (permissions, auto mode, verification), and always have a next task ready (a queue). Without the queue, parallel agents sit idle; without isolation, they overwrite each other.

## 6. Match the model and effort to the job
Use the strongest model for planning, architecture and review; a cheaper one for mechanical edits and high-volume subagent work. Lower effort for simple tasks. Usage limits are shared across everything you run, so spend the expensive capacity where judgement matters.

## Sources
- [Best practices](https://code.claude.com/docs/en/best-practices)
- [Manage costs effectively](https://code.claude.com/docs/en/costs)
- [How Claude remembers your project](https://code.claude.com/docs/en/memory)
