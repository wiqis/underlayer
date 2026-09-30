// The AArch64 Data Path: NEON, Atomics and Ordering -- Concept 3:
// The Exclusive Monitor, and Why the Retry Is the Instruction.
//
// The page's claim is structural rather than numeric: the store-exclusive
// reports failure IN A REGISTER, the instruction cannot therefore act on it,
// and the only way to act on it is a branch that goes back to the load.  So the
// loop is not an optimisation artefact -- it is forced by the interface.
//
// Its second half is the sharpest measurement in the section, and it is a
// RETRACTION: FEAT_LSE does not use one set of ordering bits for its whole
// group.  CAS uses bits 22 and 15; LDADD uses bits 23 and 22; and bit 21 is a
// constant of the whole group.  The first draft of this course said 22 and 21
// for both, and the cross-check caught it.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_atomic() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Exclusive Monitor, and Why the Retry Is the Instruction — Underlayer")
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
            <h1>The Exclusive Monitor, and Why the Retry Is the Instruction</h1>
            <div class="lesson-meta">26 min &middot; <a href="/courses/a64simd">The AArch64 Data Path: NEON, Atomics and Ordering</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>[QUOTED] <code>LDAXR</code> opens a local monitor on the address, <code>STXR</code> attempts a store under it, and the store reports <strong>success or failure in a register</strong>. The architecture guarantees nothing about when the store fails. A context switch, an exception, a different core writing the same line, a cache eviction, or the store being split can all make it fail, and <strong>there is no encoding that makes it not fail</strong>. (ARM DDI 0597, the pseudocode for the Load-Acquire-Exclusive and Store-Release-Exclusive instruction groups, and the <code>AArch64.ExclusiveMonitorsPass</code> pseudocode functions.)</p>
                <p>The reason that is a <em>loop</em> and not an instruction is therefore structural, and this page measures it rather than asserting it. Here is the chain, and every link is checkable:</p>
                <ol>
                    <li>The failure is reported <strong>in the instruction's own output</strong> — a register.</li>
                    <li>An instruction cannot act on its own output; the only thing it can do is <strong>report</strong> it.</li>
                    <li>Reporting it to a caller who has to <strong>branch</strong> is the definition of a loop.</li>
                    <li>And a branch that goes back to the load <strong>is</strong> the retry.</li>
                </ol>
                <p>The phrase "by construction" in this concept's title is a claim about the <strong>interface</strong>, and the interface is one register wide. That is why FEAT_LSE, when it arrived, had to add a <em>different kind of instruction</em> rather than a faster version of the same one — and concept 3 measures both halves of that.</p>
            </div>

            <div class="unit unit-model">
                <h2>The measurement: acquire is one bit, and it is bit 15</h2>
                <div class="hex-dump">
                <pre>instruction               word         binary                                three bits to read
  ------------------------ ----------- ------------------------------------ ------------------------
  ldxr w1, [x0]            0x885f7c01  10001000010111110111110000000001     o1=0 pair=0 size=2
  ldaxr w1, [x0]           0x885ffc01  10001000010111111111110000000001     o1=1 pair=0 size=2
  ldxr x1, [x0]            0xc85f7c01  11001000010111110111110000000001     o1=0 pair=0 size=3
  ldaxr x1, [x0]           0xc85ffc01  11001000010111111111110000000001     o1=1 pair=0 size=3
  ldxrb w1, [x0]           0x085f7c01  00001000010111110111110000000001     o1=0 pair=0 size=0
  ldaxrh w1, [x0]          0x485ffc01  01001000010111111111110000000001     o1=1 pair=0 size=1
  stxr w2, w1, [x0]        0x88027c01  10001000000000100111110000000001     o1=0 pair=0 size=2
  stlxr w2, w1, [x0]       0x8802fc01  10001000000000101111110000000001     o1=1 pair=0 size=2
  stlxr w2, x1, [x0]       0xc802fc01  11001000000000101111110000000001     o1=1 pair=0 size=3
  ldxp x9, x8, [x0]        0xc87f2009  11001000011111110010000000001001     o1=0 pair=1 size=3
  ldaxp x9, x8, [x0]       0xc87fa009  11001000011111111010000000001001     o1=1 pair=1 size=3
  stlxp w14, w9, w8, [x0]  0x882ea009  10001000001011101010000000001001     o1=1 pair=1 size=2
  clrex                    0xd5033f5f  11010101000000110011111101011111     o1=0 pair=0 size=3

  [MEASURED-ON-BYTES]  the acquire/release bit is BIT 15 and it is
  ONE BIT, and it is the same bit in a load and in a store:
     ldxr w1, [x0]            xor ldaxr w1, [x0]          = 0x00008000  -&gt; bit 15
     stxr w2, w1, [x0]        xor stlxr w2, w1, [x0]      = 0x00008000  -&gt; bit 15
     ldxr x1, [x0]            xor ldaxr x1, [x0]          = 0x00008000  -&gt; bit 15
     ldxp x9, x8, [x0]        xor ldaxp x9, x8, [x0]      = 0x00008000  -&gt; bit 15
     stxp w14, w9, w8, [x0]   xor stlxp w14, w9, w8, [x0] = 0x00008000  -&gt; bit 15
                </pre>
                </div>
                <p>Five XORs, five identical masks, and the bit is <strong>15</strong>. Acquire and release are not separate flags and they are not separate instructions — they are <em>one bit on the access itself</em>, and it is the same bit whether the access is a load, a store, 8 bits wide or 128.</p>
                <p>Now the retraction, and it is the one this page exists for:</p>
                <div class="formula">
   AND BIT 21 IS NOT THE ACQUIRE BIT

   MEASURED over the thirteen words above: bit 21 is 0 in
   EVERY single-register word and 1 in EVERY pair word.  So
   it is the PAIR DISCRIMINATOR.

   A bit that is CONSTANT across the family you are
   describing is the signature of a field you did not mean,
   and that is the cheapest possible test and the one the
   first draft did not run.
                </div>
                <p>And the size is <code>bits[31:30]</code>, two bits, all four values allocated — the same two bits a scalar <code>ldrb</code> writes, spelled <em>twice</em> in the assembly, once as the mnemonic suffix and once as the register width. That is the third time in this course that one field is written twice in the syntax, and it is the sharpest argument here for reading a field once and printing it wherever the assembly happens to want it.</p>
            </div>

            <div class="unit unit-reality">
                <h2>FEAT_LSE: one instruction instead of four — and the bit it moved</h2>
                <p>[QUOTED] FEAT_LSE is armv8.1-a and added compare-and-swap and the atomic memory operations as single instructions. The point is not that the instruction is longer or shorter. The point is that <strong>the loop is gone</strong> — and the loop was not an optimisation artefact, it was forced by the interface above. An architecture that added the feature had to add an instruction whose failure mode is not a register, and that is a <em>different kind of atomic</em> rather than a faster one. (Arm Architecture Reference Manual, FEAT_LSE, and the <code>AArch64.CAS*</code> pseudocode.)</p>
                <p>What is measurable is what the compiler does with the feature. The same C, the same <code>-O2</code>, one flag apart:</p>
                <div class="hex-dump">
                <pre>     cas64     (a 64-bit compare-exchange)
       baseline : ldr x9, [x1] | ldaxr x8, [x0] | cmp x8, x9 | b.ne .LBB12_4
                  | stlxr w10, x2, [x0] | cbnz w10, .LBB12_1
       -march=armv8.1-a:
                  ldr x9, [x1] | mov x8, x9 | casal x8, x2, [x0]
                  | cmp x8, x9 | cset w0, eq | b.eq .LBB12_2
     inc_seq   (a fetch-add)
       baseline : mov x8, x0 | ldaxr x0, [x8] | add x9, x0, #1
                  | stlxr w10, x9, [x8] | cbnz w10, .LBB6_1 | ret
       -march=armv8.1-a:
                  mov w8, #1 | ldaddal x8, x0, [x0] | ret
     xchg_seq  (an exchange)
       baseline : mov x8, x0 | ldaxr x0, [x8] | stlxr w9, x1, [x8]
                  | cbnz w9, .LBB10_1 | ret
       -march=armv8.1-a:
                  swpal x1, x0, [x0] | ret

     FOUR instructions become ONE.  This is a COMPILE-TIME
     INSTRUCTION COUNT, printed as such, and it is the only
     "speedup" this course can print.
                </pre>
                </div>
                <p>And here is the measurement that had to be retracted. The first draft of this course said the LSE group encodes acquire as bit 22 and release as bit 15 in CAS and bit 21 in the LDADD family. <strong>Both halves of the LDADD half are wrong.</strong> Sweeping four suffixes in each half:</p>
                <div class="hex-dump">
                <pre>  [MEASURED-ON-BYTES]  THE GROUP IS NOT ONE GROUP.  In the CAS half
  ACQUIRE IS BIT 22 and RELEASE IS BIT 15; in the LDADD half ACQUIRE
  IS BIT 23 and RELEASE IS BIT 22.  Four suffixes, each half:
     cas  0x88a17c02   casal 0x88e1fc02   xor 0x00408000  -&gt; bits 22 and 15
     casp 0x48207c82  caspal 0x4860fc82  xor 0x00408000  -&gt; bits 22 and 15
     ldadd  0xb8210002  a: 0xb8a10002  xor 0x00800000  -&gt; bit 23
     ldadd  0xb8210002  l: 0xb8610002  xor 0x00400000  -&gt; bit 22
     ldadd  0xb8210002  al:0xb8e10002  xor 0x00c00000  -&gt; bits 23 and 22
     ldclr  0xb8211002  a: 0xb8a11002  xor 0x00800000  -&gt; bit 23
     ldclr  0xb8211002  l: 0xb8611002  xor 0x00400000  -&gt; bit 22
     ldclr  0xb8211002  al:0xb8e11002  xor 0x00c00000  -&gt; bits 23 and 22

     AND BIT 21 IS 1 IN EVERY ONE OF THOSE EIGHT WORDS AND IN THE
     FOUR CAS WORDS ABOVE, so it is a CONSTANT of the whole group
     rather than an ordering bit.
                </pre>
                </div>
                <div class="formula">
   R21, and the sentence worth more than the number

   CLAIMED     the LSE group encodes acquire as bit 22 and
               release as bit 21, once for the whole group

   MEASURED    CAS AND CASP: acquire is bit 22, release is bit 15.
               LDADD AND ITS SIBLINGS: acquire is bit 23,
               release is bit 22.  Bit 21 is 1 in every word in
               both halves.

   FOUND BY    the cross-check printing `ldadd` where the
               assembler prints `ldaddl`

   WHY         a wrong constant and a constant FIELD look
               identical until you sweep the suffix, and the
               wrong one promoted a relaxed atomic to a release
               one, in a legal word with nothing wrong in it.
                </div>
                <p>Read that "found by" line twice. The decoder was not obviously wrong. It printed <code>ldaddl</code> for a word that is <code>ldadd</code> — a real instruction, a legal word, a relaxed atomic silently promoted to a release one, and <strong>nothing anywhere in the output said the number was wrong.</strong> A wrong constant and a constant field look identical until you sweep the suffix.</p>
                <h3>One bit, two meanings</h3>
                <p>The consequence is the sharpest thing in the section. <code>CASP</code> is the 128-bit form, and <strong>its 128-bit-ness is bit 23</strong> — which is the bit that says "acquire" in the LDADD family:</p>
                <div class="hex-dump">
                <pre>     cas  w1, w2, [x0]               0x88a17c02  b23=1
     cas  x1, x2, [x0]               0xc8a17c02  b23=1
     casp x0, x1, x2, x3, [x4]      0x48207c82  b23=0
     caspal x0, x1, x2, x3, [x4]     0x4860fc82  b23=0

     ONE BIT, TWO MEANINGS, NO OVERLAP, and the two meanings are
     in the same word a few opcodes apart.  So the question
     "does this word want a 128-bit atomic or an acquire" has
     no answer from a field diagram.
                </pre>
                </div>
                <p>And in the CAS half "release" is not a flag either: <code>bits[15:10]</code> reads <code>0b011111</code> for <code>cas</code> and <code>0b111111</code> for <code>casl</code>. The same six bits, with the release bit as the <strong>top one of the opcode</strong>. So a decoder that wants a release flag in this group has to read the opcode and then test a bit of it, which is the same work twice and looks like a different design.</p>
            </div>

            <div class="unit unit-example">
                <h2>What FEAT_LSE does not buy</h2>
                <p>A feature is not a blanket, and the 16-byte case is where the course finds out:</p>
                <div class="hex-dump">
                <pre>     cas_pair_seqcst    -&gt; caspal x2, x3, x6, x7, [x0]
     cas_pair_relaxed   -&gt; casp  x2, x3, x6, x7, [x0]
     cas_pair_acqrel    -&gt; caspal x2, x3, x6, x7, [x0]
     pair_fetch_add     -&gt; ldaddal x1, x8, [x0] | ldaddal x1, x1, [x9]

     THREE different C11 memory orders produce TWO distinct
     instructions, and a 128-bit FETCH-ADD produces TWO 64-bit
     `ldaddal` because there is no 128-bit LSE arithmetic at all.
                </pre>
                </div>
                <p>At baseline the same thing is a loop, and the loop has the same interface as the single-word one — <code>ldaxp</code> and <code>stlxp</code> name two data registers and one status register, so the pair form has the same status-register interface and therefore the same loop. clang emits <strong>seven instructions per attempt against the single word's four</strong>.</p>
                <p>And <code>casp</code> is worth reading for its own sake, because it is the only instruction in this course that names 128 bits of memory in a 32-bit instruction:</p>
                <div class="hex-dump">
                <pre>     casp x0, x1, [x2]          -&gt; expected register
     casp x0, x1, x2            -&gt; expected comma
     casp x0, x1, x2, x3        -&gt; too few operands for instruction
     CASP takes FIVE operands -- two register pairs and the
     memory -- and the diagnostic for the three-operand form
     points AT THE MEMORY OPERAND, which is the one operand
     that was correct.
                </pre>
                </div>
                <p>A diagnostic that points at the right operand is a diagnostic that <em>will</em> be believed, and the first draft of this file believed it and then reported a <strong>refusal</strong> where there was an instruction. That is retraction R8, and it was found by assembling nine spellings of one mnemonic — the mnemonic the compiler itself emits.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Find the loop and then remove it, watching the count.</strong> Compile <code>__atomic_fetch_add</code> at <code>-O2</code> and again at <code>-O2 -march=armv8.1-a</code>. <em>(Expect <code>ldaxr | add | stlxr | cbnz</code> and then <code>ldaddal</code> with no branch at all. Then count: six instructions against three, and note that the six includes a <code>mov</code> and a <code>ret</code> that are not part of the atomic. Read the count as a count.)</em></li>
                    <li><strong>Sweep the LSE suffix yourself and find bit 21.</strong> Assemble <code>ldadd</code>, <code>ldadda</code>, <code>ldaddl</code>, <code>ldaddal</code> and XOR each against the first. <em>(Expect bit 23 for the <code>a</code> form, bit 22 for the <code>l</code> form, and both for <code>al</code> — and then check bit 21 in all four and find it set in all four. That last check is the one that would have saved the first draft, and it takes four seconds.)</em></li>
                    <li><strong>Look for the instruction that is not in the pair form.</strong> Search the LSE mnemonics for a 128-bit fetch-add. <em>(Expect nothing assembles. LSE has a compare-and-swap for pairs and <strong>no arithmetic for pairs</strong>, and a feature that covers three of the four operations on a given width is not a blanket. Ask what it takes to get the fourth: two <code>ldaddal</code>s, which is a lost-update window twice as wide.)</em></li>
                    <li><strong>Answer the interface question in your own words.</strong> Why must the retry be a loop rather than an instruction? <em>(Expect the chain: failure comes back in a register; an instruction cannot act on its own output; therefore something outside the instruction must branch; therefore the branch is outside the instruction; therefore the retry is outside the instruction. Then ask what an instruction with a different interface would look like — that is <code>casp</code>, and it is the reason FEAT_LSE exists rather than a faster <code>stlxr</code>.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Forwards, and it is the most important connection in the course. <a href="/courses/a64simd/lessons/a64-order">Acquire and Release Are Access Modes</a> is where the <em>ordering</em> half of the suffixes above gets its meaning: concept 3 measured that the suffixes cost one or two bits, and concept 4 measures that a C11 <code>seq_cst</code> operation and a C11 <code>acquire</code> operation are the <strong>same instruction</strong> and that the whole corpus emits three barriers. Read them together and the sentence that emerges is that on AArch64, ordering is a property of the <em>access</em> and a barrier is the exception, not the mechanism.</p>
                <p>Backwards, into the machine course. <a href="/courses/a64sys/lessons/a64-registers">The register concept</a> is where the width field that this page sweeps four times was introduced for the scalar case, and the "one field written twice in the syntax" observation is a direct descendant of that course's <code>w</code>-versus-<code>x</code> distinction. <a href="/courses/a64sys/lessons/a64-interrupts">The exception concept</a> is quietly relevant too: a context switch is one of the things that makes an exclusive store fail, and that is the link between this page's loop and the machine course's exception entry.</p>
                <p>Sideways, to the sibling that can measure what this one cannot. <a href="/courses/x86simd">The x86-64 SIMD course</a> has <code>lock cmpxchg</code>, which is the same feature bought a different way: on x86-64 the <code>lock</code> prefix makes an <em>ordinary</em> compare-and-swap atomic for a whole memory region, so the interface is the prefix rather than the mnemonic. Both architectures solved the same interface problem — an atomic that cannot fail needs no status register — and both chose to add a <em>different instruction</em> rather than make the old one cleverer. The difference is that x86-64 generalised it to "any read-modify-write" and AArch64 had to enumerate the operations.</p>
                <p>Outward, and this is the transferable lesson of the retraction: <strong>a wrong constant and a constant field are the same shape.</strong> Every reader of an encoding has a handful of bit constants, and a field that happens to be constant across a corpus will be read as a constant, and the two are indistinguishable until someone sweeps the axis the constant was supposed to vary along. The general form costs nothing to apply to a machine you can run: <em>when you hardcode a bit, write down which instruction you varied to find it</em>, and if the answer is "I read it in a table", the bit is a guess with a citation.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/a64simd/lessons/a64-neonspace">The Shared Memory Space</a></span>
                <span>Next: <a href="/courses/a64simd/lessons/a64-order">Acquire and Release Are Access Modes, Not Barriers</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
