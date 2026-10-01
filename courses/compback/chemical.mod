// Compiler Backend: From IR to Machine Code -- pre-rendered HTML pages.
//
// WHAT THIS MODULE IS FOR, and the position in the chain is the first thing
// worth reading.  `docs/course-mission.md` defines the spine as
//
//     lexing -> parsing -> IR -> codegen -> object files -> linking -> loading
//
// and this collection has taught BOTH ENDS IN DEPTH -- the ELF course, the
// object-format courses, the relocation and linking courses, the dynamic
// linking and image courses, and three whole architecture sections -- while
// the MIDDLE WAS TAUGHT NOWHERE.  This module is the hole being filled.
//
// A DIFFERENT KIND OF COURSE, and the difference is worth naming in the module
// declaration rather than only on a page: THIS IS THE FIRST COURSE IN THE
// COLLECTION WHOSE MACHINE RUNS THE CODE IT MAKES.  x86-64 is native on this
// host, so section 10 of the artifact can put a RATIO on the cost of a spill
// and a ratio on the cost of a schedule.  That single measurement is the one
// that belongs here and nowhere else, and it is why this course exists
// alongside the courses that came before it rather than as a sixth summary of
// them.
//
// AND IT STILL CANNOT EXECUTE AArch64 OR RISC-V.  Both cross-compile; neither
// cross-LINKS (aarch64-linux-gnu-ld and riscv64-linux-gnu-ld are NOT
// INSTALLED) and neither runs (qemu and spike are both ABSENT).  So nothing
// this course emits for those two targets is ever executed and no relocation
// it emits is ever resolved.  That is why every page carries one of exactly
// three labels and there is no fourth:
//
//     MEASURED             about x86-64 code, because it RAN
//     MEASURED-ON-BYTES    about an AArch64 or RISC-V INSTRUCTION, because a
//                          word was emitted and read back and nothing more
//     QUOTED               about what a machine WOULD DO, with a document
//
// A LABEL RENDERED TWO WAYS IS NOT A LABEL, and the reason is mechanical: the
// provenance table in the artifact's section 12 prints a summary line that
// only adds up if the three spellings are used consistently, and
// `tools/verify_compback.py` counts them with word-boundary regexes for the
// same reason `tools/verify_rvpriv.py` does.
//
// LLVM IS THE ORACLE AND NEVER A DEPENDENCY.  The mission says a learner
// finishing this chain should be able to emit machine code for x86-64, AArch64
// and RISC-V without depending on LLVM or any other backend.  So clang is
// read -- what does the best available compiler do with this function at this
// optimisation level -- and compared against an allocator and a scheduler that
// are written here.  The artifact's section 2 prints WHAT REPLACES LLVM BY
// FILE NAME, and the list is the honest shape of the dependency:
//
//     textual IR (parse and print)      cbir.py   (read_llvm_ir)
//     the IR itself                      cbir.py   (Ins, is_reg, simulate)
//     instruction selection              cbir.py   (isel_tree, PATTERNS)
//     register allocation, linear scan   cbreg.py  (alloc_linear_scan)
//     register allocation, colouring     cbreg.py  (alloc_colour)
//     liveness and interference          cbreg.py  (build_interference)
//     spill slots and reloads            cbreg.py  (pack_spill_slots)
//     coalescing                         cbreg.py  (coalesce)
//     instruction scheduling             cbsched.py (build_dag, list_schedule)
//     the ENCODER                        cbenc.py  (enc_a64_madd, enc_x86)
//     the machine we measure on          cbbench.c (the timing instrument)
//
// AND WHAT IS STILL MISSING IS PRINTED RATHER THAN IMPLIED, because the
// sentence a reader is most entitled to is the one that says what the course
// does not do: no SSA construction and no PHI placement, no CFG, no
// dominators, no loop structure, no peepholes, no compressed encodings, no
// exception frames and no debug information.  The IR is straight-line, and the
// reason is in `cbir.py`'s own docstring: instruction selection, allocation
// and scheduling are three questions about a SEQUENCE of operations, and a
// branch would put a fourth question in the middle of them.
//
// The CBI dependencies below are declared rather than assumed.  A
// `chemical.mod` that does not name html_cbi, css_cbi and js_cbi does not
// trigger a CBI build, and the build then fails with "couldn't find macro
// parser for '#html'" -- which reads like a toolchain fault and is a manifest
// fault.  `courses/rvpriv/chemical.mod` is the same shape and is the worked
// example.

application compback_course

source "src"

import std
import cstd
import page
import html_cbi
import css_cbi
import js_cbi
import fs

import "../../content"
import "../../core"
