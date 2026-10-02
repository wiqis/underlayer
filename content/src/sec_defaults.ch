// Executable Security and Hardening — Module 1: The Defaults
// Concept: codegen, linker, and driver decide hardening separately, and disagree.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sec_defaults() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Three Layers, Two Answers — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson sec-lesson">
            <a href="/courses/sec" class="back-link">Back to course</a>
            <h1>Three Layers, Two Answers</h1>
            <div class="lesson-meta">24 min &middot; Module 1: The Defaults &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>There are two hardening concepts in this collection already, and both are honest about what they are. <code>macho-hardening</code> covers NULL-page protection, ASLR and PIE on Mach-O. <code>pe-security-flags</code> covers <code>DllCharacteristics</code>: the ASLR bit, the NX bit, the CFG bit. <strong>Both are lists of flag names, on platforms this chain has not otherwise touched.</strong></p>
                <p>That is a real gap and it is not a small one. A flag name tells you the feature exists. It does not tell you whether the bit is set in your binary, whether the toolchain set it for you, or what the bit <em>does</em> when it is. So this course moves the same subject to x86-64 ELF and moves it down from names to bytes.</p>
                <p>And the first thing the measurement found is the reason the course exists. <strong>Here is one source file, compiled with <code>-O1</code> and no flags of any kind, by two compilers on this machine:</strong></p>
                <div class="hex-dump">
                    <pre>$ cd courses/sec/assets/samples &amp;&amp; ./build_samples.sh 2&gt;&amp;1 | sed -n '/H1/,/H2/p'
     no flags at all, -O1, identical source:
   clang        %fs:0x28 references = 0
   gcc          %fs:0x28 references = 2
</pre>
                </div>
                <p><strong>One of them emits a stack canary and the other does not.</strong> Same source. Same machine. Same command line, minus the compiler name. If you have a hardening policy written down, this is the first thing it has to answer, and the answer is not in your build system &mdash; it is in which compiler you happened to install.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>It gets worse, or better, depending on your temperament. Hardening is not decided in one place. <strong>Three separate decisions, made by three different pieces of software, any of which can differ between two machines running the same project.</strong></p>
                <div class="formula">
  1. CODEGEN   the COMPILER decides
               does it emit a stack canary?
               does it emit endbr64?
               does it turn strcpy into __strcpy_chk?

  2. LINKER    YOU decide, with flags
               -z relro   -z now   -z noexecstack
               -z execstack   -z text

  3. DRIVER    the compiler DRIVER decides
               which of those flags it passes
               to ld on your behalf, with no
               flag from you at all

  layer 3 is the one nobody thinks about,
  and it is the one that made the two
  binaries on the previous page differ in
  a second, independent way.
                </div>
                <p>Layer 3 is worth dwelling on because it is genuinely surprising as a category. <strong>The compiler driver is the program you invoke, and it decides which linker flags to add behind your back.</strong> Ask it:</p>
                <div class="hex-dump">
                    <pre>$ gcc -O1 -### -o /dev/null canary.c 2&gt;&amp;1 | grep -oE '\-z [a-z]+' | sort -u
  -z now
  -z relro
$ clang -O1 -### -o /dev/null canary.c 2&gt;&amp;1 | grep -oE '\-z [a-z]+' | sort -u
  (nothing)
</pre>
                </div>
                <p><strong>gcc's driver passes <code>-z relro -z now</code>. clang's passes nothing.</strong> So the gcc binary gets <em>full</em> RELRO and the clang binary gets only the implicit partial &mdash; and under clang a tail of the GOT stays writable. <a href="/courses/sec/lessons/sec-relro">The RELRO concept</a> measures exactly which bytes, and the reason it is eight bytes is the interesting part.</p>
                <p>The three layers are independent, which is what makes this a build-system problem rather than a compiler problem:</p>
                <div class="formula">
  "our policy is -fstack-protector-strong
   and -Wl,-z,now"

  read literally, that pins layer 1 and
  layer 2. it says NOTHING about layer 3.

  so two teams with the SAME written policy,
  on two distros, ship different binaries --
  and neither is wrong, and neither noticed.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>Measured, in the Files</h2>
                <p>Not in the driver flags &mdash; in the output. The artifact reads the two binaries with no compiler involved:</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/H8/,$p'
     what each driver passes to ld with NO flags of your own:
   gcc        -z now -z relro
   clang      nothing

     the consequence, in the FILES. Same source, same -O1, no flags:
   drv_gcc     RELRO tier full  covered by RELRO yes
   drv_clang   RELRO tier partial  covered by RELRO NO
</pre>
                </div>
                <p>Two hardening properties, from one source file and one command line:</p>
                <div class="hex-dump">
                    <pre>$ python3 harden.py drv_gcc 2&gt;/dev/null | sed -n '5,20p'
  stack executable?                  no   [PT_GNU_STACK flags RW-]
  RELRO region                       0x3da8..0x4000
  RELRO tier                         full
    .got.plt section                 absent
    covered by RELRO                 yes
  stack canary refs (%fs:0x28)       2

$ python3 harden.py drv_clang 2&gt;/dev/null | sed -n '5,20p'
  RELRO tier                         partial
    .got.plt section                 present
    covered by RELRO                 NO
  stack canary refs (%fs:0x28)       0
</pre>
                </div>
                <p><strong>Read those two blocks side by side.</strong> The gcc binary has a stack canary and full RELRO with the GOT entirely sealed. The clang binary has neither, and its <code>.got.plt</code> extends past the end of the read-only region. Neither team passed a hardening flag. One of them is substantially more hardened, by accident, because of which compiler is installed.</p>
                <p>And the canary count is 2 rather than 1, which is worth a moment. A canary is <em>read once and compared once</em>, so two references to <code>%fs:0x28</code> is one tripwire, not two. <a href="/courses/sec/lessons/sec-canary">The canary concept</a> takes the three instructions apart; here the point is only that the number is small and countable, which is what makes it measurable from the file at all.</p>
            </div>

            <div class="unit unit-example">
                <h2>Doing Something About It</h2>
                <p>The obvious move is to pass the flags explicitly, and that is correct and insufficient. The problem is that some of the decisions are not reachable by a flag you can add to a compiler command &mdash; they are defaults you have to check.</p>
                <div class="formula">
  the flags you CAN pin, and should:

    -fstack-protector-strong        layer 1
    -fcf-protection=full            layer 1
    -D_FORTIFY_SOURCE=3             layer 1
    -Wl,-z,relro -Wl,-z,now         layer 2
    -Wl,-z,noexecstack              layer 2
    -Wl,-z,ibtplt                   layer 2

  the decision you CANNOT pin, only check:

    does the driver add -z flags behind
    my back, and will it next year?

  you cannot turn that off. you can only
  MEASURE it -- and measuring is a script,
  which is module 4.
                </div>
                <p>So the practical answer has two halves, and the second half is the one teams skip. <strong>Pin what you can. Verify what you cannot.</strong> A one-line CI check that runs a posture reader over every binary you ship catches the whole class &mdash; a driver that changed, a distribution that changed a default, a new dependency built with different flags.</p>
                <p>That check is worth writing for a second reason. <strong>It is a regression test, and these flags are exactly the kind of thing that regresses silently.</strong> Nobody removes <code>-z now</code> on purpose. A build rule gets refactored, a link line gets rebuilt from variables, and one <code>-z</code> falls out &mdash; and the binary still compiles, still runs, and is quietly weaker. The symptom of that change is not a build failure. It is nothing at all, which is why it needs a test rather than a review.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/sec/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/H1/,/H2/p'
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/H8/,$p'
$ python3 harden.py drv_gcc drv_clang
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/H8/,/A /p'
</pre>
                </div>
                <p>Then go and find the rest of them:</p>
                <div class="hex-dump">
                    <pre>  1. Compile the same file every way you can
     and diff the postures:
       for cc in gcc clang; do
         $cc -O1 -o t_$cc canary.c
         python3 harden.py t_$cc | tail -2
       done
     Now add -fstack-protector-all to both and
     repeat. Which columns changed, and which did
     not? (The canary column changes. The RELRO
     column does NOT, because -fstack-protector
     is a codegen flag and RELRO is a LINK-time
     property. Two of the three layers are
     visible in that one experiment.)

  2. Ask each compiler what it thinks the
     default IS, from its own documentation on
     disk, and compare with what you measured:
       gcc -Q --help=common 2&gt;/dev/null | grep -i 'stack-protector\|fortify'
       clang -cc1 --help | grep -i 'stack-protector\|fortify'
     Did the documentation and the binary agree?
     (On this machine they do, and the course
     claims the measurement, not the docs.)

  3. Now the interesting one: what does
     -### say for a LINK that goes through a
     wrapper -- a response file, a cmake
     link.txt, a gold/lld invocation? Find the
     real link line in your build directory
     and read it. (This is where layer 3 hides
     when there are more than three layers.)

  4. Build the SAME source with -static and
     with -shared, both fully hardened, and run
     harden.py on each. Which checks still mean
     anything? (PIE is meaningless for the static
     one. RELRO still works. The canary is
     unaffected. A check that does not apply to
     your build type is a check that will
     eventually be reported as a FAILURE and
     then ignored -- so know which ones those
     are.)

  5. Take a real binary you did not build --
     /usr/bin/ls, or a system library -- and run
     harden.py on it. Then compare with what
     your distribution's hardening documentation
     claims. Any disagreement is either a
     documentation bug or a per-package build
     exception, and both are worth knowing about.
</pre>
                </div>
                <p>Exercise 1 is the one that makes the three-layer model concrete, and its result is counter-intuitive. <strong>Adding <code>-fstack-protector-all</code> fixes the canary column and leaves RELRO exactly where it was</strong>, because the canary is produced by the compiler and RELRO is produced by the linker. They are not two settings of one thing. That is why &ldquo;we enabled hardening&rdquo; is an incomplete sentence, and why the posture report has a row per layer rather than one score.</p>
                <p>Exercise 5 is the one that changes how you read a hardening claim. <strong>Run the reader on a binary you did not build and the answer will not match the distribution&rsquo;s hardening page</strong> &mdash; because most distributions apply hardening per package, and the packages are built by different rules. A hardening claim about &ldquo;the distribution&rdquo; is usually a claim about a subset, and the only way to know which subset is to read the binary.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept is the argument for the course, so it is worth being explicit about what it corrects. <a href="/courses/reloc/lessons/pie-randomize">The relocations course</a> measured randomisation and <a href="/courses/reloc/lessons/pie-flags">the PIE flags</a> taught that <code>-fPIE</code> and <code>-pie</code> are two different flags at two different layers. <strong>That is layer 1 and layer 2 of this model, already established &mdash; and the missing third layer is the one that made the two binaries on this page differ.</strong> PIE is a codegen decision; <code>-z now</code> is a link decision; whether either reaches the linker by default is a driver decision. Three questions where most people have one.</p>
                <p>The connection to the <a href="/courses/img/lessons/img-place">image-loading course</a> is mechanical and total. <strong>Everything this course hardens is something the kernel grants.</strong> <code>PT_GNU_STACK</code> is a <em>request</em> in a segment header, and the kernel decides whether to honour the execute bit. <code>PT_GNU_RELRO</code> is a range the loader tells the kernel to seal once relocation is done. The stack canary lives in the thread control block, which the <a href="/courses/img/lessons/img-auxv">kernel builds</a> and hands over in the auxv &mdash; which is why <code>%fs:0x28</code> is a fixed offset with no setup code: the C runtime reads it from there. <strong>A hardening feature that is not a kernel-granted permission is a compiler convention, and the two categories have different failure modes.</strong></p>
                <p>The connection to the <a href="/courses/dyn/lessons/dyn-bind-time">dynamic linking course</a> is a debt that <a href="/courses/sec/lessons/sec-relro">the RELRO concept</a> pays. That course measured that <code>.got.plt</code> disappears under <code>-z now</code> and correctly declined to say why. <strong>The reason is that under lazy binding the loader still has to <em>write</em> the resolved address into the GOT slot</strong> &mdash; so a page containing that slot cannot be read-only, and full RELRO is only possible once the loader has finished writing. The section did not disappear to save space. It disappeared because sealing it made it unnecessary.</p>
                <p>Two connections outward, both to concepts that exist and both at the flag level. <code>macho-hardening</code> and <code>pe-security-flags</code> list names; this course reads bits, and the first concept in each of those would be the same experiment run on a different platform. <strong>That is a good property of this course: the method transfers, and the specific findings do not.</strong> A reader who has learned to check rather than to trust will get the same value from a Mach-O or a PE binary, and that is the transferable skill &mdash; not the number <code>0x10000</code>, which is x86-64 Linux and nothing else.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/img/lessons/img-walk">Previous: Rebuilding the Image Reader</a></span>
                <span>Next: <a href="/courses/sec/lessons/sec-canary">The Canary and Its Limits</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
