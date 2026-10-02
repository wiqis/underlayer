// Executable Security and Hardening — course landing page
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sec_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Executable Security and Hardening — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson sec-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>Executable Security and Hardening</h1>
            <div class="lesson-meta">7 concepts &middot; 4 modules &middot; 167 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
                <p>There are two hardening concepts in this collection already. <a href="/courses/macho/lessons/macho-hardening">Mach-O hardening</a> covers NULL-page protection, ASLR and PIE. <a href="/courses/pe/lessons/pe-security-flags">PE security flags</a> covers <code>DllCharacteristics</code>: the ASLR bit, the NX bit, the CFG bit. Both are honest, and <strong>both are lists of flag names on platforms this chain has not otherwise touched.</strong></p>
                <p>A flag name tells you a feature exists. It does not tell you whether the bit is set in your binary, whether your toolchain set it for you, or what the bit <em>does</em> when it is. So this course moves the same subject to x86-64 ELF and moves it down from names to bytes. And the very first measurement shows why that was necessary:</p>
                <div class="hex-dump">
                    <pre>$ cd courses/sec/assets/samples &amp;&amp; ./build_samples.sh 2&gt;&amp;1 | sed -n '/H1/,/H2/p'
     no flags at all, -O1, identical source:
   clang        %fs:0x28 references = 0
   gcc          %fs:0x28 references = 2
</pre>
                </div>
                <p><strong>One source file. <code>-O1</code>. No flags of any kind. One compiler emits a stack canary and the other does not</strong> &mdash; and they disagree twice more, on the linker flags their drivers pass and on whether FORTIFY is on at all. Seven concepts in four modules:</p>
                <div class="formula">
  MODULE 1  The Defaults
            three layers -- codegen, linker, driver --
            and two compilers that disagree on all three
            the stack canary: %fs:0x28, three
            instructions, and the overflow it cannot see

  MODULE 2  The GOT
            the two tiers of RELRO, the page
            arithmetic, and the eight writable bytes
            FORTIFY: a compile-time fact turned into
            a runtime argument, visible in the imports

  MODULE 3  Permissions
            W^X: the stack's execute bit, and the
            section that made TEXTREL nearly extinct
            CET: endbr64 is present whether or not
            the binary asks for enforcement

  MODULE 4  Read It Yourself
            parse a binary's posture with no
            toolchain, and know which source each
            check read
</div>
            </div>

            <div class="unit unit-example">
                <h2>Every number here was measured</h2>
                <p>Toolchain and limits, up front: <strong>gcc 15.2.0 and clang 21.1.8 on the same machine, GNU ld 2.46, glibc 2.43, x86-64 Linux.</strong> Two compilers is not a limitation here &mdash; it is the subject. <strong>No AArch64 machine was available, so nothing is claimed about a second architecture</strong>, and no kernel source was read, so every claim is observational. Both limits are in <code>research.md</code> rather than smoothed over.</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/H3/,/H4/p'
   partial  -Wl,-z,relro             0x000208 present    none
   full     -Wl,-z,relro,-z,now      0x000230 ABSENT     BIND_NOW,FLAGS_1),

   partial     RELRO 0x403df8..0x404000  ends on a page: YES
            .got.plt 0x403fe8..0x404008  CROSSES the RELRO end: YES
                                          -&gt; 8 bytes stay writable
</pre>
                </div>
                <p>Three findings carry the course. <strong><code>-z relro</code> is a no-op on this toolchain</strong> &mdash; the linker already emits the segment, at the same size, so there are two states and not three. <strong>The RELRO range always ends on a page boundary</strong>, so <code>-z now</code> extends it backwards rather than forwards. And <strong>the <code>.got.plt</code> crosses that boundary by eight bytes</strong> &mdash; and those are the lazy-binding slots the loader still has to write, which is precisely why full RELRO is only possible once resolution is done first.</p>
                <p>And the one that is easiest to get wrong: <code>endbr64</code> is present in a binary built with CET explicitly <em>disabled</em>. Five of them, all from the distribution&rsquo;s pre-hardened <code>crt1.o</code> and <code>crti.o</code>. <strong>Enforcement comes from a property note the kernel reads, not from the instructions.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>The artifact</h2>
                <p>One reader, no toolchain. It parses the ELF header, the program headers, the section table, the dynamic array, the string table and a note with <code>struct.unpack_from</code> and nothing else:</p>
                <div class="hex-dump">
                    <pre>$ python3 harden.py relro_partial
  stack executable?                  no   [PT_GNU_STACK flags RW-]
  RELRO tier                         partial
    .got.plt section                 present
    covered by RELRO                 NO
    ends on a page                   yes
  stack canary refs (%fs:0x28)       0
  FORTIFY _chk imports               none
  CET IBT (indirect branch tracking) False
  position independent               NO (ET_EXEC)
  WEAKNESSES: NOT PIE, partial RELRO only, no stack canary
</pre>
                </div>
                <p>That fourth line is the one that makes it a tool. Not &ldquo;partial&rdquo;, which is a label the file claims about itself, but the geometric fact that the GOT does not fit inside the sealed range. <strong>Every check names the source it read</strong>, because a check that reads the same byte twice and calls it two checks is worse than no check &mdash; and two of the eight features (the canary and FORTIFY) leave no header field at all, so a tool built on the assumption that hardening is a set of flags reports nothing about the two most widely deployed features in the world.</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh     # 8 finding groups, from empty
$ python3 crosscheck.py  # re-derives every claim: 60 checks
$ python3 harden.py &lt;any binary&gt;
</pre>
                </div>
            </div>

            <div class="unit unit-example">
                <h2>What was retracted</h2>
                <p>Three claims did not survive measurement, and all three are in <code>research.md</code> and asserted in the crosscheck rather than quietly corrected.</p>
                <p><strong>&ldquo;A known-size destination gives you <code>__memcpy_chk</code>.&rdquo;</strong> It does not on clang 21 &mdash; <code>strcpy</code> becomes <code>__strcpy_chk</code> reliably, <code>memcpy</code> did not even with a statically known 4096-byte destination, and the rule was not determined from source. <strong>&ldquo;A global overflow is not caught.&rdquo;</strong> Wrong in a default build: FORTIFY caught it. The canary did not. That correction turned a single-mechanism concept into the two-mechanism comparison that is now the most useful table in the course. And <strong>&ldquo;five <code>endbr64</code> therefore CET is enabled&rdquo;</strong> &mdash; wrong, and the counting method was retracted with it.</p>
                <p>Plus five bugs in the tooling itself, kept because they are the lesson. <strong>The posture reader hung on the first real binary</strong> because a note entry of size 0 advances a loop by nothing &mdash; and for a security tool a hang is the worst available outcome, because no answer looks nothing like a wrong answer. <strong>The crosscheck read the file offset where it meant the address</strong>, and four checks reported true claims as false; a check that fails for the wrong reason is worse than no check, because it teaches you to ignore it. And <strong>two checks searched for driver flags in the wrong stream</strong> &mdash; <code>-###</code> prints to stderr &mdash; so they found nothing, which is indistinguishable from never having run.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Start Here</h2>
                <p>If you want the surprise first, go to <a href="/courses/sec/lessons/sec-defaults">Three Layers, Two Answers</a>. If you want the artifact, go to <a href="/courses/sec/lessons/sec-posture">Reading a Binary&rsquo;s Posture</a> and run it on a binary you did not build.</p>
                <p>Either way the thing to take away is not a list of flags. It is that <strong>hardening is decided in three places by three different pieces of software, only two of which you control, and the only way to know what a binary has is to read the binary</strong> &mdash; which is the same conclusion the whole chain has been arriving at since the first hex dump, and the reason this course ends with a reader instead of a recommendation.</p>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
