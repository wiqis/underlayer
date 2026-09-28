// SIMD and Vector Processing — Concept 5: alignment, the gather, and the tail
public namespace underlayer_content {

using std::string

using std::string_view

public func render_simd_boundaries() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Alignment, the Gather, and the Tail — Underlayer")
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
            <h1>Alignment, the Gather, and the Tail</h1>
            <div class="lesson-meta">27 min &middot; <a href="/courses/simd">SIMD and Vector Processing</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Everything so far was about a loop over <strong>consecutive</strong> elements, where a wide instruction is a straightforward win. This concept is about the three places that stops being true, and all three cost more per element than a 4-wide add does.</p>
                <p>Start with the one everybody gets wrong, because it is the one the measurement refuses to confirm. The folklore is that unaligned vector loads are slow &mdash; that a misaligned 32-byte load costs you because it straddles a cache line. The artifact measures it at two working-set sizes:</p>
                <div class="hex-dump">
                <pre>$ ./simdbench | sed -n '/arm  /,/^      unaligned instruction/p'
   arm                                                               ns/iter  vs arm 1
   _mm256_load_pd   (DEMANDS 32B) on a 32-byte aligned address          7.58     1.00x
   _mm256_loadu_pd  (demands nothing) on a 32-byte aligned address       7.13     0.94x
   _mm256_loadu_pd  (demands nothing) on a +8 MISALIGNED address        7.58     1.00x

      unaligned instruction, aligned address / aligned instruction   0.94x
      MISALIGNED address / aligned address                           1.00x
  </pre>
                </div>
                <p><strong>All three are within 6% of each other, and the spread moves between runs</strong> &mdash; one of them even came out <em>faster</em> than the others. That is the signature of no effect rather than a small one: a real cost of alignment would be a consistent ordering. The same comparison at 2&nbsp;MiB per stream, past the L2, came out at 0.92&times;, 1.29&times; and 1.00&times; on the three recorded runs &mdash; <strong>no consistent direction</strong>, which is what &ldquo;no effect&rdquo; looks like when the arm is bandwidth-bound and the run is noisy. On this machine an unaligned 32-byte vector load of memory is <strong>free</strong>.</p>
                <p>So why does <code>_mm256_load_pd</code> exist? Because the requirement is a <strong>fault</strong> requirement, and the artifact measures that separately &mdash; by forking a child process and catching what comes back:</p>
                <div class="hex-dump">
                <pre>      _mm256_load_pd on a +8 address, in a child process: raised SIGSEGV (signal 11)
  </pre>
                </div>
                <p><strong>The two instructions differ in a way the table above cannot time: one of them is a legal program and the other is not.</strong> That is worth a whole paragraph, and it generalises: <em>check whether the thing faults before you spend a benchmark on asking how slow it is.</em> A duration table is the wrong instrument for a correctness requirement.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: a wide instruction is worth what the addresses allow</h2>
                <p>With the alignment surprise out of the way, the model that explains all three of this concept's findings is one sentence:</p>
                <div class="formula">
   A WIDE INSTRUCTION IS WORTH WHAT THE ADDRESSES ALLOW.

     Four CONSECUTIVE addresses: the load unit fetches
     32 bytes for the four lanes either way, one memory
     operation serves them all, and the width is pure win.
     This is the case every optimisation is written for.

     Four SCATTERED addresses: the four accesses are
     INDEPENDENT, and independent memory operations cannot
     be overlapped, because the memory system has no way to
     know they are unrelated.  The width buys you arithmetic
     you could have had anyway and charges you for the
     independence you just lost.

   So: a permuted access is a SCATTER, a GATHER, a
   TRANSPOSE or a SHUFFLE, and on every one of those the
   width is a COST until measured otherwise.
                </div>
                <p>And the gather is where the sentence is worth the most, because the instruction designed for the job is the slowest thing in the table:</p>
                <div class="hex-dump">
                <pre>$ ./simdbench | sed -n '/arm  /,/hand gather, four scalar/p'
   arm                                                                  ns/iter  vs arm 1
   four SEQUENTIAL addresses: 3 loads, 1 store, 1 fma per 4 elements          13.01     1.00x
   hand gather: FOUR SCALAR LOADS, then build the vector, then 1 fma          26.81     2.06x
   hardware gather: vpgatherdd, one instruction for the same four loads      74.54     5.73x

      the hand gather, against the SEQUENTIAL loop it replaces    2.06x
      vpgatherdd, against the same sequential loop                 5.73x
      vpgatherdd, against FOUR ORDINARY SCALAR LOADS                2.78x
  </pre>
                </div>
                <p><strong>The gather instruction is 2.78&times; slower than four ordinary scalar loads.</strong> Read that again, because it is the sentence the whole section exists for. <code>vpgatherdd</code> is not one instruction doing four things at once. It is one instruction doing four <em>independent</em> loads, and the memory system cannot overlap them. The instruction saves the register moves and charges a decode penalty for them.</p>
                <p>This is not a compiler artefact &mdash; both arms are intrinsics in the same translation unit, with the same flags, in the same loop nest. And it is the same finding as the FMA row in the previous concept's table, with a bigger multiplier: <strong>an extra instruction you did not need costs a fetch and a decode slot, and on a loop that is not short of either, removing one buys nothing.</strong> Here the arithmetic runs the other way &mdash; the wide instruction is the extra one.</p>
                <p>There is a genuine caveat, and the artifact states it: this is measured on <em>gather</em>. A <em>segment load</em> &mdash; a strided run rather than an arbitrary index list &mdash; is a different instruction with a different contract, and on some microarchitectures it is a genuine win. <a href="/courses/simd/lessons/simd-three">The three-architectures concept</a> covers the one that exists for exactly this job.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: the tail, and why the clever answer is the slow one</h2>
                <p>Now the third cost, and the one that has a mask register's entire reason for existing. A 66-element loop with a 4-wide instruction leaves two elements over, and this machine has no AVX-512, so there is no <code>k</code> register to say &ldquo;only two of these four lanes&rdquo;. Three strategies, and two of them are wrong:</p>
                <div class="hex-dump">
                <pre>$ ./simdbench | sed -n '/64 elements/,/CONTROL: a PART/p'
   64 elements, 4-wide, NO TAIL at all                (the reference)      12.71     1.00x
   66 elements, 4-wide + a SCALAR remainder of 2                         12.94     1.02x
   66 elements, 4-wide + one OVERLAPPING iteration, 2 valid lanes stored      22.50     1.77x
   68 elements, plain 4-wide: WRITES 2 ELEMENTS PAST THE END OF THE ARRAY      13.91     1.09x
   CONTROL: a FULL 32-byte overlap (load exactly what was stored)        13.95     1.10x
   CONTROL: a PARTIAL overlap load, only 1 lane stored back              16.62     1.31x
  </pre>
                </div>
                <p>Four findings, in order of how surprising they are.</p>
                <ul>
                    <li><strong>The scalar remainder is free: 1.02&times;.</strong> Two elements out of 66 is 3% of the work and it costs 2%. This is the right answer and it is not a trick &mdash; it is a <code>for</code> loop with a scalar body.</li>
                    <li><strong>The overlapping last iteration is 1.77&times; &mdash; the worst arm in the table</strong>, and it is the one that is supposed to be the clever one. On a machine with no mask, the textbook trick is to run one more 4-wide iteration starting at element 62 and store only the two lanes that exist.</li>
                    <li><strong>The two controls say why</strong>, which the overlapping arm on its own does not. A <em>full</em> 32-byte overlap is 1.10&times; and a <em>partial</em> overlap load is 1.31&times;. So the cost is not &ldquo;doing the tail&rdquo; &mdash; it is the load at +62, which <strong>overlaps the 32-byte store at +60 by half</strong>. A load that overlaps a recent store only partly cannot be <em>forwarded</em> from the store buffer; it has to wait for the store to reach the cache. The overlapping trick reads back the very line it has just written, half-aligned, and that is the slowest thing in the table.</li>
                    <li><strong>The arm that writes past the end is cheap (1.09&times;) and it is a bug.</strong> It writes two elements into memory the array does not own. The array in the artifact is declared with eight spare doubles, which is why it does not crash and why it is a bug rather than an accident. A vector loop that over-reads and over-writes its tail is a portable program that gets faster by writing to memory it does not have.</li>
                </ul>
                <p>And the mechanism in point 3 is marked <strong>INFERRED</strong> in the artifact, not measured, because there is no PMU on this machine and nothing above is a count of anything. It is a mechanism with two controls supporting it, which is the strongest kind of claim this hardware can support. The controls are the point: a single measurement of &ldquo;the overlapping trick is slow&rdquo; would have been a story, and two controls that separate the full overlap from the partial one make it an argument.</p>
                <div class="formula">
   THE ORDERING, which is the thing to remember:

     on a machine WITHOUT a mask register, WRITE THE TAIL
     SCALAR.  It is free, it is correct, and the clever
     alternative is the most expensive row in the table.

   And this is exactly what a mask register is for.  A
   masked store uses a bit per lane to say which lanes to
   KEEP, so the last iteration of a 66-element loop is
   the same instruction as every other iteration with two
   lanes switched off -- no epilogue, no branch, no
   partial-overlap load, and nothing written past the end.

   SVE calls this PREDICATION and RISC-V V does it with vl
   (the vector length register).  AArch64 NEON and x86-64
   without AVX-512 do not have it, and both arrive at the
   same answer this table measured: peel it.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the three rules, and the two that are not what they look like</h2>
                <p>Collecting this concept into something a code generator can use:</p>
                <div class="formula">
   1. ALIGNMENT IS A CORRECTNESS REQUIREMENT HERE, NOT A
      SPEED ONE.
         _mm256_load_pd   demands 32-byte alignment and
                          FAULTS without it (measured, in a
                          forked child: SIGSEGV).
         _mm256_loadu_pd  demands nothing and costs the
                          same (measured, twice, at L1 and
                          past the L2; the L1 arms agree
                          within 6% and the 2 MiB arm has no
                          consistent direction across three
                          runs, which is what no effect
                          looks like when the loop is
                          bandwidth-bound anyway).

         So emit the aligned form when you KNOW the address
         is aligned -- it is a smaller decoder case and it
         is one fewer thing to have to be right about -- and
         do not expect it to be faster on this machine.  On
         some other microarchitecture it is.

   2. A GATHER IS NOT A WIDE INSTRUCTION.
         vpgatherdd       2.78x four ordinary scalar loads
         hand gather      2.06x a sequential 4-wide load
         sequential       1.00x

         If you have an indirect access, the default on this
         machine is FOUR SCALAR LOADS and a vector built
         from them.  A segment load for a regular stride is
         the case where a wide instruction may still win.

   3. THE TAIL IS FREE IF YOU DO IT SCALAR AND EXPENSIVE
      IF YOU DO IT CLEVERLY.
         scalar remainder      1.02x
         overlapping iteration 1.77x   <- the clever one
         writing past the end   1.09x   <- and a bug
                </div>
                <p>Two of these deserve a note about what they are <em>not</em>, because both are commonly over-generalised.</p>
                <p><strong>Rule 1 does not survive a page boundary.</strong> A 32-byte load whose last bytes are in the next 4&nbsp;KiB page is a different case, and the artifact says so in its limits block: it has no PMU, it did not measure a page-crossing vector load, and it does not claim anything about one. The measured &ldquo;free&rdquo; is free <em>within a page</em>, and that is the only claim being made.</p>
                <p><strong>Rule 2 is about an arbitrary index list.</strong> A gather whose four addresses happen to be adjacent is a sequential load wearing a gather's clothes, and the microarchitecture may detect that. What was measured is a permutation &mdash; <code>index[j] = (j * 7) &amp; 63</code> &mdash; which is the realistic case for indirect array access and which the compiler cannot fold back into a load.</p>
                <p>And the general form of all three, which is the sentence the section is built on: <strong>the width is a property of the register, and whether it is a benefit is a property of the addresses.</strong> Everything in this concept is that sentence in three costumes, and every one of them cost more than the 4-wide add does. <em>Optimise for the shape of the access, not for the size of the register.</em></p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce all three tables and read the surprising one first.</strong> <em>(Expect the alignment arms to be indistinguishable, expect <code>vpgatherdd</code> to be several times the hand gather, and expect the overlapping tail to be the worst row. If the alignment arms differ sharply, you are on a microarchitecture where the folklore is true &mdash; check the disassembly for a <code>vmovupd</code> that became two operations, and treat your result as a fact about that machine and not a contradiction of this one.)</em></li>
                    <li><strong>Do the fault experiment yourself, because it is thirty seconds.</strong> Write a two-line program that calls <code>_mm256_load_pd</code> on <code>ptr + 1</code> and run it. <em>(Expect SIGSEGV, immediately, with no output. Then add <code>__attribute__((aligned(32)))</code> to a local array and do it again, and note that the compiler now knows the address is aligned and will not let you make the mistake. That is the real reason aligned loads exist in a compiler: <em>they are an assertion the compiler can check and you cannot get wrong accidentally</em>.)</em></li>
                    <li><strong>Replace a gather with four scalar loads in real code and measure.</strong> Find an indirect access &mdash; a sparse lookup, a particle gather, a <code>pixels[i * stride]</code> where <code>stride</code> is a variable. <em>(Expect a win of around 2&ndash;3&times; over the hardware gather and roughly parity with whatever the compiler was doing. If the win is larger, check whether the compiler was emitting a gather at all &mdash; most do not, and the baseline you are comparing against may be something else entirely.)</em></li>
                    <li><strong>Take a vectorised loop with a runtime length and add the tail three ways.</strong> Scalar remainder, overlapping iteration, and padded array. <em>(Expect the scalar remainder to cost nothing, the overlap to be the most expensive, and the padding to be fastest and wrong. <strong>The padding case is the dangerous one</strong> &mdash; it is a buffer overflow that works until it does not, and the exercise is worth doing precisely so you can recognise it in code you did not write. If you do pad, the padding is not an optimisation: it is a precondition, and it belongs in a comment and in a bounds check.)</em></li>
                    <li><strong>Find an indirect access that is actually a strided run and ask whether a segment load exists for your target.</strong> <em>(Expect the answer to be yes on RISC-V V and SVE, and no on x86-64 &mdash; which is why x86 gather instructions exist at all and why they cost what they do. This is the clearest place in the course where an ISA feature is a direct consequence of another ISA not having one, and it is a good bridge to <a href="/courses/simd/lessons/simd-three">the three-architectures concept</a>.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/simd/lessons/simd-shapes">the shapes concept</a> is where the load and the store were identified as the real cost of a vector loop &mdash; the four-body table showed an add and a multiply costing the same because they hide inside the memory operations. This concept is that cost's price list. And <a href="/courses/simd/lessons/simd-reduce">the reduction concept</a> is the structural twin: <strong>a tail and a fold are the same problem</strong> &mdash; a few elements left over after a wide operation &mdash; and both arrive at &ldquo;do them one at a time, it is free&rdquo; for the same reason and on the same machine without a mask register.</p>
                <p>Forward, <a href="/courses/simd/lessons/simd-three">the three-architectures concept</a> is the direct answer to two of this concept's findings. AArch64 NEON has <strong>no gather instruction at all</strong>, which sounds like a missing feature and is actually the reason the hand-written gather is not merely faster but the only option there; and SVE and RISC-V V both have predication, which is the answer to the tail table. <a href="/courses/simd/lessons/simd-harness">The harness concept</a> then explains why this section's mechanism is marked INFERRED and its checks assert shapes.</p>
                <p>Outward, the two connections a compiler author needs most. <a href="/courses/mem/lessons/mem-latency">The memory course's latency concept</a> is where &ldquo;where do the bytes come from&rdquo; was made a measurement rather than an assumption, and it is the reason the alignment result could be checked at two working-set sizes instead of one: a claim about a load is a claim about a <em>cache level</em>, and the answer changes when the answer changes. <a href="/courses/mem/lessons/mem-writes">Its writes concept</a> is where the store side of every table in this concept was introduced. And <a href="/courses/isa/lessons/isa-length">The ISA course's length concept</a> is where you can go to see <em>why</em> <code>vmovapd</code> and <code>vmovupd</code> are two opcodes rather than one with a flag &mdash; the ISA course teaches the encoding, and this concept measures what the two encodings cost.</p>
                <p>One outward-facing consequence, and it is the most practical thing in the concept. <strong>&ldquo;Aligned&rdquo; is a promise a declaration makes and a compiler can check.</strong> <code>__attribute__((aligned(32)))</code> on a local array does not just help the optimiser &mdash; it makes a whole class of misaligned access <em>unrepresentable</em>. That is the same shape as the trap in <a href="/courses/smp/lessons/smp-sharing">the multiprocessor course's sharing concept</a>, where an attribute on a one-dimensional array aligned the <em>array</em> and not the <em>elements</em> and every &ldquo;private line&rdquo; row was a false-sharing row wearing a different label. <strong>Both are cases of a declaration promising alignment at the wrong granularity, and both are silent.</strong></p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/simd/lessons/simd-reduce">Going Back to One Scalar</a></span>
                <span>Next: <a href="/courses/simd/lessons/simd-three">Three Answers to One Shape</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
