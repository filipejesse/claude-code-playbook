#!/usr/bin/env bash
# PreToolUse(Bash) guard: blocks a short list of commands that are never worth the risk
# (recursive rm of /, ~, ., *; force-push; pushing to the default branch)
# for an unattended agent. Exit 2 blocks the call and shows stderr to Claude.
# This is a last line of defence, not a sandbox: permission rules, auto mode and
# /sandbox do the real work. Keep the list short so it never blocks normal work.
set -u

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -z "$cmd" ] && exit 0
CWD=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD=$PWD

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

is_default_branch() { # $1 = branch, $2 = repository dir
  [ -n "$1" ] || return 1
  case "$1" in main | master) return 0 ;; esac
  d=$(git -C "$2" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)
  [ -n "$d" ] && [ "$1" = "${d#origin/}" ]
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
    cd) # follow `cd dir && ...` so later checks look at the right repository
      t=${1:-$HOME}
      t=${t%\"} t=${t#\"} t=${t%\'} t=${t#\'}
      case "$t" in "~" | "~/"*) t="$HOME${t#\~}" ;; esac
      case "$t" in /*) ;; *) t="$CWD/$t" ;; esac
      if [ -d "$t" ]; then CWD=$(cd "$t" && pwd -P); fi
      ;;
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
      repo=$CWD
      if [ "${1:-}" = "-C" ] && [ -n "${2:-}" ]; then
        case "$2" in /*) repo=$2 ;; *) repo="$CWD/$2" ;; esac
        shift 2
      fi
      [ "${1:-}" = "push" ] || return 0
      shift
      pos=0 refs=""
      for a in "$@"; do
        case "$a" in
          --force | -f | --mirror) block "git push $a (use --force-with-lease on your own branch, by hand)" ;;
          +*) block "git push with a forced refspec '$a'" ;;
          -*) ;;
          *) pos=$((pos + 1)); [ "$pos" -ge 2 ] && refs="$refs $a" ;;
        esac
      done
      cur=$(git -C "$repo" branch --show-current 2>/dev/null)
      if [ -z "$refs" ]; then
        is_default_branch "$cur" "$repo" && block "git push while on '$cur': push a feature branch and open a PR"
      fi
      for r in $refs; do
        dst=${r##*:}
        dst=${dst#refs/heads/}
        [ "$dst" = "HEAD" ] && dst=$cur
        is_default_branch "$dst" "$repo" && block "git push to the default branch '$dst': open a PR instead"
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
