#!/usr/bin/env bash
# PreToolUse(Bash) gate: `gh pr create` is blocked unless the branch commits a PR doc
# (docs/pr/*.md) that contains a Mermaid sequence diagram. Exit 2 blocks the call.
# Opt out for one project with "env": {"PLAYBOOK_PR_DOC": "0"} in its .claude/settings.json.
set -u
input=$(cat) # always drain stdin, even when opting out
[ "${PLAYBOOK_PR_DOC:-1}" = "0" ] && exit 0
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$cwd" ] && cwd=$PWD
# Only act when a simple command actually *is* `gh pr create` (not text inside a quoted string).
is_pr_create() {
  set -f
  # shellcheck disable=SC2086
  set -- $1
  set +f
  while [ "$#" -gt 0 ]; do
    case "$1" in sudo | command | env | nohup | time) shift ;; *=*) shift ;; *) break ;; esac
  done
  [ "${1##*/}" = "gh" ] && [ "${2:-}" = "pr" ] && [ "${3:-}" = "create" ]
}
found=0
segments=$(printf '%s\n' "$cmd" | tr ';&|' '\n\n\n')
while IFS= read -r seg; do
  set -f
  # shellcheck disable=SC2086
  set -- $seg
  set +f
  if [ "${1:-}" = "cd" ]; then # follow `cd dir && ...`
    t=${2:-$HOME}
    # shellcheck disable=SC2088 # matching a literal ~ in the command text
    case "$t" in "~" | "~/"*) t="$HOME${t#\~}" ;; esac
    case "$t" in /*) ;; *) t="$cwd/$t" ;; esac
    if [ -d "$t" ]; then cwd=$(cd "$t" && pwd -P); fi
  fi
  if is_pr_create "$seg"; then found=1; break; fi
done <<EOF
$segments
EOF
[ "$found" -eq 1 ] || exit 0
git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Base branch: --base/-B from the command, else the remote's default, else main/master.
base=$(printf '%s' "$cmd" | sed -nE 's/.*(--base|-B)[= ]+([^[:space:]]+).*/\2/p' | head -1)
if [ -n "$base" ] && git -C "$cwd" rev-parse -q --verify "origin/$base" >/dev/null 2>&1; then
  base="origin/$base"
fi
[ -z "$base" ] && base=$(git -C "$cwd" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)
if [ -z "$base" ]; then
  for b in origin/main origin/master main master; do
    if git -C "$cwd" rev-parse -q --verify "$b" >/dev/null 2>&1; then base=$b; break; fi
  done
fi
[ -z "$base" ] && exit 0 # can't determine the base; don't block

docs=$(git -C "$cwd" diff --name-only "$base...HEAD" -- 'docs/pr/*.md' 2>/dev/null)
for f in $docs; do
  body=$(git -C "$cwd" show "HEAD:$f" 2>/dev/null) || continue # committed content only
  if printf '%s' "$body" | grep -q '```mermaid' && printf '%s' "$body" | grep -q 'sequenceDiagram'; then
    exit 0
  fi
done

cat >&2 <<EOF
Blocked by claude-code-playbook: every pull request needs a PR doc committed on this branch.
Expected: docs/pr/<YYYY-MM-DD>-<branch>.md (compared against $base) explaining what changed,
why, and how it was verified, with Mermaid diagrams: at least one sequenceDiagram, plus
flowchart / erDiagram / stateDiagram-v2 / classDiagram where they help.
Use the /open-pr skill to write the doc and open the PR, or commit the doc and retry.
EOF
exit 2
