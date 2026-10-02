// SIMD and Vector Processing — course landing page
public namespace underlayer_content {

using std::string

using std::string_view

public func render_simd_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("SIMD and Vector Processing — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson simd-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>SIMD and Vector Processing</h1>
            <div class="lesson-meta">7 concepts &middot; 4 modules &middot; 186 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
                <p>The five courses before this one each had one core in them, and they got away with it. <a href="/courses/isa/lessons/isa-decode">The ISA course</a> gave you the bytes of an instruction. <a href="/courses/exe/lessons/exe-instrument">The execution course</a> followed one through a pipeline. <a href="/courses/mem/lessons/mem-latency">The memory course</a> followed an address down to DRAM and back. <a href="/courses/priv/lessons/priv-doors">The privilege course</a> followed a fault to a table a process may not read. <a href="/courses/smp/lessons/smp-sharing">The multiprocessor course</a> added a second core and found that the cost of sharing lives in the cache line and not in the data. All five were about <em>one</em> value at a time, and none of them needed anything else.</p>
                <p>That is exactly why a term slipped through. A word-boundary count over the concept files those five courses left behind, taken this morning, with <code>grep -rlwi</code> over <code>content/src/</code>:</p>
                <div class="formula">
  term              files   sense
  MESI                  2   both yesterday's smp course -- 0 before it
  snoop                 3   all three in smp_*.ch -- 0 before it
  XMM / YMM / ZMM       0   never written at all
  NEON                  0   never written at all
  emmintrin             0   never written at all
  vectoriz*             0   the word is not used
  lane                  0   THE CENTRAL DEFINITION, ABSENT
  mask register         0   absent
  k register            0   absent
  FMA                   0   absent
  avx2                  0   absent
  float point           0   absent
  SIMDe                 0   absent
  scatter               0   absent
  horizontal add        0   absent
  SIMD                  8   see below
  AVX / AVX-512        6   the ISA course, all of it
  gather                2   neither of them about vectors
  shuffle               1   a study-method table
                </div>
                <p><strong>Read the two rows that matter.</strong> <code>SIMD</code> appears in eight files and not one of them teaches it: the privilege course uses it as the <em>vector-19 exception</em> in its canonical-address table, this pair of landing pages spell the phrase out, and the other three are the <strong>WebAssembly <code>simd</code> proposal</strong> in the wasm course. And <code>AVX</code> and <code>AVX-512</code> appear in six files, five of them the ISA course &mdash; and every single one of them is about the <code>0x62</code> EVEX prefix and the <code>BOUND</code> instruction it collided with. <strong>That course taught what byte introduces an AVX-512 instruction and never said what the instruction does.</strong> The <code>gather</code> hits are a reading-comprehension passage about bees gathering nectar and a linker step that collects symbol tables; the one <code>shuffle</code> is a table of revision techniques that tells you to shuffle your topics.</p>
                <p><strong>And the sharpest one is not even a term count.</strong> <a href="/courses/exe/lessons/exe-deps"><code>exe_deps.ch</code></a> says a loop unrolls into &ldquo;multiples of the SIMD width&rdquo; and <a href="/courses/exe/lessons/exe-latency"><code>exe_latency.ch</code></a> says the same work is done &ldquo;in SIMD&rdquo;. The execution course uses the phrase as a known quantity and never defines it, exactly as the memory course used &ldquo;SMT siblings&rdquo; without ever saying what a sibling is. <strong>This course is the definition.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>The one measurement that makes the course</h2>
                <p>One statement &mdash; <code>A[i] = A[i]*B[i] + C[i]</code> &mdash; over three arrays, and one thing changed per column: <strong>how much memory the working set is.</strong> Same source, same machine, same 4-wide instruction, arms interleaved.</p>
                <div class="hex-dump">
                <pre>$ ./simdbench | sed -n '/working set/,/neither column/p'
   working set          per array   all three   scalar      2-wide      4-wide    4-wide/scalar  auto-vec/scalar  via POINTERS/scalar
   L1                         0 KiB        2 KiB     0.719      0.361      0.185         3.89x           3.90x              0.11x
   L1 -&gt; L2                  32 KiB       96 KiB     0.799      0.461      0.357         2.24x           2.24x              0.12x
   beyond L2                256 KiB      768 KiB     0.827      0.507      0.431         1.92x           1.95x              0.12x
   beyond L2, inside L3    2048 KiB     6144 KiB     0.831      0.508      0.429         1.94x           1.90x              0.12x
   beyond L3               8192 KiB    24576 KiB     1.531      1.442      1.340         1.14x           1.18x              0.23x
  </pre>
                </div>
                <p><strong>The lane count did not change between the first row and the last.</strong> It is four in both. The 4-wide arm is <strong>3.89&times;</strong> the scalar arm when the three arrays total 2 KiB and live in a 32 KiB L1, and <strong>1.14&times;</strong> when they total 24 MiB and do not. Same instruction, same register, same compiler, same second.</p>
                <p>And here is the sentence that makes it a result rather than a number:</p>
                <div class="hex-dump">
                <pre>   The lane count did not change between those two rows.  It is four in
   both.  The only thing that changed is where the bytes come from, and
   the speedup fell from 3.89x to 1.14x -- a factor of 3.41 -- while the
   SCALAR arm barely moved at all: 0.719 ns/element at 2 KiB and 1.531 at
   24 MiB, a factor of 2.13.  The 4-wide arm went from 0.185 to 1.340, a
   factor of 7.25.
  </pre>
                </div>
                <p><strong>The vector arm's cost went up by seven and the scalar arm's by two, and the difference is the speedup.</strong> A 4-wide loop does not do less work than a scalar loop. It does the same work in a quarter of the instructions, which is worth almost nothing once the bottleneck is bandwidth rather than the instruction rate. That is what &ldquo;vectorise the hot loop&rdquo; means, and this table is where it stops meaning that.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Three results that were not what the prose expected</h2>
                <p>A course whose headline came out cleanly would be less interesting than one whose second, third and fourth results refused to be written in advance. All three of these are in the recorded output, and all three are printed by the artifact itself.</p>
                <div class="hex-dump">
                <pre>$ ./simdbench | sed -n '/vpgatherdd, against/,/SCATTER, a GATHER/p'
      the hand gather, against the SEQUENTIAL loop it replaces    2.06x
      vpgatherdd, against the same sequential loop                 5.73x
      vpgatherdd, against FOUR ORDINARY SCALAR LOADS                2.78x
  </pre>
                </div>
                <p><strong>The gather instruction is 2.8&times; slower than four ordinary scalar loads.</strong> <code>vpgatherdd</code> is one instruction that does four <em>independent</em> loads, and independent loads cannot be overlapped, because the memory system has no way to know they are unrelated. The instruction saves the register moves and charges a decode penalty for them. This is not a compiler artefact: both arms are intrinsics in the same translation unit. And it is the same finding as the FMA row in the next section, with a bigger multiplier.</p>
                <div class="hex-dump">
                <pre>$ ./simdbench | sed -n '/NO TAIL at all/,/not own/p'
   64 elements, 4-wide, NO TAIL at all                          12.71     1.00x
   66 elements, 4-wide + a SCALAR remainder of 2                12.94     1.02x
   66 elements, 4-wide + one OVERLAPPING iteration, 2 valid     22.50     1.77x
   68 elements, plain 4-wide: WRITES 2 ELEMENTS PAST THE END    13.91     1.09x
   CONTROL: a FULL 32-byte overlap                              13.95     1.10x
   CONTROL: a PARTIAL overlap load, only 1 lane stored back     16.62     1.31x
  </pre>
                </div>
                <p><strong>The clever tail is the most expensive row in its own table.</strong> On a machine with no mask register, the textbook trick for a 66-element loop is to run one more 4-wide iteration starting at element 62 and store only the two lanes that exist. It is 1.77&times; the no-tail arm. The two controls say why: a <em>full</em> 32-byte overlap is 1.10&times; and a <em>partial</em> overlap load is 1.31&times;, so the cost is the half-overlapping load reading back a line the loop has just written &mdash; store-to-load forwarding cannot serve it. Meanwhile the <strong>scalar remainder is 1.02&times;</strong>, and the arm that writes two elements past the end is 1.09&times; and corrupts whatever follows. <strong>Write the tail scalar.</strong> It is free, it is correct, and it is what AVX-512 has a mask register to avoid needing.</p>
                <div class="hex-dump">
                <pre>$ ./simdbench | sed -n '/THE COMPARISON, as SPEEDUPS/,/Instruction COUNT/p'
      4 lanes with FMA (E) / 4 lanes without (D)   1.00x   &lt;- FMA's contribution
      the hand-written 4-wide (E) / the compiler (A)   1.00x
      one fewer memory op (F) / three loads (E)     1.12x   &lt;- SLOWER, and that
         is the finding: a memory operand buys a shorter instruction and
         costs a longer dependency.  Instruction COUNT is not the cost.
  </pre>
                </div>
                <p><strong>Two more nulls, and both are results.</strong> FMA halves the arithmetic instruction count and the time does not move at all. And the arm that removes a whole load by making it a memory operand of the FMA is <em>slower</em>, because that instruction must wait for the load to land before it can multiply. <strong>A shorter instruction is a longer dependency.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>What is deferred, and what this artifact will not claim</h2>
                <p>Printed in the artifact's own limits block rather than footnoted, because a limit that is a footnote is a limit that gets forgotten. This machine is a virtualised guest and <code>perf_event_paranoid</code> is <strong>4</strong>, so there is no PMU at all:</p>
                <ul>
                    <li><strong>No count of anything.</strong> No instruction, no uop, no cycle, no load, no store and no cache-line split can be counted here. Every number in this course is a <em>duration</em>, and a duration bounds a count without measuring it. Every mechanism in every table is marked INFERRED for that reason, and the store-forwarding explanation in the tail table is a mechanism with two controls supporting it, not a count.</li>
                    <li><strong>Anything at all about AVX-512.</strong> Five CPUID leaves, all zero, printed in section 0 of the artifact. What a ZMM is and what a k0-k7 mask register is comes from the manuals. <strong>Nothing about a 512-bit register is measured here</strong>, and in particular the claim that one gives you eight doubles is a claim about the <em>encoding</em> and not about how fast anything is.</li>
                    <li><strong>Whether the upper-ZMM state costs anything.</strong> The manuals describe the aliasing and the VEX zeroing. Measuring it needs a 512-bit machine and a register this CPU does not have.</li>
                    <li><strong>Whether the compiler vectorised.</strong> Section 3 quotes speedups for two compiler arms, and a speedup is a consequence of the codegen rather than evidence for it. So <code>build_samples.sh</code> compiles <em>four</em> forms of the same loop and appends their mnemonics, and the harness checks the disassembly. <strong>The first version of this course had no disassembly at all and got the mechanism wrong twice.</strong></li>
                    <li><strong>The other two architectures.</strong> AArch64 NEON, SVE and RISC-V V are quoted from manuals with a document, not run. There is no such machine in the room.</li>
                    <li><strong>Anything about floating-point correctness.</strong> The fixed point the checksums rely on is exact by construction &mdash; 0.25, 0.5 and 0.25 are all powers of two &mdash; so a checksum of 32.0 proves the right <em>number of operations</em> happened. It does not prove a vector sum equals a scalar sum, and section 5 says in the body that a tree reduction reassociates and therefore gives a different answer.</li>
                </ul>
                <p>What the roadmap folds into this course is the last outstanding item in the neutral CPU-architecture sequence, and the one with a different shape from the other four: <strong>the first four were about two processors talking to each other; this one is about widening the data path of the one you already have.</strong> The deferral chain is discharged. The memory course's limits block named cache coherence, NUMA and multiprocessor memory, and the multiprocessor course paid that; the privilege course used the word SIMD without defining it, and this course defines it. <strong>That is the last of the four.</strong></p>
                <p>The completion criterion is not &ldquo;read it&rdquo;. It is: <em>reproduce the 131 checks, then restore the static initialisers on the control arm's three pointers and watch the control come back to 3.90&times; and group D fail by name.</em> A control that cannot fail is not a control, and this artifact shipped one for a day.</p>
            </div>

            <div class="unit unit-connect">
                <h2>What comes before, and what comes next</h2>
                <p>Before, and in the order the debt was incurred. <a href="/courses/exe/lessons/exe-deps">The execution course's dependency concept</a> is where &ldquo;multiples of the SIMD width&rdquo; appears as a known quantity, and its <a href="/courses/exe/lessons/exe-latency">latency concept</a> is where &ldquo;the same work in SIMD&rdquo; does &mdash; both are answered here, and the independence result in module 2 is that course&rsquo;s central fact carried one register over. <a href="/courses/isa/lessons/isa-opcodes">The ISA course's opcode concept</a> is where an AVX-512 instruction&rsquo;s <code>0x62</code> prefix is decoded and what it does is not; <a href="/courses/isa/lessons/isa-length">its length concept</a> is where the VEX and EVEX encodings that decide the register width are laid out. <a href="/courses/mem/lessons/mem-hierarchy">The memory course's hierarchy concept</a> is the cache table section 3's working set is measured against, and <a href="/courses/mem/lessons/mem-writes">its writes concept</a> is where a 3-loads-1-store loop was already visible as a shape without anyone naming it. <a href="/courses/priv/lessons/priv-vectors">The privilege course's vector-19 exception</a> is the only place the word SIMD appeared in five courses, and it was an exception table. <a href="/courses/smp/lessons/smp-atomic">The multiprocessor course's atomic concept</a> measured what a prefix that promises more than you asked for costs, which is the same shape as arm F here. And <a href="/courses/wasm/lessons/wasm-instructions">the WebAssembly course's instruction concept</a> has the other <code>simd</code> proposal, quoted and never connected to a machine.</p>
                <p><strong>The deferral is discharged, and so is the sequence.</strong> Of the roadmap's neutral CPU-architecture items, cache coherence, NUMA, and the canonical-address forms are all paid; CPU Virtualization is not addressed by this course or any other and this course does not pretend otherwise. What remains open after this one is a compiler author's question and not a learner's: <strong>when is a wide instruction the right one, and the answer is &ldquo;when the four addresses allow it&rdquo; &mdash; which is a question about aliasing, about gather cost, and about whether the loop is memory-bound.</strong> All three of those are measured in the seven concepts below.</p>
            </div>

            <div class="lesson-footer">
                <span>Start: <a href="/courses/simd/lessons/simd-width">A Register With Lanes In It</a></span>
                <span>End of SIMD and Vector Processing &middot; <a href="/courses">all courses</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
