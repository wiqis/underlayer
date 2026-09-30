// The RISC-V ABI -- Concept 3: the register file as roles, and the two files.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rv_registers() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Register File as Roles, Not Numbers — Underlayer")
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
            <h1>The Register File as Roles, Not Numbers</h1>
            <div class="lesson-meta">24 min &middot; <a href="/courses/rvabi">The RISC-V ABI, and the Register That Isn&rsquo;t There</a></div>

            <div class="unit unit-why">
                <h2>Why the register list is a claim and not a caption</h2>
                <p>The ABI names <strong>roles</strong>. <code>t0</code> is x5, <code>s0</code> is x8 and is also called <code>fp</code>, <code>ra</code> is x1, <code>sp</code> is x2, <code>zero</code> is x0. <strong>And the encoding holds a NUMBER in every case, not a name.</strong> The register field is five bits wide and there are thirty-two things it can mean, so the disassembly&rsquo;s job is to pick a name &mdash; and sometimes there are two names for one number, and a reader who has only seen one of them will think the other is a different register.</p>
                <p>This concept is where the section&rsquo;s spine stops being a slogan and becomes a register count. <a href="/courses/rvabi/lessons/rv-noflags">Concept 2</a> showed that there is no register a comparison writes to. The consequence is countable: <strong>a RISC-V callee saves fewer registers than an x86-64 callee for the same C, because there is no flags register to save.</strong> That is the whole of what a register list is for, stated as a difference.</p>
                <p>And the page opens with a retraction, because the measurement that exists to settle the role-versus-number question &mdash; a census of all thirty-two registers across the whole corpus &mdash; <strong>was wrong the first time it ran, and wrong in a way no table of plausible names could reveal.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>The audit, before the census</h2>
                <p>The census counts register fields by reading the <strong>bits</strong> with this file&rsquo;s own table, and the first version of that table asked the inherited decoder for each field by name. Two things went wrong, and both produced numbers that looked entirely reasonable.</p>
                <p><strong>First: a decoder reads the fields its rendering needs.</strong> For <code>c.sdsp ra, 24(sp)</code> the inherited decoder emits <em>one</em> field line &mdash; the funct3 &mdash; and explains the rest in prose, because the CSS format&rsquo;s <code>rs2</code> exists only to be printed. So the lookup returned <strong>nothing</strong>, and the first version of the store audit reported the eighth integer argument of <code>m18</code> as having arrived in <code>t0</code> when it arrived in <code>a7</code>.</p>
                <p><strong>Second, and this is the one <a href="/courses/rvasm/lessons/rv-encoding">rv-encoding</a> exists for: a compressed register field is THREE bits and its value 0 means x8.</strong> Reading it with the five-bit table reports every register eight too small. The first version did exactly that, and the census printed <strong>131 writes to <code>x0</code></strong> &mdash; on an architecture where the manual says x0 is hardwired to zero and can never be written.</p>
                <p>So the table is not trusted. It is <strong>audited against a second rendering of the same bits</strong> &mdash; the operand list the inherited decoder printed, produced by different code in a different file &mdash; and the count is printed above the census, on every run:</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/BEFORE THE CENSUS/,+5p'
  BEFORE THE CENSUS, THE READER THAT PRODUCES IT IS AUDITED against
  the inherited decoder's own printed operands -- a SECOND rendering
  of the same bits, by a different code:

    5973 instructions checked, 5973 agree, 0 disagree
    10640 instructions placed from the FORMAT alone
    0 instructions this table could not place at all
                </pre>
                </div>
                <p>And it took four more rounds to get to 0, each of which was a real bug rather than a tuning problem. The last two were the sharpest: <strong>the base register of a floating-point load is in the INTEGER file</strong>, and <strong>the B format&rsquo;s <code>rs2</code> is at bits[24:20]</strong> and not bits[20:15] as the table first said. Both were found by the audit and neither was findable by reading the table, because a wrong lookup produces a <em>real register of the wrong kind</em> and a plausible disassembly.</p>
            </div>

            <div class="unit unit-example">
                <h2>Thirty-two registers, counted by role</h2>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/^  x   ABI name/,/^  31 /p'
  x   ABI name  role          printed text  as a source  as a dest
  0   zero      zero          185           110          75
  1   ra        ra            442           430          113
  2   sp        sp            187           623          126
  3   gp        gp            0             0            0
  4   tp        tp            0             0            0
  5   t0        temp          177           98           106
  8   s0        callee-saved  222           750          134
  10  a0        argument      2009          1169         1341
  11  a1        argument      1236          829          622
  ...                                      (a2 through a7 fall off)
  26  s10       callee-saved  0             0            0
  27  s11       callee-saved  0             0            0
  31  t6        temp          28            14           14
                </pre>
                </div>
                <p>The interesting rows are not the largest ones. Read these four:</p>
                <ul>
                    <li><strong>x0 is read constantly and written 75 times, and not one of those 75 writes takes effect.</strong> The manual says &ldquo;Register <code>x0</code> is hardwired with all bits equal to 0&rdquo; &mdash; <strong>QUOTED</strong> &mdash; and a hardwired register is not a register you can write. It is a <strong>constant with an encoding</strong>. Every arithmetic comparison on this architecture is written <code>sltu rd, rs1, x0</code> or <code>beq rs, x0, target</code>, so x0 is read constantly. And <code>zero</code> is the most common register in the printed text &mdash; 185 appearances, ahead of every temporaries and every callee-saved register, because a comparison against zero is the commonest operation there is.</li>
                    <li><strong><code>gp</code> and <code>tp</code> are zero everywhere.</strong> The ABI calls them <strong>UNALLOCATABLE</strong>, which is a stronger word than &ldquo;preserved&rdquo; and appears nowhere else in the table: they are not yours to use <em>even when nothing else is available</em>. <strong>A rule that no compiler breaks and a rule that does not exist are indistinguishable except to a count</strong>, and the count is 0 across the whole corpus at every level, agreed by both readers.</li>
                    <li><strong><code>s10</code> and <code>s11</code> are zero too</strong>, and for an ordinary reason: the corpus&rsquo;s functions are not deep enough to need twelve callee-saved registers. A register the ABI preserves that no compiler ever uses is still a real row of the table, and its zero is about the corpus rather than about the architecture.</li>
                    <li><strong><code>sp</code> is the most-read register in the architecture</strong> at 623 &mdash; ahead of <code>a0</code> at 1169? No: <code>a0</code> leads, and that is right, because every store in <code>abi.c</code> is <code>fsd fa0, off(a0)</code>. What makes <code>sp</code> interesting is the opposite column: it is read 623 times and written only 126, and at <code>-O1</code> and above the compressed stack forms have <strong>no base-register field at all</strong> &mdash; it is not five bits of encoding spent on <code>11111</code>, it is the <em>format</em>.</li>
                </ul>
                <h3>THE TWO NAMES FOR x8</h3>
                <p>The ABI calls it <code>s0</code> and the frame-pointer convention calls it <code>fp</code>, and <strong>THE TWO NAMES FOR x8 ARE THE SAME REGISTER</strong>. The decoder prints <code>s0</code>; the second reader prints <code>s0</code>; <code>fp</code> is the assembler&rsquo;s alias and appears in the text only when you ask for it. <a href="/courses/rvabi/lessons/rv-calling">Concept 1</a> quoted the rule: &ldquo;the register remains callee-saved&rdquo;, which is the sentence that lets a compiler use <code>s0</code> as an ordinary register.</p>
                <p>That is much milder than the AArch64 trap where register number 31 is <code>sp</code> in one instruction slot and <code>xzr</code> in another, and the reason it is milder is worth stating precisely: <strong>on RISC-V the number determines the name, always; on AArch64 the SLOT determines it.</strong> RISC-V has one name per number and the difficulty is entirely in knowing which <em>file</em> a number is in &mdash; which is the next trap.</p>
                <h3>The frame pointer, OPTIONAL and measured at four levels</h3>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/AND THE FRAME POINTER/,+6p'
  level       instructions  s0 written  s0 read
  regs.c -O0  270           12          124
  regs.c -O1  127           0           0
  regs.c -O2  127           0           0
  regs.c -Os  127           0           0
                </pre>
                </div>
                <p><strong>At <code>-O0</code> clang writes <code>s0</code> twelve times and reads it 124 times; at every level above that it touches it zero times.</strong> And that is not the compiler declining to use a frame pointer &mdash; it is the compiler discovering that the corpus has no function deep enough to need one. <strong>A reader who took the <code>-O0</code> row as &ldquo;RISC-V uses <code>s0</code> as a frame pointer&rdquo; has taken a compiler&rsquo;s choice as a property of the contract</strong>, and <a href="/courses/x86abi/lessons/x86-frame">x86-frame</a> is the lesson about what that mistake looks like when the choice goes the other way.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Two files, one spelling, and the trap that caught this file</h2>
                <p>The floating-point table is a <strong>SECOND FILE with the same roles</strong>, and it is counted separately: 32 rows, <code>ft0</code>&ndash;<code>ft11</code> temporary, <code>fs0</code>&ndash;<code>fs11</code> callee-saved, <code>fa0</code>&ndash;<code>fa7</code> argument. So <code>fa5</code> and <code>a5</code> are different registers that share a spelling up to one character, and the only reason they are not confused by eye is that the printed name has the <code>f</code> in it.</p>
                <p>The eye is not the problem. <strong>A decoder is the problem</strong>, and here is the sentence that has to be carried out of this page:</p>
                <div class="hex-dump">
                <pre>    A REGISTER NUMBER IS NOT A REGISTER UNTIL YOU KNOW WHICH
    FILE IT IS IN, and the encoding does not say.
                </pre>
                </div>
                <p>MEASURED from the corpus: <code>fsd fa0, -24(s0)</code> has <code>rs2</code> = bits[24:20] = <strong>10</strong> and <code>rs1</code> = bits[19:15] = <strong>8</strong>. Same five bits, same two values, and <strong>two different registers</strong>: 10 in the integer file is <code>a0</code> and in the floating-point file is <code>fa0</code>; 8 in the integer file is <code>s0</code> and in the floating-point file is <code>fs0</code>. The store moved a value out of <code>fa0</code> and addressed memory through <code>s0</code>. <strong>A reader that picks the wrong file reports a store of <code>a0</code> to an offset from <code>s0</code> &mdash; two real registers, one of the wrong kind, and a function whose every register name is plausible.</strong></p>
                <p><strong>And this file got it wrong first, which is the only reason that sentence is stated so firmly.</strong> The census was originally built by asking &ldquo;is this instruction floating-point?&rdquo; <em>once per instruction</em> and applying the answer to every field. For <code>fsd</code> that answers &ldquo;floating-point&rdquo; for the <strong>base</strong> as well as the data, and the audit printed <strong>18 writes to <code>gp</code> and 8 to <code>tp</code></strong> over a corpus in which the compiler writes neither. The arithmetic of a wrong lookup turns one register into another: a real <code>a2</code>, read as a base in the wrong file, comes out as <code>fs2</code>, and <code>fs2</code> read as an integer is <code>x18</code>, which is <code>s2</code>.</p>
                <p>Nothing about that table looked wrong. <strong>Only the audit turned 201 disagreements into 0</strong>, and only the audit could have: it compares this file&rsquo;s reading against a different piece of code&rsquo;s rendering of the same word, instruction by instruction. That is the argument for the audit existing at all, and it is the same argument as <a href="/courses/rvasm/lessons/rv-verify">rv-verify&rsquo;s cross-check</a> and this course&rsquo;s own two-reader comparison &mdash; <strong>a decoder is not checked by whether it decodes.</strong></p>
                <h3><code>mv rd, x0</code> is not a <code>c.mv</code></h3>
                <p>Three spellings of a zero, asked of the <strong>assembler</strong> rather than of clang, and asked at two <code>-march</code> settings:</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/THREE SPELLINGS/,+9p'
  source  exactly               rv64gc  the second reader says   rv64i
  mv      mv      t0, zero      2 bytes  li  t0, 0x0              4 bytes
  addi    addi    t0, zero, 0   2 bytes  li  t0, 0x0              4 bytes
  li      li      t0, 0         2 bytes  li  t0, 0x0              4 bytes
  add     add     zero, t0, t1  4 bytes  add  zero, t0, t1        4 bytes
  li      li      zero, 42      4 bytes  li  zero, 0x2a          4 bytes
  mv      mv      zero, t0      4 bytes  mv  zero, t0            4 bytes
  nop     nop                   2 bytes  nop                     4 bytes
                </pre>
                </div>
                <p><strong>And here is the finding the concept is named for.</strong> Ask for <code>mv t0, zero</code> and the answer is that it does NOT become a <code>c.mv</code>: <strong>it becomes <code>c.li t0, 0</code></strong> &mdash; the compressed load-immediate with a zero immediate &mdash; which is the same encoding as <code>addi t0, zero, 0</code> and as <code>li t0, 0</code>. All three are <strong>2 bytes</strong> at <code>-march=rv64gc</code> and <strong>4 bytes</strong> at <code>-march=rv64i</code>.</p>
                <p>Which is the point. <strong>There is no <code>c.mv</code> with a zero source.</strong> In the compressed specification <code>c.mv</code> is defined only when <code>rs2</code> is not x0, and the cell with <code>rs2 = x0</code> is <code>c.li</code>. So a course that asked &ldquo;does the compiler use <code>mv rd, x0</code> or <code>addi rd, x0, 0</code> for a zero&rdquo; is asking about a distinction the assembler <strong>already removed</strong> &mdash; it canonicalises all three spellings into one instruction before the encoder ever sees them.</p>
                <p>And what the compiler actually picks, counted by the immediate read from the bits rather than by the mnemonic:</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/AND WHAT THE COMPILER PICKS/,+6p'
    c.li rd, 0                   3     c.li         a2, 0
    addi rd, x0, 0               15    addi       a2, zero, 0
    lui rd, 0                    0
    mv rd, x0                    0
    (instructions with an immediate read) 260
                </pre>
                </div>
                <p>The compiler emits the <strong>two-byte</strong> form 3 times and the <strong>four-byte</strong> form 15 times in the same corpus at the same optimisation level, and never <code>mv rd, x0</code> at all &mdash; for the encoding reason above, not for taste. An instruction count cannot tell those two apart: both are one instruction. <strong>A byte count can: 2 against 4.</strong></p>
                <p>And read the denominator while you are there. 260 instructions carry an immediate this file knows how to read, and 18 of them have a zero immediate. <strong>The first version of that table printed all four counts as ZERO</strong>, because it asked the decoder for a field the decoder writes under a different name. A count of zero out of 260 is a measurement; a count of zero out of <em>zero</em> is a bug wearing the costume of a result, and <strong>the denominator sitting next to the numerator is the only thing on the page that tells them apart.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Reproduce the file bug, then fix it and watch the audit.</strong> <em>(In <code>rvabi.py</code>, find <code>_name_of</code> and delete the line that says the base of a floating-point load is an integer register. Re-run and look at section 7. Expect the register census to report writes to <code>gp</code> and <code>tp</code> over a corpus that contains none, and expect the audit printed immediately above the table to report a large disagreement count. Nothing crashes; every name is a real register. <strong>This is the exercise the whole concept is built for.</strong>)</em></li>
                    <li><strong>Prove that <code>li zero, 42</code> is a real instruction with a real effect that is not an effect.</strong> <em>(Assemble it, read the four bytes, and see that the immediate 42 is in the word. Then ask what the hardware does with them: nothing, and <strong>this course cannot measure that</strong> because there is no RISC-V silicon on this host. So the honest statement is two-part and both halves are on the limits list: the encoding is MEASURED, the discard is not.)</em></li>
                    <li><strong>Find the register the corpus never uses, and then make it use one.</strong> <em>(<code>s10</code> and <code>s11</code> are zero because nothing in four files of ordinary C is deep enough to need twelve callee-saved registers. Write a function that is, count the callee-saved register it spills, and compare against the same function compiled for x86-64. The difference is the section&rsquo;s spine made arithmetic: RISC-V saves fewer registers per callee because <strong>there is no flags register to save</strong>, and that is a number you can put in a table.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/rvasm/lessons/rv-encoding">rv-encoding</a> is where the compressed <code>rd'</code> is measured &mdash; three bits at bits[9:7], value 0 meaning x8 &mdash; and the 131 phantom writes to <code>x0</code> on this page are that finding used against itself. <a href="/courses/rvabi/lessons/rv-noflags">Concept 2</a> is where the absent register shows up: <strong>a register list with no entry for &ldquo;the condition&rdquo; is a register list that says something</strong>, and this page is the count.</p>
                <p>Across architectures, <a href="/courses/a64abi/lessons/a64-registers">a64-registers</a> is the same trap with a worse mechanism, and the comparison is the point. AArch64 has register number 31 mean <code>sp</code> in one instruction slot and <code>xzr</code> in another, and it has the integer and floating-point files to get wrong as well. <strong>RISC-V has one name per number and two files; AArch64 has two names per number in some slots and two files. The RISC-V version is easier to read and the AArch64 version is easier to decode wrongly</strong> &mdash; which is not the same thing, and the reason to learn both.</p>
                <p>And <a href="/courses/x86abi/lessons/x86-saved">x86-saved</a> is where the comparison in the &ldquo;try it&rdquo; above comes from: the x86-64 callee has a flags register to preserve and RISC-V&rsquo;s does not, so the same C produces a different number of saved registers on the two, and the difference is a <em>design consequence</em> rather than an implementation detail.</p>
                <p>Forwards, <a href="/courses/rvabi/lessons/rv-compressed-cost">concept 4</a> takes the register file&rsquo;s constraints and asks what compression does to them &mdash; because the compressed forms can only name x8 to x15, and that is a constraint the register allocator has to respect, which is why a &ldquo;pure encoding&rdquo; change can move an <em>instruction count</em>.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/rvabi/lessons/rv-noflags">No Flags Register, No Condition Codes, No CMOV</a></span>
                <span>Next: <a href="/courses/rvabi/lessons/rv-compressed-cost">What Compression Does to the ABI and to Disassembly</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
