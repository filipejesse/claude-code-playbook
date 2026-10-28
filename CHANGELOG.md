# Changelog

Newest first. Each entry links the review it came from (see `docs/last-reviewed.md`).

## 2026-10-28 (autopilot: one session per spec)
- Fixed: `autopilot start` resumed the same Claude session for every spec in a project, so each request re-read all earlier specs' history (a real project reached ~840K cached tokens per request after nine specs). The session is now tied to a checksum of the SPEC.md it started on; a new or edited spec, a finished run, a session from an older runner or `AUTOPILOT_FRESH_SESSION=1` start fresh. Restarts and usage-limit waits within a spec still resume.
- Fixed: background subagents were stopped 10 min after the last turn and their work redone. Autopilot now gives them 1 h (`AUTOPILOT_BG_WAIT_MS`), and the goal tells Claude to wait for them and stop idle dev servers before ending a turn.
- Guide 9 and `/autopilot-spec` mention starting on a fresh usage window and trusting the folder.

## 2026-10-23 (frontend specialist)
- New `frontend` subagent with the `impeccable` and `frontend-design` skills preloaded through `skills:` frontmatter. It reads the project's design system first and checks the rendered result at mobile and desktop widths.
- The global working agreement has a Frontend section: UI work follows those two skills and goes to the `frontend` agent.
- `install.sh` installs both plugins at user scope (`--no-plugins` to skip). Failures are reported but don't stop the install, and uninstall keeps the plugins.

## 2026-10-21 (demo with a real PR)
- First live end-to-end run that opened its own PR: a landing page from SPEC.md to a verified PR with its PR doc in about 1 min 45 s. The README demo GIF now shows that run, readable on phones, with a title header; `docs/assets/social-preview.png` is for the repo's link card.
- Fixed: `autopilot start` wrote every runner log line twice, and the first attempt logged a harmless "No such file" error.

## 2026-10-21 (open-source readiness)
- README leads with autopilot: a recorded real run, requirements (plan, Claude Code version, permissions), a safety warning, known limitations, and an "unofficial" notice.
- `./install.sh --autopilot-only` installs only what autopilot needs; `--uninstall` still removes everything.
- CONTRIBUTING.md, SECURITY.md (private reports for guard bypasses), issue templates including an autopilot run report. CI now also lints `home/bin/autopilot`.

## 2026-10-20 (PR rules, credits guard)
- Every PR ships with a PR doc with Mermaid diagrams: `/open-pr` skill, `pr-doc-gate.sh` hook, global rule. The guard now blocks pushes to the default branch; branch pushes and `gh pr create` are allowed.
- Autopilot never spends usage credits: it refuses to start, and stops mid-run, if `/usage` shows credits on. It sleeps until `resetsAt` when a limit ends a run, uses `--permission-prompts none`, and can open the final PR.

## 2026-10-20 (later)
- Autopilot: `/autopilot-spec` (one interview, then a SPEC.md with verifiable criteria) and the `autopilot` runner (`/goal` + auto mode + no questions + `CLAUDE_CODE_RETRY_WATCHDOG` to wait out usage limits + resume-on-exit + keep-awake). Guide 9. Tests with a stub `claude`, plus a smoke run against real Claude Code.

## 2026-10-20
- Initial playbook: 8 guides, installer with merge/uninstall/copy modes, global working agreement, guard and notification hooks, status line, reviewer/verifier/researcher subagents, bootstrap-project/handoff/next-task skills, `loop.md`, project templates, test suite and CI.
