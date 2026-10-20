# 6. Keeping agents busy while you have capacity

> Last verified: 2026-10-20 against the Claude Code docs (v2.1.304).

Idle agents usually mean one of three things: no next task is ready, the agent is waiting on you for a decision or an approval, or you didn't notice it finished. Fix all three and agents keep working until your usage window runs out.

## 1. Always have a ready queue

Agents can't stay busy on vague intentions. They need small, well-specified tasks waiting.

- **GitHub issues labelled `agent-ready`**: the recommended queue. Claiming with a label works across worktrees, machines and cloud sessions. Each issue should be one PR: the outcome, where to look, how to verify.
- **`TASKS.md`**: fine for a single agent on one machine (template in `home/templates/project/`).
- **Fill the queue in planning sessions.** Spend an Opus planning session turning a feature into 5–10 independent issues. That is the highest-leverage use of your attention.

`/next-task` (installed by the playbook) takes the next ready task, claims it, implements it on a branch, verifies, runs the reviewer, opens a PR, and updates the queue. Ambiguous tasks get a question and a `blocked` label instead of a guess.

## 2. Remove the reasons agents wait on you

- **Permissions.** Auto mode plus allow rules for each project's check commands (see [4. Safety](04-safety.md)). Long runs: `/sandbox`.
- **Verification it can run itself.** A test command in the project CLAUDE.md, a `/goal` condition, or a Stop hook. Without one, every task ends with "please check".
- **Decisions up front.** Interview-then-spec for big work, so implementation sessions don't stop to ask.

## 3. Notice when an agent stops

- The playbook's `notify.sh` hook sends a desktop alert on "needs input" and on every finished turn.
- `claude agents` groups sessions into *Needs input*, *Working* and *Ready for review*. Check it whenever an alert fires.
- The status line shows context % per session; above ~60%, have the agent `/handoff` and start fresh.

## Running unattended

| Tool | Runs where | Good for |
|---|---|---|
| `/loop` (interval optional) | Your open session (survives `/bg`) | Draining the queue with `/loop /next-task`, babysitting a PR. A bare `/loop` uses `~/.claude/loop.md`, which the playbook installs: continue work → tend the PR → next task → stop. Recurring loops expire after 7 days. |
| `/goal <condition>` | Your session | Keeping one task going until a checkable condition holds ("all tests in tests/api pass"). |
| Background session | Your machine, no terminal needed | `claude --bg "/loop /next-task"` turns a repo into a worker. |
| Desktop scheduled tasks | Your machine, app open | Local recurring jobs that need local files. |
| Cloud scheduled tasks (`/schedule`) | Anthropic cloud, laptop closed | Nightly queue draining, PR review on open, weekly maintenance. Minimum interval 1 hour. Needs a claude.ai login, and on Team/Enterprise the org must allow scheduled tasks and cloud sessions. |

Example: drain the queue overnight in the cloud.
```text
/schedule every weeknight at 1:07am in <org>/<repo>: run /next-task until three tasks are done or the queue is empty, then stop
```
For cloud runs the skill must live in the repo, since a cloud session only sees a fresh clone. Copy `next-task` into the repo's `.claude/skills/`, or write the steps into the prompt.

## Whole projects, unattended

For a new project with a clear end state, use [Autopilot](09-autopilot.md): one interview, then Claude works until the spec is verified, waiting out usage limits by itself.

## Using the capacity you have (without wasting it)

On Team and Enterprise plans, each seat has an allowance that resets on a rolling **5-hour window** and a **weekly** window, shared with Claude chat. "Don't let agents rest" means aiming parallel work at the windows:

- Start your heaviest parallel batch early in a 5-hour window, not at its end.
- Check `/usage`: it shows the plan bars, which skills, subagents and MCP servers are eating usage, and fixes you can apply with `f`.
- When you hit a limit, Claude Code can wait and continue the interrupted task automatically after the reset (`/rate-limit-options`).
- Spend Opus on planning and review, and run workers on Sonnet: `claude --bg --model sonnet …`, or per subagent with `model:` in its frontmatter.
- Don't run loops that do nothing. An idle `/loop` still sends your full context every time it fires; end it when the queue is empty.

## Sources
- [Run prompts on a schedule](https://code.claude.com/docs/en/scheduled-tasks)
- [Cloud scheduled tasks](https://code.claude.com/docs/en/routines)
- [Agent view](https://code.claude.com/docs/en/agent-view)
- [Manage costs: Teams and Enterprise](https://code.claude.com/docs/en/costs#claude-for-teams-and-enterprise)
