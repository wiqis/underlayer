// Compiler Backend: From IR to Machine Code -- concept 4: instruction
// scheduling, the kernel chosen on purpose, and the trap that makes a
// schedule look good while being wrong.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_cb_sched() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Instruction Scheduling — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson compback-concept">
            <a href="/courses/compback" class="back-link">Compiler Backend: From IR to Machine Code</a>
            <h1>Instruction Scheduling</h1>
            <div class="lesson-meta">26 min &middot; Concept 4 of 6 &middot; module: three questions about a sequence &middot; <a href="/courses/compback">Compiler Backend: From IR to Machine Code</a></div>

            <div class="unit unit-why">
                <h2>Which order, and why it is the third question rather than the first</h2>
                <p>Selection chose the instruction. Allocation chose the register. What is left is the order &mdash; and this is the pass that looks like an optimisation and is actually a <em>legality</em> pass, because a schedule that does not respect the dependencies is not a fast program, it is a different program.</p>
                <p>The algorithm here is list scheduling, in full:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/LIST SCHEDULING, in full/,/THIRD IS A THIRD POLICY/p'
  LIST SCHEDULING, in full: while unscheduled nodes remain, take one with
  no unscheduled predecessor, and among those take the one the PRIORITY
  FUNCTION prefers.  Three priorities, all measured:

    index      the input order, which is a SCHEDULE and the control
               every other schedule is measured against
    height     longest chain STARTING at the node, ties to the LOWEST
               index -- which on this kernel reproduces the input order
    height_hi  the SAME priority, ties to the HIGHEST index -- which on
               this kernel produces a different order from `height` and
               nothing else does
    degree     most UNSCHEDULED SUCCESSORS, which is a third policy
                </pre>
                </div>
                <p>Three phases and they are not separable: <strong>build the dependency graph, ask what a node&rsquo;s priority is, then repeatedly take the ready node the priority function prefers.</strong> Everything interesting on this page is in one of those three phases, and the phase most textbooks spend least time on is the first.</p>
            </div>

            <div class="unit unit-model">
                <h2>The kernel is chosen on purpose, and the choice is the lesson</h2>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/  THE KERNEL IS kernel_d/,/CONCLUDES THAT SCHEDULING WORKS/p'
  THE KERNEL IS kernel_d, 16 instructions, and §KEEP§IT IS NOT kernel_a:
  §KEEP§kernel_a IS A DEPENDENCY CHAIN, ITS CRITICAL PATH EQUALS ITS
  LENGTH, AND EVERY SCHEDULE OF IT IS THE INPUT ORDER -- §KEEP§SO A
  SCHEDULER MEASURED ON IT HAS NOTHING TO DECIDE. §KEEP§A LIST SCHEDULER
  THAT IS GIVEN NO CHOICE PRINTS THREE COPIES OF THE INPUT AND A
  READER WHO HAS NOT SPOTTED IT CONCLUDES THAT SCHEDULING WORKS.
                </pre>
                </div>
                <p><strong>This is worth more than any number on the page.</strong> <code>kernel_a</code> is a dependency chain: its critical path equals its length, so every legal schedule of it is the input order. Run a list scheduler on it and it prints three copies of the input. A reader who has not spotted that concludes scheduling works, because the output is stable and reproducible and the checksum never moves.</p>
                <p>That is the failure mode to carry out of this page: <strong>an experiment with no variance proves nothing, and a scheduler given no choice produces none.</strong> The kernel below is 16 instructions with a critical path of 8 and ILP 2.00, so there is genuinely room to move things.</p>
                <div class="formula">
   ILP IS A RATIO AND NOT A SPEEDUP

   ILP here is instructions divided by critical path:
   16 / 8 = 2.00.  §KEEP§IT IS A PROPERTY OF THE DAG AND OF A
   MACHINE WIDTH THAT IS NOT MEASURED HERE, §KEEP§AND A NUMBER THAT
   IS DIVIDED BY A CRITICAL PATH IS NOT A TIME.

   2.00 does NOT mean this program runs twice as fast as
   a serial one.  It means the DAG has twice as many nodes
   as its longest chain, and how much of that a machine can
   exploit depends on its width, its issue rules and its
   rename table -- none of which this course measures.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>Four legal orders, and the only thing separating three of them</h2>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/WITHOUT memory dependencies: critical path/,/THE ONLY THING THAT SEPARATES THE FOUR/p'
  WITHOUT memory dependencies: critical path 8 of 16 instructions, ILP 2.00
    priority    order                      illegal   checksum
    index       [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]    0   same
    height      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]    0   same
    height_hi   [3, 2, 1, 0, 5, 4, 7, 6, 10, 9, 8, 12, 11, 13, 14, 15]    0   DIFFERENT
    degree      [0, 1, 2, 4, 6, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15]    0   DIFFERENT
                </pre>
                </div>
                <p>Four orders, all legal, <strong>zero illegal reorders in any of them</strong>. And <code>height</code> reproduces the input order exactly while <code>height_hi</code> does not &mdash; and they are <em>the same algorithm</em>.</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/§KEEP§AND `height` AGAINST `height_hi`/,/BREAKING IT TOWARD THE HIGHEST/p'
  §KEEP§AND `height` AGAINST `height_hi` IS THE MOST IMPORTANT ROW IN
  THAT LIST, §KEEP§BECAUSE THEY ARE THE SAME ALGORITHM WITH A DIFFERENT
  UNDOCUMENTED TIE-BREAK, §KEEP§AND EVERY LIST SCHEDULER IN EVERY
  TEXTBOOK BREAKS TIES BY SOME RULE AND NONE OF THEM SAY WHICH. §KEEP§A
  BACKEND THAT REPORTS "MY SCHEDULER IS BETTER" WITHOUT NAMING THE
  TIE-BREAK HAS REPORTED A DIFFERENT SCHEDULER AND NOT A BETTER ONE.
                </pre>
                </div>
                <p><strong>Same priority function, opposite tie-break, different schedule.</strong> Every list scheduler in every textbook breaks ties by <em>some</em> rule and none of them say which. So the sentence &ldquo;my scheduler is better&rdquo; without naming the tie-break is reporting a different scheduler and not a better one &mdash; and this is the same class of mistake as the register-allocation page&rsquo;s spill policies: <strong>a comparison that does not name the decision it is not varying has compared two configurations and called it an algorithm.</strong></p>
                <p>Mechanically it is simple. The four initial <code>mov</code>s have the same downstream height, so breaking the tie toward the lowest index reproduces the input order and breaking it toward the highest produces <strong>its reverse on the first four instructions and nothing else</strong>.</p>
                <p>And the checksums differ between the four. That is <em>not</em> a bug, and the artifact explains it in the same breath as the verdict:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/AND THE CHECKSUM DIFFERS BETWEEN THEM/,/THE ARGUMENT FOR HAVING BOTH/p'
    §KEEP§AND THE CHECKSUM DIFFERS BETWEEN THEM, §KEEP§WHICH IS NOT
    A BUG: §KEEP§IT IS A FOLD OVER THE VALUES *IN SCHEDULED ORDER*,
    §KEEP§AND TWO LEGAL SCHEDULES OF THE SAME PROGRAM DEFINE THEIR
    VALUES IN A DIFFERENT ORDER. §KEEP§§KEEP§THAT IS EXACTLY WHY A
    FOLD THAT IGNORED THE ORDER COULD NOT HAVE DETECTED THE
    ALIASING TRAP, §KEEP§AND IT IS THE ARGUMENT FOR HAVING BOTH.
                </pre>
                </div>
                <p>Read that last sentence carefully, because it is the course&rsquo;s position on evidence stated once and it applies everywhere. <strong>A fold that ignored the order could not have detected the aliasing trap</strong> &mdash; the trap on the next page &mdash; so having both checks is not redundancy. One says &ldquo;legal&rdquo;, the other says &ldquo;correct&rdquo;, and they are different claims.</p>
            </div>

            <div class="unit unit-example">
                <h2>The trap: a schedule that respects the dependencies it can see</h2>
                <p>Here is the failure this pass is most likely to produce, and it is worth being precise about why it is not a bug in the scheduler.</p>
                <p>The kernel stores to <code>[1024+8]</code> and then loads from <code>[1024+8]</code>. <strong>The same address</strong>, so the dependency is real, and a scheduler that does not know they alias will hoist the load above the store.</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/    memory deps   priority     order/,/WRONG ANSWER/p'
    memory deps   priority     order                            checksum   VERDICT
    WITH          index       [0, 1, 2, 3, 4, 5, 6, 7]    6601140724   correct
    WITH          height      [0, 1, 2, 3, 4, 5, 6, 7]    6601140724   correct
    WITH          height_hi   [1, 0, 2, 3, 4, 5, 6, 7]    10036638844   WRONG ANSWER
    WITHOUT       index       [0, 1, 2, 3, 4, 5, 6, 7]    6601140724   correct
    WITHOUT       height      [0, 1, 2, 3, 5, 6, 4, 7]    6601062688   WRONG ANSWER
    WITHOUT       height_hi   [1, 0, 2, 5, 3, 6, 7, 4]    10034139088   WRONG ANSWER
                </pre>
                </div>
                <p>Three wrong answers, and notice that <strong>the WITH-memory-dependency <code>height_hi</code> row is wrong too</strong> &mdash; so this is not only &ldquo;the scheduler dropped an edge&rdquo;. It is: <em>a tie-break plus a dependency builder</em> can move an instruction across a real dependency even when the memory edges are all present.</p>
                <p>And then the row that settles what the wrong rows actually mean. The same <code>height</code> schedule, run on <strong>distinct addresses</strong>, where the reorder is legal:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/the same schedule on DISTINCT addresses/,/IS THE WORST COMBINATION THIS/p'
    the same schedule on DISTINCT addresses, where the reorder is
    legal:
    WITHOUT       height      [0, 1, 2, 3, 5, 6, 4, 7]    6601062688   correct
                </pre>
                </div>
                <p><strong>The exact same schedule, checksum <code>6601062688</code>, is wrong on one kernel and correct on the other.</strong> The only difference between the two kernels is whether the backend knew the addresses aliased.</p>
                <div class="formula">
   WHY BOTH VERDICTS ARE PRINTED

   They are NOT contrasted for effect.  They are BOTH
   TRUE and they SAY DIFFERENT THINGS.

   "Without alias analysis the schedule is sometimes wrong"
   and "the schedule is legal and produces a different value
   only where the addresses alias" are the same fact seen
   from two sides, and the second one is the one that tells
   you what to build.

   §KEEP§A SCHEDULER THAT DROPS AN UNKNOWN MEMORY DEPENDENCY IS
   NOT WRONG, IT IS A SCHEDULER WITHOUT AN ALIAS ANALYSIS.
                </div>
                <p>That distinction is worth its cost. <strong>A scheduler that drops an unknown memory dependency is not wrong; it is a scheduler without an alias analysis.</strong> Every production compiler makes this choice deliberately, and the difference between the choices is not correctness &mdash; it is how many times the answer will be right on code you did not write.</p>
                <h3>And timing will not catch it</h3>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/§KEEP§AND TIMING WILL NOT CATCH IT/,/IT IS A LIE THAT HAPPENS TO POINT DOWN/p'
  §KEEP§AND TIMING WILL NOT CATCH IT. §KEEP§IF THE ONLY MEASUREMENT
  WERE HOW FAST THE TWO SCHEDULES ARE, THE BROKEN ONE WINS. §KEEP§THE
  ONLY THING THAT CATCHES IT IS A VALUE, WHICH IS WHY EVERY SCHEDULE
  IN THIS FILE IS EVALUATED AND ITS CHECKSUM PRINTED BESIDE ITS
  LENGTH. §KEEP§THIS IS THE GENERAL FORM OF EVERY TIMING BUG IN THIS
  COLLECTION AND IT IS WORTH NAMING: A FASTER WRONG ANSWER IS NOT A
  SMALLER NUMBER, IT IS A LIE THAT HAPPENS TO POINT DOWN.
                </pre>
                </div>
                <p><strong>A faster wrong answer is not a smaller number; it is a lie that happens to point down.</strong> That is the general form of every timing bug in this collection, and this page is where it is sharpest, because the failure mode it produces is <em>faster and wrong</em> &mdash; the worst combination. A slower wrong answer gets caught in a test suite the first time. A faster one gets shipped.</p>
                <div class="callout callout-note">
                    <p><strong>The fifth bug in this collection that lived in the failure branch.</strong> The dependency builder skipped every instruction with <strong>no destination</strong> &mdash; which is <em>every store</em>. So the memory-ordered schedule reordered stores across the very things that compute their data. The schedule that was supposed to catch the aliasing bug was the schedule that carried it. A check that runs only when something has already gone wrong cannot be the thing that notices; and a builder that walks instructions and asks &ldquo;does this one have a destination?&rdquo; has quietly decided that stores are not instructions.</p>
                </div>
                <h3>And the first version of this scheduler was backwards</h3>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/§KEEP§AND THE FIRST VERSION OF THIS FILE COMPUTED ONLY THE LONGEST/,/THE WHOLE OF THE PRIORITY FUNCTION/p'
  §KEEP§AND THE FIRST VERSION OF THIS FILE COMPUTED ONLY THE LONGEST
  CHAIN *ENDING* AT EACH NODE AND USED IT AS THE PRIORITY -- §KEEP§SO THE
  SCHEDULER PREFERRED THE NODES WHOSE WORK ARRIVED LATEST, WHICH IS THE
  EXACT OPPOSITE OF WHAT HIDES LATENCY. §KEEP§IT PRODUCED A SCHEDULE, IT
  WAS LEGAL, IT WAS DETERMINISTIC, AND IT WAS NO BETTER THAN THE INPUT
  ORDER. §KEEP§THE TWO HEIGHTS ARE NOW COMPUTED AND THE DISTINCTION IS
  THE WHOLE OF THE PRIORITY FUNCTION.
                </pre>
                </div>
                <p>Read that again: it produced a schedule, it was legal, it was deterministic, and it was no better than doing nothing. <strong>A wrong priority function is not a crash, a wrong answer, or a hang. It is a scheduler that runs.</strong> That is now retraction R9&rsquo;s sibling on this page, and the two heights are computed and named because the distinction between them <em>is</em> the priority function.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Measure your scheduler on a chain and watch it prove nothing.</strong> <em>(Run the scheduler on <code>kernel_a</code> instead of <code>kernel_d</code>. Expect all three priorities to print the identical input order, with zero illegal reorders and identical checksums. Now run <code>kernel_d</code>. <strong>The difference between those two runs is not a property of the scheduler; it is a property of whether you gave it anything to decide.</strong> If your own test suite runs only on chains, you are shipping a scheduler you have never tested.)</em></li>
                    <li><strong>Flip the tie-break and watch a different scheduler appear.</strong> <em>(Change <code>height</code> to break ties toward the highest index instead of the lowest, which is exactly what <code>height_hi</code> is. Re-run. Expect the order to change on the first four instructions and nowhere else, and the checksum to change with it because the fold is over values in <em>scheduled</em> order. <strong>Nothing about the priority function changed &mdash; only the tie-break &mdash; and that is the whole argument for naming tie-breaks in any scheduler comparison you read or write.</strong>)</em></li>
                    <li><strong>Delete the store edge from the dependency builder.</strong> <em>(Find the loop that walks instructions and notice which ones it skips. An instruction with no destination register is a store, and a store skipped is an ordering constraint dropped. Re-run the memory-ordered schedule and watch the checksum go from <code>6601140724</code> to <code>6601062688</code> while the edge count falls by one. <strong>Then time both and watch the broken one win.</strong> That is the exercise: build the trap, then observe that the measurement a reader would naturally reach for endorses it.)</em></li>
                    <li><strong>Make the two addresses different and re-run the broken schedule.</strong> <em>(Change the store and the load in the kernel to different offsets, keeping the schedule exactly as it was. <strong>Expect the same schedule to become correct</strong>, with the same checksum. This is the step that turns &ldquo;the scheduler is wrong&rdquo; into &ldquo;the scheduler has no alias analysis&rdquo;, and it takes thirty seconds. Do it before you do anything else with this kernel &mdash; a failure you have not localised is not a finding.)</em></li>
                    <li><strong>Ask your own compiler whether it reorders memory operations.</strong> <em>(Compile two stores and a load of the same location at <code>-O2</code>, then at <code>-O0</code>. Where the order changes, the answer is in an alias analysis; where it does not, the conservative path was taken. <strong>The number of places you find is the real cost of that choice</strong>, and it is a fact about your program rather than about the compiler, which is the reason no course in this collection can measure it for you.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/exe/lessons/exe-latency"><code>exe-latency</code></a> derived why a dependency chain costs you what it costs, and <a href="/courses/exe/lessons/exe-deps"><code>exe-deps</code></a> is where out-of-order execution and the rename table were introduced. This page deliberately does not repeat either: <strong>the question here is not whether reordering helps a machine but whether the compiler is allowed to do it</strong>, and the aliasing kernel answers the second question rather than the first. <a href="/courses/exe/lessons/exe-speculate"><code>exe-speculate</code></a> covers the other direction &mdash; speculation past a branch the compiler did not reorder.</p>
                <p>Across architectures, <a href="/courses/a64simd/lessons/a64-order"><code>a64-order</code></a> and <a href="/courses/x86simd/lessons/x86-order"><code>x86-order</code></a> taught the <em>architectural</em> guarantee: what the hardware promises once the compiler has emitted the order. Read them beside this page and the difference is the whole subject of scheduling. <strong>Those courses asked what the machine guarantees about the order you chose. This one asks which order you were allowed to choose in the first place, and the answer is &ldquo;any order whose dependencies you can prove, and only those&rdquo;.</strong></p>
                <p>Forwards, <a href="/courses/compback/lessons/cb-abi"><code>cb-abi</code></a> is the fourth thing a backend must know before it emits anything, and it is a constraint of a different kind: not &ldquo;what order is legal&rdquo; but &ldquo;which registers exist at all&rdquo;. <a href="/courses/compback/lessons/cb-verify"><code>cb-verify</code></a> then reads all of this back out of the finished bytes.</p>
                <p>Outward, two limits and they are both printed in the artifact rather than implied. <strong>The schedule here is measured as a checksum and a critical path and never as a time</strong>, because the only schedule that could be timed is one the machine has already reordered &mdash; and <a href="/courses/compback/lessons/cb-regalloc"><code>cb-regalloc</code></a> measures that instead, and reports that the difference was <em>below the comparison floor</em>. And <strong>the aliasing trap is constructed, not discovered</strong>: the two kernels differ by one literal address, so the experiment shows that a scheduler without an alias analysis is wrong, and it says nothing about how often a real one would be. A constructed trap is a demonstration and not a rate, and the distinction is the reason the experiment can be run on a build machine at all.</p>
                <p>And the general form, which is the third time this collection has needed it: <strong>the check that lives in the failure branch is invisible on a healthy run.</strong> That is how the store-edge bug survived, how the cross-check&rsquo;s classifier stayed in a path a passing run never reaches, and how this course&rsquo;s own dead normalisers stayed dead until someone pre-seeded a fire table and printed the zeros. Print the rows that fired zero times. A rule that never fired is a row, not an absence.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/compback/lessons/cb-regalloc">Register Allocation</a></span>
                <span>Next: <a href="/courses/compback/lessons/cb-abi">The Backend and the ABI</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
