// Executable Security and Hardening — Module 3: Permissions
// Concept: the stack's execute bit, and the section that made writable text
// segments unnecessary.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sec_wx() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("W^X, and Why TEXTREL Died — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson sec-lesson">
            <a href="/courses/sec" class="back-link">Back to course</a>
            <h1>W^X, and Why TEXTREL Died</h1>
            <div class="lesson-meta">23 min &middot; Module 3: Permissions &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every hardening feature so far has been about making something <em>unwritable</em>: the GOT, the canary&rsquo;s frame. This one is the other direction, and it is the oldest idea in the set: <strong>a page of memory should be either writable or executable, never both.</strong> The reason is not abstract. A write primitive plus an executable page is arbitrary code execution; either one alone is much less.</p>
                <p>On Linux the mechanism is a single bit in a segment header, and it is worth being precise about which bit, because there are two and they are different things.</p>
                <div class="hex-dump">
                    <pre>$ cd courses/sec/assets/samples &amp;&amp; ./build_samples.sh 2&gt;&amp;1 | sed -n '/H5/,/H6/p'
  PT_GNU_STACK flags, which is the stack's permission request:
   default  0x000000 RW 0x10
   noexec   0x000000 RW 0x10
   exec     0x000000 RWE 0x10
  (the flags column is RWE -- the 'E' is executable STACK)
</pre>
                </div>
                <p><strong>One bit, and it is a request.</strong> <code>PT_GNU_STACK</code> is a program header that says &ldquo;when you map the stack, use these permissions&rdquo;, and the kernel is free to grant less. On this system the default is <code>RW</code>, so the stack is not executable, and <code>-Wl,-z,execstack</code> is the flag that gives it away.</p>
                <p>So the practical check is one character in one segment header, and the practical advice is: <strong>grep your build system for <code>execstack</code> and be suspicious when you find it.</strong> It is a flag that exists for two legitimate reasons &mdash; a JIT, and hand-written shellcode &mdash; and it is also the kind of thing that gets copied between projects until nobody remembers why it is there.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>W<sup>^</sup>X has two halves, and the second one is the interesting half because <strong>it is a historical problem that has been solved so thoroughly that it has almost disappeared from the vocabulary.</strong></p>
                <div class="formula">
  W^X, half 1: the STACK

    a function that maps shellcode onto the
    stack and jumps to it needs the stack
    to be executable. so:

      shellcode  --> [w]rite to stack
                 --> [x]ecute from stack

    break either link and the chain dies.
    PT_GNU_STACK breaks the second.

  W^X, half 2: the TEXT SEGMENT

    a RELATIVE relocation in a shared library
    writes a pointer value into a segment.
    if that segment is READ-ONLY (because it
    holds code or constants), the loader
    cannot apply the relocation.

    the old resolution: let the loader write
    to the text segment, and record that fact
    in the file with a DT_TEXTREL tag so
    everyone knows this library is special.

    the cost: a shared library that needs
    TEXTREL is a library that CANNOT be fully
    write-protected, ever, and every consumer
    of it inherits that.
                </div>
                <p>Half 2 is the interesting one because it is a genuine historical accident that got fixed, and the fix is a section name. <strong>When the linker knows a segment will be written during load but should be read-only afterwards, it puts the contents in <code>.data.rel.ro</code></strong> &mdash; &ldquo;relocatable data, read-only&rdquo; &mdash; places it in a segment that is writable during load, and lets <a href="/courses/sec/lessons/sec-relro">RELRO</a> seal it once the loader is done.</p>
                <div class="formula">
  the loader needs to write a pointer here
              |
              v
    not .rodata    -- the segment is R-only
                      and always will be
    not .data      -- writable forever, so no
                      protection at run time
    .data.rel.ro   -- writable DURING load,
                      sealed by RELRO after
                </div>
                <p>That third option is the whole trick, and it is why <code>TEXTREL</code> is nearly extinct. <strong>The loader always had somewhere legal to write; the only question was whether the linker gave it a section there.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>The Experiment That Failed, and Why That Was the Result</h2>
                <p>So: try to build a shared library that needs a text relocation. The obvious specimen is a table of pointers to string literals, which is exactly the case <code>TEXTREL</code> existed for.</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/H5/,/H6/p'
   TEXTREL in the plain build:        0
   TEXTREL even with -z text:         0
   -z text refused to link:           no

   TEXTREL could not be forced, and the reason IS the finding:
     [13] .rodata           PROGBITS   0000000000002000 002000 000011 01 AMS
     [18] .data.rel.ro      PROGBITS   0000000000003e20 002e20 000018 00  WA
     GNU_RELRO      0x002e10 0x0000000000003e10 0x0000000000003e10 0x0001f0 0x0001f0 R   0x1
</pre>
                </div>
                <p><strong>The experiment failed, and the failure is the finding.</strong> Passing <code>-z text</code> &mdash; which tells the linker to <em>refuse</em> any text relocation &mdash; did not refuse anything, because there were none to refuse. The pointer table went to <code>.data.rel.ro</code> instead of <code>.rodata</code>.</p>
                <p>And the arithmetic confirms it, which is the check worth writing:</p>
                <div class="hex-dump">
                    <pre>$ python3 - &lt;&lt;'PY'
    .data.rel.ro   0x3e20..0x3e38  INSIDE  RELRO range 0x3e10..0x4000
    .rodata        0x2000..0x2011  OUTSIDE RELRO range 0x3e10..0x4000
    .got           0x3fc8..0x3fe8  INSIDE  RELRO range 0x3e10..0x4000
  PY
</pre>
                </div>
                <p><code>.data.rel.ro</code> is inside the sealed range. <code>.rodata</code> is outside, and always will be. <strong>So the section is writable at exactly the moment the loader needs to write it, and read-only at exactly the moment anybody might want to.</strong> That is the entire mechanism, and it is the same &ldquo;writable during load, sealed after&rdquo; idea that <code>RELRO</code> applies to the GOT &mdash; doing a second job on a data section.</p>
                <p>So the honest statement about <code>TEXTREL</code> is this: <strong>it is a tag you will rarely see, and the reason is a linker feature rather than a policy.</strong> A reader who went looking for it and concluded &ldquo;my library is safe because it has no <code>TEXTREL</code>&rdquo; has proved very little &mdash; the absence is the default, not the achievement. The useful check is the positive one: is the pointer table in <code>.data.rel.ro</code>, and is that section inside the <code>RELRO</code> range?</p>
            </div>

            <div class="unit unit-example">
                <h2>Checking It</h2>
                <p>Both halves of W<sup>^</sup>X are one field and one section, and the artifact reads both:</p>
                <div class="formula">
  # half 1: the stack
  gs = seg(PT_GNU_STACK)
  stack_exec = bool(gs.flags &amp; PF_X)      # PF_X == 1

  # half 2: is anything writable that should not be?
  d = dict(dynamic())
  textrel = d.get(DT_TEXTREL, 0)

  # and the positive version, which is the one that means something:
  dro = section('.data.rel.ro')
  relro = seg(PT_GNU_RELRO)
  inside = dro.addr &gt;= relro.vaddr
           and dro.addr + dro.size &lt;= relro.vaddr + relro.memsz
                </div>
                <p>Note the asymmetry, which is the transferable part. <strong>&ldquo;No <code>TEXTREL</code>&rdquo; is a weak claim; &ldquo;<code>.data.rel.ro</code> is inside <code>RELRO</code>&rdquo; is a strong one.</strong> The first is the absence of a marker, and the absence of a marker is the default. The second states the positive property that actually provides the protection, and it would catch a linker that emitted the section outside the sealed range.</p>
                <p>That is the same habit the <a href="/courses/sec/lessons/sec-relro">RELRO concept</a> taught with <code>covered by RELRO</code> rather than <code>tier</code>, and the same habit the <a href="/courses/img/lessons/img-entries">image course</a> taught by checking a mapped address against a file offset rather than trusting a value. <strong>Check the geometry, not the label.</strong> Three courses, three mechanisms, one rule.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/sec/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/H5/,/H6/p'
$ python3 harden.py wx_default wx_exec
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/H5/,/H6/p'
</pre>
                </div>
                <p>Then look for the cases the model does not cover:</p>
                <div class="hex-dump">
                    <pre>  1. Find a REAL library that still emits
     TEXTREL. Not on this system -- try
     searching a large /usr/lib for the tag:
       for f in /usr/lib/x86_64-linux-gnu/*.so*; do
         readelf -dW "$f" 2>/dev/null | grep -q TEXTREL &amp;&amp; echo "$f"
       done
     When you find one, check whether its
     .data.rel.ro is inside its RELRO. (A
     library can have BOTH: TEXTREL for the
     leftovers and RELRO for the rest, and
     the tag tells you which parts are still
     exposed.)

  2. Make the stack executable on purpose and
     run code from it. Write a function that
     writes shellcode to a local buffer and
     calls it, build once with
     -Wl,-z,execstack and once without, and
     observe: the second one SEGFAULTS. (That
     is PT_GNU_STACK being enforced, and it is
     the clearest demonstration in the course
     of a header field changing what the
     hardware will do.)

  3. Now the modern replacement. Most JITs
     no longer need an executable stack --
     they mmap a page with PROT_READ|PROT_WRITE
     and mprotect it to PROT_READ|PROT_EXEC
     after writing. Write one and read its
     /proc/self/maps lines. (It shows up as
     an r-xp region with no file, exactly
     like the vDSO from the img course. The
     kernel grants execute permission for a
     SPECIFIC range, which is W^X-compatible in
     a way an executable stack never was.)

  4. Check a JIT you use. If it is on this
     system, look for rwxp or rwx in
     /proc/PID/maps. A region that is
     simultaneously writable and executable
     is a region where W^X has been suspended,
     and it is worth knowing which and why.

  5. Finally, the check that will save you
     time: grep a whole source tree for
     execstack.
       grep -rn 'execstack' --include=Makefile --include='*.mk' .
     (Expect the hits to be in a JIT, a
     shellcode test, or a copy-paste. The
     fourth kind is a project that enabled it
     in 2015 to fix one problem and never
     turned it off -- and nobody can now say
     what would break.)
</pre>
                </div>
                <p>Exercise 3 is the most important one, because it shows that the flag is a <em>historical</em> mechanism rather than a permanent necessity. <strong>A JIT today does not need an executable stack; it allocates a page, writes, and asks for execute permission on that page alone.</strong> That is strictly better than an executable stack &mdash; the permission is narrow and temporary rather than global and permanent &mdash; and it means the <code>-z execstack</code> hit in a modern codebase is far more likely to be legacy than necessary. The exception is hand-written shellcode, where the shellcode genuinely arrives on the stack.</p>
                <p>Exercise 1 is the one that makes the historical claim concrete, and the answer on a current system is usually <em>nothing</em>, or a handful of exotic libraries. <strong>That absence is the achievement, and it was an accident of a linker feature rather than a security decision.</strong> Which is a good note to end the concept on: the strongest result in this area came from giving the loader somewhere better to write, not from asking anyone to be careful.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept closes a loop that <a href="/courses/link/lessons/link-default-script">the linker-script course</a> opened without being able to close. That course found the default script&rsquo;s rule for <code>.got.plt</code> and noted that the section can be empty on this toolchain. <strong>It could not say why a section would be emptied, and the answer is here: a linker that resolves everything eagerly has no lazy-binding table to give a section.</strong> The link between &ldquo;which sections exist&rdquo; and &ldquo;which protections are available&rdquo; is not obvious until you see that <code>-z now</code> changes both, and it is the same flag in both cases.</p>
                <p>The connection to <a href="/courses/img/lessons/img-place">Where the Kernel Put Everything</a> is about who grants. <code>PT_GNU_STACK</code> is a <em>request</em> and the <a href="/courses/img/lessons/img-place">same concept that measured the <code>MAP_FIXED</code> floor</a> measured that a hint below <code>0x10000</code> is simply relocated rather than refused. <strong>W<sup>^</sup>X is therefore a request, not a guarantee, and the kernel is entitled to grant less than you asked for.</strong> That is the correct design &mdash; a security policy that the kernel can tighten unilaterally is a policy that survives kernel updates &mdash; but it means a reader should check what was granted in <code>/proc/&lt;pid&gt;/maps</code>, not what was requested in the file. <a href="/courses/img/lessons/img-entries">The image course&rsquo;s central lesson</a> again: the file and the running process are different objects.</p>
                <p>Two connections outward. <a href="/courses/dyn/lessons/dyn-dlopen">The <code>dlopen</code> concept</a> is where this bites in practice: loading a library you did not audit gives it <code>MAP_FIXED</code>, and a library with an executable stack hands you a page you can write and execute. <strong>That is the argument for a plugin sandbox, and it is an argument about permissions rather than about validation.</strong> And the <a href="/courses/macho/lessons/macho-hardening">Mach-O hardening concept</a> covers the same guarantee on a different platform &mdash; it names NULL-page protection, which is the Darwin spelling of the <code>mmap_min_addr</code> floor the image course measured. Same idea, different kernel, and the fact that two kernels converged on the same defence is a decent argument that it is the right one.</p>
                <p>One honest limit. <strong>Nothing here was measured on AArch64, and the <code>PT_GNU_STACK</code> bit is portable while <code>.data.rel.ro</code> is a linker convention.</strong> The mechanism transfers; the spelling may not. The course claims the mechanism, the specific offsets, and the specific section name, and stops there.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/sec/lessons/sec-fortify">Previous: FORTIFY Leaves a Trace</a></span>
                <span>Next: <a href="/courses/sec/lessons/sec-cet">CET: The Instructions Are Not the Request</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
