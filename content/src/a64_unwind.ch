// The AArch64 Procedure Call Standard -- Concept 5: the second description of
// a frame.  The CFI ratio, and the shape the course was written to find and
// did not find.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_unwind() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Frame in a Second Language, and the Shape That Was Not There — Underlayer")
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
            <h1>The Frame in a Second Language, and the Shape That Was Not There</h1>
            <div class="lesson-meta">24 min &middot; <a href="/courses/a64abi">The AArch64 Procedure Call Standard</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Everything in the last four concepts happened while your function was <em>running</em>. Every instruction in it executed, in order, and the only person who could see it was the CPU. Now imagine a debugger, a profiler, a garbage collector, or an exception unwinder: something that arrives <strong>after the frame is gone</strong> and has to reconstruct where the saved registers were.</p>
                <p>It cannot. The CPU is gone, the registers are gone, and the stack below <code>sp</code> is, on AArch64, the region <a href="/courses/a64abi/lessons/a64-frame">concept 3</a>'s standard forbids anyone to read. <strong>So the frame has to describe itself, in advance, in a language that is not assembly.</strong></p>
                <div class="formula">
   THE PROBLEM, IN ONE SENTENCE

   A stack walk answers:  "for the frame at address A,
   where is register R?"

   The answer needs two facts: where the frame's base
   pointer is, and what offset from it R was saved at.

   Neither fact is recoverable from the stack on this
   architecture.  They have to be WRITTEN DOWN.
                </div>
                <p>That is Call Frame Information, and it is a genuinely <strong>second language</strong>: it has its own vocabulary, its own encoding inside <code>.eh_frame</code>, its own readers, and on this architecture it is <em>required to agree with a named register in the ABI</em>. The interesting measurement is the ratio between the two languages, and the second interesting thing is that the shape this course was written to find is not the shape the compiler produces.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: one frame, two descriptions, side by side</h2>
                <p>Here is <code>nonleaf</code> at -O0. Left: the instructions. Right: the directives that describe the same frame to something that was not there when the function ran.</p>
                <div class="hex-dump">
                <pre>  INSTRUCTIONS                    CFI DIRECTIVES
  sub sp, sp, #48            .cfi_startproc
  stp x29, x30, [sp, #32]    .cfi_def_cfa_offset 48
  add x29, sp, #32           .cfi_def_cfa w29, 16
  stur x0, [x29, #-8]        .cfi_offset w30, -8
  str x1, [sp, #16]          .cfi_offset w29, -16
  ldur x8, [x29, #-8]        .cfi_def_cfa wsp, 48
  ldr x9, [sp, #16]          .cfi_def_cfa_offset 0
  subs x8, x8, x9            .cfi_restore w30
  str x8, [sp, #8]           .cfi_restore w29
  ldr x0, [sp, #8]           .cfi_endproc
  ldur x1, [x29, #-8]
  bl inner
  ldr x8, [sp, #8]
  add x0, x0, x8
  ldp x29, x30, [sp, #32]
  add sp, sp, #48
  ret
                </pre>
                </div>
                <p><strong>Both columns describe one frame. The left is four instructions; the right is ten directives.</strong> Read the correspondence line by line, because it is the whole model:</p>
                <ul>
                    <li><strong><code>.cfi_def_cfa_offset 48</code> is <code>sub sp, sp, #48</code> in English.</strong> The <em>CFA</em> &mdash; Canonical Frame Address &mdash; is defined as <em>a register plus a number</em>. Initially the register is <code>wsp</code> and the number is 0: the canonical frame address is where the stack pointer was at the last point the table could see.</li>
                    <li><strong><code>.cfi_def_cfa w29, 16</code> is <code>add x29, sp, #32</code> plus arithmetic.</strong> The CFA rule has just <em>changed</em>: it is now <code>x29</code> + 16, and the 16 is the distance from the frame record to the CFA. <strong>The number and the register can change independently, and that is the entire expressive power of the format.</strong></li>
                    <li><strong><code>.cfi_offset w30, -8</code> is the fact that <code>x30</code> is in a register and was written to the stack.</strong> It is not an instruction; it is a claim about an instruction, made elsewhere, in advance.</li>
                    <li><strong><code>.cfi_def_cfa wsp, 48</code> then <code>.cfi_def_cfa_offset 0</code> is the epilogue</strong> &mdash; two directives to say &ldquo;the stack pointer is moving back&rdquo;.</li>
                </ul>
                <p>And the part that makes this architecture's version clearer than x86-64's: <strong>the register in <code>.cfi_def_cfa w29, 16</code> is not a convention the compiler chose. It is <code>r29</code>, the register AAPCS64 &sect;5.2.3 <em>names</em> as the frame pointer.</strong> On x86-64 the CFI reports a convention; here it is <strong>reporting which of the mandated levels of frame-record conformance the platform required</strong>, and a reader can go and look it up. The second language has a vocabulary the first language is quoted from. Read <a href="/courses/a64asm/lessons/a64-verify">the encoding course's cross-check concept</a> and then come back: that is the same property the first language has when a bit pattern is checked by two readers.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The measurement, and the shape that was not there</h2>
                <p>The question this concept exists to answer: <strong>how many CFI rows does a given function need, and how does that change with optimisation?</strong> A <em>row</em> is one <code>DW_CFA_advance_loc</code> &mdash; the unit that matters, because the unwind table is a <strong>piecewise-constant</strong> description of the frame and a row is the interval over which it is constant.</p>
                <p>So the plan and the brief for this course both offered this as the characteristic example:</p>
                <div class="formula">
   THE SHAPE THIS COURSE WAS WRITTEN TO FIND

   "a function that needs 3 rows at -O0 and 9 at -O2
    is saying something"

   And the measurement says: no function in this corpus
   does that.  No function EVER gains a row.  Row counts
   are 0, 2, 3 or 4 at every level, and nine functions go
   from 2 rows to 0.
                </div>
                <p><strong>A predicted shape that the measurement does not contain is a retraction and not a nuance.</strong> Here is the whole table, all twenty-five functions, so the surprise is measured rather than narrated &mdash; and so you can find the real shape yourself before it is named:</p>
                <div class="hex-dump">
                <pre>$ python3 a64abi.py --run | sed -n '/function    -O0  insn/,/va          110/p'
  function    -O0  insn/rows/rules/bytes  -O2  insn/rows/rules/bytes  what happened
  i9          34 / 2 / 0 / 20            13 / 0 / 0 / 16            shrank -4 bytes, rows -2
  m18         61 / 2 / 0 / 24            23 / 0 / 0 / 16            shrank -8 bytes, rows -2
  c9          21 / 4 / 2 / 36            19 / 4 / 2 / 36            identical
  use_big     13 / 4 / 2 / 36            11 / 4 / 2 / 36            identical
  leaf_spill  22 / 2 / 0 / 20            14 / 2 / 0 / 20            identical
  nonleaf     17 / 4 / 2 / 36            14 / 4 / 2 / 36            identical
  leaf_vec    18 / 2 / 0 / 20            10 / 2 / 0 / 20            identical
  many        84 / 4 / 2 / 40            67 / 4 / 12 / 64           TABLE GREW +24, rows +0
  fmany       81 / 4 / 2 / 36            54 / 4 / 10 / 76           TABLE GREW +40, rows +0
  va         110 / 3 / 1 / 32            68 / 2 / 0 / 24            shrank -8 bytes, rows -1
                </pre>
                </div>
                <p>Two functions grew. <strong>And neither of them grew in rows.</strong> That is the real finding, and it is better than the shape that was predicted:</p>
                <ul>
                    <li><strong><code>many</code> holds its 4 rows from -O0 to -O2 and its table grows from 40 to 64 bytes</strong>, because at -O0 it saves <code>x30</code> and <code>x29</code> and at -O2 it saves ten callee-saved registers as well &mdash; and <a href="/courses/a64abi/lessons/a64-save">every single one of them needs a <code>DW_CFA_offset</code> that says where to find it</a>. Twelve rules at -O2 against two at -O0.</li>
                    <li><strong><code>fmany</code> does the same thing in the vector bank: 36 to 76 bytes for the same 4 rows</strong>, because <code>d8</code>&ndash;<code>d15</code> became eight more rules. (Two of them are the exact <code>DW_CFA_offset</code> opcode and eight are the <em>extended</em> form &mdash; same information, different encoding, which is precisely why the <code>rules</code> column counts <code>DW_CFA_offset*</code> and the section 9B census counts only the exact opcode: 28 at -O2 rather than 36.)</li>
                    <li><strong>And <code>va</code> is the opposite, in both columns</strong>: 3 rows and 32 bytes at -O0, 2 rows and 24 bytes at -O2. The -O0 prologue is a <code>str x30, [sp, #304]</code>, an <code>add x8, sp, #112</code> and a <code>str x8, [sp, #40]</code> &mdash; <strong>three separate changes of the frame</strong>. The -O2 prologue is one <code>sub sp, sp, #224</code> and one <code>add sp, sp, #224</code>, and a frame that is entered once and left once needs a description of the interval between them and almost nothing else.</li>
                </ul>
                <div class="formula">
   THE INFORMATION CONTENT OF AN UNWIND TABLE

   It is neither the frame nor the row count.  It is

       the number of points at which the frame changes shape
       TIMES
       the number of registers whose location it states.

   And optimisation moves those two in OPPOSITE
   DIRECTIONS in the same function:

       many    rows  4 -> 4      rules  2 -> 12
       fmany   rows  4 -> 4      rules  2 -> 10
       va      rows  3 -> 2      rules  1 -> 0
       i9      rows  2 -> 0      rules  0 -> 0
            </div>
                <p>So the summary sentence of this concept: <strong>the row count says how many TIMES the frame changes, and the rule count says how much STATE it has, and only the second one went up.</strong> And the harness asserts the <em>direction</em> of both and not their values, because every one of these numbers is a property of clang 21.1.8 and not of a standard. That is retraction R7, printed in full by the artifact in section 11, and it is the second of the two predictions this course made about this table that the measurement refused.</p>
                <h3>And the other half of the ratio</h3>
                <p>Row counts are per function. The cost that matters is per <em>object</em>, and here the number is the most quotable thing on this page:</p>
                <div class="hex-dump">
                <pre>$ python3 a64abi.py --run | grep -A5 'eh_frame      ratio'
  lvl  .text bytes    .eh_frame      ratio          functions
  O0   2964           800            27.0%          25
  O1   1776           792            44.6%          25
  O2   1872           792            42.3%          25
  Os   1796           792            44.1%          25
                </pre>
                </div>
                <p><strong>The unwind table is a fixed fraction of the code and it does not shrink when the code does.</strong> At -O0 the object spends 27.0% of <code>.text</code> in <code>.eh_frame</code> and at -O2 it spends 42.3%, because the same 25 functions need the same 25 FDEs whether each is 34 instructions or 13. Halving the code moved the table from 27.0% to 42.3% of it. <strong>The per-function floor is a CIE reference, an FDE header and at least one row, and no amount of optimisation removes it</strong> &mdash; which is the whole information-content argument in one line: <strong>the cost of the second language is a function of the NUMBER OF FUNCTIONS, not of the amount of code in them.</strong></p>
                <p>So the practical advice is measurable rather than a matter of taste: <strong>unwind tables are worth paying for in a library with many small functions and not worth paying for in one with few large ones</strong>, and a compiler backend that cannot turn them off is paying a per-function tax on every function it emits. <code>gcc</code> and <code>clang</code> both have a flag for it, and this table is the number the flag is worth.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the second reader's own account, printed verbatim</h2>
                <p>Everything above was read out of <code>.eh_frame</code> with <code>struct.unpack_from</code>. Here is what <code>llvm-readelf-21 --unwind</code> says about the same bytes, printed as it prints them, because <strong>a second reader that is only summarised is not a second reader</strong>:</p>
                <div class="hex-dump">
                <pre>$ llvm-readelf-21 --unwind abi_O2.o | head -24
  .eh_frame section at offset 0x7e8 address 0x0:
    [0x0] CIE length=16
      version: 1
      augmentation: zR
      code_alignment_factor: 1
      data_alignment_factor: -4
      return_address_register: 30

      Program:
        DW_CFA_def_cfa: reg31 +0

    [0x14] FDE length=16 cie=[0x0]
      initial_location: 0x0
      address_range: 0x34 (end : 0x34)

      Program:
        DW_CFA_nop:
        DW_CFA_nop:
        DW_CFA_nop:
                </pre>
                </div>
                <p>Three lines in that header are the concept, and the third is the hinge back to <a href="/courses/a64abi/lessons/a64-registers">concept 2</a>:</p>
                <ul>
                    <li><strong><code>return_address_register: 30</code></strong> is <code>x30</code>, and the CFI is naming it. This is the register the frame record's <em>highest</em> addressed double-word holds, per AAPCS64 &sect;5.2.3 &mdash; so the second language is not inventing a fact, it is reporting a mandate.</li>
                    <li><strong><code>data_alignment_factor: -4</code></strong> is why every <code>DW_CFA_offset</code> in the table is negative and small (<code>-8</code>, <code>-16</code>). CFI offsets are in units of the data alignment factor, not bytes, so an offset of <code>-8</code> means <strong><code>-32</code> bytes</strong>. <strong>A reader who reads a <code>DW_CFA_offset</code> as a byte offset is wrong by a factor of four on every register in the table</strong>, and a debug session that prints <code>x30</code> at <code>rsp - 8</code> instead of <code>rsp - 32</code> will hand you a value from somewhere else in the frame and it will look like a real number.</li>
                    <li><strong><code>DW_CFA_def_cfa: reg31 +0</code></strong> &mdash; <code>reg31</code> is the stack pointer, and it is <strong>the same number 31</strong> that concept 2 showed being three different things in three different instruction slots. <strong>There is one number, and in the instruction file it means <code>sp</code> in a destination and zero in a logical source, and in the unwind table it means the stack pointer and nothing else.</strong> That is why the two pages are adjacent in the course, and it is the sharpest possible demonstration that a field's meaning is a property of the language that owns it.</li>
                </ul>
                <p>And one thing that is worth noticing by its absence: <strong>there is no row for the flags.</strong> <a href="/courses/a64abi/lessons/a64-save">Concept 4</a> counted zero <code>mrs</code>/<code>msr</code> of a flag register, and here is the consequence at the other end: on x86-64 the <code>DW_CFA</code> encoding has no register for the flags either, so an unwinder on both architectures simply cannot restore them &mdash; and on x86-64 that is a <em>loss</em>, because <code>PUSHFQ</code> put them in the frame. <strong>Same gap in the format, two different reasons for it.</strong></p>
                <h3>What cannot be measured here</h3>
                <p>Everything on this page is a count of things in a file. <strong>No unwinder was run</strong> &mdash; there is no AArch64 machine, emulator or linker on the build host, so not one instruction in this course has been executed. So the claims here are that the table <em>contains</em> the description, not that any tool <em>used</em> it correctly. <a href="/courses/x86abi/lessons/x86-unwind">The x86-64 unwinding concept</a> is where you will find the other half of that: it ran <code>backtrace()</code> on real hardware and got seven frames with the flag and one frame without it, and <strong>that is a result this architecture cannot produce, at all, on this host</strong>.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Turn the tables off and count what you saved.</strong> Compile a small C file for <code>aarch64-linux-gnu</code> twice, with and without <code>-fno-asynchronous-unwind-tables</code>, and compare the <code>.eh_frame</code> size against the <code>.text</code> size in each. <em>(Expect <code>.eh_frame</code> to vanish and the ratio to go from 42.3% to nothing at -O2, and expect the per-function cost to be roughly constant as you add functions: 792 bytes for 25 functions is about 32 bytes each, and 25 more functions will cost about 25 more. Then add the flag back and try it at -O0, where the ratio is 27.0% rather than 42.3% &mdash; the same table is a much better deal when the code it describes is long.)</em></li>
                    <li><strong>Read a <code>DW_CFA_offset</code> as bytes and watch it be wrong by four.</strong> Take the <code>nonleaf</code> prologue, note <code>.cfi_offset w30, -8</code>, and compute the address as <code>x29 - 8</code>. <em>(Expect garbage: the offset is in units of the data alignment factor, which is -4, so the register is at <code>x29 - 32</code>. Then confirm it against the instruction stream &mdash; <code>stp x29, x30, [sp, #32]</code> puts <code>x30</code> at the higher address, 16 bytes above <code>x29</code> itself, and the CFA is <code>x29 + 16</code>, so <code>x30</code> is at CFA minus 32. Three different descriptions of one 16-byte store, and they agree.)</em></li>
                    <li><strong>Look for the row count to lie to you.</strong> Find a function in the corpus whose CFI has <strong>zero</strong> rows &mdash; <code>i9</code> at -O2 has none, and nine functions have none &mdash; and check what the FDE says. <em>(Expect the minimum 16-byte FDE: a header, a CIE pointer, and a padding <code>DW_CFA_nop</code> instead of rows. That is not a broken table; it is a function that allocates nothing, so there is nothing to describe, and it is the floor the 27.0%-to-42.3% argument is built on. Now find the function whose table <em>grew</em> &mdash; <code>fmany</code>, 36 to 76 bytes, same four rows &mdash; and you have the whole concept in two lookups.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, all four, and specifically <a href="/courses/a64abi/lessons/a64-save">concept 4</a>: the callee-saved registers are exactly what a second description has to record, and <code>many</code> growing from 40 to 64 bytes at a constant four rows is a direct consequence of it saving ten more registers. <a href="/courses/a64abi/lessons/a64-registers">Concept 2</a> is the hinge &mdash; <code>reg31</code> in the CFI and <code>sp</code> in the instruction field are the same five bits with different owners. <a href="/courses/a64abi/lessons/a64-frame">Concept 3</a> is the subject being described a second time, and the four marked prologue lines there are the four lines the directives on this page describe. <a href="/courses/a64abi/lessons/a64-aapcs">Concept 1</a> is the reason the CFA is defined in terms of a stack pointer at all.</p>
                <p>Sideways, three neighbours that own the edges. <a href="/courses/dyn/lessons/dyn-order-runtime">The dynamic-linking course</a> is where a frame gets walked for the first time in a real program, because that is what the loader does before <code>main</code>. <a href="/courses/sec/lessons/sec-canary">The stack canary</a> is a value in the frame with no unwind entry of its own &mdash; and a reader who has read this page can now say precisely why a canary cannot be verified during an unwind. <a href="/courses/x86abi/lessons/x86-unwind">The x86-64 unwinding concept</a> is the same second language with a frame pointer that <em>moves</em>, and it is the one place in the collection that could measure what happens when the description is missing.</p>
                <p>Outward, and the general form is worth carrying out of here. <a href="/courses/a64asm/lessons/a64-verify">The encoding course's two-reader cross-check</a> is the same argument applied to bytes: two readers, and then one of them poisoned on purpose so that 100% means something. <a href="/courses/x86abi/lessons/x86-verify">The x86-64 ABI course's verification concept</a> is the same argument applied to a compiler, and it found 271 <code>PUSHFQ</code> in 9,255 real functions and had to explain 97 of them. <strong>A claim that two independent readings agree on is worth something a claim that one reading supports is not, and this concept is a claim that one reading supports &mdash; and says so.</strong></p>
                <p>And the last honest word: this course ends where the section's next courses begin. Everything on these five pages is checkable with a hex editor, which is the design. The parts of the chain that need silicon &mdash; whether a <code>stp</code>/<code>ldp</code> pair is free, whether a misaligned store traps, whether an unwinder reads the right slot &mdash; are somebody else's course, and the artifact's section 12 names every one of them in its own words.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/a64abi/lessons/a64-save">Callee-Saved, and the Count of Zero That Is Also a Rule</a></span>
                <span>End of The AArch64 Procedure Call Standard &middot; <a href="/courses">all courses</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
