# The Instruction Set Architecture — research log

Every claim about the x86-64 encoding was measured before it was written, on
this machine, with these tools. Claims that did not survive measurement were
retracted rather than softened, and the retractions are recorded below.

## Toolchain, and why it is not incidental

| Tool | Version | Role |
|---|---|---|
| clang | 21.1.8 | produces the specimens |
| GNU objdump | 2.46 (binutils) | **the oracle** — the only thing a claim is compared against |
| Python | 3 | the artifact and the crosscheck |

The oracle is `objdump`, and that choice has consequences recorded under
**Oracle limitations** below. `objdump` is a *reader*, not a specification, so
where it and this course disagree the course says so rather than deferring.

## Scope: what the prior courses left open

The chain had used x86-64 machine code as an opaque byte string that
relocations patch. `obj-arch-table` poses the question —

> **Q1a. how many bytes is the instruction?**
> **Q1b. at what offset within it does the field start?**

— and then explicitly declines to answer it, because answering it is a
disassembler's job, not a linker's. `word-boundary` grep over all ~44 concept
files written before this one:

| Term | Files |
|---|---|
| `ModRM`, `modrm` | **0** |
| `SIB byte` | **0** |
| `EVEX`, `VEX` | **0** |
| `EFLAGS`, `RFLAGS`, `condition code` | **0** |
| `two-byte opcode` | **0** |
| `instruction set architecture` | **0** |
| `REX` | 8 (only as "32-bit vs 64-bit relocation width") |
| `opcode` | 43 (always as "the byte a relocation must not patch") |
| `x86-64` | 59 (always as the machine the file targets) |

So: the bytes were everywhere and the meaning nowhere. The relocations course
could say "a `disp32` sits at offset 1" and the link course could say "`.got.plt`
is writable"; neither could say *why those bytes are there*. This course
answers Q1a and Q1b, and the artifact is a decoder that shows its work.

## The findings

### F1 — One byte stream, two meanings

`40 89 e8`:

| mode | decode |
|---|---|
| 64-bit | **one** instruction, 3 bytes |
| 32-bit | **two** instructions: 1 byte, then 2 bytes |

`0x40`–`0x4F` is `INC`/`DEC` in 32-bit mode and a REX prefix in 64-bit mode.
The byte stream therefore does not determine the instruction — the **mode**
does. This is the same class of fact as the ELF `e_machine` field, one level
down: an object file's contents are meaningless without a declared
architecture, and the sharpest demonstration of that is a three-byte string
with two correct readings.

**F1b — and there is a second collision, the same shape.** `0x62` is the
AVX-512 **EVEX prefix** in 64-bit mode and `BOUND` in 32-bit. A disassembler
without AVX-512 support refuses it and loses the instruction stream from that
point on. Measured: `objdump` printed `(bad)` and then decoded garbage.

### F2 — REX: four bits, and they ADD 8

`REX = 0100WRXB`. Each of R, X, B **adds 8** to a 3-bit field, so
`R=1` with `reg=000` is **r8**, not r9. Measured:

| bytes | decode |
|---|---|
| `89 c0` | `mov eax,eax` |
| `44 89 c0` | `mov eax,r8d` — R=1 |
| `4c 89 c0` | `mov rax,r8` — W=1 R=1 |
| `49 8b 00` | `mov rax,[r8]` — B=1 |

**And the order rule, which is a different rule:** a REX byte must be the
**last** prefix before the opcode. `66 48 8b c0` is one instruction;
`48 66 8b c0` is not one instruction, because a legacy prefix after REX is not
a prefix — it is the opcode.

### F3 — ModRM: 256 combinations, and the two fields that decide the length

All 256 ModRM bytes for `8b /r` (`MOV r32, r/m32`) were completed with the
trailing bytes their form needs and each was decoded:

- **0 of 256** failed to decode as exactly one instruction.
- `mod=11` is exactly **64 of 256** (a quarter) — the register forms.
- `mod≠11` is 192 — the memory forms.

`mod` and `rm` **together are the only fields that decide the instruction's
length**, which is the answer to `obj-arch-table`'s Q1a.

### F4 — SIB: index=100 is "no index", and the byte order is not the obvious one

Two of my recollections were wrong and measurement corrected both:

- **`index=100`** (with `REX.X=0`) means **no index**. `index=101` is **rbp**.
  This is why `[rbp+rsi*1]` cannot be encoded without a displacement.
- **`base=101`** is "no base" **only at `mod=00`**, where the `disp32` becomes
  an absolute address. At `mod=01`/`10` it is simply rbp.

And the byte order: **`8b 84 24 11 22 33 44` is `mov eax,[rsp+0x44332211]`
while `8b 84 11 22 33 44 24` is `mov eax,[rcx+rdx*1+0x24443322]`.** Both are
valid, and they are different instructions. The SIB byte comes immediately
after the ModRM, **before** the displacement.

Scale: `ss=0..3` → `×1, ×2, ×4, ×8`, all four measured.

### F5 — The opcode map, the escape, and its holes

Of the 256 one-byte values: **228 decode to an instruction, 27 are prefixes
(16 REX + 11 legacy), 1 is nothing.** The 27 is the count worth remembering —
over a tenth of the one-byte map is not an instruction at all.

The `0F` escape: `0F 05` SYSCALL, `0F 0B` **UD2** (deliberately undefined, so
a bad indirect branch faults immediately rather than wandering), `0F 0E` FEMMS
(3DNow!), `0F 1F /r` multi-byte NOP, and the two escape maps `0F 38` / `0F 3A`
where the vector extensions live.

`F3 0F 1E FA` is **ENDBR64** and exactly 4 bytes; bare `0F 1E FA` is a
multi-byte NOP. The `F3` is what makes the difference — a direct connection to
the CET concept in the hardening course, which measured those `endbr64`
instructions and asked where the enforcement request lived.

### F6 — The sixteen condition codes, shared by two opcode groups

`0F 80`–`0F 8F` are `Jcc rel32`; `0F 90`–`0F 9F` are `SETcc r/m8`; and the two
groups line up condition for condition (`0F 84`=JE with `0F 94`=SETE). All 16
measured: O NO B AE E NE BE A S NS P NP L GE LE G. The same conditions also
exist with an 8-bit displacement at `0x70`–`0x7F`, which is why a compiler
emits a short form for nearby branches and a near form otherwise.

### F7 — The length formula

```
length = prefixes + opcode + modrm + sib + displacement + immediate
```

Verified on 14 specimens, all matching. Two rows carry the weight:

- `48 b8 <8 bytes>` is **10** — REX.W gives `movabs` a real 64-bit immediate.
- `48 c7 40 20 00 00 00 00` is **8**, not 11. **REX.W widens the *operand*,
  not the immediate**: `mov r/m64, imm32` sign-extends. So you cannot load
  `0x00000000FFFFFFFF` with a single instruction. This was a bug in the
  decoder before it was a finding in the course — it cost four bytes and
  desynchronised every boundary after it.

And `f6 c0 01` is 3 bytes while `f6 d0` is 2: **for the `F6`/`F7` groups the
ModRM reg field decides whether an immediate exists at all** (`reg` 0 and 1 are
`TEST`, the other six take none). So a bare `f6` is not a length.

### F8 — The length distribution, and why a disassembler is fragile

Over a real `.text`: 129 instructions, mean 3.60 bytes, range 1–7. Over the
corpus: 472 instructions, mean 3.99.

The load-bearing property is that **instruction boundaries form a chain**:
`start[0]=0`, `start[i+1]=start[i]+len[i]`. One wrong length desynchronises
every boundary after it, so a section can only be called a match if the chain
consumes it **exactly**. A per-instruction count that happens to agree proves
nothing — which is the argument for checking the chain.

## The artifact

`x86dec.py` — 1042 lines, no toolchain, no `objdump`. Parses the ELF section
table to find code, then decodes each instruction and **prints the derivation
for every field**. The naming is a lookup table's job; the *encoding* is the
lesson, and the tool is built around that.

`crosscheck.py` — 118 checks in 9 groups, including **I9, which audits all 364
entries of the opcode tables** against the oracle: 0 length disagreements.

**The two decoders agree on 578 of 578 instruction boundaries (100%)** across
every code section of three specimens, with every chain closing exactly.

## Oracle limitations, measured

These are properties of `objdump`, and each one forced a decision.

1. **`objdump` does not apply `REX.X` to the SIB index.** `45 8b 04 24` should
   be `[rsp+r12*1]`; it prints `[rsp]`. It applies REX.R and REX.B correctly.
   → The crosscheck compares instruction **boundaries and lengths**, not
   operand text, so the two readers cannot disagree where they are being
   compared. The artifact *does* apply REX.X, and says so.
2. **`objdump` wraps long encodings across lines** — at most 7 bytes on the
   first, the remainder on a continuation line with no mnemonic field. An
   instruction is not a line. → Three separate parsers in this course had to be
   fixed for this, and each time the *decoder* looked wrong when it was the
   *check* that was wrong.
3. **`objdump` emits entries with no mnemonic at all** for a byte run it cannot
   name (`11f4: aa aa aa`). A parser requiring three tab-separated fields drops
   them silently.
4. **It refuses AVX-512 and loses the stream.** `(bad)` at `0x62`, then
   garbage. → The corpus is built `-march=x86-64`. A reader that gives up is
   not a reader that disagrees, and the two must not be confused.
5. **It cannot decode `0F 38` / `0F 3A` without AVX** and emits `.byte 0xf`.
6. **On `48 66 …` it recovers** by printing a bare `rex.W` and re-reading the
   `0x66` as a prefix. Architecturally the `0x66` is the opcode (PUSH ES,
   invalid in 64-bit) and the instruction faults. The artifact refuses. Both
   are defensible; the difference is a decision, and the course states it.

## Retractions, recorded

**R1 — "A known-size destination means `index=100` is rsp."** No. Measured:
`index=100` with `REX.X=0` is **no index**; `index=101` is rbp. The retraction
is in `build_samples.sh` I4 and asserted by I4's checks.

**R2 — "The SIB byte follows the displacement."** No. Measured both orders:
they are different instructions, and the SIB comes **first**.

**R3 — "`0F F4` is HLT."** No. It is `PMULUDQ` (SSE2). `F4`=HLT is a
*one*-byte opcode that had been copied into the two-byte table. Found by the
I9 table audit, not by any hand-written example.

**R4 — "`D3` takes an 8-bit immediate."** No. `D0`–`D3` are shift-by-1 and
shift-by-CL; **none** takes an immediate. Only `C0`/`C1` do.

**R5 — "`48 C7 /0` has an 8-byte immediate."** No — 8 bytes total, because
REX.W widens the operand and not the immediate. Found as a decoder bug and
kept as finding F7.

## Errors in the tooling, kept because they are the lesson

**E1 — the reference parser dropped real instructions.** It required three
tab-separated fields, so `objdump`'s no-mnemonic entries vanished and three
sections reported `578/611` agreement when the decoder was right. Three
separate parsers had the same flaw. A check that fails for the wrong reason is
worse than no check, because it teaches you to ignore it.

**E2 — duplicate dict keys, silently.** The opcode tables had **13** duplicate
keys. Python keeps the last, so three of them undid fixes applied minutes
earlier, and the line-based cleanup that removed them also deleted nine `XCHG`
entries that merely shared a line with a duplicate. Found by counting keys per
table — a one-line check that should have been there from the start.

**E3 — an over-broad exception list.** `TWO_BYTE_MODRM_IS_REG` included `0F 09`,
`0F 0B` and `0F 31`, which take **no** ModRM, so the decoder demanded a byte
that does not exist and refused three ordinary instructions.

**E4 — the operand order was backwards for the whole ALU family.** `0x89` is
`MOV r/m, r`, not `MOV r, r/m`. The rule is that the **even** base opcode is
`r/m, r` and the **odd** one is `r, r/m`; the author of the code (this course)
had it exactly reversed, and it was only visible by comparing against the
oracle.

**E5 — a zero-width step.** Not in this course's artifact, but the same family
as the hardening course's hang: the immediate was counted twice after an edit,
so every instruction with an immediate overran. Found by the I8 length table.

**E6 — the file/hex argument ambiguity.** `x86dec.py corpus` fed a filename to
`bytes.fromhex` and produced a traceback that looked like a decoder bug. The
tool now distinguishes a path from a hex string and says which it expected.

## What is deliberately not claimed

- **A second architecture.** No AArch64 machine or linker was available. The
  DWARF frame course covers AArch64 register encodings; nothing here claims a
  second-architecture result.
- **The mnemonic tables are partial by design.** `x86dec.py` resolves *length
  and structure* for 364 audited opcode entries and *names* a subset. Where it
  has no name it prints `(op xx)` rather than guessing, because a guessed
  mnemonic is a claim nothing checked. It is not a complete disassembler and
  does not pretend to be.
- **Operand semantics.** `render()` prints operand text well enough to be
  useful and is not a full AT&T/Intel translation layer. The length arithmetic
  is the contract; the text is a convenience.
- **Why the ISA is shaped this way.** The historical reasons for the `0F`
  escape, for `index=100` reserving rsp, and for the REX design are documented
  by Intel and were not read from source here. The course states the
  mechanisms and the consequences, and attributes intent to nobody.
- **Micro-architecture.** Nothing here is about execution, timing, decode
  width, or branch prediction. That is a different course.

## Reproducing

```bash
cd courses/isa/assets/samples
./build_samples.sh     # findings I1-I8, from an empty directory
python3 crosscheck.py  # 118 checks, including a 364-entry table audit
python3 x86dec.py 4889e84883ec205bc3
python3 x86dec.py --why 8b442420
python3 x86dec.py corpus
```

Tracked: `build_samples.sh`, `x86dec.py`, `crosscheck.py`, `.gitignore`.
Everything else — every `.c` file, every binary, every temp file the scripts
write — is a build product, and `build_samples.sh` writes the `.c` files
itself.
