# 5. Running work in parallel

> Last verified: 2026-10-20 against the Claude Code docs (v2.1.304).

Pick the lightest option that fits. Each step up adds throughput and also coordination cost and token spend.

| Need | Use | Isolation |
|---|---|---|
| Keep a big search or a log dig out of your context | **Subagent** (`use a subagent to…`, or a named one like `verifier`) | Separate context, same checkout |
| One change spread across many files | **`/batch <instruction>`**: splits it across 5–30 subagents, each in its own worktree | Worktree per subagent |
| Two or more independent tasks in one repo, you steering each | **`claude --worktree <name>`** in separate terminals | Worktree per session |
| Many tasks you dispatch and check on later | **Background sessions + agent view**: `claude --bg "…"`, `claude agents` | Worktree per session, automatic |
| Work across several repos at once | One background session per repo, `claude agents` to watch them all | Per repo |
| Scripted fan-out (migrations, audits) | `claude -p` in a loop with `--allowedTools` and `--permission-mode dontAsk` | Your choice |
| Sessions that coordinate among themselves | **Agent teams** (experimental, off by default) | Per teammate |

## Worktrees

```bash
claude --worktree feature-auth     # new worktree + branch worktree-feature-auth
claude --worktree "#1234"          # check out PR 1234 into its own worktree
```

- Worktrees live in `.claude/worktrees/<name>/`; add that path to `.gitignore`.
- A fresh worktree has no gitignored files. List the ones it needs (`.env`…) in `.worktreeinclude`; `/bootstrap-project` creates it.
- By default worktrees branch from the remote default branch. Set `"worktree": {"baseRef": "head"}` to branch from your current work instead.
- Each worktree needs its own dependency install, so expect a setup cost per worktree in big projects.
- "Yes, don't ask again" approvals in a worktree are saved to the main checkout and apply to all its worktrees.

## Agent view: the control room

```bash
claude --bg --name fix-flaky "investigate the flaky SettingsChangeDetector test"
claude --agent reviewer --bg "review PR 1234 against its issue"
claude agents                      # one screen: working / needs input / ready for review
```

In agent view: `Space` peeks at a session and lets you reply without attaching, `Enter` attaches, `Ctrl+T` pins, `Ctrl+X` stops. Inside any session, `/bg` sends it to the background. Dispatched sessions move into their own worktree before editing, then commit, push and may open a draft PR.

This is research preview: shortcuts can change. Check `claude agents --help` after updates.

## Patterns that pay off

- **Writer / reviewer.** One session implements; a second, with fresh context, reviews the diff against the plan. The playbook's `reviewer` subagent does this inside one session.
- **Test-first split.** One session writes failing tests from the spec; another makes them pass.
- **Spec, then fan out.** Plan a feature in one session into independent issues, then dispatch one background session per issue with `/next-task <n>`.
- **Name everything.** `--name` and `/rename` make agent view and `--resume` readable.

## Limits to respect

- Every session and subagent draws from the same usage allowance (see [7. Cost and usage](07-cost-and-usage.md)). Five parallel sessions burn the window roughly five times faster.
- Parallel sessions in one worktree overwrite each other. Use worktrees whenever more than one session edits the same repo.
- Merge conflicts grow with parallelism. Keep tasks small and in different areas, and merge often.

## Sources
- [Run parallel sessions with worktrees](https://code.claude.com/docs/en/worktrees)
- [Agent view](https://code.claude.com/docs/en/agent-view)
- [Subagents](https://code.claude.com/docs/en/sub-agents)
- [Best practices: automate and scale](https://code.claude.com/docs/en/best-practices#automate-and-scale)
