// The x86-64 Data Path — Concept 6: the artifact, thirty encodings
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_bytes() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Thirty Encodings, Round-Tripped and Cross-Checked — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
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
                    <button onclick="closeShortcuts()" class="a11y-close">Close</button>
                </div>
            </div>
            <div class="reading-controls">
                <label>Font: <select id="font-size" onchange="setFontSize(this.value)"><option value="small">Small</option><option value="medium" selected>Medium</option><option value="large">Large</option></select></label>
                <label>Spacing: <select id="line-height" onchange="setLineHeight(this.value)"><option value="compact">Compact</option><option value="normal" selected>Normal</option><option value="relaxed">Relaxed</option></select></label>
                <label>Letters: <select id="letter-spacing" onchange="setLetterSpacing(this.value)"><option value="tight">Tight</option><option value="normal" selected>Normal</option><option value="loose">Loose</option></select></label>
                <label>Width: <select id="content-width" onchange="setContentWidth(this.value)"><option value="narrow">Narrow</option><option value="normal" selected>Normal</option><option value="wide">Wide</option></select></label>
            </div>
            <h1>Thirty Encodings, Round-Tripped and Cross-Checked</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/x86simd">The x86-64 Data Path</a></div>

            <div class="unit unit-why">
                <h2>Why this concept is the course</h2>
                <p>Everything in the five previous pages is a measurement of the hardware. This one measures <em>the artifact that measured the hardware</em>, and it is here because of a specific failure: <strong>the first encoder in this course round-tripped 28 of 28 and was wrong.</strong></p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/WHY A SECOND READER/,/proves it\./p'
  WHY A SECOND READER IS NOT OPTIONAL, and this file is the
  argument.  The first encoder in this course round-tripped
  28 of 28 and was WRONG: it wrote the two-byte VEX with the
  three-byte field order, and a decoder built from the same
  wrong table agreed with it perfectly.  A round trip is a
  tautology and it certified a broken encoder.  R9.
                </pre>
            </div>
                <p>Twenty-eight out of twenty-eight, and the encoder was emitting <strong>legal bytes for a different instruction</strong> &mdash; which is the worst kind of wrong. There is no trap to catch it, because the bytes are valid; there is no length to be surprised by, because the length is right. Every test that compares a thing to itself passes, and the only test that would have caught it is one that brings in a reader nobody on the project wrote.</p>
                <p>So this concept builds three readers instead of one: an encoder, a decoder, and <code>objdump</code>. The first two are written from the same table and are therefore a <em>consistency check</em>. The third was not written from that table by anybody on this project and is therefore a <em>check</em>. The difference between those two words is the entire content of this page.</p>
            </div>

            <div class="unit unit-model">
                <h2>Thirty cases, and three numbers that are not the same claim</h2>
                <p>The encoder emits its own bytes to a flat binary, the build script assembles that binary verbatim, and <code>objdump -D -b binary</code> disassembles it. That means the second reader is reading <strong>bytes this file produced</strong>, not bytes someone typed. Here is the table &mdash; nine legacy rows, seventeen VEX, four EVEX:</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/^  MAP  | addps/,/^  MAP  | vpxor/p'
  MAP  | addps xmm0,xmm1                  | 0f 58 c1 | roundtrip | objdump agrees
  MAP  | addpd xmm0,xmm1                  | 66 0f 58 c1 | roundtrip | objdump agrees
  MAP  | movaps xmm0,xmm1                 | 0f 28 c1 | roundtrip | objdump agrees
  MAP  | movups xmm0,xmm1                 | 0f 10 c1 | roundtrip | objdump agrees
  MAP  | movdqa xmm0,xmm1                 | 66 0f 6f c1 | roundtrip | objdump agrees
  MAP  | movdqu xmm0,xmm1                 | f3 0f 6f c1 | roundtrip | objdump agrees
  MAP  | pxor xmm0,xmm1                   | 66 0f ef c1 | roundtrip | objdump agrees
  MAP  | mulps xmm0,xmm1                  | 0f 59 c1 | roundtrip | objdump agrees
  MAP  | addps xmm0,[rbx]                 | 0f 58 03 | roundtrip | objdump agrees
  MAP  | vaddps xmm2,xmm1,xmm0            | c5 f0 58 d0 | roundtrip | objdump agrees
  MAP  | vaddps ymm2,ymm1,ymm0            | c5 f4 58 d0 | roundtrip | objdump agrees
  MAP  | vaddpd ymm2,ymm1,ymm0            | c5 f5 58 d0 | roundtrip | objdump agrees
  MAP  | vaddps ymm10,ymm0,ymm0           | c5 7c 58 d0 | roundtrip | objdump agrees
  MAP  | vmovaps ymm0,[rbx]               | c5 fc 28 03 | roundtrip | objdump agrees
  MAP  | vaddps zmm0,zmm1,zmm2            | 62 f1 74 48 58 c2 | roundtrip | objdump agrees
  MAP  | vaddps zmm0{k2},zmm1,zmm2        | 62 f1 74 4a 58 c2 | roundtrip | objdump agrees
  MAP  | vaddps zmm0,zmm1,zmm2{ru-sae}    | 62 f1 74 58 58 c2 | roundtrip | objdump agrees

  30 cases, 30 round-tripped, 30 cross-checked against
  objdump, 0 disagreed.
                </pre>
            </div>
                <p>Three numbers, and the artifact is explicit that they are not the same claim:</p>
                <div class="formula">
   THE THREE NUMBERS ARE NOT THE SAME CLAIM.

   "round-tripped"     the encoder and the
                       decoder agree with each
                       other.  NECESSARY and NOT
                       SUFFICIENT.  Two readers
                       built from one table will
                       agree whether or not the
                       table is right.

   "objdump agrees"    an implementation that
                       was NOT written from this
                       table read the same bytes
                       and named the same
                       instruction.  This is the
                       claim worth making.

   "0 disagreed"       a count, and the only one
                       of the three that would
                       change if the second
                       reader were the thing
                       that was broken.
            </div>
                <p>That last row is the one that is easy to miss and it is where the most instructive failure in this course lives. <strong>The first version of the cross-check reported 28 <em>disagreements</em> out of 30, and the file reported them as evidence that the encoder was broken.</strong> The encoder was perfect. The <em>reader of the disassembly</em> was off by one row: <code>objdump</code> prints a section header before the first instruction, that line has no mnemonic in it, and the loader counted it as row 0. Every row was then compared against its <strong>neighbour&rsquo;s</strong> text &mdash; and the two rows that reported agreement did so only because both of them happen to be <code>vaddps</code>.</p>
                <div class="formula">
   THE LESSON, and it is worth more
   than the thirty bytes.

   A cross-check that DISAGREES with
   almost everything is as SUSPICIOUS as
   one that AGREES with everything.

   The two failure modes a misaimed check
   can have -- all-disagree and all-agree
   -- look nothing like each other and are
   EQUALLY WRONG.  The only reason this one
   was caught is that the number was
   checked against what a CORRECT run looks
   like, and not against whether it felt
   right.
            </div>
                <p>And the structural fix, which is the kind of thing worth copying: <strong>the loader now prints how many lines it skipped</strong>, and the harness asserts the counts.</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | grep 'vecmaps_dis.txt'
  vecmaps_dis.txt                    loaded, 30 rows  (1 header, 290 padding skipped)
                </pre>
            </div>
                <p>One header, 290 padding lines, thirty instructions. A harness that only checked &ldquo;thirty rows loaded&rdquo; would pass the broken loader, because both loaders read thirty lines. <em>Asserting the shape of the input is what makes the parse checkable</em>, and the same discipline is in the alignment probe, where the build script disassembles the probe bodies and the harness asserts the mnemonics are present &mdash; because a probe the compiler deleted also returns cleanly.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What the second reader found that the first could not</h2>
                <p>Three bugs, and all three had the same signature:</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/AND THE CROSS-CHECK IS WHAT FOUND/,/surprised by\./p'
  AND THE CROSS-CHECK IS WHAT FOUND THE THREE BUGS that the
  round trip could not: the two-byte VEX field order, the
  inversion of R and X and B, and the fact that the L bit
  is TWO bits wide in EVEX and one in VEX.  All three
  produced LEGAL BYTES for A DIFFERENT INSTRUCTION, which
  is the worst kind of wrong: there is no trap to catch it
  and no length to be surprised by.
                </pre>
            </div>
                <ul>
                    <li><strong>The two-byte VEX field order.</strong> <code>C5</code> is followed by <code>R~ vvvv L pp</code>, and the first version wrote them in the order the three-byte form uses. Same bits, different assignment &mdash; and a decoder built from the same wrong table read it back perfectly.</li>
                    <li><strong>The inversion of R, X and B.</strong> Those three bits are <em>inverted</em> in the encoding: a <code>0</code> means &ldquo;extend to the full register set&rdquo; and a <code>1</code> means &ldquo;this is the last register&rdquo;. The encoder wrote them the right way up. <code>vaddps xmm2, xmm1, xmm0</code> came out as an instruction on different registers, which is a <a href="/courses/x86abi/lessons/x86-verify">silent wrong answer</a> of the worst kind: the code assembled, ran, and computed on the wrong data.</li>
                    <li><strong>The L bit is two bits wide in EVEX and one in VEX.</strong> And when <code>L'L = 00</code> those same two bits are the <em>rounding control</em> instead, which is why the table has a row with a broadcast bit and no length at all. A decoder that reads <code>L'L</code> as a length without first asking whether the instruction <em>has</em> a length decodes a correct instruction into a wrong one &mdash; and <a href="/courses/x86simd/lessons/x86-avx512">the AVX-512 concept</a> is entirely about this one field.</li>
                </ul>
                <p>And one more that is not a bug but a fact nobody had written down: <strong>the operand map</strong>. In a three-operand instruction the fields are</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/THE OPERAND MAP/,/R10 is that mistake/p'
  THE OPERAND MAP, which is not in any of the tables above and
  which this file established by assembling three distinct
  registers and reading which field each landed in:
      Intel 'vaddps DEST, SRC1, SRC2'
        ModRM.reg = DEST   vvvv = SRC1   ModRM.rm = SRC2
  A reader who assumes the GPR convention -- r/m is always the
  destination -- will mis-decode every three-operand instruction
  in the set.  R10 is that mistake, caught by the assembler.
                </pre>
            </div>
                <p>That map is not in any specification table, because it is not a property of the encoding &mdash; it is a property of <em>which register you named</em>. So it cannot be looked up, and the only trustworthy way to learn it is to assemble three distinct registers and read which field each landed in, which is a five-line experiment. <a href="/courses/x86asm/lessons/x86-map">The assembly course&rsquo;s map concept</a> established the general form; this file re-derived it because a table you did not derive yourself is a table you cannot check.</p>
            </div>

            <div class="unit unit-example">
                <h2>Twenty-four retractions, sorted, and the one that took three attempts</h2>
                <p>Every retraction in the course is printed by the artifact and asserted as text by the harness, so a taken-back claim can be neither quietly dropped nor edited into being right. Sorted by what kind of mistake each one is:</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/AND THE ONES THAT ARE NOT ABOUT/,/ends on\./p'
  AND THE ONES THAT ARE NOT ABOUT THE ARCHITECTURE AT ALL
  are R8, R11, R16, R17, R19, R21, R23 and R24, and they
  are the eight a reader should take away from this
  course: every one of them is a measurement that was
  WRONG about the machine and RIGHT about its own
  instrument.  Six of the twenty-four are mistakes about
  what a NUMBER is (R2, R4, R18, R19, R20 and R22),
  SEVEN are about what an INSTRUMENT is (R3, R8, R11,
  R16, R21, R23 and R24), three are about what an
  ENCODING is (R9, R10 and R15), and the rest are about
  what a BINARY contains or what a SPECIFICATION says.
  Not one of the twenty-four is a mistake about how a
  computer works, and that is the argument the course
  ends on.
                </pre>
            </div>
                <p><strong>Not one of the twenty-four is a mistake about how a computer works.</strong> Six are mistakes about what a number is (a <code>lock dec</code> reported non-atomic because the expectation was wrong, <code>btc</code> reported exact because the instrument could not read it). Seven are mistakes about what an instrument is &mdash; a probe the compiler deleted, a static array the compiler folded, a thread id that was never used, a section header counted as an instruction. Three are mistakes about what an encoding is. And <strong>the eight that are not about the architecture at all are the eight worth taking away</strong>, because every one of them is a measurement that was wrong about the machine and right about its own instrument.</p>
                <p>Which brings us to the one that took three attempts, and it is the best story in the course because <strong>the tell was visible the whole time and the file printed it without objecting.</strong></p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/R24\. /,/should have been SMALLER/p'
  R24. "The arm labelled 'store to my line, then load the
        peer's' is a two-thread ping-pong."  RETRACTED, and it
        took THREE attempts to fix, which is why it is here at
        that length.
        ONE.  The body took a THREAD ID and never used it
        TWO.  Indexing by id was not enough...  aligned(64)
        is not a promise about the elements; it is a promise
        about the object.
        THREE.  The fix is a STRIDE: a line is 64 bytes and a
        uint64_t is 8, so each thread gets a row of eight.
        THE TELL, and it is the part worth keeping: the
        store-only floor came out ABOVE the ping-pong in every
        run.  That is impossible for a floor, and this file
        PRINTED THE RATIO instead of treating it as a
        contradiction of its own vocabulary.  A row's NAME is a
        claim about what the row did, and a name is not
        evidence.
                </pre>
            </div>
                <p>Three bugs, and the first two produced numbers that looked entirely reasonable. <code>aligned(64)</code> on a two-element array aligns the <em>array</em>, not each element, so the two threads&rsquo; words were still eight bytes apart in one cache line &mdash; and the experiment that was supposed to show that two separate lines are cheaper than one shared line was in fact measuring the shared line twice. The fix that worked was a <em>stride</em>: eight words per thread, because a line is 64 bytes and a word is 8.</p>
                <p>And the tell. <strong>The store-only floor came out <em>above</em> the thing it was a floor for, in every single run.</strong> That is impossible &mdash; a floor is a lower bound by definition &mdash; and the file printed the ratio rather than treating it as a contradiction of its own vocabulary. The general form is the most useful thing on this page: <em>a number that cannot have come out is the friendliest thing an experiment ever does, and the only way to deserve it is to hold a claim that says the number should have been <strong>smaller</strong></em>. A test that says &ldquo;faster&rdquo; passes when the instrument is broken; a test that says &ldquo;slower&rdquo; fails, and hands you the instrument.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce the whole thing.</strong> <code>cd courses/x86simd/assets/samples &amp;&amp; ./build_samples.sh</code>. <em>(Expect 266 checks, 30 rows with <code>objdump agrees</code> on every one, and a build that runs the artifact three times and cross-checks a fourth. The recorded <code>vecdump.out</code> ships with the course precisely so that the harness is runnable on a machine that never ran the benchmark &mdash; a course whose claims can only be checked by first rebuilding its own artifact is a course whose claims are only verifiable on the machine that wrote them.)</em></li>
                    <li><strong>Break the cross-check on purpose.</strong> This is the completion criterion. Delete the header-skip in <code>load_dis()</code> in <code>vecmaps.c</code> so <code>objdump</code>&rsquo;s section header is counted as row 0 again. <em>(Expect group I to report 28 disagreements out of 30 for an encoder that is entirely correct, and expect the two rows that still agree to be the two that both happen to be <code>vaddps</code>. Then restore it and watch it go back to 30. If your breakage produces all-agree instead, you have removed the wrong check &mdash; and that is worth noticing, because it is the other failure mode and it looks <em>better</em>.)</em></li>
                    <li><strong>Break the round trip, and watch it pass.</strong> Swap the R and X bits in the encoder so it writes them the right way up. <em>(Expect the round-trip column to stay at 30 of 30, because the decoder has the same inversion. Then run <code>objdump -D -b binary vecmaps.bin</code> by hand and see the register names come out wrong. This is the cleanest demonstration in the collection of what a tautology looks like from the inside: every test you wrote passes and the program is broken.)</em></li>
                    <li><strong>Reproduce the floor tell.</strong> In <code>vec5.c</code>, change <code>LINE_WORDS</code> from 8 to 2 and rerun. <em>(Expect the layout block to print &ldquo;8 bytes apart (THE SAME LINE)&rdquo; and the store floor to come back out above the ping-pong. Then let the harness run and watch group G fail on the <em>ordering</em> rather than on a number &mdash; which is the shape of a check that is about the claim and not about the digits. Then put it back.)</em></li>
                    <li><strong>Write your own second reader.</strong> Take any encoder you have written, and check it against something you did not write. <em>(Expect the round trip to pass and expect at least one row to disagree, and expect the disagreement to be a field whose meaning you had silently assumed. The class of bug is narrow &mdash; a field that depends on another field, a bit that is inverted, a width that changed between extension and base &mdash; and it is invisible to every test that compares the encoder to itself.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, everything. This concept is the account of the instrument that produced the other five, and the two things it is not are worth naming: it does not measure the hardware, and it does not measure the course. <a href="/courses/x86asm/lessons/x86-map">The assembly course&rsquo;s map concept</a> found the R/X/B inversion that this file re-found from the other direction; <a href="/courses/x86sys/lessons/x86-boundary">the third course&rsquo;s last concept</a> proved that <code>CR4.OSXSAVE</code> is unreadable from ring 3 and this course&rsquo;s third concept infers it; and <a href="/courses/simd/lessons/simd-compiler">the SIMD course&rsquo;s compiler concept</a> is the same class of failure &mdash; a measurement that ran the wrong instruction &mdash; in a place where no disassembler is available to catch it.</p>
                <p>Forwards, and the chain in this section is now complete. The x86-64 data path course was the fourth and last of the four, and it inherits from the first three: the encoding from <code>x86asm</code>, the calling convention from <code>x86abi</code>, the <code>#GP</code> as a signal number from <code>x86sys</code>. What it gives back is the one thing all three needed and none of them could supply: <strong>a second reader.</strong> A decoder that was not written from your table is the only instrument in this collection that has caught a real encoding bug, and it has now caught one in every course in the section that has one.</p>
                <p>Outward. The transferable idea is not about x86 at all, and it is the one every neutral course in this collection is built on: <strong>a test that compares a thing to itself cannot fail in a way that means anything.</strong> Round trips, benchmarks that measure their own overhead, a compiler&rsquo;s vectoriser checked against its own output, a lock-free queue checked against a lock, a course&rsquo;s own diagram checked against its own prose. The second reader is the only defence, it costs one command, and it is skipped exactly when the code looks most finished.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86simd/lessons/x86-order">Ordering: TSO, the Three Fences, and the Direction Flag</a></span>
                <span>End of The x86-64 Data Path &middot; <a href="/courses/x86simd">course index</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
