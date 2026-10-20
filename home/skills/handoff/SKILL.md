---
name: handoff
description: Write or update HANDOFF.md so a fresh session (or another agent) can continue this work without re-discovery. Use before /clear, before stepping away, or when context is getting full.
---

Write `HANDOFF.md` at the root of the current working tree (the worktree, if in one). Overwrite the previous version; it describes the present, not a history.

Keep it under 60 lines, in this shape:

```markdown
# Handoff: <short task name>
Updated: <date and time> · Branch: <branch> · Last commit: <short sha + subject>

## Goal
<one or two sentences: what done looks like>

## State
- Done: <what is finished and verified, with the command that verified it>
- In progress: <what is half-done, and where>
- Not started: <remaining steps>

## Decisions
- <decision> because <reason>  (only ones a newcomer would otherwise re-litigate)

## Next steps
1. <the very next concrete action, with file paths>

## Gotchas
- <traps already hit: flaky tests, env quirks, wrong approaches already tried>
```

Then check whether `HANDOFF.md` is gitignored or committed in this repo and follow that convention; if neither is established, leave it uncommitted and say so. Finish by telling the user it is safe to /clear, and give the one-line prompt to resume: `Read HANDOFF.md and continue from Next steps.`
