// The x86-64 Machine — Concept 8: the performance monitoring architecture
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_pmu() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Performance Monitoring Architecture — Underlayer")
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
                    <button onclick="closeShortcuts()" class="a11y-close">Close</button>
                </div>
            </div>
            <div class="reading-controls">
                <label>Font: <select id="font-size" onchange="setFontSize(this.value)"><option value="small">Small</option><option value="medium" selected>Medium</option><option value="large">Large</option></select></label>
                <label>Spacing: <select id="line-height" onchange="setLineHeight(this.value)"><option value="compact">Compact</option><option value="normal" selected>Normal</option><option value="relaxed">Relaxed</option></select></label>
                <label>Letters: <select id="letter-spacing" onchange="setLetterSpacing(this.value)"><option value="tight">Tight</option><option value="normal" selected>Normal</option><option value="loose">Loose</option></select></label>
                <label>Width: <select id="content-width" onchange="setContentWidth(this.value)"><option value="narrow">Narrow</option><option value="normal" selected>Normal</option><option value="wide">Wide</option></select></label>
            </div>
            <h1>The Performance Monitoring Architecture</h1>
            <div class="lesson-meta">24 min &middot; <a href="/courses/x86sys">The x86-64 Machine</a></div>

            <div class="unit unit-why">
                <h2>Why this matters, and why this concept is mostly reference</h2>
                <p>Every number in the previous seven concepts that you would want to compare &mdash; instructions retired, cycles elapsed, branches taken, cache misses, mispredictions &mdash; comes from the performance monitoring architecture. A processor that cannot count its own events cannot be understood by measurement, only by reading about it. That is the situation on this machine, and the honest thing is to say so at the top of the concept rather than to build five pages of numbers and then footnote that they came from a manual.</p>
                <p>So this concept is <strong>reference material with the absence proved</strong>. The counters and events are quoted and marked. The <em>absence</em> is measured three ways, and the third of those ways is the one that made the course's original sentence wrong.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: architectural counters, and the vendor event lists on top of them</h2>
                <p>The architecture provides four things, and they are enough to build any profiler on any machine:</p>
                <ul>
                    <li><strong>General-purpose counters</strong> &mdash; a small number of 64-bit registers (four on Intel, six on this AMD part) that count an event you select by writing a control register, not by a number in an instruction. The event is chosen by writing an <em>event-select MSR</em>, and the MSR number and the event number are <strong>vendor-specific</strong>.</li>
                    <li><strong>Fixed counters</strong> &mdash; two or three counters wired to a fixed event. On Intel they count instructions retired, reference cycles and unhalted core cycles; on AMD the equivalent trio is the same idea with different names. These are the counters a profiler reaches for first precisely because they are architectural.</li>
                    <li><strong>A way to read them</strong> &mdash; the <code>RDPMC</code> instruction, whose permissiveness is a single bit: <code>CR4.PCE</code>. Clear, and <code>RDPMC</code> is a <code>#GP</code> at any CPL above zero.</li>
                    <li><strong>A way to get the count out of the kernel</strong> &mdash; the <code>perf_event_open</code> system call, which is Linux rather than architecture, and whose permissiveness is a separate number: <code>/proc/sys/kernel/perf_event_paranoid</code>.</li>
                </ul>
                <div class="formula">
   AND THE ONE BIT THAT MATTERS MOST, which
   is not on this page.

   CR4.PCE, bit 8: "if 1, RDPMC can be
   executed at any privilege level".

   That is a design decision with a
   security argument on both sides and it
   goes the way this course's measurement
   shows it going.  A counter that a user
   program can read is a side channel:
   BRANCH PREDICTOR, and shared-cache
   occupancy, and the timing of a
   dependent-load chain all become
   observable by counting.  So RDPMC from
   ring 3 is a #GP, and the event-counting
   interface that remains is a system call
   that asks the kernel.

   The second question -- how often MAY a
   process count -- is a policy setting and
   not an architectural one, which is why
   the third concept's boundary table has
   RDPMC in it and this page has three
   different permission systems stacked
   on top of one another.
                </div>
                <p>The vendor event lists are where a profiler's portability problems live, and the reason is not that they are long. <strong>It is that an event number is a claim about a stepping-level silicon part and the numbering has holes, renumberings and reserved ranges.</strong> On a given family the core events are stable; across a family boundary they are not. Any document that presents &ldquo;the x86 performance events&rdquo; as a list is presenting one vendor's list, and the more useful table is the one that says which vendor.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: three ways in, all three refused, and the metal is present</h2>
                <p>This is the section that matters, and it is short:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/6B\./,/6C\./p' | head -14
  6B. THERE IS NO COUNTER THIS PROCESS CAN OPEN.  Three ways in,
      all three refused, and none of them is a statement about the
      silicon.

  ABSENT | RDPMC in a forked child | si_code 128 | signal 11 | KILLED
  ABSENT | perf_event_open, a NULL attr | -1 | errno 13 | EACCES
  ABSENT | open /dev/cpu/0/msr | DENIED | errno 13 | EACCES: root only
  ABSENT | and yet CPUID.80000008.EBX bit 6 core-PMU = 1 and
  ABSENT | bit 15 L3-PMU = 1, so the METAL HAS PERFORMANCE
  ABSENT | MONITORS and this process is not allowed to read them.
  ABSENT | A first draft of this course said 'this machine has
  ABSENT | no PMU'.  The right sentence is about ACCESS, and it
  ABSENT | is a better one because it is falsifiable: it says
  ABSENT | which permission is missing, and a page that cannot
  ABSENT | name the missing permission is not making a claim.
                </pre>
            </div>
                <p>Three refusals, three <em>different</em> mechanisms, and they have to be read together with the two CPUID bits that follow.</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | grep -E 'paranoid|core-PMU|EBX 0x'
  /proc/sys/kernel/perf_event_paranoid = 4
  CPUID | 0x80000008 | EBX 0x191ef657 | core-PMU 1 L3-PMU 1
                </pre>
            </div>
                <ul>
                    <li><strong><code>RDPMC</code> in a forked child: killed by signal 11, <code>si_code 128</code>.</strong> A <code>#GP</code> with an empty error code, exactly like every other privileged instruction in the boundary table. <code>128</code> is the kernel's way of saying the CPU raised a general-protection fault and there is no address to report &mdash; which is why a counter that does not exist and a counter you may not read are the same signal.</li>
                    <li><strong><code>perf_event_open</code>: <code>EACCES</code>.</strong> The kernel's own interface, refused by policy. <code>perf_event_paranoid = 4</code> is the setting: at 4 a process may not count hardware events at all without privileges, and this one did not have them. <strong>This is a number a user process can read and a knob a user can ask to be changed &mdash; which is the difference between this refusal and the one above it.</strong></li>
                    <li><strong><code>/dev/cpu/0/msr</code>: <code>EACCES</code>, root only.</strong> The third door, and the one that would have given the event-select MSRs. A process that could read an MSR could program a counter directly and bypass every <code>perf</code> policy, which is why the file is root-only and why <code>perf_event_paranoid</code> cannot be used to open it.</li>
                    <li><strong>And yet <code>core-PMU = 1</code> and <code>L3-PMU = 1</code>.</strong> The silicon has performance monitors. The <code>perfctr_core</code> and <code>perfctr_nb</code> flags were in the <code>flags</code> line of <code>/proc/cpuinfo</code> before this course started, and CPUID says so in the same word that says <code>RDPMC</code> is not permitted.</li>
                </ul>
                <div class="formula">
   THE CORRECTION, and it is retraction R7.

   DRAFT      "this machine has no
               performance monitoring
               hardware"

   MEASURED   the hardware HAS core and L3
               performance monitors, and
               this process is not permitted
               to read them, by three
               separate mechanisms

   The two sentences have different
   consequences, and that is the whole
   reason the second is better.  The
   first says the instrument does not
   exist, so there is nothing to arrange.
   The second says the instrument exists
   and names the permission: raise
   perf_event_paranoid, or grant
   CAP_PERFMON, or pass a PMU through
   from the host.  One is a dead end and
   one is a ticket.

   And the general form is the one this
   course has now used twice: an ABSENCE
   OF ACCESS and an ABSENCE OF HARDWARE
   look identical from inside a process,
   and they are diagnosed by asking
   CPUID -- which is unprivileged -- and
   not by trying harder.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked: what the TSC can and cannot stand in for</h2>
                <p>With no counters, every timing in this course has come from the time-stamp counter, and section 1 measured its rate twice before making a claim about anything:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/TSC rate, busy/,/apart/p'
  TSC rate, busy                    2.2957 GHz
  TSC rate, across a 300 ms sleep   2.2957 GHz
  drift                             -0.0006 %
  pinned to cpu3, and the cpu that answered is 3  (VERIFIED -- the rows below are a controlled experiment)
  POINTER CHASE, 64 KiB of nodes    5.725 ticks/op
  ARITHMETIC increment loop         1.198 ticks/op
  the floor used for every band in this file is the POINTER CHASE,
  because the increment loop is printed too and is the CLOCK rather
  than noise: 4.78x apart.
                </pre>
            </div>
                <p>Three things in that block are load-bearing, and the first is the one nobody checks.</p>
                <ul>
                    <li><strong>The TSC is invariant, and that was measured rather than assumed.</strong> Busy and across a 300&nbsp;ms sleep, the same rate to within 0.0006&nbsp;%. <strong>A TSC tick is therefore TIME, and every figure derived from it is a ratio and not a cycle count.</strong> A processor that slept for 300&nbsp;ms and came back with a different rate would make every constant in this course a function of the machine's load, and the measurement is what licenses the use.</li>
                    <li><strong>Two floors, and only one of them is noise.</strong> A pointer chase waits on a load, so the core clock is not in the measurement; an arithmetic loop is bounded by the core clock, so a frequency ramp reads as a 60&nbsp;% &ldquo;noise&rdquo; that is really the clock. The chase is the floor and the loop is <em>the clock</em>, and saying so is the difference between a noise band and an instrument.</li>
                    <li><strong>Placement was verified from inside the process.</strong> The CPU that answered is read back with <code>sched_getcpu()</code> after pinning, and the artifact prints whether the two agreed. A benchmark that pins and does not check has measured a distribution over the machine and called it a measurement of the code.</li>
                </ul>
                <p>And here is the honest accounting of what the TSC can replace. <strong>It can bound a count and it cannot measure one.</strong> If a change makes a program 2.00&times; slower, the TSC says so; whether the extra is instructions, cache misses or branch mispredictions is a question only a counter can answer, and this machine has none that this process can read. A duration is evidence of a <em>cost</em> and never of a <em>mechanism</em>, and the four previous courses in this collection that measured mechanisms &mdash; the ISA course's branch-versus-<code>cmov</code> result, the vector course's gather cost, the memory course's TLB reach, the SMP course's true-sharing number &mdash; all had to mark the mechanism <code>INFERRED</code> for exactly this reason.</p>
                <div class="formula">
   WHAT THE INSTRUMENTS ACTUALLY BUY, on a
   machine with an invariant TSC and no
   readable counters.

   TSC   MEASURES   elapsed time
         and therefore BOUNDS any count,
         because a program cannot retire
         more events than it has ticks
         multiplied by some rate you do not
         know.

   TSC   CANNOT     separate two programs
                    that take the same time
                    for different reasons, and
                    therefore cannot tell you
                    WHY anything got slower.

   So a claim of the form "this instruction
   is N times cheaper" is a claim a TSC
   can make, and a claim of the form "this
   instruction retires fewer events" is
   not, and a course that has only the
   first kind of instrument should say so
   on every page that uses it rather than
   in a footnote at the end.
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Read the paranoid value and decide what it licenses.</strong> <code>cat /proc/sys/kernel/perf_event_paranoid</code> and then read the kernel's documentation for that value. <em>(Expect 4 to mean no hardware counting without privileges, and expect 2 to mean per-process counting with a kernel restriction. The number is a policy and a policy can be changed, which is the whole point of the retraction: an instrument that is switched off is not an instrument that is absent.)</em></li>
                    <li><strong>Check whether the metal has a PMU before you write a lesson about its absence.</strong> <code>grep perfctr /proc/cpuinfo</code> and <code>CPUID.80000008:EBX</code> bits 6 and 15. <em>(Expect both to say the counters exist. A course that teaches &ldquo;this CPU cannot be profiled&rdquo; from a <code>perf</code> failure has taught a property of a configuration file, and the difference shows up the moment somebody profiles the same program on a laptop.)</em></li>
                    <li><strong>Measure the TSC rate the way the artifact does, and then deliberately break the measurement.</strong> Time a busy loop with <code>clock_gettime</code> and a <code>sleep</code>, compare the two rates, and then repeat with a <code>nanosleep</code> whose duration you got wrong. <em>(Expect the first pair to agree and the second to print a rate that is a function of your own denominator. A denominator you chose is not a clock, and this is the one mistake in the instrument section that a reader can make themselves in five minutes.)</em></li>
                    <li><strong>Compare what a TSC can and cannot tell you about one function you know the answer to.</strong> Take a loop with a data-dependent branch, one with the same instruction count and no branch, and time both. <em>(Expect them to differ, because the branch mispredicts and the TSC sees the difference. Then ask what it would take to find out <em>how many</em> mispredicts, and answer: a branch-miss counter, which this process cannot read. The observation is free and the explanation is not, and that asymmetry is the concept.)</em></li>
                    <li><strong>Find where in your own codebase a claim rests on an event count rather than a duration.</strong> <em>(Expect to find comments that say &ldquo;fewer instructions&rdquo; rather than &ldquo;faster&rdquo;, and expect that every one of them was written by somebody with better access than a student has. The honest move is to rewrite them as a duration, because a duration is the claim you can check, and to say which mechanism the duration is consistent with and which it rules out.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, and this concept is downstream of the fourth: <strong><code>CR4.PCE</code> is bit 8 of the register whose every other bit is unreachable from ring 3</strong>, and this is the one place in the course where a bit in that table decides whether an entire category of measurement is available. <a href="/courses/x86asm/lessons/x86-flags">The assembly course's flags concept</a> is where <code>RDTSC</code> itself is a two-byte instruction with a serialising property; the CPUID bits here are in the same family of small unprivileged instructions that report the machine's shape.</p>
                <p>Forwards, and this is the hinge of the course's last third. The next concept is the whole inventory, and its last row is a counterexample: <strong>the absence of AVX-512 is a <em>feature bit</em> and the absence of the counters is a <em>permission</em>, and they are told apart by the fact that one is read with an unprivileged instruction and the other is not.</strong> Two absences, two kinds, and the distinction is the difference between a hardware fact and a configuration fact.</p>
                <p>Outward. The comparison belongs to the other courses, and the one to make is not x86 against ARM: it is <em>a machine with counters against a machine without them as a course-authoring constraint</em>. Four results in this collection had to be marked <code>INFERRED</code> for want of a counter, and every one of those markings is an argument that the absence of an instrument is a limit on what may be <em>claimed</em> and not only on what may be measured. <a href="/courses/smp/lessons/smp-sharing">The multiprocessor course's false-sharing result</a> is the cleanest case: the number was real, the mechanism was inferred from the shape of the table, and the page said so.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86sys/lessons/x86-paging">The Four Entries and Every Flag in One</a></span>
                <span>Next: <a href="/courses/x86sys/lessons/x86-boundary">What Ring 3 Can See, and What It Cannot</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
