#!/usr/bin/env bash
# Records the README demo: a real autopilot run (no stubs, uses your plan's window) that builds a
# small landing page and opens its own pull request on a throwaway GitHub repo.
#   DEMO_REPO=<you>/autopilot-demo-landing \
#   asciinema rec --headless --window-size 100x32 -c docs/assets/record-autopilot-demo.sh demo.cast
#   python3 docs/assets/tidy_cast.py demo.cast tidy.cast 76   # display only: shorter paths, colored tags, one line per tool call
#   agg --cols 76 --rows 22 --font-size 22 --line-height 1.3 --idle-time-limit 2 --speed 1.5 \
#       --last-frame-duration 6 --font-family "SF Mono,Menlo" tidy.cast term.gif
#   python3 docs/assets/brand.py   # needs Pillow and macOS fonts; writes autopilot-demo.gif and social-preview.png
# DEMO_REPO must not exist yet: the script creates it as a private repo. Without DEMO_REPO the run
# stays local and stops before the PR step.
set -u
export AUTOPILOT_MODEL="${AUTOPILOT_MODEL:-haiku}"
P=/tmp/apdemo/landing
rm -rf "$P"; mkdir -p "$P"; cd "$P" || exit 1
cat > SPEC.md <<'S'
# Acme Notes landing page

A one-page marketing site for a fictional note-taking app, "Acme Notes". No build step, no dependencies.

## Acceptance criteria
1. `index.html` has a hero (one `h1`, a tagline, a call-to-action link to `#pricing`), a features section with three features, a pricing section with two plans, and a footer.
2. Styles live in `styles.css`; the page has a viewport meta tag and at least one media query, so it works at 375px and 1280px wide.
3. Accessible basics: `<html lang>`, `alt` on every image, headings in order, no empty links.
4. No external requests and no JavaScript: no `http://` or `https://` in any `src` or `href`, no `<script>`.
5. `index.html` and `styles.css` together are under 30 KB.

## Verification
`./verify.sh` exits 0 and checks every criterion, using only bash and the python3 standard library.
S
printf '.autopilot/\n' > .gitignore
git init -q -b main && git add . && git commit -qm "SPEC.md"
if [ -n "${DEMO_REPO:-}" ]; then
  gh repo create "$DEMO_REPO" --private --source . --remote origin --push >/dev/null 2>&1 || { echo "could not create $DEMO_REPO" >&2; exit 1; }
fi
p() { printf '\033[1;32m$\033[0m %s\n' "$*"; sleep 1; }
p "cat SPEC.md"; cat SPEC.md; sleep 3
p "autopilot start"; autopilot start | sed -e "s#/private$P#.#g" -e "s#$P#.#g"; sleep 4
p "autopilot log"
autopilot log "$P" 2>/dev/null &
L=$!; disown $L
for _ in $(seq 1 1800); do [ -f AUTOPILOT_DONE.md ] || [ -f AUTOPILOT_BLOCKED.md ] && break; sleep 1; done
while [ -f .autopilot/runner.pid ] && kill -0 "$(cat .autopilot/runner.pid)" 2>/dev/null; do sleep 1; done
sleep 1; kill $L 2>/dev/null; pkill -f "tail -n 50 -f $P" 2>/dev/null
echo; p "autopilot status"; autopilot status | sed -n '1,4p'; sleep 2
p "./verify.sh"; ./verify.sh 2>&1 | tail -8; sleep 3
if [ -n "${DEMO_REPO:-}" ]; then
  p "gh pr view --json title,url,headRefName,files"
  gh pr view --json title,url,headRefName,files -q '"\(.title)\n\(.url)\nbranch: \(.headRefName)\nfiles: \([.files[].path] | join(", "))"'
  sleep 3
fi
p "git log --oneline"; git log --oneline | head -8; sleep 3
