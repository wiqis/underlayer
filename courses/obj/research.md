# Object Files — Phase A research record

> Scope and goal: `docs/course-mission.md`. This course is the **object files**
> link in the parsing→executable chain, and it is written from the **linker's**
> point of view, because the mission's outcome is a learner who can build a
> linker.
>
> Status: **complete.** All 18 concepts written and verified, all five modules
> shipped, landing page and static output generated. See "Course plan" at the
> end, and findings 36-46 below for what the writing itself turned up --
> including three corrections to earlier findings in this record.

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
relocations and no directories. **Mach-O objects _do_ carry an
`LC_SEGMENT_64` command** and it is still not a mapping plan: its `segname`
is sixteen zero bytes, one unnamed segment with `vmaddr 0x0` holding all six
sections flat. A claim written here that Mach-O objects have no segment command
was **wrong** and was caught by re-measuring after the concept was drafted.
Three mechanisms, one shared refusal — and it is an impossibility rather than an omission, because
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

### 17. COFF hides half its symbol table inside the symbol table

`demo_coff.o`: `PointerToSymbolTable = 0x211`, `NumberOfSymbols = 26`, so the
string table is at `0x211 + 26*18 = 0x3e5` and the records are **18 bytes** with
an **8-byte** name field (not 4 — 8+4+2+2+1+1 = 18).

Decoding all 26 records: **only 14 are symbols.** Twelve are auxiliary records,
each immediately following a section symbol whose `NumberOfAuxSymbols = 1`, and
each with a garbage `Value` (`0x672d789d`, `0xd04b58a`, `0x7831d036`, …) and
`StorageClass = 0`. A reader that does not honour `NumberOfAuxSymbols` prints
twelve nonsense symbols with nonsense addresses and **nothing looks wrong**.

The cross-check that catches it: each aux record carries the section's size and
relocation count, and `demo_coff.o` also has both in the 40-byte section
headers. **The same facts twice in COFF** — so comparing them is a one-line
validation of a COFF reader.

### 18. COFF's 8-byte name field is a union, and both halves appear

    inline:  the 8 bytes ARE the name, NUL-padded
             b'.text\x00\x00\x00'   b'@feat.00'   b'compute'
             b'.debug$S'  is exactly 8 with NO NUL

    strtab:  first 4 bytes ZERO, last 4 are a DECIMAL offset
             into the string table at 0x3e5
             strtab+4  -> message_bytes     strtab+18 -> global_counter
             strtab+33 -> external_fn       strtab+45 -> .llvm_addrsig
             strtab+59 -> uninitialised    strtab+73 -> ??_C@_05CJBACGMB@hello?$AA@

`strtab+45` is the same string the section-name `/45` escape resolves to — one
string table, two uses. (Verified: the `/45` offset is **decimal 45**, and
hex 0x45 = 69 lands in the symbol names instead. Getting this wrong on the first
attempt is the normal experience.)

### 19. Section 0 does not mean undefined in COFF, and `ABS` is a third thing

    [20] external_fn   sect=UNDEF(0)  class=EXTERNAL(2)   a real want
    [25] demo.c        sect=UNDEF(0)  class=0             NOT a want
    [15] @feat.00      sect=ABS(-1)   class=STATIC(3)     an absolute constant
    [24] .file         sect=DEBUG(-2) class=103           the source filename

**`SectionNumber == 0` is necessary but not sufficient.** COFF reuses one byte
(`StorageClass`) for both "am I defined" and "how visible am I"; ELF splits them
into `st_shndx` and `st_info`'s binding nibble. A COFF reader testing only the
section number treats `demo.c` as an unresolved symbol.

`ABS` is a genuinely distinct concept: the `Value` is a constant, not an address
or an offset. Adding a section base to it produces a pointer, which is not what
it meant.

### 20. Section symbol counts differ by policy, not by format defect

COFF emitted **7** section symbols (one per section). ELF emitted **2**
(`STT_SECTION` for `.text` and `.rodata.str1.1` only) — and **not** for `.data`,
which has a relocation against it, because that relocation targets the variable
`message` by name and so nothing needs a section symbol. Mach-O emitted 0.

**Demand-driven:** a section symbol exists because something *named that
section*. Neither format is wrong, and both counts occur in files from the two
most common toolchains. A tool assuming "every section has a symbol"
over-allocates; a tool assuming one-to-one correspondence breaks on ELF.

### 21. COFF's Type field packs a base type in its high nibble

`compute`, `call_out` and `use_data` all have `Type = 0x20`, which is
`0x2 << 4` — base type 2, *function*. Every data symbol has `Type = 0`. So COFF
distinguishes code from data in exactly one place, and ELF does it with
`STT_FUNC` vs `STT_OBJECT` and Mach-O with an `N_TYPE` mask. Three
vocabularies for the same question.

### 22. Section record sizes: 40 / 64 / 80 bytes, and Mach-O's alignment is a log

    COFF    40-byte records, 7 sections
    ELF     64-byte Elf64_Shdr, 16 entries in demo_elf.o
    Mach-O  80-byte section_64, 6 sections

Mach-O's extra 16 bytes per section are a second name field (the segment name),
and every section declares `__TEXT` or `__DATA` there — inert in an object,
because the single `LC_SEGMENT_64` is unnamed.

    ELF AddressAlignment   Mach-O align
    16                     4     (2^4 = 16 bytes)
     8                     3     (2^3 =  8 bytes)

**ELF stores a byte count, Mach-O stores a logarithm.** Both wrong readings are
plausible powers of two, and the failure is a section placed at an address
satisfying the wrong constraint — which links cleanly and faults at run time
only when an aligned SSE/AVX operand (`movaps`) meets it.

### 23. Correction: Mach-O objects DO have an LC_SEGMENT_64

An earlier draft of this record claimed Mach-O objects have no segment command.
**That was wrong.** Re-measured: `demo_macho.o` has `ncmds = 4`, one of which is
`LC_SEGMENT_64` — 72 bytes, `vmaddr 0x0`, `vmsize 252`, `nsects 6`, and its
`segname` field is **sixteen zero bytes**. One unnamed segment holding all six
sections flat. So Mach-O objects carry a segment command that is a placeholder
with the right shape, and a reader must know not to treat it as a mapping plan.
The lesson stands (an object's addresses are unknowable) but the mechanism is
nuanced rather than absent, and the concept was corrected before shipping.

### 24. `st_value` is an alignment for a COMMON symbol — the only symbol whose Value is not a value

Source (5 builds on this machine):

    int tentative;            /* tentative definition */
    int initialised = 5;      /* real definition       */
    int main(void) { return tentative + initialised; }

| build | `tentative` Ndx | Val | Size | Type | `initialised` |
|---|---|---|---|---|---|
| clang `-fno-common` | **5** (a real section) | 0 | 4 | `B` (.bss) | 4, 0, `D` |
| clang `-fcommon` | **COM** | **4** | 4 | **`C`** | 4, 0, `D` |
| gcc (default) | 5 | 0 | 4 | `B` | 4, 0, `D` |
| COFF | — | 0 | 4 | `B` | 4, 0, `D` |
| Mach-O | 0x60 | — | 4 | `S` (`__common`) | 0x1c, `D` |

**`st_value = 4` in the COMMON case is the required alignment, not an address.**
A COMMON symbol is in no section and has no position, so ELF repurposes the
field for alignment and puts the size in `st_size`. A reader that adds a section
base to it produces a plausible, meaningless number. `st_shndx` is the only
thing that distinguishes the two meanings — a three-level dependency
(`st_value` depends on `st_shndx`, whose reserved value is the special case).

### 25. With `-fcommon` there is no `.bss` section, and the file is 72 bytes smaller

    clang -fno-common:  1312 bytes, 11 sections, .bss PRESENT
    clang -fcommon:     1240 bytes, 10 sections, .bss ABSENT

The saving is exactly the section header. A COMMON symbol needs no section to
live in, so none is created; the linker invents the zero-fill region in the
output after merging every COMMON symbol by name — **largest size, strictest
alignment, one allocation, all references pointed at it.**

### 26. Three encodings of one C rule

- **ELF `SHN_COMMON`** — no section at all; `st_value` = alignment,
  `st_size` = size. Cheapest in the file, most expensive in the reader.
- **Mach-O `__common`** — a real section, `flags = 0x1` (`S_ZEROFILL`),
  `size 4`, `offset 0`, `addr 0x60`. Most expensive in the file, cheapest in
  the reader: a symbol in a section means what it always means.
- **COFF** — a storage class rather than a special section index, inheriting the
  same one-field-two-jobs problem as the symbol table.

All three converge on the *same* linker algorithm. The difference is purely how
much the file has to say about it.

### 27. The GCC 9 → 10 ABI break, and why it was not a bug

`-fcommon` was GCC's default through GCC 9; `-fno-common` became the default in
GCC 10. A library built with GCC 9 has COMMON symbols; an application built with
GCC 10 has `.bss` tentative definitions; linking them gives a duplicate-symbol
error. Every prebuilt C library on a Linux distribution, and every application
linking against one, broke.

**Neither behaviour is non-conforming.** C permits a translation unit to treat a
tentative definition as a definition, *and* permits merging them — the standard
arguably leaves the question open, and the two flags answer it differently. So
this was not a compiler bug: it was two toolchains answering an underspecified
question differently, and **the format had no way to make them interoperate
because it faithfully recorded a decision each side made locally.**

The design lesson: *when two correct producers disagree, a format must give them
a way to record the disagreement, not just agreement.* ELF's answer is
`SHN_COMMON` plus the `.gnu.linkonce` section-group mechanism — and the break
happened anyway, because nothing in the format says `.bss` and COMMON mean
incompatible things. Same shape as the JVM attribute mechanism's safety property:
letting a reader *skip* is safer than letting it *misread*.

### Not yet done

`obj-strings` is still unwritten even though its material is largely covered by
findings 18, 19 and the sections/symbols concepts — the three name-storage
strategies, ELF's two string tables, and COFF's single table serving both
`/NNN` section-name escapes and long symbol names. It should be written as a
short synthesis rather than re-measured.

### 28. The relocation tables are a classification, not a list

Two authoritative sources on this machine, and they answer different questions:

| Source | What it gives | Count |
|---|---|---|
| `/usr/include/elf.h` | names and numbers only, plain enum | 44 `R_X86_64_` |
| `/usr/lib/llvm-21/include/llvm/BinaryFormat/ELFRelocs/X86_64.def` | names **plus per-entry property flags** | 44 |
| `.../AArch64.def` | same | **233** |

**AArch64's 233 is two ABIs in one table:** 147 `LP64` plus **86 `R_AARCH64_P32_*`**
(ILP32). The headline number is 233; the useful number is 147. Always check for
a second ABI before concluding anything from a count.

| Arch | Total | PC-relative | TLS |
|---|---|---|---|
| x86-64 | 44 | 18 | 18 |
| AArch64 (LP64) | 147 | 71 | 53 |

LLVM's classification flags, decoded:

| Flag | Bit | Meaning |
|---|---|---|
| `REL` | 0x1 | divide by field width — the stored value is an offset |
| `SYM` | 0x2 | plain symbol address, not divided |
| `PC` | 0x4 | subtract the patch address |
| `TYPE` | 0x8 | the field holds an address — **overflow must fail the link** |
| `SIZE` | 0x10 | needs **twice** the field space; a second quantity is packed alongside |
| `TLS` | 0x20 | thread-local |
| `IREL` | 0x40 | resolver address, patched at load time |

**A linker implements ~9 cases (absolute, PC-relative, GOT-relative, PLT/call,
overflow check, paired entries, TLS, IRELATIVE, NONE) and derives the rest,
which are width and sign variants.** 147 entries collapse to nine behaviours.

### 29. The AArch64 pairing is a bit in the table, not just a convention

Every AArch64 relocation participating in an ADRP/LO12 pair carries **`SIZE`**:

    R_AARCH64_ADR_PREL_PG_HI21      275  SIZE+SYM+REL
    R_AARCH64_ADR_PREL_PG_HI21_NC   276  SIZE+PC
    R_AARCH64_LDST32_ABS_LO12_NC    285  SIZE+TYPE+PC+REL
    R_AARCH64_LDST64_ABS_LO12_NC    286  SIZE+TYPE+PC+SYM

`SIZE` means "not independent — needs extra space because a second quantity is
encoded alongside". So **the machine-checked form of finding 1 is a bit saying
this relocation has a partner.** A linker that processes records independently
links cleanly and faults at run time, because nothing in the file is malformed:
each record is valid alone, and the pairing is a relationship the file cannot
mark as violated.

### 30. `R_X86_64_PC32` is flagged `SYM`; `R_X86_64_PLT32` is flagged `PC`

This closes the second concept's open question. The two perform **identical
arithmetic**; the only difference is the PLT hint — and the hint **is the `PC`
flag**. The name describes the *field* (`PC32` = 32-bit PC-relative displacement)
while the flags describe the *relocation's behaviour*. Reading both gives the
whole type; reading either alone gives half of it and a plausible wrong answer.

### 31. TLS is where relocation tables actually grow

18 of x86-64's 44 and 53 of AArch64's 147 entries are TLS. A thread-local address
has several components (thread pointer, TLS-block offset, module offset, symbol
offset) and each instruction form combines a different subset — roughly a dozen
types per architecture. **Relocation table size tracks instruction-set complexity
in the area being addressed, not the number of addressing modes**, and the growth
clusters where new capabilities arrived rather than spreading evenly. This is the
same additive-growth pattern as the JVM attribute mechanism and ELF section types.

The table is **not partitioned by file type** — the same `R_X86_64_PC32` appears in
an object and an executable, and `R_X86_64_32` is normal in an object and
forbidden in a PIE. The *compiler's choices* pick the subset, so a linker must
handle the union and a PIE-aware linker must reject the wide one deliberately.

### Not yet done

`obj-relocations`, `obj-addends` and `obj-pic` remain in Module 3. Their
material is largely measured (findings 1, 4, 14, 29, 30), but `obj-pic` needs a
GOT-relative specimen built with `-fPIC` and the non-PIC/PIE comparison
measured rather than described. `obj-emit` still has no hand-built object file,
which is the mission's "from scratch" test.

### 32. `-fPIE` produces IDENTICAL relocations to no flag; only `-fPIC` changes them

Same `demo.c`, same machine, `llvm-objdump-21 -r`, three builds:

| `.text` reloc | no flag | `-fPIC` | `-fPIE` |
|---|---|---|---|
| data ref 1 | `PC32` @0x04 | **`REX_GOTPCRELX` @0x05** | `PC32` @0x04 |
| data ref 2 | `PC32` @0x0a | **`REX_GOTPCRELX` @0x0e** | `PC32` @0x0a |
| the call | `PLT32` @0x21 | `PLT32` @0x21 | `PLT32` @0x21 |
| data ref 3 | `PC32` @0x33 | **`REX_GOTPCRELX` @0x33** | `PC32` @0x33 |
| `.data` → literal | `64` | `64` | `64` |
| internal calls | `PC32` ×3 | `PC32` ×3 | `PC32` ×3 |

**Two findings, both counter-intuitive:**

1. **`-fPIE` and no flag are byte-identical in their relocation sets.** A PIE
   executable is loaded near its link address, so it does not need GOT
   indirection for its own data. Only `-fPIC` — a shared library, which can be
   loaded anywhere — pays for the GOT.
2. **The offsets shift by one byte under `-fPIC`** (0x04→0x05, 0x0a→0x0e). The
   instruction got *longer*: `REX_GOTPCRELX` requires a REX prefix byte that the
   plain RIP-relative form does not. **Changing the relocation type changes the
   instruction encoding, which changes every subsequent offset in the section.**
   A tool that assumes relocation offsets are independent of relocation types will
   be wrong on every `-fPIC` object.

Note also that the *call* is `PLT32` in all three — the call path is already
indirection-based, so PIC does not change it. Only the **data** references move to
the GOT, and that is the whole design.

### 33. C's plain `inline` provides no external definition — so no COMDAT group appears

Tested at both `-O1` and `-O0`, three formats:

    inline int shared_inline(int x) { return x + 1; }
    int a(int v) { return shared_inline(v); }

    ELF    readelf -g: "There are no section groups in this file."
           llvm-nm:  U shared_inline        <- UNDEFINED, no definition
    COFF   two .text sections (indexes 0 and 4); the second has
           Characteristics 0x60501020 vs the first's 0x60500020 --
           the difference is 0x1000 = IMAGE_SCN_LNK_COMDAT
    Mach-O llvm-nm: U _shared_inline          <- UNDEFINED

**C99's `inline` alone does not create an external definition** — that is the
"inline vs extern inline vs static inline" rule, and it means there is nothing
in the object for a group to own. COFF emitted a COMDAT section anyway; ELF and
Mach-O emitted no group and no `linkonce`. Linking the two objects produced **no
collision**, because there was nothing to collide.

**To exercise the COMDAT path, the specimen needs `static inline` (which does
create a definition) or a C++-style inline with external linkage.** This is
recorded as an open measurement, not a conclusion: the three formats disagreed
and the next session must establish which of them is right and why before
`obj-comdat-group` claims anything.

### 34. A weak definition in COFF gets a section named after its *referrer*

From a three-format build of:

    __attribute__((weak)) int maybe(int x) { return x - 1; }
    int uses_weak(int a) { return maybe(a); }

    ELF    W maybe
    COFF   W maybe   AND  a .weak.maybe.default.caller   section
    Mach-O _maybe

**COFF's extra section embeds the referencing function's name** — `.weak.maybe
.default.caller` — because COFF has no per-symbol COMDAT. Its mechanism is to put
the definition in a section whose *name* is unique to the definition, and that
name happens to be built from the symbol plus the function that triggered the
emission. That is a real and undocumented-looking design divergence worth a
concept, and it is the sort of thing that only shows up when you look at
`llvm-readobj --sections` rather than at `nm`.

### Not yet done — 9 concepts

Module 3: `obj-relocations`, `obj-addends`, `obj-pic`
Module 4: `obj-comdat-group`, `obj-archives`, `obj-weak-undef`
Module 5: `obj-emit`, `obj-arch-table`, `obj-verify`

`obj-pic` has everything it needs (finding 32). `obj-addends` and
`obj-relocations` have findings 1, 4, 14, 29, 30. `obj-comdat-group` and
`obj-weak-undef` have finding 34 but finding 33 is an **open question that must
be resolved before writing** — the three formats disagreed on whether a COMDAT
section appears, and the mission's rule is that a claim needs agreement.

`obj-emit` still has no hand-built object file, which is the mission's
"from scratch" test.

### 35. RESOLVED: why C's `inline` never produces a COMDAT group, and C++'s does

Finding 33 was left open because the three formats appeared to disagree. They
do not — the specimen was wrong. Measured properly, three formats, C and C++:

| source | definition? | ELF group | COFF COMDAT | Mach-O |
|---|---|---|---|---|
| `inline int f()` (C99) | **none** — undefined symbol | no | no | no |
| `static inline int f()` | file-local, private linkage | no | no | no |
| `inline int f()` (C++) | **yes**, external linkage | **yes** | **yes** (`0x1000`) | yes |

**The rule: a COMDAT group exists only for a symbol with external linkage that
more than one translation unit might define.** C's plain `inline` provides no
external definition (the C99 inline/extern-inline/static-inline rule), so there
is nothing to group. C's `static inline` is private to one file, so there is
nothing to merge. **C++'s `inline` does have an external definition and may
appear in any number of translation units — which is exactly the situation a
group exists to resolve.**

And the ELF group, decoded, shows all three mechanisms keying on the *mangled
name*:

    COMDAT group section [4] `.group' [_Z10cxx_inlinei] contains 1 sections:
       [Index]    Name
       [    5]   .text._Z10cxx_inlinei

The group's **signature is `_Z10cxx_inlinei`**, and the member section is
**named after the signature too**. Two objects each defining `cxx_inline` link
with **no duplicate-symbol error** — verified: `ld -r t1.o t2.o` is silent, where
without the group it would be a hard error.

COFF's variant, from finding 34, embeds the *referrer* instead:
`.weak.maybe.default.caller`. **Same concept, different key.** Mach-O uses a
`linkonce` section type; `nm` shows `_Z10cxx_inlinei` as `T` in both, with the
merge decided by the section rather than the symbol.

**So the three mechanisms, correctly:**
- **ELF** `SHT_GROUP` — a named group section; the signature is the symbol name
- **COFF** `IMAGE_SCN_LNK_COMDAT` (0x1000) — a flag on the section itself, with a
  unique section name
- **Mach-O** a `linkonce` section type — carried in the section flags

Three teams, one problem, three places to put the answer: a group table, a
section flag, and a section type. **This is the clearest case in the course of an
essential idea being reinvented independently three times** — the test the
triangulation concept proposed for telling essential from accidental.

---

## Module 3 findings (added while writing obj-relocations, obj-addends, obj-reloc-tables, obj-pic)

### 36. CORRECTION to finding 4: the addend is in the RECORD, not in the bytes

Finding 4 said the `-0x4` in a relocation listing "is the *implicit* addend,
which lives in the four bytes of `.text` at offset 4". **That is wrong for
`demo_elf.o`, and the correction is the whole subject of `obj-addends`.**

    $ xxd -s 0x40  -l 8  demo_elf.o        # .text + 4:  03 3d 00 00 00 00
                                              #              ^^^^^^ ALL ZERO
    $ xxd -s 0x250 -l 8  demo_elf.o        # r_addend:  fc ff ff ff ff ff ff ff

x86-64 is **RELA**. The `-4` is an explicit signed `i64` in the relocation
record and the four bytes in the section are zero, because a relocatable
object has no addresses to put there.

Proved by building the 32-bit counterpart of the same 30 lines, which uses
**REL** and therefore has no addend field at all:

    $ clang -target i386-pc-linux-gnu -O1 -fno-pic -c demo.c -o demo_i386_nopic.o
    $ xxd -s 0x60 -l 6 demo_i386_nopic.o
    00000060: e9fc ffff ff66                 e9 = jmp rel32 at text offset 0x20
                                            fc ff ff ff = the -4, at 0x21

Same source, same machine, two answers -- and the only variable is whether the
record type is REL or RELA.

### 37. COFF's PC bias is in the TYPE's definition, and linking proves it

`demo_coff.o`'s `.text` at offset 4 is `00 00 00 00` and its record is
`04 00 00 00 | 11 00 00 00 | 04 00` -- three fields, **no addend**. So where
is the `-4`? In the specification of `IMAGE_REL_AMD64_REL32`, which defines
the value as the displacement from the byte *following* the field.

Verified by linking, which is the only way to see a value the input never
contained:

    $ clang -target i386-pc-windows-msvc -O1 -c demo.c -o a.obj
    $ ld -m i386pe --oformat pei-i386 -o out.exe a.obj b.obj
    $ llvm-objdump-21 -d out.exe
    00401020 <_call_out>:
      401020: e9 1b 00 00 00    jmp 0x401040 <_external_fn>

    S = 0x401040   P = 0x401021   bias = 4
    0x401040 - (0x401021 + 4) = 0x401025 -> 0x1b

**The `-4` is in the linker's code and in no input file.** So the addend is
*data* in ELF-RELA and *code* in COFF, and a tool holding a COFF object can
never recover the bias from it.

### 38. CORRECTION to finding 2: "COFF has no PLT variant" is per-TARGET, not per-format

    x86-64 COFF:  0x4 IMAGE_REL_AMD64_REL32  x4   (call and data refs alike)
    i386   COFF:  0x14 IMAGE_REL_I386_REL32   (the call)
                  0x6 IMAGE_REL_I386_DIR32  x3   (the data refs)

Different types, same format. The claim only holds for x86-64, which sharpens
finding 2's real point: a linker implements a vocabulary per **target**.

### 39. The three relocation records, field by field, all measured

| | ELF64-RELA | ELF32-REL | COFF x64 | Mach-O x64 |
|---|---|---|---|---|
| size | 24 | 8 | 10 | 8 |
| offset | `r_offset` u64 | `r_offset` u32 | `VirtualAddress` u32 | `r_address` **i32** |
| sym+type | packed: `(sym<<32)\|type` | packed: `(sym<<8)\|type` | **separate** u32 + u16 | 6 bitfields in one u32 |
| addend | `r_addend` i64 | (none -- in the bytes) | (none -- in the bytes) | (none -- in the bytes) |
| links to its section | `sh_info` in the reloc's header | same | positional (`relptr`) | positional (`reloff`) |
| order in file | ascending | ascending | ascending | **descending** |

The Mach-O `0x1d000003` unpacked and checked by hand against the bytes:
`type=1, extern=1, length=2, pcrel=1, symnum=3 (_message)`.

## Module 4 findings (obj-comdat-group, obj-archives, obj-weak-undef)

### 40. CORRECTION to finding 35: Mach-O has NO linkonce section

Finding 35 said Mach-O "uses a `linkonce` section type". **Modern clang does
not emit one, and the term is not in the format definitions at all:**

    $ grep -i linkonce /usr/lib/llvm-21/include/llvm/BinaryFormat/MachO.h
    (no output)

    $ llvm-objdump-21 --section-table ca_macho.o
      __text      addr=0x0000 size=0x0019 flags=0x80000400
      __eh_frame  addr=0x0020 size=0x0068 flags=0x6800000b
    # two sections. No member section, no group.

    # the whole mechanism, decoded from the nlist_64 entries:
    __Z13shared_inlinei  n_type=0x0f  sect=1  n_desc=0x0080  N_WEAK_DEF

So the three mechanisms are:

| | where the answer lives | cost | can it detect disagreement |
|---|---|---|---|
| ELF | a whole `SHT_GROUP` section | +1 section, +1 symbol | no |
| COFF | a `0x1000` bit + a `Selection`/checksum in the aux record | +1 section, +1 aux | yes, advisory |
| Mach-O | **one bit in a symbol** | 0 | no |

The replacement is a better lesson than the original: two formats put the
answer in a section and the third puts it in a symbol.

### 41. COFF's COMDAT has a policy and a checksum; the other two have neither

Both COFF specimens carry `Checksum = 0x751D2B5A`, `Selection = 2`
(`IMAGE_COMDAT_SELECT_ANY`), and byte-identical bodies (`8d 41 01 c3`).
`SELECT_NODUPLICATES` and `SELECT_ASSOCIATIVE` also exist and are the only
per-definition merge policies in any of the three formats.

### 42. The C counterexample: COMDAT is a C++ requirement and C never got one

Four spellings of one function, three formats, measured:

| source | `nm` | group? | two TUs link? |
|---|---|---|---|
| C `inline` | `U f` (UNDEFINED) | no | n/a -- nothing exists |
| C `static inline` | `t f` (local) | no | n/a -- private |
| C `inline` + `extern` decl | `T f` (global) | **no** | **FAILS**: `multiple definition of 'f'` |
| C++ `inline` | `T f` + WEAK + group | yes | links silently |

The rule: **a group exists only for a symbol with external linkage that more
than one translation unit is licensed to define.** C's `static inline` is
private; C's plain `inline` emits no definition at all; C's `inline`+`extern`
has a definition but C does not license the duplication.

### 43. COFF has no weak flag -- the name IS the mechanism

    w_coff.o:     .weak.maybe.default.uses_weak      Section .text (1), EXTERNAL
    uw_coff.o:    .weak.optional_hook.default.probe  Section ABSOLUTE(-1), Value 0

No bit, no storage class, no aux field. The referrer's name is embedded
because COFF has no per-symbol COMDAT and needs a name unique per
(definition, referrer) pair -- so two TUs with the same weak symbol and
different callers produce different names, do not merge, and coexist.

The undefined-weak case is the elegant one: `Section = IMAGE_SYM_ABSOLUTE`
with `Value = 0` **reuses the category that already means "constant"** to say
"the address zero". No new field.

### 44. Weak defeat removes the SYMBOL and keeps the BYTES

    $ ld -r w_elf.o w2_elf.o -o rw.o        # silent
    $ readelf -sW rw.o | grep maybe
      8: 0000000000000020  4 FUNC  GLOBAL DEFAULT 1  maybe   # promoted, points at 0x20

    $ llvm-objdump-21 -d rw.o
      0: 8d 47 ff   leal -0x1(%rdi),%eax    <-- the WEAK body, still here
      3: c3
     20: 8d 47 64   leal  0x64(%rdi),%eax   <-- the STRONG body, where `maybe` points

Input `.text` sizes 21 and 22; merged `.text` is **54**. 5 of the extra 11
bytes are the dead weak body and the rest is padding. **No tool reports
anything.** The only way to reclaim it is to have put the definition in its own
section -- i.e. a COMDAT group.

### 45. Archive resolution is a fixed point, not a backwards scan

The common claim ("linkers read archives backwards") is false, and the way to
settle it is to build an archive where a backwards pass also fails:

    $ ar rcs libfwd.a l2.o l1.o l3.o
    $ ld -o fwd -Map=fwd.map main.o libfwd.a     # SUCCEEDS

* forward: `l2` is passed before anything wants `level2` -> fail
* backward: `l1` is reached while `l2` is still ahead of the cursor -> fail

Both single passes fail and the link works, so GNU ld repeats the scan until a
pass loads nothing new. The map file is the evidence:

    Archive member included to satisfy reference by file (symbol)
    libfwd.a(l1.o)  main.o (level1)
    libfwd.a(l2.o)  libfwd.a(l1.o) (level2)
    libfwd.a(l3.o)  libfwd.a(l2.o) (level3)

And `libdemo.a`'s map lists only `mathlib.o` and `strlib.o`. `unused.o` is
**not mentioned anywhere** -- not included, not discarded, not at all.

## Module 5 findings (obj-emit, obj-arch-table, obj-verify)

### 46. The from-scratch object file, and the four bugs that got past every tool

`emit_elf.py` writes a 936-byte ELF64 x86-64 relocatable object using nothing
but `struct`. GNU `ld` merges it with compiler-produced objects and the
resulting program prints the right answers.

    $ ./app
    start(5)      = 11
    answer        = 41
    *answer_ptr   = 41   (answer_ptr == &answer: yes)

The linker's arithmetic, checked by hand:

    start  at 0x1140:  e8 01 00 00 00   0x1144 + 5 + 1  = 0x114a = compute
    compute at 0x114a: e8 0d 00 00 00   0x114e + 5 + 0x0d = 0x1160 = helper
    .data: answer = 0x29 = 41 at 0x4010; answer_ptr = 0x4010 at 0x4014

**Four bugs, and every one produced a file that `readelf`,
`llvm-readobj-21` and `llvm-objdump-21` read without a warning:**

1. `e_shoff` hardcoded to 64 -- the header pointed the section table at
   `.text`. `readelf` errored. Loud, and the lucky case.
2. `sh_link`/`sh_info` on the relocation sections pointing at the wrong
   indices. The file *parsed*; every symbol name came out empty.
3. `answer` and `answer_ptr` both at offset 0 of an 8-byte `.data` -- they
   **overlapped**. Legal ELF. Linked, ran, printed an address where 41 was
   expected. **No tool reported anything.**
4. `addl $1` emitted *before* the call instead of after, so `compute` was
   `helper(x+1)`. Plausible disassembly, wrong program.

Only bug 3 is instructive, and it is the argument for `obj-verify`: an object
file has **no internal consistency check on symbol placement**.

### 47. The AArch64 relocation field is a BIT RANGE, verified positively

`enc_a64_nopic.o` at `-fno-pic`, one reference to `g32`:

    0: 90000008   adrp x8, #0    R_AARCH64_ADR_PREL_PG_HI21  g32
    4: b9400100   ldr  w0, [x8]  R_AARCH64_LDST32_ABS_LO12_NC g32
    8: d65f03c0   ret

Decoded by hand from the little-endian word `0x90000008`:

    bit 31      op      = 1            (ADRP, not ADR)
    bits 30:29  immlo   = 0            2 of the 21 bits
    bits 28:24  fixed   = 10000        must be exactly this
    bits 23:5   immhi   = 0            the other 19 bits
    bits 4:0    Rd      = x8
    -> 21-bit signed page delta = (immhi << 2) | immlo

and the LDR word `0xb9400100`: `size=2, imm12 = bits 21:10 = 0, Rn = x8, Rt = w0`.

**Verified positively, not by reading zeros.** `aarch64_enc.py` encodes a
chosen page delta, the words are placed with `.inst`, and an independent
disassembler reads back what was encoded:

    $ python3 aarch64_enc.py --build 3    ->  0xf0000008
    $ llvm-objdump-21 -d adrp_test.o
      0: f0000008   adrp x8, 0x3000                     = +3 pages
      4: f0ffffc8   adrp x8, 0xffffffffffffb000         = -5 pages
     20: 90000008   adrp x8, 0x0

So the 21 bits are split 2 + 19 and sign-extended, and a linker must
**read-modify-write** -- a plain four-byte overwrite destroys the destination
register. There is no AArch64 linker on this machine, so the pair was verified
by construction and read-back rather than by linking, and the concept says so.

### 48. x86-64 field offsets vary with the instruction's prefixes

All from `enc_nopic.o` (`-O0 -fno-pic`):

    bytes                     len  field at   instruction
    e8 00 00 00 00             5     +1       call rel32
    0f 84 00 00 00 00          6     +2       jz   rel32
    8b 05 00 00 00 00          6     +2       movl (%rip), %eax
    8b 04 25 00 00 00 00       6     +3       movl 0x0, %eax
    48 8b 05 00 00 00 00       7     +3       movq (%rip), %rax
    48 8b 04 25 00 00 00 00    7     +4       movq 0x0, %rax
    c7 04 25 <disp32> <imm32> 10     +3       movl $1, 0x0

**The field offset is not derivable from the relocation type** -- the same
type appears at +3 and +4 depending on a REX prefix. And the last row is why
"the field is the last four bytes" is a trap: it has an immediate after it.

## Harness state

`assets/samples/crosscheck.py` runs **95 checks, 0 failures**, in three tiers
that are ordered by independence rather than by count:

* **Tier 3** -- the file disagrees with itself. COFF's aux records repeat each
  section's size and relocation count, so a reader that mis-parses them
  disagrees with the section header with no oracle at all. ELF's symtab
  `sh_info` must be the index of the first GLOBAL and everything before it
  LOCAL. This tier is the cheapest and catches the most.
* **Tier 2** -- this decoder, written from the specifications, diffed field by
  field against `readelf` and `llvm-readobj-21`. ELF and COFF have two
  independent toolchains on this machine; **Mach-O has one**, and the concepts
  say so rather than implying parity.
* **Tier 1** -- the emitter vs a reference producer. Listed last deliberately:
  a reference producer is an oracle for *a* file, not for *your* file, and a
  whole-file byte diff has a signal-to-noise ratio bad enough that people
  learn to ignore it.

Tier 1 as a *byte* comparison is worthless and is **not** done. The acceptance
test for `hand.o` is instead: GNU `ld` accepts it, it links with
clang-produced objects, and the program prints the right numbers.

`assets/samples/ardec.py` decodes `libdemo.a` field by field from the format
description and cross-checks the index against each member's own symbol table
-- two independent records of the same fact, so the index is auditable.

`assets/samples/build_samples.sh` rebuilds every specimen and ends with a
`cmp` proving `demo_elf.o` is byte-reproducible, which is what lets the course
say "these exact bytes are these exact claims".

## Three corrections, and why they are recorded rather than quietly fixed

Findings 4, 35 and 8 were wrong in the same way: **each was a plausible
reading of a specification that had been consulted rather than a file that had
been opened.** Finding 8's claim that "ELF needs two string tables ...
`demo_elf.o` has both" is false of the very file the course ships -- see 49.

### 49. CORRECTION: `demo_elf.o` has ONE string table, not two

    e_shstrndx = 1
    .symtab sh_link = 1
    section 1 is named .strtab

There is no `.shstrtab` section header in the file at all, and the single
table's contents interleave section names and symbol names with nothing to
distinguish them:

    b'\x00.rela.text\x00call_out\x00.comment\x00.bss\x00message_bytes\x00
      global_counter\x00external_fn\x00...'

GCC's build of the same 30 lines **does** have two, with `e_shstrndx = 16` and
`sh_link = 15`. Both are conforming: the specification says section names come
from the table named by `e_shstrndx` and never says that table must be
distinct from `.strtab` or be called `.shstrtab`.

**So the rule is an index, not a name** -- and a reader that looks for
`.shstrtab` works on one of the two most common producers on Earth and fails on
the other, with empty names rather than an error. `obj-sections` and
`obj-strings` were corrected to teach this, and the exercise each one built on
the false claim was rewritten, because the original could not be completed.

Also corrected in passing: finding 22's "16 entries in demo_elf.o" (it is 15,
and the last is `.symtab`; `.shstrtab` simply has no section header of its
own).

## Not established, still

- **No three-format crosscheck harness in the COFF/JVM sense.** What exists is
  `crosscheck.py`, which is stronger in one way (three tiers, and Tier 3 needs
  no second implementation) and weaker in another (it covers this course's
  specimens, not the whole format). Recorded rather than implied.
- **No Mach-O linker and no AArch64 linker on this machine.** Mach-O claims
  rest on LLVM 21 plus hand-decoding; the AArch64 pairing was verified by
  encoding a value and having an independent disassembler read it back, not by
  linking. Both concepts state which is which.
- **No independent AArch64 producer.** The AArch64 findings rest on clang
  alone, unchanged from the original research.
- **`hand.o` is x86-64 only.** The header and every table are architecture
  independent, and `e_machine` is a single field, but the four `.text` bytes
  and the three relocations are not, and nothing here has been linked on
  AArch64 because there is no linker here to link with.

### 50. `demo_coff.o` is not byte-reproducible, and the reason is one field

`build_samples.sh` ends with a `cmp` proving `demo_elf.o` rebuilds
byte-identically, which is what lets the course say "these exact bytes are
these exact claims". **COFF cannot do that, and the reason is a single 4-byte
field: the file header's `TimeDateStamp` at offset 4.**

Measured: a rebuild changes **3 bytes**, all inside that field
(`0x6ab7c0eb` -> `0x6ab81f5b`). Every structural field is identical --
`Machine = 0x8664`, `NumberOfSections = 7`, `PointerToSymbolTable = 0x211`,
`NumberOfSymbols = 26`, `OptionalHeaderSize = 0`.

No claim is affected, and it is worth being precise about why rather than
asserting it: the concepts quote the `.text` data at `0x12c`, the `.text`
relocations at `0x16a`, and the symbol table at `0x211`, and **none of those
is the timestamp.** So the course is safe, and the reproducibility claim is
weakened for COFF in a specific, checkable way rather than globally.

This is a good illustration of the general rule the course teaches: a
"byte-exact" claim is only as good as knowing **which** bytes the claim is
about. A harness that compared whole files would report a false failure here,
and a reader who assumed reproducibility would assume the wrong thing in the
other direction.
