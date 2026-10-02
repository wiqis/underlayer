// The AArch64 Procedure Call Standard -- Concept 4: who must save what.
// x19-x28, the bottom 64 bits of v8-v15, the platform register, and the two
// counts of zero that are also rules.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_save() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Callee-Saved, and the Count of Zero That Is Also a Rule — Underlayer")
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
            <h1>Callee-Saved, and the Count of Zero That Is Also a Rule</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/a64abi">The AArch64 Procedure Call Standard</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p><a href="/courses/a64abi/lessons/a64-aapcs">Concept 1</a> said which register argument four goes in. <a href="/courses/a64abi/lessons/a64-frame">Concept 3</a> said how a function gets memory. Neither said what happens to a register's <em>contents</em> across the call &mdash; and that is the question a function actually has to answer, because a value the compiler put in a register before a call is dead unless somebody saves it.</p>
                <p>The split is a bargain, and it is the same bargain on every architecture:</p>
                <div class="formula">
   THE BARGAIN

   CALLER-SAVED  a temporary.  Use it freely.  After the
                 call, assume it is destroyed.  Cost of
                 using one: nothing.

   CALLEE-SAVED  a slot with your name on it.  Use it only
                 if you are willing to write it back.  After
                 the call, assume it survived.  Cost of
                 using one: two instructions.

   The compiler pays the cost, not the programmer.  The
   rule exists so that neither side has to know the other's
   register allocation.
                </div>
                <p>Why the split exists at all: a fixed rule is the only kind of rule that can be checked. &ldquo;The callee preserves <code>x19</code>&ndash;<code>x28</code> unless it uses them, in which case it restores them&rdquo; is a sentence two compilers can both obey without exchanging a word. &ldquo;The callee preserves the registers it used&rdquo; is not, because each side would have to know what the other did.</p>
                <p>On this architecture the list is short, the vector half has a clause that everybody drops, and two of the rules people <em>quote</em> for AArch64 do not exist. All three of those are measured below.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: the document's four rows, and the one everybody drops</h2>
                <p>Quoted, with section numbers, because three of these four rows are places a first draft of this course was wrong:</p>
                <div class="hex-dump">
                <pre>AAPCS64 6.1.1  Registers r19-r29 and SP are Callee-saved.  All
          64 bits of each value stored in r19-r29 are
          Callee-saved.

        6.1.2  Registers v8-v15 are Callee-saved and the
          remaining registers (v0-v7, v16-v31) are
          Caller-saved.  Additionally, only the bottom 64
          bits of each value stored in v8-v15 need to be
          Callee-saved; it is the responsibility of the
          caller to preserve larger values.

        5.1.1  The role of register r18 is platform specific.
          If a platform ABI has need of a dedicated
          general-purpose register to carry inter-procedural
          state then it should use this register for that
          purpose.  If the platform ABI has no such
          requirements, then it should use r18 as an
          additional Caller-saved register.

        5.1.1  The N, Z, C and V flags are undefined on entry
          to and return from a public interface.
                </pre>
                </div>
                <p>Four rows and four different things, so read them one at a time.</p>
                <ul>
                    <li><strong><code>x19</code>&ndash;<code>x28</code>, plus <code>x29</code>, <code>x30</code> and <code>SP</code> &mdash; all 64 bits.</strong> Six rows collapsed into one, and the &ldquo;all 64 bits&rdquo; is not decoration: it is what separates this from the vector row, which is a half-clause. Note also that <code>SP</code> is in the list, which is why <a href="/courses/a64abi/lessons/a64-frame">concept 3</a>'s <code>add sp, sp, #48</code> is a <em>restoration</em> and not a detail.</li>
                    <li><strong><code>v8</code>&ndash;<code>v15</code> &mdash; and ONLY THE BOTTOM 64 BITS of each.</strong> This is the row that gets dropped, and dropping it changes what you expect to see in a disassembly. <strong>It is not that <code>v8</code>&ndash;<code>v15</code> must be preserved; it is that the top 64 bits of them are the CALLER'S problem.</strong> A compiler that saves <code>q8</code> when it only needed <code>d8</code> has obeyed the standard and wasted a store, and a compiler that saves <code>d8</code> when it needed <code>q8</code> has broken it. The clause is a permission and an obligation at once, and it is the only place in the AAPCS64 where a register is <em>partly</em> callee-saved.</li>
                    <li><strong><code>r18</code> is platform specific</strong> &mdash; the standard does not say what it is, it says the <em>platform ABI specification</em> must say. And it gives the platform the choice: a dedicated register for inter-procedural state, or an additional caller-saved temporary. <strong>On Linux, the platform ABI specification does not reserve it, so it is an ordinary caller-saved temporary.</strong> The two clauses are not alternatives in the abstract; they are a decision the platform makes, and this course's platform made the second one.</li>
                    <li><strong><code>NZCV</code> is UNDEFINED across a public interface.</strong> Undefined is not &ldquo;preserved&rdquo; and not &ldquo;destroyed&rdquo;: a callee may leave the flags in any state, and a caller may not read them across a call. Three words, and all three matter.</li>
                </ul>
                <p>And a row that is <strong>not</strong> in the document and that everybody quotes anyway: <strong>there is no flag register to save.</strong> More on that below, because the measurable consequence of the difference between <em>undefined</em> and <em>preserved</em> is a count of zero, and a course that asserted a cost without printing the zero would be describing an optimisation rather than a fact.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What the compiler actually did, and the count that is arithmetic</h2>
                <p>The corpus has two functions built specifically to force this question. <code>many</code> keeps twelve values live across twelve calls; <code>fmany</code> keeps ten doubles live across ten calls. <strong>Neither can keep them in the caller-saved temporaries</strong>, and the only way to find out what a compiler does when it has to reach further down the file is to write one that has to.</p>
                <div class="hex-dump">
                <pre>$ python3 a64abi.py --run | sed -n '/O0   many   gpr:/,/Os   fmany/p'
  O0   many   gpr: saved none        restored none
  O0   fmany  gpr: saved none        restored none
  O1   many   gpr: saved x19-x28     restored x19-x28
  O1   fmany  gpr: saved none        restored none   |  fp: saved d8-d15   restored d8-d15
  O2   many   gpr: saved x19-x28     restored x19-x28
  O2   fmany  gpr: saved none        restored none   |  fp: saved d8-d15   restored d8-d15
  Os   many   gpr: saved x19-x28     restored x19-x28
  Os   fmany  gpr: saved none        restored none   |  fp: saved d8-d15   restored d8-d15
                </pre>
                </div>
                <p>Two rows are the whole concept, so read them carefully.</p>
                <p><strong><code>many</code> at -O2 saves <code>x19</code>&ndash;<code>x28</code> &mdash; all ten &mdash; in five <code>stp</code> pairs, and restores them in five <code>ldp</code> pairs.</strong> Twenty instructions, ten of them pairs, to hold twelve values across twelve calls. And the reason it needs ten callee-saved registers is <strong>a count and not a preference</strong>:</p>
                <div class="formula">
   WHY x19-x28 AND NOT x19-x21

   caller-saved temporaries in the integer bank   7   (x9-x15)
   values that must survive a call                 12
                                                   --
   have nowhere else to live                        5

   x19-x28 is not a set of ten CHOSEN registers.
   It is what is LEFT.  The five it could not avoid
   saving happened to be the first five of the
   callee-saved range, and the other five are free.
                </div>
                <p>That is the useful thing about the count: it says the callee-saved registers exist to absorb an <strong>overcommitment</strong>, and it predicts what a function with seventeen live values across a call would do &mdash; save ten callee-saved registers <em>and</em> spill two to the stack, because there are only ten. A reader who thinks of <code>x19</code>&ndash;<code>x28</code> as ten preferred temporaries will predict wrong in both directions.</p>
                <p><strong>And <code>fmany</code> saves <code>d8</code>&ndash;<code>d15</code> &mdash; the 64-bit view, not <code>q8</code>&ndash;<code>q15</code>.</strong> The compiler obeyed the &ldquo;bottom 64 bits&rdquo; rule <em>exactly</em>. A reader who assumed it would save 128-bit registers would read the disassembly and conclude the compiler had made an error &mdash; and the error would be in the reading, not in the code. <strong>This is the one place in the whole course where doing less work is the correct behaviour, and it is invisible in the disassembly except as the absence of a wider instruction.</strong></p>
                <h3>Two counts of zero, which are also rules</h3>
                <p><strong>The platform register.</strong> The plan for this course said <code>r18</code> &ldquo;is preserved only across a call that uses the stack &mdash; measure how often the compiler saves it.&rdquo; The measurement is the way to find out, and it is this:</p>
                <div class="hex-dump">
                <pre>$ python3 a64abi.py --run | sed -n '/THE PLATFORM REGISTER/,/^$/p'
  [MEASURED]  Occurrences of w18/x18 in the whole corpus at all four
  levels: 0.
                </pre>
                </div>
                <p>Zero. Not because the compiler is lazy, but because <strong>there is nothing to save</strong>. Linux does not reserve <code>x18</code>, so the AAPCS64's second clause applies: it is an additional caller-saved temporary, and a caller-saved temporary is not saved by anybody. <strong>A conditional rule that a compiler never implements is indistinguishable from a rule that does not exist, and the measurement is the only thing that tells them apart.</strong> The rule in the plan is an AArch32 and Windows x86-64 idea: on 32-bit Arm, <code>r13</code> is the platform register and software that uses it must save it around a call that might touch the stack, and on Windows x64 the thread information block lives in the <code>GS</code> segment rather than in a register at all. <strong>Retraction R5, and it is retracted rather than softened.</strong></p>
                <p><strong>The flags.</strong> The AAPCS64 says <code>NZCV</code> is undefined across a public interface, and:</p>
                <div class="hex-dump">
                <pre>$ python3 a64abi.py --run | sed -n '/THE FLAG REGISTER, OR THE ABSENCE/,/^$/p'
  [MEASURED]  mrs/msr of a flag register in the corpus: 0.  There
  are none, and there is no assembly mnemonic for "save the
  flags" on this architecture, because the flags live in no
  register that a normal instruction can name.  x86-64's answer
  is PUSHFQ, one instruction that writes 8 bytes onto the
  stack, and the x86abi course counted 271 of them in 94
  functions.  AArch64's answer is that there is nothing to
  count: the flags are a side effect of a bit in an
  instruction, and the sentence that makes them not your
  problem is a sentence rather than a store.
                </pre>
                </div>
                <p>Read that last sentence twice, because it is the difference between an ABI and a habit. <strong>On x86-64 the flags are a register, so preserving them is a memory operation a compiler emits and a reader can count.</strong> On AArch64 the flags are a side effect of a bit in the instruction word &mdash; the <code>S</code> and <code>C</code> bits of the condition field, which is <a href="/courses/a64asm/lessons/a64-encoding">bits[15:12] in a data-processing instruction</a> and nowhere else &mdash; so there is nothing to save and no instruction to save it with. <strong>The measurable consequence is a count of zero, and a course that asserted a cost without printing the zero would be describing an optimisation rather than a fact.</strong> That is retraction R6.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the range that was wrong, and what it would have forced</h2>
                <p>The plan for this course said the AAPCS64 preserves the lower 64 bits of <code>v0</code>&ndash;<code>v7</code>. It preserves the lower 64 bits of <code>v8</code>&ndash;<code>v15</code>. This is retraction R4, and it is worth dwelling on because <strong>the consequence is not a detail</strong>:</p>
                <ul>
                    <li><strong><code>v0</code>&ndash;<code>v7</code> are the argument and result registers.</strong> <a href="/courses/a64abi/lessons/a64-aapcs">Concept 1</a> measured it: a <code>double</code> argument arrives in <code>d0</code>&ndash;<code>d7</code>, and so does a <code>double</code> result. They are <em>entirely</em> caller-saved.</li>
                    <li><strong>So a course that got the range wrong would have had to explain a callee saving the registers its own arguments just arrived in</strong> &mdash; which is not a rule, it is a contradiction. There is no reading of a consistent ABI in which the register a double argument arrives in must survive the call.</li>
                    <li><strong>And the vector callee-saved range is <em>only</em> eight registers wide</strong>, <code>v8</code>&ndash;<code>v15</code>, against thirty-two in the whole file. There are no <code>v18</code>&ndash;<code>v31</code> callee-saved registers, and the reason is a count: <code>fmany</code> keeps ten doubles live across ten calls and saves eight of them, so the two that do not fit have to go somewhere else &mdash; and there is nowhere else in the vector bank, so they are recomputed or spilled.</li>
                </ul>
                <p>The pattern across all four rows of the model is worth stating once, because it is the thing a reader should carry out of this page: <strong>on this architecture almost nothing is callee-saved, and every one of the exceptions is a place where the cost is paid by a <em>pair</em> of instructions and a stack slot.</strong> Ten general registers and eight vector registers out of 64, plus the stack pointer, the link register and the frame pointer. Everything else is a temporary you are free to destroy, and the price of the arrangement is that a function with a lot of live state pays for a save area whether it wants to or not.</p>
                <p>Now the practical consequence, which is the reason a backend author reads this page. To preserve a caller-saved value across a call, a compiler must either <strong>spill it to its own frame</strong> &mdash; and on AArch64 <a href="/courses/a64abi/lessons/a64-frame">a frame is a request, so the request is made once and can hold all of them</a> &mdash; or <strong>move it to a callee-saved register</strong>, which costs the pair of instructions. There is no third option, and there is no red zone to spill into for free. A compiler that chose spill-always would be correct and would pay for a frame in every function; a compiler that chose callee-saved-always would be correct and would spend twenty instructions in <code>many</code>. <strong><code>many</code> did the second at -O2 and the first at -O0, and the difference in instruction count is 84 to 67 in the other direction</strong> &mdash; at -O0 clang spilled everything and needed no callee-saved registers at all, and at -O2 it used the registers and needed no spills.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Count the saves, and check the width.</strong> Compile a C function with a loop whose body is a call and whose accumulator is a <code>double</code> and a <code>long</code>, for <code>aarch64-linux-gnu</code> at <code>-O2</code>. <em>(Expect it to reach for <code>d8</code>&ndash;<code>d15</code> and <code>x19</code>&ndash;<code>x28</code>, and expect the vector saves to be <code>d</code>-width and not <code>q</code>-width. If they are <code>q</code>-width, look again &mdash; the compiler may have a live 128-bit value, and the way to tell is whether anything writes the top half. A <code>q</code> save where only a <code>d</code> is live is a wasted store, and a <code>d</code> save where a <code>q</code> is live is a bug.)</em></li>
                    <li><strong>Write a function that would need a seventeenth callee-saved register.</strong> Seventeen values of type <code>long</code> live across a call. <em>(Expect: ten registers saved, the rest spilled to the frame, and a frame that is a multiple of 16 because of the spill slots and not because of the call. Now count the caller-saved temporaries the same function uses &mdash; seven, <code>x9</code>&ndash;<code>x15</code> &mdash; and check the arithmetic in the box above. The number <em>is</em> the rule.)</em></li>
                    <li><strong>Ask the assembler about the two registers that are not what they look like.</strong> <em>(Expect <code>x18</code> to assemble and to behave as an ordinary caller-saved temporary on Linux: put a value in it, make a call, and read it back in hand-written assembly, and it will not survive, which is legal and is the point. And expect there to be no mnemonic for the flags at all &mdash; there is no <code>pushfq</code> equivalent, and searching the assembler for one is a five-minute experiment that ends in a diagnostic. <a href="/courses/x86abi/lessons/x86-saved">The x86-64 saved-registers concept</a> is the direct contrast, and it counts 271 <code>PUSHFQ</code> across a corpus.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, both neighbours. <a href="/courses/a64abi/lessons/a64-frame">Concept 3</a> is where the frame this page fills is created, and the <code>stp x29, x30</code> that saves the frame record is itself an instance of the rule on this page &mdash; <code>x29</code> and <code>x30</code> are callee-saved, so they are saved in a pair and restored in a pair, and that is the only reason the prologue has the shape it has. <a href="/courses/a64abi/lessons/a64-registers">Concept 2</a> is where <code>x29</code> and <code>x30</code> stop being letters: <code>29</code> and <code>30</code> are numbers in five-bit fields, and the AAPCS64 gives them names (<code>FP</code> and <code>LR</code>) in the same document that gives <code>sp</code> a name.</p>
                <p>Sideways, and this is the sibling reference: <a href="/courses/x86abi/lessons/x86-saved">The x86-64 saved registers</a> has the same bargain with a different partition &mdash; six GPRs and sixteen XMM against ten and eight, and a flags register that must be pushed. <a href="/courses/sec/lessons/sec-canary">The stack canary</a> is a value in the frame for the same reason all of this exists: it must survive a call, and a frame is the only region of memory the ABI promises will. <a href="/courses/dyn/lessons/dyn-order-runtime">The dynamic-linking course</a> is where the loader's own frame sits, and it is a frame like any other, built by the same rules, and it is the reason a program starts with a stack at all.</p>
                <p>Forwards, one concept, and it is the one that uses everything above. <a href="/courses/a64abi/lessons/a64-unwind">Concept 5</a> is about the second description of a frame &mdash; and <strong>the callee-saved registers are exactly what a second description has to record</strong>. <code>many</code> at -O2 holds the same four CFI rows as at -O0 and its table grows from 40 to 64 bytes, because the unwind table has to say where twelve saved registers are, and there is no <code>PUSHFQ</code>-shaped shortcut for a register the architecture does not let you name.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/a64abi/lessons/a64-frame">No Red Zone, and the Two Instructions That Is Worth</a></span>
                <span>Next: <a href="/courses/a64abi/lessons/a64-unwind">The Frame in a Second Language, and the Shape That Was Not There</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
