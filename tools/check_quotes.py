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
    # The RISC-V section's SECOND course, and it needs its own entry for the
    # same reason every course above does: a course absent from PREFIXES
    # passes this tool WITHOUT BEING CHECKED, which is the one failure mode
    # the tool exists to prevent.  Note the id collision this entry has to
    # avoid -- `rv_compressed.ch` belongs to `rvasm` and is listed there, and
    # this course's page of the same subject is `rv_compressed_cost.ch` with
    # the `_cost` suffix, because render_concept() resolves ids GLOBALLY and
    # two pages cannot both be `rv-compressed`.  The tuple here lists only
    # THIS course's six files.
    "rvabi": ("rv_calling.ch", "rv_noflags.ch", "rv_registers.ch",
              "rv_compressed_cost.ch", "rvabi_landing.ch"),
    # The RISC-V section's FOURTH course, and the one with no runtime subject
    # at all: no machine, no emulator, no linker, so every number in it is a
    # bit pattern, a count of bit patterns, an arithmetic identity or a
    # refusal from a real assembler.  That does not make it exempt -- an
    # exempt course is one this tool cannot check, and the whole point of the
    # entry is that a course absent from PREFIXES passes WITHOUT BEING CHECKED.
    #
    # The id collision this entry has to avoid is the one the plan creates:
    # `rv-verify` is given to BOTH `rvasm` and `rvpriv`, and render_concept()
    # resolves ids GLOBALLY with no course in the key, so `rvasm` kept it and
    # this course's artifact page is `rv_boundary.ch` instead.  The tuple here
    # lists only THIS course's five files, and none of them collides with the
    # two entries above.
    "rvpriv": ("rv_modes.ch", "rv_paging.ch", "rv_traps.ch",
               "rv_boundary.ch", "rvpriv_landing.ch"),
    # The RISC-V section's FOURTH and LAST course, and the one this tool
    # matters most for.  Four concepts plus a landing page, and every id is
    # DISJOINT from the three RISC-V courses above it -- which is the whole
    # point, because render_concept() resolves ids GLOBALLY with no course in
    # the key.  §KEEP§THE THREE RETIRED-IDS ARE WORTH NAMING HERE, BECAUSE TWO OF
    # THEM ARE PREFIXES OF LIVE ONES: `x86-atom` OPENS `x86-atomics` AND
    # `rv-noflag` OPENS `rv-noflags`, SO A LINK CHECK THAT USED A SUBSTRING
    # WOULD REJECT THIS COURSE FOR LINKING TO A PAGE ONE CHARACTER LONGER THAN
    # AN ID IT HAS RETIRED.  §KEEP§A NEGATIVE THAT CANNOT BE SATISFIED BY THE
    # ARTIFACT IT IS WRITTEN FOR IS NOT A NEGATIVE; IT IS A BUG WEARING ONE.
    "rvat": ("rv_amo.ch", "rv_fence.ch", "rv_vector.ch", "rv_dataflow.ch",
             "rvat_landing.ch"),
    # The compiler backend course, and the one this tool matters most for
    # AFTER rvat, because its output file is the FOURTH name that collides with
    # a sibling's subject rather than with a sibling's filename.  compback.out
    # records instruction counts for x86-64, aarch64 AND riscv64 in the same
    # tables, and it records the SAME hex words the assembly courses record --
    # 0x9b000820 is an AArch64 `madd` and both `a64asm` and `rvasm` print
    # AArch64 and RISC-V words in their own recordings.  So a page of this
    # course that quoted the WRONG course's output would find most of its hex
    # tokens present, which is exactly the quiet partial pass this table
    # exists to prevent.
    #
    # The entry lists SEVEN files and not six, and the seventh is the landing
    # page: the landing page of every course above quotes measured output too,
    # and a PREFIXES entry that left it out would leave the most-quoted page in
    # the course unchecked while the file count still looked plausible.
    #
    # Two more things about this course are worth recording next to the entry,
    # because both are the kind of thing that makes a token check pass for the
    # wrong reason.  FIRST, section 10 of the artifact -- the ONLY section in
    # the whole collection that can put a ratio on real memory traffic -- prints
    # RATIOS ONLY and contains no `ticks/op` at all, so the TICK regex below has
    # nothing to find in this course's pages: the exact ticks were moved into a
    # SEPARATE file, `cbbench.out`, precisely because a report containing a
    # clock reading cannot be byte-identical between two runs.  SECOND, the
    # harness's own check count (171) is in EXEMPT below, because the harness
    # counts itself after the run and the number therefore cannot be in the
    # output it is checking -- the same reason the five numbers above it are.
    "compback": ("cb_ir.ch", "cb_isel.ch", "cb_regalloc.ch", "cb_sched.ch",
                 "cb_abi.ch", "cb_verify.ch", "compback_landing.ch"),
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
    # This course's artifact is `rvabi.py` and its output is `rvabi.out`, and
    # it is a DIFFERENT file from every name above.  Without this entry a
    # table that named only `rvdec.out` would check this course's pages
    # against the encoding course's recording -- and the two share a
    # `rv_compressed` subject, so the numbers are similar enough to pass.
    "rvabi": "rvabi.out",
    # This course's artifact is `rvpriv.py` and its output is `rvpriv.out`, and
    # it is a DIFFERENT file from every name above.  This one matters more than
    # the rvabi entry did, because the two output files share a subject: both
    # record the same CSR instruction encodings, and a page that quoted
    # rvabi.out by mistake would find most of its numbers present -- the
    # relocation codes, the shift amounts and the `a7`/`a6` XOR all appear in
    # both.  So a missing entry here would produce a quiet partial pass rather
    # than an obvious miss, which is the failure mode this table exists to
    # prevent.
    "rvpriv": "rvpriv.out",
    # This course's artifact is `rvat.py` and its output is `rvat.out`, and it
    # is a DIFFERENT file from every name above.  This entry matters more than
    # the rvpriv one did, because of a coincidence worth recording: §KEEP§BOTH
    # OUTPUT FILES CONTAIN THE SAME TWO HEX WORDS -- `0x00b6252f` (amoadd.w) AND
    # `0x0330000f` (fence rw, rw) -- SO A PAGE THAT QUOTED THE WRONG ONE WOULD
    # FIND MOST OF ITS HEX TOKENS PRESENT.  §KEEP§A MISSING ENTRY HERE PRODUCES A
    # QUIET PARTIAL PASS RATHER THAN AN OBVIOUS MISS, WHICH IS THE FAILURE MODE
    # THIS TABLE EXISTS TO PREVENT, AND IT IS WHY THE CHECK BELOW REPORTS HOW MANY
    # TOKENS IT EXAMINED.
    "rvat": "rvat.out",
    # This course's artifact is `compback.py` and its output is `compback.out`,
    # and it is a DIFFERENT file from every name above.  This entry matters more
    # than any of the previous ones for a reason worth stating precisely: §KEEP§
    # compback.out CONTAINS A RATIO AND A COUNT FOR THE SAME SUBJECT THAT
    # rvat.out ALSO RECORDS -- both courses compile the same three targets and
    # both count the machine instructions -- §KEEP§ SO A PAGE OF THIS COURSE THAT
    # QUOTED THE WRONG ONE WOULD FIND MOST OF ITS DECIMAL TOKENS PRESENT AND
    # PASS.  §KEEP§ AND THE COLLECTION HAS NOW PAID FOR A QUIET PARTIAL PASS
    # FOUR TIMES, WHICH IS WHY THE COUNT OF TOKENS EXAMINED IS PRINTED BELOW AND
    # WHY A COURSE THAT ADDS PAGES WITHOUT ADDING ITSELF TO PREFIXES SHOWS UP AS
    # A FILE COUNT THAT DID NOT MOVE.
    "compback": "compback.out",
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
    "171":  "the rvabi harness's own check count, for the same reason",
    "391":  "the rvpriv harness's own check count, for the same reason.  "
            "Eighteen of those are pinned claim sentences, so the count is a "
            "property of the harness and not of the artifact's output -- which "
            "is exactly why it cannot be in the output.",
    "0x9f": "a hint encoding quoted in a64sys, present in a64sys.out",
    "0x80aa": "a c.mv encoding quoted on the rv-compressed page; it is in "
              "rvdec.out inside section 4C's refusal table",
    "0x552023": "the 4-byte `sw` the rv-compressed page contrasts against a "
                "refused `c.sw`; section 4C prints it",
    "0x00b5": "the B-type words on the rv-immediate page, printed in full by "
              "section 7's offset table",
    # NO ENTRY FOR compback, AND THE REASON IS WORTH RECORDING RATHER THAN
    # LEAVING AS A SILENT OMISSION.  §KEEP§ Adding one "so it is there if it is
    # ever needed" would be the same class of mistake the NORMALISER fire table
    # in the artifacts exists to catch: an entry that no check can reach is a
    # row with a zero, and a row with a zero reads as a permission.  §KEEP§ All
    # THREE regexes above were run against every figure this course's pages
    # quote, and the result is a finding about the SHAPE of the subject rather
    # than about the course:
    #
    #   * TICK  finds NOTHING, and cannot.  compback.out contains no `ticks/op`
    #     AT ALL -- the raw ticks were moved into the separate file
    #     `cbbench.out` precisely because a report containing a clock reading
    #     and a file that is byte-identical between two runs cannot both be
    #     true.  A page that printed one would be quoting a number the course
    #     deliberately made unquotable, and this table should NOT be the place
    #     that quietly permitted it.
    #   * RATIO finds almost nothing, because this course's ratios are printed
    #     as BANDS ("1.25-1.56") rather than as "1.25x".  The regex needs a
    #     trailing `x`, and the report's own reason for the bands is the one
    #     printed above: printing "1.12x" for one arm and "1.11x" for another
    #     when they differ by less than the floor would be a third decimal
    #     place deciding which run you get.
    #   * HEX finds the real thing, and it is the only one of the three that
    #     does.  The instruction-selection page quotes ten AArch64 words and
    #     the ABI page twelve more, all of them from the recorded encoder
    #     cross-check rather than from a disassembly a page typed out.
    #
    # So this course is checked on its hex tokens and NOT on its timing, and the
    # honest sentence is that the mechanical half of rule 2 reaches the bytes
    # and does not reach the clock.  The clock is checked by crosscheck.py's own
    # 171 assertions instead, which is the mechanism that CAN reach it.
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
                 "rvdec.py", "./rvabi", "rvabi.py", "crosscheck.py",
                 "build_samples.sh", "./rvpriv", "rvpriv.py",
                 # The RISC-V section's fourth course, and its pages quote
                 # `rvat.py` with a `$` prompt, which the prompt test alone
                 # would catch -- and the command is listed anyway for the
                 # reason the comment above this tuple gives: a filter that
                 # passes by luck is a filter that will fail by accident.
                 "rvat.py", "./rvat", "corrupt.py",
                  # The compiler backend course.  Three commands and all three
                  # are needed, which is worth saying because two of them look
                  # like they could be omitted and the omission would be
                  # SILENT: `compback.py --run` is the report itself,
                  # `crosscheck.py` and `corrupt.py` are the harness and its
                  # corruption suite, and a page that quotes the HARNESS's own
                  # output -- its 171 checks, its 22 corruptions, its verdicts
                  # -- names one of the last two rather than the first.  The
                  # `cbbench` entry is the FOURTH file this course quotes and
                  # the reason it is needed is not obvious: the raw ticks live
                  # in cbbench.out and NOT in compback.out, because a report
                  # containing a clock reading and a file that is byte-
                  # identical between two runs cannot both be true.  So the
                  # register-allocation page quotes both files, and a filter
                  # that knew only about compback.py would skip every block it
                  # takes from the other one.
                  "./compback", "compback.py", "./cbbench", "cbbench.c")

TICK = re.compile(r"(\d+\.\d{3}) ticks/op")
HEX = re.compile(r"(0x[0-9a-f]{8,16})\b")
# §KEEP§THE BARE-WORD VARIANT, AND IT IS OPT-IN PER COURSE BECAUSE IT IS A
# PROPERTY OF THE ARTIFACT AND NOT OF THE TOOL.  compback.out prints an
# instruction word BARE in its section 9 second-reader table (`8b010408`,
# `20a5a533`) and only `0x`-prefixes the same width of word in section 5
# (`0x9b000820`).  So a page that quoted the bare table FAITHFULLY had all
# twelve of its hex words skipped by the `0x`-requiring pattern above, and the
# tool reported ALL CONSISTENT over 7 tokens while the page carried twelve
# unchecked bit patterns -- the quiet partial pass this table exists to
# prevent, reached through TYPOGRAPHY rather than through a missing entry.
#
# It is NOT enabled globally, because enabling it globally was tried and
# reverted: it immediately surfaced seven tokens in FOUR other courses
# (`0000000000000023`, `00000000000283d0`, `0000000000000420`, `00a5a023`, two
# `0000000000000006`, and four BINARY literals `0b100110`/`0b100111`/
# `0b011010`/`0b011011` in `a64_encoding.ch` that the bare pattern grabbed out
# of a `0b` prefix and that are not hex words at all).  Adjudicating four
# courses' content from inside a change to a thirteenth one is how a shared
# tool acquires a hundred-line diff nobody asked for.  So the set below names
# the courses whose ARTIFACT prints words bare, which is the property the
# pattern is actually about, and a course that starts printing a bare word and
# is not in the table gets the old under-reaching behaviour rather than seven
# false alarms.
#
# The `0b` lookbehind is there because of `a64_encoding.ch`: `0b100110` is six
# binary digits that a naive bare pattern reads as a hex word.  A course that
# quotes binary literals as bare digits needs the exclusion in any case.
BARE_HEX_COURSES = ("compback",)
BARE_HEX = re.compile(r"(?<![0-9a-fxb])(?:0x)?([0-9a-f]{8}|[0-9a-f]{16})\b")
if COURSE in BARE_HEX_COURSES:
    HEX = re.compile(r"(0x[0-9a-f]{8,16})\b|(?<![0-9a-fxb])([0-9a-f]{8}|[0-9a-f]{16})\b")
    # the two alternation groups, so the caller unpacks whichever fired
    HEX_GROUP = (1, 2)
else:
    HEX_GROUP = (1,)
RATIO = re.compile(r"(\d+\.\d{2})x\b")

fails = 0
checked = 0
# HOW MUCH WAS LOOKED AT, and this is printed because the tool's worst failure
# mode is silent: a course absent from PREFIXES visits no files, extracts no
# tokens, and prints "0 not in <output>" -- which reads exactly like a clean
# course.  A tool that cannot say how much of the corpus it examined is a tool
# whose "ALL CONSISTENT" is not evidence of anything.  So the counts of FILES
# and of QUOTED BLOCKS are reported, and a course that adds pages without
# adding itself to PREFIXES shows up here as a file count that did not move.
files_seen = 0
blocks_quoted = 0

for name in sorted(os.listdir(os.path.join(ROOT, "content", "src"))):
    if not name.endswith(".ch"):
        continue
    if name not in PREF:
        continue
    files_seen += 1
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
        blocks_quoted += 1
        for pat, kind in ((TICK, "ticks/op"), (HEX, "hex"), (RATIO, "ratio")):
            for m in pat.finditer(b):
                if kind == "ratio":
                    tok = m.group(0)
                elif kind == "hex":
                    # HEX may have TWO alternation groups (see BARE_HEX above)
                    # and exactly one of them is set on any given match, so the
                    # token is whichever captured.  Leaving this as
                    # m.group(1) would read an unset group as None and print
                    # `None not in compback.out` -- a MISSING line whose token
                    # is the string "None", which is a failure report nobody
                    # can act on, and which a bare pattern reaching other
                    # courses would produce on every single match.
                    tok = next(g for g in (m.group(n) for n in HEX_GROUP)
                               if g)
                else:
                    tok = m.group(1)
                if tok in EXEMPT or tok[2:] in EXEMPT:
                    continue
                checked += 1
                if tok not in open(OUT, errors="replace").read():
                    print("  MISSING  %-24s %-20s (%s)" % (name, tok, kind))
                    fails += 1

print("")
print("check_quotes: %d of %s's %d page files, %d of their quoted blocks, "
      "%d tokens, %d not in %s"
      % (files_seen, COURSE, len(PREF), blocks_quoted, checked, fails,
         os.path.basename(OUT)))
if files_seen != len(PREF):
    print("PROBLEM: %d of the %d files listed in PREFIXES for %s are not on "
          "disk, or a page was added without being listed -- and a course "
          "with nothing to check prints the same line as a clean one."
          % (files_seen, len(PREF), COURSE))
    fails += 1
if blocks_quoted == 0:
    print("PROBLEM: no quoted block in %s names a command, so nothing was "
          "checked at all" % COURSE)
    fails += 1
if fails:
    print("PROBLEMS: a concept quotes a number the recorded run does not contain.")
else:
    print("ALL CONSISTENT: every quoted figure is in the recorded artifact output")
sys.exit(1 if fails else 0)
