---
name: autopilot-spec
description: Start a project that Claude builds unattended. Interview the user once, write a self-contained SPEC.md with verifiable acceptance criteria and a single verification command, scaffold the repo, and hand off to `autopilot start`. Use when the user wants Claude to work autonomously to a finished result.
disable-model-invocation: true
---

This is the **only** conversation with the user before an unattended run (`autopilot`). Anything you don't settle now, the run will have to decide alone, so make the spec complete enough that a capable engineer could finish the project without asking a single question.

Idea from the user: $ARGUMENTS

## 1. Interview (AskUserQuestion, several rounds if needed)
Cover the hard parts, not the obvious ones:
- **Outcome and users:** who uses it, the 3-7 core flows, what "finished" looks like.
- **Form:** web app, CLI, API, library, bot, data pipeline. Where it runs (local only is the default; the run never deploys).
- **GitHub:** whether to create a private GitHub repo for it now. With a remote, the run finishes by opening a PR with its PR doc; without one, the work stays on a local branch.
- **Stack:** recommend one (mainstream, well documented, easy to test). Let the user override.
- **Data and integrations:** what's stored and where; external APIs. Anything that needs keys or paid access must be either stubbed/mocked or provided now as a gitignored `.env`. The run can't get credentials later.
- **Quality bar:** tests expected, accessibility, performance, platforms.
- **Out of scope:** say it explicitly; it stops gold-plating.
- **Decision rules:** how to break ties alone (e.g. "simplest thing that satisfies the criterion", "no new dependencies unless needed").
Stop when every acceptance criterion can be checked by a command or by an observable result Claude can produce itself (test output, a screenshot, a curl response).

## 2. Write SPEC.md
```markdown
# <Project>: spec
## Outcome
## Users and core flows
## Acceptance criteria
1. <criterion>: verified by <command or observable result>
...
## Verification
`<one command, e.g. ./verify.sh or make verify>` exits 0 only when every automated criterion passes.
## Stack and constraints
## Out of scope
## Decision rules
```
Criteria must be specific and testable ("POST /todos with an empty title returns 422", not "validates input"). Prefer 8-20 criteria. Order them so early ones build the foundation.

## 3. Scaffold
In the target directory (create it if needed; ask for the path in the interview, defaulting to `~/Repos/<slug>`):
- `git init` if needed.
- The verification script named in SPEC.md, initially failing (it should run the test suite plus any build or lint steps).
- `CLAUDE.md` from `~/.claude/playbook/templates/project/CLAUDE.md`, filled in with the chosen stack's commands (mark ones that don't exist yet as planned).
- `PROGRESS.md` (every criterion listed as not started), an empty `DECISIONS.md`, and `.gitignore` with `.autopilot/`, `.env*`, `!.env.example`, plus the stack's defaults.
- `.claude/settings.json` with allow rules for the stack's build, test and package-manager commands, so the run never waits on a permission it could have had.
- Commit: `Spec and scaffold for autopilot run`.
- If the user chose a GitHub repo: `gh repo create <name> --private --source . --remote origin --push`. This publishes the first commit and is the only time the default branch is pushed directly (the guard hook blocks `git push` to it, by design). All later work goes through PRs.

## 4. Hand off
Show a 5-line summary of the spec, then tell the user to start the run:
```bash
cd <dir> && autopilot start
```
and how to watch it: `autopilot log`, `autopilot status`. Note that it only runs on the subscription window (it refuses to start, and stops, if usage credits are on), waits out usage limits on its own, keeps the machine awake, and ends with a PR plus its PR doc when there is a remote. Do not start the run yourself unless the user asks.
