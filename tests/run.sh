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
install() { "$REPO/install.sh" "$@" >/dev/null 2>&1; }

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
check "settings has guard hook" "jq -e '[.hooks.PreToolUse[].hooks[].command] | any(endswith(\"guard-bash.sh\"))' '$CLAUDE_DIR/settings.json' >/dev/null"
check "no unresolved placeholder" "! grep -q __PLAYBOOK__ '$CLAUDE_DIR/settings.json'"
check "hook scripts executable" "[ -x '$CLAUDE_DIR/playbook/hooks/guard-bash.sh' ] && [ -x '$CLAUDE_DIR/playbook/statusline.sh' ]"

echo "Idempotent re-run"
before=$(cat "$CLAUDE_DIR/settings.json")
install
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
"$REPO/install.sh" --dry-run >/dev/null 2>&1
check "no files created" "[ -z \"\$(ls -A '$CLAUDE_DIR')\" ]"

echo "Copy mode"
new_home
install --copy
check "real directory with marker" "[ -d '$CLAUDE_DIR/playbook' ] && [ ! -L '$CLAUDE_DIR/playbook' ] && [ -f '$CLAUDE_DIR/playbook/.playbook-copy' ]"
check "agents resolve" "[ -f '$CLAUDE_DIR/agents/verifier.md' ]"
install --copy
check "re-run in copy mode keeps working" "[ -f '$CLAUDE_DIR/playbook/CLAUDE.md' ] && [ -f '$CLAUDE_DIR/agents/verifier.md' ]"

echo "Refuses to clobber foreign playbook dir"
new_home
mkdir -p "$CLAUDE_DIR/playbook" && echo x >"$CLAUDE_DIR/playbook/note"
check "exits non-zero" "! '$REPO/install.sh' >/dev/null 2>&1"
check "leaves it alone" "[ -f '$CLAUDE_DIR/playbook/note' ]"

echo "Guard hook"
G="$REPO/home/hooks/guard-bash.sh"
guard() { printf '{"tool_input":{"command":%s}}' "$(jq -Rn --arg c "$1" '$c')" | "$G" >/dev/null 2>&1; }
for c in 'rm -rf /' 'rm -rf ~' 'rm -fr ~/' 'sudo rm -r -f /' 'rm -rf $HOME' 'cd x && rm -rf .' 'git push --force origin main' 'git push -f' 'git push origin +main' 'rm --recursive /*'; do
  guard "$c"; rc=$?
  check "blocks: $c" "[ $rc -eq 2 ]"
done
for c in 'ls -la' 'rm -rf ./build' 'rm -rf node_modules dist' 'rm file.txt' 'git push origin feature/x' 'git push --force-with-lease origin feature/x' 'echo "rm -rf is dangerous"' 'grep -rf patterns /'; do
  guard "$c"; rc=$?
  check "allows: $c" "[ $rc -eq 0 ]"
done

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
printf '%s | watchdog=%s\n' "$*" "${CLAUDE_CODE_RETRY_WATCHDOG:-}" >>"$STUB_LOG"
n=$(wc -l <"$STUB_LOG" | tr -d ' ')
echo '{"type":"system","subtype":"init","session_id":"sess-123"}'
if [ "$STUB_MODE" = "done-second" ]; then
  echo "work $n" >>work.txt
  [ "$n" -ge 2 ] && echo done >AUTOPILOT_DONE.md
fi
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
apr() { PATH="$STUB:$PATH" AUTOPILOT_NO_CAFFEINATE=1 AUTOPILOT_BACKOFF_SECONDS=0 "$AP" "$@" >/dev/null 2>&1; }

P=$(mktemp -d)
check "refuses without SPEC.md" "! apr run '$P'"

new_project
STUB_MODE=done-second apr run "$P"; rc=$?
check "finishes when AUTOPILOT_DONE.md appears" "[ $rc -eq 0 ] && [ -f '$P/AUTOPILOT_DONE.md' ]"
check "resumed the same session after an early exit" "[ \"\$(wc -l <'$P/calls.log' | tr -d ' ')\" = 2 ] && sed -n 2p '$P/calls.log' | grep -q -- '--resume sess-123'"
check "first run sets the goal, auto mode, no questions" "head -1 '$P/calls.log' | grep -q -- '/goal Every acceptance criterion' && head -1 '$P/calls.log' | grep -q -- '--permission-mode auto' && head -1 '$P/calls.log' | grep -q -- '--disallowedTools AskUserQuestion'"
check "usage-limit watchdog enabled" "grep -q 'watchdog=1' '$P/calls.log'"
check "works on an autopilot/ branch, not main" "git -C '$P' branch --show-current | grep -q '^autopilot/'"
check "gitignores its state dir" "grep -qx '.autopilot/' '$P/.gitignore'"
st=$(PATH="$STUB:$PATH" "$AP" status "$P" 2>&1)
check "status reports done" "printf '%s' \"\$st\" | grep -q 'state:    done'"
check "no pid files left behind" "[ ! -f '$P/.autopilot/runner.pid' ] && [ ! -f '$P/.autopilot/claude.pid' ]"

new_project
STUB_MODE=stall apr run "$P"; rc=$?
check "stops as blocked after 3 runs without progress" "[ $rc -eq 3 ] && [ -f '$P/AUTOPILOT_BLOCKED.md' ] && [ \"\$(wc -l <'$P/calls.log' | tr -d ' ')\" = 3 ]"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
