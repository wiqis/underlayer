// Multiprocessor Architecture — Concept 5: the thing this machine cannot do
public namespace underlayer_content {

using std::string

using std::string_view

public func render_smp_numa() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Thing This Machine Cannot Do — Underlayer")
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
            <h1>The Thing This Machine Cannot Do</h1>
            <div class="lesson-meta">22 min &middot; <a href="/courses/smp">Multiprocessor Architecture</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>A concept whose experiment produced no result is normally a concept that should be deleted. This one is not, and the reason is worth stating before any number appears: <strong>the portable content here is a distinction, and the distinction is measurable even though only half of it is.</strong></p>
                <p>Memory Non-Uniform Access is the case where the answer to &ldquo;how far is memory?&rdquo; depends on <em>which processor asked</em>. Two cores, identical in every respect, get different answers, and neither answer is wrong. That possibility is why a single-core machine cannot answer the question and a two-socket machine cannot answer it with the two cores it already has.</p>
                <p>And it is conflated with coherence constantly, which is the practical cost of the confusion. Both are described as &ldquo;the memory is remote&rdquo;, and they are not the same phenomenon, they do not have the same mechanism, and <strong>they do not have the same fix</strong>: false sharing and a contended cache line are fixed by padding or sharding; a NUMA placement problem is fixed by getting the memory near the core that touches it, and padding makes it worse by spreading the data out.</p>
                <p>The framing this section uses is the one the artifact prints, and it is unusual enough to be worth adopting generally: <em>the absence is a measurement, not a gap.</em> &ldquo;There is one memory domain on this machine&rdquo; is a fact read out of <code>/sys</code>, not a shrug about the hardware. It was established before any claim was made, it is asserted by the harness, and it constrains what every other number in the course is allowed to mean.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: two different questions</h2>
                <div class="formula">
   cache coherence  a question between two CACHES.
                     One line, one owner at a time.
                     Solved by a protocol, and the cost
                     is a LINE TRANSFER.
                     THIS is what section 2 measured.

   NUMA             a question between a CORE and a
                     MEMORY CONTROLLER.  Nothing is
                     shared and nothing is owned; the
                     address just DECODES differently.
                     The cost is LATENCY and BANDWIDTH,
                     not ownership transfer.
                </div>
                <p>Four differences, and each one is enough on its own to tell the two apart in a profile:</p>
                <div class="formula">
                     COHERENCE            NUMA
   how many agents?      2+ caches            1 core, N controllers
   what is contended?    a LINE               a PAGE / a mapping
   who loses?            the writer           nobody
   what transfers?       ownership            nothing; it is a
                         of the cache line    longer walk to memory

   and the symptom:
     coherence   two threads on two cores get slower
                 when they touch the same line
     NUMA        one thread on one core gets slower when
                 it touches memory attached to another core
                </div>
                <p>The line that does the most work is the third one: <strong>in a coherence problem something is owned and has to change hands; in a NUMA problem nothing is owned and nothing changes hands.</strong> That is why no amount of padding helps a NUMA problem &mdash; padding does not move ownership, because there is none &mdash; and why it can even make things worse by spreading a working set across more pages in more places.</p>
                <p>The other half of the model is what makes a NUMA machine hard to reason about: <strong>the answer is a function of the address, not of the program.</strong> The same instruction, the same cache state, the same everything, gets a different latency because the top bits of the address route the transaction to a different controller. There is no coherence state to inspect, because no state is involved; there is only where the bits go.</p>
                <p>Which is exactly why the memory course could not reach it either. That course followed an address down through the TLB and the page tables and out to DRAM, and its limits block names cache coherence, NUMA and multiprocessor memory as belonging elsewhere. <strong>This is that elsewhere, and the first half of the job is to say what this machine's answer would have to look like before you notice there isn't one.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: one node, one domain</h2>
                <div class="hex-dump">
                <pre>$ ./smpbench | sed -n '/5. NUMA/,/ONE memory domain/p'
5. NUMA, WHICH IS ABSENT HERE
   Memory Non-Uniform Access is the case where the answer to "how far
   is memory?" depends on WHICH processor asked.  This machine has one
   socket and one memory controller group, so the phenomenon cannot
   occur -- and its absence is a measurement, not a gap.

   /sys/devices/system/node/online  "0"  -> 1 node(s)
   node0 cpulist                    "0-11"

   So: ONE memory domain.  Every core on this machine is the same
   distance from every address, and the number in section 2 is a
   statement about CACHE COHERENCE and not about distance.
 </pre>
                </div>
                <p>One node. Its CPU list is <code>0-11</code> &mdash; every logical CPU on the machine, which is the kernel saying there is nowhere else to be. <strong>Every core is the same distance from every address</strong>, so a measurement on this machine of &ldquo;how far is memory&rdquo; would produce one number and it would be true of every core, which is precisely the property NUMA exists to violate.</p>
                <p>What follows, stated precisely rather than apologetically, is the part that constrains the rest of the course:</p>
                <div class="hex-dump">
                <pre>   * every ratio in section 2 is a COHERENCE ratio.  None of them is
     a NUMA ratio, and none of them would survive a machine with two
     nodes, where the remote case would be a DIFFERENT experiment
     rather than a bigger number.

   * the pinning in section 2 chooses between CORES, not between
     nodes.  On a two-socket machine the same code and the same
     pinning routine would measure remote memory if the second core
     were on the other socket, and the harness would still go green,
     because nothing in it checks the node.  THAT IS A REAL GAP IN
     THIS HARNESS and it is named here rather than left.

   * a reader on a multi-socket machine should extend the topology
     section to read physical_package_id -- which this file already
     reads, prints, and does not yet act on -- and add a row per
     (core, node) pair rather than per core pair.
 </pre>
                </div>
                <p>Three claims and each one earns its place.</p>
                <p><strong>Every ratio in the placement table is a coherence ratio.</strong> 13.05&times; for true sharing and 10.92&times; for false sharing are statements about a line changing hands between two caches inside one package. On a two-node machine the &ldquo;remote&rdquo; version of the same experiment would not be a larger number for the same effect &mdash; it would be a different effect with a different mechanism, and reporting it as the same row would be the mistake this bullet exists to prevent.</p>
                <p><strong>The pinning chooses between cores, not nodes.</strong> <code>cpu2</code> and <code>cpu4</code> are different cores and, on this machine, trivially the same distance from memory. Copy the artifact to a dual-socket machine, run the same command, and if the second CPU happens to be on the other socket you are now measuring remote memory &mdash; <em>and every check in the harness would still pass</em>, because the placement check verifies CPU identity and nothing verifies memory identity.</p>
                <p><strong>The fix is already half-written.</strong> The artifact reads and prints <code>physical_package_id</code> for every CPU and then does not act on it. On this machine every value is 0 and acting on it would change nothing; on a two-socket machine the same loop with the same pinning would produce rows across sockets and the table would quietly stop being the experiment it says it is. <strong>A field that is read, printed, and not used is the strongest possible hint that the code was written on a machine where it could not matter &mdash; and this one is flagged in the artifact rather than left to be discovered.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the harness's own gap, and the sentence it is confusing</h2>
                <p>The bullet about the harness going green is worth making concrete, because a gap in a course's own verification is a different kind of embarrassing from a gap in a machine.</p>
                <div class="formula">
   the harness, group B, checks:

     the online CPU list was read from /sys          exact
     CPU 0 is IN the list even with no online file  exact
     cores x threads-per-core == the CPU count      exact
     no CPU is its own sibling                      exact
     every sibling relation is MUTUAL               exact
     the cache list and the sibling list AGREE      exact

   the harness does NOT check:

     that the two CPUs in any row are in the same node

   so on a two-socket machine, with the artifact
   unchanged and the pinning unchanged, every one of
   those checks passes and section 2 has silently
   become an experiment about remote memory.
                </div>
                <p><strong>That is not a hypothetical.</strong> The artifact's own pinning picks <code>cpu2</code> and <code>cpu4</code> by hard-coded number. On a machine whose CPUs are numbered with node 0 first &mdash; which is the normal arrangement and is the arrangement here &mdash; those two are in the same node. On a machine that enumerates differently, or on one where you edit the pinning to <code>cpu2</code> and <code>cpu40</code> because that is what you meant to do, they are not, and the number you take away is about a different question.</p>
                <p>The honest repairs are all small and all in the same place: check the node inside the worker alongside <code>sched_getcpu()</code>, discard and count a repetition whose two threads are in different nodes, and add a row per (core, node) pair so that the remote case is a labelled row rather than an accidental one. <strong>None of them was done here, because on this machine there is nothing to check, and the correct thing to do with a check you cannot exercise is to say so in the output &mdash; which is what the third bullet is.</strong></p>
                <div class="formula">
   They are confused constantly, and the confusion has
   a name: "the memory is remote".  On a one-node machine
   that sentence is MEANINGLESS, which is why this course
   can make the distinction without measuring the second
   half of it.
                </div>
                <p>That last observation is the useful one to take away, and it is worth a moment. <strong>On this machine, &ldquo;the memory is remote&rdquo; cannot be a true sentence.</strong> There is no second place for memory to be. That is not a limitation on what you may conjecture about your own machine &mdash; it is a limitation on this machine, established by reading a file, and it is the reason the distinction can be taught with a hard boundary around the half that was not measured.</p>
                <p>What a reader with a two-socket machine should do is not re-run this artifact. It is extend it, and the extension is exactly the shape of the extension that has been needed three times in this collection: read one more thing out of <code>/sys</code>, cross-check it against a second file that a different subsystem wrote, and turn the thing the code already reads but ignores into the thing the code acts on.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Read your node topology and say out loud whether this course's ratios mean anything on your machine.</strong> <code>cat /sys/devices/system/node/online</code> and, for each node, <code>cat /sys/devices/system/node/nodeN/cpulist</code>. Then compare each node's CPU list against the sibling pairs from the first concept. <em>(Expect, on a single-socket machine, one node containing every CPU and no sibling pair crossing a boundary. Expect, on a dual-socket machine, two nodes each containing whole sibling pairs &mdash; and that is exactly why the placement rows would still be valid on a dual-socket machine, because pinning to siblings of the same core also pins within a node. The rows that would break are the ones pinning across sockets, which is worth checking deliberately.)</em></li>
                    <li><strong>Classify six real performance complaints.</strong> For each, name it coherence or NUMA and say what would change if you were wrong: (a) a threaded reduction is 10&times; slower than the serial version and adding padding to the per-thread accumulators does nothing; (b) a process is fast when it starts and slow after a large allocation; (c) two threads writing adjacent struct fields are slower than two threads writing fields 64 bytes apart; (d) a memcpy is slower on a large buffer than on a small one by more than the size ratio; (e) a thread migrates and performance collapses; (f) the machine is fast with one socket's worth of threads and slow with all of them. <em>(Expect (c) to be the only unambiguous coherence case and expect at least one of the others to be genuinely undecidable from the symptom &mdash; which is the practical argument for the distinction being a question you ask about <em>mechanism</em>, not about speed.)</em></li>
                    <li><strong>Add the node check to a copy of the artifact, and see whether it can ever fire.</strong> Have each worker read <code>/sys/devices/system/node/cpuN/</code>'s node id after <code>sched_getcpu()</code>, print it, and add a harness check that the two workers are in the same node. <em>(Expect the check to pass on every repetition on this machine, and expect that to be the entire point: you have written a check whose failure mode you cannot demonstrate, which is precisely the situation the privilege course's exercise 2 is about. Note the difference from a check you can break &mdash; that is what makes it weaker, and it is better to know which of your checks are which.)</em></li>
                    <li><strong>Prove that the distinction predicts a number, using the numbers already measured.</strong> Coherence transfers a line, so its cost should land in the last-level-cache band that <a href="/courses/mem/lessons/mem-latency">the memory course's latency concept</a> measured. NUMA transfers nothing, so its cost should land near the DRAM band that same concept measured. <em>(Expect the coherence row&rsquo;s 47.76 ticks/op to be consistent with an L3 round trip rather than with a DRAM access &mdash; at this machine&rsquo;s own measured TSC rate of 2.2957&nbsp;GHz that is about 21&nbsp;ns &mdash; and expect that this is a bound and not an identification, because without a PMU you cannot count transfers and are inferring from the price. The prediction is falsifiable in one direction: a DRAM round trip would have put the row near 350 ticks instead of 48, so the measurement is able to rule the slow mechanism out even though it cannot count the fast one.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/smp/lessons/smp-ordering">the ordering concept</a> established the course's largest limit: a duration cannot establish a guarantee. This concept is the second-largest, and it is the one where the temptation is different. Ordering cannot be measured <em>at all</em>; NUMA cannot be measured <em>here</em>, and the second kind is much easier to fake. <strong>The defence is the same in both cases and it is the harness's: assert the absence, assert the reason, and never print a number in the space where the number is unknown.</strong></p>
                <p>Forward, <a href="/courses/smp/lessons/smp-three">the three-architectures concept</a> covers the other two machines' coherence designs, and the interesting thing about it here is that <em>all three have the same unit of sharing and the same state machine</em>. NUMA is the thing that changes when you leave one: it is not a protocol at all, it is the address space having more than one answer to the question &ldquo;where does this live.&rdquo; And <a href="/courses/smp/lessons/smp-harness">the harness concept</a> is where the node gap from this section shows up as a check that is absent, which is its own small demonstration of the rule the whole course is built on.</p>
                <p>Outward, the closest neighbours are in the memory course and they are about the same walk at two different distances. <a href="/courses/mem/lessons/mem-latency">The memory course's latency concept</a> chased an address from L1 to DRAM on one core and found the bands; every number it produced is a <em>local</em> number, and this concept is the one that says what happens when &ldquo;local&rdquo; stops meaning one thing per core. <a href="/courses/mem/lessons/mem-translation">Its translation concept</a> is where the address is split into parts, and on a NUMA machine the interesting part is the one this course cannot reach: the bits that choose the controller are decoded from the <em>physical</em> address, so the difference between local and remote is a property of the mapping and not of the code. <strong>Which means the fix for a NUMA problem is usually a policy decision made by the first-touching thread, and a policy decision is not a performance detail.</strong></p>
                <p>And for anyone building a runtime: the reason this concept exists in a course that cannot measure it is that &ldquo;is it coherence or is it NUMA&rdquo; is a question your scheduler will eventually have to answer automatically. <strong>You cannot answer it by measuring, on one machine, and you cannot answer it by counting, because there is no PMU.</strong> You answer it by reading the topology and by knowing which question each number answers.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/smp/lessons/smp-ordering">A Duration Is Not a Guarantee</a></span>
                <span>Next: <a href="/courses/smp/lessons/smp-three">Three Answers to Two Questions</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
