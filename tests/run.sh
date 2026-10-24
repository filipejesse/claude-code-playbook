#!/usr/bin/env bash
# Variables like $before and $out are read inside the eval strings passed to check().
# shellcheck disable=SC2034
# Test suite: runs everything against a throwaway HOME, never your real ~/.claude.
set -uo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
PASS=0 FAIL=0
ok() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

new_home() {
  T=$(mktemp -d)
  export HOME="$T" CLAUDE_DIR="$T/.claude"
  unset CLAUDE_CONFIG_DIR
  mkdir -p "$CLAUDE_DIR"
}
# A stub claude for the installer: logs each call to $HOME/claude-calls and keeps the
# installed plugins in $HOME/stub-plugins.json, so tests never touch real plugins.
PSTUB=$(mktemp -d)
cat >"$PSTUB/claude" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$HOME/claude-calls"
f="$HOME/stub-plugins.json"
[ -f "$f" ] || echo '[]' >"$f"
case "$*" in
  --version) echo "9.9.9 (Claude Code stub)" ;;
  "plugin list --json") cat "$f" ;;
  "plugin marketplace list --json") echo '[{"name":"claude-plugins-official"}]' ;;
  "plugin install "*)
    if [ -n "${STUB_PLUGIN_FAIL:-}" ]; then echo "network unreachable" >&2; exit 1; fi
    jq --arg id "$3" '. + [{id: $id, enabled: true}]' "$f" >"$f.tmp" && mv "$f.tmp" "$f" ;;
  "plugin enable "*) jq --arg id "$3" 'map(if .id == $id then .enabled = true else . end)' "$f" >"$f.tmp" && mv "$f.tmp" "$f" ;;
esac
STUB
chmod +x "$PSTUB/claude"
install() { PATH="$PSTUB:$PATH" "$REPO/install.sh" "$@" >/dev/null 2>&1; }
calls() { cat "$HOME/claude-calls" 2>/dev/null; }

echo "JSON files"
for f in "$REPO"/home/settings.json "$REPO"/home/templates/project/.claude/settings.json; do
  check "valid JSON: ${f#"$REPO"/}" "jq -e . '$f' >/dev/null"
done

echo "Frontmatter"
for f in "$REPO"/home/agents/*.md "$REPO"/home/skills/*/SKILL.md "$REPO"/.claude/skills/*/SKILL.md; do
  check "name+description: ${f#"$REPO"/}" "head -1 '$f' | grep -q '^---$' && grep -q '^name: ' '$f' && grep -q '^description: ' '$f'"
done

echo "Fresh install"
new_home
install
check "playbook dir links to checkout" "[ \"\$(readlink '$CLAUDE_DIR/playbook')\" = '$REPO/home' ]"
check "agents linked" "[ -L '$CLAUDE_DIR/agents/reviewer.md' ] && [ -f '$CLAUDE_DIR/agents/reviewer.md' ]"
check "skills linked" "[ -f '$CLAUDE_DIR/skills/next-task/SKILL.md' ]"
check "loop.md linked" "[ -f '$CLAUDE_DIR/loop.md' ]"
check "autopilot on PATH dir" "[ -x '$HOME/.local/bin/autopilot' ]"
check "CLAUDE.md imports playbook" "grep -qx '@~/.claude/playbook/CLAUDE.md' '$CLAUDE_DIR/CLAUDE.md'"
check "settings has statusLine" "jq -e '.statusLine.command | endswith(\"/playbook/statusline.sh\")' '$CLAUDE_DIR/settings.json' >/dev/null"
check "settings has PR doc gate" "jq -e '[.hooks.PreToolUse[].hooks[].command] | any(endswith(\"pr-doc-gate.sh\"))' '$CLAUDE_DIR/settings.json' >/dev/null"
check "settings has guard hook" "jq -e '[.hooks.PreToolUse[].hooks[].command] | any(endswith(\"guard-bash.sh\"))' '$CLAUDE_DIR/settings.json' >/dev/null"
check "no unresolved placeholder" "! grep -q __PLAYBOOK__ '$CLAUDE_DIR/settings.json'"
check "hook scripts executable" "[ -x '$CLAUDE_DIR/playbook/hooks/guard-bash.sh' ] && [ -x '$CLAUDE_DIR/playbook/statusline.sh' ]"

check "frontend agent linked, preloads both skills" "[ -f '$CLAUDE_DIR/agents/frontend.md' ] && grep -qx '  - impeccable:impeccable' '$CLAUDE_DIR/agents/frontend.md' && grep -qx '  - frontend-design:frontend-design' '$CLAUDE_DIR/agents/frontend.md'"
check "CLAUDE.md has frontend rules" "grep -q '^## Frontend' '$CLAUDE_DIR/playbook/CLAUDE.md'"
check "adds the impeccable marketplace" "calls | grep -qx 'plugin marketplace add pbakaus/impeccable'"
check "installs both frontend plugins at user scope" "calls | grep -qx 'plugin install impeccable@impeccable --scope user' && calls | grep -qx 'plugin install frontend-design@claude-plugins-official --scope user'"
check "does not re-add a known marketplace" "! calls | grep -q 'marketplace add anthropics/'"

echo "Idempotent re-run"
before=$(cat "$CLAUDE_DIR/settings.json")
: >"$HOME/claude-calls"
install
check "plugins not reinstalled" "! calls | grep -qE 'plugin install|marketplace add'"
check "settings unchanged" "[ \"\$(cat '$CLAUDE_DIR/settings.json')\" = \"\$before\" ]"
check "import added once" "[ \"\$(grep -c 'claude-code-playbook:begin' '$CLAUDE_DIR/CLAUDE.md')\" = 1 ]"
check "no backup on no-op" "! ls '$CLAUDE_DIR'/settings.json.bak-playbook-* >/dev/null 2>&1"

echo "Merge preserves existing config"
new_home
cat >"$CLAUDE_DIR/settings.json" <<'EOF'
{ "theme": "dark", "model": "opus",
  "permissions": { "allow": ["Bash(make *)", "Bash(git diff *)"], "deny": ["Read(./private/**)"] },
  "statusLine": { "type": "command", "command": "~/my-statusline.sh" },
  "hooks": { "Stop": [ { "hooks": [ { "type": "command", "command": "say done" } ] } ] },
  "env": { "FOO": "1" } }
EOF
printf '# My rules\n- be terse\n' >"$CLAUDE_DIR/CLAUDE.md"
mkdir -p "$CLAUDE_DIR/agents"
echo "mine" >"$CLAUDE_DIR/agents/reviewer.md"
install
S="$CLAUDE_DIR/settings.json"
check "keeps unrelated keys" "jq -e '.theme == \"dark\" and .model == \"opus\" and .env.FOO == \"1\"' '$S' >/dev/null"
check "keeps user allow rule" "jq -e '.permissions.allow | index(\"Bash(make *)\")' '$S' >/dev/null"
check "no duplicate allow rule" "[ \"\$(jq '[.permissions.allow[] | select(. == \"Bash(git diff *)\")] | length' '$S')\" = 1 ]"
check "adds playbook deny rules" "jq -e '.permissions.deny | index(\"Read(~/.ssh/**)\") and index(\"Read(./private/**)\")' '$S' >/dev/null"
check "keeps user status line" "jq -e '.statusLine.command == \"~/my-statusline.sh\"' '$S' >/dev/null"
check "keeps user Stop hook and adds ours" "[ \"\$(jq '[.hooks.Stop[].hooks[].command] | length' '$S')\" = 2 ]"
check "backup written" "ls '$CLAUDE_DIR'/settings.json.bak-playbook-* >/dev/null 2>&1"
check "user CLAUDE.md content kept" "head -1 '$CLAUDE_DIR/CLAUDE.md' | grep -q '^# My rules'"
check "does not overwrite user's agent" "[ ! -L '$CLAUDE_DIR/agents/reviewer.md' ] && grep -q mine '$CLAUDE_DIR/agents/reviewer.md'"
install --force-statusline
check "--force-statusline replaces it" "jq -e '.statusLine.command | endswith(\"/playbook/statusline.sh\")' '$S' >/dev/null"

echo "Uninstall"
install --uninstall
check "removes playbook dir" "[ ! -e '$CLAUDE_DIR/playbook' ]"
check "removes our links only" "[ ! -e '$CLAUDE_DIR/skills/next-task' ] && grep -q mine '$CLAUDE_DIR/agents/reviewer.md'"
check "removes import block" "! grep -q claude-code-playbook '$CLAUDE_DIR/CLAUDE.md' && grep -q 'be terse' '$CLAUDE_DIR/CLAUDE.md'"
check "removes our hooks, keeps user's" "jq -e '[.hooks.Stop[].hooks[].command] == [\"say done\"] and (.hooks.PreToolUse == null)' '$S' >/dev/null"
check "no playbook paths left" "! grep -q '/playbook/' '$S'"
check "keeps unrelated keys" "jq -e '.theme == \"dark\" and (.permissions.deny | index(\"Read(./private/**)\"))' '$S' >/dev/null"

echo "Dry run writes nothing"
new_home
PATH="$PSTUB:$PATH" "$REPO/install.sh" --dry-run >/dev/null 2>&1
check "no files created" "[ -z \"\$(ls -A '$CLAUDE_DIR')\" ]"

echo "Copy mode"
new_home
install --copy
check "real directory with marker" "[ -d '$CLAUDE_DIR/playbook' ] && [ ! -L '$CLAUDE_DIR/playbook' ] && [ -f '$CLAUDE_DIR/playbook/.playbook-copy' ]"
check "agents resolve" "[ -f '$CLAUDE_DIR/agents/verifier.md' ]"
install --copy
check "re-run in copy mode keeps working" "[ -f '$CLAUDE_DIR/playbook/CLAUDE.md' ] && [ -f '$CLAUDE_DIR/agents/verifier.md' ]"

echo "Autopilot-only install"
new_home
install --autopilot-only
S="$CLAUDE_DIR/settings.json"
check "autopilot command and its skills linked" "[ -x '$HOME/.local/bin/autopilot' ] && [ -f '$CLAUDE_DIR/skills/autopilot-spec/SKILL.md' ] && [ -f '$CLAUDE_DIR/skills/open-pr/SKILL.md' ] && [ -f '$CLAUDE_DIR/agents/verifier.md' ]"
check "project template reachable for /autopilot-spec" "[ -f '$CLAUDE_DIR/playbook/templates/project/CLAUDE.md' ]"
check "other skills, agents and loop.md not linked" "[ ! -e '$CLAUDE_DIR/skills/next-task' ] && [ ! -e '$CLAUDE_DIR/agents/reviewer.md' ] && [ ! -e '$CLAUDE_DIR/loop.md' ]"
check "no global CLAUDE.md import" "! grep -qs claude-code-playbook '$CLAUDE_DIR/CLAUDE.md'"
check "guard and PR-doc hooks only" "jq -e '([.hooks.PreToolUse[].hooks[].command | split(\"/\") | last] | sort) == [\"guard-bash.sh\", \"pr-doc-gate.sh\"] and (.hooks | keys) == [\"PreToolUse\"]' '$S' >/dev/null"
check "deny rules, no status line" "jq -e '(.permissions.deny | index(\"Read(**/.env)\")) and (.statusLine == null)' '$S' >/dev/null"
install
check "full install afterwards adds the rest" "[ -e '$CLAUDE_DIR/skills/next-task' ] && grep -q claude-code-playbook '$CLAUDE_DIR/CLAUDE.md' && jq -e '.statusLine and .hooks.Stop' '$S' >/dev/null"
new_home
S="$CLAUDE_DIR/settings.json"
install --autopilot-only
install --uninstall --autopilot-only
check "uninstall removes everything" "[ ! -e '$HOME/.local/bin/autopilot' ] && [ ! -e '$CLAUDE_DIR/skills/open-pr' ] && [ ! -e '$CLAUDE_DIR/playbook' ] && ! grep -q '/playbook/' '$S'"

echo "Frontend plugins"
new_home
echo '[{"id":"impeccable@impeccable","enabled":false},{"id":"frontend-design@claude-plugins-official","enabled":true}]' >"$HOME/stub-plugins.json"
install
check "re-enables a disabled plugin" "calls | grep -qx 'plugin enable impeccable@impeccable --scope user' && ! calls | grep -q 'plugin install'"
new_home
install --no-plugins
check "--no-plugins makes no plugin calls" "! calls | grep -q '^plugin'"
new_home
out=$(PATH="$PSTUB:$PATH" STUB_PLUGIN_FAIL=1 "$REPO/install.sh" 2>&1); rc=$?
check "plugin failure is reported, not fatal" "[ $rc -eq 0 ] && grep -q 'warn claude plugin install' <<<\"\$out\" && [ -f '$CLAUDE_DIR/agents/frontend.md' ]"
new_home
out=$(PATH="/usr/bin:/bin" "$REPO/install.sh" 2>&1); rc=$?
check "without claude, prints the commands to run" "[ $rc -eq 0 ] && grep -q 'claude plugin install impeccable@impeccable --scope user' <<<\"\$out\""
new_home
install --dry-run
check "dry run makes no plugin changes" "! calls | grep -qE 'plugin install|marketplace add'"
new_home
install --autopilot-only
check "--autopilot-only skips plugins" "! calls | grep -q '^plugin'"

echo "Refuses to clobber foreign playbook dir"
new_home
mkdir -p "$CLAUDE_DIR/playbook" && echo x >"$CLAUDE_DIR/playbook/note"
check "exits non-zero" "! PATH='$PSTUB':\$PATH '$REPO/install.sh' >/dev/null 2>&1"
check "leaves it alone" "[ -f '$CLAUDE_DIR/playbook/note' ]"

echo "Guard hook"
G="$REPO/home/hooks/guard-bash.sh"
GR=$(mktemp -d)
git -C "$GR" init -q -b main
git -C "$GR" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
guard() { jq -n --arg c "$1" --arg d "${2:-$GR}" '{tool_input: {command: $c}, cwd: $d}' | "$G" >/dev/null 2>&1; }
for c in 'rm -rf /' 'rm -rf ~' 'rm -fr ~/' 'sudo rm -r -f /' 'rm -rf $HOME' 'cd x && rm -rf .' 'git push --force origin main' 'git push -f' 'git push origin +main' 'rm --recursive /*'; do
  guard "$c"; rc=$?
  check "blocks: $c" "[ $rc -eq 2 ]"
done
for c in 'git push origin main' 'git push -u origin HEAD:master' 'git push' 'git push origin HEAD'; do
  guard "$c"; rc=$?
  check "blocks default-branch push (on main): $c" "[ $rc -eq 2 ]"
done
git -C "$GR" switch -q -c feature/x
for c in 'git push' 'git push -u origin feature/x' 'git push origin HEAD'; do
  guard "$c"; rc=$?
  check "allows feature-branch push: $c" "[ $rc -eq 0 ]"
done
guard "cd '$GR' && git push" "$(mktemp -d)"; rc=$?
check "follows cd into a feature-branch repo before judging a push" "[ $rc -eq 0 ]"
GM=$(mktemp -d)
git -C "$GM" init -q -b main
guard "cd $GM && git push" "$GR"; rc=$?
check "follows cd into a repo on main and blocks" "[ $rc -eq 2 ]"
guard "git -C $GM push" "$GR"; rc=$?
check "honors git -C when judging a push" "[ $rc -eq 2 ]"
for c in 'ls -la' 'rm -rf ./build''rm -rf node_modules dist' 'rm file.txt' 'git push origin feature/x' 'git push --force-with-lease origin feature/x' 'echo "rm -rf is dangerous"' 'grep -rf patterns /'; do
  guard "$c"; rc=$?
  check "allows: $c" "[ $rc -eq 0 ]"
done

echo "PR doc gate"
PG="$REPO/home/hooks/pr-doc-gate.sh"
PR=$(mktemp -d)
git -C "$PR" init -q -b main
git -C "$PR" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C "$PR" switch -q -c feature/y
echo x >"$PR/a.txt" && git -C "$PR" add a.txt && git -C "$PR" -c user.name=t -c user.email=t@t commit -qm change
gate() { jq -n --arg c "$1" --arg d "$PR" '{tool_input: {command: $c}, cwd: $d}' | "$PG" >/dev/null 2>&1; }
gate 'gh pr create --title x --body y'; rc=$?
check "blocks gh pr create without a PR doc" "[ $rc -eq 2 ]"
gate 'git status'; rc=$?
check "ignores other commands" "[ $rc -eq 0 ]"
mkdir -p "$PR/docs/pr" && printf '# x\n```mermaid\nflowchart LR\n  a-->b\n```\n' >"$PR/docs/pr/2026-10-20-feature-y.md"
git -C "$PR" add docs && git -C "$PR" -c user.name=t -c user.email=t@t commit -qm doc
gate 'gh pr create --base main --title x'; rc=$?
check "blocks a PR doc without a sequenceDiagram" "[ $rc -eq 2 ]"
printf '# x\n```mermaid\nsequenceDiagram\n  A->>B: hi\n```\n' >"$PR/docs/pr/2026-10-20-feature-y.md"
gate 'gh pr create --base main --title x'; rc=$?
check "blocks an uncommitted PR doc" "[ $rc -eq 2 ]"
git -C "$PR" -c user.name=t -c user.email=t@t commit -qam "doc diagrams"
gate 'gh pr create --base main --title x'; rc=$?
check "allows once the doc with a sequenceDiagram is committed" "[ $rc -eq 0 ]"
gate 'cd sub && gh pr create -B main'; rc=$?
check "detects gh pr create inside compound commands" "[ $rc -eq 0 ]"
git -C "$PR" switch -q -c feature/z main
gate 'claude -p "then run gh pr create --title t"'; rc=$?
check "ignores gh pr create inside a quoted argument" "[ $rc -eq 0 ]"
gate 'git add . && gh pr create --title t'; rc=$?
check "blocks gh pr create after && on a branch without a doc" "[ $rc -eq 2 ]"
jq -n --arg c "cd $PR && gh pr create --title t" --arg d "$(mktemp -d)" '{tool_input: {command: $c}, cwd: $d}' | "$PG" >/dev/null 2>&1; rc=$?
check "follows cd into the repo before checking for the doc" "[ $rc -eq 2 ]"
PLAYBOOK_PR_DOC=0 jq -n --arg d "$(mktemp -d)" '{tool_input: {command: "gh pr create"}, cwd: $d}' | PLAYBOOK_PR_DOC=0 "$PG" >/dev/null 2>&1; rc=$?
check "PLAYBOOK_PR_DOC=0 opts out" "[ $rc -eq 0 ]"

echo "Status line"
SL="$REPO/home/statusline.sh"
out=$(printf '%s' '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/tmp/demo"},"context_window":{"used_percentage":72.4},"cost":{"total_cost_usd":1.5},"rate_limits":{"five_hour":{"used_percentage":23.5},"seven_day":{"used_percentage":41.2}}}' | "$SL")
check "full input" "printf '%s' \"\$out\" | grep -q 'Opus · demo' && printf '%s' \"\$out\" | grep -q 'ctx 72%' && printf '%s' \"\$out\" | grep -q '\\\$1.50' && printf '%s' \"\$out\" | grep -q '5h 23% · 7d 41%'"
out=$(printf '%s' '{"model":{"display_name":"Sonnet"}}' | "$SL")
check "minimal input" "[ \"\$out\" = 'Sonnet' ]"

echo "Autopilot"
AP="$REPO/home/bin/autopilot"
STUB=$(mktemp -d)
cat >"$STUB/claude" <<'EOF2'
#!/usr/bin/env bash
if [ "${2:-}" = "/usage" ]; then
  case "${STUB_USAGE:-subscription}" in
    subscription) echo "You are currently using your subscription to power your Claude Code usage" ;;
    credits) printf 'You are currently using your subscription to power your Claude Code usage\nUsage credits: $12.00 spent this month\n' ;;
    api) echo "You are using an API key" ;;
  esac
  exit 0
fi
printf '%s | watchdog=%s\n' "$*" "${CLAUDE_CODE_RETRY_WATCHDOG:-}" >>"$STUB_LOG"
n=$(wc -l <"$STUB_LOG" | tr -d ' ')
echo '{"type":"system","subtype":"init","session_id":"sess-123"}'
case "$STUB_MODE" in
  done-second)
    echo "work $n" >>work.txt
    [ "$n" -ge 2 ] && echo done >AUTOPILOT_DONE.md ;;
  limit)
    if [ "$n" -eq 1 ]; then
      printf '{"type":"rate_limit_event","rate_limit_info":{"status":"rejected","resetsAt":%s}}\n' "$(($(date +%s) + 2))"
    else
      echo done >AUTOPILOT_DONE.md
    fi ;;
esac
exit 1
EOF2
chmod +x "$STUB/claude"
new_project() {
  P=$(mktemp -d)
  git -C "$P" init -q -b main
  echo "# spec" >"$P/SPEC.md"
  git -C "$P" add . && git -C "$P" -c user.name=t -c user.email=t@t commit -qm init
  export STUB_LOG="$P/calls.log"
  : >"$STUB_LOG"
}
apr() { PATH="$STUB:$PATH" AUTOPILOT_NO_CAFFEINATE=1 AUTOPILOT_BACKOFF_SECONDS=0 AUTOPILOT_RESET_GRACE_SECONDS=0 "$AP" "$@" >/dev/null 2>&1; }

P=$(mktemp -d)
check "refuses without SPEC.md" "! apr run '$P'"

new_project
STUB_MODE=done-second apr run "$P"; rc=$?
check "finishes when AUTOPILOT_DONE.md appears" "[ $rc -eq 0 ] && [ -f '$P/AUTOPILOT_DONE.md' ]"
check "resumed the same session after an early exit" "[ \"\$(wc -l <'$P/calls.log' | tr -d ' ')\" = 2 ] && sed -n 2p '$P/calls.log' | grep -q -- '--resume sess-123'"
check "first run sets the goal, auto mode, no questions" "head -1 '$P/calls.log' | grep -q -- '/goal Every acceptance criterion' && head -1 '$P/calls.log' | grep -q -- '--permission-mode auto' && head -1 '$P/calls.log' | grep -q -- '--disallowedTools AskUserQuestion' && head -1 '$P/calls.log' | grep -q -- '--permission-prompts none'"
check "goal allows PRs with the PR doc, forbids default-branch pushes" "head -1 '$P/calls.log' | grep -q -- '/open-pr' && head -1 '$P/calls.log' | grep -q -- 'never push to the default branch'"
check "usage-limit watchdog enabled" "grep -q 'watchdog=1' '$P/calls.log'"
check "works on an autopilot/ branch, not main" "git -C '$P' branch --show-current | grep -q '^autopilot/'"
check "gitignores its state dir" "grep -qx '.autopilot/' '$P/.gitignore'"
st=$(PATH="$STUB:$PATH" "$AP" status "$P" 2>&1)
check "status reports done" "printf '%s' \"\$st\" | grep -q 'state:    done'"
check "no pid files left behind" "[ ! -f '$P/.autopilot/runner.pid' ] && [ ! -f '$P/.autopilot/claude.pid' ]"

new_project
t0=$(date +%s)
STUB_MODE=limit apr run "$P"; rc=$?
t1=$(date +%s)
check "waits for the usage-limit reset, then resumes" "[ $rc -eq 0 ] && [ $((t1 - t0)) -ge 2 ] && grep -q 'waiting for the window to reset' '$P/.autopilot/autopilot.log' && sed -n 2p '$P/calls.log' | grep -q -- '--resume sess-123'"

new_project
STUB_USAGE=credits STUB_MODE=done-second apr run "$P"; rc=$?
check "refuses to run when usage credits are on" "[ $rc -ne 0 ] && [ ! -s '$P/calls.log' ] && [ ! -f '$P/AUTOPILOT_DONE.md' ]"
STUB_USAGE=api STUB_MODE=done-second apr run "$P"; rc=$?
check "refuses when billing can't be confirmed" "[ $rc -ne 0 ] && [ ! -s '$P/calls.log' ]"
STUB_USAGE=credits AUTOPILOT_ALLOW_CREDITS=1 STUB_MODE=done-second apr run "$P"; rc=$?
check "AUTOPILOT_ALLOW_CREDITS=1 overrides" "[ $rc -eq 0 ]"

new_project
t0=$(date +%s)
PATH="$STUB:$PATH" AUTOPILOT_NO_CAFFEINATE=1 AUTOPILOT_BACKOFF_SECONDS=0 STUB_MODE=done-second "$AP" run "$P" 2>&1 | cat >/dev/null
t1=$(date +%s)
check "exits promptly, leaving nothing holding its output open" "[ $((t1 - t0)) -lt 15 ]"

new_project
PATH="$STUB:$PATH" AUTOPILOT_NO_CAFFEINATE=1 AUTOPILOT_BACKOFF_SECONDS=0 STUB_MODE=done-second "$AP" start "$P" >/dev/null 2>&1
for _ in $(seq 1 100); do [ -f "$P/AUTOPILOT_DONE.md" ] && ! [ -f "$P/.autopilot/runner.pid" ] && break; sleep 0.1; done
check "start: each log line written once" "[ \"\$(grep -c 'autopilot started' '$P/.autopilot/autopilot.log')\" = 1 ] && [ \"\$(grep -c 'DONE: see' '$P/.autopilot/autopilot.log')\" = 1 ]"
check "start: no error before the first events file exists" "! grep -qs 'No such file' '$P/.autopilot/autopilot.log' '$P/.autopilot/runner.out'"

new_project
STUB_MODE=stall apr run "$P"; rc=$?
check "stops as blocked after 3 runs without progress" "[ $rc -eq 3 ] && [ -f '$P/AUTOPILOT_BLOCKED.md' ] && [ \"\$(wc -l <'$P/calls.log' | tr -d ' ')\" = 3 ]"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
