// The x86-64 Data Path — Concept 4: the atomic set
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_atomics() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Atomic Set: Which Instructions Imply LOCK — Underlayer")
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
            <h1>The Atomic Set: Which Instructions Imply LOCK, and Which Do Not</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/x86simd">The x86-64 Data Path</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p><a href="/courses/smp/lessons/smp-atomic">The SMP course</a> measured what a lost update costs and told you to use <code>lock</code>. This concept is the exhaustive answer to the question that follows immediately and is almost never asked: <strong>which instructions can you put it on, and what happens if you leave it off?</strong> The answer is not &ldquo;the ones that write memory&rdquo;, and it is emphatically not &ldquo;all the read-modify-writes&rdquo;.</p>
                <p>Forty-two arms, three instruments, two threads pinned to two cores with a barrier and the shared word reset before every single arm. And two results in the set are the course:</p>
                <ul>
                    <li><strong><code>lock inc</code> is exact.</strong> The draft for this course said it was not. It is, and the reason it is the only read-modify-write with that property is a single sentence in the instruction's description: <code>INC</code> does not disturb the <code>CARRY</code> flag, so it needs no special case in the silicon.</li>
                    <li><strong><code>or $0</code>, <code>and $0xffffffff</code>, <code>xor $0</code> and <code>sub $0</code> with no prefix all lose updates.</strong> These are the arms that look like no-ops, and a no-op is the perfect camouflage: there is no visible effect of the lost update because there was no visible effect to begin with.</li>
                </ul>
            </div>

            <div class="unit unit-model">
                <h2>Instrument one: the counter, and the arms it can decide</h2>
                <p>The counter is the obvious instrument &mdash; two threads increment a shared word N times each, and a total of 2N means nothing was lost. Here is the whole table, and every row's target is a <em>different</em> number for a reason that is worth reading before the verdicts:</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/^  CNT  | instruction/,/bt  \$0/p'
  CNT  | add $1,        no LOCK   | 83 00 01             |       120000 |        78548 | NOT ATOMIC
  CNT  | add $1,        LOCK      | f0 83 00 01          |       120000 |       120000 | ATOMIC
  CNT  | inc,           no LOCK   | ff 00                |       120000 |        63066 | NOT ATOMIC
  CNT  | inc,           LOCK      | f0 ff 00             |       120000 |       120000 | ATOMIC
  CNT  | dec,           no LOCK   | ff 08                |  4294847296 |  4294900952 | NOT ATOMIC
  CNT  | dec,           LOCK      | f0 ff 08             |  4294847296 |  4294847296 | ATOMIC
  CNT  | xadd $1,       NO PREFIX | 0f c1 01             |       120000 |        77812 | NOT ATOMIC
  CNT  | xadd $1,       LOCK      | f0 0f c1 01          |       120000 |       120000 | ATOMIC
  CNT  | cmpxchg loop,  NO PREFIX | 0f b1 01             |       120000 |        62692 | NOT ATOMIC
  CNT  | cmpxchg loop,  LOCK      | f0 0f b1 01          |       120000 |       120000 | ATOMIC
  CNT  | cmpxchg8b,     NO PREFIX | 0f c7 01             |       120000 |        63790 | NOT ATOMIC
  CNT  | cmpxchg16b,    NO PREFIX | 48 0f c7 01          |       120000 |        62430 | NOT ATOMIC
  CNT  | cmpxchg8b,     LOCK      | f0 0f c7 01          |       120000 |       120000 | ATOMIC
  CNT  | cmpxchg16b,    LOCK      | f0 48 0f c7 01       |       120000 |       120000 | ATOMIC
  CNT  | load+add+XCHG            | mov;add;87           |       120000 |        80634 | NOT ATOMIC
  CNT  | load+add+LOCK XCHG       | mov;add;f0 87        |       120000 |        83096 | NOT ATOMIC
                </pre>
                </div>
                <p>Read the <code>dec</code> rows first, because they carry the concept's sharpest methodological point. The word starts at zero and each thread decrements 60000 times, so the exact total is <strong>2<sup>32</sup> &minus; 2N = 4294847296</strong>, not 2N. A table that expected 2N would report a perfectly atomic <code>lock dec</code> as non-atomic &mdash; and did, for one run, before the expectation was corrected. <strong>The expectation is the thing that has to be right before a measurement can be called a pass</strong>, and there are three of them here, not one: an arm that moves the value up ends at 2N, one that moves it down ends at 2<sup>32</sup>&minus;2N, and one that <em>toggles</em> a bit ends at 0 because the two threads toggle an even number of times between them. Getting any of the three wrong calls a working arm broken.</p>
                <p>And the last two rows are the other half of the story, so do not skip them. <code>mov;add;87</code> is a load, an add and a bare <code>XCHG</code> with a memory operand &mdash; and it loses updates. Adding <code>lock</code> to that <code>XCHG</code> <strong>does not help</strong>, and the reason is the shape of the program rather than the instruction: by the time the <code>XCHG</code> runs, the damage is in the <code>mov</code> and the <code>add</code> before it. <code>XCHG</code> is genuinely atomic with a memory operand, and that fact does not make a three-instruction sequence atomic. <strong>Atomicity is a property of the instruction, and a sequence of atomic instructions is not thereby an atomic sequence.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>Instrument two: the value-preserving arm, and why it is the decisive one</h2>
                <p>The counter cannot decide <code>or $0</code>, because the value never changes and a lost update leaves no trace. So the second instrument asks a different question: run an operation that does not move the value, and check whether a counter the operation <em>should</em> have incremented got incremented anyway. A <code>sub $0</code> is a subtraction of zero, which changes nothing; the instrument counts how many times each thread's <em>own</em> paired counter advanced past the value it had written. If the word is not read and written atomically, one thread's write is lost between the other's read and write.</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/^  PAIR | instruction/,/sbb \$0,        LOCK/p'
  PAIR | or  $0,        NO PREFIX | 83 08 00             |        60000 |        23643 | NOT ATOMIC
  PAIR | or  $0,        LOCK      | f0 83 08 00          |        60000 |        60000 | ATOMIC
  PAIR | and $0xffffffff,NO PREFIX | 81 20 ff ff ff ff    |        60000 |        30345 | NOT ATOMIC
  PAIR | and $0xffffffff,LOCK     | f0 81 20 ff ff ff ff |        60000 |        60000 | ATOMIC
  PAIR | xor $0,        NO PREFIX | 83 30 00             |        60000 |        28042 | NOT ATOMIC
  PAIR | xor $0,        LOCK      | f0 83 30 00          |        60000 |        60000 | ATOMIC
  PAIR | sub $0,        NO PREFIX | 83 28 00             |        60000 |        21598 | NOT ATOMIC
  PAIR | sub $0,        LOCK      | f0 83 28 00          |        60000 |        60000 | ATOMIC
  PAIR | xor $0x80000000,NO PREFIX | 81 30 00 00 00 80    |        60000 |        26480 | NOT ATOMIC
  PAIR | xor $0x80000000,LOCK     | f0 81 30 00 00 00 80 |        60000 |        60000 | ATOMIC
  PAIR | bt  $0 + a mov           | 0f ba 20 00; 89      |        60000 |      6172342 | NOT ATOMIC
  PAIR | adc $0,        NO PREFIX | 83 10 00             |        60000 |        85507 | NOT ATOMIC
  PAIR | adc $0,        LOCK      | f0 83 10 00          |        60000 |       120000 | NOT ATOMIC
  PAIR | sbb $0,        NO PREFIX | 83 18 00             |        60000 |   4294924018 | NOT ATOMIC
  PAIR | sbb $0,        LOCK      | f0 83 18 00          |        60000 |            0 | NOT ATOMIC
                </pre>
                </div>
                <p><strong>Every value-preserving arm without a prefix loses, and every one with a prefix is exact.</strong> That is fifteen rows and a partition, and it is the strongest result in the course because the verdict does not depend on the counts: the arms are 23643, 30345, 28042 and 21598 where exactness is 60000, and the <em>locked</em> versions of all four are 60000 exactly. A number moves between runs. <em>These four all lost, and these five all did not</em> does not.</p>
                <p>The last four rows are the interesting failures, and they are failures of the <strong>expectation</strong> rather than of the instruction. <code>adc $0</code> adds the carry flag, and a two-threaded loop on that flag produces 120000 with a <code>lock</code> and <strong>120000</strong> without &mdash; the flag happens to be stable, and the arm is testing the wrong thing. <code>sbb $0</code> subtracts it, and the totals are 0 and 4294924018 because a <code>sbb</code> on a carry-heavy loop is not a counter at all. They are in the table because <strong>a table of atomic instructions should include the ones the instrument cannot decide</strong>, and hiding two of them would make the table look tidier and be worth less.</p>
                <h3>The third instrument, and the retraction that made it necessary</h3>
                <p><code>NOT</code> and <code>NEG</code> report no old value and they are involutions, so neither instrument can read them. Apply twice and ask whether the word came back: the pair <em>is</em> the identity, so a lost update is the only thing that can break it.</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/^  IDENT|/,/^$/p'
  IDENT| instruction              | bytes                |        final | verdict
  IDENT| not, twice,    no LOCK   | f7 d0                | 0x5a5a5a5a | RESTORED
  IDENT| not, twice,    LOCK      | f0 f7 d0             | 0x5a5a5a5a | RESTORED
  IDENT| neg, twice,    no LOCK   | f7 d8                | 0x5a5a5a5a | RESTORED
  IDENT| neg, twice,    LOCK      | f0 f7 d8             | 0x5a5a5a5a | RESTORED
                </pre>
                </div>
                <p>All four say <code>RESTORED</code>, and <strong>that is not evidence that they are atomic.</strong> Two threads applying <code>NOT</code> an even number of times between them returns the word to where it started whether or not either was lost. The unprefixed arms being <code>RESTORED</code> is the <em>expected</em> reading, and an instrument that cannot tell an atomic operation from a non-atomic one has told you nothing. This is retraction 3, and it is the most useful thing in the file: <strong>a lost-update count is a test for atomicity only for operations that move a value in one direction</strong>, which is a much narrower statement than &ldquo;is it atomic&rdquo; and the reason this section has three instruments rather than one.</p>
            </div>

            <div class="unit unit-example">
                <h2>Two lists that everybody quotes and nobody distinguishes</h2>
                <p>This is the part of the concept that changes how you read every other reference on the subject, and it is <code>NOT MEASURED</code> &mdash; it is quoted from the SDM and then <em>used</em> to read the measured table above.</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/1B3\. THE LOCK LIST/,/without it\./p'
  1B3. THE LOCK LIST, AND WHO IMPLIES IT.  NOT MEASURED.

  The SDM names EIGHTEEN instructions that accept a LOCK prefix:
    ADD ADC AND BTC BTR BTS CMPXCHG CMPXCHG8B CMPXCHG16B
    DEC INC NEG NOT OR SBB SUB XOR XADD XCHG
  and says of XCHG, in so many words:
    'If a memory operand is referenced, the processor's locking
     protocol is automatically implemented for the duration of
     the exchange operation, REGARDLESS OF THE PRESENCE OR
     ABSENCE OF THE LOCK prefix.'

  THE INSTRUCTION WITH NO LOCK IS 'BT'.  BTC, BTR and BTS are on
  the list; BT is not, because BT does not write.  A read-modify-
  write a reader builds out of BT and a store is therefore two
  instructions and no encoding can make it atomic, which is a
  fact about the INSTRUCTION SET rather than about a prefix.
                </pre>
                </div>
                <div class="formula">
   TWO LISTS, AND THEY ARE NOT THE SAME.

   THE EIGHTEEN     instructions that ACCEPT
                    a LOCK prefix.  If you write
                    `lock` in front of one, it
                    assembles.

   THE IMPLICIT SET  instructions that are ATOMIC
                    WITHOUT one.  Exactly one, and
                    the SDM says so in a sentence.

   Everybody quotes the first when they
   mean the second, which is why
   `lock xadd` and a bare `xchg` get
   described as the same mechanism.
   They are not: the bare xchg is a
   different mechanism entirely.
            </div>
                <p>So the <code>lock inc</code> result has a precise reading. The draft said <em>&ldquo;INC and DEC are not atomic even with the LOCK prefix,&rdquo;</em> and the SDM is the source of that error: it lists <code>INC</code> as accepting the prefix, and a reader who skims &ldquo;accepts&rdquo; as &ldquo;is atomic&rdquo; gets it wrong. Measured, both are exact. The reason is in the instruction's own description and is about a <em>flag</em>: <strong><code>INC</code> and <code>DEC</code> do not disturb <code>CARRY</code></strong>, which is precisely why they were given their own opcodes <code>fe</code> and <code>ff</code> separate from the general <code>ADD</code>/<code>SUB</code> forms &mdash; and that freedom from the carry flag is exactly what lets the locked versions be ordinary locked operations rather than a special case in the silicon.</p>
                <p>And the bit-test row at the end of the counter table is the shape of a limit worth naming. <code>BTS</code> and <code>BTR</code> both read <code>ATOMIC</code> with and without a prefix &mdash; not because the unprefixed form is atomic, but because <strong>they are idempotent, so this instrument cannot tell</strong>. <code>btc</code> toggles and is the only one of the three the counter can decide. Getting a table like this right is less about the hardware than about choosing an operation whose failure has a visible consequence.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce the counter table.</strong> <code>cd courses/x86simd/assets/samples &amp;&amp; ./build_samples.sh</code>, then read section 4. <em>(Expect the seven locked arms to hit their targets exactly and the unprefixed twins to land somewhere below. Expect the <code>dec</code> rows to be 4294847296 and not 120000 &mdash; and if your run reports 120000 for the locked <code>dec</code>, you have found the bug that made retraction 18 necessary, and it is the single most useful thing a reader can reproduce here.)</em></li>
                    <li><strong>Write the value-preserving arm yourself.</strong> <em>(Expect it to be much harder than the counter, and expect the moment you get it wrong to be a <em>missing</em> result rather than a wrong one. The whole point of that instrument is that the failure has no visible effect, which is why three earlier versions of it were wrong in three different ways &mdash; a per-thread hash set, a shared set that needed the same counter it was testing, a counted clobber, and a paired counter. All four attempts are written out in the artifact&rsquo;s header comment, because a retraction with the instruction beside it is worth more than one with the word &ldquo;counter&rdquo; in it.)</em></li>
                    <li><strong>Find the boundary between the two lists.</strong> Write a loop that does <code>bt $0</code> and a store, and reason about whether any encoding makes it atomic. <em>(Expect the answer to be no, and expect the reason to be a fact about the instruction set rather than about a prefix: <code>BT</code> does not write, so a read-modify-write built out of it is two instructions, and no prefix can make a sequence atomic. This is the one place in the course where the answer is a structural argument rather than a measurement, and it is worth noticing that the artifact says so.)</em></li>
                    <li><strong>Test the assumption that <code>xchg</code> makes a sequence safe.</strong> Take the last two rows of the counter table and reverse them &mdash; put the <code>XCHG</code> first. <em>(Expect it to be exact, because now the <code>XCHG</code> really is the only memory-touching instruction in the sequence and it really is atomic. Same instruction, same prefix, opposite verdict. The property was never about the instruction; it was about being the one that touches memory in a read-modify-write.)</em></li>
                    <li><strong>Find a real code review that got this wrong.</strong> Look for <code>lock</code> in front of an instruction that never needed it. <em>(Expect to find some, and expect the reason they are harmless is that the prefix costs a few percent on an instruction that was already serialising for another reason. The interesting review question is not &ldquo;is this lock necessary&rdquo; but &ldquo;what does this instruction guarantee, and does the code around it depend on the guarantee or on the hope that it was there&rdquo;.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/smp/lessons/smp-atomic">the SMP course's atomic concept</a> measured the cost of a race and told you that the fix is <code>lock</code>. This page is the reference that says <em>which</em> <code>lock</code>, and it is worth reading the pair in that order: knowing the principle without the list produces code that is correct by luck, and knowing the list without the principle produces code that is fast and wrong. <a href="/courses/simd/lessons/simd-compiler">The SIMD course's compiler concept</a> is where you will meet the same problem in a different shape &mdash; a compiler that reorders a non-atomic access is a bug, and the rule that prevents it is the same list.</p>
                <p>Forwards, and the connection is mechanical rather than thematic. Every row in the table above is a <em>single instruction</em> made atomic, and the next concept is about what happens when one core's atomic operation is not enough &mdash; because atomicity says nothing about <em>order</em>. Two cores can each perform their operations perfectly and still disagree about the order they happened in. That gap is what <code>MFENCE</code> and its two siblings exist to close, and it is the reason the <code>btc</code> and <code>adc</code> rows that could not be decided here are worth keeping even unresolved.</p>
                <p>Outward. The eighteen-instruction list is a beautiful piece of historical accident and it is the same list on every x86-64 part ever made, because it is baked into the encoding rather than the implementation. <a href="/courses/x86asm/lessons/x86-integers">The assembly course's integer concept</a> covers the flag semantics that make <code>INC</code> special here &mdash; <code>INC</code> and <code>DEC</code> not touching <code>CARRY</code> is a flag-design decision from 1978 that is still the reason two instructions behave differently from their obvious general forms. The transferable shape is: <strong>an instruction set accumulates special cases, and the special case is almost always about a flag nobody was thinking about when they wrote the loop that uses it.</strong></p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86simd/lessons/x86-avx512">AVX-512: ZMM, k0&#8211;k7, and a Decoder That Needs No Silicon</a></span>
                <span>Next: <a href="/courses/x86simd/lessons/x86-order">Ordering: TSO, the Three Fences, and the Direction Flag</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
