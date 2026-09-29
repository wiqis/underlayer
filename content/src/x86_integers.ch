// x86-64 Assembly and Encoding — Concept 2: the integer instruction set
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_integers() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Integer Set, Which Nothing Teaches — Underlayer")
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
            <h1>The Integer Set, Which Nothing Teaches</h1>
            <div class="lesson-meta">28 min &middot; <a href="/courses/x86asm">x86-64 Assembly and Encoding</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>A word-boundary scan over the concept files of all 21 shipped courses, taken the morning this one was written, found <code>SUB</code> and <code>CMP</code> and <code>MOVZX</code> and <code>LEAQ</code> and <code>SHR</code> and <code>ROL</code> and <code>SETcc</code> and <code>CMOVcc</code> in <strong>zero files</strong>. Not one. And those are not exotic instructions: they are the arithmetic that everything else is written in terms of.</p>
                <p>What exists instead is <a href="/courses/isa/lessons/isa-opcodes">the opcode concept</a>, and it is a different thing. It teaches <strong>how to read a byte</strong> &mdash; fourteen <code>0F xx</code> opcodes taken apart one at a time, which is exactly the right way to teach a decoder and the wrong way to teach an instruction set. <a href="/courses/exe/lessons/exe-latency">The execution course's latency concept</a> teaches <strong>that a dependency is a dependency</strong> and that the chain costs you. Neither of them is the set, and this concept is the set.</p>
                <p>And the reason it matters is not completeness for its own sake. It is that <strong>the width of a register in the source decides the answer, not the speed</strong>, and there is no compiler diagnostic, no assembler diagnostic and no runtime check for getting it wrong:</p>
                <div class="hex-dump">
                <pre>  starting value                            0x0123456789abcdef
  mov ax, al            -&gt;  0x0123456789abcdef   a 16-bit write, top 48 KEPT
  mov eax, al           -&gt;  0x0000000055667788   a 32-bit write, top 32 CLEARED

  starting value                            0xffffffffffffffff
  shr $1, eax            -&gt;  0x000000007fffffff   NOT shifted.  ZEROED.
  shr $1, rax            -&gt;  0x7fffffffffffffff   what you meant
  </pre>
                </div>
                <p>Those six lines are read out of a register, not timed, and they are exact. A backend that emits the wrong one produces a program that is correct on some inputs and silently wrong on the rest, and the inputs it is wrong on are the ones where the upper half happened to be zero.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: four instructions, one control, and a group that does not chain</h2>
                <p>Eight operations per iteration in every arm, the same two loop instructions in every arm, and the operation under test changed and nothing else. Then the same four instructions with the operations made independent.</p>
                <div class="hex-dump">
                <pre>$ ./x86dec | sed -n '/2A\.  THE ALU GROUP/,/THE CAVEAT/p'
  the loop shell, the operation REMOVED (control)         1.766 ticks/op

  add, chain of eight on rax                              6.948 ticks/op
  add, eight independent registers                        1.866 ticks/op
  sub, chain of eight on rax                              7.886 ticks/op
  sub, eight independent registers                        1.964 ticks/op
  cmp, EIGHT WRITES TO THE FLAGS REGISTER                2.711 ticks/op
  cmp, eight independent registers                        2.712 ticks/op
  test, EIGHT WRITES TO THE FLAGS REGISTER               1.595 ticks/op
  test, eight independent registers                       1.586 ticks/op

         add      3.72x
         sub      4.02x
         cmp      1.00x
         test     1.01x
  </pre>
                </div>
                <p>The top half of that table is the story everybody tells and it is right. <strong>ADD chains at 3.72&times; and SUB at 4.02&times;</strong> &mdash; a data dependency is a dependency, the second operation cannot start until the first has written its result, and eight of them in a row is eight latencies.</p>
                <p>The bottom half is the finding, and it is the reason this concept exists. <strong>CMP chains at 1.00&times; and TEST at 1.01&times;: they do not chain at all.</strong> Eight flag-writers in a row cost the same as eight flag-writers on eight registers &mdash; and there is exactly one flags register, it is 32 bits wide of which six are arithmetic, and every one of those eight operations is architecturally required to write it.</p>
                <div class="formula">
   ADD and SUB chain on a DATA dependency:  the second
   instruction's SOURCE REGISTER is the first one's
   DESTINATION.  That is visible in the instruction.

   CMP and TEST chain on the FLAGS REGISTER, which is a
   different thing entirely: no data flows between them,
   they share a REGISTER, and the architecture does not
   say that sharing a register creates a dependency.

   The draft of this course said it did, because the
   manual says they all write the same register.  Those
   are two different sentences and the measurement
   separates them.
                </div>
                <p><strong>The mechanism, marked separately from the measurement, because a course that blurs them is the disease this one is about:</strong> the flags are <em>renamed</em>. Each flag-writer is given its own physical copy of the six flag bits and the serialisation is logical rather than physical. That is in the vendor manual. It is <strong>not</strong> observable from user mode, it is not observable on this machine at all, and the artifact says so in its limits block under the heading <code>WHETHER THIS PROCESSOR RENAMES THE FLAGS REGISTER</code>. The numbers are the measurement. The mechanism is a citation. Neither is standing in for the other.</p>
                <h3>And a control that cannot be subtracted</h3>
                <p>The eight-nop row is in that table and it is the first thing a reader should be suspicious of, because <code>test independent</code> at 1.586 is <em>below</em> the nop control at 1.766. A cost that comes out negative is not a small cost. It is a control that cannot be subtracted.</p>
                <div class="formula">
   Eight NOPS and eight SUBS are both ten instructions
   and they are NOT the same ten.  A nop takes an issue
   slot and retires without producing a value.  The row is
   kept because it shows the loop is the SHAPE this table
   thinks it is, and it is labelled as a shape control and
   NOT a cost control, and no cost in this course is a
   difference against it.

   The artifact CHECKS that rather than asserting it: it
   compares each row against the nop row and prints which
   ones came in below it, and on the recorded run one did.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: LEA, the two shift counts, and the three widths of MOV</h2>
                <h3>LEA: one instruction, three inputs, and no multiplier</h3>
                <p>The first concept showed you that <code>lea 0(%rdi,%rsi,4), %rax</code> is five bytes and touches no memory. The obvious next question is whether it is <em>fast</em>, and the obvious answer is that one instruction must beat three.</p>
                <div class="hex-dump">
                <pre>$ ./x86dec | sed -n '/THE RATIO, SEVEN TIMES/,/spread\./p'
      THE RATIO, SEVEN TIMES, ALTERNATING, one LEA over three ALU ops.
      A single pair of rows is a SAMPLE; this is a distribution.
      Three runs of this course produced single-pair ratios of
      2.00x, 0.55x and 2.77x for the SAME two arms on the SAME machine,
      which is not a measurement of an instruction, it is a
      measurement of what else the machine was doing:

        minimum 0.553x    mean 1.088x    maximum 1.823x
        the seven agree to within 229.7%
  </pre>
                </div>
                <p><strong>A mean of 1.09&times; with a spread of 230 %.</strong> There is no 3&times; win here in either direction, and the honest second half is the half that is easy to get wrong: <strong>a mean of 1.00&times; would not be evidence that the two forms are equal either.</strong> A mean is not a measurement of equality when the spread around it is that wide. The interesting number in the whole section is the spread.</p>
                <p>What <em>is</em> stable is the shape of LEA's own cost, and it is not flat &mdash; four shapes of the same instruction, one operation each, identical loop shells:</p>
                <div class="hex-dump">
                <pre>  lea (rdi), rax          -- a base and nothing else      1.205 ticks/op
  lea (rdi,rsi), rax      -- a base and an index          1.205 ticks/op
  lea 8(rdi,rsi), rax     -- and a displacement           0.665 ticks/op
  lea 0(rdi,rsi,4), rax   -- and a scale                  0.755 ticks/op
  </pre>
                </div>
                <p>And that sweep does not hold its order between runs either, which the artifact says rather than hides. The claim that survives is the negative one: <strong>the address-generation unit has a cost and the instruction count does not.</strong> Three cheap ALU operations issue alongside each other and alongside the loop; one address computation does not. The mechanism is marked INFERRED, because there is no counter on this machine that can count AGU occupancy and the vendor manual has no number for it either.</p>
                <div class="hex-dump">
                <pre>$ ./x86dec | sed -n '/2C\.  THE TWO SHIFT/,/2D\./p'
  shl $1, rax  -- the count is IN the instruction    1.205 ticks/op
  shl cl, rax  -- the count comes from cl          0.672 ticks/op
  shl cl, rax with cl=63   -- NOT CLEARED, see below  0.878 ticks/op

        shl %cl with cl = 0    ->  0x0123456789abcdef   (unchanged)
        shl %cl with cl = 1    ->  0x02468acf13579bde
        shl %cl with cl = 63   ->  0x8000000000000000   (everything shifted out)
        shl %cl with cl = 64   ->  0x0123456789abcdef   (SAME as 0: masked)
  </pre>
                </div>
                <p><strong><code>cl = 64</code> is a shift of zero.</strong> The count is masked to six bits for a 64-bit operand, so a caller who leaves 64 in <code>%cl</code> gets back an unchanged value, with no fault and no indication that anything went wrong. That is a property of the ISA and not of this processor, and it is why the variable form is not simply the faster form however the timing comes out.</p>
                <p>And the third row is <strong>the bug, not a result</strong>. It shifts a zero sixty-three times. On three runs of this artifact that row came out cheaper than, dearer than, and equal to a real shift &mdash; and a timing table cannot tell you which, because a fast instruction and a deleted one look identical in a number. Only the bit patterns settle it, and that is why they are printed beside the timing rather than after it.</p>
                <h3>MOVZX, MOVSX, and the width in the name</h3>
                <div class="hex-dump">
                <pre>  movzx eax, al             -- explicit zero extension    1.206 ticks/op
  mov eax, eax              -- the 32-bit operation       1.206 ticks/op
  movsx eax, al             -- explicit sign extension    0.766 ticks/op

  rax = 0x1122334455667788, al = 0x88, and then:
     nothing at all       -&gt;  0x1122334455667788
     mov ax, al           -&gt;  0x1122334455667788   (a 16-bit write, upper bits KEPT)
     mov eax, al          -&gt;  0x0000000055667788   (a 32-bit write, upper bits CLEARED)
  and the two extensions of the byte 0x88:
     movzx eax, al        -&gt;  0x0000000000000088
     movsx eax, al        -&gt;  0x00000000ffffff88
     movsxd rax, eax      -&gt;  0x0000000000000088   (the 64-bit form of the same thing)
  </pre>
                </div>
                <p>The costs are unremarkable and the <strong>correctness is the whole story</strong>. <code>movzx 0x88</code> is 136; <code>movsx 0x88</code> is 4294967176, because 0x88 has its top bit set and a sign extension is a different number. Get the one you want wrong and every comparison downstream is a comparison of the wrong numbers, and it will be right for every input whose eighth bit is clear.</p>
                <p>And the second trap is the one that costs a day. <code>mov ax, al</code> leaves the top 48 bits <strong>exactly as they were</strong>, so a compiler that meant to move a byte and emitted the 16-bit form produces a value that is correct in its low half and <em>carries the previous contents of the register in its high half</em>. No assembler warns. No compiler warns. A &ldquo;mov&rdquo; with a size suffix is a request for a specific width and the hardware gives you exactly that width and nothing more.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the flag table, and the two rows worth stopping on</h2>
                <p>Every number above is what the machine charges. This is what the architecture says, and it is a table of flags rather than of cycles &mdash; six arithmetic flags, CF PF AF ZF SF OF, and for each instruction group, which of them it <em>writes</em>.</p>
                <div class="formula">
   instruction group                  CF PF AF ZF SF OF   the trap
   ---------------------------------   -- -- -- -- -- --  --------------
   add, adc, sub, sbb, cmp, neg      y  y  y  y  y  y   OF says signed
                                                            overflow
   inc, dec                           -  -  -  y  y  -   CF is NOT written
   and, or, xor, test                 -  - -  y  y  -   AND clears CF and OF
   shl, sal, shr, sar                 y  - -  y  y  y   OF only for a count
   shl, shr with a count of 1         y  - -  y  y  y   OF MEANS OVERFLOW
   shl, shr with a count &gt; 1          y  - -  y  y  -   and is UNDEFINED
   rol, ror                           -  - -  -  -  y   ONLY OF is written
   rcl, rcr                           y  - -  -  -  y   and CF for the rotate
   imul                               y  - -  -  y  -   the 3 forms differ
   mul                                y  - -  -  -  y   OF and SF undefined
   div, idiv                          -  - -  -  -  -   WRITES NO FLAGS AT ALL
   lea                                -  - -  -  -  -   so does an address
   mov                                -  - -  -  -  -   and every load
   setcc, cmovcc                      -  - -  -  -  -   they READ the flags
                </div>
                <p><code>inc</code> and <code>dec</code> deliberately do not write CF, and that is not an oversight: it is why x86 has separate <code>inc</code> and <code>add $1</code> at all. A counter can be incremented in a loop without destroying a carry that a multi-precision addition is in the middle of, and the opcode byte freed up is a bonus.</p>
                <p>And <code>div</code> writing no flags at all is why a divide has to be followed by a compare to be usable, and why the compiler emits one. The artifact proves both of those from the machine rather than quoting them, and the proof is a shape rather than a number:</p>
                <div class="hex-dump">
                <pre>$ ./x86dec | sed -n '/TWO DIVIDES/,/identical rows/p'
      5 + 5 = 10, so PF=1 and everything else clear:
        add  eax, 5   EFLAGS = 0x0000000000000206
      5 - 7 = -2, so CF=1 (borrow), SF=1 and AF=1 (borrow out of bit 4):
        sub  eax, 7   EFLAGS = 0x0000000000000293
      0x7ffffffe and 0x80000000 have the same low bit, so CF agrees:
        shr  eax, 1   after 0x7ffffffe   EFLAGS = 0x0000000000000216
        shr  eax, 1   after 0x80000000   EFLAGS = 0x0000000000000a16
        THAT BIT IS OF, and the rule it obeys is the one the
        table above only claimed.
      TWO DIVIDES, of different numbers, in a row:
        div  eax, 2   after mov eax, 9    EFLAGS = 0x0000000000000a12
        div  eax, 3   after mov eax, 11   EFLAGS = 0x0000000000000a12
        THE TWO ROWS ARE BYTE-IDENTICAL and the two operations
        are not.
  </pre>
                </div>
                <p><strong>Two divides of different numbers give byte-identical EFLAGS</strong>, because a divide writes none. The first version of this table compared the divide against the row <em>above</em> it, found them different, and read the difference as the divide doing something. Two identical rows are a control; one row compared with an unrelated one is not.</p>
                <p>And the two <code>shr</code> rows differ in <strong>exactly one bit</strong>, and it is bit 11. Two inputs with the same low bit, one with the top bit set and one without, shifted right by one, produce the same value and the same four other flags &mdash; and differ only in OF. That is the cheapest possible demonstration that a flag table is worth reading and that <strong>OF is the one row in it that is a trap</strong>: after a shift by one it means <em>overflow</em>, and after a shift by more than one it is undefined, so a compiler that emits <code>sar</code> by a runtime amount and then reads OF has emitted a program that is correct for one count and undefined for every other.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce the four ratios before you read anything else.</strong> <code>cd courses/x86asm/assets/samples &amp;&amp; ./build_samples.sh</code>, then read section 2A. <em>(Expect ADD and SUB above 2.5&times; and CMP and TEST near 1.0. If CMP and TEST come out above 2&times; on your machine, the flags are not being renamed there and the shape of the table is a fact about your silicon rather than about the ISA &mdash; which is worth knowing and worth reporting. If ADD and SUB come out near 1.0 as well, your compiler hoisted the chain and the body is not what the label says: check the disassembly before you believe either number.)</em></li>
                    <li><strong>Change the control so it is a control.</strong> Replace the eight <code>add $1</code> with eight <code>lea 1(%rax),%rax</code> &mdash; an operation that produces a value the next operation cannot use &mdash; and re-measure the chain. <em>(Expect the chain ratio to fall, because the dependency you removed was the whole of it. Then replace the eight with eight <code>mov %eax,%eax</code> and watch the chain ratio collapse to 1.0 as well, which tells you something uncomfortable: on a wide core, most of what looks like a dependency chain is not.)</em></li>
                    <li><strong>Build the SHR bug on purpose and find it with the bit pattern rather than the timing.</strong> Write a function that shifts by a value the caller supplies, forget to mask it, and have the caller pass 64. <em>(Expect a function that returns its input unchanged, with no fault and no diagnostic. Then write the checker you should have written &mdash; compare the result against the input, and reject any count &ge; 64 &mdash; and note that this is a correctness fix, not a performance one, and that the compiler will never have told you.)</em></li>
                    <li><strong>Go looking for the 16-bit write in code you did not write.</strong> Assembly produced by a hand-written backend, or a compiler with a misconfigured target triple. <em>(Expect it to be rare and to be catastrophic when it happens, because a 16-bit <code>mov</code> to a register is the only way in the integer set to produce a value whose low half is right and whose high half is a previous life. This is the single argument in this concept for reading the disassembly of a compiler you did not write.)</em></li>
                    <li><strong>Write out the OF rule and test all three cases.</strong> <code>sar</code> by one from a negative, <code>sar</code> by one from a positive, <code>sar</code> by a runtime amount. <em>(Expect the first two to set OF according to the table and the third to be undefined &mdash; and expect the third to be a case where the &ldquo;fast&rdquo; shift is the one you cannot check the flags of. A rule that is defined for a count of one and undefined for a count of two is a rule you cannot put in a compiler without a guard, and knowing which of your own code sits on that boundary is the point.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/exe/lessons/exe-latency">The execution course's latency concept</a> is where a dependency chain is derived rather than measured, and this concept deliberately does not repeat it: the experiment is the same shape and the subject is the ALU group as a set. <a href="/courses/isa/lessons/isa-opcodes">isa-opcodes</a> has the fourteen <code>0F xx</code> opcodes this course never names. <a href="/courses/isa/lessons/isa-rex">isa-rex</a> has the <code>48</code> in <code>48 8d 44 f7 08</code> and <a href="/courses/isa/lessons/isa-sib">isa-sib</a> has the <code>f7</code>; both are linked rather than repeated.</p>
                <p>Forwards, the flag table at the end of this concept is the <em>input</em> to <a href="/courses/x86asm/lessons/x86-flags">the flags concept</a>, which takes the six flags and asks what you can build out of them &mdash; and finds that the two branchless forms, <code>SETcc</code> and <code>CMOVcc</code>, differ in a way that no timing on this machine can see. <a href="/courses/x86asm/lessons/x86-vex">The prefix encodings</a> comes back to <code>0x8d</code> and <code>0x8b</code> and asks why <code>LEA</code> is a different opcode from a load rather than a load with a flag.</p>
                <p>Outward, two neighbours that own the edges of this one. <a href="/courses/simd/lessons/simd-width">The vector course's width concept</a> measured what a wrong width costs when the data is 128 bits wide, and found that an unaligned load is free on this machine &mdash; <strong>this course does not re-measure that and does not restate its number as its own</strong>, because re-publishing another course's measurement is the remembered-number mistake this course's harness exists to prevent. <a href="/courses/priv/lessons/priv-vectors">The privilege course's vector concept</a> covers the <em>system</em> vector of exceptions, which is a different word in a different language, and reading both is the cheapest way to stop confusing the two.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86asm/lessons/x86-asm">Reading a Disassembly Without Being Fooled</a></span>
                <span>Next: <a href="/courses/x86asm/lessons/x86-flags">From a Comparison to a Boolean</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
