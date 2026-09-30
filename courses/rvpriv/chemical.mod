// The RISC-V Privileged Architecture -- pre-rendered HTML pages.
//
// THE DIFFERENCE THIS MODULE HAS FROM EVERY OTHER COURSE MODULE IN THIS
// COLLECTION IS NOT A STYLISTIC ONE, and it is worth reading before the first
// number: THIS COURSE HAS NO RUNTIME CLAIM OF ANY KIND.  There is no RISC-V
// machine on the build host, no emulator, and not even a RISC-V linker --
// qemu-riscv64, spike and riscv64-linux-gnu-{gcc,as,ld} are all absent.  So
// no exception is taken, no page is walked, no TLB is ever consulted, and no
// `ecall` is observed trapping or returning.  The artifact says so in its own
// header, in section 1, at the end of every affected section, and in a table
// in section 15 rather than in a disclaimer at the end.
//
// That is a weaker position than any other RISC-V course in this section is
// in, and it is a STRENGTHENED one, because the subject is a document and the
// document is exactly what can be quoted and then checked against bytes.  What
// survives the absences is the part a compiler author needs: the twelve CSR
// instruction encodings and the one funct3 bit between them, the CSR address
// arithmetic, the relocation records a page-table walk emits, and the size
// arithmetic of Sv39/Sv48/Sv57.  All of it is a bit pattern, a count of bit
// patterns, an arithmetic identity, or a refusal from a real assembler.
//
// `ecall` is the one place where the temptation to overstate is strongest,
// and it is labelled MEASURED-AS-EMITTED rather than MEASURED wherever it
// appears: the compiler emits the constant 0x00000073 with a7 around it, and
// that is a different claim from "the trap is taken".  The concept page for it
// carries the distinction in its own text rather than in a footnote.
//
// The CBI dependencies below are declared rather than assumed.  A
// `chemical.mod` that does not name html_cbi, css_cbi and js_cbi does not
// trigger a CBI build, and the build then fails with "couldn't find macro
// parser for '#html'" -- which reads like a toolchain fault and is a manifest
// fault.  `courses/rvasm/chemical.mod` is the same shape and is the worked
// example.

application rvpriv_course

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