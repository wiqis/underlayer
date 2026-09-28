// Multiprocessor Architecture — Concept 6: three answers to two questions
public namespace underlayer_content {

using std::string

using std::string_view

public func render_smp_three() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Three Answers to Two Questions — Underlayer")
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
            <h1>Three Answers to Two Questions</h1>
            <div class="lesson-meta">26 min &middot; <a href="/courses/smp">Multiprocessor Architecture</a></div>

            <div class="a11y-note" style="display:none">
                <p><strong>A note on this concept's evidence, before anything else.</strong> Everything below is quoted from architecture manuals and from the RISC-V specification. <em>None of it was measured</em>, because this course was written on x86-64 and there is no AArch64 or RISC-V machine in the room. The artifact prints the same limit in its own limits block &mdash; <em>THE OTHER TWO ARCHITECTURES. Section 6 is quoted, not run.</em> <strong>Read this as a shape to look for on hardware you do have, not as a set of facts about hardware you do not.</strong> Every claim carries a document, and the one thing that <em>is</em> measured here &mdash; the fact that an uncontended atomic costs several times a plain store &mdash; is a fact about x86-64 and about no other architecture.</p>
            </div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Three of the five rows in the shape below have been the same on every desktop CPU for thirty years, which is why &ldquo;cache coherence&rdquo; feels like one technology rather than three implementations of a specification. <strong>The other two rows are where the architectures genuinely differ, and those two rows are exactly what decides whether a lock-free algorithm you wrote on one of them is correct on another.</strong></p>
                <p>The two questions are the two promises from <a href="/courses/smp/lessons/smp-atomic">the atomic concept</a> and <a href="/courses/smp/lessons/smp-ordering">the ordering concept</a>, taken one level up:</p>
                <ol>
                    <li><strong>How do you make an update indivisible?</strong> Two cores must not interleave a read-modify-write of the same location.</li>
                    <li><strong>How do you order the accesses around it?</strong> Two cores must not observe the accesses on either side in an order that contradicts the program.</li>
                </ol>
                <p>On x86-64 the answer to both is one bit in an instruction prefix. <strong>That is the whole design decision, and it is a decision with a price that this course measured:</strong> because <code>lock</code> implies a full barrier, every atomic operation on x86-64 also pays for ordering whether or not the program needed it &mdash; which is why an uncontended <code>fetch_add</code> costs 2.54&times; a plain store on this machine with nothing to contend against.</p>
                <p>AArch64 answers the first question with instructions that carry a mode and the second with instructions that carry a different mode. RISC-V answers the first with an instruction pair that may have to be retried and the second with a fence whose operands say which edges you want. <strong>Three genuinely different designs for the same two questions</strong>, and the interesting part is not that they differ &mdash; it is that two of them let you pay for only one of the answers.</p>
                <div class="formula">
   R5. "`lock` is one idea that could have been three."  The x86-64
       design ties ATOMICITY and ORDERING to one prefix, so every
       atomic operation is also a full barrier.  AArch64 makes them
       separate instructions and RISC-V makes them a fence with chosen
       edges.  A lock-free algorithm written on x86-64 is therefore
       correct partly BY ACCIDENT: it relies on an ordering guarantee it
       never asked for, because the hardware supplied it for free.  Port
       that algorithm to a weakly-ordered machine and it is wrong, and
       the tests that passed on the first machine will not find it.
                </div>
                <p>That is the retraction this concept is built around, and the phrase to dwell on is <strong>by accident</strong>. The x86-64 algorithm is not wrong. It is not even fragile. It is correct for a reason its author did not know they were relying on, and they cannot know they were relying on it because on that machine there is no experiment that distinguishes &ldquo;I asked for ordering&rdquo; from &ldquo;I got it free&rdquo;.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: the same five-part shape, and it recurs</h2>
                <p>The privilege course found this shape for traps and it turns out to be the same shape for coherence, which is worth noticing because it is the second time in this collection that five questions have produced five parts:</p>
                <div class="formula">
                    x86-64      AArch64       RISC-V

  1. a unit of sharing      a cache line  a cache line  a location
  2. a state machine        MESI          MESI          MESI
  3. a way to notice        a snoop       a snoop       a snoop
     a change
  4. an atomic update       LOCK          LDAR-STLR     LR-SC
  5. a way to order it      a prefix      an access     a FENCE
                                         mode
                </div>
                <p><strong>Rows 1, 2 and 3 are why the word &ldquo;coherence&rdquo; feels like one thing.</strong> The unit of sharing is a cache line everywhere, because a cache tracks lines and not variables. The state machine is MESI everywhere, because MESI is the minimum state set that lets a core know whether it may read a line without asking. And every cache watches for changes &mdash; a snoop &mdash; because that is the cheapest way to notice that somebody else just wrote the line you hold. <strong>Change none of those three and you have not changed the architecture; you have changed the vendor.</strong></p>
                <p>Rows 4 and 5 are where the design decisions live, and they differ in kind rather than in spelling:</p>
                <div class="hex-dump">
                <pre>x86-64
  the ordered atomic  a `lock` PREFIX.  On x86 it implies a full
                      barrier, which is why an uncontended atomic still
                      costs several times a plain store -- section 3.
  the order           STRONG: loads and stores are not reordered
                      with other loads and stores, so an ordinary
                      fence is REDUNDANT here and the same source
                      needs one elsewhere.
  what is hardware    the LINE and the atomic instruction.  The
                      PROTOCOL is microcode, not an instruction
                      anyone can execute.

AArch64
  the tagged accesses an INSTRUCTION: LDAR, STLR, LDAXR/STLXR.  The
                      acquire and the release are things you WRITE,
                      which is a different design from a prefix.
  the cost            an acquire load costs what a plain load costs
                      plus the wait; the barrier is not a separate
                      instruction you sprinkle, it is a MODE the
                      access itself has.  On x86 the same guarantee is
                      attached to every locked instruction whether you
                      wanted it or not.
  the order           WEAK by default.  Two cores may observe stores
                      in different orders.  THIS is the real reason
                      the fence in section 4 is not redundant in
                      general -- it is redundant HERE, and the source
                      has to say so with an intrinsic.

RISC-V
  the order           WEAK, and the fences are FENCE instructions
                      whose OPERANDS say which edges you want:
                      FENCE rw,rw orders reads before writes,
                      FENCE w,r does the other pair.
                      A single FENCE orders everything.
  the atomics         LR/SC.  The load-reserved does NOT lock the
                      line and the store-exclusive only succeeds if
                      nothing else wrote in between, so a CONTENDED
                      atomic is a RETRY LOOP BY CONSTRUCTION rather
                      than by accident.  The opposite trade from x86's:
                      no unconditional line acquisition, and unbounded
                      retries under contention.
  the cost            an LR/SC pair is two instructions where x86
                      spends one.  The win is that the uncontended
                      case touches nothing it does not need to.
                </pre>
                </div>
                <p>Three different trades, and each is a coherent position rather than an oversight:</p>
                <ul>
                    <li><strong>x86-64 buys simplicity at the price of paying for everything.</strong> One prefix, one guarantee, no room for the programmer to ask for less. The programmer who only needs atomicity cannot have it without the barrier.</li>
                    <li><strong>AArch64 buys expressiveness with instructions.</strong> The programmer can say exactly which guarantee they want, on each access. The cost is vocabulary: four instruction forms to learn where x86 needs one.</li>
                    <li><strong>RISC-V buys the cheapest uncontended case and pays in retries.</strong> <code>LR</code>/<code>SC</code> does not take the line, so an uncontended pair touches almost nothing; under contention the retries are unbounded and the algorithm has to be written to tolerate them, which is a much larger burden on the programmer and a much smaller one on the uncontended path.</li>
                </ul>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: why rows 4 and 5 decide whether your algorithm ports</h2>
                <p>Here is the concrete version of the accident, stated as a diff you could actually make:</p>
                <div class="formula">
   /* Correct on x86-64.  Also correct on AArch64 and RISC-V,
      but for a reason the author did not choose. */
  payload = *p;               /* read  */
  ready   = 1;                /* write */

   /* On a weakly-ordered machine the write to `ready` may
      become visible before the read from `*p` completes, and
      the reader can see ready==1 with a stale payload.

      On x86-64 this cannot happen.  Not "is unlikely to",
      CANNOT.  Which is why the test suite passed. */
                </div>
                <p>That is not a hypothetical program shape; it is the message-passing loop from <a href="/courses/smp/lessons/smp-ordering">the ordering concept</a> with the fence removed, and it is the shape of most of the code in every lock-free queue, hazard pointer scheme and seqlock anyone has written. <strong>On x86-64 the author gets the ordering for free from the atomic store, and on the other two machines they get it from the store's own mode or from a fence &mdash; and neither of those is implicit.</strong></p>
                <p>Two consequences follow, and the second is the one that bites.</p>
                <p>The first is about the source. <strong>A program that is correct on x86-64 by accident is a program that is wrong on AArch64, and it is wrong in a way that will reproduce once in a million times</strong> &mdash; the same profile as the race in <a href="/courses/smp/lessons/smp-sharing">the sharing concept</a>, which is not a coincidence. Weak ordering does not make a program wrong immediately, it makes it wrong occasionally, and occasionally is the hardest thing to test for.</p>
                <p>The second is about the tests. <em>Port that algorithm to a weakly-ordered machine and it is wrong, and the tests that passed on the first machine will not find it.</em> Not &ldquo;may not&rdquo; &mdash; <strong>will not</strong>, and the reason is structural: the tests exercise the machine they were written on, and the machine they were written on cannot exhibit the bug. <strong>The only real defences are to write the ordering explicitly so that the weak target gets it, and to run the algorithm on a weak target</strong>, which is why emulators, simulators and litmus tests exist, and why &ldquo;it passed on my laptop&rdquo; is a statement about one architecture.</p>
                <h3>The one place the difference is a single line</h3>
                <div class="hex-dump">
                <pre>   the difference   a fair queue is one line of assembly on RISC-V
                   and a data structure on x86.
                </pre>
                </div>
                <p>On RISC-V a contended atomic <em>is</em> a retry loop by construction: <code>LR</code> reserves nothing, <code>SC</code> fails if anyone wrote in between, and you loop. That makes a ticket lock &mdash; fetch a number, spin until it is yours, do the work, bump the number &mdash; something the hardware already does for you. On x86 the retry loop does not exist at that level, so a fair queue needs backoff, parking, or a lock-free structure with its own proof. <strong>The same requirement, on two machines, is one instruction pair on one and a data structure on the other</strong>, and that difference is a direct consequence of whether the atomic operation is allowed to fail.</p>
                <p>Read the E state back into this, because it is the one place where x86-64 has an <em>extra</em> cost that the others do not. E exists so that a core that <em>knows</em> it is the only reader can answer a read without invalidating anybody. It is an optimisation and its price is a state the other two do not carry, which means a line can be in a state that is neither the sharer's nor the modifier's and both caches have to be able to answer &ldquo;is that mine&rdquo; about it. <strong>Every one of the three designs pays something the other two do not, and the shape with five rows is where those payments are written down.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: what changes when you port the counter from this course</h2>
                <p>Take the one line of code this course measured most carefully and translate it. The bodies were inline assembly, which is exactly the situation where the answer is not portable and where a reader most needs the shape:</p>
                <div class="formula">
  x86-64     __asm__ volatile("lock xaddq %0, %1"
                       : "+r"(r), "+m"(cell) :: "memory");
             one instruction.  atomic AND ordered.  costs
             ~2.5x a plain store even uncontended.

  AArch64    ldxr  %w0, [%1]        ; load-exclusive
             add   %w0, %w0, #1
             stxr  %w2, %w0, [%1]    ; store-exclusive
             cbnz  %w2, retry        ; it FAILED
             retry:
             ...
             a relaxed increment needs no dbar and no barrier
             at all.  an acquire/release pair adds one.

  RISC-V     lr.w  a0, (a1)
             addi  a0, a0, 1
             sc.w  a1, a0, (a1)
             bnez  a1, retry
             ...
             FENCE r,rw orders reads before writes;
             FENCE rw,w orders the other pair.  A bare
             FENCE orders everything and is expensive.
                </div>
                <p>Three observations, and each one is a lesson rather than a fact about an ISA:</p>
                <p><strong>On x86-64 the one-instruction form is a liability in portable source.</strong> You have written an x86 instruction into a program that may be compiled for something else, and no compiler can know you meant &ldquo;order my stores.&rdquo; If the code is going to be compiled for more than one target, the atomic has to be a library type with per-target implementations, and the implementation is the whole subject of this concept.</p>
                <p><strong>On AArch64 and RISC-V the uncontended case gets cheaper and the contended case gets harder.</strong> Neither takes the line unconditionally, so a counter that is mostly uncontended is genuinely cheaper than the x86 form &mdash; and a counter that is contended will spin. <strong>A <code>fetch_add</code> that never fails is a different primitive from one that may fail, and code written for the first does not port to the second without a retry loop somewhere.</strong></p>
                <p><strong>On RISC-V the ordering is a separate thing with a price list.</strong> <code>FENCE rw,rw</code> and <code>FENCE w,r</code> are cheaper than a bare <code>FENCE</code> because they order fewer edges. That is the one design on this list where the hardware lets you ask for exactly the guarantee you need, and it is also the one that puts the most responsibility on the person writing the code.</p>
                <p>And the portable conclusion, which is the thing to remember from all three: <strong>the unit of sharing and the protocol are not yours to choose, and the atomic update and the ordering are.</strong> If you are writing a compiler backend, rows 1 to 3 mean your target's line size is a fact you must look up rather than a parameter you invent. If you are writing a library, rows 4 and 5 mean the ordering you request is part of your API and part of your cost model, and both are target-dependent.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Find the atomic your program uses that you did not choose deliberately.</strong> Grep your source for <code>std::atomic</code>, for <code>atomic_add</code>, for a compiler intrinsic, and for anything inside a lock you wrote yourself. For each hit, answer: <em>which of the five rows does this depend on, and would it still be correct if row 5 were absent on this target?</em> <em>(Expect the answer &ldquo;no&rdquo; for most of them, and expect that most of them are correct anyway &mdash; because you are compiling for one architecture and the architecture supplies the guarantee. The exercise is not to fix them; it is to be able to state which guarantee each one is silently borrowing.)</em></li>
                    <li><strong>Write the same increment in all three forms and count the instructions.</strong> From the block above. <em>(Expect one on x86-64, three on AArch64 with the retry branch, three on RISC-V with the retry branch. Then answer the interesting question: which one is faster when uncontended and which one is faster when contended? The answers are not the same, and &ldquo;RISC-V is slower&rdquo; is a statement about a case you have not specified.)</em></li>
                    <li><strong>Test for the accident.</strong> Take a lock-free structure and compile it for AArch64 if you can, or run it under an emulator that models weak ordering, and run it until it is obviously wrong. <em>(Expect it to be wrong &mdash; the point of the exercise is that it is now wrong on purpose rather than by a schedule nobody will ever find for you. Then add the explicit acquire/release or fence and confirm it is right again. This is the only version of the &ldquo;test that passed on x86-64&rdquo; argument that has ever convinced anybody.)</em></li>
                    <li><strong>Explain the E state's price in one sentence a hardware engineer would accept.</strong> Why is <em>exclusive</em> a state x86-64 carries and the other two do not? <em>(Expect the answer to be about answering a read without invalidating: a core that knows it is the only reader can serve a read locally. And expect the honest follow-up, which is that a line in E is a line whose validity is a <em>promise</em> rather than an observable, so the state exists to avoid a bus transaction at the price of a state nobody else has to understand.)</em></li>
                    <li><strong>Read your compiler's output for an <code>atomic&lt;int&gt;</code> store, relaxed and seq_cst, for every target you can build for.</strong> <em>(Expect x86-64 to emit the same <code>xchg</code> for both, because the prefix already implies the barrier and the compiler has nothing to add. Expect the weakly-ordered targets to emit visibly different code for the two. That difference is the entire content of R5 in about eight lines of disassembly, and it is the thing you would have to generate correctly in a backend.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/smp/lessons/smp-numa">the NUMA concept</a> established the machine's boundary: one memory domain, so nothing here is a distance measurement. This concept is what makes the boundary irrelevant. <strong>Rows 1 to 3 of the shape are identical on all three architectures and are all about a cache line, which is a thing inside one socket.</strong> The topology question &mdash; how many memory controllers, how many nodes &mdash; is a sixth question that none of the three answers, and the machine you would need for it is the machine this course does not have. Forward, <a href="/courses/smp/lessons/smp-harness">the harness concept</a> is where the course's central claim &mdash; that B/C is a shape and not a value &mdash; is turned into a rule, and it is the concept that has to carry this one honestly: <em>this section's contents are quoted, so the harness asserts that it says so.</em></p>
                <p>Outward, the nearest neighbour in the collection is <a href="/courses/priv/lessons/priv-three">the privilege course's three-architectures concept</a>, and reading the two together is the point. That one found the same five-part shape for exceptions and privilege &mdash; a table, a reason code, a rule for who handles it, a way back, a way to prove the event came from user mode &mdash; and found the same asymmetry: <strong>the first three parts are the same everywhere and the last two are where the vendors differ.</strong> Two unrelated subsystems, one shape, the same asymmetry. That is a stronger result than either course could claim alone, and it is the argument for teaching the shape rather than the vendor's vocabulary.</p>
                <p>The other outward link is the one a compiler author needs. <a href="/courses/isa/lessons/isa-decode">The ISA course's decoder</a> gives you the bytes of an instruction and nothing about what they may do to memory; <code>F3</code> in front of an <code>ADD</code> is one byte and one extra guarantee, and this concept is the layer that says what the guarantee is and what it costs. <strong>That byte is the entire difference between 2.64 ticks per operation and 1.04</strong>, and a backend that emits it unconditionally has made a performance decision as well as a semantic one.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/smp/lessons/smp-numa">The Thing This Machine Cannot Do</a></span>
                <span>Next: <a href="/courses/smp/lessons/smp-harness">The Harness, and the Six That Refused to Go Quietly</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
