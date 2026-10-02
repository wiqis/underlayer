// The RISC-V ABI -- Concept 2: the absence, and the constructive half.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rv_noflags() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("No Flags Register, No Condition Codes, No CMOV — Underlayer")
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
            <h1>No Flags Register, No Condition Codes, No CMOV</h1>
            <div class="lesson-meta">27 min &middot; <a href="/courses/rvabi">The RISC-V ABI, and the Register That Isn&rsquo;t There</a></div>

            <div class="unit unit-why">
                <h2>Why an absence is worth twenty-seven minutes</h2>
                <p>Here is the spine, in the course mission&rsquo;s own words, and every page of this section is downstream of it:</p>
                <div class="hex-dump">
                <pre>  RISC-V has no flags register and no condition codes.  x86-64 has
  EFLAGS, AArch64 has NZCV, RISC-V has NOTHING -- so a branch is the
  only conditional thing, and that single absence explains why
  AArch64 needs csel/cset at all and why a compiler emits a branch on
  one target and a cmov on another.
                </pre>
                </div>
                <p>An absence is the hardest kind of claim to teach, because there is nothing to point at. A reader who has never compared the three targets has no reason to believe that <code>CMOVcc</code> is not merely <em>unusual</em> on RISC-V but <strong>absent</strong> &mdash; and the difference between those two is the difference between &ldquo;clang chose a branch here&rdquo; and &ldquo;clang had no choice.&rdquo;</p>
                <p>And it is <strong>fully measurable without hardware</strong>, which is why this course exists on a host with no RISC-V silicon. <strong>The compiler&rsquo;s choice is a static property of its output, and the output is bytes.</strong> There is no RISC-V machine here, no emulator, no RISC-V linker, and no timing anywhere in this course &mdash; but none of those are needed to establish that a mnemonic does not appear in an object file, or that one does.</p>
                <p>What is <em>not</em> needed here and is worth saying plainly: <strong>this page cannot tell you which of the three targets is faster.</strong> Not the branch, not the <code>cmov</code>, not the mask. The x86-64 ABI course in the first section measured a 4.92x and a 27.65x on hardware it could run; this course has no counterpart for either number and does not invent one. Read the counts below as counts.</p>
            </div>

            <div class="unit unit-model">
                <h2>The manual admits it, and the admission is the whole argument</h2>
                <p>A course that <em>inferred</em> the absence from a compiler&rsquo;s output would be arguing from a hole, and a hole is weak evidence. The manual says it outright, and saying so is what turns a negative into a measurement of a documented decision. <strong>QUOTED</strong>, <code>rv32-unprivileged</code>, the branch-design note:</p>
                <div class="hex-dump">
                <pre>  "We considered but did not include conditional moves or predicated
   instructions, which can effectively replace unpredictable short
   forward branches."
                </pre>
                </div>
                <p>Read what that concedes. <strong>It is not a claim that a conditional move would be slower.</strong> It is a claim that a conditional move <em>can</em> replace an unpredictable short forward branch, and that the architecture declined to let it. So the absence is a choice, and this course is measuring a choice rather than inferring one from a gap in a table.</p>
                <p>The same note says the design went the other way deliberately, in a sentence that names the alternatives:</p>
                <div class="hex-dump">
                <pre>  "The conditional branches were designed to include arithmetic
   comparison operations between two registers ... rather than use
   condition codes (x86, ARM, SPARC, PowerPC)."
                </pre>
                </div>
                <p>That is the reason <code>blt</code> exists at all. On x86-64 a comparison is an instruction that writes a register you do not name (<code>cmp</code> sets EFLAGS), and a branch is a separate instruction that reads it (<code>jl</code>). <strong>On RISC-V the comparison IS the branch</strong> &mdash; <code>blt a0, a1, target</code> compares two registers and transfers control, and there is no separate instruction and no state in between.</p>
                <h3>THE THREE ANSWERS, and there are exactly three</h3>
                <p>With no <code>CMOVcc</code> and no <code>SETcc</code> to reach for, a compiler implementing <code>x &lt; 0 ? a : b</code> has three moves and no fourth:</p>
                <ul>
                    <li><strong>BRANCH</strong> &mdash; the condition <em>is</em> the branch. Two instructions for a select, and the control flow is no longer straight-line.</li>
                    <li><strong>MASK</strong> &mdash; turn the condition into 0 or 1 in a register and select arithmetically with <code>xor</code>/<code>sub</code>/<code>and</code>. Straight-line, three instructions, and it computes both sides.</li>
                    <li><strong>CALL</strong> &mdash; give up and call a helper. The corpus measures this and finds <strong>zero</strong> at every optimisation level, which is itself worth printing: a classifier that quietly folds the unrecognised into one of the two interesting buckets is a classifier that cannot report its own ignorance, so the third column exists even though it is empty.</li>
                </ul>
            </div>

            <div class="unit unit-example">
                <h2>Eleven functions of <code>?:</code>, four levels, three buckets</h2>
                <p>The corpus is <code>noflags.c</code>: eleven functions, every one of them a <code>?:</code> on an integer condition, compiled at four optimisation levels and classified on the mnemonic by the decoder, out of the object file. <strong>MEASURED</strong>.</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/level  branch/,+5p'
  level  branch  mask  other  calls  what is called
  -O0    79      47    245    0      (none)
  -O1    32      34    9      0      (none)
  -O2    32      33    9      0      (none)
  -Os    30      31    9      0      (none)
                </pre>
                </div>
                <p>Read the branch column and the mask column together at <code>-O2</code> and the shape is the finding: <strong>the compiler picks a BRANCH for most of the corpus and reaches for ARITHMETIC only where arithmetic is cheaper than a branch</strong> &mdash; <code>myabs</code>, <code>mask</code>, <code>sign</code>, <code>absu</code>, which are all the same three-instruction idiom, plus <code>sign</code>, which is <em>one</em> instruction. And the <code>other</code> column falls from 245 to 9 as the optimiser stops emitting the bookkeeping the audit is counting, which is the reader&rsquo;s warning that a count over <code>-O0</code> is a count of a compiler&rsquo;s scaffolding.</p>
                <h3>THE CONSTRUCTIVE HALF, which is the half nobody states</h3>
                <p>Here is the row the course title is about, instruction by instruction at <code>-O2</code>, decoded from the bytes. <strong>MEASURED-ON-BYTES</strong>:</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/THE CONSTRUCTIVE ROW/,+22p'
  function  bytes  instruction
  myabs     4      sraiw      a1, a0, 31
  myabs     2      c.xor        a0, a1
  myabs     2      c.subw       a0, a1
  myabs     2      c.jr         ra
  mymin     4      blt        a0, a1, 0x10
  mymin     2      c.mv         a0, a1
  mymin     2      c.jr         ra
  mysel     2      c.beqz       a0, 0x36
  mysel     2      c.mv         a2, a1
  mysel     2      c.mv         a0, a2
  mysel     2      c.jr         ra
  mask      4      sraiw      a1, a0, 31
  mask      2      c.xor        a0, a1
  mask      2      c.subw       a0, a1
  mask      2      c.jr         ra
  sign      4      srliw      a0, a0, 31
  sign      2      c.jr         ra
  absu      4      srliw      a1, a0, 31
  absu      2      c.xor        a0, a1
  absu      2      c.subw       a0, a1
  absu      2      c.jr         ra
                </pre>
                </div>
                <p><code>sign</code> is <strong>ONE instruction</strong>: <code>srliw a0, a0, 0x1f</code>, and that is the whole of <code>(x &lt; 0) ? 1 : 0</code> for a signed int. <strong>There is no <code>SETcc</code> to reach for and there is nothing to reach for one WITH</strong> &mdash; the comparison never left a register, it went straight into the shift&rsquo;s operand. The result is a program in which the condition is a <strong>VALUE</strong> rather than a <strong>STATE</strong>, and that distinction is the whole of the difference between the three architectures.</p>
                <p>So <strong>the absence of a flags register is not only a cost. It is what makes <code>min</code>, <code>max</code>, <code>clamp</code> and <code>abs</code> expressible without a conditional move at all.</strong> The RISC-V answer is that <code>sltu</code> <strong>WRITES A REGISTER</strong>, so the comparison&rsquo;s result is data and the selection is arithmetic on data. On x86-64 the comparison&rsquo;s result is <strong>bits in a register you do not name</strong>, so the selection has to be an instruction that reads those bits &mdash; and that instruction is <code>CMOVcc</code>.</p>
                <p>Read <code>myabs</code> against the same C on x86-64: <code>mov</code> / <code>neg</code> / <code>cmovs</code>. Also three instructions, but <strong>one of the three reads flags</strong>, and the instruction that reads flags is one an architecture has to define, specify, and give a mnemonic. RISC-V&rsquo;s three are <code>sraiw</code>/<code>xor</code>/<code>sub</code>, and none of them is conditional.</p>
                <p>And <code>mymin</code> is a <strong>BRANCH</strong>: <code>blt a0, a1, .LBB1_2</code>, then <code>mv</code>, then <code>ret</code>. That is where a compiler with <code>CMOVcc</code> would have written a conditional move and this one cannot &mdash; and <strong>the interesting fact is that it does not want to</strong>. <code>mymin</code> is three instructions and <code>cmov</code> would have made it four.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Three targets, one C function, three DISJOINT sets</h2>
                <p>Now the comparison that the whole section exists for. <strong>One source file, three <code>--target=</code> flags, one compiler, one optimisation level</strong> &mdash; so a row that disagrees with another row is a difference between the targets and not between the bodies of work someone typed. <strong>IT IS NOT A TIMING AND NOT A SPEEDUP</strong>, and there is no ratio anywhere in this table.</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/the mnemonics in the corpus/,+3p'
  target  the mnemonics in the corpus            the idiom they are        total
  riscv64  blt(6), bge(4), c.beqz(5), c.bnez(1), bne(1)   branches          17
  aarch64  csel(14), cneg(2)                     conditional moves / sets 16
  x86-64   cmovel(3), cmoveq(3), cmovgel(1),
           cmovgl(3), cmovll(4), cmovsl(2)        conditional moves        16

  THE THREE SETS, DISJOINT -- computed, and printed whatever they
  turn out to be:
    riscv64  n x86-64   = EMPTY
    aarch64  n riscv64  = EMPTY
    aarch64  n x86-64   = EMPTY
    union of the three = 13 distinct mnemonics; sum of the sets = 13
    and every set is non-empty: aarch64=2, riscv64=5, x86-64=6
                </pre>
                </div>
                <p><strong>Union is 13, sum of the three sets is 13, so nothing is in two sets.</strong> The disjointness is <em>computed</em>, and printed whether or not it is empty, because the first version of this section wrote the word &ldquo;disjoint&rdquo; in a paragraph and never computed an intersection &mdash; which is the difference between a claim and a measurement, and the same failure shape as the zero-disagreement cross-check.</p>
                <p>And note the shape of each set. <strong>RISC-V&rsquo;s five are all branches.</strong> AArch64&rsquo;s two are <code>csel</code> and <code>cneg</code>. x86-64&rsquo;s are six <code>cmov</code> spellings &mdash; six rather than one because <code>cmovll</code> is the 32-bit &ldquo;less&rdquo; form and <code>cmovll</code> is not <code>cmovl</code>, and there are sixteen conditions times two operand sizes. A reader who wants to see that table is better served by a prefix match than by sixteen enumerated spellings, and the artifact matches on the prefix for a reason it documents: an enumerated table goes quietly empty the first time one is missed, and <strong>an empty table reads as &ldquo;this target has no conditional move&rdquo;, which is the one conclusion it must never support.</strong></p>
                <h3>The three idioms, instruction by instruction</h3>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/THE THREE IDIOMS SIDE BY SIDE/,+4p'
    mymin    a &lt; b ? a : b
      riscv64 : blt        a0, a1, 0x10 | c.mv         a0, a1 | c.jr         ra
      aarch64 : cmp   w0, w1    | csel  w0, w0, w1, lt | ret
      x86-64  : movl  %esi, %eax | cmpl  %esi, %edi | cmovll %edi, %eax | retq

        the idiom: riscv64 branch | aarch64 csel | x86-64 cmov
                </pre>
                </div>
                <p>Three architectures, one C function, one compiler &mdash; and <strong>the arithmetic is not a cost either.</strong> On x86-64 the sequence for <code>mymin</code> is <code>mov</code> / <code>cmp</code> / <code>cmov</code> / <code>ret</code>: four instructions where RISC-V&rsquo;s is three. And the reason is not that x86-64 is worse at selects:</p>
                <ul>
                    <li>x86-64 needs the <code>mov</code> because the candidate value has to be in the register the <code>cmov</code> will write, and it is not there yet.</li>
                    <li>AArch64 needs the <code>cmp</code> because NZCV has to be set before <code>csel</code> can read it.</li>
                    <li>RISC-V needs <strong>neither</strong>, because <code>blt</code> compares two registers as part of the branch and there is nothing to set up.</li>
                </ul>
                <p>So the absence of a flags register is not uniformly a cost. <strong>It costs the compiler a <code>CMOVcc</code> to reach for, and it saves the <code>mov</code> and the <code>cmp</code> that <code>CMOVcc</code> depends on.</strong> <strong>WHICH OF THOSE WINS ON REAL HARDWARE IS NOT MEASURABLE HERE AND IS NOT CLAIMED</strong> &mdash; there is no RISC-V machine, no AArch64 machine, and no cycle measured anywhere in this course.</p>
                <h3>Why <code>csel</code> has a fourth operand at all</h3>
                <p>&ldquo;<code>csel</code> exists because NZCV exists&rdquo; is only worth something if <code>csel</code> really is an instruction that reads a condition, and the condition is a <strong>four-bit field</strong>. The artifact decodes the AArch64 words with the AArch64 course&rsquo;s own <code>a64dec.py</code> &mdash; a second decoder, from a different course, and neither it nor <code>rvdec.py</code> is a disassembler:</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/word.*the reader says/,+3p'
  word        the reader says  the decoder says         condition field
  0x5a805400  cneg             cneg     w0, w0, mi   bits[15:12] = 0x5   cond 5
  0x1a81b000  csel             csel     w0, w0, w1, lt bits[15:12] = 0xb  cond 11
                </pre>
                </div>
                <p>And here is the out-of-encodings argument, counted rather than asserted. A conditional move needs <strong>three registers</strong> &mdash; two candidates and a destination &mdash; and the I-type format has three register fields: <code>rd</code> at bits[9:7], <code>rn</code> at bits[19:15], <code>rm</code> at bits[4:0]. A 64-bit I-type instruction is 32 bits: 7 of opcode, 3 of funct3, 15 of register, and 7 of immediate. <strong>The condition needs 4 bits and the immediate field has 7, so THERE IS NO ROOM LEFT for a condition</strong> in a word that already has three registers in it. <code>csel</code> is therefore a <strong>DIFFERENT ENCODING</strong>, not an instruction with an extra field &mdash; which is the strongest form the argument can take, because it is arithmetic rather than a design preference.</p>
                <p>One parsing note, because it is the kind of failure that prints like a result. The first version of that table matched the disassembly with a regex over the whole line, and its <code>\s+</code> after the instruction word <strong>consumed the tab along with the padding</strong> &mdash; so the &ldquo;mnemonic&rdquo; it captured was the first operand. Nothing matched, the table came out empty, and the section that exists to prove that <code>csel</code> is an instruction rather than a name <strong>reported no instruction and no error</strong>. The section now says how many words it found, and it splits the line on its tab.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Prove the absence by trying to write it.</strong> <em>(Write <code>c.mv a0, a1</code> and then write <code>cc.mv a0, a1</code>, or <code>setl a0</code> if you want a diagnostic. Assemble both for <code>riscv64</code>. The first succeeds; the second is not an instruction on this architecture, and an assembler that rejects a mnemonic is the cheapest possible proof that a mnemonic is <em>absent</em> rather than merely unused. Then count the <code>?:</code> in the surrounding code that could have used it.)</em></li>
                    <li><strong>Count branches, and read the number as register pressure rather than style.</strong> <em>(<code>bigsel</code> takes fifteen arguments and makes five selects. At <code>-O2</code> the compiler emits FIVE BRANCHES and spills to the stack to reach the arguments past <code>a7</code>. There is no masking alternative that fits in the registers it has, so the branch is not a preference &mdash; it is the only encoding left. Now write your own function with fifteen arguments and one select, and see how many branches <em>it</em> gets. The count of branches in a function is a measure of how much register pressure the machine has, and that is a better use of the number than a style guide is.)</em></li>
                    <li><strong>Find the control row, and then break it.</strong> <em>(<code>twice</code> uses the SAME condition twice and collapses to a single <code>add</code> on all three targets &mdash; the compiler noticed the expression is commutative in the two selects and the condition vanished. Then perturb it so the two selects are not interchangeable and watch the branches come back. A corpus where every row came out the same way would be a corpus measuring nothing; a control you can break is what makes the rest believable.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/rvabi/lessons/rv-calling">concept 1</a> established the register set this page uses as operands: <code>a0</code>&ndash;<code>a7</code> and <code>fa0</code>&ndash;<code>fa7</code> are where values arrive, so the argument registers are what a <code>?:</code> operates on. <a href="/courses/rvasm/lessons/rv-immediate">rv-immediate</a> is where <code>blt</code>&rsquo;s displacement lives &mdash; and why it is a B format with a non-contiguous immediate, which is a cost of the same decision in the encoding.</p>
                <p>Across architectures, <a href="/courses/a64abi/lessons/a64-cond">a64-cond</a> is this page from the other side. There the condition codes <em>exist</em>, and the interesting question is what you can do with them &mdash; which is a question about the <em>breadth</em> of the conditional vocabulary. Here the interesting question is what a compiler does with <em>nothing</em>, and the answer turns out to include the single most useful instruction in the corpus. <strong>Same subject, opposite direction: on AArch64 the flags are the resource, on RISC-V the missing resource is what shapes the code.</strong></p>
                <p>And <a href="/courses/x86asm/lessons/x86-map">x86-map</a> is where <code>cmovll</code>&rsquo;s actual bit layout lives, because this page counts the six spellings without explaining why there are six. The size suffix and the condition suffix are two separate things in the ModRM byte, and the reason <code>cmovll</code> is not <code>cmovl</code> is a fact about the encoding rather than about spelling. <a href="/courses/x86asm/lessons/x86-flags">x86-flags</a> is the other half: it is where EFLAGS is treated as the register RISC-V does not have.</p>
                <p>Forwards, <a href="/courses/rvabi/lessons/rv-registers">concept 3</a> turns the absence into a register-count claim: <strong>a callee here saves fewer registers than an x86-64 callee for the same C, because there is no flags register to save</strong> &mdash; and that is countable in the corpus.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/rvabi/lessons/rv-calling">The Calling Convention</a></span>
                <span>Next: <a href="/courses/rvabi/lessons/rv-registers">The Register File as Roles, Not Numbers</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
