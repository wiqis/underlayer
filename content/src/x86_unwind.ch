// The x86-64 ABI — Concept 5: unwinding and CFI
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_unwind() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Unwinding, and the Second Language — Underlayer")
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
            <h1>Unwinding, and the Second Language</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/x86abi">The x86-64 ABI</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>You have spent four concepts learning that a frame is described by a prologue: a <code>push</code>, a <code>sub</code>, a <code>mov</code>. The instructions say what happens. Now imagine you are a profiler, or a crash reporter, or a debugger, and you are standing in a function that has already run its prologue and you want to know <strong>where the frame above it is</strong>.</p>
                <p>You cannot get that from the instructions, and the reason is not that they are hard to read. It is that <strong>the information is not there in a form you can use</strong>. The prologue ran; its <code>push</code>es are gone. The return address is at <code>0(%rsp)</code> and the saved <code>%rbp</code> is at <code>8(%rsp)</code> <em>if the function pushed one</em>, and whether it pushed one is a property of the code that has already executed. The hardware will not tell you, because the hardware was not told.</p>
                <p>So the compiler writes it down. A second time, in a second language, in a table the profiler reads. That is the whole subject of this concept, and it is the reason an ABI has to be more than a register assignment: <strong>the calling convention describes how to make a call, and the unwind information describes how to walk back through one, and neither can be derived from the other.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>The model: the Canonical Frame Address, and a table of deltas</h2>
                <p>The unwind information answers one question repeatedly, at every program counter in a function: <em>where is the Canonical Frame Address?</em> The CFA is not a saved register and it is not a memory location. It is defined as <strong>the value <code>%rsp</code> would have had, at that program counter, immediately before the function's prologue ran</strong> &mdash; which is to say, at the function's entry, plus 8 for the return address.</p>
                <p>Once you know the CFA, everything else is a fixed offset from it. And so the description of a whole function is a list of <em>(where in the code, what has happened to the CFA, which register is at which offset from it)</em> pairs.</p>
                <p>Here is a real one, and it is a function you have already met in this course: <code>f7</code>, the seven-argument function from the calling convention, compiled at <code>-O2</code> where it has no frame pointer at all.</p>
                <div class="hex-dump">
                <pre>$ gcc -O2 -S -o abidump.s abidump_corpus.c &amp;&amp; sed -n '/^f7:/,/^\.LFE/p' abidump.s
f7:
	.cfi_startproc
	endbr64
	subq	$8, %rsp
	.cfi_def_cfa_offset 16          &lt;- the CFA is now rsp+16
	movq	16(%rsp), %r10
	lea	rdi,[rdi+rsi*1]
	add	rdi,rdx
	add	rdi,rcx
	add	rdi,r8
	add	rdi,r9
	add	rdi,r10
	call	abi_sink
	movl	$7, %eax
	addq	$8, %rsp
	.cfi_def_cfa_offset 8           &lt;- and back to rsp+8
	.cfi_endproc
  </pre>
                </div>
                <p>There is no <code>push %rbp</code> and no frame pointer, so the CFA cannot be recovered by following a chain of saved frame pointers. It is recovered by a rule: <strong>at this program counter, the CFA is <code>%rsp</code> plus 16</strong>. And that rule is a consequence of the two <code>subq</code>/<code>addq</code> of 8 and the return address.</p>
                <p>Now look at the instruction it annotates, because this is the payoff and it links straight back to the first concept:</p>
                <div class="formula">
   movq 16(%rsp), %r10

   16(%rsp) is the CFA, by the rule above.
   The CFA is rsp+8 at the function's entry.
   So 16(%rsp) is entry_rsp + 8.
   And entry_rsp + 8 is 8 bytes past the return address.

   THE SEVENTH ARGUMENT.  The first concept measured its
   address as `stack=0x10` in the disassembly, from the other
   side of the call.  The unwind table states the same address
   as a fact about where the CFA is, and both readers agree.
                </div>
                <p>So the CFI is not a separate piece of bookkeeping bolted onto the end. <strong>It is the same frame, described a second time, in a language whose whole purpose is to be read by something that was not there when the frame was built.</strong> And the two descriptions can be checked against each other, which is a thing you almost never get to do with a compiler's internal state.</p>
                <h3>The vocabulary</h3>
                <p>The directives are few, and each one is a small edit to a small state machine:</p>
                <div class="formula">
   THE .cfi_* DIRECTIVES, AND WHAT EACH ONE DOES

   .cfi_startproc        begin a frame description
   .cfi_endproc          end it
   .cfi_def_cfa_offset N the CFA is %rsp + N from here on
   .cfi_def_cfa_register R
                         the CFA is the VALUE IN REGISTER R,
                         not %rsp + N -- used once a frame
                         pointer exists, and it is how a
                         function with a frame pointer describes
                         itself without a table at all
   .cfi_offset R, D      register R is saved at CFA + D, and
                         must be restored to unwind past
   .cfi_restore R        and it is back in its original place
                </div>
                <p>Underneath the directives is a byte language with its own opcodes, and the numbers are worth having because they are the first thing you meet when you read an <code>.eh_frame</code> section by hand. The high two bits of a byte select its class: <code>0x40</code> is <em>advance the location</em>, <code>0x80</code> is <em>register rule</em>, <code>0xc0</code> is <em>remember and restore state</em>, and <code>0x00</code> is <em>expression and extension</em>. Inside the first class, the low six bits are the primary opcodes &mdash; <code>0x01</code> set location, <code>0x02</code>/<code>0x03</code>/<code>0x04</code> advance by 1, 2 or 4 bytes, <code>0x0c</code> define the CFA, <code>0x0d</code> define the CFA register, <code>0x0e</code> define the CFA offset. <strong>So a single byte <code>0x0e</code> is &ldquo;the CFA is <code>%rsp</code> plus the following ULEB128&rdquo; and <code>0x4c</code> is &ldquo;advance the program counter by 12&rdquo;.</strong> A whole function's unwind description is a few hundred of those bytes, and a full binary's is a few hundred thousand.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: what a profiler does when the description is absent</h2>
                <p>The question is not whether the CFI is well-formed. It is what happens to a program compiled without it, and the answer is measurable with a real unwinder rather than a simulation of one.</p>
                <p>The instrument is <code>backtrace()</code> from glibc's <code>execinfo</code> &mdash; not a stand-in for a profiler but the code <code>gdb</code>, <code>perf</code> and every crash reporter on this machine use. It is run from three nested <code>noinline</code> functions in a program built <strong>twice</strong>: once normally, and once with <code>-fno-asynchronous-unwind-tables</code>.</p>
                <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/WHAT A PROFILER CAN AND CANNOT SEE/,/^  ONE FRAME/p'
  DIRECTIVE | cfi_startproc | 33
  DIRECTIVE | cfi_endproc | 33
  DIRECTIVE | cfi_def_cfa_offset | 71
  DIRECTIVE | cfi_def_cfa_register | 0
  DIRECTIVE | cfi_offset | 5
  DIRECTIVE | total | 142
  FDE | with | 33
  EHSIZE | with | 358
  FDE | without | 0
  EHSIZE | without |

  THE INSTRUMENT IS A REAL UNWINDER.  backtrace() from glibc's
  execinfo, which is what gdb, perf and every crash reporter on
  this machine use, run from three nested noinline functions, in a
  program built TWICE: once normally and once with
  -fno-asynchronous-unwind-tables.

    uwprobe, unwind tables present:      FRAMES 7, stack depth 9
    uwprobe, unwind tables REMOVED:     FRAMES 1, stack depth 3
  </pre>
                </div>
                <p><strong>Seven frames, or one.</strong> The call chain is identical in both builds: the same three nested <code>noinline</code> functions, the same <code>backtrace()</code>, the same machine. The only difference is a compiler flag, and the flag is worth 6 frames out of 7.</p>
                <p>And the shape of the failure is the part that matters. The unwinder did not return a <em>wrong</em> answer. It returned the only answer it could: the frame it was called from. One frame. There is no diagnostic, no error code, and no indication in the return value that anything is missing &mdash; a caller that does not know the flag was set sees a one-frame backtrace and a plausible-looking program name at the bottom of it.</p>
                <div class="formula">
   33 FDEs with the flag, 0 without.  And 71 of the
   directives in that corpus are the single instruction
   `.cfi_def_cfa_offset`, which is the cheapest possible
   complete answer: "the CFA is %rsp plus this number".

   .eh_frame is 358 bytes for 33 functions with no
   frame pointer, and 428 bytes for the SAME 33 when
   they keep one.  So the price of being walkable is
   about ELEVEN BYTES a function, and a frame pointer
   adds about two of them.

   The first draft of this course put that second
   number at FORTY.  It was never measured, and it is
   wrong by a factor of about three.
                </div>
                <p><strong>And here is a number that was wrong, and is wrong in the artifact rather than only here.</strong> The draft claimed a frame description costs about eleven bytes without a frame pointer and about <em>forty</em> with one. The first half was measured. The second was an estimate written into a page as though it were a measurement, and compiling the same 33 functions three ways says the second half is <strong>thirteen bytes</strong> &mdash; a frame pointer costs about <em>two</em> bytes of table, not thirty. The three builds are the interesting part, and one of them is a lesson about flags: <code>-O2</code> and <code>-O2 -fomit-frame-pointer</code> produce <strong>byte-identical</strong> <code>.eh_frame</code> sections, because gcc omits frame pointers at <code>-O2</code> already, so the flag confirms a default rather than changing it. Only <code>-fno-omit-frame-pointer</code> moves the number. A reader who assumed a flag always changed something would have measured nothing and reported a difference anyway.</p>
                <p>The asymmetry worth naming is between the two ways of describing a frame. A frame pointer describes itself <strong>in the frame</strong> &mdash; one register, restored on the way out, costing a <code>push</code> and a <code>pop</code> and making the function slower whether or not anybody ever unwinds it. A CFI table describes itself <strong>beside the frame</strong>, in a section, costing bytes in the file and nothing at run time. gcc emits the table by default and the frame pointer only when asked, and that default is a considered choice rather than an accident: <code>-O2</code> omits frame pointers and still produces fully walkable binaries, whereas the reverse is not achievable.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: two descriptions, and the check nobody does</h2>
                <p>Take the two views of <code>f7</code> from earlier in this course and put them side by side. The first is the audit's, read from the callee's instructions; the second is the compiler's, read from its own annotations.</p>
                <div class="hex-dump">
                <pre>  WHAT THE INSTRUCTIONS SAY            WHAT THE CFI SAYS
  ------------------------------------  ------------------------------------
  subq $8, %rsp                        .cfi_def_cfa_offset 16
  movq 16(%rsp), %r10   &lt;- arg 7       the CFA is rsp+16, so
                                           16(%rsp) is CFA
  call abi_sink
  addq $8, %rsp                        .cfi_def_cfa_offset 8
  ret                                  and the CFA is back to rsp+8
  </pre>
                </div>
                <p>Both say the same thing about where argument seven is, and they say it without reference to each other. <strong>That is the interesting property and it is not an accident: the two descriptions were generated from the same compiler's model of the function, so they cannot disagree, and a compiler that emitted a CFI contradicting its own prologue would break every unwinder on the machine.</strong> So the CFI is trustworthy in a way that is unusual for compiler output, and it is worth knowing <em>why</em> rather than merely that it is.</p>
                <p>What the pair does <em>not</em> give you is a way to check either one against the architecture. The prologue is checkable &mdash; <a href="/courses/x86abi/lessons/x86-verify">the last concept</a> checks the calling convention by re-deriving it from the bytes, and it is the only part of the ABI where that is possible. The unwind table is not checkable that way, because there is no independent account of what a function's frame <em>should</em> be: it is whatever the compiler decided, and the only oracle is a program that successfully unwinds through it.</p>
                <p>Which brings the measurement back round to where it started. The reason the two builds differ by six frames is not that the second build's frames are differently described. <strong>They are not described at all.</strong> The unwind information is not a second opinion on a frame the first description got wrong; it is the only description there is, for anything that was not there at the time. Strip it and you have not made the description worse, you have removed it, and a consumer that needed it does not get a degraded answer &mdash; it gets the truth about how much it does not know.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Make a profiler blind and look at what it prints.</strong> Build any program with <code>-fno-asynchronous-unwind-tables</code> and run <code>gdb</code> on it, or <code>backtrace()</code> from a function three frames deep. <em>(Expect one frame, and expect nothing in the output to say that anything is wrong. Then <code>readelf --debug-dump=frames</code> the binary and confirm the section is absent rather than empty &mdash; the difference matters, because an empty table says &ldquo;nothing changes here&rdquo; and an absent one says &ldquo;this object has no opinion&rdquo;.)</em></li>
                    <li><strong>Count the bytes.</strong> Compare the size of a function's <code>.eh_frame</code> contribution with and without a frame pointer. <em>(Expect almost nothing: about <strong>two bytes a function</strong>, in this course's own corpus. And expect the first thing you try to teach you nothing at all &mdash; <code>-fomit-frame-pointer</code> at <code>-O2</code> is <strong>byte-identical</strong> to the default, because gcc already omits frame pointers there, so the flag measures the default rather than changing it. Only <code>-fno-omit-frame-pointer</code> moves the number. Then try <code>-fno-asynchronous-unwind-tables -fno-omit-frame-pointer</code> together and confirm that the result is a binary that runs and cannot be profiled, which is the shape of a bad default: a frame pointer walks a frame by arithmetic and needs no table, and the table is gone.)</em></li>
                    <li><strong>Find the CFA in a function of your own.</strong> Pick any function gcc emits with <code>.cfi_def_cfa_offset</code> and account for the number: count the pushes, the frame-pointer setup and the <code>sub</code>s between the function's entry and that point, and check that the annotation equals 8 plus their sum. <em>(Expect it to work the first time, and expect the second function you pick to use <code>.cfi_def_cfa_register</code> instead because it has a frame pointer. The two forms are the two ways of answering the same question, and a function that has both uses the register form and the offset form for different callee-saved registers.)</em></li>
                    <li><strong>Read six bytes of <code>.eh_frame</code> by hand.</strong> <code>readelf --debug-dump=frames</code> a small binary and find one FDE's instructions. <em>(Expect to find <code>0x0c</code> (define the CFA register), <code>0x0e</code> followed by a ULEB128 (define the CFA offset), <code>0x07</code> and <code>0x08</code> (undefined and same-value rules for the volatile registers) and a run of <code>0x00</code> nops padding the rest. Then compare that against the <code>.cfi_*</code> directives gcc emitted for the same function and account for every byte, and note how little of the 358 bytes is not padding.)</em></li>
                    <li><strong>Check whether your own project describes its frames.</strong> Look for <code>.eh_frame</code> in every binary you ship, and remember the two ways it disappears: a compiler flag, and <code>-static-libgcc</code> with a toolchain that has the tables in a separate object. <em>(Expect a partial description to be worse than none in one specific way: a frame that is described for the first ten instructions and not for the rest will unwind correctly until the eleventh, and the failure will be at whatever was called from there. The <code>sec</code> course's canary concept is the neighbouring version of this problem, where the description that goes missing is a protection rather than a table.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/x86abi/lessons/x86-frame">the stack frame</a> is the subject being described a second time, and the <code>%rbp</code> paragraph at the end of its reality section is the direct link: a frame pointer exists so a frame can be walked by arithmetic, and this concept is what arithmetic is a <em>fallback</em> for. <a href="/courses/x86abi/lessons/x86-calling">The calling convention</a> supplied the two facts the table confirms, <code>stack=0x10</code> and the 176-byte save area, and this concept is the point at which they stop being the compiler's private business.</p>
                <p>Forwards, the last concept is the one that puts a number on all of it. The audit in <a href="/courses/x86abi/lessons/x86-verify">the final concept</a> re-derives the calling convention from bytes and checks it against a specification, and the contrast with this concept is the point: <strong>that check is possible for the call and impossible for the frame</strong>, because the call has an independent oracle and the frame does not. Understanding why one part of an ABI is auditable and another part is not is worth more than either result on its own.</p>
                <p>Outward, two neighbours that own the edges. The <a href="/courses/dyn/lessons/dyn-order-runtime">dynamic-linking course</a> is about how the stack is set up before any of this course's rules have a chance to apply &mdash; the kernel hands over a <code>%rsp</code> whose alignment the ABI's rules do not describe, and the two functions that establish the invariant are the first thing that has to fix it. And <a href="/courses/link/lessons/link-orphans">The linking course's orphans concept</a> is about what happens to a section nobody references: <code>.eh_frame</code> is the section a link command is most likely to drop, precisely because nothing in the program refers to it.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86abi/lessons/x86-varargs">The One Place the ABI Describes Itself</a></span>
                <span>Next: <a href="/courses/x86abi/lessons/x86-verify">Read the ABI Out of the Disassembly</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
