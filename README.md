# Claude Code Playbook

A living, practical setup guide for [Claude Code](https://code.claude.com/docs): the principles, plus an installable baseline that configures any machine or VM the same way in one command.

It's built around three goals:
1. **Each project steers Claude well:** lean, layered context, so every session starts knowing how to build, test and ship the repo.
2. **Agents keep working while you have capacity:** isolation, a task queue, unattended verification and alerts, so parallel sessions don't stall.
3. **Resources aren't wasted:** context hygiene, the right model per job, and measuring before optimizing.

> Last reviewed: **2026-10-20** against Claude Code **v2.1.304**. See [docs/last-reviewed.md](docs/last-reviewed.md) and [how this guide stays current](docs/08-staying-current.md).

## Quick start

```bash
git clone https://github.com/filipejesse/claude-code-playbook ~/claude-code-playbook
cd ~/claude-code-playbook
./install.sh --dry-run   # see exactly what will change
./install.sh             # apply (add --install-claude on a fresh VM)
```

Then, in each repository you work on, start `claude` and run `/bootstrap-project`.

Needs `bash`, `git` and `jq`. Works on macOS and Linux (including WSL2 and remote VMs). Reversible with `./install.sh --uninstall`.

## What gets installed

All of it lives in [`home/`](home/), which is symlinked to `~/.claude/playbook`, so `git pull` updates every machine.

| Piece | What it does |
|---|---|
| [`CLAUDE.md`](home/CLAUDE.md) | A short global working agreement: verify with evidence, stay in scope, context hygiene, safe git. Imported from your `~/.claude/CLAUDE.md`; your own content stays. |
| [`settings.json`](home/settings.json) | Merged into yours, never replacing it. Adds allow rules for safe git/`gh` inspection; deny rules for `.env` files, SSH/cloud credentials and force-push; the hooks and status line below. |
| [`hooks/guard-bash.sh`](home/hooks/guard-bash.sh) | Blocks recursive `rm` of `/`, `~`, `.` or `*`, and force-pushes. A last line of defence. |
| [`hooks/notify.sh`](home/hooks/notify.sh) | Desktop alert when a session needs you or finishes, so parallel agents don't sit idle. |
| [`statusline.sh`](home/statusline.sh) | Model · repo@branch · context % (color-coded) · cost · plan windows. |
| Agents: [`reviewer`](home/agents/reviewer.md), [`verifier`](home/agents/verifier.md), [`researcher`](home/agents/researcher.md) | Fresh-context review against the plan; checks with evidence and short output; sourced research. |
| Skills: [`/bootstrap-project`](home/skills/bootstrap-project/SKILL.md), [`/handoff`](home/skills/handoff/SKILL.md), [`/next-task`](home/skills/next-task/SKILL.md) | Set up a repo for Claude; hand work to a fresh session; pull, implement, verify and PR the next queued task. |
| [`autopilot`](home/bin/autopilot) + [`/autopilot-spec`](home/skills/autopilot-spec/SKILL.md) | Describe a project once, then Claude builds it unattended until every acceptance criterion is verified, waiting out usage limits and resuming on its own. Linked to `~/.local/bin/autopilot`. |
| [`loop.md`](home/loop.md) | What a bare `/loop` does: continue → tend the PR → next task → stop. |
| [`templates/project/`](home/templates/project/) | Project `CLAUDE.md`, `.claude/settings.json`, `.worktreeinclude`, `TASKS.md`. |

## The guide

1. [Principles](docs/01-principles.md): the six ideas everything else follows from
2. [Setting up a machine](docs/02-setup.md): install, VMs, work and personal accounts, Enterprise caveats
3. [Context engineering](docs/03-context.md): CLAUDE.md layers, rules, skills, handoffs
4. [Permissions, autonomy and safety](docs/04-safety.md): modes, rules, sandbox, hooks
5. [Running work in parallel](docs/05-parallel.md): subagents, worktrees, `/batch`, agent view
6. [Keeping agents busy](docs/06-keeping-agents-busy.md): queues, `/loop`, `/goal`, scheduled tasks, usage windows
7. [Cost and usage](docs/07-cost-and-usage.md): what drives spend and the levers that matter
8. [Staying current](docs/08-staying-current.md): how this repo keeps itself up to date
9. [Autopilot](docs/09-autopilot.md): build a whole project unattended, through usage limits

## A day with this setup

```text
morning   claude (Opus, plan mode) → turn the next feature into 5-10 `agent-ready` issues
          claude --bg --model sonnet "/loop /next-task"      # one worker per repo
          claude agents                                       # watch: needs input / ready for review
daytime   alerts fire → answer questions from agent view, review PRs with the evidence attached
evening   /schedule a nightly cloud run of /next-task for the repos that allow it
weekly    /refresh-guide in this repo → review the PR → git pull everywhere
```

## Tests

```bash
tests/run.sh   # runs the installer, merge, uninstall and hooks against a throwaway HOME
```

CI runs the same suite on Ubuntu and macOS.

## License

[MIT](LICENSE)
