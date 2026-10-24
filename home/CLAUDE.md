# Working agreement (claude-code-playbook)

Applies to every project. Project CLAUDE.md files override this where they conflict.

## Done means verified
- Before saying a task is done, run the project's check (tests, build, typecheck, lint, or the app itself) and show the evidence: the command and its result.
- If no check exists or you could not run it, say so plainly instead of implying success.
- Fix root causes. Never silence a failing test, lint rule or type error to get green.

## Scope and planning
- Do what was asked. Note unrelated problems you find; don't fix them unasked.
- Plan first (plan mode or a short written plan) when the change spans several files or the approach is unclear. Skip planning when the diff fits in one sentence.
- When a requirement is ambiguous and the choice is costly to undo, ask one focused question. Otherwise pick the sensible default and state it.

## Context hygiene
- Use subagents for broad searches, log digging and test runs whose output you won't need verbatim; keep the main conversation for decisions and edits.
- Prefer CLI tools (`gh`, cloud CLIs) over MCP servers when both exist.
- When compacting, preserve: the goal, files changed, commands that verify the work, decisions made and open questions.

## Git
- Never commit directly to the default branch; work on a branch or worktree.
- Small, focused commits with messages that say why. Never force-push, rewrite published history, or push to the default branch.
- Leave the working tree clean or explain what is uncommitted and why.

## Pull requests
- Open PRs with /open-pr. Every PR ships with a committed doc, `docs/pr/<date>-<branch>.md`: what changed and why, how it was verified (commands and results), and Mermaid diagrams. At least one `sequenceDiagram` of the main flow, plus flowchart, erDiagram, stateDiagram-v2 or classDiagram when they clarify something. A hook blocks `gh pr create` without it.
- Never merge your own PR; that is the human's call.

## Frontend
- Anything a user sees (pages, components, styling, layout, motion, UX copy, accessibility) follows the `impeccable` skill as the workflow and `frontend-design` as the aesthetic direction. Invoke both before the first UI edit, even for small refinements.
- Delegate substantial UI work (a new screen, a redesign, an audit, a polish pass) to the `frontend` subagent, which has both skills preloaded. Tell it the scope, whether it's a refinement or a redesign, and the brief or pinned aesthetic if there is one.
- The project's `DESIGN.md`, tokens and existing components win over generic taste. Verify UI by looking at the rendered result at mobile and desktop widths, not only by tests.

## Long-running and parallel work
- For multi-session work, keep `HANDOFF.md` current (use /handoff) so a fresh session can continue without re-discovery.
- When blocked, state exactly what is needed (a decision, a credential, access) and stop rather than guessing around it.
