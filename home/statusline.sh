#!/usr/bin/env bash
# Status line: model · project@branch · context used · session cost · plan windows.
# Context % is the number to watch: /clear or /compact before it gets high.
# Fields that a plan doesn't report (cost on subscriptions, rate_limits on Team/Enterprise) are skipped.
set -u
input=$(cat)

IFS=$'\t' read -r model dir ctx cost five week <<EOF
$(printf '%s' "$input" | jq -r '[
  (.model.display_name // "?"),
  (.workspace.current_dir // .cwd // ""),
  ((.context_window.used_percentage // "") | tostring),
  ((.cost.total_cost_usd // "") | tostring),
  ((.rate_limits.five_hour.used_percentage // "") | tostring),
  ((.rate_limits.seven_day.used_percentage // "") | tostring)
] | map(if . == "" then "-" else . end) | @tsv' 2>/dev/null)
EOF

out="${model:-?}"
if [ -n "${dir:-}" ] && [ "$dir" != "-" ]; then
  branch=$(git -C "$dir" branch --show-current 2>/dev/null)
  out="$out · $(basename "$dir")${branch:+@$branch}"
fi

if [ "${ctx:--}" != "-" ]; then
  pct=${ctx%%.*}
  if [ "$pct" -ge 70 ] 2>/dev/null; then color='\033[31m'
  elif [ "$pct" -ge 45 ] 2>/dev/null; then color='\033[33m'
  else color='\033[32m'; fi
  out="$out · ${color}ctx ${pct}%\033[0m"
fi
[ "${cost:--}" != "-" ] && [ "$cost" != "0" ] && out="$out · \$$(printf '%.2f' "$cost")"
[ "${five:--}" != "-" ] && out="$out · 5h ${five%%.*}%"
[ "${week:--}" != "-" ] && out="$out · 7d ${week%%.*}%"

printf '%b\n' "$out"
