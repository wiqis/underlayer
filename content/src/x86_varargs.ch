// The x86-64 ABI — Concept 4: varargs
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_varargs() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The One Place the ABI Describes Itself — Underlayer")
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
            <h1>The One Place the ABI Describes Itself</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/x86abi">The x86-64 ABI</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Every other rule in this ABI is implicit. The callee knows how many arguments there are because the caller and the callee were compiled from the same declaration, so the two of them share something &mdash; a prototype &mdash; and the registers are just the places they agreed to put them. Nobody has to be told anything at run time.</p>
                <p>A variadic function breaks that completely. <code>printf</code> does not know how many arguments it was called with, or what they are, and neither does the code that walks the list. Something has to carry the information, and the ABI's answer is a small block of stack that the callee fills in before it can read anything, plus <strong>one integer in <code>%rax</code> that says how much of it is worth filling in</strong>.</p>
                <p>That is the only self-describing convention in the whole of x86-64, and it is worth looking at closely for two reasons. It is the mechanism behind the single most-used function in the C library. And it is the one place where a caller can be wrong in a way that produces <strong>a plausible number that nobody passed</strong> rather than a crash &mdash; which makes it the best demonstration in this course of what a contract violation actually looks like when the contract is about meaning rather than about memory.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: 176 bytes and one integer</h2>
                <p>The register save area is a fixed 176-byte block, and the division is not arbitrary: 48 bytes for the six integer registers at 8 bytes each, and 128 bytes for the eight SSE registers at 16 bytes each.</p>
                <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/1B\./,/^  the two sequences/p' | tail -6
  the return value             rax; rdx for a second integer; xmm0
                               for a double; xmm0:xmm1 for a long double
  the stack alignment constant 16 bytes
  %rsp at a callee's entry     8 (mod 16), because `call` pushed 8
  the red zone                 128 bytes below %rsp, LEAF functions
  the varargs save area        176 bytes = 48 integer + 128 SSE
  the initial gp_offset        8
  the initial fp_offset        48
  the vector count in %al      0 .. 8
  </pre>
                </div>
                <p>And here is the shape of the whole mechanism, which is a two-field cursor and a pointer:</p>
                <div class="formula">
   THE va_list, IN THE TERMS THE ABI DEFINES

   gp_offset     where to read the NEXT integer argument, as a
                 byte offset into the register save area.  Starts
                 at 8, because slot 0 is the register the named
                 parameter already took.
   fp_offset     the same for SSE registers.  Starts at 48,
                 which is where the FP half begins.
   overflow_arg_area
                 where the 7th and later arguments live, on
                 the stack.
   reg_save_area
                 the 176-byte block itself.

   And in a register the ABI does not put in the struct:
   %al, the number of vector registers the CALLER used.
                </div>
                <p>So a variadic callee does two things. It fills in the save area &mdash; six integer registers unconditionally, and the SSE registers <strong>only if <code>%al</code> is non-zero</strong>. And it sets the two cursors to 8 and 48. Then <code>va_arg</code> is arithmetic: read the field, add the size of the type, write the field back.</p>
                <p>Here is a real one, compiled at <code>-O0</code> so that every store is still in the listing, and read back:</p>
                <div class="hex-dump">
                <pre>$ gcc -O0 -S -o - abidump.c &amp;&amp; sed -n '/^abi_take2:/,/^\.L190:/p' abidump.s
abi_take2:
	.cfi_startproc
	endbr64
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$256, %rsp
	movq	%rdi, -248(%rbp)        -> the NAMED parameter, elsewhere
	movq	%rsi, -168(%rbp)        -> the first vararg register
	movq	%rdx, -160(%rbp)
	movq	%rcx, -152(%rbp)
	movq	%r8, -144(%rbp)
	movq	%r9, -136(%rbp)         -> the sixth, and the LAST
	testb	%al, %al               -> %al: is it ZERO?
	je	.L190                  -> if so, do not spill xmm at all
	movaps	%xmm0, -128(%rbp)     -> the FP half begins here
	movaps	%xmm1, -112(%rbp)
	movaps	%xmm2, -96(%rbp)
	movaps	%xmm3, -80(%rbp)
	movaps	%xmm4, -64(%rbp)
	movaps	%xmm5, -48(%rbp)
	movaps	%xmm6, -32(%rbp)
	movaps	%xmm7, -16(%rbp)      -> eight of them, 16 bytes each
.L190:
	movq	%fs:40, %rax           -> the stack protector canary,
	movq	%rax, -184(%rbp)          which is a DIFFERENT convention
	movl	$8, -208(%rbp)        -> gp_offset  = 8
	movl	$48, -204(%rbp)       -> fp_offset  = 48
	leaq	16(%rbp), %rax        -> overflow_arg_area
	movq	%rax, -200(%rbp)
	leaq	-176(%rbp), %rax      -> reg_save_area, the 176 bytes
	movq	%rax, -192(%rbp)
	movl	-204(%rbp), %eax
	cmpl	$175, %eax            -> will the next 16 bytes fit?
	ja	.L191                    -> no: read the stack instead
  </pre>
                </div>
                <p>Three things to read out of that, and one of them is a surprise.</p>
                <ul>
                    <li><strong>Six integer registers, unconditionally.</strong> No test, no branch. The integer half of the save area is always filled, because the cost of six stores is smaller than the cost of a branch and the caller is assumed to have used the registers if it passed anything at all.</li>
                    <li><strong>Eight SSE registers, and the guard is <code>testb %al, %al</code> followed by a jump over all eight stores.</strong> So <code>%al</code> is being used as a <strong>boolean</strong>, not as a count. The specification says it is the number of vector registers used, and gcc asks only whether it is zero. Hold that thought; it is the whole of the last section.</li>
                    <li><strong>The <code>movaps</code> stores are 16-byte <em>aligned</em> stores</strong>, at <code>-128</code> through <code>-16</code> from <code>%rbp</code>. That is the alignment rule from <a href="/courses/x86abi/lessons/x86-frame">the previous concept</a> appearing in a place nobody thinks about it: a variadic function's save area is a 16-byte-aligned object, and the ABI's stack alignment rule is what makes it possible. A variadic function compiled by a compiler that broke the alignment rule would fault in its own prologue, before reading a single argument.</li>
                </ul>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: a caller that lies about <code>%al</code></h2>
                <p>Here is the experiment. The caller puts two doubles in <code>%xmm0</code> and <code>%xmm1</code>, and then puts a chosen value in <code>%al</code> &mdash; the number of vector registers it claims to have used. The consumer is an ordinary variadic C function using <code>va_start</code> and <code>va_arg</code>, so the whole thing is compiled by gcc and the prologue above is the code that runs.</p>
                <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/The caller claims a number/,/arm 4/p'
  honest, arm 1: 1.5 and 2.5
    al=2  a=0x3ff8000000000000 (1.500000)  b=0x4004000000000000 (2.500000)
  honest, arm 2: 101.25 and 202.5 -- these are now what the save
                area holds, and arm 3 is where it stops mattering
                what the caller put in xmm0 and xmm1.
    al=2  a=0x4059500000000000 (101.250000)  b=0x4069500000000000 (202.500000)
  LYING, arm 3: the caller puts 3.5 and 4.5 in xmm0 and xmm1 and
               then says it used NO vector registers:
    al=0  a=0x4059500000000000 (101.250000)  b=0x000000000000000a (0.000000)
  al=1, arm 4: the same lie, understated rather than zero:
    al=1  a=0x400c000000000000 (3.500000)  b=0x4012000000000000 (4.500000)
  </pre>
                </div>
                <p><strong>Read arm 3 again, because the first number is the finding.</strong> The caller passed 3.5 and 4.5. The consumer returned <code>0x4059500000000000</code>, which is 101.25 &mdash; <em>exactly what arm 2 passed, bit for bit, and not what this arm passed.</em> The second came back <code>0x000000000000000a</code>, which is a fragment of a pointer and not a number anybody passed to anything.</p>
                <div class="formula">
   WHAT ACTUALLY HAPPENED IN ARM 3

   NOT: the arguments were corrupted in transit.

   YES: the arguments were never looked at.  `al` was 0,
   so the callee skipped all eight `movaps` stores.  The
   176-byte save area was therefore never written, and
   `va_arg(ap, double)` read whatever was already in those
   128 bytes -- which was the last HONEST call's data, and
   beyond it, stack.

   The value 0x4059500000000000 is not a corrupted 3.5.
   It is a perfectly intact 101.25 that was never on its
   way anywhere.
                </div>
                <p>That is a much better failure than a crash, and it is the reason this concept is on a page about contracts. A crash tells you where to look. <strong>A plausible number tells you nothing, and it will be printed into a log, compared against a tolerance, and believed.</strong></p>
                <h3>And it is not only your own code that reads it</h3>
                <p>The same experiment through glibc's <code>printf</code>, which is a variadic consumer and obeys the same rule:</p>
                <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/AND THE SAME FAILURE/,/wrong answer,/p'
glibc printf, al=2: 1.500000 2.500000
glibc printf, al=2: 101.250000 202.500000
  and now the same call with al=0, having been passed 3.5 and 4.5:
glibc printf, al=0: 101.250000 0.000000

  A number nobody passed, printed as though somebody had.  That is not
  a slow path and not a portability warning: it is a wrong answer,
  produced by a caller that broke one instruction's contract.
  </pre>
                </div>
                <p>So the mechanism is not an academic corner of the convention. It is the code path of every <code>printf</code> call with a floating-point argument in it, and the reason <code>%al</code> exists at all.</p>
                <h3>And arm 4 is the surprise, and it is a correction</h3>
                <p>The specification says <code>%al</code> is the <em>number</em> of vector registers used. Arm 4 claims <strong>one</strong> and passes two, which is a lie in the strict reading &mdash; and it works, because gcc tests <code>%al</code> for <em>zero</em> and spills all eight when it is non-zero. So on this compiler the field is a boolean and the specification's stricter reading would be a lie that happens to be harmless.</p>
                <p>That is worth stating as what it is rather than as a contradiction: <strong>a self-describing convention is still a convention.</strong> The description is there, and nothing checks it. Any callee is entitled to use <code>%al</code> as an upper bound &mdash; to trust it and read only that many registers &mdash; and one that does will break on arm 4 while working perfectly on arm 3. The value of the mechanism is that it makes the common case safe; the cost is that the common case and the correct case are not the same case.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the save area, from the specification to the addresses</h2>
                <p>The layout deserves to be written out once, because it is short and everything about varargs is a consequence of it:</p>
                <div class="formula">
   THE 176 BYTES, AT THE OFFSETS GCC ACTUALLY USES

   reg_save_area = -176(%rbp) in the listing above, so the
   offsets are measured from there:

   base +  0 ..   7   rdi's slot.  UNUSED here, because rdi is
                         the named parameter and already has a
                         home at -248(%rbp).  That is the whole
                         reason gp_offset STARTS AT 8.
   base +  8 ..  15   rsi          -> -168(%rbp)
   base + 16 ..  23   rdx          -> -160(%rbp)
   base + 24 ..  31   rcx          -> -152(%rbp)
   base + 32 ..  39   r8           -> -144(%rbp)
   base + 40 ..  47   r9           -> -136(%rbp)
   base + 48 ..  63   xmm0         -> -128(%rbp)   --> 48 is
   base + 64 ..  79   xmm1         -> -112(%rbp)       where fp_
   base + 80 ..  95   xmm2         ->  -96(%rbp)       offset
   base + 96 .. 111   xmm3         ->  -80(%rbp)       starts
   base +112 .. 127   xmm4         ->  -64(%rbp)
   base +128 .. 143   xmm5         ->  -48(%rbp)
   base +144 .. 159   xmm6         ->  -32(%rbp)
   base +160 .. 175   xmm7         ->  -16(%rbp)
                176 bytes total, and the last legal byte is
                base+175, which is the number the `cmpl $175`
                above compares against.
                </div>
                <p>Two consequences fall out of the layout and both are worth stating as rules rather than as trivia.</p>
                <p><strong>The <code>movaps</code> stores are aligned because the area is 16-byte aligned, and the area is 16-byte aligned because of the stack alignment rule.</strong> That is why the two concepts are adjacent: a variadic function is the one function whose <em>prologue</em> depends on the caller's alignment, because the save area is a 16-byte-aligned object that the callee does not build &mdash; it inherits.</p>
                <p><strong>Saving eight XMM registers costs 128 bytes of store and, when <code>%al</code> is zero, is skipped entirely.</strong> The skip is the optimisation that made the mechanism cheap, and it is also the entire attack surface: a caller that says zero pays nothing and the callee reads nothing. An implementation that trusted <code>%al</code> as an exact count would save four stores in the common case where one float is passed, at the cost of a second pass over the save area for the rest. gcc's author chose the branch.</p>
                <p>And the arithmetic of <code>va_arg</code> itself is worth one sentence, because it explains the <code>cmpl $175</code> in the listing: before reading, the callee compares the SSE cursor against 175 &mdash; the last byte of the 176-byte area &mdash; and if the next 16-byte argument would not fit, it reads from <code>overflow_arg_area</code> instead. That is the boundary between &ldquo;passed in a register&rdquo; and &ldquo;passed on the stack&rdquo;, and it is the same boundary the first concept measured at <code>stack=0x10</code>. The rest of <code>va_arg</code> is the same idea: load the cursor, add the size of the type, store the cursor back, read through the pointer.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Make the lie yourself.</strong> Copy the <code>VARARG_CALL</code> macro out of <code>abidump.c</code> into your own file, change the <code>al</code> value, and watch which arms come back wrong. <em>(Expect <code>al=0</code> to lose the FP arguments and <code>al=1</code> to keep them on gcc, and expect the values you get back to be the <em>previous</em> call's rather than zeroes. That second half is the part that makes it a security-shaped bug rather than a numerical one: the value is not garbage, it is someone else's data.)</em></li>
                    <li><strong>Find the guard in a real binary.</strong> <code>objdump -d</code> any variadic function and look for <code>testb %al,%al</code> above a block of eight <code>movaps</code> stores. <em>(Expect to find it in <code>printf</code>'s implementation, in <code>snprintf</code>, in every libc routine that takes a floating-point variadic argument, and in every program your compiler has ever produced that includes <code>&lt;stdarg.h&gt;</code>. Then change <code>al</code> to 1 in a hand-written caller and see the ones that trust the count fail and the ones that test for zero survive.)</em></li>
                    <li><strong>Work out the save-area offsets for a function whose first parameter is a double.</strong> <em>(Expect <code>gp_offset</code> to start at 0 rather than 8, because the first integer register is still available, and <code>fp_offset</code> to start at 64 rather than 48. This is the clearest demonstration that the two cursors really are independent counters, and it is the same fact the first concept measured as <code>mx</code> in the disassembly.)</em></li>
                    <li><strong>Break the alignment underneath a variadic function and watch its own prologue fault.</strong> Call a variadic function through a hand-written caller that has deleted the <code>subq $8, %rsp</code> from its outgoing-argument area. <em>(Expect a <code>SIGSEGV</code> inside the callee's <code>movaps</code>, before a single argument is read, and expect the fault address to be 8 bytes off a 16-byte boundary. That is <a href="/courses/x86abi/lessons/x86-frame">the alignment fault</a> wearing a different hat, and it is the reason the two concepts are in the same module.)</em></li>
                    <li><strong>Count the bytes.</strong> A variadic function with eight float arguments saves 128 bytes of SSE registers plus 48 of integer ones whether or not any integer was passed. <em>(Expect 176 bytes of frame that a fixed-arity function with the same eight parameters would not have, because a fixed-arity function knows the types and puts the ninth-and-later arguments straight on the stack with no save area at all. The convention pays 176 bytes for the privilege of not knowing, and that is the trade the next ABI makes differently.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/x86abi/lessons/x86-calling">the calling convention</a> is where the independence of the two register sequences was measured, and this concept is the only place in the ABI where that independence is <em>load-bearing</em>: the two cursors in the <code>va_list</code> are the same two counters, and a function whose first parameter is a double has an integer cursor starting at 0 and an SSE cursor starting at 64. <a href="/courses/x86abi/lessons/x86-frame">The stack frame</a> is where the <code>movaps</code> stores in that prologue get their alignment, and a reader who has read it will recognise <code>-128(%rbp)</code> as the first slot of a 16-byte-aligned object rather than as a coincidence of the frame size.</p>
                <p>Forwards, the <code>%al</code> finding is the last retraction in this module and it is a general one: a convention that describes itself is not thereby checked. <a href="/courses/x86abi/lessons/x86-unwind">The unwinding concept</a> is the other place in this ABI where the hardware is told something it could have worked out, and the parallel is exact &mdash; <code>%al</code> is information the caller has and the callee cannot derive, and the <code>.eh_frame</code> table is information the compiler has and the profiler cannot derive. Both are conventions rather than instructions, and both are paid for in bytes.</p>
                <p>Outward, the neutral course that owns the <em>why</em> of dynamic dispatch across a language boundary. This concept is about how a C caller tells a C callee what it passed; it is not about what happens when the two sides were compiled by different compilers in different languages, and that is <a href="/courses/dyn/lessons/dyn-order-runtime">the dynamic-linking course's runtime-order concept</a> and its interposition concept. The one thing worth carrying across is the shape of the failure: a boundary that disagrees about a signature does not crash, it returns a value from a different conversation.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86abi/lessons/x86-saved">Callee-Saved and Caller-Saved, by Experiment</a></span>
                <span>Next: <a href="/courses/x86abi/lessons/x86-unwind">Unwinding, and the Second Language</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
