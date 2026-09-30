// RISC-V: The Encoding Spectrum -- pre-rendered HTML pages.
//
// The difference this module has from the other course modules, and it is
// not a stylistic one: THIS COURSE HAS NO TIMING ANYWHERE.  There is no
// RISC-V machine on the build host, no emulator, and no RISC-V binutils --
// qemu-riscv64, spike and riscv64-linux-gnu-{gcc,as,ld} are all absent.  So
// every number in the course is a bit pattern, a count of bit patterns, an
// arithmetic identity, or a refusal from a real assembler.  The x86-64
// section's speedup ratios have NO counterpart here and are not invented to
// fill the gap.  The artifact (assets/samples/rvdec.py) prints that in its
// own header and again in section 11, where it lists what the file therefore
// cannot show, and every concept page carries the same statement.  A course
// that quietly implied a runtime measurement it did not take would be the
// exact failure this collection exists to name.

application rvasm_course

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
