// The RISC-V ABI -- Concept 1: the calling convention, with the
// specification as the oracle and the compiler as the test subject.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rv_calling() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Calling Convention — Underlayer")
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
            <h1>The Calling Convention</h1>
            <div class="lesson-meta">26 min &middot; <a href="/courses/rvabi">The RISC-V ABI, and the Register That Isn&rsquo;t There</a></div>

            <div class="unit unit-why">
                <h2>Why a calling convention is the right first thing to measure</h2>
                <p>A calling convention is not an encoding. It is a <strong>contract between two compilers</strong> that neither of them can see, and the property that makes it measurable is unusual: <strong>you can quote it exactly</strong>, and then you can check a compiler against it. That is why this concept comes first, and why the specification here is the <em>oracle</em> and <code>clang</code> is the <em>test subject</em>. Every disagreement between them is printed as a retraction rather than explained away.</p>
                <p>The method, and it is <a href="/courses/x86abi/lessons/x86-calling">x86abi&rsquo;s</a> method for the same reason: <strong>every argument is read from its own <code>volatile</code> global</strong>, so the compiler cannot forward-fold it, cannot constant-propagate it, and cannot reorder two arguments that happen to have the same value. Without that, <code>f(a, b)</code> returning <code>a - b</code> compiles to nothing at <code>-O1</code> and the measurement is about the compiler rather than about the ABI.</p>
                <p>And the second half of the method is what makes the numbers <strong>MEASURED-ON-BYTES</strong> rather than MEASURED-from-text. A store into a global looks like this:</p>
                <div class="hex-dump">
                <pre>$ llvm-objdump-21 --triple=riscv64 -dr abi_O2.o | sed -n '/sw.*0x0(a1)/,+2p' | head -3
      6: 00a5a023     	sw	a0, 0x0(a1)
		0000000000000006:  R_RISCV_PCREL_LO12_S	.Lpcrel_hi0
		0000000000000006:  R_RISCV_RELAX	*ABS*
                </pre>
                </div>
                <p>And the relocation does not name <code>G0</code>. <strong>It names <code>.Lpcrel_hi0</code> &mdash; a local label the compiler invented</strong> &mdash; and the real address is in a second entry that <em>that</em> label points at. <strong>Following the chain is what turns the store into &ldquo;the third integer argument arrived in a2&rdquo;</strong>, and it is the difference between a claim about the ABI and a claim about a text file. <a href="/courses/rvabi/lessons/rv-noflags">Concept 2</a> is not about a contract at all, and it is here that the difference shows: there, the compiler&rsquo;s choice <em>is</em> the subject.</p>
                <p>This is PIC medlow addressing, and it is not an accident of this corpus &mdash; it is what a position-independent store into a global <em>is</em>. One more thing about the corpus is worth knowing before the numbers, though, because it is a deliberate choice: every global is in its <strong>own section</strong>, because clang&rsquo;s default is to <strong>merge</strong> adjacent globals of the same type into <code>.L_MergedGlobals</code>, which would add a <em>third</em> hop &mdash; store to local label, local label to <code>auipc</code>, <code>auipc</code> to the merged object, merged object to the pointer-table slot, slot to the <code>G8</code> entry. <strong>A four-hop chain in the middle of a measurement is four chances to be wrong for a reason that has nothing to do with the calling convention</strong>, so the corpus removes the hops it does not need and the audit counts the ones it does.</p>
            </div>

            <div class="unit unit-model">
                <h2>The contract, quoted before any compiler runs</h2>
                <p>Everything in this unit is <strong>QUOTED</strong>, because nothing in it needs to be measured: it is the document, and the document is the oracle. Sections 3 and 4 of the artifact test the compiler against it.</p>
                <div class="hex-dump">
                <pre>  riscv-cc, "Register Convention / Integer Register Convention"

  Name      ABI Mnemonic  Meaning                Preserved across calls?
  x0        zero          Zero                   -- (Immutable)
  x1        ra            Return address         No
  x2        sp            Stack pointer          Yes
  x3        gp            Global pointer         -- (Unallocatable)
  x4        tp            Thread pointer         -- (Unallocatable)
  x5 - x7   t0 - t2       Temporary registers    No
  x8 - x9   s0 - s1       Callee-saved registers Yes
  x10 - x17 a0 - a7       Argument registers     No
  x18 - x27 s2 - s11      Callee-saved registers Yes
  x28 - x31 t3 - t6       Temporary registers    No
                </pre>
                </div>
                <p>Read the fourth column twice. <strong>x0 is not merely preserved; it is IMMUTABLE</strong>, which is a stronger word and the only one in that column that is not Yes or No. <strong>x3 and x4 are UNALLOCATABLE</strong>, which is stronger still and means something no other register in the table means: they are not yours to use <em>even when nothing else is available</em>. <a href="/courses/rvabi/lessons/rv-registers">Concept 3</a> measures all three.</p>
                <p>And <code>ra</code> and <code>sp</code> are both privileged: <code>ra</code> is <strong>No</strong> because nobody preserves a return address, and that single fact is why the first stacked argument is at offset <strong>zero</strong> rather than eight. On x86-64 the <code>call</code> instruction <em>pushes</em> the return address, so the callee must skip it. On RISC-V the return address lives in a register, so there is nothing on the stack to skip &mdash; and every stacked offset in this course is 8 lower than the x86-64 equivalent. One sentence, and it replaces a diagram.</p>
                <p>The floating-point table is a <strong>SECOND FILE with the same roles</strong>, and the collision is the sharpest thing in this course&rsquo;s naming: <code>riscv-cc</code> gives <em>both</em> f10-f17 and x10-x17 the range name a0-a7, with a leading <code>f</code> to tell them apart.</p>
                <div class="hex-dump">
                <pre>  f0 - f7   ft0 - ft7    Temporary registers    No
  f8 - f9   fs0 - fs1    Callee-saved registers Yes*
  f10 - f17 fa0 - fa7    Argument registers     No
  f18 - f27 fs2 - fs11   Callee-saved registers Yes*
  f28 - f31 ft8 - ft11   Temporary registers    No

  * only preserved across calls if no larger than the width of a
    floating-point register in the targeted ABI
                </pre>
                </div>
                <p>So <code>fa5</code> and <code>a5</code> are <strong>two different registers in two different files</strong>, and the only reason they are not confused is that the printed name has the <code>f</code> in it. That is a decoder problem as much as a reader problem, and <a href="/courses/rvabi/lessons/rv-registers">concept 3</a> has the sharpest available example of getting it wrong.</p>
                <p>The stack rules, and the no-red-zone one is quoted as an <strong>OBLIGATION</strong> rather than a region:</p>
                <div class="hex-dump">
                <pre>  * "The stack grows downwards (towards lower addresses) and the
     stack pointer shall be aligned to a 128-bit boundary upon procedure
     entry."
  * "The first argument passed on the stack is located at OFFSET ZERO of
     the stack pointer on function entry; following arguments are stored
     at correspondingly higher addresses."
  * "Procedures must not rely upon the persistence of stack-allocated
     data whose addresses lie below the stack pointer."
  * "Registers s0-s11 shall be preserved across procedure calls."
  * "The presence of a frame pointer is optional.  If a frame pointer
     exists, it must reside in x8 (s0); the register remains
     callee-saved."
                </pre>
                </div>
                <p>Read the third quote carefully, because the wording is doing work. <strong>x86-64 defines a 128-byte red zone and then forbids an interrupt from clobbering it. RISC-V states an obligation on the procedure and defines no region at all.</strong> There is nothing to count, which is a different thing from there being nothing there, and the only measurable consequence is what the compiler does instead: every spilled argument costs an explicit frame.</p>
                <p>And the last quote is the one with four levels of conformance available to the platform, including &ldquo;not to maintain a frame chain and use the frame pointer register as a general purpose callee-saved register&rdquo;. <strong><code>s0</code> is callee-saved regardless of whether it is a frame pointer</strong> &mdash; which is the sentence that lets a compiler use <code>s0</code> as an ordinary register, and which <a href="/courses/rvabi/lessons/rv-registers">concept 3</a> measures at four optimisation levels.</p>
            </div>

            <div class="unit unit-example">
                <h2>The audit: 44 of 44, read out of relocations</h2>
                <p>For each of <code>i1</code>&hellip;<code>i9</code>, find the store whose relocation names <code>G&lt;K&gt;</code> and read the <code>rs2</code> field of the instruction word. That register is where the K-th integer argument arrived.</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/INTEGER ARGUMENTS, -O2/,+6p'
  function  global  riscv-cc says  the bytes say  verdict
  i1        G0      a0            a0            agree
  i1        --      a0            1 in registers agree
  i2        G0      a0            a0            agree
  i2        G1      a1            a1            agree
  i2        --      a1            2 in registers agree
  ...
  i9        G7      a7            a7            agree
  i9        --      none: there is no a8   8 in registers   agree

  44 of 44 integer argument placements agree with riscv-cc's table, at -O2.
                </pre>
                </div>
                <p><strong>Forty-four of forty-four</strong>, and the denominator is arithmetic rather than a convenience: <code>i1</code>&hellip;<code>i8</code> contribute 1+2+&hellip;+8 = <strong>36</strong> register-resident arguments and <code>i9</code> contributes 8 more. The ninth of each function is not in the table because <strong>there is no register for it</strong>.</p>
                <p>That is the specification&rsquo;s half. Now the compiler&rsquo;s, and it is a different number with a different owner: <strong>the spill count is the compiler&rsquo;s, and it moves with the optimisation level.</strong></p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/in a reg/,+6p'
  level  in a reg  on the stack  specification
  -O0    0         36            a0-a7 per riscv-cc
  -O1    36        0             a0-a7 per riscv-cc
  -O2    36        0             a0-a7 per riscv-cc
  -Os    36        0             a0-a7 per riscv-cc
                </pre>
                </div>
                <p>At <code>-O0</code> clang spills <strong>every</strong> argument and at every other level it keeps all thirty-six in registers. <strong>No row is marked DISAGREE at any level</strong> &mdash; because a spilled argument is still <em>passed according to the convention</em>, it just took the &ldquo;or on the stack by value if none is available&rdquo; branch. This is the sharpest available lesson in separating a contract from an implementation: <strong>a number that moves with <code>-O</code> is the compiler&rsquo;s, and a number that does not is the ABI&rsquo;s.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>The ninth argument, and the one row no summary gets right</h2>
                <p>Two hypotheses about what happens when the argument registers run out. Either there is <strong>ONE counter</strong> that runs out after eight values of any kind, so the ninth value of anything is on the stack; or there are <strong>TWO INDEPENDENT counters</strong>, one over a0-a7 and one over fa0-fa7, so the ninth value is on the stack only if both are exhausted.</p>
                <p>Here is the ninth <em>integer</em> argument, at four levels:</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/loads from sp/,+6p'
  level  loads from sp <= 8  offset(instruction) via sp  via s0
  -O0    0                   (none)                      0(c.ld)
  -O1    1                   0(c.ldsp)                   (none)
  -O2    1                   0(c.ldsp)                   (none)
  -Os    1                   0(c.ldsp)                   (none)
                </pre>
                </div>
                <p><strong>Offset zero, at every level</strong>, and the <code>-O0</code> row is a better finding than the row it replaced. At <code>-O0</code> clang emits <code>addi s0, sp, N</code> in the prologue and reads the ninth argument from <code>0(s0)</code> &mdash; through the <strong>frame pointer</strong>, not through <code>sp</code>. And <code>s0</code> <em>is</em> the CFA: the stack pointer as it was on entry, which is exactly what the frame-pointer convention defines it to be. So the <code>-O0</code> offset is <strong>also zero, read through a different register</strong>. The first version of this section reported <code>(none)</code> at <code>-O0</code> because the audit only looked at the base register <code>sp</code>, and because the <code>-O0</code> load is a <em>compressed</em> <code>c.ld</code> whose base is a three-bit <code>rs1'</code> field rather than the five-bit one.</p>
                <p><strong>A row that is empty at one optimisation level and full at every other one is almost always a base-register assumption and not a measurement.</strong> That is the third time this collection has learned that in a row that looked empty rather than wrong.</p>
                <p>And the stack alignment is an <strong>ARITHMETIC IDENTITY</strong> and not a measurement of anything: <code>-O0</code>&rsquo;s prologue is <code>addi sp, sp, -0x40</code> and its epilogue is <code>addi sp, sp, 0x40</code>, so the sum is 0 mod 128 at the return. What the alignment <em>forces</em> &mdash; a fault on a misaligned access &mdash; <strong>cannot be measured here and is not claimed</strong>, and the artifact says so in the limits section where a reader would otherwise expect the number.</p>
                <h3>The ninth DOUBLE, which is not on the stack at all</h3>
                <p>This is the row. <code>f9</code> takes nine doubles and nothing else:</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/f9, ninth double/,+2p'
  case              after fa7        ninth double arrived in   stack loads
  f9, ninth double  fa7 (exhausted)  a0 -- an INTEGER register  0 stack reads
                </pre>
                </div>
                <p><strong>The ninth double arrives in <code>a0</code> &mdash; an integer register &mdash; and <code>f9</code> reads no stack argument at any optimisation level.</strong> The reason is the second sentence of the hardware floating-point convention, which has to be read with the third:</p>
                <div class="hex-dump">
                <pre>  * fa0-fa7 are exhausted after eight doubles.
  * "A real floating-point argument is passed in a floating-point
     argument register if it is no more than ABI_FLEN bits wide AND
     AT LEAST ONE FLOATING-POINT ARGUMENT REGISTER IS AVAILABLE.
     OTHERWISE, IT IS PASSED ACCORDING TO THE INTEGER CALLING
     CONVENTION."
  * the integer calling convention is a0-a7 first, and those are
    still free.
                </pre>
                </div>
                <p>So the ninth double goes to <code>a0</code>. <strong>It does NOT go on the stack, because nothing has exhausted the integer argument registers yet.</strong> A summary that says &ldquo;the ninth argument is on the stack&rdquo; is <em>right for integers and wrong for doubles</em>, and the only way to know which is which is to read the second convention and then measure it.</p>
                <p>The <strong>two counters</strong> are then settled by <code>m18</code> &mdash; nine integers <em>then</em> nine doubles &mdash; which is the case that separates the hypotheses, and which is in the corpus for exactly that reason:</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/ONE TOKEN PER COLUMN/,+3p'
  m8   4 int + 4 double   1&lt;-a0,...,4&lt;-a3  1&lt;-fa0,...,4&lt;-fa3  (none)
  m18  9 int + 9 double   1&lt;-a0,...,8&lt;-a7,9&lt;-t0
                            1&lt;-fa0,...,8&lt;-fa7,9&lt;-ft0          0, 8
                </pre>
                </div>
                <p><code>m8</code> agrees with <strong>both</strong> hypotheses and the artifact prints that it settles nothing, because a distinguishing case that is not printed looks like a case that was not considered. <code>m18</code> decides it: the ninth integer goes into <code>t0</code> and the ninth double into <code>ft0</code>, and it reads <strong>exactly two stack offsets, 0 and 8</strong>. Two independent counters, confirmed &mdash; the ninth double is on the stack because <em>the integers took a0-a7</em>, and it is at 8 rather than 0 because <em>the ninth integer took 0</em>.</p>
                <p>And both ninth values went through a <strong>temporary</strong>, which is worth naming because it is the only reason a reader can see the stack in that row at all. The store to <code>G8</code> has <code>rs2 = t0</code> and the store to <code>D8</code> has <code>rs2 = ft0</code>, and neither is an argument register &mdash; so the audit cannot conclude &ldquo;the ninth argument arrived in <code>t0</code>&rdquo; and stop. It has to find the <code>c.ldsp</code> that <em>filled</em> <code>t0</code>, and that load is the evidence. <strong>A register-based audit with no load audit reports a temporary and a reader has no way to know whether it was filled from the stack, from a global, or from nowhere.</strong></p>
                <p>And the caller agrees, which is the part a callee-only audit cannot do. A callee audit shows only that the callee <em>read</em> something; the caller shows where it <em>wrote</em>, and neither would catch a mistake in the other:</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/the caller, -O2/,+12p'
  call 1  stack offsets written: [0, 24, 32, 40, 48, 56, 64]
        c.li         a7, 8
        c.sdsp       s1, 0(sp)      &lt;- the ninth INTEGER at offset 0
        auipc      ra, 0x0
        jalr       ra, 0(ra)
  call 2  stack offsets written: NONE
        fsgnj.d    fa7, fs7, fs7
        c.mv         a0, s0         &lt;- the ninth DOUBLE goes into a0
        auipc      ra, 0x0
        jalr       ra, 0(ra)
  call 3  stack offsets written: [0, 8]
        fsgnj.d    fa6, fs6, fs6
        fsgnj.d    fa7, fs7, fs7
        auipc      ra, 0x0
        jalr       ra, 0(ra)
                </pre>
                </div>
                <p>Three calls, one function, and the offsets are <strong>the specification&rsquo;s</strong> rather than the compiler&rsquo;s, which is why the artifact prints them at one level deliberately: the register names inside the tail do move with the compiler, and printing four levels of them would be four copies of a compiler&rsquo;s choices wearing the weight of a contract.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Make the ninth-double row come out the way a summary says, and see what it takes.</strong> <em>(Remove the <code>fa0-fa7</code> fallback from your mental model and write <code>double d = 1.0; f9(1,2,3,4,5,6,7,8,d);</code>, then read the caller&rsquo;s disassembly with <code>llvm-objdump-21 -d</code>. Expect the ninth double in <code>a0</code>. Now add eight integer arguments in front of it so a0-a7 <em>are</em> exhausted, and expect the double to move to the stack at offset 8. Two experiments, one specification, and the rule &ldquo;falls back to the integer calling convention&rdquo; is the whole of the difference.)</em></li>
                    <li><strong>Break the relocation chain on purpose and watch the audit report a plausible zero.</strong> <em>(In <code>rvabi.py</code>, make <code>stores_to_globals</code> return an empty dict. Re-run and count: the audit will report <code>0 of 44</code> with every row reading <code>(not found)</code>, and nothing anywhere will say &ldquo;the audit was disabled.&rdquo; A silently dropped measurement is a measurement that cannot disagree, which is the exact shape of the bug this collection has paid for twice. Then read what the artifact does about it &mdash; the drops are COUNTED, not skipped.)</em></li>
                    <li><strong>Add a tenth integer argument and check whether the offset moves.</strong> <em>(It must not. The first stacked argument is at offset zero of the stack pointer <em>on entry</em>, and every subsequent one is at a correspondingly higher address &mdash; so the tenth argument is at 8, and the ninth is at 0, and neither depends on how many arguments came before. Predict the offset before you compile, then check.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/exe/lessons/exe-frontend">exe-frontend</a> is what an ELF64 relocation <em>is</em> &mdash; this page reads the tables by hand and that is a choice, not a necessity, and the choice is what makes the measurement about bytes. <a href="/courses/rvasm/lessons/rv-encoding">rv-encoding</a> is where <code>c.ld</code>&rsquo;s three-bit base register is measured, and the <code>-O0</code> row above depends on it: without that finding the audit reports <code>(none)</code> for a function that plainly reads the stack.</p>
                <p>Across architectures, <a href="/courses/x86abi/lessons/x86-calling">x86-calling</a> is the same contract with two differences that are worth the comparison. x86-64 has a <strong>red zone</strong> &mdash; 128 bytes below <code>rsp</code> that a leaf function may use without adjusting <code>rsp</code> &mdash; and it has a <strong>hidden return pointer</strong> in <code>rax</code> for an aggregate larger than 16 bytes. RISC-V has neither: no red zone because the manual forbids relying on memory below <code>sp</code>, and the same hidden-pointer rule filled by <code>a0</code>.</p>
                <p>And <a href="/courses/a64abi/lessons/a64-aapcs">a64-aapcs</a> is where the two independent argument counters <em>as AArch64 states them</em> are set out, because AArch64 reaches the same conclusion &mdash; 8 integer and 8 floating-point registers, then the stack &mdash; through a different document and with a different rule for what happens when the floating-point registers run out first. <strong>Both architectures have two counters. RISC-V is the one whose specification says so out loud in the floating-point section, which is why this row is findable at all.</strong></p>
                <p>Forwards, <a href="/courses/rvabi/lessons/rv-registers">concept 3</a> counts the register file this page has only quoted, and finds that a callee here saves <em>fewer</em> registers than an x86-64 callee for the same C &mdash; because there is no flags register to save.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/rvabi">Course landing page</a></span>
                <span>Next: <a href="/courses/rvabi/lessons/rv-noflags">No Flags Register, No Condition Codes, No CMOV</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
