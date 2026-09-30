// The AArch64 Data Path: NEON, Atomics and Ordering -- pre-rendered HTML
// pages.
//
// One difference from most of the other course modules, and it is the same one
// a64asm, a64abi and a64sys have and it is deliberate: this one has NO timing
// section and no cycle anywhere.  There is no AArch64 machine on the build
// host, no AArch64 emulator and no AArch64 linker, so not one instruction in
// this course has been run and every number on every page is a BIT PATTERN, a
// COUNT of bit patterns, an ARITHMETIC IDENTITY over a field width, or a
// REFUSAL from a real assembler.
//
// The x86-64 sibling of this course measured 3.89x, 4.92x and 27.65x.  This
// course fakes no counterpart for any of the three, and the one place a reader
// would expect a ratio -- section 5's instruction counts -- says in that
// section's own words that it is a COMPILE-TIME INSTRUCTION COUNT AND NOT A
// TIMING ONE, and then measures one that points in the OPPOSITE direction to
// the one a reader expects (34 instructions against 12 for the vectorised
// sum_loop).  The artifact (assets/samples/a64data.py) prints the absence in
// its own header and in section 1 BEFORE the first measurement, prints the
// three labels and the provenance table in section 12, the twenty-seven
// retractions in section 13, and the fourteen limits in section 14.
//
// The CBI imports below are NOT optional.  A chemical.mod that does not
// declare its html_cbi / css_cbi / js_cbi dependency never triggers a CBI
// build, and the #html macro then fails with "couldn't find macro parser" --
// which looks like a broken toolchain and is a missing line in this file.

application a64simd_course

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
