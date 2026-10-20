---
name: next-task
description: Pull the next ready task from the project's queue (GitHub issues labelled agent-ready, or TASKS.md), claim it, implement it on its own branch, verify, and open a PR. Use to keep an agent productive without a human picking each task, alone or under /loop or a background session.
---

Work exactly one task from the queue, end to end. If `$ARGUMENTS` names an issue number or task, take that one instead of picking.

## 1. Pick and claim
**GitHub queue** (when the repo has issues labelled `agent-ready`):
- `gh issue list --label agent-ready --state open --json number,title,labels,assignees --limit 20`
- Skip issues labelled `agent-claimed` or `blocked`. Take the oldest remaining one, unless one is labelled `priority`.
- Claim it before doing anything else: `gh issue edit <n> --add-label agent-claimed` and comment `Claimed by Claude Code on <hostname>, branch <branch>`. If the label is already there when you re-check, pick another issue.

**Local queue** (`TASKS.md`, single agent only): take the first unchecked item under `## Ready`, move it to `## In progress` with today's date.

If the queue is empty, say so in one line and stop. Do not invent work.

## 2. Do the work
- Work in a worktree or a new branch named `agent/<issue-or-slug>`, never on the default branch.
- If the task is ambiguous or too large for one PR, don't guess: comment on the issue (or annotate TASKS.md) with the specific question or a proposed split, label it `blocked`, remove `agent-claimed`, and pick the next task.
- Follow the project's CLAUDE.md. Plan first if it touches several files.

## 3. Verify, then ship
- Run the project's checks; delegate long runs to the `verifier` subagent. Fix failures at the root.
- For non-trivial changes, run the `reviewer` subagent against the issue text and fix real findings.
- Commit, push the branch, and open a PR that links the task (`Closes #<n>`) and includes the verification evidence.
- Update the queue: on GitHub, replace `agent-ready` with `agent-pr-open`; in TASKS.md move the item to `## Review` with the PR link.

## 4. Report
One short block: task, PR link, checks run and their results, anything left for a human. Then stop; the caller (/loop, a scheduled task, or the user) decides whether to take another task.
