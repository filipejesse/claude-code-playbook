# <Project name>

<One sentence: what this is and who uses it.>

## Commands
- Install: `<cmd>`
- Dev server / run: `<cmd>`
- Test (all): `<cmd>` · Test (one): `<cmd path/to/test>`
- Lint / format / typecheck: `<cmd>`
- Build: `<cmd>`

## Done means
- <e.g. `npm run check` passes and the affected page renders without console errors>

## Conventions Claude can't infer
- <branch naming, commit style, where new modules go, naming rules that differ from the language default>

## Boundaries
- Never edit: <generated dirs, vendored code, migrations already applied>
- Never run: <deploy commands, commands against production data>
- Ask before: <schema changes, new dependencies, public API changes>

## Gotchas
- <non-obvious things that already bit someone: env vars, services tests need, flaky areas>

<!-- Keep this file under ~80 lines. Topic-specific rules go in .claude/rules/<topic>.md with `paths:` frontmatter. -->
