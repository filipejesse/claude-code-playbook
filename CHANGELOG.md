# Changelog

Newest first. Each entry links the review it came from (see `docs/last-reviewed.md`).

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
