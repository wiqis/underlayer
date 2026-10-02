// The x86-64 Machine: Privilege, Memory and Time — course landing page
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86sys_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The x86-64 Machine: Privilege, Memory and Time — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson x86sys-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>The x86-64 Machine: Privilege, Memory and Time</h1>
            <div class="lesson-meta">9 concepts &middot; 3 modules &middot; 231 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is</h2>
            <p>Seven neutral courses already taught this material &mdash; <code>priv</code> measured the privilege boundary, <code>mem</code> measured the cost of a page-table walk, <code>smp</code> measured the topology, <code>exe</code> measured the modes &mdash; and every one of them taught it <em>neutrally</em>, with x86-64 as the running example. The section plan is explicit about what that means: <em>&ldquo;the comparison lives in the neutral courses; the depth lives in the per-arch ones.&rdquo;</em> So this course re-derives no principle. It is the <strong>exhaustive x86-64 reference</strong> for eight roadmap items, and every one of the nine concepts is a table rather than an argument.</p>
            <p>And then there is the part no neutral course can own, which is what a user process is <em>allowed to find out</em> about the machine it is running on. <a href="/courses/priv/lessons/priv-harness">The privilege course</a> established three facts: a ring-3 process may read <code>SIDT</code>, it may not read the IDT, and the CPU has no <code>avx512f</code>. This course takes those three and makes them into a systematic inventory, in which every entry of the <em>cannot</em> column is a signal number produced by a forked child and every entry of the <em>can</em> column is a bit pattern read out of a register on this CPU.</p>
            <p>The set turned out not to be the one in the manual. Here is all fifty instructions, one forked child each, with what the kernel did:</p>
            <div class="hex-dump">
                <pre>$ ./sysdump | grep '^  EDGEREAD'
  EDGEREAD | sidt                           | si_code 0 | readable
  EDGEREAD | sgdt                           | si_code 0 | readable
  EDGEREAD | sldt                           | si_code 0 | readable
  EDGEREAD | str                            | si_code 0 | readable
  EDGEREAD | smsw                           | si_code 0 | readable
  EDGEREAD | rdtsc                          | si_code 0 | readable
  EDGEREAD | rdtscp                         | si_code 0 | readable
  EDGEREAD | xgetbv                         | si_code 0 | readable
  EDGEREAD | rdfsbase                       | si_code 0 | readable
  EDGEREAD | wrfsbase                       | si_code 0 | readable
$ ./sysdump | grep '^  EDGE | rows'
  EDGE | rows 50 | faulted 39 | returned 11 | si_code 128 34 | other 5
            </pre>
            </div>
            <p>Ten instructions return. <code>SIDT</code>, <code>SGDT</code>, <code>STR</code>, <code>SLDT</code> and <code>SMSW</code> are the group every answer gets wrong, and <code>XGETBV</code> is the sharpest of them: <strong>reading the register that decides which instructions you may execute is unprivileged, and writing it is not.</strong> Thirty-four instructions die with <code>si_code 128</code> and an address of zero, which is the kernel's way of saying <em>the CPU raised a #GP and there is nothing to point at</em>.</p>
            </div>

            <div class="unit unit-model">
                <h2>The idea: a consequence is not a reading</h2>
            <p>Every result in this course is a <strong>consequence</strong> of a bit in a register the process cannot read. It is tempting to conclude that <code>CR4.UMIP</code> is zero because <code>SIDT</code> returned, and that conclusion is reasonable and it is not what the measurement supports. The kernel can have <code>UMIP</code> set and still allow the instruction; the measurement is of the effect and the bit is in another building.</p>
            <div class="formula">
   SO HERE IS THE DISTINCTION, and it governs
   every table in this course.

   A CONSEQUENCE  something the process observed
                about the machine.
   A READING     the value of a bit in a register
                the process cannot read.

   A consequence narrows the set of possible
   readings.  A reading states one.

   This course reports the first kind and
   labels the second kind QUOTED, on every
   row, in every table.
            </div>
            <p>That is why the control-register tables in the fourth concept are printed separately from every measurement and stamped <code>NOT MEASURED</code>, and why the exception table has a column that says <code>MEASURED</code> on six rows and <code>QUOTED</code> on twenty-six. Six of thirty-two is a small number and it is the honest one.</p>
            <div class="formula">
   AND THE CONSEQUENCE IS NOT ALWAYS AS SHARP
   AS THE MANUAL SUGGESTS.

   Three page faults, three different events:

     write to NULL            si_code 1
     write to a PROT_READ     si_code 2
     touch a PROT_NONE        si_code 2

   The error code the CPU pushed has a WRITE
   bit and an INSTRUCTION bit in it.  A
   demand-paging system needs both.  Ring 3
   sees one bit: present, or not.
            </div>
            </div>

            <div class="unit unit-reality">
                <h2>The correction, and it is the course's reason for existing</h2>
            <p>This course was drafted with a central claim, and the claim is wrong in a way that makes it more useful than the right one would have been.</p>
            <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/6B\./,/6C\./p' | head -12
  6B. THERE IS NO COUNTER THIS PROCESS CAN OPEN.  Three ways in,
      all three refused, and none of them is a statement about the
      silicon.

  ABSENT | RDPMC in a forked child | si_code 128 | signal 11 | KILLED
  ABSENT | perf_event_open, a NULL attr | -1 | errno 13 | EACCES
  ABSENT | open /dev/cpu/0/msr | DENIED | errno 13 | EACCES: root only
  ABSENT | and yet CPUID.80000008.EBX bit 6 core-PMU = 1 and
  ABSENT | bit 15 L3-PMU = 1, so the METAL HAS PERFORMANCE
  ABSENT | MONITORS and this process is not allowed to read them.
            </pre>
            </div>
            <p>The draft said <em>this machine has no performance monitoring hardware.</em> It has some. <code>CPUID.80000008.EBX</code> bit 6 says the core PMU is there and bit 15 says the L3 PMU is there, in the same breath in which <code>RDPMC</code> is a fault, <code>perf_event_open</code> is <code>EACCES</code> and <code>/dev/cpu/0/msr</code> is root-only. The right sentence is about <strong>access</strong>, and it is a better one because it is falsifiable: it names the permission that is missing, and a claim that cannot name the thing that would fix it is not making a claim.</p>
            <ul>
                <li><strong>A feature bit is a fact about the CPU that any process can read</strong> with an unprivileged instruction. The absence of <code>avx512f</code> is declared by the hardware. The absence of the counters is imposed by software. Two absences, two different kinds, and conflating them is how &ldquo;this CPU cannot be profiled&rdquo; gets written in a document instead of &ldquo;this process cannot read the counters&rdquo;.</li>
                <li><strong>The register is readable; the table is not.</strong> <code>SIDT</code> returns the IDT's base and limit from ring 3. Reading one byte at that base kills a forked child with <code>si_code 1</code> and an <code>si_addr</code> that is <em>exactly the base the instruction printed</em>. That is the shape of a mapping failure, not of a #GP &mdash; so the reason the IDT is unreadable is a page-table fact, and it predicts an address the sentence &ldquo;the IDT is privileged&rdquo; could never have predicted.</li>
            </ul>
            <p>There are <strong>ten retractions</strong> in this course, all printed by the artifact in its section 7 and all asserted as text by the harness, so a taken-back claim can be neither quietly dropped nor edited into being right. Two of them are harness failures rather than conceptual ones, and both are the most instructive things in the file.</p>
            </div>

            <div class="unit unit-example">
                <h2>Three results that could not have been found any other way</h2>
            <ul>
                <li><strong>The 16-byte arm of the canonical sweep measured an alignment rule while claiming to measure a canonical boundary.</strong> The C statement was <code>*(volatile __int128 *)a</code> and gcc compiled it to <code>movdqa</code> &mdash; an alignment-requiring load. The sweep then reported <code>si_code 128</code> for every address that was not 16-byte aligned, at every offset, which is a table with a pattern in it and no rule behind it. Written as inline <code>movdqu</code> the same sweep gives <code>2^47 - 15</code>, the value the rule predicts, and section 5 prints both arms side by side.</li>
                <li><strong>The upper canonical half begins at <code>0xffff800000000000</code>, and not at <code>0xffffffff80000000</code>.</strong> Everybody who has read that hexadecimal number in a kernel log has believed the half starts there. It is 2<sup>31</sup> bytes <em>inside</em> it. The first version of this course asserted it; the version after bisecting for the boundary found <code>0xffff800000000000</code> on all five access widths, and the retraction is printed in the artifact with both numbers beside it.</li>
                <li><strong>Only <code>R11</code> survives a Linux system call as destroyed, and the ISA promises exactly that.</strong> The first version of the thirteen-register table reported <strong>all fifteen clobbered</strong> &mdash; and it was the harness talking, not the CPU: the inline-asm block asked for fourteen outputs, gcc was holding the address of one of them in a register the body had already overwritten, and the program died with <code>SIGBUS</code>. A wrong answer that agrees with a plausible story is the hardest kind to catch.</li>
            </ul>
            <p>And one result is a measurement of an <em>absence</em>, which is the hardest kind to present: an untouched <code>mmap</code> region has <strong>no page-table entry at all</strong>, and the entry appears at the first touch. <code>mprotect</code> alone changes nothing. That is demand paging seen from the inside, through one kernel interface, and it is the only direct observation of the paging mechanism in this whole collection.</p>
            </div>

            <div class="unit unit-apply">
                <h2>What this course will not claim, and what is deferred</h2>
            <p>Printed in the artifact's own limits block rather than footnoted, because a limit that is a footnote is a limit that gets forgotten. There are <strong>no cycle counts at all</strong>:</p>
            <ul>
                <li><strong>No cycle counts, and no event counts of any kind.</strong> <code>perf_event_paranoid</code> is 4, <code>RDPMC</code> is a fault, <code>perf_event_open</code> is <code>EACCES</code>. Every duration in the artifact is a <em>duration</em>, and a duration bounds a count without measuring it. The instrument that would settle it is <code>perf_event_open</code> with a paranoid setting below 4 and a PMU passthrough from the host.</li>
                <li><strong>Whether <code>SMEP</code> and <code>SMAP</code> are on.</strong> <code>arch_prctl(ARCH_GET_XCOMP_PERM)</code> returns <code>0x207</code> and the kernel's report is all ring 3 has. A user process cannot execute a supervisor page to find out, because there are none to execute.</li>
                <li><strong>The <code>IA32_STAR</code>, <code>IA32_LSTAR</code> and <code>IA32_SFMASK</code> values.</strong> <code>RDMSR</code> is a fault and <code>/dev/cpu/0/msr</code> is root-only, both measured. The vDSO's bytes are a weaker source and the privilege course already used them.</li>
                <li><strong>The class of any exception.</strong> Fault, trap and abort differ in where the saved RIP points, and a ring-3 process never sees a saved RIP: the kernel does not put it in the <code>siginfo</code>. Every class in the table is <code>QUOTED</code>.</li>
                <li><strong>Which <code>DR7</code> layout this CPU implements.</strong> Two descriptions disagree, the artifact prints both, and <code>DR7</code> is unreadable from ring 3. A five-line <code>ptrace</code> program at CPL 0 would settle it.</li>
                <li><strong>The <code>PS</code> bit of a real 2 MiB mapping.</strong> <code>MAP_HUGETLB</code> returned <code>ENOMEM</code> and no transparent huge page collapsed during the run, so the 4 KiB path is the only one measured.</li>
                <li><strong>AArch64, RISC-V, and every other architecture.</strong> Quoted, not run, and deliberately absent: <a href="/courses/mem/lessons/mem-hierarchy">the memory course</a> and <a href="/courses/priv/lessons/priv-harness">the privilege course</a> own the comparison, and this one is the x86-64 reference.</li>
            </ul>
            <p>The completion criterion is not &ldquo;read it&rdquo;. It is: <em>reproduce the 214 checks, then break a positive control on purpose. Add a fourteenth register to the <code>syscall</code> marker block without naming it in that block's clobber list, and the artifact dies with <code>SIGBUS</code> instead of a number &mdash; which is exactly the bug that produced retraction R4.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>What comes before, and what comes next</h2>
            <p>Before. <a href="/courses/priv/lessons/priv-harness">The privilege course's harness concept</a> is the prerequisite rather than a link: it measured that <code>SIDT</code> returns and that the IDT does not, and this course turns that one asymmetry into fifty instructions. <a href="/courses/priv/lessons/priv-vectors">Its vector concept</a> printed the thirty-two numbers as a summary; the second concept here prints them with a class, an error-code flag and a source column, and the vendor census is asserted as a partition. <a href="/courses/mem/lessons/mem-instrument">The memory course's harness</a> measured the cost of a walk, and <a href="/courses/smp/lessons/smp-harness">the multiprocessor course's</a> measured the topology: both are <em>why</em>, and neither answers <em>which bits</em>.</p>
            <p>Forwards, and there is a shape here worth naming. The first five concepts are the machine's <strong>mode</strong> &mdash; what changes privilege level and what reads the mode. The next two are <strong>memory</strong>, and the surprising thing about them is that the boundary reappears as an <em>address</em>: the privilege check that fails is not a privilege check at all but a canonicality check on the bytes of an operand. The last two are <strong>time</strong>, and they are where the inventory becomes a lesson about what measurement is available at all.</p>
            <p>Outward. The fourth course in this section, on the x86-64 data path, inherits one thing from this course and one thing from the assembly course: the AVX-512 feature bits that the eighth concept here reads as all zero are the same zero the AVX-512 concept has to work around, and the <code>movdqa</code> trap that retraction R2 caught is the same class of problem as a misaligned vector store being a fault rather than a slowdown.</p>
            </div>

            <div class="lesson-footer">
                <span>Start: <a href="/courses/x86sys/lessons/x86-syscall">SYSCALL and the Four Registers It Touches</a></span>
                <span>End of The x86-64 Machine &middot; <a href="/courses">all courses</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
