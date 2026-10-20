# 4. Permissions, autonomy and safety

> Last verified: 2026-10-20 against the Claude Code docs (v2.1.304).

Agents that ask permission for every step don't run in parallel, because they all wait on you. Agents with no limits are a liability. The balance: let routine work flow, put hard stops on the irreversible, and verify results instead of approving each step.

## Permission modes

| Mode | Use it for |
|---|---|
| **auto** (default for interactive sessions since v2.1.283) | Day-to-day work. A classifier reviews actions and blocks risky ones (scope escalation, unknown infrastructure, actions driven by hostile content). |
| **plan** | Exploring and designing before any edit. |
| **default / Manual** | Unfamiliar or sensitive repos where you want to approve each edit and command. |
| **acceptEdits** | Accepts file edits without asking but still asks for commands. |
| **dontAsk** | Unattended scripts: only pre-approved tools run, everything else is denied. Pair with `--allowedTools`. |
| **bypassPermissions** | Only inside a disposable, isolated container or VM. Never on your workstation. |

`Shift+Tab` cycles modes in a session; `--permission-mode <mode>` sets it at launch. If auto mode isn't available on your work account, the org has turned it off: rely on allow rules plus `/sandbox` instead. `/auto-mode-setup` (v2.1.304+) reads your project and recent sessions to configure auto mode for it.

## Permission rules

Rules live in `permissions.allow | ask | deny` in any settings file and merge across levels. Evaluation is **deny → ask → allow**; the first match wins and specificity doesn't matter.

```json
"allow": ["Bash(npm run test *)", "WebFetch(domain:docs.python.org)"],
"deny":  ["Read(**/.env)", "Read(~/.ssh/**)", "Bash(git push --force *)"]
```

Path anchors are a common trap:
- `Read(**/.env)` and `./path`: relative to the working directory, so it works in every project from user settings.
- `~/path`: home directory. `//path`: absolute path.
- A single leading `/` anchors at the **settings file's** location, not the filesystem root.
- A `!` pattern in a deny list carves exceptions: `Read(!**/.env.example)`.

Bash rules match the command text after Claude Code splits compound commands and strips wrappers; they don't follow aliases or scripts. For enforcement that doesn't depend on command text, use the sandbox.

**What the playbook installs:** allow rules for read-only git and `gh` inspection plus local commits; deny rules for `.env` files (with `.env.example`-style exceptions), SSH/AWS/GPG credentials, the `gh` token file and `~/.netrc`, and force-push. Project-specific allows (your test and lint commands) belong in each repo's `.claude/settings.json`, which `/bootstrap-project` writes.

## Sandbox

`/sandbox` enables OS-level filesystem and network isolation for Bash commands (macOS, Linux and WSL2; not native Windows). Sandboxed commands can run without prompts inside the boundaries you allow. It is the strongest local control and worth turning on for long unattended runs.

## Hooks: the deterministic layer

Hooks are scripts that run at lifecycle events. Exit code `2` from a `PreToolUse` hook blocks the call even when an allow rule would permit it; a `Stop` hook exiting `2` sends Claude back to work (for example "tests must pass first").

The playbook installs two:
- `guard-bash.sh` (PreToolUse/Bash): blocks recursive `rm` on `/`, `~`, `$HOME`, `.` or `*`, and force-pushes. It's deliberately short, a last line of defence that never gets in the way of normal work.
- `notify.sh` (Notification and Stop, async): a desktop alert when a session needs you or finishes a turn. It's what makes parallel sessions practical (see [6. Keeping agents busy](06-keeping-agents-busy.md)). Set `PLAYBOOK_NOTIFY_ON_STOP=0` to only get alerts when input is needed.

Good additions per project: a PostToolUse hook that runs the formatter after edits, or a Stop hook that runs the fast test suite.

## Non-negotiables

- Secrets never go in CLAUDE.md, prompts, or this repo. Keep them in env files that are denied to reads, or in a secret manager.
- Production access is a human step. Deny deploy commands in project settings.
- Review what you merge. Autonomy is about *when* you review (at the PR, with evidence), not *whether*.

## Sources
- [Configure permissions](https://code.claude.com/docs/en/permissions)
- [Permission modes](https://code.claude.com/docs/en/permission-modes)
- [Sandboxing](https://code.claude.com/docs/en/sandboxing)
- [Hooks reference](https://code.claude.com/docs/en/hooks)
