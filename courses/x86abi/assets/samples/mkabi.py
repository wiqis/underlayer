#!/usr/bin/env python3
"""mkabi.py -- turn objdump output into the tables abidump.c audits.

This is the mechanical half of the course's distinctive idea: THE ABI IS A
CONTRACT BETWEEN TWO COMPILERS, SO YOU CAN CHECK THE COMPILER AGAINST IT.
The specification is the oracle, the compiled object is the test subject, and
nothing here is typed in by an author except the specification itself.

What is recovered, per caller function and per optimisation level:

  * which SOURCE went into which REGISTER, identified BY NAME.  The corpus's
    arguments are distinct `volatile` globals, and a linked executable makes
    objdump print the symbol in the `#` comment of every RIP-relative load, so
    the mapping is recovered from the disassembly rather than counted.

and, per callee:

  * the order in which the callee first READS each argument register, which is
    the order the parameters were declared in.

Two decisions here were learned the hard way and both are in the docstring of
the corpus:

  * a caller per callee, so no call site has to be identified by counting;
  * a LINKED executable, because in a .o every RIP-relative load reads
    `[rip+0x0]` and the argument's identity is not in the file at all.  The
    first version audited .o files and could tell that six registers were
    occupied and not one thing about which argument was in which.

Usage:  python3 mkabi.py EXE OUTFILE LABEL -O0
"""

import os
import re
import subprocess
import sys

LEVELS = ["O0", "O1", "O2", "Os"]

# ---------------------------------------------------------------- the oracle
# The System V AMD64 psABI, transcribed.  This is the specification; nothing
# below this line is measured, and everything below this line is checked.
ARG_INT = ["rdi", "rsi", "rdx", "rcx", "r8", "r9"]
ARG_SSE = ["xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5", "xmm6", "xmm7"]

# caller function -> {source: destination}, exactly as the psABI says.
SPEC = {
    "c_f0": {},
    "c_f1": {"v11": "rdi"},
    "c_f2": {"v11": "rdi", "v12": "rsi"},
    "c_f3": {"v11": "rdi", "v12": "rsi", "v13": "rdx"},
    "c_f4": {"v11": "rdi", "v12": "rsi", "v13": "rdx", "v14": "rcx"},
    "c_f5": {"v11": "rdi", "v12": "rsi", "v13": "rdx", "v14": "rcx", "v15": "r8"},
    "c_f6": {"v11": "rdi", "v12": "rsi", "v13": "rdx", "v14": "rcx", "v15": "r8",
             "v16": "r9"},
    "c_f7": {"v11": "rdi", "v12": "rsi", "v13": "rdx", "v14": "rcx", "v15": "r8",
             "v16": "r9", "v17": "stack"},
    "c_f8": {"v11": "rdi", "v12": "rsi", "v13": "rdx", "v14": "rcx", "v15": "r8",
             "v16": "r9", "v17": "stack", "v18": "stack"},
    "c_g1": {"w1": "xmm0"},
    "c_g2": {"w1": "xmm0", "w2": "xmm1"},
    "c_g8": {"w1": "xmm0", "w2": "xmm1", "w3": "xmm2", "w4": "xmm3",
             "w5": "xmm4", "w6": "xmm5", "w7": "xmm6", "w8": "xmm7"},
    "c_g9": {"w1": "xmm0", "w2": "xmm1", "w3": "xmm2", "w4": "xmm3",
             "w5": "xmm4", "w6": "xmm5", "w7": "xmm6", "w8": "xmm7",
             "w9": "stack"},
    "c_mx": {"w1": "xmm0", "w2": "xmm1", "w3": "xmm2", "w4": "xmm3",
             "v21": "rdi", "v22": "rsi", "v23": "rdx", "v24": "rcx"},
    "c_r2": {"v31": "rdi", "v32": "rsi"},
    "c_r2d": {"w1": "xmm0", "w2": "xmm1"},
}

# callee -> the registers it must read, in declaration order.
CALLEE_OF = {"c_%s" % k: k for k in
             ["f0", "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8",
              "g1", "g2", "g8", "g9", "mx", "r2", "r2d"]}
STACKED = {"f7": 1, "f8": 2, "g9": 1}


def functions(exe):
    out = subprocess.run(["objdump", "-d", "--no-show-raw-insn", "-M", "intel", exe],
                         capture_output=True, text=True).stdout
    F, cur = {}, None
    for ln in out.splitlines():
        m = re.match(r"^([0-9a-f]+) <([^>]+)>:$", ln)
        if m:
            cur = m.group(2)
            F[cur] = []
            continue
        m = re.match(r"^\s+([0-9a-f]+):\s+(\S.*)$", ln)
        if m and cur:
            body = m.group(2)
            # The comment is split by HAND.  A regex with an OPTIONAL comment
            # group matched the whole line as the body and left the comment
            # empty -- because the group was optional, the engine had no
            # reason to prefer the longer split -- and every one of the sixteen
            # callers then read "(no arguments)" on every optimisation level.
            # An optional group in a pattern that is meant to be greedy is a
            # silent way of losing the thing you came for.
            if "#" in body:
                body, comment = body.split("#", 1)
                F[cur].append((body.strip(), comment.strip()))
            else:
                F[cur].append((body.strip(), ""))
        elif not ln.strip():
            cur = None
    return F


SRC = re.compile(r"<([A-Za-z_][A-Za-z0-9_]*)>\s*$")


def caller_map(ins):
    """{source: destination} for one caller function.

    The mapping is built as a small dataflow: a RIP-relative load puts a NAME
    in a register, a register-to-register move RENAMES it, a `push` sends it to
    the stack, and whatever is still in a register when the `call` arrives is
    an argument in that register.

    Both halves of that were wrong first.  The first version recorded the
    mapping at the load, so `mov rax,[rip] # v15; mov r8,rax` -- which is what
    gcc emits at -O0 -- reported the argument in %rax, and the copy was the
    whole of the difference.  The second version reported "(no arguments)" on
    every level because the `#` comment was in a regex group marked OPTIONAL,
    and an optional group loses to a shorter overall match."""
    src = {}
    out = {}
    for text, comment in ins:
        m = re.match(r"^mov[a-z0-9]*\s+(\S+),QWORD PTR \[rip[^]]*\]$", text)
        if m:
            s = SRC.search(comment)
            if s:
                src[m.group(1)] = s.group(1)
            continue
        m = re.match(r"^mov[a-z0-9]*\s+(\S+),(\S+)$", text)
        if m:
            a, b = m.group(1), m.group(2)
            # Either direction is a rename, and BOTH had to be here.  With
            # only the `a in src` arm the argument stayed in %rax at -O0,
            # because the shape gcc emits there is
            #     mov rax,QWORD PTR [rip+X]  # <v11>
            #     mov rdi,rax
            # -- a load into a SCRATCH register and a copy out of it, so the
            # name travels rax -> rdi and the copy is in the SECOND operand.
            if a in src:
                src[b] = src.pop(a)
            elif b in src:
                src[a] = src.pop(b)
            continue
        m = re.match(r"^mov[a-z0-9]*\s+(?:QWORD|DWORD|XMMWORD) PTR "
                     r"\[(?:rsp|rbp)(?:[+-]0x[0-9a-f]+)?\],(\S+)$", text)
        if m and m.group(1) in src:
            # A store into %rsp-relative or %rbp-relative memory inside the
            # CALLER is the outgoing-argument area, and a store there is how
            # a seventh-and-later argument is passed.  At -O1 gcc holds it in
            # %xmm8 -- a register outside the eight the psABI names, and a
            # caller-saved one, which is legal precisely because the value
            # never reaches the callee in a register -- and then stores it.
            out[src.pop(m.group(1))] = "stack"
            continue
        m = re.match(r"^push\s+(\S+)$", text)
        if m and m.group(1) in src:
            out[src.pop(m.group(1))] = "stack"
            continue
        if re.match(r"^(call|jmp)\s", text):
            for reg, name in src.items():
                out[name] = reg
            src = {}
            continue
        if re.match(r"^(ret|nop|endbr|pushq|popq|data16)", text):
            src = {}
    return out


AREGS = set(ARG_INT) | set(ARG_SSE)


def callee_reads(ins):
    """The argument registers the callee reads before its first call, in the
    order it first touches them, plus the stack slot it reads for the 7th."""
    order, stack = [], None
    for text, _c in ins:
        if text.startswith("call"):
            break
        if text.startswith("ret"):
            break
        for tok in re.findall(r"\b(rdi|rsi|rdx|rcx|r8|r9|xmm[0-7])\b", text):
            if tok not in order:
                order.append(tok)
        m = re.search(r"\[(?:rbp|rsp)\+(0x[0-9a-f]+)\]", text)
        if m and int(m.group(1), 16) >= 0x10:
            stack = m.group(1)
    return order, stack


def main():
    exe, out_path, label = sys.argv[1], sys.argv[2], sys.argv[3]
    F = functions(exe)
    rows = ["# abi_dis.txt -- GENERATED by build_samples.sh.  Do not hand-edit.",
            "# The ABI, as the COMPILER EMITTED IT.  One CALLER row per caller",
            "# function, one CALLEE row per callee, and a MATCH/DIFF verdict",
            "# against the specification transcribed at the top of mkabi.py.",
            "# The spec is the oracle.  The compiler is the test subject.",
            "TOOL | objdump -d --no-show-raw-insn -M intel",
            "LEVEL | %s | %s" % (label, label)]
    nmatch = ndiff = 0
    for name in sorted(SPEC):
        if name not in F:
            rows.append("CALLER | %s | %s | MISSING FROM THE DISASSEMBLY" % (label, name))
            ndiff += 1
            continue
        got = caller_map(F[name])
        want = SPEC[name]
        ok = got == want
        nmatch += ok
        ndiff += (not ok)
        g = " ".join("%s=%s" % (k, got[k]) for k in sorted(got, key=lambda s: (len(s), s)))
        w = " ".join("%s=%s" % (k, want[k]) for k in sorted(want, key=lambda s: (len(s), s)))
        rows.append("CALLER | %s | %s | %s | %s | %s"
                    % (label, name, g or "(no arguments)", w,
                       "MATCHES THE SPECIFICATION" if ok else "DIFFERS: " + g))
    for caller in sorted(CALLEE_OF):
        cal = CALLEE_OF[caller]
        if cal not in F:
            continue
        order, stack = callee_reads(F[cal])
        rows.append("CALLEE | %s | %s | %s | stack=%s"
                    % (label, cal, " ".join(order) or "(none)", stack or "none"))
    rows.append("AUDIT | %s | %d | %d | %d match, %d differ"
                % (label, len(SPEC), nmatch, nmatch, ndiff))
    with open(out_path, "a") as f:
        f.write("\n".join(rows) + "\n")
    print("    %s: %d/%d callers match the specification" % (label, nmatch, len(SPEC)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
