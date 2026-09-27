// How a CPU Executes Instructions — Module 2: Dependencies and the Front End
// Concept: what a dependency is, why the loop hid the first measurement, and
// how far an address constrains the front end.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_exe_deps() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("A Dependency Is a Constraint, Not a Cost — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson exe-lesson">
            <a href="/courses/exe" class="back-link">Back to course</a>
            <h1>A Dependency Is a Constraint, Not a Cost</h1>
            <div class="lesson-meta">24 min &middot; Module 2: Dependencies and the Front End &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p><a href="/courses/exe/lessons/exe-latency">The last concept</a> measured a ratio &mdash; 2.7&times; between dependent and independent execution &mdash; without saying what a dependency <em>is</em>. That is backwards, and this concept puts it the right way round: <strong>an instruction costs a latency because something constrains when it may start, and the cost is a consequence of the constraint rather than a property of the instruction.</strong></p>
                <p>There is a second thing a dependency can constrain, and this course found it by accident. <strong>Two byte-identical loops in one binary, differing only in their address, measured 0.79 and 2.13 ticks per iteration.</strong> No data dependency explains that, because the code is the same code. What differs is where the front end finds it.</p>
                <div class="hex-dump">
                    <pre>$ objdump -d cycbench | grep -A9 -E '&lt;b_dep1&gt;:|&lt;b_ind1&gt;:'
0000000000002c40 &lt;aligned_0&gt;:
0000000000002cc0 &lt;branchless&gt;:
0000000000003840 &lt;b_dep1&gt;:

$ ./noise2
  64-byte aligned body               min 1.0607  max 1.2190  spread 14.9%
  same body at offset 32             min 0.9956  max 1.2104  spread 21.6%
</pre>
                </div>
                <p>So this concept has two halves that look unrelated and are not: <strong>a data dependency is a constraint on when a register may be read</strong>, and <strong>an address is a constraint on when a block of bytes may be fetched</strong>. Both are the same kind of thing &mdash; a rule that says &ldquo;not yet&rdquo; &mdash; and both are invisible in the instruction stream.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>What a dependency is, in the smallest useful terms:</p>
                <div class="formula">
  A DEPENDENCY is a claim that instruction B
  cannot read its input until instruction A
  has produced it.

  RAW   read after write    A writes r, B reads r
                            -- the real one
  WAR   write after read    B reads r, A writes r
  WAW   write after write   A writes r, B writes r

  RAW is the dependency you cannot rename away.
  It is a fact about the DATA.

  WAR and WAW are artefacts of reusing a
  register name. Give each write its own name
  and they vanish -- which is exactly what
  register renaming does, in hardware, at
  rename time, for free.

  so: the hardware removes WAR and WAW by
  renaming, and RAW survives. that is the
  entire reason out-of-order execution is
  possible and also its entire limit.
                </div>
                <p>Which gives the rule that decides performance, and it is a one-liner:</p>
                <div class="formula">
  an instruction may start when its inputs
  are ready, not when the previous
  instruction finished.

  so what limits a straight-line region is
  the LONGEST chain of RAW dependencies in it,
  not the number of instructions.

    8 dependent adds    longest chain = 8
                        -> 8 latencies
    8 independent adds  longest chain = 1
                        -> 1 latency, and the
                           other 7 overlap it
                </div>
                <p>Now the second half, which is the same shape applied to bytes rather than registers. <strong>The front end has to fetch instructions, and it fetches them in blocks that begin at boundaries determined by the address.</strong> A loop that sits entirely inside one block is fetched efficiently; one that straddles a boundary needs two. The block size is not a matter of opinion &mdash; <a href="/courses/exe/lessons/exe-instrument">the instrument concept</a> measured the cache line at 64 bytes from <code>getconf</code> and the same number out of <code>/sys</code>.</p>
                <div class="formula">
  THE ADDRESS IS A DEPENDENCY TOO.

    the front end cannot start fetching a block
    until it knows where the block starts, and
    the block starts are fixed by the address.

    so: same code, different address, different
    fetch behaviour, different time. measured,
    up to 2.5x, with no difference in the
    instruction stream at all.

  and unlike a data dependency, this one is
  fixed at LINK time and cannot be renamed away.
  the hardware cannot undo where the linker
  put things.
                </div>
                <p>That asymmetry is the point worth carrying forward. <strong>A register dependency is a property of the code and the hardware works around it by renaming. An address dependency is a property of the link and the hardware cannot work around it at all.</strong> Which means the linker is a performance tool, whether or not it knows it &mdash; and <a href="/courses/link/lessons/link-phdrs">the linker-script course</a> has been placing sections without ever having had a timing in its model.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Address Measurement, and What It Does Not Explain</h2>
                <p>One loop body, byte for byte identical, emitted at eight offsets within a 64-byte boundary:</p>
                <div class="hex-dump">
                    <pre>$ ./cycbench 2&gt;&amp;1 | sed -n '/7. ALIGNMENT/,$p'
  7. ALIGNMENT: one body, seven addresses
  -------------------------------------
     The SAME 16-byte loop (add; dec; jnz; mov), byte for byte,
     preceded by identical padding. Only the address changes.

  body                                  min ticks     vs floor
  loop at offset  0 mod 64                 0.7645        1.15x
  loop at offset  8 mod 64                 0.8334        1.26x
  loop at offset 16 mod 64                 0.7716        1.16x
  loop at offset 24 mod 64                 0.8274        1.25x
  loop at offset 32 mod 64                 1.3533        2.04x
  loop at offset 40 mod 64                 0.6638        1.00x
  loop at offset 48 mod 64                 0.8394        1.26x
  loop at offset 56 mod 64 (CROSSES)       0.8554        1.29x

     fastest 0.6638   slowest 1.3533   ratio 2.04x
</pre>
                </div>
                <p><strong>2.04&times;, for identical instructions.</strong> That is the finding, and it is larger than anything in the latency table &mdash; bigger than the dependent-versus-independent ratio, bigger than the cost of the operations themselves. <strong>Where the linker puts a loop can matter more than what the loop does.</strong></p>
                <p>And here is where the honesty has to be, because the obvious story is wrong. The loop body is 12 bytes, so offsets 0&ndash;52 fit inside one 64-byte line and offset 56 does not. <strong>If crossing a line boundary were the whole mechanism, offset 56 would be the slow row. It is not &mdash; offset 32 is, and offset 40 is the fastest of all.</strong></p>
                <div class="formula">
  measured:  offset 32 is slowest (2.04x)
             offset 40 is fastest (1.00x)
             offset 56, the one that CROSSES, is 1.29x

  so the cost is NOT a simple function of
  offset mod 64, and this course does not
  claim a mechanism.

  plausible and UNMEASURED:
    an operation cache with its own indexing
    a loop stream detector
    per-address branch predictor state
    the decode/rename boundary width

  all four would explain a non-periodic
  pattern. none of them was measured here, and
  naming them is not the same as knowing one
  of them is the answer.
                </div>
                <p>So the effect is claimed and the cause is not. That is the whole discipline in one measurement, and it is worth being explicit about why it is the right call rather than a cowardly one: <strong>a mechanism you have guessed is a mechanism a reader will act on</strong>, and acting on a wrong one costs them an afternoon. An admitted unknown costs them nothing but the question.</p>
                <p>And the practical consequence is immediate and does not need the mechanism. <strong>Every bench function in the artifact is marked <code>aligned(64)</code>, and making that change was the single largest improvement to the instrument</strong> &mdash; it is what turned the latency table from a set of numbers that contradicted each other into monotonic series. The rest of this course&rsquo;s numbers exist because of that one attribute.</p>
            </div>

            <div class="unit unit-example">
                <h2>The Loop Dependency, and the Fix That Is Not Obvious</h2>
                <p>The other dependency in the measurement was there from the start and hid everything for several iterations. <strong>Every loop carries one, in its own counter.</strong></p>
                <div class="formula">
  the loop's own chain:

      dec  -&gt;  flags  -&gt;  jnz  -&gt;  next dec
        ^                            |
        +----------------------------+

    length 1. the body must fit in its shadow.

  with ONE operation in the body:

      loop overhead   1.109 ticks
      + one add       1.084 ticks   <- LESS

    the add is not free. it is FREE, because
    the branch was the bottleneck and the add
    hid underneath it. and "less than the empty
    loop" is the tell.
                </div>
                <p>The fix is to unroll, and it is worth being precise about <em>which</em> unrolling, because there are two and they fix different things.</p>
                <div class="formula">
  unroll the BODY   -- 8 operations, 1 iteration

    loop cost / 8. the body dominates and the
    marginal cost per operation becomes the
    operation's own. THIS is what the latency
    table does.

  unroll the LOOP   -- 1 operation, 8 iterations

    same arithmetic, but now you have divided
    the dec/jnz chain by 8 as well, and the
    loop can overlap its OWN body better.

  both work, and the second is why hand-
  optimised inner loops are unrolled in
  multiples of the SIMD width: the loop cost
  has to amortise, and it amortises over the
  number of operations the core can retire at
  once.
                </div>
                <p>There is a third dependency hiding in the same measurement, and finding it is what made the flags section honest. The <code>adc</code> in the branchless variant reads the carry flag that the <code>ror</code> before it wrote. That is a RAW dependency on a register with no rename:</p>
                <div class="hex-dump">
                    <pre>$ ./cycbench 2&gt;&amp;1 | sed -n '/4. THE FLAGS/,/5. BRANCHES/p'
  body                                  min ticks     vs floor
  loop floor                               0.6630        1.00x
  1 TEST  (WRITE flags only)               0.7385        1.11x
  2 TEST  (WRITE flags only)               0.6833        1.03x
  4 TEST  (WRITE flags only)               0.9582        1.45x
  4 ROR   (a CHAIN on one register)        3.5259        4.23x
  1 ROR+ADC (read AFTER write)             0.9427        1.13x
  2 ROR+ADC (read AFTER write)             1.7822        2.14x
  4 ROR+ADC (read AFTER write)             3.7130        4.46x
</pre>
                </div>
                <p>Read the third row and the fifth. Four <code>TEST</code>s, which all <em>write</em> the flags, cost <strong>1.45&times;</strong> the floor &mdash; nearly free. Four <code>ROR</code>s cost <strong>4.23&times;</strong> &mdash; and the difference is that they all target one register, so they are an ordinary RAW chain of length 4.</p>
                <p><strong>And the first explanation this course wrote down was wrong.</strong> It said the flags register has no rename, so flag-writing instructions serialise. The measurement says otherwise. So the obvious replacement was tried &mdash; &ldquo;reading the flags is what costs&rdquo; &mdash; and four <code>ROR</code>+<code>ADC</code> pairs measured 4.46&times; against 4.23&times; for the <code>ROR</code>s alone, a difference of 1.05&times;. Also wrong.</p>
                <p><strong>Three candidate explanations, two retracted, and the survivor is the boring one:</strong> it was always an ordinary dependency, and the flags were a red herring. That is recorded in the artifact&rsquo;s own output and asserted by the crosscheck, so it cannot quietly come back.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/exe/assets/samples
$ ./cycbench 2&gt;&amp;1 | sed -n '/4. THE FLAGS/,/5. BRANCHES/p'
$ ./cycbench 2&gt;&amp;1 | sed -n '/7. ALIGNMENT/,$p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^H /,/^I /p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^I /,$p'
</pre>
                </div>
                <p>Then go looking for dependencies in code you did not write:</p>
                <div class="hex-dump">
                    <pre>  1. Classify every instruction in a real loop as
     RAW, WAR or WAW, by hand. Take something
     small:

       objdump -d --section .text yourprog \
         | sed -n '/&lt;yourfunc&gt;:/,/^$/p'

     For each pair (A, B) ask: does B read a
     register A wrote?  That is RAW and it is the
     only kind that survives renaming.

     Now do the same for the ADDRESSES: which
     blocks does this loop span, and does it cross
     a 64-byte boundary? (You can count with the
     ISA course's decoder -- it reports offsets,
     and 0x40 bytes apart is a line.)

  2. Break a WAR/WAW on purpose and show the core
     does not care. Take a register that is written
     twice in a row and give the two writes
     different destinations:

       mov rax, 1
       mov rax, 2        # WAW on rax
       ret

       mov rbx, 1        # the second write goes
       mov rax, 2        # elsewhere: no WAW

     Time both. (Expect no difference at this
     size -- the effect of WAW elimination is real
     but you need enough of them to see it. Build
     a loop with 64 WAW pairs and compare with 64
     RAW pairs; the ratio is the renaming benefit
     and it should be close to the width.)

  3. Find a RAW chain that is not obvious, which
     is the kind that actually costs time:

       a = b + c;  d = a * e;  f = d - g;

     Three operations, but a LONGEST chain of 3,
     not 3 independent ones. Now:

       a = b + c;  d = x * e;  f = y - g;

     Same operation count, longest chain 1. This
     is the whole optimisation and it is what a
     compiler does when it reassociates floating
     point -- which it may NOT do without
     -ffast-math, because it changes the result.
     That is a dependency bought with correctness,
     and it is worth finding one in a compiler
     you use.

  4. Now measure the address effect properly, at
     all 64 offsets, and see whether YOUR curve
     is periodic:

       for (off = 0; off < 64; off++)
         build a binary with a loop at that offset
         time it

     (cycbench does 8 of the 64 with one binary.
     Doing all 64 needs 64 builds, or one build
     with 64 copies at 64 offsets. Either way,
     the shape is the result. This machine's
     curve is NOT periodic in 64 -- it is not
     periodic at all -- and your front end may
     well be different. The METHOD is what
     transfers: identical bytes, varying address,
     and treat the curve as a measurement of the
     front end rather than an explanation of it.)

  5. Finally, connect the two halves, because they
     are one thing and this is the exercise that
     shows it. Write a loop where the data
     dependency is short AND the address is bad,
     and one where each is the opposite, and
     confirm the two effects are additive rather
     than one masking the other.

       // short chain, well aligned
       for (i = 0; i < n; i++) { a[i] = b[i] + c[i]; }

       // long chain, well aligned
       for (i = 0; i < n; i++) { s = s * 3 + 1; }

       // short chain, badly aligned
       //   (pad the loop to start at offset 32)

     If the effects are additive you will see
     three distinct times. If the bad alignment
     MASKS the dependency cost, the two short-
     chain versions will measure the same -- and
     that would be the more interesting result,
     because it would mean the front end, not the
     data path, is the limit for a large class
     of real code.
</pre>
                </div>
                <p>Exercise 5 is the one that unifies the concept, and its outcome is genuinely uncertain, which is why it is worth doing. <strong>If the address effect and the dependency effect are additive, this course has two independent stories. If they mask each other, the front end dominates and the latency table in module 1 describes a machine that most real code never reaches.</strong> Either answer is worth having, and the measurement is twenty lines long.</p>
                <p>Exercise 2 is the one that makes renaming real rather than a slogan. <strong>The ratio between a WAW-heavy loop and a RAW-heavy loop of the same length <em>is</em> the renaming benefit</strong>, and it should come out close to the execution width from <a href="/courses/exe/lessons/exe-latency">the latency concept</a> &mdash; two completely separate measurements landing on the same number, which is the kind of agreement the collection treats as evidence.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The connection to <a href="/courses/link/lessons/link-phdrs">the linker-script course</a> is the practical payload of this concept, and it is a debt that course could not even see. That course found the default script&rsquo;s section placement rules and their effect on the output, and had no reason to ask whether the placement cost anything &mdash; <strong>because nothing in the format records a time.</strong> This concept supplies the missing term: section alignment is not tidiness, it is up to a factor of 2.5 in execution time for a loop that happens to straddle a boundary, and it is fixed at link time in a way the hardware cannot undo. Every linker discussion in the collection up to this point has been about <em>what goes where</em>; this is the first measurement of <em>what where costs</em>.</p>
                <p>The connection to <a href="/courses/reloc/lessons/pie-cost">the PIC-cost concept</a> is a genuine trade the two courses disagree about, and the disagreement is the point. That course measured nine instructions against seventeen for the same computation and concluded PIC costs more. <strong>This concept supplies the reason that conclusion may be wrong:</strong> seventeen instructions with a longer chain is not necessarily slower than nine with a shorter one, because the extra instructions may be independent. Both are measurable, neither was measured against the other, and the resolution needs a timing experiment that spans both courses. <a href="/courses/reloc/lessons/reloc-encoding-limits">The encoding-limits concept</a> is the other half of that argument, since it is the <code>disp32</code> that makes the extra instruction necessary.</p>
                <p>Two connections outward. <a href="/courses/isa/lessons/isa-sib">The SIB concept</a> measured the one-byte instruction that exists so a compiler can write <code>base + index*scale</code> without a scratch register, and explicitly said it saves about twelve bytes and two instructions. <strong>This concept is the measurement that makes that saving worth having:</strong> two instructions that do not destroy a register are two more independent operations, and the marginal cost of an independent operation was measured at about a quarter of a dependent one. So the ISA course&rsquo;s encoding feature and this course&rsquo;s execution measurement are the same fact seen from the compiler&rsquo;s side and the CPU&rsquo;s, and each is useless without the other.</p>
                <p>And the connection to the <a href="/courses/obj/lessons/obj-verify">object course&rsquo;s oracle loop</a> is methodological rather than technical, and it is the reason this concept exists in the shape it does. That concept established the discipline of checking a value against a source that did not produce it. <strong>Here the discipline produced the course&rsquo;s single most useful result by accident</strong> &mdash; the apparent noise turned out to be a fixed per-address penalty &mdash; and it did so because a variance figure is a claim about your <em>setup</em> before it is a claim about your machine, and nobody had looked. The check that would have caught it was the obvious one: <em>are these two functions byte-identical?</em> They were not supposed to differ, and they did not &mdash; which is exactly what made the difference visible.</p>
                <p>One limit, and it bounds the concept on both sides. <strong>The address effect is measured and its mechanism is not</strong>, so this concept can say &ldquo;the address of a loop is worth up to 2.5&times;&rdquo; and not why; and the data-dependency half is measured on integer <code>add</code> in a synthetic loop, so the latency is this machine&rsquo;s integer-add latency and nothing more general. No floating point, no vector unit, no multiply, and no memory operand was measured &mdash; the last of those is where the real limit usually lives, and it is the subject of the memory-hierarchy course.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/exe/lessons/exe-latency">Previous: Latency and Throughput</a></span>
                <span>Next: <a href="/courses/exe/lessons/exe-frontend">The Front End and the Branch Predictor</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
