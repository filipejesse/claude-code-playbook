# 8. Staying current: how this guide stays alive

> Last verified: 2026-10-20.

Claude Code ships several releases a week. This repo stays useful only if it is reviewed on a schedule against primary sources, with every recommendation dated.

## The routine

1. **Weekly**, run the repo's own skill from inside this checkout:
   ```text
   /refresh-guide
   ```
   It reads the official changelog since `docs/last-reviewed.md`, sorts each change into *breaks the baseline / changes a recommendation / worth adopting / ignore*, edits the docs and `home/`, runs `tests/run.sh`, and opens a PR. You review and merge.
2. **Or automate it** as a cloud scheduled task (the repo must be on GitHub, with the Claude GitHub app able to push branches):
   ```text
   /schedule every Monday at 8:07am in <you>/claude-code-playbook: run /refresh-guide and open a PR
   ```
3. **On every machine**, `git pull` picks up merged changes, because the install is a symlink. Machines installed with `--copy` also need `./install.sh --copy` again.

## Rules for what gets in

- **Primary sources only** for facts: [changelog](https://code.claude.com/docs/en/changelog), [docs](https://code.claude.com/docs/llms.txt), release notes. Community posts are leads to verify, never citations.
- **Every doc carries a "Last verified" line.** Update it when you check the doc, even if nothing changed.
- **Research previews stay out of `home/`.** Document them; adopt them in the baseline once they're stable.
- **Remove as readily as you add.** When a built-in feature replaces something here, delete the playbook's version.
- **Personal or company specifics never go here.** They live in your private config or in each project.

## Where to look between reviews

- `claude --version`, and `/release-notes` inside Claude Code.
- The [changelog](https://code.claude.com/docs/en/changelog).
- `/usage` recommendations and `/insights` reports: they show where *your* setup is costing you, which is the best signal for what to change next.
