# Exceptions, Privilege and Mode Changes — research log

Every number in the course was measured before it was written, on this machine,
with these tools. Claims that did not survive measurement were **retracted
rather than softened**, and all eight retractions are printed by the artifact
itself so that they cannot be quietly dropped — and asserted as text by
`crosscheck.py` group H so that they cannot be *deleted* either.

## The machine

| | |
|---|---|
| CPU | AMD Ryzen 5 7430U, family 0x19 model 0x50 stepping 0x0, microcode 0xa500012 |
| Environment | **a virtualised guest**, `svm` + `hypervisor` flags present |
| Kernel | 7.0.0-34-generic (Ubuntu 15.2.0-16ubuntu1), ld 2.46 |
| Toolchain | gcc 15.2.0, Python 3.14.4 |
| TSC | 2.2957 GHz busy, 2.2957 GHz across an 80 ms sleep — **invariant to 0.001 %** |
| Core clock | not readable from user mode; `/proc/cpuinfo` sampled 1815–2637 MHz **within single runs** and is used for orientation only |
| SMEP / SMAP | CPUID feature bits both 1; `arch_prctl(ARCH_GET_XCOMP_PERM)` returns `0x207`; `/sys/.../vulnerabilities/mds` says `Not affected` |
| Noise floor | **19 % – 57 %**, depending on load, on the min-of-3 estimator |

Four of those rows decide what this course may claim at all:

1. **The core clock moves inside a single run and is not readable.** A TSC tick
   is a unit of *time*, not a count of core cycles. Every timing in the course
   is therefore a **ratio**, and the ratio has the same clock on both sides.
2. **The noise floor is 19–57 %.** That is larger than most of the interesting
   effects. It is the reason the harness asserts *structure* exactly and
   *timings* only as orderings and as ratios that clear a floor the artifact
   measured and printed itself.
3. **The machine is a guest.** This is why `int $0x80` works at all — i386
   compatibility is enabled — and the course states that as a limit rather
   than as a general claim.
4. **There is no way to read an MSR, an IDT, a CR4 or a saved RIP from ring
   3.** Most of what this course would want to measure is simply not
   available, and the limits block says which.

## Scope: what the prior courses left open

A word-boundary grep over every concept file the two preceding CPU courses
left behind:

| Term | Files |
|---|---|
| `ring 0` / `ring3` | **0** |
| `GDT` / `IDTR` | **0** |
| `CR0` / `CR3` / `CR4` | **0** |
| `CPL` / `RPL` / `DPL` / `IOPL` | **0** |
| `TSS` / `iobit` | **0** |
| `EFER` / `RFLAGS` | **0** |
| `sysret` / `iret` / `sysenter` | **0** |
| `context switch` | **0** |
| `privilege` | 4 — three are unrelated senses (prepositions/idioms, JVM inner classes, Mach-O "unprivileged") and the fourth is a limits statement in this course's own predecessor |
| `syscall` | 4 — as an **encoding** in the ISA course, as a **noun** in the vDSO concept, and as a **call the ELF loader makes**. None teaches the boundary |
| `MSR` | 1 — a forward reference |

So every word in the course's own title appears zero times, except
"privilege", which appears four times and means something else in three of
them. The four forward references are the interesting part: five earlier
courses *point at* this one and none of them answers it. The sharpest is
`img_vdso.ch`, which says entering a syscall is expensive to *enter* and
leaves the word "why" hanging.

## The findings

### F1 — SIDT reads a table you cannot read

| | |
|---|---|
| base | `0xffffffff00000000` |
| limit | `65535` → **4096** entries of 16 bytes |
| the ten bytes | `00 00 00 00 ff ff ff ff ff ff` |
| reading the first 8 bytes, in a forked child | **SIGSEGV (11)** |

The base is exactly 2³² below the top of a 48-bit space, which is the address
the x86-64 architecture itself uses — and the artifact prints what it read
*before* checking that shape, so a kernel that chose differently would be
reported rather than corrected.

**4096 entries is a bound, not an inventory.** It is 65535, the largest value
a 16-bit limit can express, and it is set that way so that `int 0xNN` with any
byte is a bounds check rather than a wild read. That is a security decision
wearing a number's clothes.

### F2 — The pseudo-descriptor is base-first, and getting it wrong is silent

Read the same ten bytes limit-first and you get:

```
base  = 0xffffffffffff0000   limit = 0
```

No fault. No impossible value. **And a limit of 0 is indistinguishable from a
kernel that installed an empty IDT** — the wrong reading is not merely wrong,
it is unfalsifiable. See R5.

### F3 — `int 0x80` works here, and `int 0x28` kills the process

| probe | result |
|---|---|
| `int $0x80` (vector 128) | **no fault** — this kernel owns vector 128 for the i386 ABI |
| `int $0x28` (vector 40) | **SIGSEGV**, si_code 128 |
| `divq` by zero | SIGFPE, si_code 1 |
| `ud2` | SIGILL, si_code 2 |
| `int3` | SIGTRAP, si_code 128 |

The user chose the vector in both `int` cases; the kernel decided what
happened. That is the division of responsibility the DPL check exists to
enforce, and it is the only clean demonstration in the course.

### F4 — The cost of crossing, isolated

Best of 9 × 20 000, arms interleaved, in TSC ticks:

| arm | ticks |
|---|---|
| `SYSCALL`, getpid | 1238.5 |
| `int $0x80`, getpid | 6095.6 |
| libc `getpid()` | 1236.5 |
| `SYSCALL`, clock_gettime | 1668.8 |
| vDSO `clock_gettime` | **60.4** |

```
int80 / syscall               4.92x
syscall-clock / vdso-clock   27.65x
```

The second pair is the result: same function, same argument, same answer, the
only difference being whether the CPU changed privilege level. **That ratio
*is* the cost of a mode change, with everything else held constant**, and it
is why the vDSO exists. The first pair is a trap and the artifact refuses to
conclude from it — see R1.

### F5 — SYSENTER is a documented divergence, not a bug

```
sysenter   ->   SIGILL  si_code=2
```

**This was the course's most nearly-published error, and the near-miss is the
lesson.** See R2. What survives is a genuine, citable vendor split: Intel SDM
Vol 2B lists SYSENTER as *valid* in 64-bit mode; AMD64 APM Vol 2 §6.1.2 says it
is "illegal in long mode and result in an invalid opcode exception (#UD)". Both
are correct. Linux encodes the split in `arch/x86/kvm/emulate.c` and QEMU
commit `c046a42c` does the same. **No erratum exists against either company,
because neither is wrong.**

### F6 — The calling convention, read out of the kernel's own bytes

The vDSO (from `AT_SYSINFO_EHDR`) contains **5** `syscall` instructions in
6667 bytes of code; **3** are unambiguously `b8 <imm32> 0f 05`:

| vaddr | bytes | number | name |
|---|---|---|---|
| `0x0ab2` | `b8 e4 00 00 00 0f 05` | 228 | `clock_gettime` |
| `0x1031` | `b8 60 00 00 00 0f 05` | 96 | `gettimeofday` |
| `0x12f5` | `b8 e5 00 00 00 0f 05` | 229 | `clock_gettime64` |
| `0x15c3` | `00 00 4c 89 ce 0f 05` | — | not decoded |
| `0x1600` | `00 00 00 31 d2 0f 05` | — | not decoded |

Three syscall numbers recovered without consulting a manual, and they agree
with `asm/unistd_64.h`. The two undecoded sites are reported as undecoded.

**There is no sigreturn trampoline in this build.** Linux removed the vDSO
sigreturn path, and the artifact says so rather than printing 15 from a nearby
pattern. See R8 and the "an absence is an absence" rule.

### F7 — The canonical boundary is 2⁴⁷ minus the width of the access

The course's central result, and the one that is both exact and surprising.

| | 1 byte | 4 byte | 8 byte |
|---|---|---|---|
| 2⁴⁷ − 10 | 1 | 1 | 1 |
| 2⁴⁷ − 7 | 1 | 1 | **128** |
| 2⁴⁷ − 4 | 1 | 1 | **128** |
| 2⁴⁷ − 3 | 1 | **128** | **128** |
| 2⁴⁷ − 1 | 1 | **128** | **128** |
| 2⁴⁷ + 0 | **128** | **128** | **128** |

Three independent bisections:

```
1-byte  first rejected address 0x0000800000000000   2^47 minus it = 0
4-byte  first rejected address 0x00007ffffffffffd   2^47 minus it = 3
8-byte  first rejected address 0x00007ffffffffff9   2^47 minus it = 7
```

**The rule: first rejected address = 2⁴⁷ − (access size − 1).** The CPU
validates the whole byte range of an operand and not merely its first byte.
This also explains *why* a non-canonical access is not a page fault: it never
becomes an address, so there is no PTE to consult and the kernel reports
`si_addr = 0` with `si_code = 128`. A handler that reads `si_addr` before
checking `si_code` concludes the process dereferenced NULL.

### F8 — Four different protection failures, one indistinguishable `si_code`

| probe | si_code | si_addr |
|---|---|---|
| read a `PROT_READ` page | **no fault** | — |
| write a `PROT_READ` page | 2 | exact |
| execute a non-executable page | 2 | exact |
| read a `PROT_NONE` page | 2 | exact |
| write a `PROT_NONE` page | 2 | exact |
| read a genuinely unmapped page | **1** | exact |

`si_code` 1 means mapped-vs-not; 2 means present-but-denied. **W/R (bit 1) and
I/D (bit 4) — the two bits a demand-paging system needs for copy-on-write and
for executable mappings — are not observable from ring 3 at all.** Five of the
eight error-code bits are lost across the boundary, and this is measured rather
than quoted.

## Retractions, recorded

All eight are printed by the artifact in section 8 and asserted as text by
`crosscheck.py`, group H.

**R1 — "The argument count explains the SYSCALL/`int 0x80` gap."** Never
claimed, and the reason is worth keeping. The first draft measured the same
syscall with 0 arguments and with 6, expecting `int $0x80` to get worse. It
cannot: the port accesses happen in the **kernel's i386 entry stub**, not in
the `INT` instruction, and the port count is decided by the kernel's knowledge
of the syscall's declared arity — which a caller cannot vary at all. The
experiment was **removed rather than reported**, and replaced by the vDSO arm,
which holds everything else constant.

**R2 — "`SYSENTER` from ring 3 raises `#GP(0)`."** Never true, on either
vendor. SYSENTER has **no CPL check at all**; it is unprivileged by design
and running it from ring 3 is its entire purpose. Intel's only `#GP(0)` is a
null `IA32_SYSENTER_CS`. The author wrote this belief into a draft, measured
`#UD`, and nearly published a story in which the two cancelled out. **They did
not**: the `#UD` is AMD having removed SYSENTER from long mode, which has
nothing to do with privilege. *Two wrong beliefs producing a right observation
is not evidence.*

**R3 — "4096 entries means 4096 interrupts."** No. The limit is a bound.

**R4 — "`si_addr` is the address the CPU faulted on."** It is the address the
**kernel chose to report**. For a non-canonical access there is none, and it
reports 0.

**R5 — "SIDT writes the limit first and the base second."** No, and **it does
not tell you**. The pseudo-descriptor is base-first at offset 0, limit-second
at offset 8. The first version used `struct { uint16_t limit; uint64_t base; }
packed`, which is 10 bytes, compiles without a warning, and reported
`base = 0xffffffffffff0000, limit = 0`. See F2.

**R6 — "`memset` on a struct a signal handler writes is fine."** No.
`memset` takes `void *`, so its writes to a volatile object are not
volatile-qualified and the compiler may elide them. The handler's record then
held values from a **previous** probe, and the bisection converged on a
boundary **inside a single page** — `0x7ffffffffffc / 0x7ffffffffffd` — which
is impossible, and printed it with total confidence beside a tidy
three-row summary. Fixed by explicit volatile writes in `clear_trap()`.

**R7 — "`__ehdr_start` is the vDSO."** No. It is a glibc symbol holding the
base of the ELF header of the **main executable**. The artifact read it,
printed fourteen program headers and an `e_shoff` past the end of the text,
and reported all of it as vDSO facts — every one true, and every one about the
wrong image. A PIE main executable and a vDSO are both `ET_DYN`, both
`EM_X86_64`, and both carry a plausible fourteen-entry program header table.
**That is exactly why the mistake was easy.** The section now prints
`__ehdr_start` and `AT_SYSINFO_EHDR` on adjacent lines.

**R8 — "The canonical boundary is the address 2⁴⁷."** Not as a statement about
an access. It is 2⁴⁷ − (size − 1). See F7, and the harness asserts the matrix
as a shape rather than any single cell.

## Retractions of the *harness*, recorded

These are the same disease the two previous courses documented: a check that
fails for the wrong reason teaches its reader to ignore it. Four were found,
and **none of them was found by reading the harness — all four were found by
running it.**

**H1 — a line-break trap that failed four checks at once.** The artifact wraps
its prose at about 78 columns, so `READ FROM THE MANUAL, not measured` is two
lines in the file, and the harness searched for the sentence. Four checks
failed about text that was demonstrably present, **including three about
retractions**. This is the worst kind of harness failure: it teaches a reader
to distrust a harness that was right. Fixed by matching against a
whitespace-normalised copy; the numeric parses still run on the original,
because collapsing whitespace there would join adjacent table columns.

**H2 — a hex parser that could not hold hex.** The number extractor returned
floats, because that is what it had always done, and crashed on the first
`0x..` it met. Two extractors now.

**H3 — a truncating extractor.** The same helper returned only the first
capture group, so a check that wanted two hex numbers got one **and could not
fail**. It now returns all groups, and the docstring says why.

**H4 — a percentage treated as a fraction.** The noise floor is printed as
`25.5`, meaning 25.5 %. A ratio check compared against `1.0 + 25.5` and
required a result under 56 — a bound so loose the check was incapable of
failing. The formula now divides by 100, and the check reports the floor it
used.

## What is deliberately not claimed

- **Any exception class.** Fault vs trap vs abort is *read from the manual*.
  Deciding it requires the saved instruction pointer, and a ring-3 process
  never sees one.
- **Any error code the CPU pushed.** A process gets the kernel's translation:
  one signal number and one `si_code`. F8 measures exactly how much survives.
- **Whether SMEP/SMAP are on**, as opposed to being *reported* on. The CR4
  bits are privileged; there is no user-mode experiment.
- **The `IA32_STAR`, `IA32_LSTAR`, `IA32_SFMASK` values.**
  `/dev/cpu/0/msr` is `crw------- root root`. The convention is recovered from
  the vDSO's bytes instead, which is a different and weaker source.
- **Anything about AArch64 or RISC-V.** Concept 3 is quoted, not run, with a
  document for every claim.
- **`int 0x80` as a general property.** It is measured as a *mechanism* on a
  guest with i386 compatibility enabled. A kernel without
  `CONFIG_IA32_EMULATION` raises `#UD`.
- **Absolute cycle counts**, for the reason in the machine table: the clock
  moves and is not readable.
- **Anything about the number of vectors in use.** 4096 is a bound.

## Reproducing

```bash
cd courses/priv/assets/samples
./build_samples.sh            # build, run, cross-check
./build_samples.sh --quick    # skip the recorded-run refresh
python3 crosscheck.py         # the harness alone, against privbench.out
./privbench                   # the artifact alone, 8 sections
```

`privbench.out` is the recorded reference run and `run1.txt` / `run2.txt` are
two more, so the claims are checkable on a machine that never ran the
benchmark. Tracked: `build_samples.sh`, `privbench.c`, `crosscheck.py`,
`privbench.out`, `run1-2.txt`, `.gitignore`. Everything else in that directory
is a build product.
