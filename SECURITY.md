# Security policy

This repo ships hooks and settings that limit what an unattended Claude Code agent can do. A bypass in them matters more than an ordinary bug.

## Report privately

Please don't open a public issue for:

- a command that gets past `guard-bash.sh` and does what the guard is meant to block (recursive `rm` of `/`, `~`, `.` or `*`, force-push, pushing to the default branch);
- a way to open a PR past `pr-doc-gate.sh`, or to make `autopilot` run on paid usage credits while its check says it won't;
- anything in the installer that overwrites or leaks files it shouldn't.

Report it through [GitHub private vulnerability reporting](../../security/advisories/new) instead. Include the exact command or settings and the Claude Code version. Expect a first reply within a week.

## Scope

The hooks are a last line of defence, not a sandbox: see [docs/04-safety.md](docs/04-safety.md). Things the hooks don't claim to stop aren't vulnerabilities, for example a destructive command they don't list, or an MCP tool that bypasses a Bash hook. Ideas for those are welcome as normal issues. Vulnerabilities in Claude Code itself go to [Anthropic](https://www.anthropic.com/responsible-disclosure-policy).
