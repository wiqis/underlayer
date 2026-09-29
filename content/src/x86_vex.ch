// x86-64 Assembly and Encoding — Concept 4: the VEX and EVEX prefixes
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_vex() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Two Bytes, Three, and the Bit That Went Wrong — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson">
            <div class="a11y-controls">
                <button class="a11y-btn" onclick="toggleHighContrast()" aria-label="Toggle high contrast">HC</button>
                <button class="a11y-btn" onclick="toggleReducedMotion()" aria-label="Toggle reduced motion">RM</button>
                <button class="a11y-btn" onclick="openShortcuts()" aria-label="Keyboard shortcuts">?</button>
            </div>
            <div class="shortcuts-modal" id="shortcuts-modal">
                <div class="shortcuts-backdrop" onclick="closeShortcuts()"></div>
                <div class="shortcuts-dialog">
                    <h3>Keyboard Shortcuts</h3>
                    <dl>
                        <dt><kbd>Ctrl</kbd>+<kbd>K</kbd></dt><dd>Open search</dd>
                        <dt><kbd>Esc</kbd></dt><dd>Close search / dialog</dd>
                        <dt><kbd>&uarr;</kbd></dt><dd>Back to top</dd>
                    </dl>
                    <button onclick="closeShortcuts()" class="shortcuts-close">Close</button>
                </div>
            </div>
            <div class="reading-controls">
                <label>Font: <select id="font-size" onchange="setFontSize(this.value)"><option value="small">Small</option><option value="medium" selected>Medium</option><option value="large">Large</option></select></label>
                <label>Spacing: <select id="line-height" onchange="setLineHeight(this.value)"><option value="compact">Compact</option><option value="normal" selected>Normal</option><option value="relaxed">Relaxed</option></select></label>
                <label>Letters: <select id="letter-spacing" onchange="setLetterSpacing(this.value)"><option value="tight">Tight</option><option value="normal" selected>Normal</option><option value="loose">Loose</option></select></label>
                <label>Width: <select id="content-width" onchange="setContentWidth(this.value)"><option value="narrow">Narrow</option><option value="normal" selected>Normal</option><option value="wide">Wide</option></select></label>
            </div>
            <h1>Two Bytes, Three, and the Bit That Went Wrong</h1>
            <div class="lesson-meta">26 min &middot; <a href="/courses/x86asm">x86-64 Assembly and Encoding</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p><a href="/courses/isa/lessons/isa-decode">The ISA course</a> taught that you can write <code>0xC4</code> and <code>0xC5</code> in a byte stream and that they change how the rest decodes. <a href="/courses/isa/lessons/isa-modes">The modes concept</a> told you that <code>0x62</code> is <code>BOUND</code> in 32-bit mode and <code>EVEX</code> in 64-bit. That is the whole of what the collection says about these three bytes, and it is the whole of what anybody can say about them by <em>recognising</em> them.</p>
                <p>What the collection does not say, anywhere, is <strong>what is inside them</strong>. And the answer is a story about an instruction set that ran out of room, told in a way that is legible from the bytes alone &mdash; and the first thing that story does is contradict the most widely repeated sentence ever written about VEX.</p>
                <div class="hex-dump">
                <pre>$ objdump -d -M intel corpus.o | grep -A1 'vex2_vaddps_ymm'
0000000000000023 &lt;vex2_vaddps_ymm&gt;:
  23:	c5 fc 58 ca    vaddps ymm1,ymm0,ymm2
  </pre>
                </div>
                <p><strong>Two bytes.</strong> <code>c5</code>, one more byte, and the 256-bit register is named perfectly well, because <code>L</code> is bit 2 of that one byte. The sentence &ldquo;the three-byte VEX form exists because the two-byte form cannot encode 256-bit registers&rdquo; is false, it appears in a great deal of documentation, and it was in the first draft of this page.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: four encodings, four jobs, one idea</h2>
                <p>Every byte below came out of the assembler in <code>corpus.s</code>, or out of a hand-built string this course decoded, and every one of them is checked against a second reader &mdash; GNU objdump 2.46 &mdash; that was not written by the same hand.</p>
                <div class="hex-dump">
                <pre>$ ./x86dec | sed -n '/4A\.  LEGACY/,/4B\./p' | head -20
  bytes: 0f 58 c1
        0f 58   the escape: `0f` moves the opcode into the
                 TWO-BYTE map, and 58 is `addps` inside it.
                 The same 58 in the ONE-byte map is
                 `pop r/m64`, which is the collision the
                 neutral course uses 0x62 for.
        c1      ModRM = 11 000 001:
                 mod = 11      no displacement, no SIB
                 reg = 000     xmm0
                 rm  = 001     xmm1
                 THERE ARE TWO SLOTS AND THAT IS ALL.  The
                 destination is reg, the source is rm, and
                 reg is OVERWRITTEN.  There is no third
                 operand and no way to name one.
  </pre>
                </div>
                <p>Two operand slots, one of which is destroyed. That is the whole reason <code>a = b + c</code> cannot be written in the legacy encoding without a copy, and it is the reason <code>blendvps</code> is more interesting than it looks:</p>
                <div class="hex-dump">
                <pre>  bytes: 66 0f 38 14 d1
        66       the pp field of a VEX byte in its old costume
        0f 38    a SECOND escape, the SSE4 map
        14       blendvps
        d1       11 010 001 = reg xmm2, rm xmm1

  and a FOURTH operand that is not in the bytes at all:

        blendvps %xmm0, %xmm1, %xmm2

  The implicit slot is xmm0.  It is not encoded, so objdump,
  a human and a decoder all have to know it separately.  That
  is the thing the VEX vvvv field removed.
  </pre>
                </div>
                <h3>The two-byte VEX, which is the clever one</h3>
                <div class="hex-dump">
                <pre>  bytes: c5 f8 58 ca
        c5       identifies the TWO-byte VEX form
        f8       = 1 111 1 0 00
                 bit 7   R      inverted; ALWAYS 1 here, which
                                 is a whole register's worth
                                 of information thrown away
                 bits 6-3 vvvv   INVERTED register number:
                                 1111 -&gt; 0, so xmm0.  THIS
                                 IS THE SECOND OPERAND, and
                                 it is the one the legacy
                                 encoding does not have.
                 bit 2   L      0 = 128 bits, 1 = 256 bits
                 bits 1-0 pp     00 none, 01 = the 0x66
                                 prefix, 10 = 0xF3, 11 = 0xF2.
                                 THIS IS THE THIRD OPERAND,
                                 folded into one field.
        ca       ModRM: reg = xmm0 (destination), rm = xmm2
        58       the opcode, vaddps.  The mnemonic grew a `v`
                 and the 0f and the 0x66 both disappeared
                 into the escape and into pp.
  </pre>
                </div>
                <p>Read that field list twice, because the compression is the point. <strong>The legacy encoding spent three separate mechanisms on what VEX spends one byte on:</strong> the <code>0f</code> escape to reach the two-byte map, a mandatory <code>0x66</code> to select single rather than double, a hard-coded <code>xmm0</code> slot, and a rule that reg is both a source and the destination. VEX makes the escape a prefix, puts the map and the operand width and the third operand into two fields, and makes the destination a third field. <strong>That is why VEX instructions are one byte shorter than the legacy ones for the same operation</strong>, which is not a coincidence and not a compression scheme &mdash; it is a different set of questions being asked of two bits.</p>
                <h3>And the three-byte form, which is for the register file running out</h3>
                <div class="hex-dump">
                <pre>  THE TWO-BYTE FORM CANNOT REACH xmm8 AND UP.  vvvv is four
  INVERTED bits and that is the whole of it, and R is pinned to
  1.  So when the register file grew past eight, one more bit was
  needed for each of three operands and there was no room left:

     c4 41 38 58 ca    vaddps xmm9,xmm8,xmm10
     c4 41 3c 58 ca    vaddps ymm9,ymm8,ymm10

     c4 41        = 0 1 0 0 0 0 0 1
                   R  X  B  mmmmm
                   0 1 0   00001 = the 0f map
  </pre>
                </div>
                <p>And the second reason, which is the one nobody quotes, because the mnemonic looks like an ordinary two-operand one:</p>
                <div class="hex-dump">
                <pre>     c4 e3 79 0f ca 0f    vpalignr xmm1,xmm0,xmm2,0xf

  A FOURTH OPERAND.  vvvv holds 4 bits, rm holds 4, and a
  fourth operand would have to go in the 3-bit pp field.
  There is no room for it there either -- and the immediate
  has nowhere to live except after the ModRM.

  and the imm8 is there, at the end, because the VEX byte
  freed the space that the 0f and the 66 used to occupy.
  </pre>
                </div>
                <p>So the three-byte form is for <strong>four register numbers instead of three, and for the instructions that have a fourth operand or an immediate</strong>. Both of those are the same problem: the two-byte form ran out of fields, and the only way to add a field is to add a byte.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: EVEX, which this machine cannot run</h2>
                <p>There is no AVX-512 on this part, and no assembler here will emit an AVX-512 instruction. So the bytes below were <strong>built by hand</strong> and then handed to three instruments that have never met the author: a decoder that does not care what the CPU supports, a disassembler, and the CPU itself.</p>
                <div class="hex-dump">
                <pre>  bytes: 62 f1 7c 48 58 ca     hand-assembled, no assembler on this
                                     machine produced it

        62       identifies EVEX.  The neutral ISA course has
                 met this byte: it is BOUND in 32-bit mode and
                 EVEX in 64-bit, and that collision is the only
                 thing it said about it.
        f1       = 1 1 1 1 0 0 00001
                 bits 7-4  R X B R'  inverted, all 1 = no
                                      register extension used
                 bits 3-2  00       RESERVED.  Must be zero,
                                      or the instruction is
                                      #UD.  Two bits that MUST
                                      be a constant are two
                                      bits the ISA has run out
                                      of names for.
                 bits 1-0  mmmmm   WHICH MAP.  01 = 0f,
                                  10 = 0f 38, 11 = 0f 3a.
                                  THE MAP STOPPED BEING A
                                  TWO-BYTE ACCIDENT AND
                                  BECAME A FIELD.
        7c       = 0 1111 1 00
                 bit 7   W      the REX.W analogue
                 bits 6-3 vvvv   inverted, 1111 -&gt; zmm0
                 bit 2   always 1, and a #UD if it is not
                 bits 1-0 pp     00 = packed SINGLE,
                                  01 = packed DOUBLE
        48       = 0 10 0 1 000
                 bit 7   z      ZEROING.  The destination is
                                  CLEARED rather than merged,
                                  so a masked-off lane is 0
                                  and not whatever was there.
                 bits 6-5 L'L    11 = 512, 10 = 256, 01 = 128.
                                  TWO bits, because the 2-bit
                                  VEX L could not express 512.
                 bit 4   b      broadcast (memory) or {er}
                 bit 3   V'     inverted, and a #UD if it is
                                  not 1 -- like bits 3-2 of
                                  byte 1, a field that must be
                                  a constant
                 bits 2-0 aaa    the MASK REGISTER, k0 to k7
        58 ca    the same opcode and the same ModRM as the
                 legacy form.  That is the design: the opcode
                 is still the opcode, and a decoder written
                 for 0f 58 with an escape in front of it keeps
                 working.
  </pre>
                </div>
                <p>And then the three instruments, all correct, all saying something different:</p>
                <div class="hex-dump">
                <pre>$ ./x86dec | sed -n '/EXECUTED on this machine/,+2p'
        EXECUTED on this machine, in a forked child: killed by signal 4.

$ objdump -D -b binary -m i386:x86-64 -M intel evex.bin
   0:	62 f1 7c 48 58 ca    	vaddps zmm1,zmm0,zmm2
  </pre>
                </div>
                <p><strong>Three readers, three answers, and the disagreement is the lesson.</strong> The hand-built bytes are a well-formed instruction; objdump names it correctly and does not care that this silicon has never heard of it; the CPU raises <code>#UD</code> and the child dies with signal 4. <em>A decoder that works on bytes and a decoder that works on what the silicon implements are different instruments</em>, and a course about instruction encoding needs both, because the day you write a linker or a disassembler the bytes are the only thing you have.</p>
                <p>And one bit of one byte changes what the instruction is, which is the sharpest thing in the field:</p>
                <div class="hex-dump">
                <pre>  62 f1 7c 48 58 ca   vaddps  zmm1, zmm0, zmm2
  62 f1 7c 4a 58 ca   vaddps  zmm1{k2}, zmm0, zmm2      aaa = 010
  62 f1 7c 58 58 ca   vaddps  zmm1, zmm0, zmm2{ru-sae}  b   = 1

  (the first two lines are what binutils printed for these exact
   bytes, and it is a SECOND reader agreeing with a hand build)

  both of the variants were executed here too, and both died
  the same way: signal 4 and signal 4.
  </pre>
                </div>
                <p>Three of the low bits of byte 4 are a <strong>mask register</strong> &mdash; a per-element predicate for a 512-bit operation, which is a capability with no analogue in any of the other 32-bit architectures in this collection and is the single most interesting thing AVX-512 added. One more bit is <strong>embedded rounding</strong> or <strong>broadcast</strong>, depending on whether the operand is a register or memory, which is a field that means two different things and is documented in two different chapters of the manual.</p>
                <h3>And what the three operands bought, priced</h3>
                <p>Two arms computing the same thing, one iteration at a time, differing only in whether the destination had to be copied first. The artifact checks that they computed the same value and prints it:</p>
                <div class="hex-dump">
                <pre>$ ./x86dec | sed -n '/4D\./,/the interesting number/p'
  vaddps xmm0, xmm0, xmm1   -- 3 operands, no copy        0.662 ticks/op
  movaps + addps           -- 2 operands, copy first      0.662 ticks/op
  movaps + addps + a discarded movd (CONTROL)             0.662 ticks/op

        the two-operand arm returned  0x40000000
        the CONTROL returned           0x40000000
        the three-operand arm returned 0x40000000
        ALL THREE AGREE: 0x40000000, which is 2.0f.
  </pre>
                </div>
                <p><strong>All three arms cost the same to three decimal places</strong> &mdash; 0.662, 0.662, 0.662 ticks per operation &mdash; and the two cheap register-to-register moves the legacy form needs are, on this machine, entirely free. <strong>The copy that the three-operand encoding eliminates bought nothing measurable here at all</strong>, and the encoding is a source-level feature that a duration cannot price. The measurement does not distinguish the two forms; the four-shape LEA sweep two concepts back is the same finding at a different width, and both are the vector course's result one instruction at a time.</p>
                <p>So: <strong>the three-operand VEX form is a source-level feature, not a performance feature.</strong> It lets a compiler write <code>a = b + c</code> without a copy. It costs nothing to buy and nothing to keep, and no duration in this artifact can price it. The mechanism is inferred &mdash; there is no counter here that can count vector-port occupancy &mdash; and the measurement establishes only that there is no <em>large</em> difference.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: writing a decoder that accepts all four</h2>
                <p>If you are building anything that reads instructions &mdash; a disassembler, a tracer, an emulator, a linker that inspects relocations &mdash; this is the decision tree, and the order of the tests is the part that is easy to get wrong.</p>
                <div class="formula">
   1. Is the first byte 0x62?
        In 64-bit mode: EVEX.  Read three more bytes and
        CHECK the two reserved bits and V' -- a decoder that
        ignores them accepts things no CPU will execute.
        In 32-bit mode: BOUND, a completely different
        instruction with a #GP if the limit is bad.
        THE MODE DECIDES.  This is the collision the ISA
        course told you about, and it is the one case where
        "read the byte" is not enough.

   2. Is it 0xC4 or 0xC5?
        VEX.  Read ONE more byte (0xC5) or TWO more (0xC4).
        For 0xC4, byte 1's low five bits are mmmmm and
        they select the map -- 1 = 0f, 2 = 0f 38, 3 = 0f 3a.
        The opcode is the NEXT byte, not the byte after the
        escape, and the ModRM is after that, and then an
        immediate whose SIZE DEPENDS ON THE OPCODE.

   3. Is it a legacy prefix -- 66, F2, F3, 67, or 0f?
        Collect them.  They are not decoration: 66 and the
        pp field are the same two bits, and F3 in front of
        0f 2a is what makes cvtsi2ss rather than cvtsi2sd.

   4. Otherwise it is the one-byte map, and the opcode's low
        three bits tell you the operand width from the
        MNEMONIC'S SUFFIX.  `subl` is 0x29 and `subb` is 0x28
        and the suffix is not decoration, it IS the opcode.

   And the trap in step 2 that this course's own decoder
   fell into: the immediate size is a property of the OPCODE
   and not of the prefix, so a decoder that assumes "VEX means
   no immediate" gets every vpalignr wrong by one byte, and
   a decoder that gets it wrong on ONE byte is wrong on
   every instruction after it in the stream.  The artifact's
   decoder had exactly that bug and the harness caught it by
   comparing lengths against binutils.
                </div>
                <p>One more thing a decoder must decide, and it is a decision a <em>linker</em> also has to make: <strong>an unrecognised byte is not an error in a stream you are scanning past.</strong> Skip it, count it, and report it &mdash; do not stop, and do not guess. The artifact's decoder does exactly that: it has a declared subset, and for the 51 corpus entries outside it it returns &ldquo;not modelled&rdquo; and prints <code>n/a</code> rather than a plausible number. <strong>A decoder that returns a wrong length for an opcode it did not model is worse than one that admits it does not know</strong>, because the wrong length is indistinguishable from a right one downstream and the admission is not.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Assemble the same instruction three ways and count the bytes.</strong> <code>addps %xmm1,%xmm0</code> (legacy, 3 bytes), <code>vaddps %xmm1,%xmm0,%xmm2</code> (VEX-2, 4 bytes), and <code>vpalignr $0x0f,%xmm2,%xmm0,%xmm1</code> (VEX-3, 6 bytes). <em>(Expect the VEX form to be one byte LONGER than the legacy form for the same arithmetic, and the reason to be that it is carrying a third operand and a map selector and a prefix width in two bytes that the legacy form spent on three separate mechanisms. Anyone who tells you VEX is &ldquo;more compact&rdquo; is comparing the wrong two things, and you now have the counter-example in your own build directory.)</em></li>
                    <li><strong>Prove the three-byte form is not for 256-bit, on your own machine.</strong> <code>objdump -d -M intel</code> a file with <code>vaddps %ymm2,%ymm0,%ymm1</code> and one with <code>vaddps %xmm2,%xmm0,%xmm1</code>. <em>(Expect two bytes each, differing in one bit, and that bit to be bit 2 of byte 1. Then compile a function that needs <code>xmm8</code> and watch the encoder reach for <code>0xC4</code> &mdash; which is the moment the design pressure that produced the three-byte form becomes visible in your own object file.)</em></li>
                    <li><strong>Hand-assemble the EVEX bytes yourself and check them against a decoder.</strong> Build <code>62 f1 7c 48 58 ca</code> with a hex editor, run <code>objdump -D -b binary -m i386:x86-64 -M intel</code> over it, and then change byte 4 from <code>0x48</code> to <code>0x4a</code> and do it again. <em>(Expect the first to decode as a 512-bit packed-single add and the second as the same add with a mask register, from three low bits. If your machine has no AVX-512, also execute it in a forked child and watch the SIGILL &mdash; that is a measurement too, and it is the only one of the three that tells you about the silicon rather than about the encoding.)</em></li>
                    <li><strong>Make the artifact's decoder wrong on purpose.</strong> In <code>x86dec.c</code>, delete the <code>imm_bytes</code> lookup from the VEX branch of <code>decode_len</code>. <em>(Expect the <code>vex3_vpalignr</code> and <code>vex3_vperm2f128</code> rows to report a length one byte short, the cross-check in section 4 to print the disagreements by name, and the harness's group F to fail. Then restore it. This is the manifest's completion criterion in miniature and it is worth doing before you believe any of group F.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/isa/lessons/isa-rex">isa-rex</a> has the <code>0x40</code>-<code>0x4F</code> byte whose job VEX absorbed, and <a href="/courses/isa/lessons/isa-modes">isa-modes</a> is where the <code>0x62</code> collision lives. <a href="/courses/isa/lessons/isa-length">isa-length</a> derived the rule this page broke three times: a decoder that miscounts an immediate is wrong by a whole instruction. <a href="/courses/isa/lessons/isa-decode">The ISA course's decoder</a> is the ancestor of the one in this course's artifact and the object of its last concept.</p>
                <p>Forwards, <a href="/courses/x86asm/lessons/x86-map">the map audit</a> is this concept's argument turned into a table: the <code>mmmmm</code> field is the reason, and the audit is 768 slots read twice to show where the room went. <a href="/courses/x86asm/lessons/x86-asm">Back to the first concept</a> if the <code>66</code> byte in <code>addpd</code> stopped making sense two pages ago &mdash; it is the <code>pp</code> field of the byte on this page, and that is the whole of it.</p>
                <p>Outward, and the nearest neighbour is the two courses that follow this one in the section. <a href="/courses/simd/lessons/simd-width">The vector course's width concept</a> measured what XMM-to-YMM-to-ZMM doubling actually costs, and its finding that a loop doing the same work in a quarter of the instructions is not four times faster <strong>is the finding at the end of this page</strong> at a width of one, which is why it is linked here rather than repeated. <a href="/courses/simd/lessons/simd-shapes">Its shapes concept</a> has the lane arithmetic, and the mask register on byte 4 is the same idea with a per-element predicate attached. And the three x86-64 data-path courses that follow this section are entirely about the register file these prefixes are reaching into: <code>ymm8</code>&ndash;<code>ymm15</code> is the eight-register file the two-byte VEX could not name, and that pressure is why the third byte exists.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86asm/lessons/x86-flags">From a Comparison to a Boolean</a></span>
                <span>Next: <a href="/courses/x86asm/lessons/x86-map">The Audit, and the Reader That Agreed With Itself</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
