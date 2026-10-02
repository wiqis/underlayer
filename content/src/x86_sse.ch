// The x86-64 Data Path — Concept 1: SSE, SSE2 and the alignment split
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_sse() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("SSE and SSE2: The XMM Register and the Alignment Split — Underlayer")
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
            <h1>SSE and SSE2: The XMM Register and the Alignment Split</h1>
            <div class="lesson-meta">26 min &middot; <a href="/courses/x86simd">The x86-64 Data Path</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p><a href="/courses/simd/lessons/simd-width">The SIMD course</a> measured that a wider vector is not automatically faster, and it did it with a body the compiler chose. This concept is the part that makes a vector body <em>unsafe to choose</em>: the difference between an instruction that works on any address and one that dies on most of them is a single letter in the mnemonic, and the letter is the only thing standing between a working program and a <code>SIGSEGV</code> that depends on where an allocator happened to put an array.</p>
                <p>There is exactly one measurement in this course that observes that requirement directly, and it is not a duration. It is <strong>ten forked children, one instruction each, at an address eight bytes off a cache line</strong>, and the output is a signal number per row. That choice is the concept: <em>alignment is a correctness requirement and a duration table is the wrong instrument for a correctness requirement</em>, because the difference between a working load and a faulting one is not a slowdown you can amortise away. It is a program that does not run.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: eight moves, and what the letters mean</h2>
                <p>The table is <code>PRINTED AND NOT MEASURED</code>, which is a real distinction here and not a formality: the <em>fault</em> half of every row is measured in the next section, one forked child per row, and the <em>encoding</em> half is quoted from the SDM and then checked byte-for-byte in <a href="/courses/x86simd/lessons/x86-bytes">the last concept</a>.</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/1B1\./,/THE NAMING IS NOT/p'
  MOVE | op   | pfx | ALIGNED | what the ALIGNED form faults on
  MOVAPS| 28  | none| 16 byte | #GP if the address is not 16-aligned
  MOVUPS| 10  | none| none   | nothing; the unaligned form
  MOVDQA| 6F  | 66  | 16 byte | #GP; the integer twin of MOVAPS
  MOVDQU| 6F  | F3  | none   | nothing
  MOVSS | 11  | F3  |  4 byte | #GP if not 4-aligned
  MOVSD | 11  | F2  |  8 byte | #GP if not 8-aligned
  MOVLPD| 13  | 66  |  8 byte | #GP if not 8-aligned
  LDDQU | F0  | F2  | none   | a LOAD that explicitly never faults
                </pre>
                </div>
                <p>The naming is not decorative and it is the fastest way to remember the table. <code>aps</code> is <em>aligned packed single</em>, <code>apd</code> is the double, and <code>dqa</code> is <em>double quadword aligned</em> &mdash; the integer twin of <code>movaps</code> with the same requirement and a <code>66</code> operand-size prefix in front of it. Wherever an <code>a</code> appears, the instruction <strong>faults on a misaligned address</strong>. Wherever a <code>u</code> appears, it does not. That is the entire rule, and it holds for all eight rows above.</p>
                <p>Three rows in that table are not about 16 bytes and are the ones people forget:</p>
                <ul>
                    <li><strong><code>MOVSS</code> and <code>MOVSD</code> require only 4 and 8 bytes</strong>, because they move one scalar and the scalar's own alignment is the requirement. <code>MOVSS</code> is opcode <code>11</code> and <code>MOVSD</code> is opcode <code>11</code> too &mdash; the difference is a prefix, <code>F3</code> against <code>F2</code>, which is a reminder that a mnemonic is not an opcode.</li>
                    <li><strong><code>MOVLPD</code> requires only 8</strong> even though it moves a packed double, because the second half of the destination is not a memory operand at all.</li>
                    <li><strong><code>LDDQU</code> requires nothing, ever.</strong> It is the only instruction in the table whose description says &ldquo;never faults&rdquo;, and it exists because the unaligned load was too useful to lose while <code>movups</code> was a slightly worse version of it. The difference is the <em>hint</em>: <code>movups</code> tells the hardware the data is unaligned and lets it skip a check that is already known, and on a machine that could load across a page boundary that hint is load-bearing.</li>
                </ul>
                <p>And the prefix column is where the trap in <a href="/courses/x86abi/lessons/x86-verify">the ABI course's last concept</a> reappears in a new costume. <code>66</code> is not a direction flag and not a size flag in the general case &mdash; in the legacy encoding space <code>66</code> is an <em>operand-size override</em>, and for a <code>mov</code> it turns a 32-bit operation into a 128-bit one. That is why <code>movdqa</code> is <code>66 0f 6f</code> and <code>movdqu</code> is <code>f3 0f 6f</code>, and why <code>movdqa</code> and <code>movaps</code> are the same instruction wearing a prefix and a name.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The measurement: ten probes, and what they prove</h2>
                <p>The buffer is <code>mmap</code>'d, so the compiler knows nothing about its contents and cannot fold a load into a constant. Each probe is one instruction in its own forked child, so a fault is a signal number rather than a dead artifact.</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/^  ALIGN |/,/vmovdqa load   | aligned/p'
  ALIGN | vmovapd load   | aligned: returned  | +8 bytes: SIGSEGV   | legacy encoding
  ALIGN | vmovupd load   | aligned: returned  | +8 bytes: returned  | legacy encoding
  ALIGN | vmovapd store  | aligned: returned  | +8 bytes: SIGSEGV   | legacy encoding
  ALIGN | vmovupd store  | aligned: returned  | +8 bytes: returned  | legacy encoding
  ALIGN | vmovdqa load   | aligned: returned  | +8 bytes: SIGSEGV   | legacy encoding
  ALIGN | vmovdqu load   | aligned: returned  | +8 bytes: returned  | legacy encoding
  ALIGN | movaps load    | aligned: returned  | +8 bytes: SIGSEGV   | legacy encoding
  ALIGN | movups load    | aligned: returned  | +8 bytes: returned  | legacy encoding
  ALIGN | vmovaps load   | aligned: returned  | +8 bytes: SIGSEGV   | VEX encoding
  ALIGN | vmovdqa load   | aligned: returned  | +8 bytes: SIGSEGV   | VEX encoding

  THE RESULT, and it is not a timing table at all:
    Every ALIGNED form faults at +8 bytes and every unaligned
    form returns -- LEGACY AND VEX ALIKE.
                </pre>
                </div>
                <p>Read the last two rows before reading anything else on this page. <code>vmovaps</code> and the VEX form of <code>vmovdqa</code> <strong>fault exactly like their legacy twins</strong>, and this course was written asserting that they would not. That claim is retraction 15, and it is the commonest false statement about AVX: that the VEX prefix removed the alignment requirement. It did not.</p>
                <div class="formula">
   WHAT AVX ACTUALLY RELAXED, and it is
   a much smaller claim than the one
   everybody quotes.

   NOT THIS   "VEX removed the alignment
               requirement."   It did not.
               vmovaps faults on the same
               addresses movaps faults on.

   THIS       the FUSED memory operand --
               vaddps ymm0,ymm1,[rbx] is one
               instruction, and the legacy
               form was a LOAD then an ADD,
               and the load could fault on an
               address the add never saw.
               Plus: the move instructions
               were relaxed for unaligned
               STORES in the AVX encoding.
            </div>
                <p>And the SDM says the thing the measurement found, in as many words: the memory operand &ldquo;must be aligned on a 16-byte (128-bit version), 32-byte (VEX.256) or 64-byte (EVEX.512) boundary or a <code>#GP</code> will be generated.&rdquo; The <code>#GP</code> is the interesting half, because it becomes a <code>SIGSEGV</code> in a user process and looks identical to an out-of-bounds access. <strong>A misaligned <code>movaps</code> is indistinguishable, from the kernel's point of view, from a wild pointer</strong> &mdash; and that is a real cost of the aligned form that has nothing to do with speed.</p>
                <p>One row deserves its own note. <code>vmovdqa load</code> appears <strong>twice</strong> in that table &mdash; once with a legacy prefix and once with a VEX one &mdash; and they are two probes that share a spelling. A harness that counted <em>names</em> would collapse them to one and conclude the table had nine rows. The partition this concept asserts is over <em>probes</em>, and the harness checks that the two sets of five and four sum to ten without any row appearing in both.</p>
            </div>

            <div class="unit unit-example">
                <h2>The trap the alignment rule hides</h2>
                <p>Here is the thing that makes this rule cost real money. A misaligned <code>movaps</code> raises <code>#GP</code>, the kernel turns that into a <code>SIGSEGV</code>, and the resulting core dump points at a <em>wild pointer</em>. So the failure mode of a vectorised loop over a correctly-sized buffer looks exactly like the failure mode of a buffer overrun &mdash; and the two have completely different fixes.</p>
                <p>There is a second trap, and it is the one that cost this course a retraction. The obvious way to write the probe is in C:</p>
                <div class="hex-dump">
                <pre>$ gcc -O2 -mavx2 -S probe.c | grep -A2 'vmov\|movap'
        vmovaps  (%rax),%ymm0        # the compiler chose the ALIGNED form
                </pre>
            </div>
                <p>You asked for a load and got a <em>faulting</em> load, and on a machine where the buffer happens to be 16-byte aligned the experiment passes and teaches you nothing. Worse, the &ldquo;m&rdquo; constraint on a <code>double[4]</code> makes gcc emit a safe sequence instead, so the instruction you meant to test is not in the binary at all &mdash; and a probe that was never executed reports &ldquo;returned&rdquo; just as cleanly as one that was. That is retraction 11, and the build script here answers it by disassembling every probe body and letting the harness assert the mnemonics are present. <strong>A probe that returns must have run, and the only way to know is to look at the bytes.</strong></p>
                <p>The general form is worth carrying: <em>when you are measuring a property of one instruction, write that instruction yourself and then prove it is the one that ran.</em> Everything else in this course is downstream of that habit.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce the ten probes.</strong> <code>cd courses/x86simd/assets/samples &amp;&amp; ./build_samples.sh</code>, then read section 2. <em>(Expect six rows to fault and four to return, and expect the two VEX rows to be the surprise. On a machine whose SDM section differs, the <code>vmovaps</code> row is the one that tells you your expectation was wrong rather than the machine.)</em></li>
                    <li><strong>Break the probe the way it was broken before.</strong> Write the aligned load in C as <code>*(volatile __m128 *)p</code> and let the compiler pick the instruction, then disassemble the body. <em>(Expect <code>vmovaps</code> or <code>vmovdqa</code>, and expect the &ldquo;m&rdquo; constraint on a <code>double[4]</code> to make gcc emit a safe sequence instead &mdash; which is retraction 7 in <a href="/courses/simd/lessons/simd-compiler">the SIMD course's compiler concept</a> and the reason the probe bodies here are hand-written asm. A probe that silently uses a different instruction than the one you meant to test is the commonest failure in this whole collection.)</em></li>
                    <li><strong>Find the four-byte and eight-byte arms.</strong> Take the same probe body and substitute <code>movss</code> and <code>movsd</code> for the packed forms. <em>(Expect them to return at +2 bytes and fault at +4 relative to an 8-byte boundary, and then work out what a compiler does when it has a 4-byte-aligned struct and a 16-byte-aligned local. The alignment of a <em>struct member</em> is a language question, and the answer propagates straight into a fault.)</em></li>
                    <li><strong>Write the check your compiler will not do for you.</strong> Take a real vector loop and add, before it, an assertion that the pointer is 16-byte aligned. <em>(Expect it to pass almost always and to catch a real bug about once a month, which is a bad ratio for an assertion and a good one for the alternative. Then <code>memalign</code> the buffer and watch the assertion become dead code that the optimizer removes &mdash; and notice that this is a real fix and also a way of making the compiler stop telling you about the bug.)</em></li>
                    <li><strong>Measure the thing this concept says is not a speed difference.</strong> Time <code>movups</code> against <code>movaps</code> on data that is already 16-byte aligned. <em>(Expect almost no difference, and expect a difference on hardware where the unaligned form crosses a cache line &mdash; which is why the aligned form exists and why &ldquo;the aligned form is faster&rdquo; is true on some machines and not on yours. The requirement is unconditional; the cost is not.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/simd/lessons/simd-width">the SIMD course's width concept</a> measured that doubling the width did not double the throughput, and <a href="/courses/simd/lessons/simd-boundaries">its boundary concept</a> is where a tail is handled. This page is the <em>safety</em> half of the same territory, and it deliberately does not repeat the width experiment. <a href="/courses/smp/lessons/smp-atomic">The SMP course</a> owns what happens when two cores touch the same aligned line at once; the last three concepts here are that, for x86-64 specifically.</p>
                <p>Forwards. The <code>#GP</code> that a misaligned aligned-form load raises is the same fault the <a href="/courses/x86sys/lessons/x86-boundary">third course's inventory</a> counted as <code>si_code 128</code>, so the mechanism is one you have already met as a number. What this page adds is that a fault can be produced by a <em>correctly bounded</em> access to a <em>correctly sized</em> object, which is a category the address-space model alone does not have. The next concept is what the encoding did to the same registers, and its first finding is that VEX did not touch this rule at all.</p>
                <p>Outward. The aligned/unaligned split is the single most common place where a portable program stops being portable, and it is worth noticing <em>who</em> picked the requirement: the <code>a</code> forms were added in 1999 for machines that could not load across a cache line cheaply, and every instruction since has inherited the letter. <a href="/courses/simd/lessons/simd-compiler">The compiler concept in the SIMD course</a> is where a language decides which of these eight rows your program actually executes, and in every case the answer was &ldquo;not the one you wrote.&rdquo;</p>
            </div>

            <div class="lesson-footer">
                <span>Start of The x86-64 Data Path &middot; <a href="/courses/x86simd">course index</a></span>
                <span>Next: <a href="/courses/x86simd/lessons/x86-avx">AVX and AVX2: Three Operands, vzeroupper, and the Upper Half</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
