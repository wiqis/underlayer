// The AArch64 Procedure Call Standard -- pre-rendered HTML pages.
//
// One difference from most of the other course modules, and it is the same one
// a64asm has and it is deliberate: this one has NO timing section and no cycle
// anywhere.  There is no AArch64 machine on the build host, no AArch64
// emulator and no AArch64 linker, so not one instruction in this course has
// been run and every number on every page is a BIT PATTERN, a COUNT of bit
// patterns, an ARITHMETIC IDENTITY over the immediates a compiler emitted, or a
// REFUSAL FROM A REAL ASSEMBLER.  The artifact
// (assets/samples/a64abi.py) prints that in its own header and in section 1
// BEFORE the first measurement, and section 12 lists what the file therefore
// cannot show.  The x86-64 ABI course in the previous section measured a 4.92x
// and a 27.65x; this course fakes no counterpart for either, and the only
// cross-architecture comparison it makes -- compile-time instruction counts --
// says in every table that it is a compile-time count.

application a64abi_course

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
