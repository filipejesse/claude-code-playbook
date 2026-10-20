# Autopilot, PR docs, and a no-credits guarantee

## Summary
Adds a way to build a whole project unattended: `/autopilot-spec` runs the only interview and writes a verifiable `SPEC.md`, then `autopilot` drives Claude until every criterion is verified and a PR is open. Runs only ever use the subscription's usage window: autopilot refuses to start, and stops mid-run, if usage credits are on, and it waits for the window to reset instead of failing. Also makes "every PR ships with a doc with Mermaid diagrams" a harness rule enforced by a hook, and blocks pushes to the default branch.

## Changes
- Autopilot runner: goal, auto mode, no questions, usage-limit wait, resume, keep-awake, credits guard (`home/bin/autopilot`)
- Spec interview and scaffold, with optional private GitHub repo (`home/skills/autopilot-spec/SKILL.md`)
- PR doc rule: skill, hook and global agreement (`home/skills/open-pr/SKILL.md`, `home/hooks/pr-doc-gate.sh`, `home/CLAUDE.md`)
- Guard blocks `git push` to the default branch (`home/hooks/guard-bash.sh`); allow rules for branch pushes and `gh pr create` (`home/settings.json`)
- Installer links `~/.local/bin/autopilot` (`install.sh`)
- Guide 9 plus updates to guides 4 and 6, README, CHANGELOG
- Tests: 99 cases, including a stub `claude` for the runner (`tests/run.sh`)

## How it works

### An autopilot run
```mermaid
sequenceDiagram
    actor User
    participant Spec as /autopilot-spec
    participant AP as autopilot runner
    participant Usage as claude -p /usage
    participant CC as claude -p goal run
    participant Eval as goal evaluator
    participant API as Anthropic API
    participant GH as GitHub

    User->>Spec: idea
    Spec->>User: interview (only questions of the run)
    Spec-->>User: SPEC.md, scaffold, first commit
    User->>AP: autopilot start
    AP->>Usage: billing check
    Usage-->>AP: "using your subscription", no credits row
    AP->>CC: --permission-mode auto --permission-prompts none
    loop until the goal is met
        CC->>API: turn (implement, run ./verify, commit)
        alt usage window exhausted
            API-->>CC: 429 rate_limit_event rejected, resetsAt
            Note over CC,API: CLAUDE_CODE_RETRY_WATCHDOG waits until resetsAt
        end
        CC->>Eval: transcript after the turn
        Eval-->>CC: not yet met, or met
    end
    CC->>GH: /open-pr (PR doc, push branch, gh pr create)
    CC-->>AP: exit, AUTOPILOT_DONE.md with evidence and PR URL
    Note over AP,Usage: every 15 min the runner re-checks billing and stops if credits turn on
```

### Runner decisions after claude exits
```mermaid
flowchart TD
    A[claude exited] --> B{AUTOPILOT_DONE.md?}
    B -- yes --> Z[exit 0]
    B -- no --> C{AUTOPILOT_BLOCKED.md?}
    C -- yes --> Y[exit 3]
    C -- no --> D{"rate_limit_event rejected with resetsAt in the future?"}
    D -- yes --> E[re-check billing, sleep until reset] --> R[resume same session]
    D -- no --> F{repo changed since the attempt?}
    F -- yes --> G[stalls = 0] --> H[backoff 1 to 15 min] --> R
    F -- no --> I{3 stalls in a row?}
    I -- no --> H
    I -- yes --> J[write AUTOPILOT_BLOCKED.md] --> C
```

### PR doc gate
```mermaid
sequenceDiagram
    participant Claude
    participant Hook as pr-doc-gate.sh
    participant Git
    Claude->>Hook: PreToolUse Bash "gh pr create ..."
    Hook->>Hook: is a simple command gh pr create? (ignores quoted text)
    Hook->>Git: diff --name-only base...HEAD -- docs/pr/*.md
    Hook->>Git: show HEAD:docs/pr/<file>
    alt committed doc with a mermaid sequenceDiagram
        Hook-->>Claude: exit 0, PR is created
    else missing or uncommitted
        Hook-->>Claude: exit 2 with instructions to run /open-pr
    end
```

## Verification
| Check | Command | Result |
|---|---|---|
| Test suite | `tests/run.sh` | 102 passed, 0 failed |
| Real run (Haiku), billing preflight against real `/usage` | `autopilot run <tmp project>` | DONE in 26-38 s, `./verify.sh` ok, `usage.txt` shows subscription billing |
| Real session, push to main | `claude -p` asked to run `git push origin main` | Blocked by guard; bare remote stayed empty |
| Real session, PR without doc | `claude -p` asked to run `gh pr create` | Blocked by pr-doc-gate |
| Settings accepted | `claude doctor` | no rejected entries |
| CI | GitHub Actions (Ubuntu, macOS, ShellCheck) | see PR checks |

## Risks and follow-ups
- Not verified live: the wait at an actual usage limit (can't be triggered on demand). It relies on the documented `CLAUDE_CODE_RETRY_WATCHDOG` behavior and on the `rate_limit_event` fallback.
- The credits check matches `/usage` text; if Anthropic changes that wording, autopilot fails closed: it refuses to run rather than risk spending credits.
- PRs opened through a GitHub MCP server bypass the gate; the global rule says to use `/open-pr` (`gh`).
- Closing a laptop lid still sleeps most Macs despite `caffeinate`.
