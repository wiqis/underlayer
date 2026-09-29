// The x86-64 Data Path — Concept 3: AVX-512, the width this machine cannot run
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_avx512() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("AVX-512: ZMM, k0-k7, and a Decoder That Needs No Silicon — Underlayer")
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
                    <button onclick="closeShortcuts()" class="a11y-close">Close</button>
                </div>
            </div>
            <div class="reading-controls">
                <label>Font: <select id="font-size" onchange="setFontSize(this.value)"><option value="small">Small</option><option value="medium" selected>Medium</option><option value="large">Large</option></select></label>
                <label>Spacing: <select id="line-height" onchange="setLineHeight(this.value)"><option value="compact">Compact</option><option value="normal" selected>Normal</option><option value="relaxed">Relaxed</option></select></label>
                <label>Letters: <select id="letter-spacing" onchange="setLetterSpacing(this.value)"><option value="tight">Tight</option><option value="normal" selected>Normal</option><option value="loose">Loose</option></select></label>
                <label>Width: <select id="content-width" onchange="setContentWidth(this.value)"><option value="narrow">Narrow</option><option value="normal" selected>Normal</option><option value="wide">Wide</option></select></label>
            </div>
            <h1>AVX-512: ZMM, k0-k7, and a Decoder That Needs No Silicon</h1>
            <div class="lesson-meta">26 min &middot; <a href="/courses/x86simd">The x86-64 Data Path</a></div>

            <div class="unit unit-why">
                <h2>Why this matters, and why this page is different</h2>
                <p>Every other page in this course reports numbers. This one reports, in most places, that a number <strong>could not be taken</strong> &mdash; and that turns out to be the most useful thing on it, because knowing <em>which</em> claims about a feature you cannot run are still safe to repeat is a skill, and it is not the same skill as knowing the feature.</p>
                <p>The evidence is eight bits long and they are all zero:</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/AVX512F/,/hi16_zmm 0/p'
  CPUID.7.0:EBX AVX512F 0 DQ 0 CD 0 BW 0 VL 0
  XCR0 0x0000000000000207  (1 x87, 2 SSE, 5 opmask, 6 zmm_hi256, 7 hi16_zmm)
  XCR0 opmask 0  zmm_hi256 0  hi16_zmm 0
                </pre>
                </div>
                <p>Five feature bits and three state bits, and every one of them is zero. So this concept is <strong>reference plus a decoder</strong>, and the decoder is the interesting part: it works on bytes, and bytes do not need a processor to run on. The distinction is worth stating precisely, because the two are confused constantly:</p>
                <div class="formula">
   A DECODER AND A BENCHMARK ARE
   DIFFERENT INSTRUMENTS, and the
   difference is not subtle.

   A DECODER     reads bytes and names
                 the instruction.  Needs
                 a CPU to run on and
                 NOTHING ELSE.  It is
                 correct or it is not.

   A BENCHMARK   runs the instruction
                 and times it.  Needs the
                 exact microarchitecture the
                 claim is about.

   This file has the first and not the
   second.  A decoder that works on bytes
   is a decoder; it is not a benchmark.
            </div>
            </div>

            <div class="unit unit-model">
                <h2>The model: an eleven-bit prefix and eight mask registers</h2>
                <p>Every AVX-512 instruction starts with the two bytes <code>62</code> and an eleven-bit field layout. Here is the field table, and every row is a thing the VEX prefix could not express at all:</p>
                <div class="formula">
   THE ELEVEN BITS OF AN EVEX PREFIX

   R~ X~ B~    16 more vector registers,
               so zmm0-zmm31
   R~'         a FOURTH bit on ModRM.reg,
               so 32 GPRs
   W           as before, and for the
               float map the packed-double
   v~3..0      the third vector operand,
               as before
   bit 2       a MANDATORY 1, which is
               what makes 62 safe
   p1 p0       the mandatory 66/F2/F3
               prefix, as before
   z           merging (0) versus ZEROING
               (1) the mask-off lanes
   L' L        the length, or the
               rounding mode
   b           broadcast from memory, or
               suppress exceptions
   V~'         a fifth bit on the v operand
   a2 a1 a0    WHICH OF EIGHT MASK
               REGISTERS; 0 means no mask
            </div>
                <p>Two rows of that table carry the whole design, and both are about <em>space</em> rather than about arithmetic.</p>
                <p><strong>The mandatory 1 in bit 2</strong> is what makes the <code>62</code> opcode safe. In 32-bit mode, <code>0x62</code> is the <code>BOUND</code> instruction, which takes a ModRM byte &mdash; and the four bits of an EVEX prefix are precisely the bits that would have been a ModRM byte. Because one of them is <em>required</em> to be 1 and <code>BOUND</code>'s ModRM byte is 16 bits wide, the two encodings can never be confused: a 32-bit program that decodes <code>62</code> as <code>BOUND</code> cannot reach a valid EVEX prefix, and a 64-bit program never sees <code>BOUND</code> at all. <strong>The extension bought 16 more registers by using the one opcode whose old meaning it could safely steal, and it made the theft safe by putting a constant in the stolen instruction's own ModRM byte.</strong></p>
                <p><strong>The <code>L'L</code> pair</strong> is the second, and it is a genuine trap for anyone writing a decoder:</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/THE FOUR LEVELS/,/no L at all/p'
  THE FOUR LEVELS, and the L'L PAIR is the whole of it:
    L'L = 00   no vector length in this instruction
    L'L = 10   128 bit, xmm
    L'L = 11   512 bit, zmm
  and when L'L is 00 the SAME two bits are the ROUNDING CONTROL,
  so a decoder cannot read them as a length without first
  asking whether the instruction has a length.  That is why the
  round trip above has a row with b=1 and no L at all.
                </pre>
                </div>
                <p>Those are four levels, and the two bits that select among them <strong>mean something else entirely</strong> when a particular bit elsewhere in the prefix is set. A decoder that reads <code>L'L</code> as a length without first asking whether the instruction <em>has</em> a length will decode a correct instruction into a wrong one &mdash; legal bytes, different instruction, no trap. That is the same class of bug as the one the previous course's encoder had, and it is why the last concept of this course round-trips its bytes against <code>objdump</code> rather than against a decoder it wrote.</p>
                <p>And the mask registers, which have <strong>no analogue anywhere else in the instruction set</strong>. <code>k0</code>&ndash;<code>k7</code> are not vector registers and not general registers: each is 64 bits, and each bit says whether one <em>lane</em> of the destination takes part. An AVX-512 add can be predicated on a mask for free &mdash; no compare instruction, no branch, no second pass over the data &mdash; because <strong>the mask is an operand of the arithmetic rather than an input to a sequence of it</strong>. Note the <code>z</code> bit in the field table, which is what makes the mask-off lanes either keep their old contents or become zero: a mask alone does not say what happens to the lanes it excludes, and that is a real omission a decoder has to handle.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What is quoted, what is measured, and the two properties that justify all of it</h2>
                <p>Every claim on this page, sorted:</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/WHAT IS QUOTED HERE/,/naming\./p'
    QUOTED  that a ZMM is 512 bits, that k0-k7 are 64 bits, that
            z is merging-versus-zeroing, that b is broadcast
    QUOTED  the four-level hierarchy and its dispatch penalty
    MEASURED the five CPUID bits are zero
    MEASURED the XCR0 state bits are zero
    MEASURED the encoder emits the bytes the SDM says and
            objdump reads them back the same way
  NOT MEASURED  that any of it is FASTER
                </pre>
                </div>
                <p>Six quoted claims, three measured ones, and one absence stated as an absence. The three measured claims are all about <em>absence</em> or about <em>bytes</em>, which is the only kind of claim this machine can support, and saying so is the whole discipline.</p>
                <p>Now the <code>XCR0</code> row, which is subtler than a feature bit and worth its own paragraph. <code>CPUID</code> reports what the <strong>silicon has</strong>. <code>XCR0</code> is a list of <strong>what the OS has agreed to save and restore</strong>, and they are not the same thing: a machine can have the first without the second. This one does not have the first. But the two are worth separating anyway, because the way AVX-512 actually fails is the second way &mdash; <strong>an EVEX-encoded instruction whose own state bit is clear does not run slowly, it does not run at all</strong>, and it raises <code>#UD</code>, which the kernel turns into <code>SIGILL</code> rather than <code>SIGSEGV</code>. That is a different failure from the <code>#GP</code> in the first concept, and a program that only handles <code>SIGSEGV</code> will not catch it.</p>
                <p>The artifact reads <code>XCR0</code> with <code>XGETBV</code> and, in passing, makes an inference worth copying. A direct <code>mov %cr4, %rax</code> to read the gate that guards <code>XGETBV</code> <strong>faults on this machine</strong>, so the bit is not read. It is inferred: <code>XGETBV</code> is <code>#UD</code> without <code>CR4.OSXSAVE</code>, and <code>XGETBV</code> returns, so the bit is set. <em>A probe that answers the question by using the thing in the question beats a probe that reads a bit it is not allowed to read, and it costs one instruction instead of a fault.</em></p>
                <h3>The two properties no other instruction in this course has</h3>
                <p>They are the reasons the extension exists, and both are consequences of the mask register being an operand:</p>
                <ul>
                    <li><strong>The tail disappears.</strong> A 4-wide loop over 66 elements needs a scalar remainder, and <a href="/courses/simd/lessons/simd-reduce">the SIMD course measured that remainder at 1.02&times;</a> &mdash; free, but only because the remainder happened to be short. With a mask register the 66th iteration is <em>the same instruction</em> with two of its four lanes switched off, so there is no second code path at all. The remainder stops being a special case and becomes an ordinary iteration.</li>
                    <li><strong>Broadcast is an operand.</strong> <code>vbroadcastsd ymm0, [rbx]</code> loads one eight-byte value into all four lanes. Those exact bytes are in <a href="/courses/x86simd/lessons/x86-bytes">the encoder's table</a> in the last concept, encoded and decoded, and the dispatch is a <em>field of the instruction</em> rather than a separate load followed by a shuffle.</li>
                </ul>
                <p>Both of those are quoted, and both are the kind of claim that is easy to accept and hard to verify. The tail claim is checkable on a machine with AVX-512 by timing a 66-element loop against a 64-element one, and the interesting part is not the speed &mdash; it is <em>whether the compiler generated one path or two</em>, which is a disassembly question rather than a timing question, and which is answerable on any machine that has the compiler even if it has no AVX-512.</p>
            </div>

            <div class="unit unit-example">
                <h2>Reading a claim you cannot check, responsibly</h2>
                <p>Most reference material about a feature you cannot run is written in the present tense &mdash; &ldquo;AVX-512 executes masked operations in a single pass&rdquo; &mdash; and the present tense is doing work it has not earned. Here is a way to write the same sentences so a reader knows exactly which of them to repeat:</p>
                <div class="hex-dump">
                <pre>   THE THREE VERBS, and they are not
   interchangeable.

   QUOTED      from a specification, and
               checkable against the spec but
               not against hardware you lack.

   MEASURED    on THIS machine, and
               reproduced by a program that
               ships with the course.

   INFERRED    a mechanism attached to a
               duration, with no counter
               behind it.  The most dangerous
               of the three, because it reads
               like the other two.
                </pre>
            </div>
                <p>Apply that to the three claims most often made about AVX-512 on a machine that has none. <em>&ldquo;The k mask removes the scalar tail&rdquo;</em> &mdash; <strong>QUOTED</strong>, and it is a claim about <em>code shape</em> that you can partly check by disassembly. <em>&ldquo;512-bit operations are faster than 256-bit&rdquo;</em> &mdash; <strong>NOT MEASURED HERE</strong>, and on most parts it is <em>false</em> because a wide vector triggers a frequency drop. <em>&ldquo;The dispatch penalty is a few cycles&rdquo;</em> &mdash; <strong>QUOTED</strong>, from the vendor manual, and a number a manual prints for a microarchitecture is a fact about that microarchitecture.</p>
                <p>None of that makes the claims unusable. It makes them <em>attributable</em>, which is a different and more durable property: you can repeat a quoted claim, you can repeat a measured one with a program, and you must repeat an inferred one by saying whose inference it is. <strong>The habit worth taking from a feature you cannot run is not the feature. It is refusing to write a specification sentence in the present tense.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Decode the bytes, on this machine, today.</strong> <code>cd courses/x86simd/assets/samples &amp;&amp; ./build_samples.sh</code>, then read section 6B. <em>(Expect three <code>0x62</code> rows in the encoder's table to round-trip and to be cross-checked against <code>objdump</code> with no hardware involved. This is the one exercise on this page you can actually complete, and it is the reason the course has a decoder at all.)</em></li>
                    <li><strong>Write the <code>L'L</code> bug on purpose.</strong> Take the decoder in the last concept and remove the test for whether the instruction has a length, so <code>L'L</code> is always read as a length. <em>(Expect the <code>b=1</code> row to decode as a 512-bit instruction and <code>objdump</code> to disagree on exactly that row. It is the cleanest demonstration in the course of why a second reader matters: the round trip will still pass, because the encoder and the decoder now share the same wrong assumption, and that is the whole content of retraction 9.)</em></li>
                    <li><strong>Count the dispatch penalty you cannot measure.</strong> Find a Skylake-SP or a Zen 4 and time the same loop at 128, 256 and 512 bits. <em>(Expect the 512-bit case to be <em>slower</em> than 256 on most parts, and expect the reason to be a frequency drop rather than a throughput one &mdash; a wide vector makes the core draw more power per cycle, and the core responds by running slower for a window of milliseconds. If you do not see that, check whether your loop is short enough to fit entirely inside the frequency transition, which is the usual reason a benchmark fails to see it.)</em></li>
                    <li><strong>Test the <code>#UD</code> hypothesis without AVX-512.</strong> Find a kernel old enough not to enable the state bits on a machine that has them. <em>(Expect an <code>SIGILL</code> rather than a <code>SIGSEGV</code>, and expect this to be the mechanism behind a class of bug reports that say &ldquo;crashes on the new server, fine on the old one&rdquo; with no further detail. The feature is present in the silicon and absent in the kernel&rsquo;s promise, and the difference between the two is exactly one bit in one register that the failing process cannot read.)</em></li>
                    <li><strong>Find out whether your compiler emits one path or two for a tail.</strong> Write a loop over 66 doubles with <code>-mavx512f</code> and disassemble. <em>(Expect a masked final iteration rather than a scalar one, and expect it to be one of the few places where reading the disassembly teaches you something no amount of running the program will. The tail is a <em>code shape</em>, and code shape is the one property of a vectoriser that is directly observable from the outside.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/x86simd/lessons/x86-avx">the previous concept</a> measured the two things VEX changed, and this one is the same exercise at a width that cannot be run. The <code>L'L</code> pair is a direct descendant of the operand-map problem <a href="/courses/x86asm/lessons/x86-map">the assembly course's map concept</a> found and fixed: the encoding has a field whose meaning depends on another field, and a decoder that ignores the dependency produces a legal instruction that is not the one intended.</p>
                <p>Forwards, and this is the hinge of the course. Everything from here on is about <em>two cores at once</em>, and the connection is not thematic but mechanical: <a href="/courses/smp/lessons/smp-atomic">the SMP course</a> measured that a data race costs a great deal and named the store buffer as the mechanism, and the next two concepts give the x86-64 instructions that address it. What this page contributes is a boundary: it is the one place in the collection where a whole feature's claims are demoted, and knowing that a demoted claim is still a claim you may repeat with attribution is the transferable part.</p>
                <p>Outward. The <code>62</code> prefix is a beautiful piece of backward-compatible design &mdash; stealing an opcode and making the theft provably safe with a constant bit &mdash; and it is the same technique the 32-bit <code>BOUND</code> instruction was stolen <em>from</em>. A reader who wants the wider pattern should look at how <code>VEX</code> stole <code>0f</code> space in the first place, which is in <a href="/courses/x86asm/lessons/x86-vex">the VEX concept</a>, and at how <a href="/courses/smp/lessons/smp-ordering">the ordering course</a> uses the same table of opcodes to reason about fences. Both are the same lesson at different scales: <strong>an encoding is a namespace, and every extension is a negotiation with the decoder.</strong></p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86simd/lessons/x86-avx">AVX and AVX2: Three Operands, vzeroupper, and the Upper Half</a></span>
                <span>Next: <a href="/courses/x86simd/lessons/x86-atomics">The Atomic Set: Which Instructions Imply LOCK</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
