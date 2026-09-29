#!/usr/bin/env python3
"""check_quotes.py -- every number a concept page quotes must exist in the
RECORDED artifact output.

This is the mechanical half of rule 2 in `docs/x86-64-section-plan.md`
("every number in a concept comes out of the recorded artifact output").  It
was written because the numbers on this machine move a great deal between
runs -- three runs of the same artifact produced single-pair ratios of 2.00x,
0.55x and 2.77x -- and a page that quotes a number from a run that is not the
recorded one is quoting a number from a machine nobody will ever have.

The rule it enforces is deliberately narrow.  It extracts three kinds of token
from a concept page and requires each to be present in x86dec.out:

  * a decimal with three places and the word `ticks/op` on the same line
  * a hex bit pattern of eight or sixteen digits
  * an `N.NNx` ratio inside a `sed`-quoted block

Tokens that are prose, arithmetic the page performs itself, or a figure the
page explicitly attributes to ANOTHER course are exempt, and the reason is in
the exclusion list below rather than in a comment nobody reads.

Usage:  python3 tools/check_quotes.py [course]
"""
import os
import re
import sys

COURSE = sys.argv[1] if len(sys.argv) > 1 else "x86asm"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "courses", COURSE, "assets", "samples", "x86dec.out")

# Numbers a page quotes on purpose that are NOT in the artifact, with the
# reason.  Adding to this list is a decision, not a convenience.
EXEMPT = {
    "155":  "the harness's own check count",
    "0.86": "the ISA course's factor, which this page deliberately does not "
            "restate",
    "13.05": "the smp course's factor, not this one's",
    "61.9": "the memory course's factor, not this one's",
    "3.89": "the simd course's factor, not this one's",
}

TICK = re.compile(r"(\d+\.\d{3}) ticks/op")
HEX = re.compile(r"(0x[0-9a-f]{8,16})\b")
RATIO = re.compile(r"(\d+\.\d{2})x\b")

fails = 0
checked = 0

for name in sorted(os.listdir(os.path.join(ROOT, "content", "src"))):
    if not name.startswith(COURSE[:3]) or not name.endswith(".ch"):
        continue
    path = os.path.join(ROOT, "content", "src", name)
    body = open(path, errors="replace").read()
    # Only look inside the quoted-output blocks.  A page's PROSE also contains
    # decimals and they are the author's arithmetic, not the artifact's.
    blocks = re.findall(r"<pre>(.*?)</pre>", body, re.S)
    for b in blocks:
        if "$ " not in b and "./x86dec" not in b and "objdump" not in b:
            continue
        for pat, kind in ((TICK, "ticks/op"), (HEX, "hex"), (RATIO, "ratio")):
            for m in pat.finditer(b):
                tok = m.group(0) if kind == "ratio" else m.group(1)
                if tok in EXEMPT or tok[2:] in EXEMPT:
                    continue
                checked += 1
                if tok not in open(OUT, errors="replace").read():
                    print("  MISSING  %-24s %-20s (%s)" % (name, tok, kind))
                    fails += 1

print("")
print("check_quotes: %d tokens from quoted output blocks, %d not in %s"
      % (checked, fails, os.path.basename(OUT)))
if fails:
    print("PROBLEMS: a concept quotes a number the recorded run does not contain.")
else:
    print("ALL CONSISTENT: every quoted figure is in the recorded artifact output")
sys.exit(1 if fails else 0)
