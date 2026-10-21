# 9. Autopilot: build a project unattended, through usage limits

> Last verified: 2026-10-20 against the Claude Code docs (v2.1.304).

Goal: describe a project once, then let Claude work until it's done, with no questions and no babysitting. When the usage window runs out, Claude waits for it to reset and continues on its own.

## Requirements

- A Claude Pro, Max or Team subscription logged in to Claude Code. API-key billing, usage-based Enterprise plans and accounts with usage credits on are refused (see [Before a long run](#before-a-long-run)).
- Claude Code v2.1.259 or later, in a folder you have trusted, with hooks enabled: `/goal` is a hook, so `disableAllHooks` or managed `allowManagedHooksOnly` turn it off.
- `bash`, `git`, `jq`; `gh` logged in for the final PR.
- Install with `./install.sh`, or `./install.sh --autopilot-only` for just the pieces autopilot uses.
- First runs belong in a VM, container or disposable account: see the warning in the [README](../README.md#before-your-first-run).

## How to use it

```text
mkdir ~/Repos/my-app && cd ~/Repos/my-app && claude
> /autopilot-spec a personal finance tracker that imports bank CSVs and shows monthly charts
```
Answer the interview. That is the only time Claude asks you anything. It writes `SPEC.md` (acceptance criteria plus one verification command), scaffolds the repo and commits. Then:

```bash
autopilot start        # runs in the background, survives closing the terminal
autopilot log          # follow what it's doing
autopilot status       # state, branch, commits, PROGRESS.md
autopilot stop         # stop; `autopilot start` later resumes the same session
```

It ends when Claude writes `AUTOPILOT_DONE.md`, with every criterion, the command that proved it and the PR URL, or `AUTOPILOT_BLOCKED.md` if only a human can unblock it (a credential, a paid service, a product decision the spec can't settle). The work is on an `autopilot/<date>` branch. If the repo has a GitHub remote, Claude opens a PR with its PR doc (Mermaid sequence and other diagrams); review it and merge. Claude never merges.

## How it works

| Need | Mechanism |
|---|---|
| Keep working turn after turn without you | `/goal <condition>`: after each turn a separate evaluator checks the condition, and Claude continues until it's met. The condition requires every SPEC.md criterion verified plus `AUTOPILOT_DONE.md`. |
| Only the subscription window, never paid credits | Before starting and every 15 min during the run, `claude -p /usage` must show subscription billing with no usage-credits row. Otherwise autopilot refuses to start, or stops and writes `AUTOPILOT_BLOCKED.md`. There is no Claude Code setting that refuses credits, so this check is the guard. |
| Never stop to ask | `--permission-prompts none` and `--disallowedTools AskUserQuestion`, and the goal tells Claude to decide, log the choice in `DECISIONS.md`, and continue. |
| No permission prompts | `--permission-mode auto` (classifier-reviewed), plus the playbook's deny rules and guard hook, plus project allow rules written by the spec step. |
| Survive the usage limit | `CLAUDE_CODE_RETRY_WATCHDOG=1`: the request waits until the limit's reset time, for both the 5-hour and the weekly windows, then the run continues in the same process. On v2.1.305+, `..._USAGE_LIMIT_RECHECK_MS` (set to 10 min) also checks whether the limit lifted early. |
| Limit hit and the process exits anyway | The runner reads the `rate_limit_event` (`status: rejected`, `resetsAt`) from the stream and sleeps until the reset before resuming. This doesn't count as a failed attempt. |
| Survive crashes and errors | The runner relaunches `claude --resume <same session>` with the goal, with backoff (1 → 15 min), up to `AUTOPILOT_MAX_RESTARTS` times. Three runs in a row with no repository change mark it blocked instead of looping forever. |
| Machine sleeping | `caffeinate` (macOS) or `systemd-inhibit` (Linux) for as long as the run lasts. Keep the laptop plugged in; closing the lid still sleeps most Macs unless an external display is attached. |
| Context filling up | Auto-compaction plus `PROGRESS.md` and `DECISIONS.md` on disk, so nothing important lives only in context. |

Why not just leave an interactive session open? Interactive sessions do continue automatically after a usage limit. But they stop re-arming after two consecutive limit hits, they don't wait for resets more than 24 hours away (the weekly limit), and they need you to press Enter after the machine slept through the reset. They also stop at any permission prompt. The headless watchdog has none of those gaps.

## Before a long run

- **Usage credits.** Autopilot refuses to run while usage credits are on, because with credits on the plan limit doesn't stop requests: they continue on paid credits. On Pro/Max turn them off at claude.ai/settings/usage. On Team/Enterprise only an Owner can, and on usage-based Enterprise plans every token is paid, so autopilot refuses there too. `AUTOPILOT_ALLOW_CREDITS=1` overrides, at your own cost.
- **Weekly window.** One autonomous run can consume a large share of the weekly allowance that your interactive work also needs. Start big runs when you can spare it, or set `AUTOPILOT_MODEL=sonnet`.
- **Work accounts.** If your org disables auto mode, run with `AUTOPILOT_PERMISSION_MODE=dontAsk`. The spec step's allow rules then decide what can run, and anything else is denied rather than prompted. Use `bypassPermissions` only inside a disposable VM or container.
- **Scope.** The goal allows pushing its own branch and opening a PR. It forbids pushing to the default branch (the guard hook also blocks it), merging, deploying, publishing and spending money.

## Sources
- [Keep Claude working toward a goal](https://code.claude.com/docs/en/goal)
- [Wait for a usage limit to reset](https://code.claude.com/docs/en/interactive-mode#wait-for-a-usage-limit-to-reset)
- [Environment variables: `CLAUDE_CODE_RETRY_WATCHDOG`](https://code.claude.com/docs/en/env-vars)
- [Headless mode](https://code.claude.com/docs/en/headless)
