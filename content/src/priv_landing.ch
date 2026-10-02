// Exceptions, Privilege and Mode Changes — course landing page
public namespace underlayer_content {

using std::string

using std::string_view

public func render_priv_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Exceptions, Privilege and Mode Changes — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    // THE PRE-PAINT THEME.  This landing page calls render_lesson_nav, which
    // passes lesson=true and therefore skips the theme script -- correct for a
    // LESSON, whose palette is hardcoded light, but wrong here: this is a
    // course landing page and a reader who chose dark, or whose OS is dark,
    // should not get a flash of light before the page settles.
    //
    // Two lines, and the alternative is to change what these 28 pages call --
    // a layout change across the whole collection that is worth doing on its
    // own and is not what the flash report asked for.
    render_theme_boot_js(&mut page, false)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson priv-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>Exceptions, Privilege and Mode Changes</h1>
            <div class="lesson-meta">8 concepts &middot; 4 modules &middot; 204 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
                <p><a href="/courses/exe/lessons/exe-latency">The CPU-execution course</a> finished by measuring a loop: a dependent chain costs 2.7&times; an independent operation, and the cost of an operation is a number of core clock cycles. <a href="/courses/mem/lessons/mem-hierarchy">The memory-hierarchy course</a> then followed an address all the way down to DRAM, and ended by naming the thing a process may not do: <em>&ldquo;a course about mode changes starts where the permissions to read those files stop.&rdquo;</em> <strong>This is that course.</strong> It is about the instant a program asks for something it cannot do itself.</p>
                <p>The scope check is unusually clean. A word-boundary grep over every concept file the two preceding courses left behind:</p>
                <div class="formula">
  `ring 0`      0 files     `ring3`         0 files
  `GDT`         0 files     `IDTR`          0 files
  `CR3`         0 files     `CR0`           0 files
  `CPL`         0 files     `RPL`           0 files
  `DPL`         0 files     `IOPL`          0 files
  `TSS`         0 files     `EFER`          0 files
  `sysret`      0 files     `iret`          0 files
  `sysenter`    0 files     `context switch` 0 files

  `privilege`   4 files — three are unrelated senses
                    (prepositions, JVM inner classes,
                     Mach-O "unprivileged")
  `syscall`     4 files — as an ENCODING, as a noun in
                    the vDSO lesson, and as a call the
                    ELF loader makes. None teaches the
                    boundary itself.

  Every word in the title of this course appears
  zero times, except "privilege", which appears four
  times and means something else in three of them.
                </div>
                <p>So this is not a course that covers a gap. It is a course that fills a hole, and the difference matters: there is no prior material to reconcile, and equally nothing in the collection so far has told you this exists. <strong>That is why the collection needs it before it needs a compiler backend</strong> &mdash; a compiler that emits object files is halfway to a compiler that runs, and the run starts here.</p>
            </div>

            <div class="unit unit-model">
                <h2>The one measurement that makes the course</h2>
                <p>Every course before this one has asked a question like &ldquo;how many times more does A cost than B?&rdquo; This course asks a sharper one, and the answer is not a number in the usual sense:</p>
                <div class="hex-dump">
                <pre>$ cd courses/priv/assets/samples &amp;&amp; ./build_samples.sh
      SYSCALL, getpid               1238.5
      int $0x80, getpid             6095.6
      libc getpid()                 1236.5

      SYSCALL, clock_gettime        1668.8
      vDSO  clock_gettime             60.4

      int80 / syscall                 4.92x
      syscall-clock / vdso-clock     27.65x
</pre>
                </div>
                <p>Look at the second pair. <strong>Same function, same argument, same answer</strong> &mdash; the only difference is whether the CPU changed privilege level on the way. That ratio <em>is</em> the cost of a mode change, measured with everything else held constant. <strong>And the first pair is a trap, not a result:</strong> the obvious explanation for <code>int $0x80</code> being 5&times; slower is that it does one I/O port access per argument &mdash; which is true of the Linux i386 entry stub, but the port accesses are executed by the <em>kernel's handler</em>, not by the <code>INT</code> instruction. This course names that as a hypothesis and declines to call it a finding, because the measurement cannot separate the hardware entry from the two different kernel stubs behind it.</p>
                <p>The 27&times; is also the whole reason the vDSO exists, and it is why <code>clock_gettime</code> in a real program costs tens of nanoseconds rather than hundreds.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The second measurement, which is the one nobody expects</h2>
                <p>Every course in this collection that has touched addresses has said a canonical address has bits 63:48 all equal. That is wrong, or rather: it is not a complete rule, and the incompleteness is a measurement.</p>
                <div class="hex-dump">
                <pre>$ ./privbench | sed -n '/address  *1 byte/,/THE RULE/p'
   address                    1 byte   4 byte   8 byte
   2^47 -10 0x00007ffffffffff6       1        1        1
   2^47  -7 0x00007ffffffffff9       1        1      128
   2^47  -4 0x00007ffffffffffc       1        1      128
   2^47  -3 0x00007ffffffffffd       1      128      128
   2^47  -1 0x00007fffffffffff       1      128      128
   2^47  +0 0x0000800000000000     128      128      128

      1-byte  first rejected address 0x0000800000000000   2^47 minus it = 0
      4-byte  first rejected address 0x00007ffffffffffd   2^47 minus it = 3
      8-byte  first rejected address 0x00007ffffffffff9   2^47 minus it = 7
</pre>
                </div>
                <p><strong>The boundary is 2<sup>47</sup> minus the width of the access, minus one.</strong> An 8-byte read fails seven bytes below 2<sup>47</sup>; a 1-byte read succeeds right up to it. The CPU validates the whole byte range of an operand and not merely its first byte. Three independent bisections agree, and the rule they add up to is exact.</p>
                <p>It matters because this is the reason a non-canonical access <em>is not a page fault</em>. It never becomes an address: there is no page-table entry to consult and no address to report. The kernel hands the process <code>SIGSEGV</code> with an <code>si_addr</code> of <strong>zero</strong>, and the only thing that distinguishes it from an ordinary unmapped read is one field of <code>siginfo</code>. <strong>A fault handler that reads <code>si_addr</code> before checking <code>si_code</code> concludes the process dereferenced a null pointer.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>The gap this course exists to close, and what is deferred</h2>
                <p>The five prior courses in this chain cover how a file is produced and where its bytes go. None covers what the machine does when a program asks for something it cannot do itself &mdash; not the file (that is <a href="/courses/img">Executable Images</a>), not the flags that guard the file (that is <a href="/courses/sec">Security and Hardening</a>), and not the instruction encoding (that is <a href="/courses/isa">the ISA</a>). <strong>This is the layer in between, and it is the last one before &ldquo;the program is running.&rdquo;</strong></p>
                <p>What is deliberately <strong>not</strong> claimed here, and is stated as a limit by the artifact rather than footnoted:</p>
                <ul>
                    <li><strong>No exception class is measured.</strong> Deciding whether a vector is a fault, a trap or an abort requires the saved instruction pointer, and a ring-3 process never sees one. The class column in this course is quoted from the manuals, and the artifact says so in the same breath.</li>
                    <li><strong>No error code is read.</strong> A user process gets the kernel's translation of the 32-bit word the CPU pushed &mdash; one signal and one <code>si_code</code>. This course measures exactly how much survives that gap, and it is less than you would hope: four different protection failures are indistinguishable.</li>
                    <li><strong>SMEP and SMAP are reported, not verified.</strong> The CR4 bits are privileged, so there is no user-mode experiment. The course prints the kernel's answer and labels it a report.</li>
                    <li><strong>The <code>IA32_STAR</code>, <code>IA32_LSTAR</code> and <code>IA32_SFMASK</code> values are not read.</strong> <code>/dev/cpu/0/msr</code> is root-only. The convention is recovered from the vDSO's bytes instead, which is a different and weaker source, and the course says which.</li>
                    <li><strong>AArch64 and RISC-V are quoted, not run.</strong> There is no such machine here. Every claim about them is a manual claim with a document number, and the whole module exists to teach the <em>shape</em> so that a reader can recognise it on hardware they do have.</li>
                </ul>
                <p>One more thing is deferred on purpose. <code>int $0x80</code> is measured here as a <em>mechanism</em>, and this machine runs it because it is a virtualised guest with i386 compatibility enabled. A bare-metal kernel, or one built without <code>CONFIG_IA32_EMULATION</code>, raises <code>#UD</code> instead. The course does not claim otherwise.</p>
            </div>

            <div class="unit unit-connect">
                <h2>What comes before, and what comes next</h2>
                <p>Before: <a href="/courses/isa/lessons/isa-decode">the ISA course's decoder</a> gives you the bytes of an instruction and nothing about what it may do; <a href="/courses/exe/lessons/exe-frontend">the execution course's frontend</a> gives you what the core does with them in user mode; <a href="/courses/img/lessons/img-vdso">the executable-images course's vDSO concept</a> already introduced the very page this course reads the kernel's calling convention out of, and noted that entering a syscall is expensive to <em>enter</em> without saying why. <a href="/courses/sec/lessons/sec-cet">The security course</a> named CR4 bits as flags on a file and never asked who reads them. <strong>Four forward references, none of them answered anywhere before this.</strong></p>
                <p>After: the roadmap's remaining CPU-architecture courses are <em>Multiprocessor Architecture</em> and <em>SIMD and Vector Processing</em>. The first is named as deferred in the memory course's own limits block, which is the correct place for a course to say what it is not covering: that course is where cache coherence, NUMA and the true meaning of a &ldquo;shared&rdquo; line get their answer, and false sharing &mdash; the one coherence-adjacent effect the memory course could measure &mdash; is explicitly not enough of one. The second has a different shape entirely: it is about widening the data path, not about crossing a boundary, and it is worth reading afterwards precisely because so much of this course is about what a single core may not do.</p>
                <p><strong>The one sentence to carry forward:</strong> a program may <em>locate</em> the kernel's gate table and may not <em>read</em> it, and every number in this course is downstream of that asymmetry.</p>
            </div>

            <div class="lesson-footer">
                <span>Start: <a href="/courses/priv/lessons/priv-table">A Table You Can Locate and Not Read</a></span>
                <span>End of Exceptions, Privilege and Mode Changes &middot; <a href="/courses">all courses</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
