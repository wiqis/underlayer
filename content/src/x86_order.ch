// The x86-64 Data Path — Concept 5: memory ordering and the three fences
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_order() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Ordering: TSO, the Three Fences, and the Direction Flag — Underlayer")
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
            <h1>Ordering: TSO, the Three Fences, and What Each One Orders</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/x86simd">The x86-64 Data Path</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>The previous concept made every instruction in the atomic set individually atomic. That is necessary and nowhere near sufficient, and the gap between the two is the entire subject of this page: <strong>two cores can each perform their operations perfectly and still disagree about the order in which they happened.</strong> Atomicity is a property of an instruction. Ordering is a property of a sequence, and the x86-64 instruction set gives you three instructions &mdash; and one of the three is nearly useless on a modern part.</p>
                <p>This is also the concept where the course's one <em>architecture-shaped</em> answer lives. <a href="/courses/smp/lessons/smp-ordering">The SMP course</a> taught total store order as a model and named the store buffer as the mechanism. The x86-64 reference for that is short &mdash; three opcodes, six bytes of encoding, and a documented rule that says stores retire in order and loads may pass them &mdash; and the reference is worth having precisely because the model is architecture-neutral and the answer is not.</p>
            </div>

            <div class="unit unit-model">
                <h2>The three fences, which are three bytes and one opcode</h2>
                <p>&ldquo;What does <code>SFENCE</code> actually encode?&rdquo; has an answer, and it is short enough to print in full. <code>NOT MEASURED</code> here &mdash; disassembled, not quoted, because the point of the table is that the encoding is small enough to be completely understood:</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/5B\. THE FENCES/,/are 11 and 000/p'
  FENCE | the three bytes | the ModRM reg field, bits 5:3
  ------+-----------------+--------------------------
  MFENCE| 0f ae f0        | 111 = 7   order loads AND stores
  LFENCE| 0f ae e8        | 101 = 5   order loads only
  SFENCE| 0f ae f8        | 111 = 7   order stores only
         all three are the SAME opcode, 0F AE, and the
         mod and rm fields are 11 and 000 in all three.
                </pre>
            </div>
                <p>Read the reg column twice. <strong><code>MFENCE</code> and <code>SFENCE</code> both have reg=7.</strong> They are told apart by the <em>map</em> &mdash; the <code>0F</code> escape byte they share &mdash; and by the CPU&rsquo;s internal decode of the escape. So there are not three opcodes and there are not three reg values either: <code>0F AE</code> is one opcode with a three-bit selector, and <strong>a decoder that switches on <code>ModRM.reg</code> alone gets <code>MFENCE</code> and <code>SFENCE</code> right only by accident.</strong> That sentence is the practical one, and it is why the last concept of this course exists.</p>
                <p>And then the detail everybody gets wrong, which is retraction 22:</p>
                <div class="formula">
   THE DRAFT SAID "a single bit position."
   IT IS TWO, AND THE DIFFERENCE IS WHY
   THE THREE BITS ARE NOT CONTIGUOUS.

   MFENCE   0xF0   reg = 111 = 7
   SFENCE   0xF8   reg = 111 = 7

   bit 3   0 in MFENCE, 1 in SFENCE   <- differs
   bit 2   0 in both
   bit 1   0 in both

   Two bit positions differ, not one.  A
   "single bit" story about this table
   cannot be made to fit, and the reason
   it cannot is that bits 2 and 1 are
   CLEAR IN BOTH, which is exactly the
   pattern a single-bit claim cannot
   produce.
            </div>
                <p>So what does each one order? <code>SFENCE</code> orders <em>stores</em> against each other, <code>LFENCE</code> orders <em>loads</em> against each other, and <code>MFENCE</code> orders both. Every memory barrier on x86-64 is one of these three, and on a modern part most of them compile to nothing at all &mdash; because the memory model guarantees that they were unnecessary in the first place.</p>
                <p>And here is the property that surprises people, quoted from the artifact because it is a fact about the <em>instruction</em> rather than a recommendation:</p>
                <div class="formula">
   A LOCKED INSTRUCTION IS A BETTER FENCE
   THAN SFENCE AND IT IS ONE INSTRUCTION
   SHORTER.

   The LOCKED store already drains the
   buffer, because the store cannot retire
   until it has.  That is why a spinlock
   built on CMPXCHG needs no SFENCE, and
   it is a property of the INSTRUCTION
   rather than a recommendation.
            </div>
                <p>That is the practical heart of the whole page. A hand-rolled spinlock that does <code>lock cmpxchg</code> and then an <code>sfence</code> is paying for a fence the <code>cmpxchg</code> already provided, and the reason it is easy to get wrong is that the <code>sfence</code> is what <em>looks</em> like the correctness argument.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The ping-pong: seven arms, and the result that is not the expected one</h2>
                <p>Two threads pinned to two cores, a barrier, and one store plus one peer load per iteration. Seven arms, interleaved, min-of-N, and the word reset before every one:</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/^  ORD  |/,/the two floors differ/p'
  ORD  | store to my line, then load the peer's  (no flag)    52.399 ticks/iter
  ORD  | ...with an SFENCE between them                    62.036 ticks/iter
  ORD  | ...with an MFENCE between them                   143.045 ticks/iter
  ORD  | ...with a LOCKED store instead of a plain one     125.864 ticks/iter
  ORD  | store and load, both words in ONE cache line      78.245 ticks/iter
  ORD  | THE FLOOR: the store alone, no peer load          62.151 ticks/iter
  ORD  | the other floor: the peer load alone              39.245 ticks/iter
                </pre>
            </div>
                <p>And the layout, which is printed because the first version of this experiment was wrong about it and the wrongness was invisible in the numbers:</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/THE LAYOUT/,/different lines/p'
  THE LAYOUT, printed because R24 was a layout bug:
    the two 'mine' lines are  64 bytes apart (TWO lines)
    the two 'both' lines are  64 bytes apart (TWO lines)
    'mine' and 'both' are in different lines: yes
                </pre>
            </div>
                <p>Three findings, and none of them is the textbook one.</p>
                <ul>
                    <li><strong>Adding an <code>SFENCE</code> does not turn the ping-pong into the textbook picture of a line changing hands on every iteration.</strong> What <code>SFENCE</code> does is make the arm more expensive, and what the <code>LOCKED</code> store does is make it more expensive, and both of those are <strong>the store buffer draining</strong> &mdash; which is the mechanism <a href="/courses/smp/lessons/smp-ordering">the SMP course named</a>. So the extension <em>confirms</em> the explanation and does not rescue the shape.</li>
                    <li><strong>Why the shape never appears:</strong> a store does not invalidate the other core&rsquo;s copy <em>when it executes</em>. It goes into this core&rsquo;s store buffer and the peer&rsquo;s copy stays <code>VALID</code> until the store <em>retires</em>. Two threads in a tight loop with no synchronisation therefore do not take turns: each runs ahead, each load often finds the peer&rsquo;s line still valid and <code>SHARED</code>, and the transfers that do happen are spread out rather than serialised. <strong>That is total store order, visible as an absence of a cost.</strong></li>
                    <li><strong>The same-line arm is several times the two-line version, and that is a bigger effect than any fence here.</strong> Whichever way you are going to make this fast, moving the two words apart is worth more than choosing a fence &mdash; and that is <a href="/courses/smp/lessons/smp-atomic">false sharing</a>, the cheapest performance bug in concurrent code to write and the most expensive to find.</li>
                </ul>
                <p><strong>MECHANISM: INFERRED.</strong> There is no counter here that can count coherence traffic: <code>perf_event_paranoid</code> is 4 and every mechanism named above is inferred from a duration. A duration bounds a count without measuring it, and the instrument that would settle it is <code>perf_event_open</code> with a permissive <code>paranoid</code> setting and a PMU passthrough from the host.</p>
                <h3>Which is also why a race is hard to find</h3>
                <p>The result of all that is worth more than the number: <strong>the fast path and the slow path look the same on average.</strong> A program with a race usually runs at full speed and gives the wrong answer once in a million times, which is exactly the profile of a heisenbug. The single-line row is the one that <em>does</em> show a cost, and it shows it because two words in one line is a different data structure rather than a different fence.</p>
            </div>

            <div class="unit unit-example">
                <h2>The direction flag is bit 10, and there is a story about why it is hard to remember</h2>
                <p>This course was written from a brief that said the direction flag is EFLAGS bit 21. It is not. Here is the register, read out with <code>PUSHFQ</code> in the artifact, with every bit named rather than the one remembered:</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/^  EFLAGS/,/bit 21/p'
  EFLAGS as read by PUSHFQ      0x0000000000000202
    bit  0 CF                 0
    bit  2 PF                 1
    bit  6 ZF                 0
    bit  9 IF                 1
    bit 10 DF, THE DIRECTION  0
    bit 11 OF                 0
    bit 16 RF                 0
    bit 18 AC                 0
    bit 21 ID, NOT DIRECTION  0
                </pre>
            </div>
                <p><strong>Bit 10 is DF. Bit 21 is the ID flag</strong>, and the ID flag has a completely different job: before <code>CPUID</code> existed, software identified a processor by <em>setting a bit it was not supposed to be able to set</em> and pushing the flags. The 8086 and 8088 had no such bit; the Pentium does. The two flags have nothing in common, and the bit number is the whole of the confusion.</p>
                <p>There is a small tell here that is worth more than the fact. The direction flag is set and cleared by two instructions that <strong>do nothing else</strong>: <code>STD</code> sets it and <code>CLD</code> clears it. There is <em>no complement</em> &mdash; no <code>CLDD</code>, no instruction to flip it &mdash; which is a gap in the instruction set closed with <code>PUSHF</code>, an <code>XOR</code> and <code>POPF</code>. And the reason the <code>ID</code> flag exists at all is that it needed to be settable <em>without a dedicated instruction</em>, which is exactly the kind of bit that gets confused with one that has its own <code>STD</code>. <strong>A flag that is set by a dedicated instruction and a flag that is set by arithmetic look the same in a manual and behave nothing alike in a shell.</strong></p>
                <p>Now what it costs. <code>rep movsb</code> moves a string in the direction <code>DF</code> names, and the two directions are not symmetric:</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/bytes |   DF=0/,/^  ---/p'
  bytes |   DF=0  |   DF=1  | ratio  | ticks/byte up | ticks/byte dn
  ------+----------+----------+--------+--------------+--------------
     16 |       23 |      184 |   8.00 |       1.4375 |      11.5000
    256 |       23 |      253 |  11.00 |       0.0898 |       0.9883
   1024 |       46 |      782 |  17.00 |       0.0449 |       0.7637
   4096 |       92 |     2875 |  31.25 |       0.0225 |       0.7019
                </pre>
            </div>
                <p>Three things in that table, and the middle one is the finding.</p>
                <ul>
                    <li><strong>The downward direction is slower at every size</strong> &mdash; 8.00&times;, 11.00&times;, 17.00&times;, 31.25&times; &mdash; and both arms printed nothing from the checksum comparison on every row, which is the check that they copied the same bytes. A <code>rep movsb</code> with <code>DF=1</code> is a correct copy. It is just a much slower one.</li>
                    <li><strong>The ratio GROWS with size, and that is the whole result.</strong> A fixed per-call overhead would give a constant ratio, so a growing one means a <em>per-byte</em> cost that the downward direction pays and the upward one does not &mdash; which is a hardware counter. The artifact marks the mechanism <strong>INFERRED</strong> and prints &ldquo;why the downward string direction is slower&rdquo; in its limits block, because the number and the reason are separable and only the number is measured.</li>
                    <li><strong>The forward per-byte cost also falls</strong>, from 1.4375 at 16 bytes to 0.0225 at 4096. That is the loop-overhead term amortising away, and it is printed in the same table precisely so the reader can see that the <em>ratio</em> is not measuring overhead: both arms have the same overhead and the ratio still grows.</li>
                </ul>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce the fence bytes.</strong> <code>cd courses/x86simd/assets/samples &amp;&amp; ./build_samples.sh</code>, then read section 5B. <em>(Expect <code>0f ae f0</code>, <code>0f ae e8</code>, <code>0f ae f8</code> and reg fields 7, 5, 7. Then write the decoder that switches on reg alone and watch it confuse <code>MFENCE</code> with <code>SFENCE</code> &mdash; which is the one practical thing on this page you can get wrong in a real disassembler.)</em></li>
                    <li><strong>Remove the <code>sfence</code> from a spinlock.</strong> Take a <code>lock cmpxchg</code> spinlock and delete the <code>sfence</code> after the successful exchange. <em>(Expect it to remain correct, because the locked instruction already drained the buffer, and expect the reasoning to be the thing that changed: the fence was never the correctness argument, the locked RMW was. Then find the version that <em>is</em> wrong &mdash; a spinlock built on <code>bt</code> plus a store &mdash; and notice that its bug is a different bug, in a different category, that no fence could fix either.)</em></li>
                    <li><strong>Build the <code>L'L</code>-style decoder bug for the fence set.</strong> <em>(Expect the failure to be a decoder that produces <em>legal</em> bytes for a different instruction, with no length surprise and no trap. This is the same class as the AVX-512 <code>62</code> prefix problem in the previous concept, and recognising the class twice is the point: an encoding is a namespace, and a decoder that ignores a field dependency is a namespace violation with a very quiet symptom.)</em></li>
                    <li><strong>Find the bit 21 in a real program.</strong> Search a codebase for <code>21</code> near the word &ldquo;flag&rdquo;. <em>(Expect to find a <code>PUSHF</code>/modify/<code>POPF</code> sequence that is <em>not</em> about the direction flag, and expect it to be an ID-detection routine that nobody has run since 1994. The sequence is still the documented way to identify a processor that has <code>CPUID</code>, which means a piece of 1994 identification code is still load-bearing in code that thinks it is from 2020.)</em></li>
                    <li><strong>Measure the direction flag&rsquo;s cost in your own string code.</strong> <em>(Expect a <code>memmove</code>-based copy to be roughly the speed of the <code>DF=0</code> arm, and expect hand-written <code>rep movsb</code> to be close to it too. Then write a copy that runs with <code>DF=1</code> and watch it approach the 31.25&times; row at large sizes &mdash; and then find out why the libc never does this, which is that <code>rep movsb</code> is not actually the fastest string primitive on a modern part for small sizes and is only competitive above a threshold that is not 16 bytes.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/x86simd/lessons/x86-atomics">the previous concept</a> made every instruction atomic and this one says what atomicity does not buy. <a href="/courses/smp/lessons/smp-ordering">The SMP course's ordering concept</a> is where TSO is taught as a model, and the seven-arm table above is that model coming back as a number &mdash; and coming back <em>disagreeing</em> with the shape the model predicts, which is the most valuable thing in the section. <a href="/courses/smp/lessons/smp-atomic">Its atomic concept</a> owns the store buffer story; this page is the x86-64 evidence for it.</p>
                <p>Forwards. <a href="/courses/x86simd/lessons/x86-bytes">The last concept</a> is the artifact, and it is a change of subject that is not really a change: it encodes and decodes thirty vector instructions, and <strong>the fence table above is the reason a second reader matters</strong>. A decoder that switches on <code>ModRM.reg</code> alone gets two of the three fences right by accident, and a round trip through a decoder built from the same wrong table would report thirty perfect rows and be wrong about every one of them.</p>
                <p>Outward. The store buffer is the reason TSO exists as a model rather than as a prohibition, and it is the reason the language-level answer is a mutex and not a fence: a C11 <code>atomic_load</code> with <em>acquire</em> ordering compiles to nothing on x86-64, because the hardware already does it. <a href="/courses/smp/lessons/smp-ordering">The ordering concept</a> owns that translation and this page is the hardware half of it. And on an ARM machine the same source line becomes a <code>dmb</code> &mdash; so the fence you do or do not emit is a fact about <em>where the code runs</em>, which is the single most useful thing to carry out of the whole section.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86simd/lessons/x86-atomics">The Atomic Set: Which Instructions Imply LOCK</a></span>
                <span>Next: <a href="/courses/x86simd/lessons/x86-bytes">Thirty Encodings, Round-Tripped and Cross-Checked</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
