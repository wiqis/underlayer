# Object Files — Phase A research record

> Scope and goal: `docs/course-mission.md`. This course is the **object files**
> link in the parsing→executable chain, and it is written from the **linker's**
> point of view, because the mission's outcome is a learner who can build a
> linker.
>
> Status: research complete, specimens staged, manifest drafted. Concepts not
> yet written. See "Course plan" at the end.

## Why this course is cross-format, and not a fifth format course

Three finished courses already cover object files *inside their own format*, and
COFF's first module is literally "The Relocatable Object":

| Course | Where it already covers objects |
|---|---|
| ELF | `elf-header-fields` (`e_type = ET_REL`), `common-sections`, `symbol-table`, `binding`, `relocation-entries`, `relocation-types` |
| COFF | module 1 "The Relocatable Object", `coff-symbol-table`, `coff-relocations`, `coff-comdat`, `coff-archives` |
| Mach-O | `macho-sections`, `macho-symtab`, `macho-relocations` |

So a format-specific object-file course would be largely redundant. What no
course can do — because each format takes its own design for granted — is teach
the object file **as a concept**, compared across formats. That is this course,
and the cross-format comparison is the teaching device, not a gimmick: the same
source compiled three ways makes the invariants and the accidents visible at
once.

## Toolchain

| Tool | Version | Role |
|---|---|---|
| `clang` | 21.1.8 | **Producer for all three formats** via `-target`; **reader** for all three |
| `gcc` | 15.2.0 | **Second, independent producer** (ELF x86-64) |
| `llvm-readobj-21` | 21.1.8 | Reader — structured field dump, all three formats |
| `llvm-objdump-21` | 21.1.8 | Reader — disassembly + relocations, all three formats |
| `llvm-nm-21`, `llvm-size-21` | 21.1.8 | Readers — symbols, sizes |
| `readelf`, `objdump`, `nm` | binutils (Ubuntu 15.2) | **Second reader toolchain** — ELF and COFF only |
| `file` | — | Reader, independent magic+structure logic, all three |
| `ar` | binutils | Producer, for archive specimens |
| `ld.bfd` / `ld` | binutils | Linker, used as an oracle for ELF |

**Two genuinely independent reader toolchains exist** (LLVM 21 and binutils) for
ELF and COFF. For Mach-O only LLVM reads it — binutils refuses — so Mach-O
verification rests on LLVM plus `file` plus hand-checks. That asymmetry is
recorded rather than hidden.

`otool`, `dumpbin`, `llvm-readobj` (unversioned) and `ld64.lld` are **absent**.
`llvm-readobj-21` and friends are present under versioned names only.

## Specimens

All produced on this machine from one 30-line `demo.c`, staged in
`assets/samples/`. The source is chosen to exercise every mechanism a linker
must see: a call to an undefined symbol, a reference to an external variable, a
global definition, a static (file-local) definition, initialised and
uninitialised data, a string literal with and without a relocation, and an
`inline` function (which forces a COMDAT/group).

| Specimen | Bytes | Format | Producer |
|---|---|---|---|
| `demo_elf.o` | 1952 | ELF64 x86-64 relocatable | clang 21.1.8 |
| `demo_elfgcc.o` | 2136 | ELF64 x86-64 relocatable | gcc 15.2.0 |
| `demo_arm64elf.o` | 2176 | ELF64 AArch64 relocatable | clang 21.1.8 |
| `demo_coff.o` | 1098 | COFF x86-64 (i386/amd64 hybrid) | clang 21.1.8 |
| `demo_macho.o` | 1224 | Mach-O 64-bit x86-64 | clang 21.1.8 |

`clang -target x86_64-pc-linux-gnu -O1 -c` is **byte-reproducible**: a rebuild
`cmp`s clean against the staged file. Reproducibility matters here because the
whole verification argument is "these exact bytes are these exact claims".

## Findings

### 1. The same source needs twice the fixups on AArch64

One relocation table per format, from `llvm-objdump-21 -r`:

| | x86-64 ELF | AArch64 ELF | COFF x86-64 | Mach-O x86-64 |
|---|---|---|---|---|
| `.text` fixups | **4** | **8** | 4 | 4 |
| `.data` fixups | 1 | 1 | 1 | 1 |
| call to undefined | `R_X86_64_PLT32` | `R_AARCH64_JUMP26` | `IMAGE_REL_AMD64_REL32` | `X86_64_RELOC_BRANCH` |
| data ref | `R_X86_64_PC32` | `ADR_PREL_PG_HI21` **+** `LDST32_ABS_LO12_NC` | `IMAGE_REL_AMD64_REL32` | `X86_64_RELOC_SIGNED` |
| 64-bit data ref | `R_X86_64_64` | `ADR_PREL_PG_HI21` **+** `LDST64_ABS_LO12_NC` | `IMAGE_REL_AMD64_ADDR64` | `X86_64_RELOC_UNSIGNED` |

AArch64 emits **two** fixups for one reference to `global_counter`: one to
materialise the page address, one to materialise the low 12 bits of the offset.
**The doubling is not about the language, the format, or the linker. It is
because an AArch64 load instruction encodes a 21-bit page delta and a 12-bit
offset in two separate fields, and the linker has to be told about both.** This
is the single best argument in the course for why an object file is
architecture-specific while the *idea* of a fixup is not.

### 2. Three vocabularies, one operation

"R_X86_64_PC32", "IMAGE_REL_AMD64_REL32" and "X86_64_RELOC_SIGNED" are the same
three things: a signed 32-bit PC-relative patch. The three formats disagree on
the *name*, on the *width encoding* (Mach-O's `X86_64_RELOC_SIGNED` has the
width in a separate byte pair), and on whether a PLT variant exists —
`R_X86_64_PLT32` in ELF, `X86_64_RELOC_BRANCH` in Mach-O, and **no distinction
at all in COFF**, where an object's call and data reference are the same
relocation. A linker author must therefore implement a *vocabulary per target*,
not a vocabulary per format.

### 3. Mach-O relocations are stored in decreasing address order

From `demo_macho.o`, `.text`: offsets `0x37, 0x26, 0x0e, 0x08`.

ELF and COFF both store relocations in **increasing** offset order. Mach-O
stores them **decreasing**, within each section. This is a real Mach-O
invariant, not an artifact: linkers have historically walked relocation entries
backwards when laying out a section. A tool that assumes ascending order across
all three formats will produce correct-looking output on two of them and
silently wrong output on the third.

### 4. The addend is in the section bytes, and the display subtracts it

`llvm-objdump-21 -r demo_elf.o` prints the VALUE column as:

    0000000000000004 R_X86_64_PC32   global_counter-0x4
    0000000000000021 R_X86_64_PLT32  external_fn-0x4

The `-0x4` is **not** part of the symbol name. It is the *implicit addend*,
which lives in the four bytes of `.text` at offset 4 and is what a
`PC32` computation must subtract. ELF has an explicit `r_addend` field in
`Elf64_Rela` as well, and clang left it zero. So an object-file reader has to
distinguish three things that all look like "the value": the symbol's address
(0, unknown), the addend (in the bytes), and the explicit addend field (0).

### 5. Mach-O objects have real section addresses; ELF and COFF objects do not

`llvm-readobj-21 --sections`, object files only:

| Section | ELF `Address` | COFF `VirtualAddress` | Mach-O `Address` |
|---|---|---|---|
| code | `0x0` | `0x0` | `0x0` |
| data | `0x0` | `0x0` | **`0x48`** |
| string literals | `0x0` | `0x0` | **`0x58`** |
| const | `0x0` | `0x0` | **`0x5E`** |
| common | — | — | **`0xF8`** |

An ELF or COFF object has **no addresses at all** — every symbol's value is an
offset within its own section, and the linker invents addresses. A Mach-O object
is laid out as though it were already an image, and its relocations are relative
to those provisional addresses. **This is a real architectural difference in
what an object file *is*:** ELF's object is "sections without addresses", Mach-O's
is "a tiny image with relocations". It also means a Mach-O relocation's offset is
an address, while an ELF relocation's offset is a section-relative offset — the
same 8-byte field means different things.

### 6. COFF section names are not unique

`demo_coff.o` has **seven** sections and **two of them are named `.rdata`** —
`llvm-readobj-21 --sections` shows two separate entries, sizes 6 and 3, one for
each string literal. COFF section names are an **8-byte inline field**, so
there is no central name table and nothing enforces uniqueness.

For a linker author this is a trap with teeth: any dictionary keyed by section
name silently loses one of the two sections. It is also why a COFF section is
identified by *index*, and why `IMAGE_SCN_LNK_INFO`/`IMAGE_SCN_LNK_COMDAT`
markers matter more in COFF than section identity does.

### 7. Alignment is a byte count in ELF and a logarithm in Mach-O

| | ELF `AddressAlignment` | Mach-O `Alignment` |
|---|---|---|
| code section | **16** | **4** |
| data section | 8 | 3 |

Both describe the same two alignments. **ELF stores a byte count, Mach-O stores
log2 of it.** A tool that copies one format's alignment into the other is wrong
by a factor of two to four, and — because both are powers of two — the result is
still a plausible-looking number, which is the worst kind of bug.

### 8. Three different strategies for storing a name

| | Section name storage | Symbol name storage |
|---|---|---|
| ELF | `u32` **offset** into `.shstrtab` | `u32` offset into `.strtab` |
| COFF | **8 bytes inline** in the header | `u32` offset into one file-wide string table |
| Mach-O | **16 bytes inline** in the section | `u32` offset into a per-segment `__stringtab` |

Consequences a learner will hit:

- ELF needs *two* string tables (`.shstrtab` for sections, `.strtab` for symbols)
  because a section header and a symbol live at different times.
- COFF can only have section names up to 8 bytes, which is why long names need
  the `/nnn` numeric escape into the string table — a mechanism ELF does not need.
- Mach-O's 16-byte field is a fixed-size C array, and `demo_coff.o`'s `.debug$S`
  shows the COFF form filling all 8 bytes with a padded name.

### 9. Symbol naming reveals the two incompatible worlds

The data relocation in `demo_coff.o` targets:

    ??_C@_05CJBACGMB@hello?$AA@

That is MSVC's mangling for the string literal `"hello"`, in which the
characters of the string are folded into the name. Mach-O names the same object
`__cstring` (a section symbol) and prefixes every C symbol with an underscore:
`_message`, `_external_fn`. ELF uses the source name unchanged: `message`,
`global_counter`.

**COFF is the outlier because MSVC mangles string literals into the symbol
name.** A linker that treats symbol names as opaque will link MSVC objects
correctly and then be unable to answer "which literal is this?" — and a tool
that wants to rewrite a string cannot find it by name at all.

### 10. Two producers disagree about section naming

Same source, same flags, two ELF objects:

| | `.text` fixup offsets | data fixup lives in |
|---|---|---|
| clang 21 | 0x04, 0x0a, 0x21, 0x33 | `.data` |
| gcc 15.2 | 0x06, 0x10, 0x1e, 0x2e | **`.data.rel.local`** |

gcc emits a separate `.data.rel.local` section for relocation-bearing data;
clang puts the relocation in `.data`. **Both are correct ELF.** A tool with a
hard-coded list of "the sections a relocatable object has" is wrong for one of
the two most common producers on Earth, and it will be wrong in a way that only
shows up when someone links gcc-built static libraries.

### 11. Only some sections get section symbols

`demo_elf.o`'s symbol table contains `STT_SECTION` entries for `.text` and
`.rodata.str1.1` — and **none** for `.data`, `.bss` or `.rodata`, even though
those sections exist and `.data` has a relocation against it.

The rule is demand-driven: a section symbol is emitted when something needs to
name the section as a whole. `.data` never needs one because its relocation
targets the *variable* `message`, not the section. A learner who assumes "every
section has a symbol" will over-allocate, and a linker that resolves a
relocation by always looking for a section symbol will find nothing for the
sections that do not have one.

### 12. Mach-O reserves a `__common` section for tentative definitions

`demo_macho.o` has a `__common` section, `Size: 0x4`, **`Offset: 0`**,
`Type: ZeroFill`. It occupies no file bytes at all — it is a declaration that
somewhere, in some object, a 4-byte zero-initialised object lives.

This is `int uninitialised;` — a *tentative definition*, the C construct whose
resolution rule ("if several objects declare it, pick one; all get zero") is the
original purpose of the COMMON symbol and the reason `-fcommon`/`-fno-common` was
a real interoperability hazard between GCC 9 and GCC 10. ELF expresses the same
thing as an `SHN_COMMON` symbol with a **size**; COFF as a symbol with storage
class `IMAGE_SYM_CLASS_EXTERNAL` and a section index of 0 plus a size in the
auxiliary record; Mach-O as a real section. **Three encodings of one language
rule, and a famous ABI break between them.**

### 13. Objects have no segments, and that is not an omission

`llvm-readobj-21 --sections` on all three objects shows **no program headers
and no segment table of any kind**. ELF's `PT_LOAD` segments, Mach-O's
`LC_SEGMENT_*` load commands, and the PE concept of a "section that is mapped"
simply do not exist in a relocatable file — because *mapping is a loader
decision*, and at object time there is nothing to map.

This is worth its own concept because it is the sharpest available answer to
"why do executables have two tables and objects have one". The two tables answer
two different questions, and the object file only has the first one.

## Course plan

Five modules. The frame throughout: **every field is taught as "this is what the
linker needs this for"**, because the mission's outcome is a learner who can
build a linker.

| # | Module | Concepts | The question it answers |
|---|---|---|---|
| 1 | Why Object Files Exist | `obj-intro`, `obj-the-hole`, `obj-triangulate`, `obj-no-segments` | What is a relocatable file, and what problem does it solve? |
| 2 | Anatomy, Compared | `obj-sections`, `obj-symbols`, `obj-strings`, `obj-bss-common` | Where do names, code and data actually live? |
| 3 | The Fixup | `obj-relocations`, `obj-addends`, `obj-pic`, `obj-reloc-tables` | What is a relocation record, field by field, and why are there so many kinds? |
| 4 | Merging and Selection | `obj-comdat-group`, `obj-archives`, `obj-weak-undef` | How do two objects that disagree become one? |
| 5 | Emitting One | `obj-emit`, `obj-verify`, `obj-arch-table` | How do I write one, and how do I know it is right? |

Module 3 is the heart and gets the most time: it is where a linker is actually
implemented. Module 5 is what makes the course honest under the mission's
"from scratch, not by delegation" rule — the learner must **emit** an object
file, not only read one, and must know which instruction encodings they need
before they can relocate them (which is where "every instruction" bites: you
cannot write a correct `PC32` fixup without knowing that `mov` with a RIP-relative
operand is 7 bytes).

## Not established

- **No three-format crosscheck harness yet.** The JVM course's harness
  (`courses/jvm/assets/samples/crosscheck.py`) is the model; an object-file
  equivalent must compare ELF, COFF and Mach-O structures against LLVM 21,
  binutils (where it exists) and a decoder written from the specifications.
  Not written yet. Until it is, findings above rest on LLVM + binutils + `file`
  agreement and hand-checks, which is recorded rather than glossed.
- **No object *emitter* specimen.** Module 5 requires one, and it does not exist
  yet. The mission's "from scratch" rule is not satisfied by a course with
  nothing to emit.
- **AArch64 relocation findings are from clang alone.** No independent producer
  for AArch64 was available (no `aarch64-linux-gnu-gcc`), so finding 1's AArch64
  column has one producer and one reader. `llvm-readobj-21` agrees with
  `llvm-objdump-21`, so the two are independent-ish, but a second producer is
  still wanted.
- **Mach-O has one reader toolchain.** binutils refuses Mach-O objects, so
  Mach-O claims rest on LLVM 21 plus `file` plus hand-checks.
- **No AArch64 *executable* or COFF *executable* has been produced yet**, so the
  object→executable transition (which is the whole point of the chain) is not
  yet demonstrated on those targets. Finding 5's claim that Mach-O objects carry
  provisional addresses is verified in the object; what a linker does with them
  is not.
- **The complete x86-64 and AArch64 object relocation tables are not yet
  transcribed.** Findings 1–2 use the handful of relocations these specimens
  happen to contain. Module 3's `obj-reloc-tables` must enumerate the full sets
  and must state which entries are object-only versus executable-only.
- **Archive (`ar`) specimens not yet staged.** Finding set covers `ar` as
  available, not as used.

---

## Module 1 findings (added while writing the first four concepts)

### 14. The four holes land on the trailing disp32 of three different instruction lengths

`llvm-objdump-21 -d --section=.text demo_elf.o`, real bytes:

    0000 <compute>:
       0: 01 ff                    addl %edi, %edi      2 bytes
       2: 03 3d 00 00 00 00        addl (%rip), %edi    6 bytes
       8: 8b 05 00 00 00 00        movl (%rip), %eax    6 bytes
       e: 01 f8                    addl %edi, %eax      2 bytes
      10: 83 c0 03                 addl $0x3, %eax      3 bytes
      13: c3                       retq                 1 byte
    0020 <call_out>:
      20: e9 00 00 00 00           jmp 0x25             5 bytes
    0030 <use_data>:
      30: 48 8b 05 00 00 00 00     movq (%rip), %rax    7 bytes

The relocation offsets are `0x04, 0x0a, 0x21, 0x33` and they are the trailing
4-byte `disp32` of a **6-byte**, a **6-byte**, a **5-byte** and a **7-byte**
encoding. So a relocation offset is *not* an instruction boundary, and three
different instruction lengths share the same 4-byte field. `.text` is 62 bytes
and `use_data` ends at 0x3e.

**No relocation for `private_counter`.** It is a file-local `int` initialised to
3, so clang folded it into the immediate `addl $0x3` at offset 0x10. Only a
`static`'s value can be folded; a global's cannot, because another translation
unit may change it. `global_counter` (7) is also global and is *not* folded.

### 15. Zero program headers in all three objects, twelve in a linked ELF

`readelf -lW demo_elf.o` prints, verbatim: **"There are no program headers in
this file."** Checked across the set: ELF 0 program headers, COFF no base
relocations and no directories, Mach-O no `LC_SEGMENT_64`. Three mechanisms,
one shared refusal — and it is an impossibility rather than an omission, because
every segment field depends on the final layout.

The linked counterpart, built on this machine from `exe.c` + `other.c`:

    size 1952 -> 16136      e_type REL -> DYN (PIE)      entry 0x0 -> 0x1040
    sections 16 -> 31       program headers 0 -> 12

    LOAD  offset 0x000000  vaddr 0x00000000  filesz 0x5e8  R    0x1000
    LOAD  offset 0x001000  vaddr 0x00001000  filesz 0x181  R E  0x1000
    LOAD  offset 0x002000  vaddr 0x00002000  filesz 0x160  R    0x1000
    LOAD  offset 0x002e00  vaddr 0x00003e00  filesz 0x220  RW   0x1000
                                        ^^^^^^^^
    the RW segment's file offset and load address differ by exactly one page

Sections went **up**, not down. The linker creates `.interp`, `.dynamic`,
`.got`, `.plt`, `.rela.dyn`, `.rela.plt`, `.init_array`, `.fini_array` and the
output's own `.symtab`/`.strtab`/`.shstrtab` — none of which any compiler
emitted. **A linker generates structure, it does not only fill holes.**

And the relocations change species: the object's four are symbol-relative and
all unresolvable locally; in the executable there are **zero** against
`external_fn` and what remains is `R_X86_64_RELATIVE` (add the load base to
what is already here) and `R_X86_64_GLOB_DAT` (ask the dynamic linker).

### 16. `nm` across the three formats, side by side

    SYMBOL          ELF          COFF              Mach-O
    compute         00000000 T   00000000 T        00000000 T _compute
    call_out        00000020 T   00000020 T        00000020 T _call_out
    use_data        00000030 T   00000030 T        00000030 T _use_data
    global_counter  00000000 D   00000000 D        00000048 D _global_counter
    message         00000008 D   00000008 D        00000050 D _message
    message_bytes   00000000 R   00000000 R        0000005e S _message_bytes
    uninitialised   00000000 B   00000000 B        000000f8 S _uninitialised
    external_fn     undefined    undefined         undefined U _external_fn
    literal         --           00000000 R ??_C@_05CJBACGMB@hello?$AA@
    clang marker    --           00000000 a @feat.00   --

- **Code offsets are byte-identical across all three** (0, 0x20, 0x30) because
  `.text` comes first with nothing before it. A coincidence of ordering, not a
  property of the formats.
- **Data differs**: Mach-O reports real addresses (`0x48` = `__data`, `0x58` =
  `__cstring`, `0x5e` = `__const`, `0xf8` = `__common`).
- **Mach-O collapses `R` and `B` into `S`.** Not information loss in the file:
  `__cstring` has `Offset: 792` (real bytes) and `__common` has `Offset: 0` (no
  bytes). `nm` is what loses it.
- **COFF has two extra symbols**: the MSVC-mangled string literal, and
  `@feat.00`, a clang-internal marker letting C output be consumed by a C++
  linker. ELF has 12 `.symtab` entries against COFF's 10 and Mach-O's 8: the
  extras are one `STT_FILE` entry and `STT_SECTION` entries for **only**
  `.text` and `.rodata.str1.1` — demand-driven, since only those two are the
  target of a relocation. `.data` has a relocation and gets **no** section
  symbol.

### Module 1 harness state

No automated crosscheck yet for the object course (recorded as a known gap in
"Not established"). Everything above is from `llvm-readobj-21`,
`llvm-objdump-21`, `llvm-nm-21`, `readelf` and hand-decoding, on files that are
committed and byte-reproducible. One error was caught and corrected **during**
writing: a plausible-looking x86-64 disassembly listing was written from memory
into `obj-the-hole`, and replaced with the real bytes from `llvm-objdump-21`
once finding 14 was measured. **That is the mission's rule working: the claim was
checked, and the claim was wrong.**
