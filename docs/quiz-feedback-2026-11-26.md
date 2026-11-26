# ELF per-option feedback - 2026-11-26 (Agent E)

## Scope and measured gap

This pass completes checklist item **2.2.37**: per-option quiz feedback for the
21 remaining ELF concept pages (`elf-identification` ... `execution`, six
options each). The three Module 1 concepts (`bytes`, `binary-representation`,
`file-layout`) had already been done under 2.2.36.

**Measured baseline disagrees with the task brief.** The brief says 90 of 144
options already carried `data-explain` and 54 were missing, three per concept
in 21 concepts. The checklist item itself says "remaining 126 options across
21 concepts", and direct HTTP measurement on 9000, 9001 and 9002 found
**18 of 144 with `data-explain` and 126 missing (21 concepts x 6 options)** on
all three servers. This pass fixed all **126** measured gaps; the served result
is now 144 of 144 explained. The difference is recorded rather than explained
away: no explanation was written to satisfy a count, only to cover an option
that was actually missing one.

## Source rule actually applied

Every explanation was written **only from that lesson's own verified text** -
its paragraphs, field tables, worked example, or the wording of the already
correct option. No byte value, offset, relocation formula, spec claim or
historical fact was introduced. Where a distractor had no distinct
justification in the lesson, the feedback compares it with the lesson's own
worked example or with the correct option and names only facts present there.
The table below gives a `file:line` reference and a short quote for each of the
126 explanations so a reviewer can audit them without re-deriving them.

Renderer behaviour: `tools/elf_quiz_feedback.py` (2.2.35) had already changed
ELF's local `checkQuiz` to read `data-explain` in **both** branches. The served
script on 9003 contains both reads, so no JS, CSS or markup change was needed;
the 126 attributes were added in `#html` as `data-explain="..."` on the
existing `.quiz-option` buttons.

## Source evidence (126 explanations)

| Concept | Quiz | Option | Feedback added | Source in the lesson |
|---|---|---|---|---|
| binding.ch | `quiz-b-1` | The linker picks the one with the larger value | The resolution rules say multiple strong definitions produce an error, because STB_GLOBAL must be unique across the program. There is no value comparison. | `binding.ch:68, 76` - Global - Visible to all object files in the link. Must be unique across entire program; Multiple strong definitions = error |
| binding.ch | `quiz-b-1` | The linker reports a "multiple definition" error | The resolution rules state that multiple strong definitions are an error, the multiple definition error named in the why unit. | `binding.ch:45, 76` - Multiple strong definitions = error (multiple definition) |
| binding.ch | `quiz-b-1` | The first one wins silently | That is the rule the lesson gives for multiple weak definitions. Strong GLOBAL definitions must be unique, so two of them are an error. | `binding.ch:68, 76-77` - Multiple weak definitions = pick any (usually first one found) |
| binding.ch | `quiz-b-2` | Weak symbols are faster at runtime | The model says weak is like global but can be overridden by a strong definition. The lesson does not connect binding to runtime speed. | `binding.ch:55, 69` - Weak - Like global, but can be overridden. If a strong (global) definition exists, the weak one is ignored |
| binding.ch | `quiz-b-2` | To provide a default implementation that can be overridden by a strong definition | The model defines weak as overridable, and the resolution order says strong definitions override weak ones; that is a default implementation. | `binding.ch:55, 69, 75` - Strong (GLOBAL) definitions override weak ones |
| binding.ch | `quiz-b-2` | Weak symbols use less memory | Compare with the model: the weak and strong difference is which definition wins at link time, not memory use. | `binding.ch:55, 75` - Weak - Like global, but can be overridden |
| common_sections.ch | `quiz-cs-1` | It contains no data | The lesson's note says .bss takes no space in the file but is zero-filled in memory. It holds uninitialized globals, so saying it contains no data misses the memory side. | `common_sections.ch:54, 85` - .bss - Uninitialized globals (zero-filled at runtime); it takes no space in the file but is zero-filled in memory |
| common_sections.ch | `quiz-cs-1` | It takes no space in the file — zeroed at runtime | The note in the lesson says SHT_NOBITS means it takes no space in the file but is zero-filled in memory. | `common_sections.ch:85` - it takes no space in the file but is zero-filled in memory |
| common_sections.ch | `quiz-cs-1` | It's compressed | Compare with the lesson's note: .bss takes no space in the file and is zero-filled in memory. No compression is described. | `common_sections.ch:85` - it takes no space in the file but is zero-filled in memory |
| common_sections.ch | `quiz-cs-2` | R (read-only) — same as the segment | The table gives .rodata the flag SHF_ALLOC only, and the lesson's answer applies the segment's R permission to it: read-only, same as the segment. | `common_sections.ch:73, 115` - .rodata \| SHT_PROGBITS \| SHF_ALLOC \| Read-only constants |
| common_sections.ch | `quiz-cs-2` | RW (read-write) — data sections are writable | The writable flag belongs to .data (SHF_WRITE), while .rodata has SHF_ALLOC only and is read-only. The lesson's answer keeps the segment's R permission. | `common_sections.ch:73-74, 115` - .data \| SHT_PROGBITS \| SHF_ALLOC + SHF_WRITE |
| common_sections.ch | `quiz-cs-2` | RE (read-execute) — it's code | The executable flag belongs to .text (SHF_EXECINSTR), not .rodata, whose flags are SHF_ALLOC only. The answer here is read-only, like the segment. | `common_sections.ch:72-73, 115` - .text \| SHT_PROGBITS \| SHF_ALLOC + SHF_EXECINSTR |
| dynamic_relocations.ch | `quiz-dr-1` | GLOB_DAT is for functions, JUMP_SLOT is for data | The table lists GLOB_DAT as a global variable address in a GOT entry and JUMP_SLOT as a function address in a PLT/GOT entry with lazy binding. The option swaps them. | `dynamic_relocations.ch:80-81` - GLOB_DAT \| S \| Global variable address (GOT entry); JUMP_SLOT \| S \| Function address (PLT/GOT entry, lazy binding) |
| dynamic_relocations.ch | `quiz-dr-1` | GLOB_DAT resolves at load time (for data references), JUMP_SLOT uses lazy binding (for function calls) | The table and the model put GLOB_DAT with data references at load time and JUMP_SLOT with function calls using lazy binding. | `dynamic_relocations.ch:54-55, 80-81` - .rela.dyn - patch data references; .rela.plt - set up PLT stubs for lazy function binding |
| dynamic_relocations.ch | `quiz-dr-1` | They are identical — just different names | The table gives them different usages, and the model processes .rela.dyn at load time but .rela.plt on first call. | `dynamic_relocations.ch:69-70, 80-81` - .rela.dyn \| Load time; .rela.plt \| First call |
| dynamic_relocations.ch | `quiz-dr-2` | The program won't start | LD_BIND_NOW changes when addresses are resolved; the lesson's answer says the program still starts, with slightly slower startup and a slightly faster first call. | `dynamic_relocations.ch:153` - slightly slower startup but slightly faster first call |
| dynamic_relocations.ch | `quiz-dr-2` | All function addresses are resolved at load time instead of on first call — slightly slower startup but slightly faster first call | The lesson's answer: all function addresses resolve at load time instead of on first call, so startup is slightly slower and the first call slightly faster. | `dynamic_relocations.ch:153` - All function addresses are resolved at load time instead of on first call |
| dynamic_relocations.ch | `quiz-dr-2` | All symbols become hidden | The lesson describes LD_BIND_NOW only as changing when function addresses are resolved, not as changing symbol visibility. | `dynamic_relocations.ch:58, 153` - Most dynamic relocations use lazy binding - function addresses are resolved on first call |
| dynamic_section.ch | `quiz-ds-1` | They list the exported symbols | The tag table assigns DT_SYMTAB to the dynamic symbol table; DT_NEEDED is described as a shared library dependency, one occurrence per library. | `dynamic_section.ch:74, 83` - DT_NEEDED \| 1 \| Shared library dependency; Each occurrence = one library dependency |
| dynamic_section.ch | `quiz-ds-1` | They specify which shared libraries the program depends on | DT_NEEDED is defined in the tag table as a shared library dependency, and the lesson says each occurrence is one dependency. | `dynamic_section.ch:74, 83` - DT_NEEDED - I need this shared library |
| dynamic_section.ch | `quiz-ds-1` | They store the program's entry point | The tag table lists DT_INIT and DT_FINI for initialization and finalization addresses, but no entry-point tag; DT_NEEDED is the dependency entry. | `dynamic_section.ch:74, 80-81` - DT_INIT \| 12 \| Initialization function address; DT_FINI \| 13 \| Finalization function address |
| dynamic_section.ch | `quiz-ds-2` | ld.so will use libfoo.so.4 automatically | The DT_NEEDED value names the library to load; the lesson's answer is that ld.so fails with libfoo.so.3: cannot open shared object file when that name is not found. | `dynamic_section.ch:74, 154` - ld.so will fail to load the program with libfoo.so.3: cannot open shared object file |
| dynamic_section.ch | `quiz-ds-2` | ld.so will fail to load the program with "libfoo.so.3: cannot open shared object file" | The lesson's answer: ld.so fails to load the program with libfoo.so.3: cannot open shared object file. | `dynamic_section.ch:154` - cannot open shared object file |
| dynamic_section.ch | `quiz-ds-2` | The program will crash at runtime | Compare with the lesson's answer: the load fails with a cannot open shared object file error, rather than a crash while the program is running. | `dynamic_section.ch:154` - ld.so will fail to load the program |
| elf_header_fields.ch | `quiz-ehf-1` | e_shoff | The field table lists e_shoff as the section header table offset at byte 40; the loader reads e_phoff at byte 32 instead. | `elf_header_fields.ch:83-84` - e_phoff \| 32 \| 8 \| Program header table offset; e_shoff \| 40 \| 8 \| Section header table offset |
| elf_header_fields.ch | `quiz-ehf-1` | e_phoff | The field table says e_phoff is the program header table offset, at byte 32 in the 64-bit header. | `elf_header_fields.ch:83` - e_phoff \| 32 \| 8 \| Program header table offset |
| elf_header_fields.ch | `quiz-ehf-1` | e_entry | The table gives e_entry at byte 24 as the virtual address of the entry point. It points to code, not to the program header table. | `elf_header_fields.ch:82` - e_entry \| 24 \| 8 \| Virtual address of entry point |
| elf_header_fields.ch | `quiz-ehf-2` | 56 bytes | 56 is e_phentsize, the size of one entry, not the whole table. The lesson's own note multiplies 9 entries by 56 bytes. | `elf_header_fields.ch:87, 146` - e_phentsize \| 54 \| 2 \| Program header entry size (56 for 64-bit); 9 entries x 56 bytes each = 504 bytes total |
| elf_header_fields.ch | `quiz-ehf-2` | 504 bytes | 9 entries times 56 bytes each is 504 bytes, exactly as the lesson's apply note states. | `elf_header_fields.ch:139, 146` - 9 entries x 56 bytes each = 504 bytes total |
| elf_header_fields.ch | `quiz-ehf-2` | 9 bytes | 9 is e_phnum, the number of entries. Each entry is 56 bytes, so the table spans 9 times 56 = 504 bytes, not 9. | `elf_header_fields.ch:88, 146` - e_phnum \| 56 \| 2 \| Number of program header entries |
| elf_identification.ch | `quiz-ei-1` | 01 02 03 04 | The identification array starts with the magic number 7f 45 4c 46 at bytes 0-3. The byte 01 is the class at byte 4, not a magic byte. | `elf_identification.ch:62, 95` - Bytes 0-3: Magic number - 7f 45 4c 46; worked dump starts 7f 45 4c 46 02 01 |
| elf_identification.ch | `quiz-ei-1` | 7f 45 4c 46 | Bytes 0-3 are the magic number, 7f 45 4c 46, which spells .ELF. The worked example starts with exactly these four bytes. | `elf_identification.ch:62, 95` - Magic number - 7f 45 4c 46 (spells .ELF) |
| elf_identification.ch | `quiz-ei-1` | ff fe fd fc | The ID card gives bytes 0-3 as 7f 45 4c 46. The worked dump starts with those bytes; ff fe fd fc is not the magic number shown in this lesson. | `elf_identification.ch:62, 95` - Bytes 0-3: Magic number - 7f 45 4c 46 |
| elf_identification.ch | `quiz-ei-2` | 64-bit, little-endian | Byte 4 is 01, and the lesson says 1 means 32-bit, 2 means 64-bit. The 02 here is byte 5, the data encoding, so the class is still 32-bit. | `elf_identification.ch:63, 134` - Byte 4: Class - 1 = 32-bit, 2 = 64-bit; Byte 4 = 01 means 32-bit |
| elf_identification.ch | `quiz-ei-2` | 32-bit, little-endian | Byte 5 is 02, and the lesson says 1 is little-endian and 2 is big-endian. Compare with the worked 02 01 example, which is 64-bit little-endian. | `elf_identification.ch:64, 99, 134` - Byte 5: Data encoding - 1 = little-endian, 2 = big-endian |
| elf_identification.ch | `quiz-ei-2` | 32-bit, big-endian | The lesson states it directly: byte 4 = 01 means 32-bit and byte 5 = 02 means big-endian. | `elf_identification.ch:134` - Byte 4 = 01 means 32-bit. Byte 5 = 02 means big-endian. |
| entry_point.ch | `quiz-ep-1` | The main() function | The model says e_entry points to the C runtime startup code, which eventually calls main(). The lesson also says the linker sets e_entry from the _start symbol. | `entry_point.ch:60, 66` - For most programs, this points to the C runtime startup code, which eventually calls your main() |
| entry_point.ch | `quiz-ep-1` | The _start / initialization code | The entry point is set by the linker from the _start symbol; the lesson's example places 0x6810 in the initialization code that runs before main(). | `entry_point.ch:66, 78` - The entry point is set by the linker based on the _start symbol |
| entry_point.ch | `quiz-ep-1` | The first instruction of .text | The lesson's example puts the entry point 0x6810 in the .init section, the initialization code that runs before main(), not at the first instruction of .text. | `entry_point.ch:78` - The entry point 0x6810 falls in the .init section - the initialization code that runs before main() |
| entry_point.ch | `quiz-ep-2` | It will crash immediately | Compare with the lesson's answer: it may run but skip initialization (ctors, libc setup). Jumping into .text still reaches code, so the defect described is missing setup, not an instant crash. | `entry_point.ch:103` - It may run but skip initialization (ctors, libc setup) |
| entry_point.ch | `quiz-ep-2` | It may run but skip initialization (ctors, libc setup) | The lesson's answer is that it may run but skip initialization, because _start is the symbol the linker used for the entry point. | `entry_point.ch:66, 103` - The entry point is set by the linker based on the _start symbol |
| entry_point.ch | `quiz-ep-2` | The kernel will refuse to execute it | The kernel jumps to the address stored in e_entry; the lesson describes no check on where that address lies. The consequence it gives is skipped initialization, not refusal. | `entry_point.ch:60, 103` - When the kernel loads an ELF file, it maps the segments into memory and then jumps to the address stored in e_entry |
| execution.ch | `quiz-ex-1` | They're the same function | The startup sequence lists _start before __libc_start_main, which then calls main(argc, argv, envp); the lesson also calls main a callback passed to __libc_start_main. | `execution.ch:31-32, 39, 66` - ld.so calls _start; _start calls __libc_start_main; main() is just a callback |
| execution.ch | `quiz-ex-1` | _start is the ELF entry point (assembly stub) that calls __libc_start_main, which then calls main() — main() is a callback, not the entry point | The lesson's answer: _start is the ELF entry point assembly stub, it calls __libc_start_main, which calls main as a callback. | `execution.ch:49, 32, 39, 66, 117` - _start is the ELF entry point (assembly stub) that calls __libc_start_main, which then calls main() |
| execution.ch | `quiz-ex-1` | main() calls _start | The order is the reverse: ld.so calls _start, which calls __libc_start_main, which calls main. The lesson says _start never returns. | `execution.ch:31-32, 39, 65` - It never returns - __libc_start_main calls exit(), which terminates the process |
| execution.ch | `quiz-ex-2` | The constructor isn't running | The startup sequence says __libc_start_main calls .init_array constructors before main. The lesson's answer explains the missing output with stdout buffering instead. | `execution.ch:37, 128` - Calls .init_array constructors; stdout isn't flushed yet |
| execution.ch | `quiz-ex-2` | stdout isn't flushed yet — constructors run before main, and stdout is line-buffered; if you don't print a newline, the output stays in the buffer until main runs or the program exits | The lesson's answer: constructors run before main, and stdout is line-buffered, so printf without a newline stays in the buffer until main runs or the program exits. | `execution.ch:128` - stdout is line-buffered; if you don't print a newline, the output stays in the buffer |
| execution.ch | `quiz-ex-2` | The kernel runs constructors after main | The startup sequence puts .init_array constructors before main and .fini_array destructors in cleanup after main returns; the constructor comes first. | `execution.ch:37, 43, 128` - Cleanup - Calls atexit() handlers, .fini_array destructors |
| ld_so.ch | `quiz-ld-1` | To specify library search paths | The environment table lists LD_LIBRARY_PATH as the variable for additional search paths. LD_PRELOAD is listed separately as force-loading libraries before all others. | `ld_so.ch:41, 51-52` - LD_LIBRARY_PATH \| Additional library search paths; LD_PRELOAD \| Force-load libraries before all others |
| ld_so.ch | `quiz-ld-1` | To force-load a library before all others, allowing it to override (interpose) symbols in subsequent libraries | The table defines LD_PRELOAD as force-loading libraries before all others; the why unit says this is how symbols are overridden or interposed. | `ld_so.ch:22, 52` - Understanding ld.so explains ... how LD_PRELOAD works |
| ld_so.ch | `quiz-ld-1` | To disable lazy binding | The table assigns disabling lazy binding to LD_BIND_NOW, not LD_PRELOAD. | `ld_so.ch:52-53` - LD_BIND_NOW \| Disable lazy binding (resolve all symbols at load) |
| ld_so.ch | `quiz-ld-2` | The program is corrupted | The lesson's answer points to the library not being installed or not being in the search order; the error text names a shared object file, not a malformed program. | `ld_so.ch:115, 118` - error while loading shared libraries: libfoo.so.3: cannot open shared object file |
| ld_so.ch | `quiz-ld-2` | The library is not installed, or it's installed in a path not in the search order (check LD_LIBRARY_PATH and /etc/ld.so.cache) | The lesson's answer: the library is missing from the system or from the search order, which you inspect with LD_LIBRARY_PATH and /etc/ld.so.cache. | `ld_so.ch:118, 41-44` - check LD_LIBRARY_PATH and /etc/ld.so.cache |
| ld_so.ch | `quiz-ld-2` | Your CPU doesn't support the instruction set | Compare with the lesson's answer: the failure is a library lookup failure, diagnosed with the search order and LD_DEBUG, not an instruction-set check. | `ld_so.ch:81, 118` - The LD_DEBUG output shows the exact search sequence - useful for debugging library not found errors |
| loader.ch | `quiz-kl-1` | Because the kernel always allocates full pages | Compare with the lesson's answer: the reason given is that the MMU operates in pages, and partial pages would waste memory or require special handling. | `loader.ch:104` - The memory management unit (MMU) operates in pages - partial pages would waste memory or require special handling |
| loader.ch | `quiz-kl-1` | The memory management unit (MMU) operates in pages — partial pages would waste memory or require special handling | The lesson's answer: the MMU operates in pages, so partial pages would waste memory or require special handling. | `loader.ch:104` - partial pages would waste memory or require special handling |
| loader.ch | `quiz-kl-1` | Because ELF files must be 4KB-aligned | The lesson says LOAD segments are page-aligned (0x1000 = 4KB) and file and memory offsets may differ. The reason given is the MMU, not a rule about the whole file. | `loader.ch:76, 104` - LOAD segments are page-aligned (0x1000 = 4KB), so the file and memory offsets may differ |
| loader.ch | `quiz-kl-2` | It works fine because the kernel doesn't check permissions | The field list gives the code segment p_flags as PF_R \| PF_X, read-execute with no write, and the lesson's answer says the MMU enforces the page permissions. | `loader.ch:52, 115` - Code segment - p_flags = PF_R \| PF_X (read-execute, no write) |
| loader.ch | `quiz-kl-2` | The program crashes with a segfault — the MMU enforces page permissions and the write triggers a protection fault | The lesson's answer: the MMU enforces page permissions, so a write into a PF_R \| PF_X segment triggers a protection fault and a segfault. | `loader.ch:52, 115` - the MMU enforces page permissions and the write triggers a protection fault |
| loader.ch | `quiz-kl-2` | The kernel silently ignores the write | Compare with the lesson's answer: a protection fault and segfault, not a silently ignored write. | `loader.ch:115` - The program crashes with a segfault |
| memory_layout.ch | `quiz-ml-1` | .bss uses a more efficient encoding | The lesson says .bss has p_filesz = 0 but p_memsz nonzero and the kernel allocates zeroed memory without reading the file. The saving comes from storing no bytes, not an encoding. | `memory_layout.ch:77, 124` - p_filesz = 0 but p_memsz is nonzero. The kernel allocates memory for it but doesn't read from the file |
| memory_layout.ch | `quiz-ml-1` | .bss doesn't store data in the file at all — the kernel allocates zero-filled memory at load time, so p_filesz = 0 but p_memsz is nonzero | The lesson's detail: p_filesz = 0 while p_memsz is nonzero; the kernel allocates zero-initialized memory without reading file bytes, saving file space. | `memory_layout.ch:77, 124` - it's always zero-initialized. This saves file space |
| memory_layout.ch | `quiz-ml-1` | .bss is compressed in the ELF file | The lesson says the kernel does not read from the file for .bss because it is always zero-initialized. There are no compressed bytes to store. | `memory_layout.ch:77` - The kernel allocates memory for it but doesn't read from the file |
| memory_layout.ch | `quiz-ml-2` | In the .text segment (code) | The why unit says a crash at 0x7ffd... is on the stack while 0x55555... is in code. The address in the question starts 0x7ffd. | `memory_layout.ch:22, 135` - When you see a crash at address 0x7ffd..., you know it's on the stack |
| memory_layout.ch | `quiz-ml-2` | On the stack — addresses in the 0x7ffd... range are in the mmap/stack region, far above the code/data segments | The why unit places 0x7ffd... addresses on the stack, and the lesson's answer calls that range the mmap/stack region, far above the code and data segments. | `memory_layout.ch:22, 135` - addresses in the 0x7ffd... range are in the mmap/stack region, far above the code/data segments |
| memory_layout.ch | `quiz-ml-2` | In the .bss segment | The table puts .bss in a PT_LOAD data segment; the lesson's worked address 0x7ffd4a3b2100 is assigned to the stack region instead. | `memory_layout.ch:72, 135` - .bss \| rw- \| PT_LOAD (data segment, memsz larger than filesz) |
| memory_mapping.ch | `quiz-mm-1` | 0x1200 | 0x1200 is the file offset you start from. The lesson's formula subtracts p_offset and adds p_vaddr: 0x1200 - 0x1000 + 0x2000. | `memory_mapping.ch:51, 76` - virtual_address = file_offset - p_offset + p_vaddr |
| memory_mapping.ch | `quiz-mm-1` | 0x2200 | 0x2200 = 0x1200 - 0x1000 + 0x2000, the lesson's own formula applied to p_offset 0x1000 and p_vaddr 0x2000. | `memory_mapping.ch:51, 88` - 0x2200 = 0x1200 - 0x1000 + 0x2000 |
| memory_mapping.ch | `quiz-mm-1` | 0x3200 | The formula adds p_vaddr only once. 0x3200 would add 0x2000 twice; the worked substitution gives 0x2200. | `memory_mapping.ch:51, 88` - 0x2200 = 0x1200 - 0x1000 + 0x2000 |
| memory_mapping.ch | `quiz-mm-2` | The kernel rejects the binary | The lesson's answer is that overlap is allowed and the linker ensures non-overlapping alignments. Rejection is not the behaviour taught here. | `memory_mapping.ch:97` - It's allowed - the linker ensures non-overlapping alignments |
| memory_mapping.ch | `quiz-mm-2` | The second segment overwrites the first | Compare with the lesson's answer: overlap is allowed and the linker ensures non-overlapping alignments; it does not describe a later mapping overwriting an earlier one. | `memory_mapping.ch:97` - It's allowed - the linker ensures non-overlapping alignments |
| memory_mapping.ch | `quiz-mm-2` | It's allowed — the linker ensures non-overlapping alignments | The lesson's answer: this is allowed, because the linker ensures non-overlapping alignments. | `memory_mapping.ch:97` - It's allowed - the linker ensures non-overlapping alignments |
| program_header_table.ch | `quiz-pht-1` | The file is corrupted | The field table defines p_filesz as the size in the file and p_memsz as the size in memory, which may be larger for .bss. A larger memory size is an expected case, not corruption. | `program_header_table.ch:82-83` - p_memsz \| 8 \| Size of segment in memory (may be larger for .bss) |
| program_header_table.ch | `quiz-pht-1` | Extra memory is zero-initialized (like .bss) | The field table says p_memsz may be larger than p_filesz for .bss; the extra memory is zero-initialized. | `program_header_table.ch:83` - Extra memory is zero-initialized (like .bss) |
| program_header_table.ch | `quiz-pht-1` | The segment is compressed | Compare with the field table: p_filesz and p_memsz describe file size and memory size, with the difference explained by .bss. Compression is not part of either description. | `program_header_table.ch:82-83` - p_filesz \| 8 \| Size of segment in the file |
| program_header_table.ch | `quiz-pht-2` | 0x0 — the byte is at offset 0 | p_offset is the file offset where the segment starts, so with p_offset 0x0 the first byte is at file offset 0x0. p_vaddr 0x4000 is where it maps in memory. | `program_header_table.ch:79-80` - p_offset \| File offset where segment starts; p_vaddr \| Virtual address to map to |
| program_header_table.ch | `quiz-pht-2` | 0x4000 — same as the virtual address | 0x4000 is p_vaddr, the virtual address to map to, not a file offset. The question asks for the file offset, which is p_offset = 0x0. | `program_header_table.ch:79-80` - p_vaddr \| 8 \| Virtual address to map to |
| program_header_table.ch | `quiz-pht-2` | It depends on the alignment | The first byte of a segment is at p_offset regardless of alignment; p_align is a separate field described as the alignment requirement. Here p_offset is 0x0. | `program_header_table.ch:79, 84` - p_align \| 8 \| Alignment requirement |
| relocation_entries.ch | `quiz-re-1` | It stores the symbol index | The lesson says r_info packs the symbol index and type; r_addend is a separate field described as an extra adjustment to the final value. | `relocation_entries.ch:55, 73-76` - Addend - An extra adjustment to add to the final value; Symbol: ELF64_R_SYM(info) |
| relocation_entries.ch | `quiz-re-1` | It's an extra constant added to the computed relocation value | The model calls the addend an extra adjustment added to the final value, which is what r_addend holds in Elf64_Rela. | `relocation_entries.ch:55` - Addend - An extra adjustment to add to the final value |
| relocation_entries.ch | `quiz-re-1` | It stores the size of the symbol | Compare with the model: r_addend is the extra adjustment to the final value, not a property of the symbol. | `relocation_entries.ch:53-55` - Offset / Info / Addend - the three parts of a relocation entry |
| relocation_entries.ch | `quiz-re-2` | Rela is smaller | Compare with the lesson's answer: Rela is preferred because the addend lives in the entry, not because the entry is smaller. | `relocation_entries.ch:62-64, 135` - The addend is stored in the relocation entry itself, not pre-patched into the target location |
| relocation_entries.ch | `quiz-re-2` | The addend is stored in the relocation entry itself, not pre-patched into the target location — cleaner for position-independent code | The lesson's answer: the addend is in the relocation entry itself rather than pre-patched into the target, which is cleaner for position-independent code. | `relocation_entries.ch:135` - cleaner for position-independent code |
| relocation_entries.ch | `quiz-re-2` | Rel supports more relocation types | The lesson's two structures differ in where the addend is stored; it gives no difference in supported relocation types. | `relocation_entries.ch:62-64, 135` - Elf64_Rel (without addend, rarely used) |
| relocation_types.ch | `quiz-rt-1` | S + A (absolute address) | The formula table gives S + A to R_X86_64_64, the absolute data reference. PLT32 is listed separately as L + A - P. | `relocation_types.ch:67, 69` - R_X86_64_64 \| 1 \| S + A; R_X86_64_PLT32 \| 4 \| L + A - P |
| relocation_types.ch | `quiz-rt-1` | L + A - P (PLT entry address minus current position) | The table lists R_X86_64_PLT32 with formula L + A - P, where L is the PLT entry address and P is the place being patched. | `relocation_types.ch:69, 78-79` - L = PLT entry address (for PLT32); P = Place (offset being patched) |
| relocation_types.ch | `quiz-rt-1` | G + GOT + A - P (GOT entry address) | That is the table's formula for R_X86_64_GOTPCRELX, which targets a GOT entry. PLT32 uses the PLT entry address L instead. | `relocation_types.ch:69-70` - R_X86_64_GOTPCRELX \| 41 \| G + GOT + A - P |
| relocation_types.ch | `quiz-rt-2` | GOTPCRELX is faster | The lesson's answer names relaxation and support for data and code references; it does not claim a raw speed advantage. | `relocation_types.ch:140` - GOTPCRELX allows the linker to optimize to direct calls when possible (relaxation), and works with both data and code references |
| relocation_types.ch | `quiz-rt-2` | GOTPCRELX allows the linker to optimize to direct calls when possible (relaxation), and works with both data and code references | The lesson's answer: GOTPCRELX lets the linker relax to direct calls when possible and works with both data and code references. | `relocation_types.ch:140` - allows the linker to optimize to direct calls when possible (relaxation) |
| relocation_types.ch | `quiz-rt-2` | PLT32 doesn't support 64-bit addresses | The table describes PLT32 as a 32-bit PC-relative call via the PLT; the difference taught here is relaxation and reference kinds, not address width. | `relocation_types.ch:69, 140` - R_X86_64_PLT32 \| 4 \| L + A - P \| 32-bit PC-relative via PLT (function calls) |
| section_header_table.ch | `quiz-sht-1` | The file offset | The field table lists sh_offset as the file offset and sh_addr as the virtual address, 0 when not loaded. Those are two different fields. | `section_header_table.ch:64-65` - sh_addr \| 8 \| Virtual address (0 if not loaded); sh_offset \| 8 \| File offset |
| section_header_table.ch | `quiz-sht-1` | The virtual address in memory | The field table defines sh_addr as the virtual address in memory, 0 when the section is not loaded. | `section_header_table.ch:64` - sh_addr \| 8 \| Virtual address (0 if not loaded) |
| section_header_table.ch | `quiz-sht-1` | The section size | The table gives sh_size as the section size in bytes. sh_addr is the virtual address, a different field. | `section_header_table.ch:64, 66` - sh_size \| 8 \| Section size in bytes |
| section_header_table.ch | `quiz-sht-2` | 0x200 (512 bytes) | sh_size is the section size in bytes, so 0x200 is 512 bytes. sh_offset only says where the section starts in the file. | `section_header_table.ch:65-66` - sh_offset \| 8 \| File offset; sh_size \| 8 \| Section size in bytes |
| section_header_table.ch | `quiz-sht-2` | 0x1000 (4096 bytes) | 0x1000 is sh_offset, the starting file offset, not the number of bytes. The size field is sh_size = 0x200. | `section_header_table.ch:65-66` - A section has sh_offset=0x1000 and sh_size=0x200 |
| section_header_table.ch | `quiz-sht-2` | 0x1200 | 0x1200 would be offset plus size, an end position, not the byte count the question asks for. The table gives the byte count as sh_size = 0x200. | `section_header_table.ch:65-66` - sh_size \| 8 \| Section size in bytes |
| section_vs_segment.ch | `quiz-svs-1` | Yes — debugging sections like .symtab are not in any LOAD segment | The lesson's note says sections like .symtab, .strtab and .debug_* are not loaded into memory and have no corresponding segment. | `section_vs_segment.ch:103` - Sections like .symtab, .strtab, and .debug_* are not loaded into memory - they have no corresponding segment |
| section_vs_segment.ch | `quiz-svs-1` | No — every section must be in a segment | The table says sections are defined by the section header table and used by tools, while segments are defined by the program header table for the loader. The note gives .symtab as a section with no segment. | `section_vs_segment.ch:65-66, 103` - Defined by \| Section header table \| Program header table |
| section_vs_segment.ch | `quiz-svs-1` | Only .bss can exist without a segment | Compare with the note: it names .symtab, .strtab and .debug_*, not .bss, as sections with no corresponding segment. | `section_vs_segment.ch:103` - Sections like .symtab, .strtab, and .debug_* are not loaded into memory |
| section_vs_segment.ch | `quiz-svs-2` | strip — removes .symtab and .strtab sections | strip removes the .symtab and .strtab sections, which the lesson lists as sections rather than segments; that is the section-header change the question asks for. | `section_vs_segment.ch:56-57, 110` - strip - removes .symtab and .strtab sections |
| section_vs_segment.ch | `quiz-svs-2` | ld — relinks the segments | The table says the loader uses segments, so relinking rebuilds segments - the opposite of the section-only change requested. The lesson's answer is strip. | `section_vs_segment.ch:66, 110-111` - ld - relinks the segments |
| section_vs_segment.ch | `quiz-svs-2` | objcopy — copies and modifies segments | Compare with the lesson's answer: strip removes .symtab and .strtab sections. The option describes changing segments, which the question explicitly rules out. | `section_vs_segment.ch:110-112` - strip - removes .symtab and .strtab sections |
| segment_types.ch | `quiz-st-1` | PT_DYNAMIC | The segment-type table says PT_DYNAMIC carries dynamic linking information, while PT_INTERP is the path to the interpreter, that is, the dynamic linker. | `segment_types.ch:79-80` - PT_DYNAMIC \| 2 \| Dynamic linking information; PT_INTERP \| 3 \| Path to interpreter (dynamic linker) |
| segment_types.ch | `quiz-st-1` | PT_INTERP | The table gives PT_INTERP as the path to the interpreter (dynamic linker), and the model calls it the path to the dynamic linker. | `segment_types.ch:64, 80` - PT_INTERP - This is the path to the dynamic linker |
| segment_types.ch | `quiz-st-1` | PT_LOAD | The table describes PT_LOAD as a loadable segment mapped into memory. It is PT_INTERP that holds the path to the interpreter. | `segment_types.ch:78, 80` - PT_LOAD \| 1 \| Loadable segment - mapped into memory |
| segment_types.ch | `quiz-st-2` | 1 — they're all mapped together | The model labels each PT_LOAD a load this into memory instruction, and the lesson's answer counts 3 for 3 PT_LOAD segments. They are separate mappings, not one. | `segment_types.ch:62, 124` - PT_LOAD - Load this into memory (code, data, BSS) |
| segment_types.ch | `quiz-st-2` | 3 — each PT_LOAD becomes a separate mmap region | Each PT_LOAD is its own load instruction, so 3 PT_LOAD segments become 3 separate mapped regions, as the lesson's answer states. | `segment_types.ch:62, 124` - 3 - each PT_LOAD becomes a separate mmap region |
| segment_types.ch | `quiz-st-2` | It depends on the page size | Compare with the lesson's answer: 3 PT_LOAD segments map as 3 regions. p_align is a separate field and the question only counts PT_LOAD entries. | `segment_types.ch:62, 124` - 3 PT_LOAD segments -> 3 memory regions |
| shared_libraries.ch | `quiz-sl-1` | To make the file system faster | The lesson explains the three names as a way to update a library without breaking programs linked against the soname; filesystem speed is not mentioned. | `shared_libraries.ch:57` - This three-level naming lets you update a library ... without breaking programs linked against soname |
| shared_libraries.ch | `quiz-sl-1` | To support backward-compatible upgrades: new versions can be installed alongside old ones without breaking existing programs | The lesson says the three-level naming lets you bump 1.2.3 to 1.2.4 without breaking programs linked against libfoo.so.1. | `shared_libraries.ch:53-57` - Real name libfoo.so.1.2.3; Soname libfoo.so.1; Linker name libfoo.so |
| shared_libraries.ch | `quiz-sl-1` | It's just a convention with no practical benefit | The benefit is stated explicitly: updating the real name leaves programs linked against the soname working. | `shared_libraries.ch:57` - without breaking programs linked against soname libfoo.so.1 |
| shared_libraries.ch | `quiz-sl-2` | Yes, always recompile | Programs record the soname in their .dynamic section, and the lesson says the symlink can be repointed to the new real name so existing programs use it automatically. | `shared_libraries.ch:77, 142` - the linker reads the soname from the library and stores it in your program's .dynamic section |
| shared_libraries.ch | `quiz-sl-2` | No — update the libfoo.so.1 symlink to point to 1.2.4, and existing programs will use the new version automatically | The lesson's own answer: update the libfoo.so.1 symlink to 1.2.4 and existing programs use the new version without recompiling. | `shared_libraries.ch:142` - update the libfoo.so.1 symlink to point to 1.2.4, and existing programs will use the new version automatically |
| shared_libraries.ch | `quiz-sl-2` | Only if the ABI changed | Compare with the worked example: the lesson answers that repointing the libfoo.so.1 symlink is enough for this 1.2.3 to 1.2.4 upgrade; it gives no ABI-change condition there. | `shared_libraries.ch:57, 142` - bump 1.2.3 to 1.2.4 without breaking programs linked against soname |
| symbol_table.ch | `quiz-st-1` | .symtab is for dynamic linking, .dynsym is for static linking | The table assigns .symtab to the static linker and debugger, and .dynsym to ld.so. The option reverses those two users. | `symbol_table.ch:70-71` - .symtab \| Full symbol table (all symbols) \| Static linker, debugger; .dynsym \| Dynamic symbols \| Dynamic linker (ld.so) |
| symbol_table.ch | `quiz-st-1` | .symtab has all symbols, .dynsym has only those needed for dynamic linking | The table says .symtab is the full symbol table and .dynsym holds only symbols needed for dynamic linking. | `symbol_table.ch:70-71` - .symtab has all symbols, .dynsym has only those needed for dynamic linking |
| symbol_table.ch | `quiz-st-1` | They are identical — .dynsym is just a backup | The table gives them different purposes and different users: .symtab for the static linker and debugger, .dynsym for ld.so. | `symbol_table.ch:70-71` - .dynsym \| SHT_DYNSYM \| Dynamic symbols (exported/imported only) |
| symbol_table.ch | `quiz-st-2` | The symbol is corrupted | The field table says st_shndx 0 means undefined, and the worked nm output reads U as undefined, imported from another library. That is a normal import, not corruption. | `symbol_table.ch:83, 114` - st_shndx \| Section index (0 = undefined); U means undefined (imported from another library) |
| symbol_table.ch | `quiz-st-2` | The symbol is defined in another object file or library (it is an import) | st_shndx = 0 is SHN_UNDEF; the field table calls it undefined and the worked output reads U as imported from another library. | `symbol_table.ch:83, 114` - If a symbol has st_shndx = SHN_UNDEF (0) ... it is an import |
| symbol_table.ch | `quiz-st-2` | The symbol is at address 0 | Address or offset is st_value, a separate field; st_shndx is the section index, and 0 means undefined. Compare with the U entry in the worked output. | `symbol_table.ch:83-84, 114` - st_value \| Symbol value (address or offset) |
| visibility.ch | `quiz-v-1` | The symbol is available everywhere but marked as internal | The table gives HIDDEN as not exported and unresolvable by the dynamic linker from other modules; INTERNAL is a separate visibility with its own row. | `visibility.ch:69-70` - Internal \| STV_INTERNAL \| local to the module; Hidden \| STV_HIDDEN \| not exported |
| visibility.ch | `quiz-v-1` | The symbol is not exported — other shared libraries cannot resolve it | The table describes STV_HIDDEN as not exported, with the dynamic linker unable to resolve it from other modules. | `visibility.ch:70` - Hidden \| STV_HIDDEN \| 2 \| Symbol is not exported |
| visibility.ch | `quiz-v-1` | The symbol is stripped from the binary | The table describes HIDDEN as a value in st_other that makes the symbol not exported. It says nothing about removing the symbol from the binary. | `visibility.ch:62, 70` - Visibility is stored in the low 2 bits of st_other |
| visibility.ch | `quiz-v-2` | Protected symbols are smaller in the binary | The table defines PROTECTED as exported but resolved to the local definition, so no interposition. Size is not part of that description. | `visibility.ch:71` - Protected \| STV_PROTECTED \| 3 \| Exported but references within the module resolve to the local definition (no interposition) |
| visibility.ch | `quiz-v-2` | To prevent interposition — ensure calls within the library always resolve to the local definition, even if LD_PRELOAD defines the same symbol | The table says PROTECTED is exported but references within the module resolve to the local definition; the default row names LD_PRELOAD interposition. | `visibility.ch:68, 71` - Default \| STV_DEFAULT \| 0 \| Symbol is exported. Dynamic linker can interpose it (LD_PRELOAD) |
| visibility.ch | `quiz-v-2` | Protected symbols load faster | Compare with the table: the difference between DEFAULT and PROTECTED is interposition, not startup time. | `visibility.ch:68, 71` - Protected ... (no interposition) |


## Verification - commands and results

Build (compiler exit 0; only pre-existing warnings from shared libraries):

```
cd D:\Programming\Wiqis\Web\underlayer
& 'D:\Programming\Chemical\chemical\cmake-build-debug\TCCCompiler.exe' `
  chemical.mod -o build/underlayer-feedback.exe -bm-modules --no-cache
```

Server on 9003, with a copy of the database, PID 37428, left running:

```
Copy-Item underlayer.db underlayer-feedback-9003.db -Force
$env:PORT='9003'; $env:DATABASE_URL='./underlayer-feedback-9003.db'; $env:COURSES_DIR='./courses'
Start-Process build/underlayer-feedback.exe -WorkingDirectory <repo root> -PassThru -WindowStyle Hidden
```

Endpoints (all HTTP 200):

```
GET /api/health                                  -> 200 (36 bytes)
GET /courses/elf/lessons/bytes                   -> 200 (122546 bytes)
GET /api/courses/elf/lessons/bytes/units         -> 200 (786 bytes)
```

Checkers:

```
py -3 tools/elf_feedback_check.py http://localhost:9001
  elf_feedback_check: FAIL - 126 of 144 options missing data-explain across 24 lessons;
                      0 fetch errors; 0 JS branch failures   (exit 1, baseline)
py -3 tools/elf_feedback_check.py http://localhost:9003
  elf_feedback_check: PASS - all 144 options in 24 lessons have non-empty data-explain;
                      both checkQuiz branches consume it      (exit 0)
py -3 tools/journey_quality_check.py http://localhost:9003 --workers 8
  RESULT: 68 passed, 0 failed, 68 total                       (exit 0)
py -3 tools/lesson_pager_check.py http://localhost:9003
  lesson_pager_check: ALL 35 CHECKS PASSED                    (exit 0)
```

Real browser (Chrome/CDP on 9003, `elf-identification`, real mouse click on a
`.quiz-option` after opening Deep dive):

- Wrong option `01 02 03 04` in `quiz-ei-1` produced, in `#quiz-ei-1
  .quiz-feedback`: **"Not quite. The identification array starts with the magic
  number 7f 45 4c 46 at bytes 0-3. The byte 01 is the class at byte 4, not a
  magic byte."**
- Correct option `32-bit, big-endian` in `quiz-ei-2` produced: **"Correct. The
  lesson states it directly: byte 4 = 01 means 32-bit and byte 5 = 02 means
  big-endian."**
- Screenshot: `build/elf-feedback-wrong.png` (generated, untracked). The CDP tab
  created for this check was closed afterwards; the other agent's 9004 tab was
  left active and untouched.

## Deliberately left alone

- No change to `checkQuiz`, the quiz CSS, or the verdict prefix. "Not quite."
  and the existing colour styling predate this pass (2.2.35); rewriting them is
  a platform-wide tone decision, not a content fix. The added text itself
  contains no shaming or verdict words.
- No other course, no `journey_*.ch`, no landing pages, no ownership files of
  the other agent (`course_landing.ch`, `journey_quality_check.py`), and no
  files outside this pass: `tools/theme_check.py`, `tools/checker_nonvacuity.py`,
  `.github/`, the Android repo.
- `courses/elf/src/main.ch` defines no `checkQuiz`, so it needed no edit.
  Generated `courses/*/output/` files remain untracked and untouched; the
  backend patcher is what serves the corrected attributes on 9003.
- The TestEnv suite was not run: `AGENTS.md` records a known compiler/harness
  blocker for `tests/chemical.mod`. Verification here is the endpoint matrix,
  the three checkers and the real browser click above.
- Servers 9000, 9001 and 9002 were left running; `underlayer-feedback-9003.db`
  is a local copy and is not committed.

## Follow-ups

- The brief's 54/90 count should be re-measured by whoever recorded it; the
  served reality on this machine is 126/18 and is now 0/144.
- Regenerating static `courses/elf/output` with `bash scripts/build_static.sh
  elf` remains necessary for GitHub Pages / `file://` copies (pre-existing gap,
  recorded in `SKILL.md`); this pass only changed the committed source.
