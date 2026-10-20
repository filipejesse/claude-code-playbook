---
name: refresh-guide
description: Keep this playbook current - read what changed in Claude Code since the last review, update the affected docs and baseline files, and open a PR. Run weekly (manually, or from a scheduled task).
---

Maintain the claude-code-playbook repository you are in.

1. Read `docs/last-reviewed.md` for the last reviewed date and Claude Code version.
2. Collect what changed since then, from primary sources only:
   - The official changelog: https://code.claude.com/docs/en/changelog
   - The docs index (https://code.claude.com/docs/llms.txt) for pages that are new or renamed.
   - Pages the docs in this repo link to, when a changelog entry touches their topic.
   Use the `researcher` subagent for the reading so raw pages stay out of this conversation.
3. Triage each change into one of:
   - **Breaks the baseline**: a setting key, hook event, frontmatter field or command used in `home/` changed or was removed. Fix it and run `tests/run.sh`.
   - **Changes a recommendation**: a doc in `docs/` now gives outdated or suboptimal advice. Update the doc and its "Last verified" line.
   - **Worth adopting**: a new feature that fits a principle in `docs/01-principles.md`. Add it to the relevant doc, briefly. Add it to the baseline in `home/` only if it is stable (not research preview) and useful on every machine.
   - **Ignore**: everything else. Don't pad the docs.
4. Update `docs/last-reviewed.md` (date, Claude Code version, one line per adopted change) and add an entry to `CHANGELOG.md`.
5. Run `tests/run.sh`. Commit on a branch `refresh/<date>` and open a PR whose body lists each change with its source link. If nothing needed changing, update only `docs/last-reviewed.md` and say so.

Never change the user's installed config from here; this skill only edits the repository.
