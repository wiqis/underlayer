// AArch64: Encoding From The Ground Up -- pre-rendered HTML pages.
//
// One difference from the other course modules, and it is deliberate: this
// one has NO timing section and no cycle anywhere.  There is no AArch64
// machine on the build host and no emulator, so every number in the course is
// a bit pattern, a count of bit patterns, an arithmetic identity, or a
// refusal from a real assembler.  The artifact (assets/samples/a64dec.py)
// prints that in its own header and in section 1, and section 15 lists what
// the file therefore cannot show.  A course that quietly implied a runtime
// measurement it did not take would be the exact failure this collection
// exists to name.

application a64asm_course

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
