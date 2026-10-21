# Contributing

Thanks for helping. This repo is a living guide, so the most useful contributions are:

- **Corrections when Claude Code changes.** A flag renamed, a default flipped, a doc page moved. Link the changelog entry or doc page.
- **Autopilot run reports.** Especially runs that hit a real usage limit, ran on Linux or WSL2, or ended blocked. Use the "Autopilot run report" issue template.
- **Bugs in the installer or hooks**, with the command that reproduces them.

For a way to get a dangerous command past a guard hook, follow [SECURITY.md](SECURITY.md) instead of opening a public issue.

## Making a change

1. Fork, branch from `main`, keep the change focused.
2. Run the checks. CI runs the same ones on Ubuntu and macOS:
   ```bash
   tests/run.sh                                    # installer, merge, uninstall, hooks, autopilot (stubbed claude)
   shellcheck --severity=warning install.sh tests/run.sh home/bin/autopilot home/hooks/*.sh home/statusline.sh docs/assets/*.sh
   ```
   The tests use a throwaway `HOME` and a stub `claude`, so they never touch your setup or spend usage.
3. Add a test for any behavior change in `install.sh`, a hook or `autopilot`.
4. If you change guidance, update the doc's "Last verified" line and cite the source (official docs or changelog).
5. Open a PR with a doc in `docs/pr/<YYYY-MM-DD>-<branch>.md`: what changed, why, how you verified it, and at least one Mermaid `sequenceDiagram`. The `/open-pr` skill writes it for you, and this repo's own hook expects it. See [docs/pr/](docs/pr/) for examples.

## Style

- Shell: `bash`, portable between macOS (bash 3.2, BSD tools) and Linux (bash 5, GNU tools). Code that runs under `set -u` must not read unset positional parameters.
- Docs: plain English, short sentences, commands you can copy. Prefer linking the official docs over restating them.
- Keep the hooks' block list short. A guard that blocks normal work gets turned off.
