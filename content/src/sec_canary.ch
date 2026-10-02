// Executable Security and Hardening — Module 1: The Defaults
// Concept: %fs:0x28, three instructions, and the one overflow it cannot see.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sec_canary() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Canary and Its Limits — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson sec-lesson">
            <a href="/courses/sec" class="back-link">Back to course</a>
            <h1>The Canary and Its Limits</h1>
            <div class="lesson-meta">25 min &middot; Module 1: The Defaults &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The stack canary is the most widely deployed anti-exploit measure in the world, and almost nobody can say how it works. Here is the whole mechanism, in three instructions from a real binary on this machine:</p>
                <div class="hex-dump">
                    <pre>$ cd courses/sec/assets/samples &amp;&amp; ./build_samples.sh 2&gt;&amp;1 | sed -n '/H1/,/H2/p'
  the mechanism, in the gcc default build -- load, store, compare:
      1192:	64 48 8b 04 25 28 00 	mov    %fs:0x28,%rax
      119b:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
      11ca:	48 8b 44 24 18       	mov    0x18(%rsp),%rax
      11cf:	64 48 2b 04 25 28 00 	sub    %fs:0x28,%rax
      11d8:	75 0b                	jne    11e5 &lt;main+0x5c&gt;
</pre>
                </div>
                <p>That is the entire feature. <strong>Read <code>%fs:0x28</code>, park a copy in the frame, and on the way out check that the copy still matches.</strong> If a buffer overflow ran off the end of a local array far enough to reach the parked copy, the subtraction is non-zero and the <code>jne</code> branches away &mdash; to <code>__stack_chk_fail</code>, which prints a message and does not return.</p>
                <p>Five instructions, and there is no setup code anywhere. <strong><code>%fs:0x28</code> is a fixed offset into the thread control block, and the value is already there</strong> &mdash; put there by the C runtime at thread creation, from a source of randomness the attacker cannot see. The <a href="/courses/img/lessons/img-auxv">kernel builds the thread control block</a> and hands the process a pointer to it; <code>%fs</code> is the register that points at the current one. That is why there is nothing to initialise: the canary predates <code>main</code>.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>What the check does and does not cover, which is the part that matters:</p>
                <div class="formula">
  the tripwire is PLACED in the frame, and
  it is checked against %fs:0x28.

  so it detects:   a write that changed the
                   frame between the prologue
                   and the epilogue.

  it does NOT detect:
    a write somewhere else entirely
      a global buffer, a heap block, another
      thread's stack. the frame is untouched,
      the subtraction is zero, nothing fires.

    a write that does not change the value
      an off-by-one that lands in padding.

    a write that is later RESTORED
      which is why the canary is paired with
      -fstack-protector-strong rather than
      used alone.

  the canary is a tripwire, not a boundary.
  it tells you the frame was disturbed. it
  does not tell you WHICH write did it, and
  it does not stop a write that missed it.
                </div>
                <p>And here is the part that makes it precise rather than impressionistic. <strong>The canary sits between the local arrays and the saved registers.</strong> An overflow travelling <em>upward</em> through the frame must cross it. That is why the mechanism works at all, and it is also why it is a poor detector of anything that is not travelling upward through the frame.</p>
                <div class="formula">
  higher addresses
  +--------------------+  <- saved rbp, return addr
  |  saved registers   |     an overflow that
  +--------------------+     reaches HERE has
  |  CANARY            | <--- already smashed the
  +--------------------+     return address.
  |  local array       |     the canary is a
  +--------------------+     WARNING, not a save.
  |  ... more locals   |
  +--------------------+  <- %rsp, the low end
   lower addresses
                </div>
                <p>So the honest description is: <strong>the canary converts a silent control-flow hijack into a loud, diagnosable abort, at the cost of three instructions per protected function.</strong> It is a detector, not a prevention mechanism, and it does not make the overflow not happen.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What It Does Not Catch, Measured</h2>
                <p>Three overflows, 200 bytes each, in two builds. The specimen has a global buffer, a function that overflows a global while holding a local, and a function with no local at all:</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/H2 /,/H3 /p'
     three overflows, 200 bytes each, two builds:
   case  gcc default (FORTIFY on, canary on)  canary only (FORTIFY off)
   a     buffer overflow                      NO DIAGNOSTIC
   b     buffer overflow                      stack smashing
   c     buffer overflow                      NO DIAGNOSTIC

  the two messages, which is how you tell them apart in the wild:
   canary:   *** stack smashing detected ***
   fortify:  *** buffer overflow detected ***
</pre>
                </div>
                <p><strong>Read the middle column against the right one.</strong> With FORTIFY switched off, the canary catches exactly one of the three: case <code>b</code>, the overflow of the function&rsquo;s <em>own local</em>. Cases <code>a</code> and <code>c</code> overflow a <em>global</em> &mdash; the damage never touches the frame, so the canary is intact and completely silent. That is not a bug in the implementation. It is what the mechanism is.</p>
                <p>And the left column is the surprise. <strong>In a default gcc build, FORTIFY catches all three</strong>, because <code>strcpy</code> into a known-size object is checkable wherever that object lives &mdash; frame or global, the compiler knows the size at compile time either way. So the two mechanisms are not redundant and they are not nested: they have genuinely different reach, and on this compiler both are on by default at <code>-O1</code>.</p>
                <p>The messages are the practical takeaway, because <strong>both mechanisms abort and the aborts look identical from a distance</strong>. Anyone debugging a crash needs to know which one fired, and the message is the only way to tell:</p>
                <div class="hex-dump">
                    <pre>  *** stack smashing detected ***   the CANARY tripped.
                                       The frame changed. Look for an
                                       overflow of a LOCAL in THIS function.

  *** buffer overflow detected ***   FORTIFY, at a __*_chk call.
                                       The length exceeded a size the
                                       COMPILER knew. It may be a global,
                                       a heap block, or a local.

  *** Segmentation fault ***       neither fired. The write went
                                       somewhere with no tripwire.
</pre>
                </div>
                <p>That last line is the uncomfortable one and it belongs in the table. <strong>The absence of a diagnostic is not evidence of safety</strong> &mdash; it is evidence that this particular tripwire was not on the path. The <a href="/courses/img/lessons/img-place">image course</a> already taught the <code>MAP_FIXED</code> lesson about tools that fail silently; this is the same shape in a different place.</p>
            </div>

            <div class="unit unit-example">
                <h2>Counting Tripwires From the File</h2>
                <p>There is no header field, no flag, no note for the stack protector. <strong>Its entire trace is an instruction pattern, so a posture reader has to look for the bytes.</strong> That is why <code>harden.py</code> does this:</p>
                <div class="formula">
  ncan = len(re.findall(rb'\x64[\x48\x49\x4c]..[\x25\x2d]', data))

  %fs:0x28 appears in two encodings:

    64 48 8b 04 25 28 00 00 00   mov %fs:0x28,%rax
    64 48 2b 04 25 28 00 00 00   sub %fs:0x28,%rax

  the 64 prefix is the FS segment override,
  48 is the REX.W for a 64-bit operation, and
  the 25 28 00 00 00 is the displacement 0x28
  encoded as a 32-bit absolute address -- which
  is why there is no register at all: an
  absolute address needs no base.
                </div>
                <p>The result is a number, and the number is the whole check. Zero tripwires in a binary with functions means no stack protector. Two tripwires means one. It is a coarse instrument &mdash; it cannot tell you <em>which</em> functions are protected &mdash; and it is stated as coarse in the artifact. <strong>But it is the only signal available, and it is enough to catch the default that <a href="/courses/sec/lessons/sec-defaults">the last concept</a> measured.</strong></p>
                <p>Which functions get instrumented is a separate question, and the answer is a heuristic the compiler applies, not a guarantee. <code>-fstack-protector</code> instruments every function with a frame. <code>-fstack-protector-strong</code> (gcc&rsquo;s default) instruments a narrower set: functions with a local array, or that take an address of a local, or that call <code>alloca</code>. <code>-fstack-protector-all</code> instruments everything with a frame. <strong>Measured on this machine, all three produce 2 references, and <code>-fno-stack-protector</code> produces 0 &mdash; because this specimen falls inside all three heuristics.</strong> A specimen that separated them would be a better demonstration, and the difference is worth knowing about rather than assuming: the flag names suggest a spectrum, and on a small function they do not differ.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/sec/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/H2 /,/H3 /p'
$ python3 harden.py can_gcc can_clang
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/H1/,/H3/p'
</pre>
                </div>
                <p>Then find where it stops working, which is the better exercise:</p>
                <div class="hex-dump">
                    <pre>  1. Write a function with a local array, and
     one WITHOUT, and one that only calls
     alloca. Count %fs:0x28 refs in each, under
     -fstack-protector, -strong and -all.
     (This is the experiment that separates the
     three heuristics. My first specimen did not
     separate them, because it satisfied all
     three at once -- so the ladder read as
     "no difference" when the real answer was
     "this function is inside every
     heuristic".)

  2. Recover the canary value at run time and
     print it. Then print it again from a
     SECOND thread. (Same value or different?
     The TCB is per-thread, so the answer is
     the more interesting of the two -- and
     the reason a canary is not a constant is
     that the attacker cannot read it.)

  3. Overwrite the canary yourself. Take
     probe_can, and in case b, write one byte
     PAST the local array before returning.
     You should get "stack smashing" on a
     single byte of overflow. (The tripwire is
     adjacent, not approximate. It fires on a
     one-byte overrun, which no bounds check
     would.)

  4. Now find an overflow the canary CANNOT
     see, on purpose: strcpy into a global from
     a function with no locals, compiled with
     -fno-stack-protector. Run it. (Silence.
     That is case c in the table, and producing
     it deliberately is the point.)

  5. Finally, make the tripwire fire on a
     DIFFERENT function's frame. Overflow a
     local in f() so far that it reaches g()'s
     saved return address. Which function
     reports it? (Whichever one's epilogue
     runs -- and that is a real property of
     this design: the diagnostic names a
     function that may not be the one with the
     bug.)
</pre>
                </div>
                <p>Exercise 5 has the best answer in the course and it is genuinely counter-intuitive. <strong>The diagnostic names whichever function&rsquo;s epilogue happens to run, which is frequently not the function with the bug.</strong> That is a direct consequence of placing the tripwire in the frame rather than at the overflow site &mdash; and it is why &ldquo;stack smashing detected&rdquo; tells you <em>that</em> a frame was disturbed and almost nothing about <em>where</em>. Anyone chasing one of these for a day has been misled by the function name in the message.</p>
                <p>Exercise 2 is the one that closes the security argument. <strong>Per-thread means the value is not a constant, and not-a-constant is the entire property.</strong> A canary that were a fixed global would be readable by any code in the process, and an attacker with a write primitive would simply restore it after overwriting the return address &mdash; turning the detector back off. The <a href="/courses/img/lessons/img-auxv">auxv&rsquo;s <code>AT_RANDOM</code></a> and the kernel&rsquo;s per-thread secret are what make the tripwire something the attacker cannot defuse, and that is a better reason for the design than &ldquo;it detects overflows&rdquo;.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The direct technical debt this pays is to the <a href="/courses/img/lessons/img-auxv">auxiliary vector concept</a>. That concept established that <code>AT_RANDOM</code> points at 16 bytes of kernel-supplied randomness on the initial stack, and noted that the value changes every run. <strong>The canary is the other end of that: the C runtime reads those bytes at startup and derives a per-thread secret, which is why <code>%fs:0x28</code> is non-zero and unpredictable without a single instruction of setup code.</strong> Two concepts, one mechanism, and the kernel is at the bottom of both. It is a good illustration of why the image course came first: a hardening feature you cannot explain is a flag, and a hardening feature you can explain is a design.</p>
                <p>The connection to <a href="/courses/sec/lessons/sec-fortify">FORTIFY</a> is the other half of this concept and the contrast is the useful part. <strong>The canary is a runtime detector over a whole frame; FORTIFY is a compile-time check at a specific call with a specific known size.</strong> That difference explains the entire H2 table: FORTIFY caught the global overflow the canary structurally cannot see, because the canary is a property of <em>where the check lives</em> (the frame) and FORTIFY is a property of <em>what the code says</em> (this copy, this size). Neither is better. They have different reach, and a hardened build wants both.</p>
                <p>Two connections to earlier courses, both about cost. <a href="/courses/reloc/lessons/reloc-encoding-limits">The relocations course</a> measured the price of position independence &mdash; one extra relocation per datum &mdash; and established the pattern this course repeats: <em>a security property costs something measurable, and the cost is the point of measuring it.</em> Five instructions and two relocations-worth of register pressure per protected function is a small price, and it is a price, and the honest thing is to name it rather than pretend the feature is free. The <a href="/courses/link/lessons/link-static-real">static linking course</a> measured the other extreme &mdash; <code>-static</code> at 52&times; &mdash; and a canary is <em>cheaper</em> than that, which is a useful reminder that &ldquo;more secure&rdquo; and &ldquo;more overhead&rdquo; are not the same axis.</p>
                <p>And the connection to the platform, briefly, because it is a real limitation. <strong>All of this is x86-64 System V.</strong> AArch64 spells the same idea <code>SP</code>; the per-thread secret lives at a different offset in a different register. The mechanism transfers and the encodings do not, which is why the posture reader counts a byte pattern rather than reading a header field &mdash; and why a reader who takes the <code>0x28</code> offset as universal will get a confident wrong answer on the second architecture. <a href="/courses/dwarf/lessons/dwarf-frames">The DWARF frame course</a> covers the register-encoding side of that for AArch64, and this course deliberately does not duplicate it.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/sec/lessons/sec-defaults">Previous: Three Layers, Two Answers</a></span>
                <span>Next: <a href="/courses/sec/lessons/sec-relro">The Two Tiers of RELRO</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
