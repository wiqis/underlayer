// The RISC-V Privileged Architecture -- concept 3: ecall, the five trap
// registers, and why the mode is not in the instruction.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rv_traps() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("ecall, the Five Registers, and Why the Mode Is Not in the Instruction — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson rvpriv-concept">
            <a href="/courses/rvpriv" class="back-link">The RISC-V Privileged Architecture</a>
            <h1>ecall, the Five Registers, and Why the Mode Is Not in the Instruction</h1>
            <div class="lesson-meta">24 min &middot; Concept 3 of 4 &middot; module: the address, the bits, and the trap &middot; <a href="/courses/rvpriv">The RISC-V Privileged Architecture</a></div>

            <div class="unit unit-why">
                <h2>The strongest thing measured on this page, and it is measured as emitted</h2>
                <p>Everything a system call <em>is</em> &mdash; who handles it, what it returns, what the mode transition costs &mdash; is unmeasurable on this host. There is no RISC-V machine, no emulator, and no way to observe a trap. So this concept opens by being precise about the weaker claim it <em>can</em> measure, and then measures that as hard as it can.</p>
                <div class="callout callout-warn">
                    <p><strong>The distinction, stated once and used throughout:</strong> <em>MEASURED-AS-EMITTED</em> means the compiler produced the constant <code>0x00000073</code> with the ABI&rsquo;s registers around it. It does <strong>not</strong> mean the trap is taken, that supervisor mode is entered, that <code>a7</code> is ever read, that a kernel exists, or that anything comes back. All five are quoted rules with section numbers attached, and the artifact labels every one of them QUOTED.</p>
                </div>
                <p>Now the measurement. The corpus contains three wrappers: one that puts the syscall number in <code>a7</code>, one that puts it in <code>a6</code> &mdash; the register a reader would guess from x86-64, where the number goes in <code>rax</code> &mdash; and one other.</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/THE CONTROL\./,/^$/p'
  THE CONTROL.  `sys_write` puts the number in a7 and
  `sys_write_a6` puts it in a6 -- the register a reader would
  guess from x86-64, where the number goes in rax.  The two
  functions are the same C with one word changed.

    li     a7, 0x40           0x04000893
    li     a6, 0x40           0x04000813
    XOR 0x00000080 -- bits 7
                </pre>
                </div>
                <p>Two instructions. <code>li a7, 0x40</code> is <code>0x04000893</code> and <code>li a6, 0x40</code> is <code>0x04000813</code>, and they differ by <code>0x00000080</code> &mdash; <strong>bit 7, one bit, and nothing else in the word.</strong> And that bit has a name: <code>a7</code> is x17 and <code>a6</code> is x16, and x17 is <code>0b10001</code> while x16 is <code>0b10000</code>, so the difference is the lowest bit of the <strong>destination field</strong>, <code>rd</code> at <code>inst[11:7]</code>. Not the opcode, not the immediate, not the CSR field.</p>
                <p>Now put that next to what <code>ecall</code> actually is. <code>ecall</code> is <code>0x00000073</code> &mdash; thirty-one fixed bits and nothing that names a register. The number is in <code>a7</code>, which is <code>rd[0]</code> of a word three instructions earlier, and <em>nothing in the <code>ecall</code> refers to it</em>.</p>
                <div class="callout callout-note">
                    <p><strong>So the entire difference between a working system call and a broken one, on this architecture, is a bit that appears in a DIFFERENT INSTRUCTION than the one that performs the call.</strong> There is no linker check for it, no assembler check for it, no encoding relationship between the two words, and no diagnostic. A kernel whose ABI said <code>a6</code> instead of <code>a7</code> would be a kernel that works, and the only way to find out which one you have is to read <code>a7</code> or <code>a6</code> out of a register in a debugger on hardware this host does not have.</p>
                </div>
                <p>That is the strongest form of &ldquo;the <code>ecall</code> convention is an ABI and not an architecture&rdquo;, and it is measured rather than asserted. The weaker form &mdash; <em>the instruction does not name a register</em> &mdash; is true and was already stated in <a href="/courses/rvasm/lessons/rv-immediate"><code>rv-immediate</code></a>. The stronger form is that the register the ABI names is carried by a field <strong>the ABI also has to agree on separately</strong>, one bit wide, in an instruction the architecture does not associate with the call.</p>
                <h3>And it holds at four optimisation levels</h3>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/THE SAME FUNCTIONS AT FOUR LEVELS/,+6p'
  level    sys_write insns   bytes    sys_write_a6 insns  words that differ  same length?
  O0       30                100      30                  1                 yes
  O1       5                 16       5                   1                 yes
  O2       5                 16       5                   1                 yes
  Os       5                 16       5                   1                 yes
                </pre>
                </div>
                <p>The instruction counts spread from 30 to 5, and <strong>that spread is the compiler&rsquo;s and not the convention&rsquo;s</strong>. A reader who quoted 30 would be quoting a property of clang&rsquo;s <code>-O0</code> scaffolding; a reader who quoted 5 would be quoting clang 21.1.8&rsquo;s <code>-O1</code>. The number that is the ABI&rsquo;s is the last two columns: the two functions have the <strong>same length at every level and differ in exactly one word</strong>. Which word moves with the level &mdash; at <code>-O0</code> the registers are spilled and reloaded, so it moves &mdash; and that is why the harness asserts the shape and not the offsets.</p>
                <p>That distinction was learned the hard way and is retraction R4: the first version of the corpus never used its arguments after the trap, clang deleted the argument loads at <code>-O1</code> and above, and the function became three instructions &mdash; a number that is a compiler&rsquo;s opinion of unused parameters rather than a count of the convention. <strong>A count over <code>-O0</code> is a count of a compiler&rsquo;s scaffolding, and the only way to tell a convention&rsquo;s number from a compiler&rsquo;s is to vary the level and see which one moves.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>The five trap registers, and the one bit that writes them</h2>
                <p>Five CSRs carry a trap&rsquo;s state, and their addresses are the twelve-bit numbers from <a href="/courses/rvpriv/lessons/rv-modes">concept 1</a> decomposed. The artifact prints all of them with the decomposition beside the address, which is what makes the convention real rather than a list of hex numbers:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/  name      address/,/^  mtvec/p' | grep -E 'name|stvec|sepc|scause|stval|satp '
  name          address    word          csr[11:10]  access  csr[9:8]  privilege  csr[7:0]
  stvec         0x105      0x105022f3    0           rw      1          S          0x05
  sepc          0x141      0x141022f3    0           rw      1          S          0x41
  scause        0x142      0x142022f3    0           rw      1          S          0x42
  stval         0x143      0x143022f3    0           rw      1          S          0x43
  satp          0x180      0x180022f3    0           rw      1          S          0x80
  mtvec         0x305      0x305022f3    0           rw      3          M          0x05
                </pre>
                </div>
                <p>Every supervisor row has <code>csr[9:8] = 1</code> and every machine row has <code>csr[9:8] = 3</code>. That is not decoration: it is the difference between a trap handler and a user program, encoded in the number. And read the last two columns together &mdash; <code>mtvec</code> and <code>stvec</code> are both &ldquo;number 5&rdquo;, and they are different registers only because of the privilege pair.</p>
                <h3>And every one of them is written by the same instruction</h3>
                <p>Here is the finding this concept is built around, and it comes from writing the same CSR three ways and looking at the words:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/THE THREE stvec WRITES/,+7p'
  function                  insns    the register    the value in it        the whole body
  set_stvec_direct          4        a1              0x000000001000        lui | csrr | csrw | ret
  set_stvec_vectored        5        a1              0x000000001001        lui | addi | csrr | csrw | ret
  set_stvec_misaligned      4        a1              0x000000000123        li | csrr | csrw | ret

  ALL THREE FUNCTIONS EMIT THE SAME 32-BIT WORD FOR THE stvec WRITE, 0x10559073
                </pre>
                </div>
                <p><strong>Direct, Vectored and a misaligned value all emit <code>0x10559073</code>.</strong> The mode is not in the instruction &mdash; it is in the value, four instructions earlier, and the instruction does not know which of the three things it is writing. So a disassembler reading the object can recover the instruction and <strong>cannot recover the mode</strong>, and the value that would tell it is four instructions earlier in the same function.</p>
                <p>The third function is the interesting one. The specification says the CSR &ldquo;contains only bits XLEN&minus;1 through 2 of the address BASE&rdquo; and that &ldquo;the lower two bits are filled with zeroes&rdquo;, so:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/AND THE MISALIGNED ONE/,+3p'
  AND THE MISALIGNED ONE IS THE INTERESTING ONE. ... So
  writing 0x123 does NOT set BASE to 0x123: it sets BASE to 0x120 and MODE
  to 3, and a mode of 3 is Reserved, which `priv-spec` says in one word and
  does not define.
                </pre>
                </div>
                <p>And the assembler did not diagnose it. There is no diagnostic, and there could not be: <strong>the instruction does not know the value.</strong> A kernel that computes a trap vector address and forgets to clear the low two bits gets a Reserved mode, and the behaviour of a Reserved mode is not specified. This is the third place in the course where a constraint is enforced by hardware this host does not have, and it is the one a backend author is most likely to get wrong &mdash; because the code is a perfectly ordinary <code>csrw stvec, a1</code> and reads correctly.</p>
                <div class="callout callout-note">
                    <p><strong>Decode that word and notice what is not in it.</strong> <code>0x10559073</code> is: opcode <code>0x73</code>, <code>funct3</code> = 1 so CSRRW, <code>inst[31:20]</code> = <code>0x105</code> so <code>stvec</code>, <code>rs1</code> = 11 = <code>a1</code>, <code>rs2</code> = 5 = <code>t0</code>, <code>funct7</code> = 8, and <code>rd[4:0]</code> = 0. <strong>The zero in <code>rd</code> is what makes the write discardable</strong>, and that is why <code>csrw</code> needs no encoding of its own: it is the encoding with <code>rd</code> = <code>x0</code>, which is concept 1&rsquo;s alias table showing up here as a consequence rather than as a curiosity. And <code>funct7</code> = 8 and <code>rs2</code> = 5 are both read off the word and <em>neither is in the source</em>.</p>
                </div>
            </div>

            <div class="unit unit-example">
                <h2>The interrupt bits: a quoted rule, measured without quoting it</h2>
                <p>Three functions set one interrupt-enable bit each, and the whole of the interrupt &mdash; the cause number, the bit, the mask &mdash; is a constant the compiler passed through:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/THE THREE INTERRUPT ENABLE BITS/,+4p'
  function        cause number    the bit       the mask   what the compiler emitted  body
  enable_ssie     1               1 &lt;&lt; 1        0x2        0x2     csrr | ori | csrw | ret
  enable_stie     5               1 &lt;&lt; 5        0x20       0x20    csrr | ori | csrw | ret
  enable_seie     9               1 &lt;&lt; 9        0x200      0x200   csrr | ori | csrw | ret
                </pre>
                </div>
                <p>Read the masks as a <em>shape</em> rather than as three numbers: <code>0x2</code>, <code>0x20</code> and <code>0x200</code> are 1, 5 and 9 <strong>shifted left once</strong>, and that shift is the whole of the mapping from cause number to bit position. A reader who has internalised the rule can derive the mask for cause 13 without looking it up &mdash; and that is a property a quoted table does not give you.</p>
                <p>The rule itself is quoted: &ldquo;Interrupt cause number <em>i</em> &hellip; corresponds with bit <em>i</em> in both <code>sip</code> and <code>sie</code>.&rdquo; The cause numbers 1, 5 and 9 are the specification&rsquo;s Table 2. But notice what was measured: the compiler emitted <code>ori a0, a0, &lt;mask&gt;</code> and nothing else. It has no idea these are interrupts &mdash; it sees <code>v | (1UL &lt;&lt; 5)</code> in C.</p>
                <div class="callout callout-warn">
                    <p><strong>And the read-then-write is not a convention either. It is a race.</strong> Each of the three functions is <code>csrr sie ; ori ; csrw sie</code> &mdash; a read-modify-write of a register that hardware also writes, and two of them running at once lose an update. The specification&rsquo;s answer is that <code>sie</code> and <code>sip</code> are subsets of <code>mie</code> and <code>mip</code> and the writes go to the same homonymous fields; it does not provide an atomic read-modify-write, and a kernel that enables interrupts does it in a critical section. None of that is measurable here. <strong>The race is a quoted consequence and the three instruction triples are measured on bytes, and the two must not be run together in a reader&rsquo;s head.</strong></p>
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>What was measured here, and what was not</h2>
                <p>This is the concept where the gap between measured and quoted is widest, so it gets the longest scope list.</p>
                <ul>
                    <li><strong>MEASURED-AS-EMITTED:</strong> the constant <code>0x00000073</code>; that <code>a7</code> is the destination of the instruction that loads the number; that <code>a7</code> and <code>a6</code> differ by exactly bit 7 of one word; that the pair differs in exactly one word at all four optimisation levels.</li>
                    <li><strong>MEASURED-ON-BYTES:</strong> the three <code>stvec</code> functions&rsquo; words, all identical; the five trap CSR addresses and their decompositions; the three enable masks and the compiler&rsquo;s <code>ori</code> immediates; the read-modify-write instruction triples.</li>
                    <li><strong>QUOTED:</strong> that the syscall number goes in <code>a7</code> and the return value in <code>a0</code>; that <code>ecall</code> raises an environment-call exception and traps to supervisor mode; that the <code>stvec</code> low two bits are the MODE field; that a mode of 3 is Reserved; that cause number <em>i</em> is bit <em>i</em> in <code>sip</code>/<code>sie</code>; that the read-modify-write race exists and needs a critical section.</li>
                    <li><strong>NOT MEASURED, AND NOT MEASURABLE ON THIS HOST:</strong> that the trap is taken; that supervisor mode is entered; that <code>a7</code> is read; that a kernel exists; that anything returns; that the hardware clears the low two bits of <code>stvec</code>&rsquo;s BASE; that the race actually loses an update.</li>
                </ul>
                <p>Retraction R11 is this page&rsquo;s, and it is the one that took two attempts: the first draft reported the three functions&rsquo; bodies as three different instruction counts, and a reader could have concluded the mode was visible in the code; the second draft had the same finding for a different reason &mdash; the functions returned their constant, clang put the return value in <code>a1</code> and the argument in <code>a0</code>, and the three <code>csrw</code> words came out with <em>two different</em> <code>rs1</code> values. The fix made the functions return the value instead, so all three write the same register. <strong>A disassembler reading the object can recover the instruction and cannot recover the mode, and the value that would tell it is four instructions earlier in the same function.</strong></p>
                <p>And one methodological retraction that belongs on this page even though it is about a different section: R4, the <code>-O0</code> scaffolding, is recorded here because <em>this</em> is the concept whose numbers it nearly corrupted.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Count the bits between two working system calls.</strong> <em>(Take the two lines from the control block above and work out, from the ISA alone, which field the differing bit lives in and what its width is. The answer is one bit of <code>rd</code>, which is five bits wide &mdash; so the ABI chose the <em>lowest</em> of thirty-two register numbers and the difference is <code>0x80</code> in the word. Then ask: if the ABI had said <code>a5</code>, would the toolchain have noticed? It would not, and neither would yours.)</em></li>
                    <li><strong>Write a <code>set_stvec</code> that can be got wrong, and prove the assembler will not help.</strong> <em>(Return <code>base | 1</code> without clearing the low two bits &mdash; or <code>base + 4</code>, whose low two bits are already clear, versus <code>base + 2</code>, whose are not. Assemble all three and confirm the <code>csrw</code> word is <strong>identical in all three cases</strong>. Then write down what actually distinguishes them: a value four instructions earlier that a human being chose.)</em></li>
                    <li><strong>Derive a mask you have not looked up.</strong> <em>(The page derives the masks for causes 1, 5 and 9 by shifting. Work out the mask for cause 13 &mdash; supervisor external interrupt is not 13, so pick a cause that is: use the specification&rsquo;s table &mdash; and then write the C that would produce it and compile it. If your C emits <code>ori</code> with that immediate, you have measured the rule without quoting it, which is the whole of this section&rsquo;s method.)</em></li>
                    <li><strong>Change the optimisation level and watch which number moves.</strong> <em>(Rebuild the corpus at <code>-O0</code>. The instruction counts will move from 5 to 30 and the byte counts from 16 to 100. The two numbers that must <em>not</em> move are the last two columns: same length, one word differing. Those are the ABI&rsquo;s numbers. Everything else in the table is clang 21.1.8&rsquo;s, and quoting it as a property of the convention is retraction R4.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Back to <a href="/courses/rvpriv/lessons/rv-modes">concept 1</a>, where the twelve-bit CSR address was decomposed &mdash; the <code>csr[9:8] = 1</code> column on this page is that decomposition applied to five specific numbers, and the <code>funct3</code> bit that makes <code>csrw</code> discardable is the same bit concept 1 found between the register and immediate forms. Forward to <a href="/courses/rvpriv/lessons/rv-boundary">concept 4</a>, where every measured and quoted claim on the first three pages is counted in one table.</p>
                <p>Out to <a href="/courses/rvabi/lessons/rv-calling"><code>rv-calling</code></a>, which is where <code>a7</code> and <code>a6</code> were introduced as ordinary argument registers. On this page they acquire a job, and the interesting thing is that the job is <em>not visible in the instruction that does it</em> &mdash; which is a fact about the boundary between an ABI and an architecture, and that course is where the ABI half lives.</p>
                <p>And out to <a href="/courses/a64sys/lessons/a64-syscall"><code>a64-syscall</code></a> and <a href="/courses/x86sys/lessons/x86-syscall"><code>x86-syscall</code></a>, which ask the same question on machines this collection can run. Read them beside this page and the difference is the point of the course: those two could watch a trap happen and describe its cost. This one cannot, so it counted the bits that make it work &mdash; and the bit it found is one that neither a linker nor an assembler will ever check for you.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/rvpriv/lessons/rv-paging">Sv39, Sv48, Sv57 and satp, Measured on the Compiler's Own Shifts</a></span>
                <span>Next: <a href="/courses/rvpriv/lessons/rv-boundary">What This Course Measured, and What It Refused To</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}