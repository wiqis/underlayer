// Multiprocessor Architecture — Concept 1: a claim about a pair
public namespace underlayer_content {

using std::string

using std::string_view

public func render_smp_topology() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("A Claim About a Pair — Underlayer")
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
            <h1>A Claim About a Pair</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/smp">Multiprocessor Architecture</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Every number in this course is a claim about <strong>a pair of cores</strong>, and a pair of cores means nothing until you can say which pair. Two threads on unspecified CPUs is not a measurement; it is a rumour with a number attached. The artifact puts it as the first of six rules in its own header, and the reason it learned it was expensive:</p>
                <div class="formula">
   R2. "Two threads on unspecified CPUs is a measurement."  NO, and
       the memory course already knew it -- that is why it discarded
       rows where both threads landed on one core.  The difference here
       is that the check is the MECHANISM rather than a filter: every
       worker calls sched_getcpu() and the repetition is discarded if
       either thread is anywhere but where it was pinned.  Rows that
       fail this are counted and printed, not quietly dropped.
                </div>
                <p>So this concept is where the pinning acquires a meaning. To say &ldquo;two threads on cpu2 and cpu4&rdquo; is not to name two integers. It is to say: <em>two different physical cores, each with its own L1 and its own L2, both inside one package, both sitting on a shared L3</em> &mdash; and every experiment later in the course either depends on that being true or is invalid because it is not.</p>
                <p>And this concept pays a debt. The memory course excluded every row where both threads landed on the same physical core, on the stated grounds that &ldquo;two SMT siblings share L1 and L2 and are a different measurement&rdquo;, and used the term without defining it. A sibling is a specific thing with a specific source file, and it takes four rows of <code>/sys</code> to define properly. <strong>Until it is defined, the memory course's exclusion has no defensible justification &mdash; only a plausible one</strong> &mdash; and a reader who cannot check a justification cannot apply it to their own machine.</p>
                <p>There is also a bug in this section worth reading for its own sake, because it is the shape of a whole family of errors: <strong>the first version of this walk reported the machine correctly except for one CPU, and produced a table with a hole in it that looked perfectly well-formed.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>The model: three files, one walk, and one missing file</h2>
                <p>The kernel exposes the machine's shape in several directories that different subsystems maintain, and they are maintained independently. What this concept reads:</p>
                <div class="formula">
   /sys/devices/system/cpu/online
       which logical CPUs are up

   /sys/devices/system/cpu/cpuN/topology/core_id
       which PHYSICAL core this CPU is half of

   /sys/devices/system/cpu/cpuN/topology/
       physical_package_id
       which socket, when there is more than one

   /sys/devices/system/cpu/cpuN/topology/
       thread_siblings_list
       the OTHER half of this core -- "0-1", "2-3"

   /sys/devices/system/cpu/cpu0/cache/indexN/
       shared_cpu_list, size, level, type
       which CPUs share this cache, and how big it is
                </div>
                <p>The walk is: for each <code>cpuN</code> directory, read <code>online</code>, keep it if the file says <code>1</code>, stop at the first <code>cpuN</code> whose directory is gone. Straightforward, and the first version of it had this shape:</p>
                <div class="formula">
   for (c = 0; c &lt; 256; c++) &#123;
       if (read("/sys/.../cpu%d/online") &lt;= 0) continue;   /* WRONG */
       if (b[0] == '0') continue;
       cpu[nc++] = c;
   &#125;
                </div>
                <p><strong>CPU 0 has no <code>online</code> file at all.</strong> It cannot be offlined, so the kernel never writes one, and <code>read</code> returns <code>-1</code> &mdash; indistinguishable, to that loop, from a CPU that is not there. The first version skipped it. That dropped one of twelve CPUs, put a hole in the sibling table, and made the artifact report &ldquo;1 logical CPU per core&rdquo; on a machine with two.</p>
                <div class="hex-dump">
                <pre>  /* CPU 0 has NO online file: it cannot be offlined, so the kernel does
   not write one.  The first version of this walk SKIPPED IT for that
   reason, which dropped one of twelve CPUs, made the sibling table
   have a hole in it, and reported "1 logical CPU per core" on a
   machine with two.  A missing file is not a missing CPU. */
                </pre>
                </div>
                <p>The fix is one clause: if the read fails, the directory still exists, and this is <code>cpu0</code>, then it is online by definition. <strong>The general rule is the same one the rest of this collection keeps arriving at, in a new costume: an absent file is not an absent fact, and the code that cannot tell those apart will report a confidently wrong number.</strong> This is why the harness asserts that CPU 0 is <em>in</em> the printed list.</p>
                <h3>The sibling lookup, which took three attempts</h3>
                <p>Resolving &ldquo;who is the other half of this core&rdquo; means parsing a kernel CPU list, which is not the comma-separated list people assume. It is ranges: <code>&quot;0&quot;</code>, <code>&quot;0-1&quot;</code>, <code>&quot;0,8&quot;</code>, <code>&quot;0-1,8-9&quot;</code>.</p>
                <div class="formula">
  Attempt 1  return the FIRST NUMBER in the list.
             For "2-3" that is 2 -- the CPU ASKING.
             Every even-numbered CPU reported its sibling
             as itself, the table printed "sibling of cpu2
             is cpu-1", and the whole topology had a hole
             in it.  It failed loudly, which is why it
             survived one run.

  Attempt 2  recover both ends of a run by walking
             BACKWARDS over the already-parsed run, and
             get the wrong end.  It returned 0 for
             every CPU, CONFIDENTLY, because 0 is always
             online.  A parser that returns a plausible
             wrong answer is worse than a parser that
             returns none.

  Attempt 3  a forward tokenizer, every intermediate
             value checked, and "the first entry in the
             list that is not the CPU asking".
                </div>
                <p>Attempt 2 is the one to dwell on. It produced a complete, well-formatted table in which every CPU was confidently reported as the sibling of CPU 0. <strong>Nothing in the output was wrong-looking, and that is precisely what makes it the dangerous version</strong> &mdash; attempt 1 at least printed <code>-1</code>, which a reader would investigate.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: what the machine said</h2>
                <div class="hex-dump">
                <pre>$ ./smpbench | sed -n '/12 online CPUs/,/the caches/p'
   12 online CPUs: 0 1 2 3 4 5 6 7 8 9 10 11

   core_id, package, and the other half of each core:
      cpu0   core_id=0  package=0  sibling of cpu0 is cpu1
      cpu1   core_id=0  package=0  sibling of cpu1 is cpu0
      cpu2   core_id=1  package=0  sibling of cpu2 is cpu3
      cpu3   core_id=1  package=0  sibling of cpu3 is cpu2
      cpu4   core_id=2  package=0  sibling of cpu4 is cpu5
      cpu5   core_id=2  package=0  sibling of cpu5 is cpu4
      cpu6   core_id=3  package=0  sibling of cpu6 is cpu7
      cpu7   core_id=3  package=0  sibling of cpu7 is cpu6
      cpu8   core_id=4  package=0  sibling of cpu8 is cpu9
      cpu9   core_id=4  package=0  sibling of cpu9 is cpu8
      cpu10  core_id=5  package=0  sibling of cpu10 is cpu11
      cpu11  core_id=5  package=0  sibling of cpu11 is cpu10
   =&gt; 6 distinct physical cores, 2 logical CPUs per core
 </pre>
                </div>
                <p>Six physical cores, two logical CPUs each, one package, and every sibling relation <strong>mutual</strong>: cpu2's sibling is cpu3 and cpu3's sibling is cpu2. The harness asserts all three of those properties separately, because a sibling table where each row is <em>individually</em> plausible and the relation is not mutual is exactly the shape of attempt 2, and it still prints fine.</p>
                <p>The derivation is one multiplication and it has to be exact:</p>
                <div class="formula">
   6 cores  x  2 logical CPUs per core  =  12 online CPUs

   cores x threads-per-core == the CPU count, EXACTLY.
   A machine with a core you never counted and a
   core counted twice satisfies this too -- which is
   why the harness also asserts that no CPU is its own
   sibling, that no lookup returned -1, and that every
   relation is mutual.  One equation, four checks.
                </div>
                <p>Now the part that turns a report into a check.</p>
                <div class="hex-dump">
                <pre>$ ./smpbench | sed -n '/the caches/,/THAT IS WHY THE HARNESS/p'
   the caches, and which CPUs share each one:
      L1 data          32 KiB  shared by [0-1]
      L1 names [0-1] = 2 CPU(s); the topology puts 2 of
         them in one core_id group.  AGREE
      L1 instruction   32 KiB  shared by [0-1]
      L1 names [0-1] = 2 CPU(s); the topology puts 2 of
         them in one core_id group.  AGREE
      L2 unified      512 KiB  shared by [0-1]
      L2 names [0-1] = 2 CPU(s); the topology puts 2 of
         them in one core_id group.  AGREE
      L3 unified     16384 kiB  shared by [0-11]

   cross-check: the cache sharing lists and the topology's own
      thread_siblings_list AGREE (3 of 3 levels agreed)
   Two independent kernel files, one fact.  That is what makes this a
   check rather than an echo -- and it is why the harness can assert it
 </pre>
                </div>
                <p><strong>This is the definition the memory course owed, and it is a definition in the form of a cross-check.</strong> The L1 data cache's <code>shared_cpu_list</code> names <code>[0-1]</code>. The topology's <code>thread_siblings_list</code> names <code>0-1</code> for the same core. These are two files written by two different kernel subsystems, and they were written without any arrangement with each other &mdash; the cache subsystem does not consult the topology when it fills in a sharing list, and vice versa. <strong>That is what makes it a check rather than an echo: a program that read the same byte twice would agree with a wrong answer, and one that reads the same fact from two independent writers would have to be wrong in two places at once.</strong></p>
                <p>Three of three levels agreed. <code>AGREE</code> is printed per level rather than once at the end, because a single summary line tells you nothing about <em>which</em> level failed, and the next thing this course does is use the L1 and L2 sharing lists to decide what an SMT sibling physically is.</p>
                <p>One structural fact falls out of the table and is worth stating because it is the reason row D later is a different experiment rather than a cheaper one. <strong>The L1 sharing set is a strict subset of the L3 sharing set</strong> &mdash; two CPUs at the first level, twelve at the third &mdash; and it is contained in it exactly as the sibling pairs are. Two CPUs that share an L1 share an L2 and an L3. Two CPUs that share only an L3 have two separate coherence conversations to run.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: three questions with the artifact</h2>
                <div class="formula">
  Q1. What is this machine, exactly?  Not "roughly a
      six-core laptop" -- the numbers.

      $ ./smpbench | sed -n '/online CPUs/,/AGREE/p'

      12 online CPUs, 6 distinct physical cores,
      2 logical CPUs per core, 1 package, 32 KiB L1
      (2 CPUs each), 512 KiB L2 (2 CPUs each),
      16384 KiB L3 (12 CPUs).  3 of 3 cross-checks AGREE.

      Do NOT carry those numbers to your own machine.
      Read them there.  A machine that prints 4 cores
      per package and 2 per socket is a different
      experiment and this course says so.

  Q2. Where do the two threads in every later
      experiment actually go?

      cpu2 and cpu4 -- different core_ids, same package.
      cpu2 and cpu3 -- the SAME core_id, and the
      shared_cpu_lists confirm the L1 is common.

      That is the difference between row D and every
      other row in the table, and it is not a small
      one: row D's two threads have ONE L1 between
      them and there is no second cache to be
      coherent with.

  Q3. Break the sibling parser on purpose.
      Replace list_other() with "return the first
      number in the list".  Rebuild.  Rerun.

      (Expect: attempt 1's symptom.  Every
      even-numbered CPU reports itself, the table
      prints "sibling of cpu2 is cpu-1", and group B
      of the harness fails on THREE named checks: no
      CPU is its own sibling; no lookup returned -1;
      every sibling relation is MUTUAL.  The third is
      the one that catches it, because the relation
      stops being symmetric even where each row looks
      plausible.)
                </div>
                <p>Q3 is the one to do, and the order matters: do it <strong>before</strong> you read attempt 2's history, so that you meet the loud failure first and then learn that the quiet one was worse. <strong>A check that has never been seen to fail is a check nobody has reason to believe</strong>, and group B's three sibling checks are the reason the topology in this course can be trusted at all.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Read your own machine and write the four facts down before you look anything up.</strong> <code>cat /sys/devices/system/cpu/online</code>; the <code>core_id</code> and <code>physical_package_id</code> of CPU 0; <code>cat /sys/devices/system/cpu/cpu0/cache/index*/shared_cpu_list</code>. Then predict which CPUs are siblings before you read <code>thread_siblings_list</code>. <em>(Predicting first is what makes the exercise worth doing. Almost everyone predicts a contiguous pair or a stride; the answer is usually neither, and on machines with more than one socket the pair crosses the package boundary.)</em></li>
                    <li><strong>Prove the multiplication on your machine and explain why one equation is four checks.</strong> Distinct <code>core_id</code> values &times; logical CPUs per core must equal the count of online CPUs exactly. Then say why a machine that counted one core twice and missed another satisfies the equation anyway &mdash; and name the three additional properties that catch it.</li>
                    <li><strong>Find the CPU with no <code>online</code> file and explain why it is the most important CPU on the machine.</strong> <em>(It is CPU 0, it cannot be offlined, and the kernel never writes the file. It is also the CPU the artifact reads the cache sharing lists from, which is why <code>cpu0</code> appears in the paths rather than the CPU under test.)</em></li>
                    <li><strong>Write the cross-check yourself, in whatever language you like, and make it fail on purpose.</strong> Compare each cache's <code>shared_cpu_list</code> against <code>thread_siblings_list</code>, then hard-code one of the L1 lists to the L3 list and confirm your check goes red. <em>(A cross-check that cannot fail is an echo, and the fastest way to find out which of yours is an echo is to feed it a wrong answer on purpose.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Forward, <a href="/courses/smp/lessons/smp-sharing">the next concept</a> spends the whole topology on one table with seven rows, and the reason it can is here: with the pairs named and cross-checked, &ldquo;only the memory address changed&rdquo; becomes a statement a reader can verify rather than a claim about a benchmark. <strong>Every ratio in that table is a claim about the pair cpu2/cpu4 specifically, and if the pin fails the repetition is discarded and counted.</strong></p>
                <p>Backwards, <a href="/courses/mem/lessons/mem-instrument">the memory course's instrument concept</a> is the direct ancestor of section 0 of this course's artifact: measure the clock, measure the noise floor, print the floor, and only then make a claim. The rule is not repeated here except to say it was followed &mdash; <code>perf_event_paranoid</code> is 4, which means this machine has no PMU, and that single fact decides the shape of all six remaining concepts. <a href="/courses/mem/lessons/mem-sharing">The memory course's sharing concept</a> is the page whose &ldquo;SMT siblings&rdquo; this concept defines; reading them in that order is the honest way to see the debt being paid, because the definition is only interesting once you know what was excluded with it.</p>
                <p>Outward, there are two neighbours worth reading side by side with this one. <a href="/courses/exe/lessons/exe-instrument">The execution course's instrument concept</a> is what makes &ldquo;the same clock on both sides, so the clock cancels&rdquo; a rule rather than a hope &mdash; a ratio has the same core clock in numerator and denominator, which is the only reason any of these numbers is a number at all. And <a href="/courses/priv/lessons/priv-harness">the privilege course's harness</a> is the model for what this course's harness does with the topology: <strong>structural claims asserted exactly, because the online CPU list and the sibling pairs are exact facts about this machine and not about a machine in general.</strong></p>
                <p>One practical line to carry out of here. If you are writing anything that must be measured rather than guessed &mdash; a benchmark, a profiler, a scheduler, a runtime &mdash; <code>shared_cpu_list</code> is the file that tells you whether two CPUs you are about to pin to are the same core, and it is a different file from the one that tells you the core id. <strong>Reading one and assuming the other is a mistake with a factor of about two in it, and it is the mistake this course exists to make once and only once.</strong></p>
            </div>

            <div class="lesson-footer">
                <span>First: <a href="/courses/smp">course home</a></span>
                <span>Next: <a href="/courses/smp/lessons/smp-sharing">Three Things Called Contention</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
