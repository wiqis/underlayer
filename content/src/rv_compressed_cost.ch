// The RISC-V ABI -- Concept 4: the consequence of the compressed extension,
// and what a disassembler has to do to find an instruction boundary.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rv_compressed_cost() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("What Compression Does to the ABI and to Disassembly — Underlayer")
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
                    <button onclick="closeShortcuts()" class="shortcuts-close">Close</button>
                </div>
            </div>
            <div class="reading-controls">
                <label>Font: <select id="font-size" onchange="setFontSize(this.value)"><option value="small">Small</option><option value="medium" selected>Medium</option><option value="large">Large</option></select></label>
                <label>Spacing: <select id="line-height" onchange="setLineHeight(this.value)"><option value="compact">Compact</option><option value="normal" selected>Normal</option><option value="relaxed">Relaxed</option></select></label>
                <label>Letters: <select id="letter-spacing" onchange="setLetterSpacing(this.value)"><option value="tight">Tight</option><option value="normal" selected>Normal</option><option value="loose">Loose</option></select></label>
                <label>Width: <select id="content-width" onchange="setContentWidth(this.value)"><option value="narrow">Narrow</option><option value="normal" selected>Normal</option><option value="wide">Wide</option></select></label>
            </div>
            <h1>What Compression Does to the ABI and to Disassembly</h1>
            <div class="lesson-meta">24 min &middot; <a href="/courses/rvabi">The RISC-V ABI, and the Register That Isn&rsquo;t There</a></div>

            <div class="unit unit-why">
                <h2>Why this page is a consequence and not a repeat</h2>
                <p><a href="/courses/rvasm/lessons/rv-compressed">rv-compressed</a> already measured the <strong>encoding</strong> side of the C extension: how many code points are reserved, which displacement families share five bit positions and are assigned seven different orders, and the four assembler refusals in the compressed register file. <strong>None of that is repeated here.</strong> What is measured here is the <em>consequence</em>, which is a different subject with a different kind of evidence: a spilling sequence, a hot loop, a <code>jal</code>/<code>ret</code> pair, and what a <strong>disassembler</strong> has to do to find an instruction boundary.</p>
                <p>Every number on this page is an <strong>INSTRUCTION COUNT or a BYTE COUNT</strong>. They are NOT a speedup, and the reason is the whole of the first section of <a href="/courses/rvabi">this course</a>: there is no RISC-V machine, no emulator and no RISC-V linker on this host, so there is nothing here that could measure one. <strong>The x86-64 ABI course measured ratios on hardware it could run; this course has no counterpart and does not estimate one.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>The confound, which is the most useful result in the section</h2>
                <p>Almost every &ldquo;what does compression cost&rdquo; measurement in the wild is a comparison of two <code>-march</code> settings that differ in more than one letter. Here, two pairs, and the difference between them is the lesson:</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/file    without C/,+8p'
  file    without C   insns  with C  d-insns  bytes  bytes+c  saved  2-byte
  cpc.c   rv64i       84     80     -4       336    200      40%    75%
  cpc.c   rv64imafd   74     80     +6       296    200      32%    75%
  regs.c  rv64i       165    127    -38      660    350      46%    62%
  regs.c  rv64imafd   127    127    +0       508    350      31%    62%
  abi.c   rv64i       389    368    -21      1556   1296     16%    23%
  abi.c   rv64imafd   368    368    +0       1472   1296     11%    23%
                </pre>
                </div>
                <p><strong><code>rv64i</code> vs <code>rv64gc</code> is CONFOUNDED.</strong> <code>rv64i</code> has no F and no D, so every <code>double</code> in the source becomes a CALL to a soft-float helper. The instruction count moves because the <em>arithmetic</em> changed, not because the encoding did. The <code>d-insns</code> column for that pair is large &mdash; <strong>&minus;38 for <code>regs.c</code></strong> &mdash; and <strong>every bit of that is the SOFT-FLOAT library and not the encoding</strong>. A reader who reported that difference as &ldquo;what compression costs&rdquo; would be reporting a floating-point software-library decision as an encoding fact, and both numbers would be real, which is exactly what makes the mistake survive review.</p>
                <p><strong><code>rv64imafd</code> vs <code>rv64imafdc</code> is CLEAN.</strong> Same base, same M, same A, same F, same D &mdash; and the only difference is the trailing C. There the <code>d-insns</code> column is <strong>+0, +0 and +6</strong>, and the honest answer is that it is <strong>ZERO OR ALMOST</strong>: <strong>the C extension changes how many BYTES an operation takes, and it does not change how many operations the compiler chose to perform.</strong></p>
                <p>And the +6 is the interesting cell, because it falsifies &ldquo;compression never changes the instruction count&rdquo; just as surely as the two zeros falsify the opposite. <code>cpc.c</code> at <code>rv64imafdc</code> emits <strong>six more instructions</strong> than at <code>rv64imafd</code>. The reason is a <strong>register constraint</strong>: the compressed forms can only name x8 to x15, and a register allocator that has to respect that will sometimes reach for a register the uncompressed encoding would not have needed. <strong>So the claim &ldquo;adding C changes bytes and not instructions&rdquo; is TRUE for two files of three and FALSE for the third</strong>, and the artifact prints that as retraction R5 rather than rounding it away.</p>
                <p>Read the two pairs side by side and the lesson is general: <strong>a <code>-march</code> comparison is a measurement of ONE extension only when every other letter is held fixed</strong>, and &ldquo;hold every other letter fixed&rdquo; has to be said out loud because the alternative &mdash; comparing the base against a <code>gc</code> build and calling the difference a compression result &mdash; is a category error that survives review because both numbers are real.</p>
            </div>

            <div class="unit unit-example">
                <h2>Three sequences, before and after, instruction by instruction</h2>
                <p>Same source, <code>-O2</code>, and the same ISA apart from the C. <strong>MEASURED-ON-BYTES</strong>, decoded rather than disassembled:</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/THE THREE SEQUENCES/,+6p'
  rv64imafd   spill   11 instructions, 44 bytes:
    slli a1,a0,1 | slli a2,a0,32 | add a1,a1,a0 | slli a0,a0,35 |
    add a0,a0,a2 | addi a2,zero,1 | slli a2,a2,32 | add a0,a0,a2 |
    srai a0,a0,32 | add a0,a0,a1 | jalr zero,0(ra)

  rv64imafdc  spill   11 instructions, 26 bytes:
    slli a1,a0,1 | slli a2,a0,32 | c.add a1,a0 | c.slli a0,35 |
    c.add a0,a2 | c.li a2,1 | c.slli a2,32 | c.add a0,a2 |
    c.srai a0,32 | c.add a0,a1 | c.jr ra

  rv64imafd   callret   4 instructions, 16 bytes:
    slli a1,a0,1 | add a0,a1,a0 | addiw a0,a0,2 | jalr zero,0(ra)

  rv64imafdc  callret   4 instructions, 10 bytes:
    slli a1,a0,1 | c.add a0,a1 | c.addiw a0,2 | c.jr ra
                </pre>
                </div>
                <p><strong>Eleven instructions and 44 bytes become eleven instructions and 26 bytes.</strong> Four and sixteen become four and ten. <strong>Every saving here is a <code>c.add</code> for an <code>add</code>, a <code>c.jr ra</code> for a <code>jalr</code>, and a <code>c.addi</code> for an <code>addi</code> &mdash; and the instruction count does not move at all.</strong></p>
                <p>Read the call/return pair twice, because it is the most compressed thing in the corpus and for a reason that is about the ABI rather than about the encoding. <code>jalr zero, 0(ra)</code> becomes <code>c.jr ra</code>: <strong>the compressed form has no operand for the link register because the cell <em>is</em> the return</strong>, and that is the same design decision that put the return address in a register in the first place. And <code>addiw a0, a0, 2</code> becomes <code>c.addiw a0, 2</code> &mdash; the compressed word form exists precisely because <strong>RV64 has a 32-bit <code>addw</code> and 32-bit operations are overwhelmingly the common case in compiled code.</strong></p>
                <h3>The spill, and the row that falsifies the easy claim</h3>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/AND THE SPILL, WHICH/,+6p'
  rv64imafd   spill    11 instructions, 44 bytes, 0 stores
  rv64imafdc  spill    11 instructions, 26 bytes, 0 stores

  rv64imafd   spilln   43 instructions, 172 bytes, 1 stores
  rv64imafdc  spilln   49 instructions, 124 bytes, 4 stores
                </pre>
                </div>
                <p><code>spilln</code> is the function that spills eight callee-saved registers, and the numbers are the most interesting on this page: <strong>124 bytes against 172 is a 28% saving, and the instruction count went UP, from 43 to 49.</strong> Six more instructions, four more stores, and a frame that is <strong>smaller</strong> in the compressed build.</p>
                <p>So a callee that spills eight registers does <em>more</em> work in the compressed build than the same callee in the uncompressed one, and the reason is not that compression made anything slower. <strong>The compressed store forms have register constraints</strong> &mdash; <code>c.sd</code> and <code>c.sw</code> can only name x8 to x15 &mdash; and when the value being saved is not in that window the allocator has to move it there first, and the move is an instruction. <strong>The compressed encoding is not uniformly shorter per operation: it is shorter per operation THAT IT ENCODES, and the register allocator reacts to that by storing differently.</strong> That is retraction R7, and it is a retraction because the obvious prediction &ldquo;the callee that spills less does less work&rdquo; measured the other way round.</p>
                <h3>The hot loop, whose BODY is the thing that repeats</h3>
                <p>A whole-function byte count measures the wrong code: the prologue runs once and the body runs <em>n</em> times. So here is the body &mdash; the instructions between the first branch and the backward branch, which is the part that repeats:</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/THE HOT LOOP/,+5p'
  rv64imafd   hot: 12 instructions, 48 bytes whole; the loop body is
              11 instructions and 44 bytes
  rv64imafdc  hot: 12 instructions, 30 bytes whole; the loop body is
              11 instructions and 28 bytes
                </pre>
                </div>
                <p><strong>44 bytes of body become 28.</strong> And read which instructions did <em>not</em> compress: <code>lw a3, 0(a0)</code> stays four bytes as <code>c.lw a3, 0(a0)</code> &mdash; <strong>because the register constraints refuse it</strong> &mdash; and <code>slli a4, a3, 1</code> stays four bytes as well, because the shift amount does not fit the compressed six-bit field. <strong>Compression is not a uniform discount on a function; it is a per-instruction question, and the answer is &ldquo;no&rdquo; a surprising fraction of the time.</strong> That is the <a href="/courses/rvasm/lessons/rv-compressed">encoding side</a> arriving as a consequence.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The boundary problem, which is where this stops being about the ABI</h2>
                <p>On x86-64 and AArch64 an instruction&rsquo;s length is a <strong>CONSTANT</strong>, so a disassembler&rsquo;s loop is:</p>
                <div class="hex-dump">
                <pre>    p += 4
                </pre>
                </div>
                <p>and the loop cannot be wrong. On RISC-V an instruction is TWO or FOUR bytes and the loop is:</p>
                <div class="hex-dump">
                <pre>    if (halfword &amp; 3) == 3:  p += 4
    else:                      p += 2
                </pre>
                </div>
                <p>which needs <strong>TWO BITS OF THE CURRENT POSITION</strong> and nothing else. That is the whole of the guarantee, and it is enormous: <strong>a word the decoder cannot name at all still advances <code>p</code> by its own length</strong>, so an unmodelled instruction is a gap in the NAMES rather than a gap in the WALK. This is <code>rvdec.py</code>&rsquo;s central problem and it is the reason a RISC-V disassembler is a different program from an AArch64 one.</p>
                <p>And the demonstration is measured rather than asserted. The artifact walks every code section of every corpus object with the rule, and again with the length SUPPLIED from outside, and reports how many instructions each walk found:</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/instructions found by the RULE/,+6p'
  object             by the RULE   with the length SUPPLIED   verdict
  probe.o            18            13                          DIFFERENT
  abi_O0.o           927           748                         DIFFERENT
  abi_O2.o           368           324                         DIFFERENT
  noflags_O2.o       74            46                          DIFFERENT
  regs_O2.o          127           87                          DIFFERENT
  ...
  6048 instructions found by the two-bit rule and 5012 found with the
  length handed in, across 25 code sections of 25 objects.
                </pre>
                </div>
                <p><strong>6,048 against 5,012 &mdash; and they are NOT equal, which is the point.</strong> If they were equal, the rule would be doing no work: the count would be entirely explained by the symbol table&rsquo;s instruction sizes. The supplied version is what a disassembler <em>with</em> a symbol table can do and the rule version is what one <em>without</em> must do, and the difference of 1,036 instructions is the population where the two disagree about where a boundary is. <strong>So the rule is load-bearing, and it is TWO BITS.</strong></p>
                <p>A reader arriving from AArch64 &mdash; where the loop is <code>p += 4</code> and cannot be wrong &mdash; has to learn this from an <em>encoding</em> rather than from an argument, because there is no RISC-V machine here to run the wrong answer on. And that is the honest end of the concept: <strong>the cost of compression is measurable in bytes, and the cost of NOT having compression is measurable in a two-bit rule, and neither of them needs hardware.</strong></p>
                <p>And what none of this can show, stated where a reader would otherwise expect the number: <strong>fewer bytes is a statement about instruction FETCH, and even that needs a memory system this course cannot measure.</strong> Fewer bytes, the same operations, and no timing. The honest sentence under that table is exactly that one, and a course that put a ratio there would be inventing a measurement it did not take.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Break the length rule and watch the instruction count move.</strong> <em>(This is the artifact&rsquo;s own poison 3, and it is four lines of code. Replace <code>p += 4</code> with <code>p += 2</code> in the rule and re-run: the walk will desynchronise, and the cross-check&rsquo;s named-instruction count will collapse while the disagreement count stays at zero &mdash; <strong>because the two readers would be reading the same wrong boundaries.</strong> That is the failure mode a decoder has that a timing measurement does not: it can be confidently wrong and self-consistent. Then restore it and confirm the count returns.)</em></li>
                    <li><strong>Build the confounded pair yourself, and then the clean one.</strong> <em>(Compile <code>regs.c</code> at <code>-march=rv64i</code> and at <code>-march=rv64gc</code>, count instructions, and get &minus;38. Then compile at <code>-march=rv64imafd</code> and <code>-march=rv64imafdc</code> and get <strong>zero</strong>. The two answers differ by 38 and the difference is entirely floating-point software. <strong>Hold every other letter fixed or do not report the comparison</strong> &mdash; and the way to know you did not hold them fixed is that a number is suspiciously large.)</em></li>
                    <li><strong>Find the instruction that refuses to compress and say why.</strong> <em>(In the <code>hot</code> loop above, <code>lw a3, 0(a0)</code> does not become two bytes. It is not because the instruction is important; it is because <code>c.lw</code> can only name <code>rd'</code> in x8&ndash;x15 and <code>a0</code> and <code>a3</code> are outside that window. Now write the same load with a pointer in <code>s0</code> and a destination in <code>a2</code> and watch the same instruction become two bytes. <strong>Compression is a property of the register numbers a program happens to use</strong>, and that is why the &ldquo;percentage of bytes saved&rdquo; column is a statement about one compiler&rsquo;s register allocation.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/rvasm/lessons/rv-compressed">rv-compressed</a> is the encoding half this page is the consequence of, and the two are deliberately not merged: reserved code points and displacement permutations are one subject, and what a spill and a hot loop actually become is another. <a href="/courses/rvabi/lessons/rv-registers">Concept 3</a> is where the x8&ndash;x15 window is introduced as a register-file fact, and this page is where it turns into an instruction-count difference.</p>
                <p>Across architectures, <a href="/courses/isa/lessons/isa-length">isa-length</a> is the general question this page answers for one architecture, and <a href="/courses/a64asm/lessons/a64-encoding">a64-encoding</a> is the case where the answer was <code>p += 4</code> and the field map <em>is</em> the curriculum. <strong>RISC-V has the same goal as AArch64 &mdash; keep the decoder simple &mdash; and pays for it differently: not with a constant length, but with a two-bit rule that is cheap to state and impossible to verify by eye.</strong></p>
                <p>And <a href="/courses/rvasm/lessons/rv-verify">rv-verify</a> is where the unmodelled words in that 6,048-versus-5,012 difference get named. This page counts the gap; that one decodes what is in it.</p>
                <p>Forwards, this is the last RISC-V concept, and the thing it hands to the next architecture is a habit rather than a fact: <strong>when you see a size comparison, ask which other things changed at the same time</strong>. The <code>-march</code> confound above is the same shape as the soft-float surprise in <a href="/courses/rvasm/lessons/rv-isa">rv-isa</a> and as the F/D removal in the ABI course before it, and all three are the same mistake wearing different clothes.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/rvabi/lessons/rv-registers">The Register File as Roles, Not Numbers</a></span>
                <span>Next: <a href="/courses/rvabi">Back to the course</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
