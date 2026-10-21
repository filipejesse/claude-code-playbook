#!/usr/bin/env bash
# Records the README demo: a real autopilot run on a tiny project (no stubs, uses your plan's window).
#   asciinema rec --headless --window-size 100x32 -c docs/assets/record-autopilot-demo.sh demo.cast
#   python3 docs/assets/tidy_cast.py demo.cast tidy.cast 76   # display only: shorter paths, colored tags, one line per tool call
#   agg --cols 76 --rows 22 --font-size 22 --line-height 1.3 --idle-time-limit 2 --speed 1.5 \
#       --last-frame-duration 6 --font-family "SF Mono,Menlo" tidy.cast term.gif
#   python3 docs/assets/brand.py   # needs Pillow and macOS fonts; writes autopilot-demo.gif and social-preview.png
set -u
export AUTOPILOT_MODEL=haiku
P=/tmp/apdemo/slugify
rm -rf "$P"; mkdir -p "$P"; cd "$P" || exit 1
cat > SPEC.md <<'S'
# slugify

A shell command that turns a title into a URL slug.

## Acceptance criteria
1. `./slugify "Hello, World!"` prints `hello-world`.
2. Runs of spaces and punctuation collapse into one `-`; no leading or trailing `-`.
3. With no argument it prints usage to stderr and exits 2.

## Verification
`./verify.sh` exits 0 and checks every criterion.
S
git init -q && git add . && git -c user.name=demo -c user.email=demo@example.com commit -qm "SPEC.md"
p() { printf '\033[1;32m$\033[0m %s\n' "$*"; sleep 1; }
p "cat SPEC.md"; cat SPEC.md; sleep 3
p "autopilot start"; autopilot start | sed -e "s#/private$P#.#g" -e "s#$P#.#g"; sleep 2
sleep 4; p "autopilot log"
autopilot log "$P" 2>/dev/null &
L=$!; disown $L
for _ in $(seq 1 240); do [ -f AUTOPILOT_DONE.md ] || [ -f AUTOPILOT_BLOCKED.md ] && break; sleep 1; done
while [ -f .autopilot/runner.pid ] && kill -0 "$(cat .autopilot/runner.pid)" 2>/dev/null; do sleep 1; done
sleep 1; kill $L 2>/dev/null; pkill -f "tail -f.*$P" 2>/dev/null
echo; p "cat AUTOPILOT_DONE.md"; cat AUTOPILOT_DONE.md 2>/dev/null | head -25; sleep 3
p './slugify "  Ship It -- Now!! "'; ./slugify "  Ship It -- Now!! "; sleep 1
p "git log --oneline"; git log --oneline | head -8; sleep 3
