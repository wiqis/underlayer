// RISC-V Atomics and the Vector Extension -- pre-rendered HTML pages.
//
// THE SPINE OF THIS COURSE IS AN ABSENCE, and it is a THIRD kind of absence.
// The two RISC-V courses before it lost the ability to TIME (`rvabi`) or to
// OBSERVE THE SUBJECT (`rvpriv`).  This one loses the ability to OBSERVE
// WHETHER ANY OF ITS INSTRUCTIONS DOES THE THING IT EXISTS TO DO.  There is no
// RISC-V machine on the build host, no emulator, and not even a RISC-V linker
// -- qemu-riscv64, spike and riscv64-linux-gnu-ld are all absent.  So no
// reservation is ever HELD, no SC is ever observed to succeed or fail, no AMO
// is ever observed to be atomic, no fence is ever observed to order anything,
// and no vector instruction is ever EXECUTED.  The artifact says so in its own
// header, in section 1, at the end of every affected section, and in a table
// rather than in a disclaimer at the end.
//
// THAT IS NOT A WEAKER COURSE THAN ITS TWO SIBLINGS.  It is a course whose
// subject is an ENCODING and a COMPILER'S CHOICE, and those are exactly the
// two things a host without hardware can measure.  An atomic instruction is a
// PROMISE about observable behaviour, and every number here is about the
// promise's TEXT: the bit that carries it, the pair of instructions that
// implements it, the number of bits the encoding has left over, and the
// compiler's decision about whether to emit the instruction at all.
//
// THERE ARE NO TIMINGS AND NO SPEEDUPS ANYWHERE IN THIS COURSE, and that is
// deliberate where `simd` and `smp` measured ratios and `a64simd` measured
// three.  The ratio has no counterpart here and is not invented to fill the
// gap.  What replaces it is an instruction count, a byte count, a bit position,
// and the sentence that a count does not know whether the instruction is fast.
// The three sibling ratios are NAMED in the artifact and explicitly disclaimed,
// because a contrast with an unmeasured number in it is a footnote, and the
// footnote is the part a reader quotes.
//
// `vsetvli` programmes the element width, the register-group count and the
// tail and mask policies AT RUN TIME, which is how one fixed 32-bit encoding
// describes a vector whose length is not in the instruction at all.  That is a
// different DESIGN from a wider register, and it is the reason `rvasm` already
// measured `vsetvli` at four bytes and `zimm[10:8]` as constant zero: this
// course BUILDS ON that and does not repeat it.  The portability cost is the
// tail policy, which the specification declines to make deterministic, and the
// compiler picks the fast one by default -- a choice a reader can only see by
// decoding two bits.
//
// The CBI dependencies below are declared rather than assumed.  A
// `chemical.mod` that does not name html_cbi, css_cbi and js_cbi does not
// trigger a CBI build, and the build then fails with "couldn't find macro
// parser for '#html'" -- which reads like a toolchain fault and is a manifest
// fault.  `courses/rvasm/chemical.mod` is the same shape and is the worked
// example.

application rvat_course

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
