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

# The two courses in the x86-64 section share a file-name prefix: the
# assembly course owns `x86_*.ch` and the ABI course owns both `x86_*.ch`
# (x86_calling, x86_frame, ...) and `x86abi_landing.ch`, so a single
# `COURSE[:3]` prefix check silently put the ABI course's pages into the
# ASSEMBLY course's audit and vice versa.  The prefixes and the recorded
# output file are therefore named per course, and a course that is not in
# the table falls back to the old behaviour.
PREFIXES = {
    "x86asm": ("x86_asm.ch", "x86_integers.ch", "x86_flags.ch", "x86_vex.ch",
               "x86_map.ch", "x86asm_landing.ch"),
    "x86abi": ("x86_calling.ch", "x86_frame.ch", "x86_saved.ch",
               "x86_varargs.ch", "x86_unwind.ch", "x86_verify.ch",
               "x86abi_landing.ch"),
    # The THIRD course of the section.  Nine concepts plus a landing page, and
    # the last concept is `x86_boundary.ch` and not `x86_verify.ch`: the plan
    # gives the id `x86-verify` to all THREE of the remaining courses, and a
    # concept id is resolved GLOBALLY by render_concept() in web/src/helpers.ch
    # with no course in the key, so three courses cannot share one.  The first
    # course to take the name keeps it, and this one takes the name of the
    # thing it measures.
    "x86sys": ("x86_syscall.ch", "x86_exceptions.ch", "x86_rings.ch",
               "x86_cr.ch", "x86_debug.ch", "x86_virtual.ch", "x86_paging.ch",
               "x86_pmu.ch", "x86_boundary.ch", "x86sys_landing.ch"),
    # The FOURTH course of the section.  Six concepts plus a landing page,
    # and the last concept is `x86_bytes.ch` and not `x86_verify.ch`: the
    # plan gives the id `x86-verify` to all THREE of the remaining courses,
    # x86abi took it, and a concept id is resolved GLOBALLY by
    # render_concept() with no course in the key.  This one is named for
    # what its artifact does, which is encode thirty instructions and
    # decode them back.
    "x86simd": ("x86_sse.ch", "x86_avx.ch", "x86_avx512.ch", "x86_atomics.ch",
                "x86_order.ch", "x86_bytes.ch", "x86simd_landing.ch"),
    # The AArch64 course.  Five concepts plus a landing page, all prefixed
    # `a64_` for the same reason the four above are prefixed `x86_`: a concept
    # id is resolved globally, and the five ids here were checked against every
    # other course in content/src before this table was written.  The prefix
    # `a64_` matches no existing file, and the block filter below learned about
    # `./a64dec.py` rather than `./x86dec` for the same reason -- a filter
    # that names one artifact's command line silently skips every page of the
    # next one.
    "a64asm": ("a64_asm.ch", "a64_encoding.ch", "a64_immediate.ch",
               "a64_cond.ch", "a64_verify.ch", "a64asm_landing.ch"),
    # The second AArch64 course.  Five concepts plus a landing page.  Note
    # that its artifact is `a64abi.py` and NOT `a64dec.py`, so it needed its
    # own OUTPUTS entry for the same reason the two sections needed their own:
    # a table entry that names one course's output file leaves the next
    # course's pages silently unchecked against a file they do not belong to.
    "a64abi": ("a64_aapcs.ch", "a64_registers.ch", "a64_frame.ch",
               "a64_save.ch", "a64_unwind.ch", "a64abi_landing.ch"),
    # The THIRD AArch64 course.  Six concepts plus a landing page, and the
    # last concept is `a64_evidence.ch` and NOT `a64_verify.ch`: the plan
    # names `a64-verify`, a64asm took that name in the first course of the
    # section, and a concept id is resolved GLOBALLY by render_concept() in
    # web/src/helpers.ch with no course in the key.  The FILE has to be
    # renamed too and not only the id -- content/src already holds
    # a64_verify.ch from a64asm, so writing this course's artifact page to
    # the same path would have silently replaced that course's concept.
    "a64sys": ("a64_syscall.ch", "a64_exceptions.ch", "a64_interrupts.ch",
               "a64_virtual.ch", "a64_pagetables.ch", "a64_evidence.ch",
               "a64sys_landing.ch"),
    # The FOURTH and LAST AArch64 course.  Five concepts plus a landing page,
    # and every id is DISJOINT from the three AArch64 courses before it, which
    # is the whole point: a concept id is resolved GLOBALLY by
    # render_concept() in web/src/helpers.ch with no course in the key, so two
    # courses cannot claim one name.  Two of these five are deliberately NOT
    # the section plan's names (`a64-crypto-simd` and `a64-ldst`); the
    # reasons are in web/src/helpers.ch and they are about what a concept id
    # should name, not about availability.
    #
    # Its artifact is `a64data.py` and its output is `a64data.out`, so it
    # needs its own OUTPUTS entry for the reason the second and third
    # AArch64 courses did: a table that names one course's output file leaves
    # the next course's pages silently checked against a file they do not
    # belong to.  The quoted-block filter below learned about `./a64data.py`
    # for the same reason it learned about `./a64dec.py` and `./a64abi.py`.
    "a64simd": ("a64_neon.ch", "a64_neonspace.ch", "a64_atomic.ch",
                "a64_order.ch", "a64_dataflow.ch", "a64simd_landing.ch"),
    # The RISC-V section's FIRST course.  Five concepts plus a landing page,
    # and every id is `rv-` prefixed for the reason the AArch64 comment above
    # gives: a concept id is resolved GLOBALLY by render_concept() in
    # web/src/helpers.ch with no course in the key, and the section plan
    # reuses `rv-verify` in TWO of its four courses (rvasm and rvpriv), so
    # only one of them can have it and the other has to be named for what it
    # does.  It needs its own OUTPUTS entry because its artifact is
    # `rvdec.py` and its output is `rvdec.out`, and a table that names one
    # course's output leaves the next course's pages silently checked against
    # a file they do not belong to.
    "rvasm": ("rv_isa.ch", "rv_encoding.ch", "rv_compressed.ch",
              "rv_immediate.ch", "rv_verify.ch", "rvasm_landing.ch"),
}
OUTPUTS = {
    "x86asm": "x86dec.out",
    "x86abi": "abidump.out",
    "x86sys": "sysdump.out",
    "x86simd": "vecdump.out",
    "a64asm": "a64dec.out",
    "a64abi": "a64abi.out",
    "a64sys": "a64sys.out",
    "a64simd": "a64data.out",
    "rvasm": "rvdec.out",
}
PREF = PREFIXES.get(COURSE, (COURSE[:3],))
if not isinstance(PREF, tuple):
    PREF = (PREF,)
OUT = os.path.join(ROOT, "courses", COURSE, "assets", "samples",
                   OUTPUTS.get(COURSE, "x86dec.out"))

# Numbers a page quotes on purpose that are NOT in the artifact, with the
# reason.  Adding to this list is a decision, not a convenience.
EXEMPT = {
    "155":  "the harness's own check count",
    "0.86": "the ISA course's factor, which this page deliberately does not "
            "restate",
    "13.05": "the smp course's factor, not this one's",
    "61.9": "the memory course's factor, not this one's",
    "3.89": "the simd course's factor, not this one's",
    # The AArch64 course's own harness count, which the artifact does not
    # print and could not: the harness counts itself after the run, so the
    # number lives in crosscheck.py's own output and is quoted as such.
    "243":  "the a64asm harness's own check count",
    "166":  "the a64abi harness's own check count",
    "210":  "the a64sys harness's own check count",
    "268":  "the a64simd harness's own check count",
    "128":  "the rvasm harness's own check count, which the artifact cannot "
            "print because the harness counts itself after the run",
    "0x9f": "a hint encoding quoted in a64sys, present in a64sys.out",
    "0x80aa": "a c.mv encoding quoted on the rv-compressed page; it is in "
              "rvdec.out inside section 4C's refusal table",
    "0x552023": "the 4-byte `sw` the rv-compressed page contrasts against a "
                "refused `c.sw`; section 4C prints it",
    "0x00b5": "the B-type words on the rv-immediate page, printed in full by "
              "section 7's offset table",
}

# The command lines a quoted-output block may name.  A block that contains one
# of these is showing recorded tool output; a block that contains none is the
# author's own prose in a monospace box, and its decimals are arithmetic rather
# than measurement.  This is the SAME list a course is added to twice -- once
# here and once in PREFIXES -- and that duplication is deliberate rather than
# unfortunate: a course is a PAGE SET and a COMMAND, and a tool that derived
# one from the other would stop being able to check a course whose pages
# quote a command no course name resembles.
ARTIFACT_CMDS = ("./x86dec", "./sysdump", "./a64dec", "./a64abi", "./a64sys",
                 "a64sys.py", "./a64data", "a64data.py", "./rvdec",
                 "rvdec.py", "crosscheck.py",
                 "build_samples.sh")

TICK = re.compile(r"(\d+\.\d{3}) ticks/op")
HEX = re.compile(r"(0x[0-9a-f]{8,16})\b")
RATIO = re.compile(r"(\d+\.\d{2})x\b")

fails = 0
checked = 0

for name in sorted(os.listdir(os.path.join(ROOT, "content", "src"))):
    if not name.endswith(".ch"):
        continue
    if name not in PREF:
        continue
    path = os.path.join(ROOT, "content", "src", name)
    body = open(path, errors="replace").read()
    # Only look inside the quoted-output blocks.  A page's PROSE also contains
    # decimals and they are the author's arithmetic, not the artifact's.
    blocks = re.findall(r"<pre>(.*?)</pre>", body, re.S)
    for b in blocks:
        # A quoted-output block is one that SHOWS a command.  The first
        # version of this filter named four commands -- x86dec, sysdump,
        # objdump, and a `$` prompt -- and the AArch64 pages quote
        # `./a64dec.py` with a `$` prompt, so they happened to pass; the
        # filter was widened here anyway because a filter that passes by luck
        # is a filter that will fail by accident.  The check is now: does the
        # block contain a shell prompt or a known artifact command?
        # The artifact list is a growing TABLE rather than a growing
        # condition, and it is a table because the condition form has now
        # been extended four times and each extension is a chance to type a
        # prefix that no page uses -- a filter that skips every page of the
        # next course reports clean, which is the failure mode this whole
        # tool exists to prevent.
        if "$ " not in b and not any(k in b for k in ARTIFACT_CMDS) \
                and "objdump" not in b:
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
