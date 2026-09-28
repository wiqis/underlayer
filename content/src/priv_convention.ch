// Exceptions, Privilege and Mode Changes — Concept 4: the convention
public namespace underlayer_content {

using std::string

using std::string_view

public func render_priv_convention() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Convention, in the Kernel's Own Bytes — Underlayer")
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
            <h1>The Convention, in the Kernel's Own Bytes</h1>
            <div class="lesson-meta">23 min &middot; <a href="/courses/priv">Exceptions, Privilege and Mode Changes</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Every tutorial of the x86-64 system-call ABI opens with the same table: number in <code>RAX</code>, arguments in <code>RDI</code>, <code>RSI</code>, <code>RDX</code>, <code>R10</code>, <code>R8</code>, <code>R9</code>, answer in <code>RAX</code>, clobbered registers <code>RCX</code> and <code>R11</code>. Where does that table come from?</p>
                <p><strong>Not from Intel.</strong> Not from AMD. Not from any architecture manual. There is no such concept as a &ldquo;system call number&rdquo; in the x86-64 architecture, and if you search the SDM for the phrase you will find nothing. It is a <em>Linux</em> decision, and it is a decision made for a reason that is visible once you see which registers the hardware already took.</p>
                <p>That distinction is the point of this concept, and it is worth being pedantic about because conflating the two produces a specific and common error: writing a syscall wrapper that sets the carry flag on error, because that is what the i386 ABI did, and then wondering why your x86-64 program reports errors wrongly.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: two facts from the architecture, five from the kernel</h2>
                <p>Sort the convention into what the hardware guarantees and what a particular operating system chose, and the second list turns out to be nearly everything.</p>
                <div class="formula">
   FROM THE ARCHITECTURE (Intel and AMD agree):

     RCX  receives the instruction pointer of the
          instruction AFTER the syscall.
     R11  receives the flags as they were before the
          syscall, before any masking.

   That is ALL the architecture says.  There is no
   number, no argument list, and no error convention.

   FROM LINUX:

     RAX        the syscall number going in, the
                return value coming out
     RDI RSI    arguments 1, 2
     RDX        argument 3
     R10        argument 4      <-- not RCX
     R8  R9     arguments 5, 6
     negative errno in RAX on failure
     CF is NOT set on error
                </div>
                <p><strong>Why <code>R10</code> and not <code>RCX</code> is the whole story in one fact.</strong> The System V AMD64 calling convention &mdash; the C ABI, which your compiler already implements &mdash; assigns the first six integer arguments to <code>RDI</code>, <code>RSI</code>, <code>RDX</code>, <code>RCX</code>, <code>R8</code>, <code>R9</code>. The hardware then takes <code>RCX</code> and <code>R11</code> for its own bookkeeping. If the syscall convention followed the C ABI, a four-argument syscall would collide with the return address. <strong>So the kernel routed around its own calling convention</strong>, and put the fourth argument in <code>R10</code>, a register the C ABI does not use for arguments in this position and which is free precisely because the hardware took <code>RCX</code> instead.</p>
                <p>This is worth understanding as a design constraint rather than a fact to memorise: <strong>every part of the syscall ABI is downstream of the two registers the instruction stole.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: read it out of the machine</h2>
                <p>There is a better source than either manual, and it is a file the kernel maps into every process: the vDSO. It contains real kernel-compiled code that issues real system calls, and it is readable from user mode. <a href="/courses/img/lessons/img-vdso">The executable-images course</a> read its ELF header. This course reads its instructions.</p>
                <p>The opcode for <code>syscall</code> is <code>0f 05</code> &mdash; two bytes, and <a href="/courses/isa/lessons/isa-opcodes">the ISA course's decoder</a> already knows that. So: find those two bytes in the vDSO's executable segment, and look at the five bytes before each one.</p>
                <div class="hex-dump">
                <pre>$ ./privbench | sed -n '/Scanning the executable segment/,/decoded/p'
   Scanning the executable segment for 0f 05, the SYSCALL opcode:

      vaddr 0x0ab2   b8 e4 00 00 00 0f 05
       .......
      `mov $228, %eax ; syscall`  ->  clock_gettime

      vaddr 0x1031   b8 60 00 00 00 0f 05
       .`.....
      `mov $96, %eax ; syscall`  ->  gettimeofday

      vaddr 0x12f5   b8 e5 00 00 00 0f 05
       .......
      `mov $229, %eax ; syscall`  ->  clock_gettime64

      vaddr 0x15c3   00 00 4c 89 ce 0f 05
       ..L....

      vaddr 0x1600   00 00 00 31 d2 0f 05
       ...1...

      5 SYSCALL instruction(s) in 6667 bytes of vDSO code, 3 decoded
</pre>
                </div>
                <p>Five <code>syscall</code> instructions in the vDSO, three of which are unambiguously a five-byte immediate load into <code>EAX</code> immediately before the instruction. The numbers are 228, 96 and 229. <strong>Check them against <code>asm/unistd_64.h</code>: they are <code>clock_gettime</code>, <code>gettimeofday</code> and <code>clock_gettime64</code>. Three of them, exactly right, in the kernel's own encoding, read out of a page a user process is allowed to read.</strong></p>
                <p>The other two sites are not decoded, and the artifact says so rather than inventing a number for them: in both, the immediate is being loaded somewhere other than <code>EAX</code>, and a bare <code>b8</code> byte occurring nearby is a one-in-256 coincidence, not an instruction. <strong>Only two of the five facts about this convention come from the architecture, and this measurement recovers three kernel-chosen numbers without consulting a single manual.</strong></p>
                <h3>An absence, reported as an absence</h3>
                <p>The obvious thing to look for is the <em>sigreturn trampoline</em>: the code that returns from a signal handler, which on older kernels lived in the vDSO as <code>mov $15, %eax ; syscall</code>. <strong>It is not in this build.</strong> Linux removed the vDSO sigreturn path years ago, and a correct decoder reports that:</p>
                <div class="hex-dump">
                <pre>$ ./privbench | sed -n '/No sigreturn trampoline/,/lies/p'
      No sigreturn trampoline in this build: Linux removed the vDSO
      sigreturn path, and a decoder that printed 15 here anyway,
      from a pattern that merely happened to be nearby, is a decoder
      that lies.  This file reports the absence instead.
</pre>
                </div>
                <p>This is a small thing with a large lesson attached. <strong>The first draft of this concept's decoder did print 15</strong> &mdash; it looked for <code>b8</code> five bytes before each <code>0f 05</code> and printed whatever it found, and on a build with a trampoline it would have been right, so the code looked fine. It found a plausible-looking number on a build that had no trampoline, and there was nothing to distinguish the two cases. Matching the <em>exact</em> byte pattern <code>b8 0f 00 00 00 0f 05 0f</code> instead of a heuristic makes the absence detectable, which is the only way to know the difference between &ldquo;found it&rdquo; and &ldquo;looked for it.&rdquo;</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the symbol that pointed at the wrong image</h2>
                <p>Before the numbers above could be read, the program had to find the vDSO. It got the wrong pointer for a while, and the failure was instructive.</p>
                <div class="hex-dump">
                <pre>$ ./privbench | sed -n '/where does the vDSO pointer come from/,/recur silently/p'
   where does the vDSO pointer come from?
      __ehdr_start (the MAIN EXECUTABLE) 0x00005cb8d9644000  e_phnum=14
      AT_SYSINFO_EHDR (the vDSO)          0x00007465da26f000
      Two different images, and the one with the obvious name is not
      the one this section is about.  Print both or you will debug the
      wrong header, which is what this file did first.
</pre>
                </div>
                <p><code>__ehdr_start</code> is a glibc symbol holding the base of the ELF header of the <strong>main executable</strong>. It is not the vDSO, and the name is not a hint that it might be. The first version of this section read it, printed fourteen program headers and an <code>e_shoff</code> that pointed past the end of the text, and reported every one of those as a fact about the vDSO. <strong>Every one of them was true, and every one of them was about the wrong image.</strong></p>
                <p>Why so easy to get wrong? Because the two images are almost identical in shape. Both are <code>ET_DYN</code>, both are <code>EM_X86_64</code>, and both carry a plausible fourteen-entry program header table. The vDSO is a shared object; a position-independent executable is a shared object. <strong>When a decoder reports something surprising about a file, check that you are looking at the file you meant before you investigate why the file is strange.</strong> The artifact now prints both addresses on adjacent lines so the confusion cannot recur quietly.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Confirm the convention from your own machine.</strong> Run the artifact and compare the three decoded numbers against <code>/usr/include/x86_64-linux-gnu/asm/unistd_64.h</code>. Then disassemble your own libc: <code>objdump -d /lib/x86_64-linux-gnu/libc.so.6 | grep -B3 syscall</code> and find the same pattern. <strong>How many distinct syscall numbers can you account for, and what are the ones you cannot yet name?</strong></li>
                    <li><strong>Explain the <code>R10</code> decision in one sentence, without using the word &ldquo;because.&rdquo;</strong> Then explain why the sixth argument is <code>R9</code> and not something else, given the C ABI runs out of registers at the same place. <em>(It does not: the C ABI has <code>RDI RSI RDX RCX R8 R9</code> and the syscall convention has <code>RDI RSI RDX R10 R8 R9</code> &mdash; six in both cases, with exactly one substitution, and the substitution is the collision.)</em></li>
                    <li><strong>Write the wrapper and get the error convention wrong on purpose.</strong> Write a <code>syscall()</code> wrapper that checks the carry flag, compile it, and use it to call a syscall that fails. <strong>Now work out why it reports success.</strong> Then fix it, and write down which convention is x86-64 and which is i386.</li>
                    <li><strong>Find a fourth fact in the vDSO that the architecture does not specify.</strong> You have three syscall numbers already. Look for what the vDSO code does with the <em>return</em> value &mdash; how does it test for an error, and what does it assume about the flags on return? <strong>Compare that with what the SDM's <code>SYSCALL</code> page says about the return value. Is the SDM silent, or does it say something?</strong></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Forward, <a href="/courses/priv/lessons/priv-canonical">the canonical-address concept</a> is the other half of what makes ring 3 ring 3. This one covered the entry; that one covers the space you enter from.</p>
                <p>Backwards, the dependency is tight and worth naming. <a href="/courses/priv/lessons/priv-doors">The doors concept</a> established that <code>SYSCALL</code> performs no CPL check and reads three MSRs; this concept established that the register the architecture <em>does</em> specify &mdash; the number &mdash; is one the architecture never mentions. Together they say something a single fact could not: <strong>the architecture's half of a system call is a stack switch and two register moves, and the operating system's half is everything else.</strong></p>
                <p>To earlier courses, three of them. <a href="/courses/img/lessons/img-vdso">The vDSO concept</a> established that the page exists, is 8&nbsp;KB, has no file behind it, and is where the clock lives. <a href="/courses/img/lessons/img-auxv">The auxiliary-vector concept</a> established that <code>AT_SYSINFO_EHDR</code> is how you are told where it is &mdash; and, characteristically, that no libc function returns it. <a href="/courses/isa/lessons/isa-decode">The ISA course's decoder</a> is what made <code>0f 05</code> a thing you could search for. <strong>Three courses, one page, and not one of them ever read a byte of its code.</strong></p>
                <p>Outward, for the compiler author this is the concept that matters most, because it is the one place where <em>the ABI is the operating system's ABI and not yours</em>. A calling convention is something a compiler and a library agree on and can version. A system-call convention is something a kernel and every binary ever compiled against it agree on, and it can never be changed. <strong>When you emit a call to <code>syscall</code> you are emitting something that will outlive the kernel, and the reason <code>R10</code> is in the fourth slot is a decision made in 2003 about two registers.</strong></p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/priv/lessons/priv-doors">Four Ways In, and One of Them Is Not a Door</a></span>
                <span>Next: <a href="/courses/priv/lessons/priv-canonical">The Hole Has No Fixed Address</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
