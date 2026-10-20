---
name: bootstrap-project
description: Set up a repository for effective Claude Code work - a lean CLAUDE.md, shared .claude/settings.json with the project's own check commands, .worktreeinclude and a task queue. Run once per repo, or again to audit an existing setup.
disable-model-invocation: true
---

Prepare the current repository for Claude Code. Templates live in `~/.claude/playbook/templates/project/`. Never overwrite an existing file without showing the diff and asking.

## 1. Learn the project (use a subagent for the scan)
Find, without reading the whole tree:
- Language(s), package manager, frameworks.
- The exact commands to install, build, test (whole suite and a single test), lint, typecheck and run the app. Prefer what CI runs (`.github/workflows`, Makefile, package scripts).
- Conventions Claude could not guess: branch naming, commit style, directories that are generated or must not be edited, required env vars, services the tests need.
- Existing instruction files: CLAUDE.md, AGENTS.md, .cursor/rules, .github/copilot-instructions.md. Reuse them; with an AGENTS.md, prefer a CLAUDE.md that imports it (`@AGENTS.md`) over duplicating it.

## 2. Ask only what the code can't tell you
At most 4 questions in one AskUserQuestion call, for example: what "done" means here, what must never be touched, deploy or production boundaries, who reviews PRs. Skip anything already answered.

## 3. Write the files
- `CLAUDE.md` from the template: under 80 lines. Only commands, non-obvious conventions, boundaries and gotchas. No file-by-file tour, no generic advice, nothing Claude can read from the code. Domain detail that matters only sometimes goes in `.claude/rules/<topic>.md` with `paths:` frontmatter, or in a project skill.
- `.claude/settings.json`: allow rules for this project's own check commands (e.g. `Bash(npm run test *)`), deny rules for secrets and production paths. Keep it shareable: nothing personal.
- `.worktreeinclude`: the gitignored files a fresh worktree needs to run (usually `.env` style files). Skip if there are none.
- `.gitignore`: add `.claude/worktrees/` and `CLAUDE.local.md` if missing.
- Task queue: ask whether to use GitHub issues labelled `agent-ready` (recommended when several agents or machines work the repo) or a local `TASKS.md` from the template.

## 4. Verify
Run the test and build commands you documented, exactly as written. Fix the docs if any command is wrong. Then report: files created or changed, commands verified, and anything you could not verify.
