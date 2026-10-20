#!/usr/bin/env bash
# Notification/Stop hook: desktop alert when a session needs you or finishes a turn,
# so parallel sessions don't sit idle unnoticed. Runs async; never blocks Claude.
#   PLAYBOOK_NOTIFY=0          turn all alerts off
#   PLAYBOOK_NOTIFY_ON_STOP=0  only alert when Claude needs input (not on every finished turn)
set -u
[ "${PLAYBOOK_NOTIFY:-1}" = "0" ] && exit 0

input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
project=$(basename "${cwd:-?}")

case "$event" in
  Notification)
    msg=$(printf '%s' "$input" | jq -r '.message // "Claude needs your input"' 2>/dev/null | cut -c1-140)
    ;;
  Stop)
    [ "${PLAYBOOK_NOTIFY_ON_STOP:-1}" = "0" ] && exit 0
    msg="Finished a turn: ready for the next task"
    ;;
  *) exit 0 ;;
esac
title="Claude Code: $project"

if [ "$(uname)" = "Darwin" ] && command -v osascript >/dev/null 2>&1; then
  osascript - "$title" "$msg" >/dev/null 2>&1 <<'APPLESCRIPT'
on run argv
  display notification (item 2 of argv) with title (item 1 of argv)
end run
APPLESCRIPT
elif command -v notify-send >/dev/null 2>&1; then
  notify-send "$title" "$msg" >/dev/null 2>&1
fi
exit 0
