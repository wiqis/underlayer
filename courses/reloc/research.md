# Relocations, PIC and PIE — research record

Every finding was **measured on this machine**. The command is given so a reader
can re-run it and, more usefully, disprove it.

## Environment

    clang              Ubuntu clang 21.1.8
    ld / ld.bfd        GNU ld (GNU Binutils for Ubuntu) 2.46
    llvm-objdump-21    LLVM 21.1.8
    glibc              2.43
    aarch64            compile-only (--target=aarch64-linux-gnu). No aarch64
                       linker or runtime, so AArch64 findings are about OBJECT
                       FILES and relocation vocabularies only, never execution.

## Scope boundary — what the obj course already taught

`obj-relocations`, `obj-addends`, `obj-reloc-tables` and `obj-pic` already cover:
the record layout field by field; `Elf64_Rela` vs `Elf64_Rel`; that the addend
lives in `r_addend` and not the section bytes; the three formats' relocation
tables; **absolute vs relative vs GOT-relative**; the three-build diff under
`-fPIC`/`-fPIE`/no flag; the decomposition of `R_X86_64_REX_GOTPCRELX`; and that
**`-fPIE` is identical to no flag**.

This course therefore does **not** re-teach those. It goes after what is left:
the *vocabulary* and why it has the shape it has; the AArch64 contrast; PIE as a
link-time property with a measurable security effect; the cost; the failure
modes; and TLS.

## Finding 1 — the same source needs one relocation on x86-64 and two on AArch64

`v.c` has one extern datum of each access width and one call. `-fno-pic` on both
targets:

    x86-64                                   aarch64
    R_X86_64_PC32      g_i-0x4               R_AARCH64_ADR_PREL_PG_HI21  g_i
    R_X86_64_PLT32     sink-0x4              R_AARCH64_LDST32_ABS_LO12_NC g_i
    R_X86_64_PC32      g_p-0x4               R_AARCH64_CALL26            sink
    ...                                      R_AARCH64_ADR_PREL_PG_HI21  g_p
                                             R_AARCH64_LDST64_ABS_LO12_NC g_p
                                             ...
                                             R_AARCH64_ADR_PREL_PG_HI21  g_c
                                             R_AARCH64_LDST8_ABS_LO12_NC  g_c

Cross-checked programmatically: **every** `ADR_PREL_PG_HI21` is followed exactly
**4 bytes** later by an `ABS_LO12_NC`, one for one. x86-64 emits one relocation
per datum; AArch64 emits two.

**The deeper finding is the second half.** AArch64's relocation *type* encodes
the **access width**: `LDST64`, `LDST32`, `LDST8` for an 8-, 4- and 1-byte
access. x86-64 has **one** form for all three, because the width is already
implied by the opcode. So the relocation vocabulary is a function of the
instruction encoding, not of the source language. The call is one relocation on
both (`PLT32` / `CALL26`) because both architectures have a PC-relative call.

## Finding 2 — aarch64's pair exists because of ±4GB, x86-64's single form because of ±2GB

x86-64's `RIP`-relative displacement is a **signed 32-bit** field, so one
reference reaches ±2GB. AArch64's `ADR` reaches ±1MB and `ADRP` ±4GB, so a
symbol further away needs *two* instructions: `ADRP` for the 4GB-aligned page
base, then `ADD`/`LDR` for the low 12 bits (a page is 4KB = 2^12, which is
exactly why the low field is 12 bits). **The two-relocation pattern is a
consequence of a wider per-instruction reach, not a worse design.**

## Finding 3 — the x86-64 vocabulary, by code model

`g.c` takes the value of a global, the address of a global, and calls an extern.

    -fno-pic -fno-pie    R_X86_64_32      (address, absolute)
                         R_X86_64_PC32    (value, relative)
                         R_X86_64_PLT32   (call)

    -fPIE  and  -fPIC    R_X86_64_REX_GOTPCRELX   (both address and value)
                         R_X86_64_PLT32

For **this source** PIE and PIC emit the *same* vocabulary, and no absolute form
survives. `PLT32` is in all three, for the reason the obj course measured: a
call was already indirect.

## Finding 4 — a codegen flag and a link flag can disagree, and the result is neither

    compiled            linked          e_type
    -fno-pic -fno-pie   -no-pie         EXEC   consistent
    -fno-pic -fno-pie   -pie            DYN    the CODE is non-PIC, the FILE is DYN
    -fPIE               -pie            DYN    consistent
    -fPIE               -no-pie         EXEC   the CODE is PIE, the FILE is EXEC
    -fPIC               -shared         DYN    consistent

The two disagreeing rows are the interesting ones. **They are the reason the
symbol-resolution course's `GLOB_DAT`-instead-of-`COPY` finding exists**: an
object compiled `-fPIE` but linked `-no-pie` is a fixed-layout executable that
still pays for GOT indirection it cannot use.

## Finding 5 — a PIE actually moves; a non-PIE does not

Six runs each, printing `(void*)main`:

    w_pie     0x631601ffb140  0x63c0b0b59140  0x5d2cde541140  0x64ca65330140 ...
    w_nopie   0x401130 0x401130 0x401130 0x401130 0x401130 0x401130

Six distinct PIE addresses, one non-PIE address. And the low **12 bits are
identical in every PIE run**: ASLR randomises the *base*, and the offset within
the first page stays a link-time constant. `w_nopie` sits below 0x80000000,
which is the whole 32-bit-address-space layout an `ET_EXEC` binary gets.

## Finding 6 — the cost of PIC, in instructions and bytes

Eight globals, one function, `-fno-pic` vs `-fPIC`:

    non-PIC, 9 instructions        PIC, 17 instructions
       movl  (%rip), %eax            movq  (%rip), %rcx     ; load the ADDRESS
       addl  (%rip), %eax            movq  (%rip), %rax
       ...  (one per global)         movl  (%rax), %eax     ; then the VALUE
                                     addl  (%rcx), %eax
                                     ...  (two per global)

The non-PIC form is a 6-byte `movl (%rip), %eax`. The PIC form is a 7-byte
`movq (%rip), %rcx` **plus** a 3-byte `movl (%rcx), %eax`. So PIC costs one
extra instruction *and* one extra byte of encoding per global reference, plus
the memory latency of the dependent load. `.got` in the resulting `.so` is
0x60 = 12 words for 8 globals.

## Finding 7 — TLS is the only relocation that calls the loader

### This finding was measured twice. The first measurement was wrong.

The first version used a single specimen in which both thread-locals were
`extern`, and concluded: *local-dynamic and initial-exec emit identical
relocation types.* That is not a fact about the models. It is a fact about the
specimen, for two independent reasons:

1. `local-dynamic` requires the symbol to be in the **same module**. An
   `extern` thread-local is not, so the request is inapplicable and the
   compiler falls back to initial-exec.
2. The specimen was compiled at `-O1`, and the module-local
   `static __thread int my_tls = 7;` read folded to the constant `7`. The
   memory access disappeared, and with it the only relocation that would have
   distinguished the models.

**The retraction:** the two models are not indistinguishable. The corrected
measurement uses two specimens and `-O0`.

### The corrected measurement

`tls2.c` — one `extern` thread-local (another module) and one `static` one
(this module), both read by a function, compiled `-O0`:

    flags                                    relocation types
    ---------------------------------------  ---------------------------
    -fPIC                                    TLSGD, TLSLD, DTPOFF32, PLT32
    -fPIC -ftls-model=local-dynamic         TLSLD, DTPOFF32, PLT32
    -fPIC -ftls-model=initial-exec          GOTTPOFF
    -fPIC -ftls-model=local-exec            TPOFF32
    -fPIE                                    GOTTPOFF, TPOFF32
    -ftls-model=local-dynamic  (no -fPIC)   GOTTPOFF, TPOFF32  (overridden)

Three findings, and the third is the one worth the concept:

1. **The ladder is monotone.** Each step down removes a loader call; the last
   step removes the GOT as well. `local-exec` is a single `TPOFF32` — an offset
   from the thread pointer, fixed at link time, with nothing to call and
   nowhere to store a replacement.
2. **`-fPIC` chooses per symbol, not per file.** In one object it emitted
   `TLSGD` for the extern and `TLSLD` for the module-local one, with two
   separate `__tls_get_addr` calls. General-dynamic asks about a *symbol*;
   local-dynamic asks about a *module* once and then adds a module-relative
   offset (`DTPOFF32`), so it is one call for N symbols.
3. **The flag is a request; PIC-ness is a constraint.** `-ftls-model=
   local-dynamic` *without* `-fPIC` is overridden: no `TLSLD`, no call. The
   compiler knows the output is an executable and chooses for itself. The
   models only become selectable when `-fPIC` is present.

### What the linker cannot catch

Forcing `local-dynamic` onto a symbol defined in **another** module links
without a diagnostic. It also *ran correctly*, returning 42 — but only because
this test contains exactly one thread-local module, so the module id and the
symbol's offset coincide. **I did not construct a failing case**, so the
honest statement is that the misuse is latent rather than observable here: the
linker has no way to detect it, and the test that would expose it needs two
modules and a specific load order.

## Finding 8 — the PIC violation names the relocation type

    $ clang -O1 -fno-pic -c vio.c -o vio_nopic.o
    $ clang -shared -o libvio.so vio_nopic.o
    ld.bfd: vio_nopic.o: relocation R_X86_64_32 against undefined symbol
      `ext_data' can not be used when making a shared object;
      recompile with -fPIC

The `-fPIC` build of the same source carries `R_X86_64_REX_GOTPCRELX` and links
silently. **The violation is a fact about the relocation type, not a policy
setting** — which is why the diagnostic can name the type and prescribe the
flag. The `R_X86_64_32` sits at offset **1**, not 0: it is the immediate of
`mov $imm32, %eax`, not a displacement.

## Finding 9 — the displacement is zero before relocation

    $ llvm-objdump-21 -d far.o
    0000000000000000 <reach>:
           0: 8b 05 00 00 00 00    movl (%rip), %eax
           6: c3                   retq

`8b 05` is the opcode; the four displacement bytes are `00 00 00 00`. The
object file carries a **placeholder**, and the addend plus the symbol's final
address are what turn it into a displacement. Seeing `movl (%rip), %eax` in an
object file and assuming the target is 0 bytes away is the natural mistake, and
the bytes refute it.

## Deliberately not claimed

- **AArch64 execution.** No aarch64 linker or runtime on this machine. Every
  AArch64 finding is about object files and relocation vocabularies, and no
  claim is made about running the code.
- **The exact number of load-time fixups for `TLSGD`,** or `ld.so`'s internal
  caching of them. The relocation and the call are measured; the loader's
  bookkeeping is not.
- **A performance comparison of PIE vs non-PIE at runtime.** The *code* cost is
  measured exactly (instructions and bytes). Wall-clock is not, because it
  depends on the machine and would be a claim I could not defend here.
