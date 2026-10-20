#!/usr/bin/env bash
# PreToolUse(Bash) guard: blocks a short list of commands that are never worth the risk
# for an unattended agent. Exit 2 blocks the call and shows stderr to Claude.
# This is a last line of defence, not a sandbox: permission rules, auto mode and
# /sandbox do the real work. Keep the list short so it never blocks normal work.
set -u

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -z "$cmd" ] && exit 0

block() {
  echo "Blocked by claude-code-playbook guard: $1" >&2
  echo "If this is really intended, ask the user to run it themselves." >&2
  exit 2
}

is_dangerous_target() {
  # literal ~ and $HOME are what we are matching in the command text
  # shellcheck disable=SC2088,SC2016
  case "$1" in
    / | /\* | '~' | '~/' | '~/*' | '$HOME' | '$HOME/' | '$HOME/*' | '${HOME}' | '${HOME}/' | '${HOME}/*' \
      | '"$HOME"' | '"$HOME/"' | '"${HOME}"' | . | ./ | .. | ../ | \*)
      return 0 ;;
  esac
  [ -n "${HOME:-}" ] && { [ "$1" = "$HOME" ] || [ "$1" = "$HOME/" ] || [ "$1" = "$HOME/*" ]; } && return 0
  return 1
}

check_segment() {
  # word-split one simple command; globbing off so "*" stays literal
  set -f
  # shellcheck disable=SC2086
  set -- $1
  set +f
  [ "$#" -eq 0 ] && return 0
  while [ "$#" -gt 0 ]; do
    case "$1" in sudo | command | env | nohup | time | doas) shift ;; *=*) shift ;; *) break ;; esac
  done
  [ "$#" -eq 0 ] && return 0
  prog=${1##*/}
  shift
  case "$prog" in
    rm)
      recursive=0
      for a in "$@"; do
        case "$a" in --recursive) recursive=1 ;; --*) ;; -*[rR]*) recursive=1 ;; esac
      done
      if [ "$recursive" -eq 1 ]; then
        for a in "$@"; do
          case "$a" in -*) continue ;; esac
          is_dangerous_target "$a" && block "recursive rm on '$a'"
        done
      fi
      ;;
    git)
      [ "${1:-}" = "push" ] || return 0
      shift
      for a in "$@"; do
        case "$a" in
          --force | -f | --mirror) block "git push $a (use --force-with-lease on your own branch, by hand)" ;;
          +*) block "git push with a forced refspec '$a'" ;;
        esac
      done
      ;;
  esac
  return 0
}

# split compound commands on ; & | and newlines (approximate, conservative)
segments=$(printf '%s\n' "$cmd" | tr ';&|' '\n\n\n')
while IFS= read -r seg; do
  check_segment "$seg"
done <<EOF
$segments
EOF
exit 0
