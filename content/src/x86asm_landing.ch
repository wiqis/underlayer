// x86-64 Assembly and Encoding — course landing page
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86asm_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("x86-64 Assembly and Encoding — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    // THE PRE-PAINT THEME.  This landing page calls render_lesson_nav, which
    // passes lesson=true and therefore skips the theme script -- correct for a
    // LESSON, whose palette is hardcoded light, but wrong here: this is a
    // course landing page and a reader who chose dark, or whose OS is dark,
    // should not get a flash of light before the page settles.
    //
    // Two lines, and the alternative is to change what these 28 pages call --
    // a layout change across the whole collection that is worth doing on its
    // own and is not what the flash report asked for.
    render_theme_boot_js(&mut page, false)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson x86asm-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>x86-64 Assembly and Encoding</h1>
            <div class="lesson-meta">5 concepts &middot; 2 modules &middot; 127 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
                <p>Six courses came before this one and four more of this shape follow it, and none of the ten mentions the subject of this course's title even once. A word-boundary scan over the concept files of all 21 shipped courses, taken the morning this course was written:</p>
                <div class="formula">
  term                             files  where
  SUB CMP MOVZX LEAQ SHR ROL        0     the integer set is untaught as a set
  SETcc CMOVcc                     0
  AT&T  Intel syntax  disassembly   0
  addps addpd movaps pxor           0     the ISA course names FOURTEEN
  red zone  callee-saved  GPR       0     `0f xx` opcodes in total
  EFLAGS                           2     both as a ROLE, never as a layout

  VEX  EVEX                         many  but every one of them is a
                                         PREFIX BYTE in the 0x62-is-BOUND
                                         story, and none says what the
                                         instruction does
                </div>
                <p><a href="/courses/isa/lessons/isa-modrm">The ISA course</a> taught the ModRM byte. <a href="/courses/isa/lessons/isa-rex">REX</a>. <a href="/courses/isa/lessons/isa-sib">SIB</a>. <a href="/courses/isa/lessons/isa-length">The length arithmetic</a>, and a thousand-line decoder in <a href="/courses/isa/lessons/isa-decode">isa-decode</a>. All of that is the <em>encoding</em> of one instruction. None of it is the <em>set</em> of instructions, and the split is the rule this section follows: <strong>the comparison lives in the neutral courses; the depth lives in the per-architecture ones.</strong> This is the per-architecture one, and what it owes in return is the exhaustive table.</p>
                <p>What it does <em>not</em> owe is anything the seven neutral courses already taught. It does not re-derive the ModRM byte, it links to it. It does not re-derive a dependency chain, it links to <a href="/courses/exe/lessons/exe-latency">the execution course</a> and measures the ALU group as a set. It does not re-derive branch prediction, it links to <a href="/courses/exe/lessons/exe-speculate">exe-speculate</a> and then says out loud that it cannot measure mispredictions on this machine and declines to guess.</p>
            </div>

            <div class="unit unit-model">
                <h2>The two results that were not the ones expected</h2>
                <p>Four instructions in one group, one dependency chain of eight against eight independent ones, and the answer is in the bottom half of the table.</p>
                <div class="hex-dump">
                <pre>$ ./x86dec | sed -n '/THE RATIOS THAT ARE THE POINT/,/^$/p'
         add      3.72x
         sub      4.02x
         cmp      1.00x
         test     1.01x
  </pre>
                </div>
                <p><strong>ADD and SUB chain at 3.72&times; and 4.02&times;. CMP and TEST chain at 1.00&times; and 1.01&times; &mdash; they do not chain at all.</strong> Eight flag-writers in a row cost the same as eight flag-writers on eight registers, and there is exactly one flags register. The draft of this course asserted the opposite, and the assertion came from reading the ISA manual: the manual says they all write the same <em>register</em>, which is a true sentence and is not the same sentence as <em>they serialise against each other</em>.</p>
                <p>And the second result is a table of 768 opcode slots read twice, once with the legacy escape and once with a VEX byte in front of the very same slots:</p>
                <div class="hex-dump">
                <pre>$ ./x86dec | sed -n '/map        slots/,/neither/p'
  map        slots   legacy   VEX   legacy only   VEX only   both   neither
  0F           256     218   101           124          7     94        31
  0F38         256      28   125            13        110     15       118
  0F3A         256       2    54             1         53      1       201
  </pre>
                </div>
                <p><strong>0F 3A is named in two of its 256 slots with the legacy escape, and in fifty-four of them with one byte in front.</strong> The maps were not left full. They were left <em>roomy</em>, and the room is what VEX and then EVEX moved into. That field &mdash; <code>mmmmm</code>, the map selector &mdash; is the whole reason a three-byte VEX exists, and it is the exact opposite of what the first draft of this page claimed.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Three things that are cheaper to state than to prove</h2>
                <p>This course has a habit that the four before it established, and it is worth showing before the first concept rather than after the last one.</p>
                <ul>
                    <li><strong>The three-byte VEX form is not for 256-bit registers.</strong> It can name them perfectly well: <code>L</code> is bit 2 of byte 1, and the assembler emits the <em>two</em>-byte form for <code>vaddps %ymm2, %ymm0, %ymm1</code> &mdash; <code>c5 fc 58 ca</code> &mdash; while this course was being written. It is for four register numbers, and for a fourth operand.</li>
                    <li><strong>A <code>LEA</code> is not a fast way to compute an address.</strong> One <code>LEA</code> and the three instructions that compute the same address measure the same, to within a spread of 230 % across seven alternating repetitions of the ratio, and a mean of 1.09&times; is not evidence that they are equal either.</li>
                    <li><strong>A failing <code>cmov</code> still reads its source operand.</strong> Not "costs about as much as" &mdash; <em>reads it</em>. The instrument is a page marked <code>PROT_NONE</code>: the child dies with SIGSEGV on the failing <code>cmov</code> and survives the failing branch, and the register results are identical so no stopwatch was ever going to find it.</li>
                </ul>
                <p>Each of those was asserted in a draft of this course. Each was measured. Each was retracted in public and the retraction is printed by the artifact and asserted as text by the harness, so it cannot be quietly deleted by a later edit.</p>
            </div>

            <div class="unit unit-example">
                <h2>What is deferred, and what this artifact will not claim</h2>
                <p>Printed in the artifact's own limits block rather than footnoted, because a limit that is a footnote is a limit that gets forgotten. <code>perf_event_paranoid</code> is <strong>4</strong> and a forked child that executed <code>RDPMC</code> was killed, so there is no PMU at all:</p>
                <ul>
                    <li><strong>No cycle counts.</strong> Every number in the measurement sections is a <em>duration</em>, and a duration bounds a count without measuring it. The instrument that would settle it is <code>perf_event_open</code> with <code>perf_event_paranoid</code> below 4 and a PMU passthrough.</li>
                    <li><strong>No branch mispredictation rate, in either direction.</strong> The artifact measures the branch in a loop the predictor can learn and says so, and will not put a number on the other case. An arm that mixed a predictable and an unpredictable branch was written, measured, and <strong>deleted</strong>: it measures a blend it cannot decompose.</li>
                    <li><strong>No observation of flag renaming.</strong> The measurements are consistent with renaming and with not renaming, and no user-mode program is allowed to find out. The vendor manual is the only source that says which it is, and the artifact labels the citation separately from the measurement.</li>
                    <li><strong>No AVX-512 execution.</strong> This part raises #UD on all of it. The EVEX concepts are a decoder result and a fault result, and they say which is which.</li>
                    <li><strong>The other two architectures are quoted, not measured.</strong> RISC-V has no flags register and no condition codes and therefore needs <code>csel</code> and <code>cset</code> to do what <code>SETcc</code> and <code>CMOVcc</code> do here. There is no such machine in the room.</li>
                </ul>
                <p>The completion criterion is not &ldquo;read it&rdquo;. It is: <em>reproduce the 155 checks, then break the decoder's length arithmetic on purpose and make the group that catches it fail by name.</em> A check that has never been seen to fail is a check with no reason to be believed, and the last concept is about a harness group that had four failures of its own before it had any passes.</p>
            </div>

            <div class="unit unit-connect">
                <h2>What comes before, and what comes next</h2>
                <p>Before. <a href="/courses/isa/lessons/isa-decode">The ISA course's decoder</a> is the direct ancestor of this course's, and its length arithmetic is the thing the last concept deliberately breaks. <a href="/courses/isa/lessons/isa-length">isa-length</a> is where the variable-length property is derived; this course quotes the derivation and measures what a 1-byte and a 4-byte instruction each cost, which is a different question. <a href="/courses/exe/lessons/exe-verify">The execution course's harness</a> and <a href="/courses/priv/lessons/priv-harness">the privilege course's</a> are the two verification models this course's harness is a third instance of, and both were written by a hand that had already broken a harness. <a href="/courses/smp/lessons/smp-atomic">The atomic concept</a> is where the <code>lock</code> prefix lives, and the four courses that follow this one &mdash; the ABI, the machine, the data path, and the artifact &mdash; all read this one's tables as given.</p>
                <p>Forward, and the practical weight is in a compiler backend. <strong>The flag table and the encoding are the two things you must get exactly right and the two things nobody thinks about</strong>, because both are invisible in the source: <code>a &lt;&lt; b</code> and <code>a &gt;&gt; b</code> are one byte different, and <code>mov eax, al</code> and <code>mov ax, al</code> are four bytes of difference with the same mnemonic. A backend that emits the wrong one produces a program that is correct on some inputs and silently wrong on the rest, and there is no test that reliably finds it.</p>
            </div>

            <div class="lesson-footer">
                <span>Start: <a href="/courses/x86asm/lessons/x86-asm">Reading a Disassembly Without Being Fooled</a></span>
                <span>End of x86-64 Assembly and Encoding &middot; <a href="/courses">all courses</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
