// The x86-64 ABI — Concept 2: the stack frame, alignment and the red zone
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_frame() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Stack Frame, the Red Zone, and Two Rules — Underlayer")
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
            <h1>The Stack Frame, the Red Zone, and Two Rules</h1>
            <div class="lesson-meta">26 min &middot; <a href="/courses/x86abi">The x86-64 ABI</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Every call on x86-64 changes the stack pointer by 8 bytes and then requires the stack pointer to be in a particular state. That is the whole of the frame. There is no frame descriptor, no link register, no callee-saved stack pointer, and no implicit &ldquo;push the arguments&rdquo; pass &mdash; all of which is exactly the machinery the 32-bit x86 conventions had, and all of which a reader who learned calling conventions on another architecture will be looking for and not finding.</p>
                <p>Two rules live in those 8 bytes, and both of them are narrower than the slogans usually attached to them.</p>
                <ul>
                    <li><strong>The alignment rule is 16 bytes, and a <code>call</code> and a tail <code>jmp</code> want OPPOSITE adjustments.</strong> Not a subtlety: the same <code>jmp</code> with the canonical <code>subq $8, %rsp</code> in front of it is not a misaligned tail call, it is a dead process.</li>
                    <li><strong>The red zone is 128 bytes, and the first 8 of them are the return-address slot.</strong> The 128 is a real number and the restriction that goes with it is not a style guideline. A function that uses the red zone and then makes a call has had a variable overwritten by the return address, and you can read the return address back out of the variable.</li>
                </ul>
                <p>And the reason for the alignment rule is not the one most people carry. It is not a penalty. <a href="/courses/simd/lessons/simd-width">The vector course's width concept</a> measured unaligned accesses on this machine and found them free, so a rule that exists for a penalty cannot be the rule on this silicon. The reason is a fault, and it is three instructions to demonstrate.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: one push, and everything that follows from it</h2>
                <p>Start from the only fact. A <code>call</code> decrements <code>%rsp</code> by 8 and writes the return address at the new <code>%rsp</code>. Everything in this concept is a consequence of that one behaviour, and the consequence you must hold on to is:</p>
                <div class="formula">
   AT A CALLEE'S FIRST INSTRUCTION, %rsp IS 8 (mod 16).

   Not 0.  Eight.  Because 8 bytes were just pushed.

   And it is 8 (mod 16) IF AND ONLY IF the caller kept %rsp
   16-byte aligned at the `call`.  So the caller's obligation,
   stated as a value rather than as a slogan, is:

        %rsp must be 16-byte aligned AT THE `call`,

   which -- because the `call` will push 8 -- is the same
   sentence as "leave %rsp 8 (mod 16) everywhere else".
                </div>
                <p>That is why the idiom you see in every prologue looks the way it does. A function with a frame needs a 16-byte-aligned outgoing argument area, and the area is at <code>%rsp</code>, so it must move <code>%rsp</code> by a multiple of 16 &mdash; and the <em>canonical</em> sequence for an 8-byte outgoing argument is the one line that looks like a mistake:</p>
                <div class="hex-dump">
                <pre>        subq    $8, %rsp          # the ABI's own idiom, for EIGHT bytes
        movq    %rdi, (%rsp)       # of outgoing argument area
        call    some_function
        addq    $8, %rsp
  </pre>
                </div>
                <p>Eight bytes of outgoing area requires eight bytes of stack, and eight bytes of stack is not 16-byte aligned unless the <code>%rsp</code> was 8 (mod 16) beforehand &mdash; which it is, because that is where a function's <code>%rsp</code> sits. The <code>subq $8, %rsp</code> is not padding. It is the difference between the callee's first instruction seeing a 16-byte-aligned address and not seeing one.</p>
                <p>And here is the measurement, which is the only way to know that any of this matters:</p>
                <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/THE ALIGNMENT FAULT/,/^  THIS IS NOT/p'
  %rsp mod 16 at a callee's first instruction, four ways in:
    a `call`, %rsp 16-aligned at the call (the rule)         8
    a `call`, the `subq $8,%rsp` deleted                      0
    a TAIL `jmp`, no adjustment at all                       8
    a tail `jmp` after `subq $8,%rsp`                        0
    and that adjustment, left in place, kills the process: KILLED by a signal, because the return address is not where `ret` looks for it

  one callee, three arms.  It is EXACTLY the prologue gcc -O0 emits:
  `pushq %rbp; movq %rsp,%rbp; subq $32,%rsp` and a 16-byte
  vector local at -16(%rbp), which is 16-byte aligned iff %rbp is,
  and %rbp is the CALLER's %rsp minus 8.

    movaps 16-byte store, CONFORMING call  -> returned, and the value read back was 0x3ff8000000000000
    movaps 16-byte store, VIOLATING call   -> KILLED by a signal
      signal 11, and 11 is SIGSEGV
    movups 16-byte store, VIOLATING call   -> returned, and the value read back was 0x3ff8000000000000
  </pre>
                </div>
                <p>Three arms, one callee, and the callee is not a contrivance: it is the prologue <code>gcc -O0</code> emits, with a 16-byte vector local at <code>-16(%rbp)</code>. Read the chain: <code>%rbp</code> is the caller's <code>%rsp</code> minus 8, so <code>%rbp</code> is 16-byte aligned exactly when the caller's <code>%rsp</code> was, so <code>-16(%rbp)</code> is 16-byte aligned exactly when the caller kept the rule. <strong>Delete one <code>subq $8, %rsp</code> in the caller and the callee dies on a legal instruction.</strong></p>
                <p>And the third arm is the one that makes it a fault rather than a penalty. <code>movups</code> is the <em>same store</em>, at the <em>same address</em>, through the <em>same misaligned call</em>, and it returns having read back the value that was stored. The difference between the two arms is one letter in a mnemonic and the difference between the two outcomes is a signal.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: the red zone, and the eight bytes that are not yours</h2>
                <p>The red zone is the 128 bytes immediately below <code>%rsp</code>, which a <strong>leaf</strong> function may use as locals without adjusting <code>%rsp</code> at all. A function with no calls therefore needs no frame, and the 128 bytes are the reason: they are already there.</p>
                <p>What the 128 bytes are <em>for</em> is a separate question, and the answer is in the specification rather than in the measurement: they exist so that a leaf can be interrupted by a signal handler that uses the stack without the leaf having had to build a frame. That is a kernel-behaviour claim and this course cannot test it, so the artifact says so in its limits block rather than paraphrasing the specification as though it had measured it. What <em>can</em> be measured is the restriction that comes with the 128 bytes, and the restriction is not about tidiness.</p>
                <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/THE RED ZONE, MEASURED/,/^  That is the whole/p'
  a leaf that writes 8 bytes at -8(%rsp) and 8 at -128(%rsp) and
  never touches %rsp at all.  The sum below is 0 only if BOTH
  words came back unchanged, so it is the checksum and the result
  in one number.

    leaf, no call, 2 slots written      every slot intact: YES -- both survived
    the same leaf, plus ONE `call`      every slot intact: NO -- at least one destroyed
    the same, plus a FRAMED callee      every slot intact: NO -- and this arm writes FOUR slots, not two
  </pre>
                </div>
                <p>A leaf that uses the red zone and never calls keeps both words. Add <em>one</em> <code>call</code> and it loses them. That is not a slow path, it is not a compiler optimisation, and it is not &ldquo;undefined behaviour&rdquo; in the C sense &mdash; the assembly is perfectly well-defined and does exactly what it says. It is a violation of the convention, and the hardware helps you find out which convention you violated:</p>
                <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/AND THE MECHANISM/,/writes them/p' \
    | sed 's/0x0000[0-9a-f]\{12\}/&lt;per-run address&gt;/'
  AND THE MECHANISM, PROVED RATHER THAN ASSERTED.  The leaf stores a
  magic word at its own -8(%rsp) and then calls a function that
  reports two numbers: its own %rsp, and 0(%rsp).
    the callee saw %rsp = &lt;per-run address&gt;
    the callee's 0(%rsp)   = &lt;per-run address&gt;
  </pre>
                </div>
                <p>The callee reports the <em>same address</em> the first concept read the return RIP from. The word that replaced the leaf's variable is the callee's own return address, and the leaf's variable and the callee's return-address slot are the same eight bytes of memory.</p>
                <div class="formula">
   THE FIRST EIGHT BYTES OF THE RED ZONE ARE THE
   RETURN-ADDRESS SLOT, AND `call` WRITES THEM.

   Not "somewhere near".  The same eight bytes.  A leaf
   function that uses -8(%rsp) and then makes a call has
   written a variable into the slot `call` is about to use.

   And the third arm is worse and less obvious: a callee
   that builds a frame of its own puts its locals BELOW your
   red zone, so all 128 bytes become its scratch space.  The
   green zone in the System V documentation is 128 bytes
   below that, and it is reserved rather than usable.
                </div>
                <p>So the leaf restriction is arithmetic about where a push lands, and the 128 is just how much the architecture gives you before the next thing you do stops being yours. A useful way to hold it: <strong>the red zone is only yours until your next <code>call</code>, and <code>call</code> is one of the eight bytes.</strong></p>
                <h3>And the frame pointer is not a frame descriptor</h3>
                <p>One more thing this concept owes the reference, because it is the piece people expect and do not get. <code>%rbp</code> is a callee-saved general register, and that is <em>all</em> it is on x86-64. There is nothing in the hardware that requires a function to establish a frame, and <code>push %rbp; mov %rsp,%rbp</code> is a gcc convention for making the frame walkable, not a requirement. That gcc can and does use <code>%rbp</code> as an ordinary ninth general register at <code>-O2</code> is direct evidence, and you can see it in the corpus this course audits: <code>mx</code> at <code>-O2</code> moves its four integer arguments into <code>%r13</code>, <code>%r12</code>, <code>%rbp</code> and <code>%rbx</code> &mdash; and <code>push</code>es all four of those registers to do it, because every one of the four is callee-saved and the values sitting in them belong to its caller.</p>
                <p>Why the convention exists is the subject of <a href="/courses/x86abi/lessons/x86-unwind">the unwinding concept</a>: a frame pointer is a way of making the frame addressable by arithmetic instead of by a table, and a table is what a profiler wants and arithmetic is what a debugger on a leaf with no description gets.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: two rules, and the trap in the word &ldquo;alignment&rdquo;</h2>
                <p>The four-way table at the top of this concept is the part worth re-reading, because the two bottom rows are a trap that a great deal of documentation walks into. The claim that &ldquo;the stack must be 16-byte aligned at every control transfer&rdquo; is <strong>false</strong>, and it is false in the most expensive way available: not slower, but dead.</p>
                <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/THE RULE IS TWO RULES/,/^$/p'
  THE RULE IS TWO RULES AND NOT ONE.  A `call` pushes 8, so the
  caller's %rsp must be 16-ALIGNED at the call.  A tail `jmp` pushes
  nothing, so the jmpping function's %rsp must be 8 mod 16, which
  for a function entered at 8 mod 16 means NO ADJUSTMENT AT ALL.  A
  PLT stub is `endbr64; jmp *GOT(%rip)` and nothing else, and it is
  right for the same reason.
  </pre>
                </div>
                <p>Both rules are about the same thing &mdash; the callee's <code>%rsp</code> is 8 (mod 16) at its first instruction &mdash; and they differ because a <code>call</code> pushes 8 and a <code>jmp</code> does not. The proof that the second rule is real and not a nicety is the best evidence in this section, because it is already in every dynamically linked program on the machine:</p>
                <div class="hex-dump">
                <pre>$ objdump -d --no-show-raw-insn -M intel /usr/lib/x86_64-linux-gnu/libc.so.6 \
    | sed -n '/&lt;free@plt&gt;:/,/^$/p'
00000000000283d0 &lt;free@plt&gt;:
   283d0:	endbr64
   283d4:	jmp    QWORD PTR [rip+0x1e9a2e]        # 211e08 &lt;free@@GLIBC_2.2.5+0x15caa8&gt;
   283da:	nop    WORD PTR [rax+rax*1+0x0]
  </pre>
                </div>
                <p>No <code>subq $8, %rsp</code>. No frame. No <code>push</code>. Two instructions, and the second one is the whole of the stub. If the canonical alignment adjustment were required before a tail transfer, every PLT entry in every shared library would be misaligned by 8 bytes, and the first 16-byte vector store in <code>memcpy</code> would fault on every call from every program. It does not, because the stub is right.</p>
                <p>What the <code>movaps</code> arm then shows is the reason the rule about <code>call</code> <em>is</em> real, and it is worth being precise about what kind of evidence a fault is. It is not a faster path and a slower path. It is a process that exists and a process that does not, and the difference is one letter of one mnemonic in the callee. That is a much stronger kind of evidence than a ratio, and it is also the only kind available here: there is no performance counter on this machine to tell you what the misaligned store <em>would</em> have cost, so the honest statement is the one about the fault and the misaligned-but-not-faulting case is in the limits block.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Delete the idiom and watch a legal program die.</strong> In <code>abis.S</code>, remove the <code>subq $8, %rsp</code> from <code>abi_call_conforming</code> and rename it. <em>(Expect the <code>movaps</code> arm to change from &ldquo;returned&rdquo; to &ldquo;KILLED by a signal&rdquo; while the <code>movups</code> arm does not move at all. That is the whole argument for the rule in one edit, and it takes ten seconds.)</em></li>
                    <li><strong>Add the idiom to a tail call and watch a process disappear.</strong> <em>(Expect <code>abi_tail_adjusted</code> to be reported as killed rather than as misaligned, and read the reason the artifact gives: the adjustment does not merely shift the alignment, it puts 8 bytes between the callee and the return address its <code>ret</code> will pop. The failure mode of the wrong tail-call fix is a jump into the middle of the stack, not a slow call.)</em></li>
                    <li><strong>Use the red zone and then call something, in C.</strong> Write a leaf function that stores a local at <code>-8(%rsp)</code> through an inline <code>asm</code>, then calls <code>printf</code>. <em>(Expect the local to come back as a code address, or as something that looks like one. Then move the local to <code>-128(%rsp)</code> and confirm that the <em>other</em> end of the red zone is the one that survives a no-frame callee and dies against a framed one &mdash; and read the psABI's note that the area is reserved from the 128th byte down, which is the reason a green zone exists at all.)</em></li>
                    <li><strong>Count the bytes the red zone actually saves.</strong> Compare the disassembly of a two-instruction leaf with and without a frame at <code>-O2</code>. <em>(Expect the difference to be small: two instructions of prologue and two of epilogue, and no <code>sub</code> at all in the red-zone version. The interesting part is what a compiler does <em>not</em> do, and the fact that this course does not measure the resulting speed-up &mdash; the red zone's cost is a plausible story and a plausible story is not a number, so the artifact declines to make one and says so.)</em></li>
                    <li><strong>Find a real program that breaks the alignment rule, if one exists.</strong> Audit the disassembly of a shared library for calls whose <code>%rsp</code> is not 16-aligned. <em>(Expect to find several, and then expect to spend the next hour discovering that your tracker loses track of <code>%rsp</code> at <code>pushfq</code>, at <code>enter</code>, and at any write it does not model. That is not a failure of diligence; it is the seventh time in this collection that a checker which cannot account for a mismatch is not evidence of a mismatch, and the last concept's retraction R6 is about exactly this experiment.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/x86abi/lessons/x86-calling">the calling convention</a> is where <code>stack=0x10</code> came from: the seventh argument sits 8 bytes past the return address, and this concept is about what that address has to be aligned to. <a href="/courses/mem/lessons/mem-translation">The memory course's translation concept</a> is the reason a misaligned 16-byte store can fault at all &mdash; a page is 4 KiB and a 16-byte-aligned object never straddles one, and the fault is a page fault rather than an alignment check. <a href="/courses/priv/lessons/priv-canonical">The privilege course's canonical-address concept</a> is the one place a similar-sounding word means something quite different, and the two are worth keeping apart.</p>
                <p>Forwards, the red zone is <strong>the reason the callee-saved set is the size it is</strong>, and that is the next concept's opening move: a caller cannot keep anything live in a caller-saved register across a call, so anything it wants to keep has to go somewhere that survives, and on x86-64 the places that survive are six registers and the stack. <a href="/courses/x86abi/lessons/x86-saved">The saved-register concept</a> opens with that argument and then checks it by experiment rather than by table. And the <code>%rbp</code> paragraph at the end of the reality section is the forward reference to <a href="/courses/x86abi/lessons/x86-unwind">unwinding</a>: a frame pointer exists so a frame can be walked by arithmetic, and that matters exactly when there is no table.</p>
                <p>Outward, one neighbour owns the <em>why</em> of the frame's contents and this course deliberately does not re-teach it. <a href="/courses/sec/lessons/sec-canary">The security course's stack-protector concept</a> is where a canary is placed between the return address and the locals and why a smash is detected rather than exploited. That is a property of a hardening tool layered on the frame, and this course owes the exhaustive x86-64 reference for the frame itself. Reading both is the cheapest way to stop confusing the two: the canary is a convention adopted by compilers, and the alignment rule is a convention adopted by the hardware's instruction set.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86abi/lessons/x86-calling">The Calling Convention, and the Register That Wasn't</a></span>
                <span>Next: <a href="/courses/x86abi/lessons/x86-saved">Callee-Saved and Caller-Saved, by Experiment</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
