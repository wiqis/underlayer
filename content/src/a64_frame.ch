// The AArch64 Procedure Call Standard -- Concept 3: the frame.
// AAPCS64 5.2.2.1 calls the region below SP the inactive region, so every
// function that wants memory must ask -- and the asking is two instructions.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_frame() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("No Red Zone, and the Two Instructions That Is Worth — Underlayer")
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
            <h1>No Red Zone, and the Two Instructions That Is Worth</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/a64abi">The AArch64 Procedure Call Standard</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p><a href="/courses/x86abi/lessons/x86-frame">The x86-64 frame concept</a> has a surprise in it, and if you have read that course you already know the shape of this one. On x86-64 a function can put a local in the 128 bytes <em>below</em> the stack pointer without moving the stack pointer at all, because the System V ABI promises that an interrupt will not touch those bytes. The region is called the <strong>red zone</strong>. A leaf function with three locals on x86-64 is <strong>8 instructions and does not move <code>%rsp</code> once</strong>.</p>
                <p>AArch64 has no such promise, and the standard does not merely omit it &mdash; it says the opposite, in the same section that states the alignment rule:</p>
                <div class="hex-dump">
                <pre>AAPCS64 5.2.2.1  Universal stack constraints, at all times
        during the execution of a thread T:

          - No thread is permitted to access (for reading or for
            writing) the inactive region of S.

        and, two bullets later, the alignment rule that every
        other concept in this course depends on:

          - SP mod 16 = 0.  The stack must be quad-word aligned.

        ... where the inactive region of T's stack is the area of
        memory denoted by the half-open interval [T.limit, T.SP).
                </pre>
                </div>
                <p><strong>Accessing it is forbidden, not merely unwise</strong> &mdash; and the sentence is in the same list as the alignment rule, which is the section that defines what a stack pointer owes the rest of the system. So there is no region of memory a function may use without first telling the world it is using it, and the way you tell the world is by moving the stack pointer.</p>
                <p>That is not a small inconvenience and it is not a style preference. It is the reason the prologue of essentially every AArch64 function that has locals is two instructions longer than the x86-64 equivalent, and it is measurable in a corpus, at four optimisation levels, with no clock involved. This concept is the measurement.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: the frame is a request, and a request is visible</h2>
                <p>Think of the stack pointer as a <em>published fact</em>. Other code can read it, and an interrupt handler will use it to find your locals. AArch64's rule is: <strong>everything at or above SP is yours and is described; everything below SP belongs to somebody else.</strong> So to get memory you must move SP down, which is a <em>publication</em>, and to give it back you must move SP up, which is a retraction of the publication.</p>
                <p>And the prologue has to be a <strong>linked list</strong>, because the AAPCS64 mandates it in &sect;5.2.3:</p>
                <div class="hex-dump">
                <pre>AAPCS64 5.2.3  Conforming code shall construct a linked list of
        stack-frames. Each frame shall link to the frame of its
        caller by means of a frame record of two 64-bit values
        on the stack (independent of the data model).  The frame
        record for the innermost frame (belonging to the most
        recent routine invocation) shall be pointed to by the
        frame pointer register (FP).  The lowest addressed
        double-word shall point to the previous frame record and
        the highest addressed double-word shall contain the value
        passed in LR on entry to the current function.

        ... and in the register table, 5.2.3's own FP:
           | r30 | LR | The Link Register.
           | r29 | FP | The Frame Pointer
           | r19...r28  |   | Callee-saved
                </pre>
                </div>
                <p>Three claims in one sentence, and each one is a design decision rather than a convenience. <strong>The frame is a linked list</strong>, so it can be walked by arithmetic instead of being searched. <strong>The record is two 64-bit values, ordered</strong> &mdash; the lowest address holds the previous frame record and the highest holds the return address from <code>LR</code> &mdash; so the order of a <code>stp</code> is not arbitrary. And <strong>the standard names the register</strong>: <code>r29</code> is <code>FP</code> and <code>r30</code> is <code>LR</code>, which is why the prologue below can be written without a comment and a reader can look up whether the compiler kept the promise. Here is the whole of it, in the disassembly of one function:</p>
                <div class="hex-dump">
                <pre>$ llvm-objdump-21 --triple=aarch64 -d abi_O0.o | sed -n '/&lt;nonleaf&gt;/,/ret/p'
  sub sp, sp, #48          &mdash; the request
  stp x29, x30, [sp, #32]  &mdash; the frame record, two 64-bit values
  add x29, sp, #32         &mdash; and the link to the caller's frame
  stur x0, [x29, #-8]
  str x1, [sp, #16]
  ...
  ldp x29, x30, [sp, #32]  &mdash; the frame record read back
  add sp, sp, #48          &mdash; the retraction
  ret
                </pre>
                </div>
                <p>Read the four marked lines as four obligations, and notice that <strong>all four are required and none of them is an optimisation decision</strong>:</p>
                <ol>
                    <li><strong>Allocate.</strong> <code>48</code> is a multiple of 16 because of <a href="/courses/a64abi/lessons/a64-aapcs">concept 1</a>. It is also a multiple of 8, which is what <code>x29</code> needs to be 8-aligned, and a multiple of 16, which is what the <code>q</code> registers need.</li>
                    <li><strong>Save the frame record.</strong> <code>x29</code> and <code>x30</code>, together, in one instruction. This is the AAPCS64's frame record and it is not optional: a function that does not save it cannot be walked.</li>
                    <li><strong>Point <code>x29</code> at it.</strong> <code>add x29, sp, #32</code> &mdash; <code>x29</code> is the frame pointer, and this instruction is what makes the frame a <em>record</em> rather than a region.</li>
                    <li><strong>Restore both.</strong> <code>ldp x29, x30, [sp, #32]</code> then <code>add sp, sp, #48</code>. Note the order: the frame record must be read <em>before</em> the retraction, because it lives in the region being retracted.</li>
                </ol>
                <p>And the part that has no analogue on x86-64: <code>add x29, sp, #32</code> points <em>into the middle of</em> the frame, not at the top of it. On x86-64 the frame pointer is set to the frame's <em>base</em> and the saved return address is at <code>0(%rbp)</code> and everything else is at negative offsets. Here the frame record is at <code>+32</code> inside a 48-byte frame and the locals are at negative offsets from it. <strong>Both conventions work; they put the number 32 and the sign the other way round, which is why a reader porting a stack-walking habit between them gets subtly wrong answers for a long time.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>The census: 25 of 25, then 14 of 25, against x86-64's 7 and then 5</h2>
                <p>The frame census is the count of who <em>asked</em>. Twenty-five functions, four optimisation levels, and the same C compiled for both targets. A pre-indexed <code>[sp, #-N]!</code> counts as an allocation, because it <strong>is</strong> one &mdash; a count of <code>sub sp, sp, #N</code> alone misses every function that fused the allocation into a save.</p>
                <div class="hex-dump">
                <pre>$ python3 a64abi.py --run | sed -n '/O0   25 of 25/,/Os   14 of 25/p'
  O0   25 of 25 functions allocate a frame at all.
  O1   14 of 25 functions allocate a frame at all.
  O2   14 of 25 functions allocate a frame at all.
  Os   14 of 25 functions allocate a frame at all.
                </pre>
                </div>
                <p>And the same number for the same C on x86-64, with the set difference, because a count of two overlapping sets is the least informative thing a reader can be handed:</p>
                <div class="hex-dump">
                <pre>  level    a64: with a frame   x86: with a frame   a64 mean   x86 mean
  O0       25 of 25              7 of 25            63 bytes    67 bytes
  O1       14 of 25              5 of 25            55 bytes    56 bytes
  O2       14 of 25              5 of 25            55 bytes    56 bytes
  Os       14 of 25              5 of 25            55 bytes    54 bytes

  O2   a64 only: big_frame cd9 inner leaf_spill leaf_vec many
                 nonleaf use_ret use_retd
       x86 only: (none)                    both: 5
                </pre>
                </div>
                <p><strong>&ldquo;x86 only: (none)&rdquo; is the finding.</strong> There is no function in this corpus that x86-64 frames and AArch64 does not. At -O0 the counts are 25 against 7, and at every level above it 14 against 5 &mdash; and <strong>the nine extra are exactly the ones whose C asks for memory that does not fit in a register</strong>: a <code>volatile</code> local, a <code>volatile</code> array, a value that must survive a call. On x86-64 those go into the 128 bytes below SP and cost nothing at all. Here they cost a <code>sub</code> and an <code>add</code>.</p>
                <p>Two rows in the artifact's per-function table are worth reading, because they explain why the -O0 number is the surprising one rather than the -O2 number:</p>
                <ul>
                    <li><strong><code>leaf_reg</code> at -O2 is four instructions with no <code>sub sp</code> at all.</strong> A leaf that needs no memory frames nothing, on either architecture. The red zone is irrelevant to it because it never wanted anything.</li>
                    <li><strong><code>leaf_spill</code> at -O2 is a LEAF that has to allocate</strong>, because it has three <code>volatile</code> locals and there is nowhere else for them to go. <strong>On x86-64 the same function at the same level is ten instructions and allocates NOTHING.</strong> This is the entire concept in one pair of rows: a leaf with locals is free on one architecture and costs two instructions on the other, and the difference is a region of memory 128 bytes wide that one ABI promises and the other forbids.</li>
                </ul>
                <h3>The same function, hand-written, so it cannot be blamed on the compiler</h3>
                <p>Hand-translated to be the same C, so the difference is the architecture and not clang's mood:</p>
                <div class="hex-dump">
                <pre>  AArch64  a64_leaf_noframe          3 instructions, 0 touch SP
      mul x8, x1, x0 ;  madd x0, x0, x8, x8 ;  ret

    AArch64  a64_leaf_frame          11 instructions, 8 touch SP
      sub sp, sp, #0x10              &lt;-- the request
      str x0, [sp, #0x8]
      str x1, [sp]
      ldr x8, [sp, #0x8]
      ldr x9, [sp]
      add x8, x8, x9
      ldr x0, [sp, #0x8]
      ldr x9, [sp]
      add x0, x8, x9
      add sp, sp, #0x10              &lt;-- the retraction
      ret

  x86-64   x86_leaf_noframe          3 instructions, 0 touch SP
      imulq %rsi, %rax ;  addq %rdi, %rax ;  retq

    x86-64   x86_leaf_frame           8 instructions, 6 touch SP
      movq %rdi, -0x8(%rsp)          &lt;-- -8(%rsp) is in the red zone
      movq %rsi, -0x10(%rsp)         &lt;-- -16(%rsp) is too
      movq -0x8(%rsp), %rax
      addq -0x10(%rsp), %rax
      movq -0x8(%rsp), %rcx
      addq -0x10(%rsp), %rcx
      addq %rcx, %rax
      retq                          <-- %rsp NEVER MOVES
                </pre>
                </div>
                <p><strong>Three instructions with no frame, on both. Eight on x86-64 with a frame and no <code>%rsp</code> movement. Eleven on AArch64 with a frame and a <code>sub</code> and an <code>add</code>.</strong> That is the whole cost of having no red zone, and it is <strong>two instructions in every function that has locals</strong> &mdash; which is every function that is not a leaf of pure arithmetic.</p>
                <p>Note the six x86-64 instructions that &ldquo;touch the stack&rdquo; and the fact that <em>none of them moves the stack pointer</em>. <strong>The count of instructions that touch the stack and the count that allocate a frame are different questions</strong>, and this corpus contains a row that answers both: AArch64 11 instructions with 8 touching the stack, x86-64 8 instructions with 6 touching it, and the 2-instruction gap is exactly the pair of <code>sp</code> movements.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the five ways to move SP, and the four that hide</h2>
                <p>This is the trap that produced a wrong number in the first version of this course's own census, so it gets its own table. Five forms, and <strong>four of them do two jobs in one instruction</strong>:</p>
                <div class="hex-dump">
                <pre>$ python3 a64abi.py --run | sed -n '/THE ONE FORM THAT HIDES/,/misses all four/p'
  form                     reads and writes           allocates
  stp x29, x30, [sp, #-16]! two registers, and SP      0xa9bf7bfd
  str x0, [sp, #-16]!      one register, and SP         0xf81f0fe0
  ldr x0, [sp], #16        one register, and SP         0xf84107e0
  ldp x29, x30, [sp], #16  two registers, and SP       0xa8c17bfd
  sub sp, sp, #16          nothing but SP               0xd10043ff

  [MEASURED-ON-BYTES]  Four of those five are ONE instruction that does
  two jobs, and a frame counter that only counts `sub sp` misses all
  four.  This is x86-64's `leave` in a different costume: x86 needs a
  separate `movq %rsp, %rbp; popq %rbp` to undo the frame, and AArch64
  folds the deallocation into the last load.
                </pre>
                </div>
                <p>The <code>!</code> is the <strong>pre-index</strong> form: writeback, so the address is computed, the access happens, <em>and</em> SP is updated. The <code>[sp], #16</code> with no <code>!</code> is the <strong>post-index</strong> form: the access happens at the current SP, <em>then</em> SP is updated. Between them they cover the entire lifecycle of a frame in four instructions &mdash; allocate, save, load-and-retract, pop.</p>
                <p>Read the first row carefully, because it is the canonical AArch64 prologue and it looks like a stack-allocated pair: <code>stp x29, x30, [sp, #-16]!</code> is <code>0xa9bf7bfd</code>, and it does <strong>three</strong> things at once &mdash; allocate 16 bytes, save the old frame pointer, and save the return address. A reader counting &ldquo;does this function allocate a frame&rdquo; by looking for <code>sub sp</code> finds nothing here, and a reader counting &ldquo;how many registers does this function save&rdquo; finds two and does not notice the allocation.</p>
                <p>The mistake this course actually made is worth printing because it is the ordinary kind. The first version of the frame census counted <code>sub sp, sp, #N</code> and <code>add sp, sp, #N</code> only, and reported <strong>nine functions with no deallocation at -O2</strong>. Three of those nine were deallocating by folding the addition into the last load &mdash; <code>ldr x0, [sp], #16</code>. So the table said the compiler had <em>leaked nine frames</em>, which is a spectacular claim to make about a compiler, and the reason it is worth printing is that <strong>nine is exactly the number of functions that take a frame at all.</strong> When a census produces a number equal to another number in the same file, stop and check the census.</p>
                <h3>What cannot be measured here</h3>
                <p>Everything on this page is a <em>count</em>, not a duration. There is no AArch64 machine on the build host, no emulator and no linker, so not one instruction in this course has been run. The frame census is arithmetic over instructions a compiler emitted; the hand-written comparison is a disassembly of code nobody executed. <strong>Whether a <code>stp</code>/<code>ldp</code> pair is cheaper than two <code>str</code>s, and whether a real <code>sub sp</code> is cheaper than a fused one, are questions this course cannot answer and does not pretend to.</strong> <a href="/courses/x86abi/lessons/x86-verify">The x86-64 ABI course</a> measured what it could and named the rest; the same discipline, one architecture over, produces a page that has a <code>ret</code> in it and no cycle.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Count allocations correctly, and find the fused ones.</strong> Compile a C file with three or four leaf functions at <code>-O2</code> for <code>aarch64-linux-gnu</code> and look for <code>sp</code> in <em>every</em> instruction, not just <code>sub sp</code>. <em>(Expect the common prologue to be <code>stp x29, x30, [sp, #-N]!</code> &mdash; allocate, save the record, in one instruction with a writeback &mdash; and the common epilogue to be <code>ldp x29, x30, [sp], #N</code> followed by <code>ret</code>, where the deallocation is inside the load. Then compile the same file for x86-64 and check whether <code>%rsp</code> moves in a leaf with a <code>volatile</code> local. It does not.)</em></li>
                    <li><strong>Write a leaf function with a <code>volatile</code> local and count the difference yourself.</strong> <em>(Expect two extra instructions and a frame on AArch64, zero extra on x86-64. Then make the local non-<code>volatile</code> and watch the AArch64 frame disappear as well &mdash; which tells you the frame is a consequence of the <em>register pressure</em>, not of the syntax, and that a red zone would have absorbed the same pressure for free.)</em></li>
                    <li><strong>Break the frame record and see what it costs.</strong> Write assembly that allocates a frame with <code>sub sp, sp, #32</code> but never stores <code>x29</code>/<code>x30</code>. <em>(Expect: the function works, and nothing at all happens &mdash; no diagnostic, no crash, no warning. Then read it with <code>gdb</code> and with a <code>backtrace</code> and notice that the two disagree, and that the disagreement starts at your frame. That is the whole argument for AAPCS64 &sect;5.2.3 in one experiment, and it is the subject of <a href="/courses/a64abi/lessons/a64-unwind">the last concept</a>.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, one concept and one tool. <a href="/courses/a64abi/lessons/a64-registers">Concept 2</a> is where 31-as-<code>sp</code> was measured, and it is the number this page moves: every <code>sub sp</code> and <code>add sp</code> in this concept is an instruction whose <code>Rd</code> field means the stack pointer rather than a register. And the 16-byte frame size is not a preference &mdash; it is <a href="/courses/a64abi/lessons/a64-aapcs">concept 1</a>'s rule, and this page is where the two meet: <strong>a frame size that is not a multiple of 16 is not a smaller frame, it is an ABI violation in the prologue of a function that was called correctly.</strong></p>
                <p>Sideways, and this is the sharpest contrast in the whole section: <a href="/courses/x86abi/lessons/x86-frame">The x86-64 frame</a> has the red zone, measured by <em>clobbering</em> it. That course could deliver a <code>SIGSEGV</code>; this one has no machine to fault on. <a href="/courses/sec/lessons/sec-canary">The stack canary</a> is a value in this frame, and the reason it needs a frame at all is the reason this page exists &mdash; on x86-64 a canary could in principle have lived in the red zone. <a href="/courses/dyn/lessons/dyn-order-runtime">The dynamic-linking course</a> is where the stack is first set up, and the frames you have been reading about are stacked on top of a region it owns.</p>
                <p>Forwards. <a href="/courses/a64abi/lessons/a64-save">Concept 4</a> is the other half of the frame's contents: who has to save <em>which</em> registers, and the two counts of zero that are also rules. <a href="/courses/a64abi/lessons/a64-unwind">Concept 5</a> is what a frame looks like to something that was not there when it ran &mdash; and it is the concept where the ratio between the instructions and their description is the measurement, so read this page's four marked prologue lines and then read that page's two columns and notice they are the same four lines.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/a64abi/lessons/a64-registers">One Register, Two Names, and Three Things Called 31</a></span>
                <span>Next: <a href="/courses/a64abi/lessons/a64-save">Callee-Saved, and the Count of Zero That Is Also a Rule</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
