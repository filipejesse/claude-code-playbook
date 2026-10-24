#!/usr/bin/env bash
# install.sh: apply the claude-code-playbook baseline to ~/.claude.
# Idempotent, reversible (--uninstall), and safe to re-run after `git pull`.
# Never overwrites files it did not create; merges settings.json instead of replacing it.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

  --dry-run           show what would change and write nothing
  --copy              copy files into ~/.claude/playbook instead of symlinking this checkout
                      (default is a symlink, so `git pull` updates your setup in place)
  --autopilot-only    install only what autopilot needs: the autopilot command, /autopilot-spec,
                      /open-pr, the verifier agent, and the guard + PR-doc hooks with the
                      permission rules (no global CLAUDE.md import, status line or notifications).
                      Run ./install.sh later to add the rest.
  --no-plugins        skip installing the frontend plugins (impeccable, frontend-design)
                      that the frontend agent preloads
  --force-statusline  replace an existing status line with the playbook's
  --install-claude    install Claude Code with the official native installer if it is missing
  --uninstall         remove everything the playbook added (settings.json is backed up first)
  -h, --help          show this help

Honors CLAUDE_CONFIG_DIR (default: ~/.claude).
EOF
}

DRY=0 COPY=0 ONLY_AP=0 NO_PLUGINS=0 FORCE_SL=0 INSTALL_CLAUDE=0 UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --copy) COPY=1 ;;
    --autopilot-only) ONLY_AP=1 ;;
    --no-plugins) NO_PLUGINS=1 ;;
    --force-statusline) FORCE_SL=1 ;;
    --install-claude) INSTALL_CLAUDE=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
SRC="$REPO/home"
CD="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
PB="$CD/playbook"
SETTINGS="$CD/settings.json"
MEMORY="$CD/CLAUDE.md"
BEGIN_MARK='<!-- claude-code-playbook:begin -->'
END_MARK='<!-- claude-code-playbook:end -->'
STAMP=$(date +%Y%m%d-%H%M%S)
# shellcheck disable=SC2088 # the literal ~ is intended: it goes into an @import line
case "$PB" in "$HOME"/*) PB_REF="~${PB#"$HOME"}" ;; *) PB_REF="$PB" ;; esac

say() { printf '  %s\n' "$*"; }
act() { if [ "$DRY" -eq 1 ]; then printf '  [dry-run] %s\n' "$*"; else printf '  %s\n' "$*"; fi; }
run() { if [ "$DRY" -eq 0 ]; then "$@"; fi; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
section() { printf '\n%s\n' "$*"; }

command -v jq >/dev/null 2>&1 || die "jq is required (preinstalled on macOS 15+; otherwise: brew install jq / sudo apt install jq)"

# The playbook settings with __PLAYBOOK__ resolved to this machine's path.
# With --autopilot-only: permissions plus the guard and PR-doc hooks, nothing else.
AP_SETTINGS_JQ='{permissions}
  + {hooks: {PreToolUse: [ .hooks.PreToolUse[] | select(any(.hooks[]; .command | test("guard-bash|pr-doc-gate"))) ]}}'
base_settings() {
  jq --arg pb "$PB" 'walk(if type == "string" then gsub("__PLAYBOOK__"; $pb) else . end)' "$SRC/settings.json"
}
install_settings() {
  if [ "$ONLY_AP" -eq 1 ]; then base_settings | jq "$AP_SETTINGS_JQ"; else base_settings; fi
}

read_settings() {
  if [ -f "$SETTINGS" ]; then
    jq -e . "$SETTINGS" >/dev/null 2>&1 || die "$SETTINGS is not valid JSON; fix it first (claude doctor shows the error)"
    cat "$SETTINGS"
  else
    echo '{}'
  fi
}

# Write new settings only if they differ; back up the old file first.
write_settings() {
  new=$1
  old=$(read_settings)
  if [ "$(printf '%s' "$old" | jq -S .)" = "$(printf '%s' "$new" | jq -S .)" ]; then
    say "ok   $SETTINGS (no changes)"
    return
  fi
  if [ "$DRY" -eq 1 ]; then
    act "would update $SETTINGS:"
    diff -u <(printf '%s' "$old" | jq .) <(printf '%s' "$new" | jq .) | sed 's/^/      /' || true
    return
  fi
  if [ -f "$SETTINGS" ]; then
    cp "$SETTINGS" "$SETTINGS.bak-playbook-$STAMP"
    say "backup $SETTINGS.bak-playbook-$STAMP"
  fi
  tmp=$(mktemp "$CD/settings.json.XXXXXX")
  printf '%s\n' "$new" | jq . >"$tmp"
  mv "$tmp" "$SETTINGS"
  act "updated $SETTINGS"
}

MERGE_JQ='
def union($a; $b): ($a // []) + [ ($b // [])[] | select(. as $x | any(($a // [])[]; . == $x) | not) ];
def hook_cmds: [ .[]? | .hooks[]? | .command // empty ];
def merge_hooks($u; $b):
  reduce ($b | keys_unsorted[]) as $ev ($u;
    (.[$ev] // []) as $cur
    | ($cur | hook_cmds) as $have
    | .[$ev] = $cur + [ $b[$ev][] | select([ .hooks[]? | .command // empty ] | any(. as $c | any($have[]; . == $c)) | not) ]);
. as $u
| reduce (($b.permissions // {}) | keys_unsorted[]) as $k (.;
    .permissions[$k] = (if ($b.permissions[$k] | type) == "array"
                        then union($u.permissions[$k]; $b.permissions[$k])
                        else ($u.permissions[$k] // $b.permissions[$k]) end))
| if $b.hooks then .hooks = merge_hooks($u.hooks // {}; $b.hooks) else . end
| if $b.env then .env = ($b.env + ($u.env // {})) else . end
| if $b.statusLine and (($u.statusLine == null) or $force or (($u.statusLine.command // "") | contains($pb)))
  then .statusLine = $b.statusLine else . end
| reduce ($b | del(.permissions, .hooks, .env, .statusLine) | keys_unsorted[]) as $k (.;
    if has($k) then . else .[$k] = $b[$k] end)
'

UNMERGE_JQ='
def strip_hooks($pb):
  with_entries(.value |= [ .[] | (.hooks |= [ .[]? | select((.command // "") | contains($pb) | not) ]) | select((.hooks | length) > 0) ])
  | with_entries(select((.value | length) > 0));
if .hooks then .hooks |= strip_hooks($pb) else . end
| if .hooks == {} then del(.hooks) else . end
| if ((.statusLine.command // "") | contains($pb)) then del(.statusLine) else . end
| reduce (($b.permissions // {}) | keys_unsorted[]) as $k (.;
    if (.permissions[$k] | type) == "array" and ($b.permissions[$k] | type) == "array"
    then .permissions[$k] |= map(select(. as $x | any($b.permissions[$k][]; . == $x) | not))
    else . end)
| if .permissions then .permissions |= with_entries(select(.value != [])) else . end
| if .permissions == {} then del(.permissions) else . end
'

# Plugins whose skills the frontend agent preloads: "<plugin>@<marketplace> <marketplace GitHub repo>".
PLUGINS=(
  "impeccable@impeccable pbakaus/impeccable"
  "frontend-design@claude-plugins-official anthropics/claude-plugins-official"
)

# Install and enable each plugin through the claude CLI, at user scope. Never fatal:
# a failure leaves the agent working without that skill, and is reported.
install_plugins() {
  if ! command -v claude >/dev/null 2>&1; then
    say "skip (claude not found); later run, for each plugin below:"
    for p in "${PLUGINS[@]}"; do
      say "     claude plugin marketplace add ${p#* } && claude plugin install ${p%% *} --scope user"
    done
    return
  fi
  plugins=$(claude plugin list --json 2>/dev/null) || plugins='[]'
  markets=$(claude plugin marketplace list --json 2>/dev/null) || markets='[]'
  for p in "${PLUGINS[@]}"; do
    id=${p%% *} repo=${p#* } market=${id#*@}
    state=$(printf '%s' "$plugins" | jq -r --arg id "$id" \
      'first(.[]? | select(.id == $id) | if .enabled then "enabled" else "disabled" end) // "missing"' 2>/dev/null) || state=missing
    case "$state" in
      enabled) say "ok   $id"; continue ;;
      disabled)
        act "enable $id"
        run_plugin enable "$id" --scope user || true
        continue ;;
    esac
    if ! printf '%s' "$markets" | jq -e --arg m "$market" 'any(.[]?; .name == $m)' >/dev/null 2>&1; then
      act "add plugin marketplace $repo"
      run_plugin marketplace add "$repo" || continue
    fi
    act "install $id"
    run_plugin install "$id" --scope user || true
  done
}
run_plugin() {
  [ "$DRY" -eq 1 ] && return 0
  if ! out=$(claude plugin "$@" 2>&1); then
    say "warn claude plugin $* failed:"
    printf '%s\n' "$out" | sed 's/^/      /'
    return 1
  fi
}

# Symlink ~/.claude/<dest> -> ~/.claude/playbook/<rel>, never touching files we don't own.
link_item() {
  dest=$2 target="$PB/$1"
  if [ -L "$dest" ]; then
    cur=$(readlink "$dest")
    if [ "$cur" = "$target" ]; then say "ok   $dest"; return; fi
    case "$cur" in
      "$PB"/*) act "relink $dest"; run rm "$dest" ;;
      *) say "skip $dest (already links to $cur)"; return ;;
    esac
  elif [ -e "$dest" ]; then
    say "skip $dest (exists and is not managed by the playbook)"
    return
  fi
  act "link $dest -> $target"
  run ln -s "$target" "$dest"
}

unlink_item() {
  dest=$1
  if [ -L "$dest" ]; then
    case "$(readlink "$dest")" in "$PB"/*) act "remove $dest"; run rm "$dest" ;; esac
  fi
}

each_item() { # calls "$1 <rel> <dest>" for every managed item
  if [ "$ONLY_AP" -eq 1 ]; then
    "$1" agents/verifier.md "$CD/agents/verifier.md"
    for n in autopilot-spec open-pr; do "$1" "skills/$n" "$CD/skills/$n"; done
    "$1" bin/autopilot "$HOME/.local/bin/autopilot"
    return
  fi
  for f in "$SRC"/agents/*.md; do n=$(basename "$f"); "$1" "agents/$n" "$CD/agents/$n"; done
  for d in "$SRC"/skills/*/; do n=$(basename "$d"); "$1" "skills/$n" "$CD/skills/$n"; done
  "$1" loop.md "$CD/loop.md"
  "$1" bin/autopilot "$HOME/.local/bin/autopilot"
}

install_playbook_dir() {
  keep=0
  if [ -L "$PB" ]; then
    if [ "$COPY" -eq 0 ] && [ "$(readlink "$PB")" = "$SRC" ]; then keep=1
    else act "remove previous link $PB"; run rm "$PB"; fi
  elif [ -d "$PB" ]; then
    [ -f "$PB/.playbook-copy" ] || die "$PB exists and was not created by the playbook; move it away first"
    act "remove previous copy $PB"
    run rm -rf "$PB"
  elif [ -e "$PB" ]; then
    die "$PB exists and is not a directory"
  fi
  if [ "$keep" -eq 1 ]; then
    say "ok   $PB -> $SRC"
  elif [ "$COPY" -eq 1 ]; then
    act "copy $SRC -> $PB"
    run cp -R "$SRC" "$PB"
    run touch "$PB/.playbook-copy"
  else
    act "link $PB -> $SRC"
    run ln -s "$SRC" "$PB"
  fi
}

do_install() {
  printf 'claude-code-playbook: installing %sinto %s%s\n' "$([ "$ONLY_AP" -eq 1 ] && echo 'autopilot only ')" "$CD" "$([ "$DRY" -eq 1 ] && echo ' (dry run)')"

  section "Claude Code"
  if command -v claude >/dev/null 2>&1; then
    say "ok   $(claude --version 2>/dev/null | head -1)"
  elif [ "$INSTALL_CLAUDE" -eq 1 ]; then
    act "install Claude Code (curl -fsSL https://claude.ai/install.sh | bash)"
    run bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
  else
    say "not found: rerun with --install-claude, or see docs/02-setup.md"
  fi

  section "Files"
  run mkdir -p "$CD" "$CD/agents" "$CD/skills" "$HOME/.local/bin"
  install_playbook_dir
  each_item link_item
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) say "note: add ~/.local/bin to your PATH to use the autopilot command" ;; esac

  section "Frontend plugins"
  if [ "$ONLY_AP" -eq 1 ]; then
    say "skip (--autopilot-only)"
  elif [ "$NO_PLUGINS" -eq 1 ]; then
    say "skip (--no-plugins): the frontend agent will report the missing skills"
  else
    install_plugins
  fi

  section "Global instructions"
  if [ "$ONLY_AP" -eq 1 ]; then
    say "skip $MEMORY (--autopilot-only: autopilot's goal carries its own rules)"
  elif [ -f "$MEMORY" ] && grep -qF "$BEGIN_MARK" "$MEMORY"; then
    say "ok   $MEMORY imports $PB_REF/CLAUDE.md"
  else
    act "append import of $PB_REF/CLAUDE.md to $MEMORY (your existing content is kept)"
    if [ "$DRY" -eq 0 ]; then
      {
        if [ -s "$MEMORY" ]; then printf '\n'; fi
        printf '%s\n@%s/CLAUDE.md\n%s\n' "$BEGIN_MARK" "$PB_REF" "$END_MARK"
      } >>"$MEMORY"
    fi
  fi

  section "Settings"
  new=$(read_settings | jq --argjson b "$(install_settings)" --arg pb "$PB" \
    --argjson force "$([ "$FORCE_SL" -eq 1 ] && echo true || echo false)" "$MERGE_JQ")
  existing_sl=$(read_settings | jq -r '.statusLine.command // empty')
  if [ "$ONLY_AP" -eq 0 ] && [ -n "$existing_sl" ] && [ "$FORCE_SL" -eq 0 ] && [[ "$existing_sl" != *"$PB"* ]]; then
    say "keeping your status line ($existing_sl); use --force-statusline to replace it"
  fi
  write_settings "$new"

  section "Next steps"
  say "1. Start a new Claude Code session (or run /reload-plugins in an open one)."
  say "2. Run /status to confirm 'User settings' loaded, and 'claude doctor' to check for rejected entries."
  if [ "$ONLY_AP" -eq 1 ]; then
    say "3. In a new project folder, run claude and /autopilot-spec <idea>, then: autopilot start"
  else
    say "3. In each repo you work on, run /bootstrap-project."
  fi
  say "Update later with: git -C \"$REPO\" pull$([ "$COPY" -eq 1 ] && echo " && \"$REPO/install.sh\" --copy")"
}

do_uninstall() {
  ONLY_AP=0 # always remove everything the playbook may have added
  printf 'claude-code-playbook: uninstalling from %s%s\n' "$CD" "$([ "$DRY" -eq 1 ] && echo ' (dry run)')"

  section "Files"
  each_item_unlink() { unlink_item "$2"; }
  each_item each_item_unlink
  if [ -L "$PB" ]; then
    act "remove $PB"; run rm "$PB"
  elif [ -d "$PB" ] && [ -f "$PB/.playbook-copy" ]; then
    act "remove $PB"; run rm -rf "$PB"
  fi

  section "Global instructions"
  if [ -f "$MEMORY" ] && grep -qF "$BEGIN_MARK" "$MEMORY"; then
    act "remove playbook import from $MEMORY"
    if [ "$DRY" -eq 0 ]; then
      tmp=$(mktemp "$CD/CLAUDE.md.XXXXXX")
      awk -v b="$BEGIN_MARK" -v e="$END_MARK" '$0 == b { skip = 1; next } $0 == e { skip = 0; next } !skip' "$MEMORY" >"$tmp"
      mv "$tmp" "$MEMORY"
    fi
  else
    say "ok   no playbook import in $MEMORY"
  fi

  section "Settings"
  if [ -f "$SETTINGS" ]; then
    new=$(read_settings | jq --argjson b "$(base_settings)" --arg pb "$PB" "$UNMERGE_JQ")
    write_settings "$new"
  else
    say "ok   no $SETTINGS"
  fi
  printf '\nPlugins installed for the frontend agent are kept; remove each with: claude plugin uninstall <plugin>@<marketplace>\n'
  printf '\nRemoved. Permission rules you also had before installing were removed too; restore them from a settings.json.bak-playbook-* backup if needed.\n'
}

if [ "$UNINSTALL" -eq 1 ]; then do_uninstall; else do_install; fi
