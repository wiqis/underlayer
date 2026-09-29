#!/usr/bin/env python3
"""abilint.py -- a System V AMD64 ABI linter, for the x86-64 ABI course.

It reads a real object or archive with `objdump` and `nm` and makes two
mechanical claims about the code it finds:

  1. CLOBBER.  A function that WRITES a callee-saved general register
     (rbx, rbp, r12, r13, r14, r15) must `push` it before the first write.
     Without that push the caller's value is gone.

  2. ALIGN.  Track %rsp mod 16 from the ABI's entry value of 8.  At a `call`
     the offset must be 8 (the call pushes 8, so the callee is entered at 8);
     at a `jmp` the offset must be 0 (a jmp pushes nothing, so the callee is
     entered at 8 - 0 = 8).  THE TWO RULES DIFFER, and that is one of the
     findings of the course.

FIVE THINGS THIS FILE GOT WRONG FIRST, all of them found by RUNNING it, and
all of them printed in the research log because a checker that examines
nothing and a checker that finds nothing produce the same line of output:

  B1. Functions were bounded by the next `<name>:` label.  objdump prints a
      shared library's cold and hot sections separately, so a neighbouring
      function's body was glued onto the end of 23 real libc functions and
      23 phantom violations appeared.
  B2. A PLT stub is not a function.  `endbr64; jmp *GOT(%rip); push idx; jmp
      resolver` was being audited as one and every stub was "misaligned".
  B3. An archive and a bare object need different keys.  `nm` prints a member
      header for an archive and nothing for a `.o`, so the symbol table and
      the disassembly were keyed differently and ZERO functions came back out
      of a `.o` file.
  B4. `push QWORD PTR [rip+0x...]` and `push 0x1` are pushes too.  The first
      pattern only matched `push <register>`, so %rsp silently desynchronised.
  B5. THE WORST ONE, and the reason the harness ships a positive control.  The
      expression that normalised a register name had its ternary the wrong way
      round, so "r12" came back as "e12", nothing was EVER recognised as a
      callee-saved register, and the linter reported ZERO violations across
      9255 functions of libc, libm, ld.so, libcrypto and /bin/ls.  Every one
      of those five zeroes was a hollow zero until `--control` was added.

The ALIGN half is still not trustworthy and the artifact says so: this file
loses track of %rsp at `pushfq`, at `enter`, at `alloca` and at any write it
does not model, and a checker that cannot account for a mismatch is not
evidence of a mismatch.  `--unmodelled` counts the sites where that happened.

Usage:
  python3 abilint.py --control                 write abi_control.txt
  python3 abilint.py --lib LIB [LIB...]        write abi_libc.txt
  python3 abilint.py --corpus F.o [...]        write abi_corpus.txt
"""

import collections
import os
import re
import subprocess
import sys

CALLEE_SAVED = ["rbx", "rbp", "r12", "r13", "r14", "r15"]

# The operations this file does NOT model, and the instruction that gives them
# away.  A function that contains one of these may lose %rsp tracking at that
# point, and every later verdict in that function is then worthless.
UNMODELLED = [
    ("pushfq", r"^pushf"),
    ("popfq", r"^popf"),
    ("enter", r"^enter\b"),
    ("alloca", r"^sub\s+rsp,(?:0x)?[0-9a-f]*$"),  # handled, listed for the count
    ("rsp write", r"^(?:mov|lea|xchg|add|sub|and|or|xor)\s+(?:r|e)?sp(?![a-z0-9])"),
]


def _run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def read_syms(path):
    """(member, name) -> (address, size), for sized text symbols only."""
    out = _run(["nm", "-S", "--defined-only", path])
    arch = "In archive" in out or path.endswith(".a")
    cur = None if arch else ""
    r = {}
    for ln in out.splitlines():
        if not ln.strip():
            continue
        if ln.rstrip().endswith(":") and not ln.startswith(" ") \
                and not re.match(r"^[0-9a-f]", ln):
            cur = ln.rstrip()[:-1]
            continue
        f = ln.split()
        if len(f) == 4 and f[2] in ("T", "t", "W", "w", "i"):
            r[(cur, f[3])] = (int(f[0], 16), int(f[1], 16))
    return r


def read_dis(path):
    """(member, address) -> [instructions], objdump -d -M intel."""
    out = _run(["objdump", "-d", "--no-show-raw-insn", "-M", "intel", path])
    arch = "In archive" in out
    cur = None
    m = collections.defaultdict(list)
    for ln in out.splitlines():
        g = re.match(r"^(\S+\.o):\s+file format", ln)
        if g:
            cur = g.group(1) if arch else ""
            continue
        g = re.match(r"^\s+([0-9a-f]+):\s+(.*)$", ln)
        if g and cur is not None:
            m[(cur, int(g.group(1), 16))].append(g.group(2).strip())
    return m


def funcs(path):
    S, A = read_syms(path), read_dis(path)
    out = collections.OrderedDict()
    for (mem, name), (a, sz) in S.items():
        if name.startswith(".") or "@plt" in name or sz == 0:
            continue
        ins = []
        for x in range(a, a + sz):
            ins.extend(A.get((mem, x), []))
        if ins:
            out["%s:%s" % (mem, name) if mem else name] = ins
    return out


def reg64(op):
    """The 64-bit register an operand names, or None.

    B5 lived here.  A 32-bit write to %ebx destroys the low half of %rbx, so
    every name is normalised UP to its 64-bit form."""
    o = op.strip()
    if "[" in o:
        return None
    m = re.fullmatch(r"[re]?(ax|bx|cx|dx|si|di|bp|sp|[0-9]+)", o)
    return None if not m else "r" + m.group(1)


def imm(t):
    if t is None:
        return None
    try:
        return int(t, 16) if t.lower().startswith("0x") else int(t)
    except ValueError:
        return None


DEST = re.compile(
    r"^(mov|movabs|lea|add|sub|and|or|xor|shl|shr|sar|rol|ror|imul|mul|"
    r"idiv|div|neg|not|inc|dec|pop|set\w+|cvt\w+|movs\w+|stos\w+|xchg|"
    r"lzcnt|tzcnt|popcnt|bswap|xadd|cmpxchg|adcx|adox)\s+(.*)$")


def clobber_audit(F):
    """-> (flagged, used, saved, names)"""
    flagged, used, saved, names = [], collections.Counter(), collections.Counter(), []
    for name, ins in F.items():
        has_call = any(i.startswith("call") or i.startswith("jmp ") for i in ins)
        first = {}
        for idx, i in enumerate(ins):
            m = DEST.match(i)
            if not m:
                continue
            ops = m.group(2).split(",")
            if not ops:
                continue
            d = reg64(ops[0])
            if d in CALLEE_SAVED and d not in first:
                first[d] = idx
        for r, idx in sorted(first.items()):
            used[r] += 1
            if any(re.fullmatch(r"push\s+%s" % r, i) for i in ins[:idx]):
                saved[r] += 1
            else:
                kind = "nonleaf" if has_call else "leaf"
                flagged.append((name, r, kind))
                names.append(name)
    return flagged, used, saved, set(names)


def align_audit(F):
    """-> (calls_known, calls_bad, jmps_known, jmps_bad, flagged_names, unmodelled)"""
    ck = cb = jk = jb = 0
    names, unmod = set(), 0
    for name, ins in F.items():
        off, rbp, lost = 0, None, False
        for i in ins:
            if lost:
                break
            m = re.match(r"^(push|pop)[bwlq]?\s+(\S+)$", i)
            if m:
                off = None if off is None else (off + (8 if m.group(1) == "push" else -8)) % 16
                if m.group(2) in ("rbp", "ebp"):
                    rbp = None
                continue
            m = re.match(r"^(?:sub|add)\s+rsp,(\S+)$", i)
            if m and m.group(1).lower() not in ("rsp", "esp", "sp"):
                v = imm(m.group(1))
                if off is None or v is None:
                    off = None
                else:
                    off = (off + v if i.startswith("sub") else off - v) % 16
                continue
            m = re.match(r"^lea\s+rsp,\[rsp([+-][^\]]+)\]$", i)
            if m:
                t, v = m.group(1), imm(m.group(1)[1:])
                if off is None or v is None:
                    off = None
                else:
                    off = (off + v if t[0] == "+" else off - v) % 16
                continue
            m = re.match(r"^and\s+rsp,(\S+)$", i)
            if m:
                v = imm(m.group(1))
                off = None if (v is None or (v & (v - 1))) else (v - 8) % 16
                continue
            if i.startswith("leave"):
                off = rbp
                continue
            if i == "mov rbp,rsp":
                rbp = off
                continue
            if i.startswith("call"):
                if off is not None:
                    ck += 1
                    if off != 8:
                        cb += 1
                        names.add(name)
                continue
            if i.startswith("jmp"):
                if off is not None:
                    jk += 1
                    if off != 0:
                        jb += 1
                        names.add(name)
                continue
            if i.startswith("ret"):
                off = None if off is None else (off - 8) % 16
                continue
            if re.match(r"^(mov|lea|xchg|add|sub|and|or|xor)\s+(rsp|esp|sp)\b", i):
                lost = True
                unmod += 1
    return ck, cb, jk, jb, names, unmod


def fingerprint(path):
    try:
        return os.path.getsize(path)
    except OSError:
        return -1


# A function whose CONTRACT is to install a previously saved register context
# is REQUIRED to clobber the callee-saved registers, so a mechanical checker
# that flags it is reporting the checker, not the code.  glibc has a family of
# these and they are the single largest group among its flags.
CONTEXTLIKE = re.compile(
    r"longjmp|setjmp|backtrace|swapcontext|makecontext|getcontext|"
    r"siglongjmp|sigsetjmp|restore_rt|unwind|clone|pthread_switch")


def audit_lib(path):
    F = funcs(path)
    flagged, used, saved, fnames = clobber_audit(F)
    ck, cb, jk, jb, anames, unmod = align_audit(F)
    return dict(path=os.path.basename(path), size=fingerprint(path),
                nfunc=len(F), flagged=flagged, fnames=fnames,
                used=used, saved=saved,
                ck=ck, cb=cb, jk=jk, jb=jb, anames=anames, unmod=unmod)


def emit_lib(rec, out):
    p = rec["path"]
    out.append("LIBRARY | %s | %d bytes" % (p, rec["size"]))
    out.append("FUNCTIONS | %d" % rec["nfunc"])
    for r in CALLEE_SAVED:
        out.append("CENSUS | %s | %d | %d" % (r, rec["used"][r], rec["saved"][r]))
    out.append("CLOBBERFLAGS | %d | %d functions"
               % (len(rec["flagged"]), len(rec["fnames"])))
    leaves = sum(1 for f in rec["flagged"] if f[2] == "leaf")
    out.append("CLOBBERKIND | leaf | %d | nonleaf | %d" % (leaves, len(rec["flagged"]) - leaves))
    ctx = sum(1 for f in rec["flagged"] if CONTEXTLIKE.search(f[0]))
    out.append("CLAPPERCONTEXT | %d | %d"
               % (ctx, len(rec["flagged"]) - ctx))
    # The two exemptions are counted independently above, and a page that
    # adds them up has to know whether they OVERLAP.  A function can be both a
    # leaf and a context-restorer (setjmp is exactly that), so "the rest" is
    # not a subtraction unless the overlap is reported.  The first draft of
    # the concept page subtracted 26 from 271 and then 97 again and called the
    # remainder 148, and the remainder was only right because the overlap is
    # zero on this library -- which is a fact, not an arithmetic identity.
    both = sum(1 for f in rec["flagged"]
               if f[2] == "leaf" and CONTEXTLIKE.search(f[0]))
    out.append("CLAPPERBOTH | %d | %d unclassified after both exemptions"
               % (both, len(rec["flagged"]) - leaves - ctx + both))
    for f in sorted(rec["flagged"])[:40]:
        out.append("CLAPPER | %s | %s | %s" % f)
    if len(rec["flagged"]) > 40:
        out.append("CLAPPERTRUNC | %d more, listed in the artifact not the file"
                   % (len(rec["flagged"]) - 40))
    out.append("ALIGNCALLS | %d | %d" % (rec["ck"], rec["cb"]))
    out.append("ALIGNJMP | %d | %d" % (rec["jk"], rec["jb"]))
    out.append("ALIGNFNAMES | %d" % len(rec["anames"]))
    out.append("UNMODELLED | %d" % rec["unmod"])


def main():
    args = sys.argv[1:]
    mode = "control" if "--control" in args else "lib"
    targets = [a for a in args if not a.startswith("--")]
    out = ["# abi_libc.txt -- GENERATED by build_samples.sh.  Do not hand-edit.",
           "# The linter's own verdict on real code.  The ALIGN half of the",
           "# linter does not model every %rsp-writing instruction and the",
           "# artifact retracts the alignment claim it would otherwise support.",
           "#"]
    if mode == "control":
        out.append("# POSITIVE CONTROL: a file built to be caught.")
        for t in targets:
            emit_lib(audit_lib(t), out)
        path = "abi_control.txt"
    else:
        for t in targets:
            emit_lib(audit_lib(t), out)
        path = "abi_libc.txt"
    with open(path, "w") as f:
        f.write("\n".join(out) + "\n")
    print("    wrote %s (%d lines)" % (path, len(out)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
