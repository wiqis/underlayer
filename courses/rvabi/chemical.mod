// RISC-V: The ABI, and the Register That Isn't There -- pre-rendered HTML
// pages.
//
// The difference this module has from every other course module in this
// collection, and it is not a stylistic one: THIS COURSE HAS NO TIMING
// ANYWHERE.  There is no RISC-V machine on the build host, no emulator, and
// no RISC-V binutils -- qemu-riscv64, spike and riscv64-linux-gnu-{gcc,as,ld}
// are all absent.  So every number in the course is a bit pattern, a count
// of bit patterns, an arithmetic identity, or a refusal from a real
// assembler.  The x86-64 ABI course in the first section of this collection
// measured a 4.92x and a 27.65x; this course has NO counterpart for either
// number and does not invent one.  What replaces a ratio is an INSTRUCTION
// COUNT and a BYTE COUNT, and every table that prints one says so in its own
// caption rather than in a limits section at the end.
//
// The artifact (assets/samples/rvabi.py) prints the same three absences
// before its first measurement, in its own header and again in section 1,
// and every concept page carries the statement too.  A course that quietly
// implied a runtime measurement it did not take would be the exact failure
// this collection exists to name -- and this one is the course where the
// temptation is strongest, because the subject IS performance.
//
// The CBI dependencies below are declared rather than assumed.  A
// `chemical.mod` that does not name html_cbi, css_cbi and js_cbi does not
// trigger a CBI build, and the build then fails with "couldn't find macro
// parser for '#html'" -- which reads like a toolchain fault and is a
// manifest fault.  `courses/rvasm/chemical.mod` is the same shape and is the
// worked example.

application rvabi_course

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
