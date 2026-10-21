"""Display-only cleanup of the autopilot demo recording.

Shortens the temp project path to ./, colors the log tags, and truncates `tool` lines to
one row so long shell commands don't wrap. Claude's messages (`say`) and all other output
are left as recorded. Usage: tidy_cast.py <in.cast> <out.cast> <cols>
"""
import json, re, sys
src, dst, cols = sys.argv[1], sys.argv[2], int(sys.argv[3])
lines = open(src).read().splitlines()
hdr = json.loads(lines[0])
out = [json.dumps(hdr)]
GREEN, CYAN, DIM, BOLD, RST = '\x1b[32m', '\x1b[36m', '\x1b[2m', '\x1b[1m', '\x1b[0m'
def fix(l):
    l = l.replace('/private/tmp/apdemo/slugify/', './').replace('/private/tmp/apdemo/slugify', '.').replace('/tmp/apdemo/slugify', '.')
    m = re.match(r'^(tool|say|init|end)(\s+)(.*)$', l)
    if not m: return l
    tag, sp, rest = m.groups()
    if tag == 'tool':
        full = tag + sp + rest
        if len(full) > cols - 1: full = full[:cols - 2] + '…'
        return CYAN + full[:4] + RST + DIM + full[4:] + RST
    if tag == 'say': return BOLD + 'say' + RST + sp + rest
    if tag == 'end': return GREEN + BOLD + tag + sp + rest + RST
    return DIM + tag + sp + rest + RST
for l in lines[1:]:
    e = json.loads(l)
    if e[1] == 'o':
        e[2] = '\r\n'.join(fix(x) for x in e[2].split('\r\n'))
    out.append(json.dumps(e))
open(dst, 'w').write('\n'.join(out) + '\n')
