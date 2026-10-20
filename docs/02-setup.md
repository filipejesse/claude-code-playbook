# 2. Setting up a machine

> Last verified: 2026-10-20 against the Claude Code docs (v2.1.304).

## New machine or VM in four commands

```bash
git clone https://github.com/<you>/claude-code-playbook ~/claude-code-playbook
cd ~/claude-code-playbook
./install.sh --install-claude   # installs Claude Code if missing, then the baseline
claude                          # first run: log in with your account
```

Requirements: `bash`, `git`, `jq` (preinstalled on macOS 15+; `sudo apt install jq` on Debian/Ubuntu). Linux desktop notifications need `notify-send`; without it the notification hook does nothing.

`./install.sh --dry-run` shows every change first. `./install.sh --uninstall` reverses it.

## What the installer does

| Change | Where | Notes |
|---|---|---|
| Links the baseline | `~/.claude/playbook` → `home/` in the checkout | `git pull` updates your setup. Use `--copy` on machines where you won't keep the checkout. |
| Links agents, skills, `loop.md` | `~/.claude/agents/`, `~/.claude/skills/`, `~/.claude/loop.md` | Skips any file you already have with the same name. |
| Imports the global working agreement | appends an `@~/.claude/playbook/CLAUDE.md` block to `~/.claude/CLAUDE.md` | Your own content in that file is kept. |
| Merges settings | `~/.claude/settings.json` | Adds permission rules, hooks and the status line. Keeps your keys, never duplicates entries, keeps an existing status line unless `--force-statusline`. Writes a timestamped backup before any change. |

After installing: open a new session, run `/status` (the `Setting sources` line should list User settings) and `claude doctor` (lists any rejected entries).

## Installing Claude Code itself

The native installer is the recommended path and auto-updates in the background:

```bash
curl -fsSL https://claude.ai/install.sh | bash          # latest channel
curl -fsSL https://claude.ai/install.sh | bash -s stable # ~1 week behind, skips regressions
```

Homebrew (`brew install --cask claude-code`, or `claude-code@latest`) and apt/dnf/apk repositories exist too, but they don't auto-update. To stay current, which is the point of this playbook, prefer the native installer on the `latest` channel. Use `stable` on machines where breakage costs more than missing a week of features.

## Logging in on a remote VM

Over SSH, run `claude`, press `c` to copy the login URL, open it in your local browser, and paste the code it shows back at the `Paste code here if prompted` prompt.

For scripts and CI on a box with no interactive login, `claude setup-token` prints a one-year OAuth token tied to your subscription. Set it as `CLAUDE_CODE_OAUTH_TOKEN` on that machine. It can only make model requests (no Remote Control, no claude.ai connectors). Treat it like a password: keep it in the machine's secret store, never in this repo.

## Work and personal accounts on one machine

Give each account its own config directory, and install the baseline into both:

```bash
# ~/.zshrc or ~/.bashrc
alias claude-work='CLAUDE_CONFIG_DIR=~/.claude-work claude'

CLAUDE_CONFIG_DIR=~/.claude-work ./install.sh   # baseline for the work account
./install.sh                                    # baseline for the personal account
```

Each directory keeps its own login, settings, history and memory, so work sessions never see personal config and the reverse.

## Work (Enterprise) vs personal machines

On an organization account, your admins can deliver **managed settings** that sit above everything this playbook writes:
- Run `/status`: if `Setting sources` lists a managed source, those keys win and you can't override them. Some features may be off entirely, such as auto mode, scheduled tasks, cloud sessions or particular models.
- Permission `allow` lists merge across levels, unless the org sets `allowManagedPermissionRulesOnly`.
- The baseline here contains nothing company-specific, so the same install works at work and at home. Put company-specific rules in that company's repos (project `CLAUDE.md` and `.claude/settings.json`), never in this public repo.
- Never commit credentials, internal hostnames or org policy text here. If you need a private layer, keep a separate private repo and import it from `~/.claude/CLAUDE.md`.

## Sources
- [Advanced setup](https://code.claude.com/docs/en/setup)
- [Settings files and precedence](https://code.claude.com/docs/en/settings)
- [Managed settings](https://code.claude.com/docs/en/managed-settings)
