// SIMD and Vector Processing — Concept 1: a register with lanes in it
public namespace underlayer_content {

using std::string

using std::string_view

public func render_simd_width() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("A Register With Lanes In It — Underlayer")
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
            <h1>A Register With Lanes In It</h1>
            <div class="lesson-meta">26 min &middot; <a href="/courses/simd">SIMD and Vector Processing</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Start with a debt, because the debt is the reason this course exists and it is a single sentence in a file you may have read. <a href="/courses/exe/lessons/exe-deps">The execution course's dependency concept</a> explains that a loop unrolls into &ldquo;multiples of the SIMD width&rdquo;, and <a href="/courses/exe/lessons/exe-latency">its latency concept</a> says a different shape does &ldquo;the same work in SIMD&rdquo;. Both use the phrase as a known quantity. Across the five CPU-architecture courses before this one, a word-boundary count finds <code>lane</code> <strong>zero</strong> times, <code>XMM</code>, <code>YMM</code> and <code>ZMM</code> <strong>zero</strong> times, and <code>emmintrin</code> <strong>zero</strong> times.</p>
                <p>And the other side of the same debt is stranger. <code>AVX-512</code> appears in five files, all of them the ISA course, and every one of them is about the <code>0x62</code> EVEX prefix and the <code>BOUND</code> instruction whose opcode it stole from. <a href="/courses/isa/lessons/isa-opcodes">That course</a> will teach you to decode the byte that introduces an AVX-512 instruction and will not tell you what the instruction does. <strong>A vocabulary that appears only in a prefix table has been taught as a decoding problem, not as a machine.</strong></p>
                <div class="hex-dump">
                <pre>$ grep -rlwi -e XMM -e YMM -e ZMM -e lane -e emmintrin content/src/*.ch | wc -l
0
  </pre>
                </div>
                <p>So the first thing this course owes you is a definition, and a definition in this collection is a table with integers in it rather than a paragraph. Here it is &mdash; and it is <strong>computed by the artifact at run time from <code>sizeof</code></strong>, not copied out of a manual, so it is a fact about this build rather than a fact about a document:</p>
                <div class="hex-dump">
                <pre>$ ./simdbench | sed -n '/register   bytes/,/k0-k7/p'
   register   bytes    64-bit double   32-bit float   32-bit int   8-bit int   16-bit int
   XMM         16           2               4              4            16             8
   YMM         32           4               8              8            32            16
   ZMM         64           8              16             16            64            32   &lt;- not in this CPU
   k0-k7         64 bits, one per lane of a ZMM.  64 of them per ZMM, 512 per
           architectural ZMM.  Not in this CPU.
  </pre>
                </div>
                <p><strong>A vector register is a number of bytes. A lane is a division.</strong> That is the whole content of the register, and everything else in this course is a consequence of it. The execution course's phrase has a referent: the SIMD width is 16, 32 or 64 <em>bytes</em>, and &ldquo;multiples of the SIMD width&rdquo; means &ldquo;multiples of that byte count, in elements of whatever type the array holds&rdquo;.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: two columns and one trap</h2>
                <p>Read the table by columns and every row is arithmetic. Doubles are 8 bytes, so an XMM holds 16/8 = 2 and a YMM holds 32/8 = 4. <strong>Two lanes was not a choice anybody made.</strong> It is the only answer that fits, and the same division gives 4 floats, 8 floats, 4 int32s, 16 int8s and 8 int16s in a YMM without a single one of them being a design decision.</p>
                <div class="formula">
   THE ONLY THING THAT DECIDES THE LANE COUNT:

       lane count = register width in bytes
                    ----------------------------
                    size of one element in bytes

   doubles are 8 bytes, so:
       SSE2   16 bytes / 8  = 2 lanes   (a choice you do not have)
       AVX    32 bytes / 8  = 4 lanes
       AVX-512 64 bytes / 8 = 8 lanes   (not on this machine)

   and the harness asserts every one of those twenty-five
   numbers EXACTLY, because they are exact.
                </div>
                <p>Now the trap, and it is the one the whole course turns on. The table has a column that says how many elements an instruction touches, and it does <strong>not</strong> have a column that says how much faster that makes anything. Those are different columns, and the second one is a measurement, and here it is:</p>
                <div class="hex-dump">
                <pre>$ ./simdbench | sed -n '/working set/,/beyond L3/p'
   L1                         0 KiB        2 KiB     0.719      0.361      0.185         3.89x
   L1 -&gt; L2                  32 KiB       96 KiB     0.799      0.461      0.357         2.24x
   beyond L2                256 KiB      768 KiB     0.827      0.507      0.431         1.92x
   beyond L2, inside L3    2048 KiB     6144 KiB     0.831      0.508      0.429         1.94x
   beyond L3               8192 KiB    24576 KiB     1.531      1.442      1.340         1.14x
  </pre>
                </div>
                <p>Four lanes. The first row says that buys 3.89&times; and the last row says the same four lanes buy 1.14&times;. <strong>The register did not change.</strong> What changed is whether the three arrays fit in a 32 KiB L1, and the answer to &ldquo;how fast is four lanes&rdquo; turns out to be &ldquo;it depends, and here is the dependency&rdquo;.</p>
                <p>The most useful way to hold this is as a division. The speedup is bounded by <strong>how much of the loop the width actually divides</strong>:</p>
                <div class="formula">
   THIS LOOP, PER FOUR ELEMENTS:

     scalar   4 loads   4 multiplies   4 adds   4 stores   = 16 ops
     4-wide   3 loads   1 multiply    1 add    1 store    =  6 ops

   The width divides the ARITHMETIC by 4 and the memory
   OPERATIONS by 4.  Both of those are instruction counts,
   and both stop being instruction counts the moment the
   memory system is the thing you are waiting for.

   So there are TWO ceilings and the loop hits whichever is
   lower:

     the ISSUE ceiling   -- how fast the core can retire
                            loads, stores and FP ops.  The
                            width helps, and helps ~4x.

     the MEMORY ceiling   -- how fast the bytes arrive.  The
                            width does not help at all: a
                            32-byte load and a 8-byte load
                            fetch the same number of BYTES per
                            element, and if those bytes come
                            from DRAM they take as long in both
                            cases.

   In L1 the issue ceiling is lower and 4 lanes wins.
   At 24 MiB the memory ceiling is lower and 4 lanes
   buys almost nothing.
                </div>
                <p>That is the model. The rest of the course is three elaborations of it: the compiler is one way of getting the issue ceiling (concept 2), the horizontal add is the one place the width does not divide anything (concept 4), and the gather is a case where the width makes the addresses worse (concept 5).</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: what the width table is missing</h2>
                <p>Three things the table cannot say, each of which is a trap, and each of which the artifact has to state as a limit because on this machine it cannot be measured.</p>
                <h3>One: a 512-bit register is not four times a 128-bit one in practice</h3>
                <p>The manuals describe the <strong>upper-ZMM state</strong>: on every x86 CPU since 2013 the upper 256 bits of a ZMM are <em>aliased</em> onto the YMM, and on the parts with 256-bit-and-down registers a VEX-encoded instruction zeroes the upper bits of its destination. So writing a YMM and reading a ZMM's low half are the same register, and the 512-bit encoding does not give you a second independent register for the price of one. <strong>This artifact cannot measure any of it</strong> &mdash; five CPUID leaves, all zero, printed in section 0 &mdash; so it is quoted and not claimed, and the limits block says so.</p>
                <h3>Two: the width is not even a property of the register on every architecture</h3>
                <p>On x86-64 the width is a property of the <strong>encoding</strong>: VEX encodes 128 or 256, EVEX encodes 512. On AArch64 NEON it is 128 bits and always has been, so a portable NEON loop over doubles is 2-wide and there is no wider option in the base architecture at all. On SVE and on RISC-V V the width is <strong>chosen by the implementation</strong>, and the same binary runs at a different width on a different part. <a href="/courses/simd/lessons/simd-three">The three-architectures concept</a> is entirely about this, and it is quoted rather than measured.</p>
                <h3>Three: a mask register is a third operand, not a modifier</h3>
                <p>This is the one the rest of the course pays for, so it is worth getting exactly right even though it cannot be measured here. A mask register is <code>k0</code>&ndash;<code>k7</code>, 64 bits each, one bit per lane of a 512-bit register. A masked <em>load</em> uses a set bit to say which lanes to take; a masked <em>store</em> uses a set bit to say which lanes to keep. It is not a modifier on the instruction &mdash; it is a full operand with its own register file, and it is the reason AVX-512 has essentially no tail problem. The last concept of module 3 measures the tail this machine has to handle without one, and measures the scalar answer as <strong>free</strong>.</p>
                <div class="formula">
   SO THE DEFINITION THE EXECUTION COURSE OWED, IN FULL:

     a VECTOR REGISTER is a fixed number of bytes, named
       by its width: XMM is 16, YMM is 32, ZMM is 64.

     a LANE is one element-sized slot in it.  The lane
       count is the width divided by the element size and
       is never anything else.

     the SIMD WIDTH -- the phrase exe_deps.ch uses -- is
       the width in BYTES, not in elements, and the two
       are related by the type of the array.

     a WIDE INSTRUCTION applies one operation to every
       lane independently.  It is worth what the ADDRESSES
       allow, which on a sequential loop is the full width
       and on a gather is very nearly nothing at all.
                </div>
                <p>And the honest close on the table: <strong>none of these five courses had any reason to teach this</strong>. Each of them had a single core and a single value at a time, and a single core processing one value at a time does not need the word. It is the same shape of debt as &ldquo;SMT siblings&rdquo; in the memory course, and it is discharged the same way: by printing the definition in the artifact&rsquo;s own output rather than in a changelog.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: reading the twenty-five integers</h2>
                <p>The harness asserts this table exactly, and it is worth seeing why that is a legitimate exact assertion when every other number in the artifact is a shape. Do the division yourself for the two columns that are not obvious:</p>
                <div class="formula">
   XMM, 16 bytes:
      8-bit int    16 / 1  = 16 lanes
      16-bit int   16 / 2  =  8 lanes
      32-bit int   16 / 4  =  4 lanes
      32-bit float 16 / 4  =  4 lanes
      64-bit double 16 / 8 =  2 lanes

   YMM is exactly double every one of those, and ZMM exactly
   double again.  The harness checks the doubling as its own
   assertion, so a table that got one cell wrong while
   keeping the doubling would still be caught.
                </div>
                <p>Now the part that is not a division, and it is the part a code generator has to know. <strong>The width is in the instruction encoding, and the encoding is what makes the two load families different.</strong> <code>vmovapd</code> <em>demands</em> a 32-byte aligned address; <code>vmovupd</code> demands nothing. Those are two different opcodes with two different alignment contracts, and the difference between them is not a performance hint &mdash; the next section of the course measures the aligned one <em>faulting</em> on an address the unaligned one handles silently.</p>
                <p>So here is the whole thing as a compiler backend would want it, in the order it would want it:</p>
                <div class="formula">
   1. the element type and the array length give you
      how many BYTES the loop touches per iteration.

   2. the target's widest register that divides that
      evenly gives you the lane count.  No wider, or the
      loop has a TAIL (module 3).

   3. if the addresses are CONSECUTIVE, emit a wide
      aligned-or-unaligned load and store per register.
      This is the case every optimisation is written for.

   4. if the addresses are NOT consecutive -- a gather, a
      scatter, a transpose, a permute -- a wide
      instruction is a COST until measured otherwise, and
      module 3 measures it at 2.8x the alternative.

   5. if anything REDUCES the lanes back to one -- a dot
      product, a sum, a maximum -- that reduction is a
      separate cost and it is module 2.
                </div>
                <p>Steps 1 to 3 are the whole of vectorisation and they are a page long. <strong>Steps 4 and 5 are the rest of the course</strong>, and they are where every wrong &ldquo;it is 4&times; faster&rdquo; claim in the world comes from &mdash; because step 4 is silently false for a gather and step 5 is silently false for a sum.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Rebuild the lane table yourself before you read anything else in the course.</strong> <code>cd courses/simd/assets/samples &amp;&amp; ./build_samples.sh</code>, then <code>./simdbench | sed -n '/register   bytes/,/k0-k7/p'</code>. <em>(Expect thirty-two bytes for YMM and four lanes of doubles, exactly. Then change the <code>64-bit double</code> column to <code>32-bit float</code> in <code>sec_register</code> without changing the code that prints it, rebuild, and watch the harness fail on that one check and no other &mdash; which is what an exact structural assertion is for, and is the only kind of check in this artifact that can tell you which cell you broke.)</em></li>
                    <li><strong>Find the phrase you were given as a known quantity.</strong> Grep every concept file of the five preceding CPU-architecture courses for <code>width</code>, <code>vector</code> and <code>wide</code> with word boundaries. <em>(Expect a handful of hits, none of which is a definition, and expect at least one of them to be about a cache line's width rather than a register's. The exercise is not to find the term &mdash; it is to notice how comfortable you were with it before this concept.)</em></li>
                    <li><strong>Measure the ceiling for a loop you actually have.</strong> Take a real kernel of yours, run it over a 64-element array and then over a 4&nbsp;MiB one, and time both. <em>(Expect the ratio to be much smaller on the second, and expect the scalar version's per-element cost to have barely moved &mdash; that is the sentence in the artifact's section 3 and it is the single most portable fact in this course. If your ratio does <em>not</em> collapse, your loop is probably arithmetic-bound already, and that is worth knowing too: it means the vectoriser is not the lever.)</em></li>
                    <li><strong>Check the width claim on a gather you already have.</strong> Find an indirect access in real code &mdash; a <code>pixels[i * stride + offset]</code>, a sparse matrix multiply, a particle gather. <em>(Expect that hand-unrolling it by four scalar loads and assembling the vector is competitive with a wide instruction, and on this machine it is <em>2.8&times; faster</em>. If you find a case where the hardware gather wins, it will be one with a <em>regular</em> stride &mdash; and the answer to that is a segment load, which is a different instruction on a different architecture and is the last third of module 3.)</em></li>
                    <li><strong>Go looking for &ldquo;four lanes&rdquo; in your own reasoning.</strong> Every time you have written down a speedup as a multiple of a lane count, add the workload to the sentence. <em>(Expect that most of them cannot be repaired, and that the ones which can be repaired all end with the same clause: &ldquo;when the data is in L1&rdquo;. The clause is not a footnote on the claim; on this machine it is most of the claim.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, this concept is the definition <a href="/courses/exe/lessons/exe-deps">the execution course's dependency concept</a> and <a href="/courses/exe/lessons/exe-latency">its latency concept</a> both assumed. Read them after this one and the phrase &ldquo;multiples of the SIMD width&rdquo; will have a referent. <a href="/courses/isa/lessons/isa-length">The ISA course's length concept</a> is where the VEX and EVEX encodings that decide which of these three widths an instruction gets are laid out, and it is worth reading in that order &mdash; this concept gives the registers, that one gives the bytes that select them.</p>
                <p>Forward, <a href="/courses/simd/lessons/simd-compiler">the compiler concept</a> takes the 4-wide arm from the table above and asks the question this concept deliberately did not answer: if the width only buys 3.89&times; in L1 and 1.14&times; out of it, <em>which of the two ceilings is binding in your code, and how do you know?</em> It answers it with a disassembly rather than a speedup, and it retracts two claims this course made about the compiler in its own first draft.</p>
                <p>Outward, the connection that will matter longest is to a code generator. <a href="/courses/mem/lessons/mem-writes">The memory course's writes concept</a> already showed a loop with three loads and a store per iteration and called it a shape; this course says the shape has a width, and that the width divides the memory operations by four only in the <em>instruction count</em> sense. <a href="/courses/wasm/lessons/wasm-instructions">The WebAssembly course's instruction concept</a> has the <code>simd</code> proposal quoted as a specification and never connected to a register &mdash; and that proposal is the one place in the collection where a 128-bit vector type is defined for a machine that does not have one, which is the cleanest possible statement of the abstraction this table is about.</p>
            </div>

            <div class="lesson-footer">
                <span>Start: <a href="/courses/simd">SIMD and Vector Processing</a></span>
                <span>Next: <a href="/courses/simd/lessons/simd-compiler">The Compiler, the Intrinsics, and a Control That Lied</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
