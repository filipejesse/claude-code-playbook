# 3. Context engineering: making each project steer Claude

> Last verified: 2026-10-20 against the Claude Code docs (v2.1.304).

The goal: a fresh session in any repo should know, from the first prompt, how to build, test and ship that repo, and what not to touch, without you re-explaining and without wasting context on things it could read from the code.

## The layers, and what goes in each

| Layer | File | Loaded | Put here |
|---|---|---|---|
| Organization | managed `CLAUDE.md` (admins) | always | company policy; you don't edit it |
| You, everywhere | `~/.claude/CLAUDE.md` (+ this playbook's import) | always | how you like to work: verification, git hygiene, communication |
| Project, shared | `CLAUDE.md` or `.claude/CLAUDE.md` at repo root | always | commands, conventions, boundaries, gotchas, committed to git |
| Project, topic | `.claude/rules/<topic>.md` with `paths:` frontmatter | when Claude touches matching files | rules for one area: API handlers, migrations, frontend |
| Project, personal | `CLAUDE.local.md` (gitignored) | always | your sandbox URLs, test accounts, personal shortcuts |
| On demand | skills (`.claude/skills/<name>/SKILL.md`) | when invoked or relevant | workflows and domain knowledge needed only sometimes |
| Learned | auto memory | always (first 200 lines / 25KB) | notes Claude takes from your corrections; review it occasionally with `/memory` |

Files above the working directory load at launch; `CLAUDE.md` files in subdirectories load when Claude works there. All of them are concatenated, not overridden, so contradictions between layers confuse Claude: keep each fact in exactly one place.

A repo that already has `AGENTS.md` works as-is: Claude Code reads it when there is no `CLAUDE.md`. If you need both, make `CLAUDE.md` import it with a line `@AGENTS.md` rather than duplicating it.

## Writing a project CLAUDE.md that works

Run `/bootstrap-project` (from this playbook) in the repo. It drafts the file from the template and verifies every command it documents. The rules it follows:

- **Under ~80 lines.** The docs say keep each file under 200, and shorter is better: long files make Claude skip rules. For every line ask "would removing this cause a mistake?"
- **Include** commands Claude can't guess, the definition of done, conventions that differ from defaults, boundaries (never edit / never run / ask first), and real gotchas.
- **Exclude** anything readable from code, standard language conventions, file-by-file tours, long explanations, and information that changes often.
- **Emphasis sparingly.** One `IMPORTANT` line stands out; ten don't.
- **Treat it as code.** When Claude ignores a rule, the file is usually too long or the rule ambiguous. Prune, rephrase, and check that behaviour actually changes. `/doctor` proposes cuts for content Claude can derive from the codebase.

Promote a rule out of CLAUDE.md when:
- it must *always* hold: make it a permission rule or hook ([4. Safety](04-safety.md));
- it matters only for part of the codebase: move it to `.claude/rules/` with `paths:`;
- it's a procedure you run sometimes: make it a skill.

## Path-scoped rules

```markdown
---
paths:
  - "src/api/**/*.ts"
---
# API handlers
- Validate input with the schemas in src/api/schemas; never trust req.body directly.
- Every new endpoint needs an integration test in tests/api/.
```

## Frontend work: skills preloaded into a specialist

UI work is where generic defaults show most, so the playbook gives it a standard instead of relying on taste per session:

- The global working agreement says anything a user sees follows the [`impeccable`](https://github.com/pbakaus/impeccable) skill as the workflow (context loading, sub-commands like `audit`, `polish`, `harden`, and a craft floor read before every UI edit) and `frontend-design` as the aesthetic direction.
- The [`frontend`](../home/agents/frontend.md) subagent has both skills in its `skills:` frontmatter, so their full text is injected when it starts, instead of depending on the model choosing to invoke them. Delegate a screen, a redesign, an audit or a polish pass to it. It reads the project's `DESIGN.md` and components first, and it checks the rendered result at mobile and desktop widths before reporting.
- `install.sh` installs both plugins at user scope through `claude plugin` (`--no-plugins` skips this). If a plugin is missing or disabled, Claude Code skips the preload with only a debug-log warning, so the agent is told to say so and stop.
- The preload applies when the agent runs as a **subagent**. Started as the main session (`claude --agent frontend`), it does not apply, and the agent loads the skills with the Skill tool instead.

To give one project its own frontend rules (its stack, tokens, component paths), add a `.claude/rules/frontend.md` with `paths:` for the UI directories, as above.

## Keeping state across sessions

- **Name sessions** (`/rename oauth-migration`) and resume them with `claude --resume`, treating each as a branch of work.
- **Handoffs.** Before `/clear`, or when context passes ~60%, run `/handoff`. It writes `HANDOFF.md`, which a fresh session reads to continue. This beats compaction for long efforts: you choose what survives.
- **Compaction instructions.** The playbook's global file tells Claude what to preserve when compacting. Add project specifics (e.g. "always keep the migration plan") to the project CLAUDE.md.
- **Side questions** that shouldn't grow the context: `/btw`.

## Sources
- [How Claude remembers your project](https://code.claude.com/docs/en/memory)
- [Best practices: write an effective CLAUDE.md](https://code.claude.com/docs/en/best-practices#write-an-effective-claude-md)
- [Skills](https://code.claude.com/docs/en/skills)
- [Subagents: preload skills](https://code.claude.com/docs/en/sub-agents)
