// Compiler Backend: From IR to Machine Code -- concept 6: reading a
// backend's decisions back out of the bytes, and the measured/quoted
// boundary the course ends on.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_cb_verify() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Read a Backend's Decisions Back Out of the Bytes — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson compback-concept">
            <a href="/courses/compback" class="back-link">Compiler Backend: From IR to Machine Code</a>
            <h1>Read a Backend&rsquo;s Decisions Back Out of the Bytes</h1>
            <div class="lesson-meta">22 min &middot; Concept 6 of 6 &middot; module: the contract, and reading the decisions back out &middot; <a href="/courses/compback">Compiler Backend: From IR to Machine Code</a></div>

            <div class="unit unit-why">
                <h2>Every page so far told you what the backend decided. This one asks whether you can find out.</h2>
                <p>Five pages of this course measured decisions: which machine form, which register, which order, which contract. All of them were made by a program you could read. <strong>None of them left a trace in the output you would ship.</strong> A shipped binary has no selector, no allocator and no scheduler in it. It has bytes.</p>
                <p>So here is the question that turns the whole course into something you can use: <strong>given a function with no symbol table and no debug information, what can you recover &mdash; and how do you know which of your four answers was a measurement?</strong></p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/THE ARTIFACT.  Given a compiled function/,/a reading can be checked/p'
THE ARTIFACT.  Given a compiled function with no symbol table and no
debug information, recover:

  1. how many instructions it contains,
  2. how many of them touch memory,
  3. its APPARENT REGISTER PRESSURE -- the number of distinct
     registers live at the busiest point,
  4. and what that implies about the allocator that produced it.

  §KEEP§AND (4) IS THE ONLY ONE OF THE FOUR THAT IS AN INFERENCE, AND
  IT IS LABELLED AS ONE. §KEEP§THE FIRST THREE ARE COUNTS AND THE
  FOURTH IS A READING, AND THE DISTINCTION IS THE WHOLE POINT OF
  THIS SECTION: §KEEP§A COUNT CAN BE CHECKED AND A READING CANNOT.
                </pre>
                </div>
                <p>Read that last line twice, because it is the discipline of the entire page and it is not a stylistic preference. <strong>A count can be checked and a reading cannot.</strong> Anyone can re-run the instruction count and get the same number. Nobody can re-run an inference and get the same inference, because an inference has a step in it where a person had to think &mdash; and the person&rsquo;s conclusion is not in the binary.</p>
                <div class="callout callout-note">
                    <p><strong>Three counts and one reading, labelled apart, is the difference between a tool and a story.</strong> A backend profiler that prints four numbers with no indication of which are recomputable is not measuring anything &mdash; it is asserting four things and checking none. The artifact labels item 4 in the artifact&rsquo;s own text before it prints a single figure, and this page follows the same rule in every block below.</p>
                </div>
            </div>

            <div class="unit unit-model">
                <h2>The six rows, and the fourth column is not what the first three are</h2>
                <p>Every figure in this table is <strong>MEASURED</strong>: words were emitted by a real compiler, read back by a disassembler this course drives itself, and counted. Six rows, three targets, two optimisation levels.</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/  target   level   instructions   headers   mem ops/,/  riscv64   O2/p'
  target   level   instructions   headers   mem ops   distinct regs
  x86_64    O0              235        11       141               5
  x86_64    O2              253        11        37               6
  aarch64   O0              265        11       136               6
  aarch64   O2              190        11        11              12
  riscv64   O0              329        11       173               9
  riscv64   O2              207        12         6               8
                </pre>
                </div>
                <p>There is an enormous amount in that table and almost none of it is what a reader expects. <strong>Instruction count goes <em>up</em> from <code>-O0</code> to <code>-O2</code> on two of the three targets</strong> &mdash; 235 to 253 on x86-64, 265 down to 190 on AArch64, 329 down to 207 on RISC-V. And <strong>the register count goes the wrong way too</strong>: 5 to 6 on x86-64, 6 to 12 on AArch64, 9 to 8 on RISC-V. Every reader coming out of the previous five pages expects the optimised build to be smaller in every column. It is not, and the column that moved most is the one that moved the hardest to read: <strong>141 memory operations down to 37.</strong></p>
                <p>The memory-operation column is the real signal, and the reason is the subject of <a href="/courses/compback/lessons/cb-ir"><code>cb-ir</code></a>: <code>-O0</code> spills every argument to the stack and <code>-O2</code> keeps a leaf in registers. 141 loads and stores against 37 is not an optimisation, it is <strong>the difference between a function that talks to memory and a function that does not.</strong> The instruction count rises while the function gets faster, because the instructions it gained are SIMD ones that do four lanes at a time &mdash; and if your profiler reported only instruction count, <code>-O2</code> would look like a regression.</p>
                <h3>The inference, printed with its reasoning</h3>
                <p>Now the fourth item, for one function, and note that the reasoning is printed with it rather than beneath it:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/THE INFERENCE, for one function/,/VISIBLE IN A/p'
THE INFERENCE, for one function, and the reasoning is printed with it:

    function        leaf
    instructions    9
    distinct regs   7
    peak at one     3 registers, at instruction 3

    §KEEP§AND WHAT THAT IMPLIES IS A READING, NOT A COUNT:
    §KEEP§A LEAF WITH 9 INSTRUCTIONS THAT NEVER TOUCHES THE STACK AND
    PEAKS AT 3 DISTINCT REGISTERS WAS ALLOCATED WITHOUT SPILLING, AND
    §KEEP§A COMPARISON WITH THE -O0 BUILD OF THE SAME SOURCE IS WHAT
    TURNS THE READING INTO AN INFERENCE, AND §KEEP§THE DIFFERENCE
    BETWEEN THE TWO IS THE ALLOCATOR'S WORK AND NOTHING ELSE'S.

    -O0 build of the same leaf: 23 instructions, 15 of them touching
    rsp or rbp -- which is the PROLOGUE, and §KEEP§A PROLOGUE IS
    §KEEP§THE ONE PLACE A REGISTER ALLOCATION IS VISIBLE IN A
    DISASSEMBLY WITHOUT ANY DEBUG INFORMATION AT ALL.
                </pre>
                </div>
                <p><strong>Nine instructions, seven distinct registers, peaking at three live at instruction 3 &mdash; and a comparison with 23 instructions and 15 stack references at <code>-O0</code>.</strong> The difference between the two builds is the allocator&rsquo;s work and nothing else&rsquo;s, because the source is the same and the instruction selection is nearly the same shape. That is what turns a reading into an inference, and it is why the <code>-O0</code> build is in the block at all: <strong>without a second build to compare against, &ldquo;peaks at 3 registers&rdquo; says nothing about spilling, because you do not know what the pressure would have been.</strong></p>
                <p>And note what is <em>not</em> claimed. The artifact does not say the <code>-O2</code> leaf was allocated <em>well</em>. It says it was allocated <strong>without spilling</strong>, and that is a completely different sentence &mdash; the first is a judgement about quality and the second is a count of what did not happen.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What this cannot do, and why the frame is the signal</h2>
                <p>Three limits, and the second is the one that changes how you build the tool:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/WHAT THIS SECTION CANNOT DO, and it is a real limit/,/no bit says which/p'
WHAT THIS SECTION CANNOT DO, and it is a real limit:
  * it cannot recover the ALLOCATION, only its CONSEQUENCE.  Two
    different allocations can produce the same instruction count and
    the same memory-op count and differ in speed.
  * it cannot tell a SPILL from a deliberate MEMORY REFERENCE.  §KEEP§A
    STORE TO [rsp+8] WITH NO FRAME IS A SPILL; A STORE TO [rdi+8] IS
    THE PROGRAM. §KEEP§WITHOUT THE FRAME, THEY LOOK LIKE EACH OTHER,
    AND THAT IS WHY THE FRAME IS THE SIGNAL AND NOT THE STORE.
  * it cannot distinguish a COALESCED MOV from one the compiler chose
    to keep, because both are one instruction and no bit says which.
                </pre>
                </div>
                <p><strong>The second bullet is the design.</strong> If you try to detect spills by looking for stores to a stack slot, you are looking at <code>movq %rdi, -0x8(%rbp)</code> &mdash; which is a spill &mdash; and at <code>movq %rax, 8(%rdi)</code> &mdash; which is the program storing to an array the caller passed in. <strong>The two are the same instruction shape.</strong> The only thing that separates them is that one of them is <em>near a frame</em> and the other is not.</p>
                <div class="formula">
   WHY A FRAME IS THE SIGNAL AND NOT A STORE

   A store to [rsp+8] with NO FRAME is a spill.
   A store to [rdi+8]                 is the program.

   Same opcode.  Same addressing form.  Same 4 bytes.
   The ONLY thing that separates them is whether the
   function established a stack frame at all.

   SO: A PROLOGUE IS VISIBLE BECAUSE IT IS A FRAME,
   NOT BECAUSE IT SAVES REGISTERS.  The registers it
   saves are the allocator's business, and the compiler
   may save more than it modified.  What is recoverable
   from a disassembly alone is the FRAME and the
   MEMORY TRAFFIC INSIDE IT.
                </div>
                <p>That retraction is <strong>R14</strong> in the artifact&rsquo;s list of eighteen, and it is the one a backend author is most likely to get wrong &mdash; because the intuitive reading of a prologue is &ldquo;the places it saves registers&rdquo; and the correct reading is &ldquo;the place it made a frame&rdquo;. Retraction R14 says it plainly: <em>it is visible because it is a frame; the registers it saves are the allocator&rsquo;s business and the compiler may save more than it modified.</em></p>
                <p>The first bullet is the one that should govern how you name the tool. <strong>You are recovering consequences, not the allocation.</strong> Two different allocations can produce the same instruction count, the same memory-op count and the same register count and differ in speed &mdash; and there is no bit anywhere in the binary that says which one it was. That is R13, and it is the sentence this course wants you to carry out of the last page.</p>
            </div>

            <div class="unit unit-example">
                <h2>The boundary, as a table with a count</h2>
                <p>Everything above is <strong>MEASURED</strong>. Everything the other five pages quote about three architecture manuals is <strong>QUOTED</strong>. Those are different kinds of knowledge and the boundary between them is not a disclaimer &mdash; it is a table, and the count is printed with it, because <em>a percentage in a sentence is a number nobody can check</em>.</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/^  25 rows:/,/ON EITHER SIDE/p'
  25 rows:  8 MEASURED,  9 MEASURED-ON-BYTES,  8 QUOTED

  32 per cent is QUOTED, and §KEEP§THAT NUMBER IS SMALLER THAN THE
  x86-64 SECTION'S AND THE COMPARISON IS PRINTED BOTH WAYS BECAUSE
  §KEEP§SAYING "THIS COURSE QUOTES LESS" WITHOUT THE OTHER NUMBER
  WOULD BE A COMPARISON WITH NO DENOMINATOR ON EITHER SIDE.
                </pre>
                </div>
                <p><strong>25 rows: 8 MEASURED, 9 MEASURED-ON-BYTES, 8 QUOTED.</strong> Thirty-two per cent quoted &mdash; and that is the smallest quoted fraction of any course in this collection, which is a fact about the <em>subject</em> and not about the author. A compiler backend is the one place in this collection where a machine can be asked a question, and <a href="/courses/x86abi/lessons/x86-verify"><code>x86-verify</code></a> holds the other number. <strong>The honest sentence is the two-way comparison, because saying &ldquo;this course quotes less&rdquo; without the other number is a comparison with no denominator on either side.</strong></p>
                <p>And the rows a reader is most likely to mistake for measurements are marked in the table itself:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/AND THE THREE ROWS THAT ARE QUOTED/,/AND IT IS TRUE/p'
AND THE THREE ROWS THAT ARE QUOTED *AND* NOT MEASURED ARE MARKED,
because they are the rows a reader is most likely to mistake for
measurements:

    NOT MEASURED HERE
    NOT MEASURED HERE

  §KEEP§THE COMPLEXITY CLAIMS ARE THE ONES THAT MATTER MOST AND THE
  ONES THIS COURSE MEASURED LEAST, BECAUSE MEASURING THEM PROPERLY
  NEEDS A CORPUS OF THOUSANDS OF INSTRUCTIONS AND THIS ONE HAS TWELVE.
  §KEEP§SAYING THAT IS CHEAPER THAN BUILDING THE CORPUS AND IT IS
  MORE USEFUL, BECAUSE A READER WHO BELIEVED THE COMPLEXITY CLAIM
  BECAUSE IT WAS IN A TABLE WOULD BE WRONG IN A WAY NOBODY WOULD
  NOTICE.
                </pre>
                </div>
                <p><strong>And here is a defect in this very block, and it is worth more than the block.</strong> The header says <strong>three</strong> rows are marked. The block prints <strong>two</strong> lines reading <code>NOT MEASURED HERE</code>. You can check it: <code>grep -c "NOT MEASURED HERE" compback.out</code> returns six occurrences in the whole file, two of which are in this table and two of which are in the complexity rows&rsquo; own source lines. <strong>A count that does not add up, in the one section whose entire subject is counts that add up.</strong> Every other number on this course has been checked; this one has not, and it shipped.</p>
                <p>It is not repaired here, deliberately. <strong>The pages read the artifact, and a page that silently corrected a recorded figure would be worse than one that quoted it</strong> &mdash; because the correction would be invisible and the artifact would go on being wrong. The two unmarked rows are the complexity claims, and their reasoning is stated in the paragraph underneath: <em>measuring them properly needs a corpus of thousands of instructions and this one has twelve.</em></p>
                <div class="callout callout-note">
                    <p><strong>A boundary page that hides a boundary defect is the worst kind of boundary page.</strong> This is the collection&rsquo;s own recurring shape applied to itself. A label rendered two ways is not a label; a count that does not add up is not a count; and a summary line that disagrees with the table it summarises is the failure mode of every harness in this codebase that has ever counted the wrong thing and printed a clean result. The generalisation is already written down next door in <a href="/courses/rvpriv/lessons/rv-boundary"><code>rv-boundary</code></a>:<em>a percentage in a sentence is a number nobody can check</em> &mdash; and a header sentence that says &ldquo;three&rdquo; above a table that marks two is the same defect one level up.</p>
                </div>
                <h3>The four retries that would make the table trustworthy</h3>
                <p>Before the table can be believed there are three things to run, and they are the last mechanical half of the course:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/  Two readers over every word of the aarch64 leaf/,/IT IS A ROW WITH A ZERO AND NOT AN ABSENCE/p'
  Two readers over every word of the aarch64 leaf: 9 words, 9 agree,
  0 disagree, and the disagreements are printed above rather than
  summarised. §KEEP§THE THREE THAT REMAINED IN AN EARLIER VERSION OF
  THIS SECTION WERE PURELY PRINTING CONVENTIONS -- `lsl, #1` against
  `lsl #1`, and `#0x6` against `#6` -- §KEEP§AND THE FIRE TABLE IS WHAT
  MADE THEM VISIBLE, BECAUSE A DISAGREEMENT YOU CANNOT CLASSIFY IS A
  DISAGREEMENT YOU CANNOT FIX.

  THE NORMALISER FIRE TABLE, PRE-SEEDED WITH EVERY RULE NAME:

    collapse space                     0
    comma before shift or immediate      10
    hex immediate                      1
    mnemonic case                     16
    drop register size suffix          0   NEVER FIRED -- BY DESIGN
    sp alias                           0   NEVER FIRED -- BY DESIGN

    6 rules, 3 fired, 3 matched nothing.
    THE DEAD ONES: collapse space, drop register size suffix, sp alias
                </pre>
                </div>
                <p><strong>Nine words, nine agreeing, zero disagreeing</strong> &mdash; and the three that disagreed in an earlier version were commas and radixes. <em>A disagreement you cannot classify is a disagreement you cannot fix</em>, and the fire table is what makes them classifiable: <strong>ten of the twelve firings are the comma rule, and one is the radix.</strong> The table exists so that a rule which never fires is <em>a row with a zero</em> rather than an absence.</p>
                <p>And two of the three dead rules are <strong>dead by design and say so in the table itself</strong>, which is the inversion this course needed. <code>drop register size suffix</code> and <code>sp alias</code> never fire here because the corpus does not exercise them &mdash; and <strong>a rule that normalises away the difference between an <code>x8</code> and a <code>w8</code> makes the whole comparison vacuous</strong>, reporting zero disagreements over a corpus where every word disagrees. That is the class of bug that reads as success.</p>
                <p>The counter also counts a rule firing when it changes <em>either</em> side, not only this file&rsquo;s rendering, and the reason is the sharpest line in the artifact: <strong>&ldquo;a fire table that counts one side is a table of how often <em>we</em> print things a certain way.&rdquo;</strong> The first version applied every rule to one side only, so <code>hex immediate</code> never fired &mdash; for the reason the rule was written to fix.</p>
                <h3>Four poisons, and all four fired</h3>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/^  ALL FOUR FIRED/,+1p'
  ALL FOUR FIRED: yes
                </pre>
                </div>
                <p>The four deltas, and each one names the number it claims to move:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | grep -E 'DELTA:|HIDDEN\.$|5 of 9 reported'
    DELTA: misroutes -1, checksum changed YES
    DELTA: edges -15, checksum changed YES
    DELTA: edges -1, and the poisoned schedule gives A DIFFERENT ANSWER
    DELTA: 5 of the 9 planted disagreements were HIDDEN.
                </pre>
                </div>
                <p>Read those four numbers as a set, because the set is the argument. <strong>Poison 2 is the one that matters: <code>edges -15</code> <em>and</em> the checksum went wrong.</strong> A poison that only checked &ldquo;did anything move&rdquo; would have passed on a delta of <code>+1</code> and would have missed the direction entirely &mdash; and here the direction <em>is</em> the finding, because the bug removes edges, makes the graph easier, and reports a <strong>better</strong> spill count. That is why the verifier for this course requires the <em>sign</em> of the edge delta and not only that something moved.</p>
                <p>And <strong>poison 4 is the class of bug that reads as success</strong>: nine real disagreements are planted in the text the check compares, a normaliser that keeps the mnemonic and the first operand and discards the rest is added, and the broken check reports <strong>4 of 9</strong>. Five of nine failures were <em>hidden</em> by a rule that made the two readers agree by deleting the same operand from both &mdash; <strong>so the agreement became evidence about the normaliser rather than about either decoder.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Break the fingerprint and watch the inference survive while the count lies.</strong> <em>(Build the same <code>leaf.c</code> at <code>-O2</code> and at <code>-O0</code>, count instructions, memory operations and distinct registers for both, and compare against the table on this page. Then compile at <code>-O1</code> as well, which is in the corpus but not in the six rows. <strong>Write down which of your four numbers changed and which did not.</strong> The instruction count moves and the memory-op count moves faster, because that is where the allocation is visible &mdash; and a fingerprint that reported only instruction count would have reported <code>-O2</code> as bigger.)</em></li>
                    <li><strong>Find the case where the frame signal fails.</strong> <em>(Take a function with a stack array and a function that spills a value, and look for a store you cannot classify. An indexed store through a base that is itself a spilled value looks exactly like a deliberate memory reference &mdash; one load to classify it, but the artifact&rsquo;s sentence stands: <strong>without the frame, a spill and a program load look like each other.</strong> Try a <code>-Os</code> build, which omits the frame far more aggressively than <code>-O0</code> does, and see how many stores you are left with that you cannot name.)</em></li>
                    <li><strong>Count the labels in this course and check that they add up.</strong> <em>(<code>grep -c</code> for each of <code>MEASURED</code>, <code>MEASURED-ON-BYTES</code> and <code>QUOTED</code> in <code>compback.out</code>, and compare the first figure with the second. A label rendered two ways is not a label. Then find the block in section 12 whose header says three and whose table marks two, and <strong>work out whether any other count in the file disagrees with its own header</strong> &mdash; that is the exercise, because it is the one that found this defect, and a boundary page is only as trustworthy as the last count on it.)</em></li>
                    <li><strong>Plant a disagreement and hide it with a normaliser.</strong> <em>(Add a rule to the two-reader comparison that keeps the mnemonic and the first operand and discards the rest, then plant nine real disagreements in the text. Expect the broken check to report far fewer than nine &mdash; <strong>this course measures 5 of 9 hidden, and that number is the one worth reproducing</strong> because it is the difference between a cross-check and a rubric. A check that agrees has not been shown able to disagree.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, this page reads all five of its predecessors out of the finished bytes, and the two most interesting results are cross-checks rather than readings. <strong><code>-O2</code> emits <em>more</em> instructions than <code>-O0</code> on two of three targets and far fewer memory operations</strong> &mdash; which is <a href="/courses/compback/lessons/cb-ir"><code>cb-ir</code></a>&rsquo;s finding (<code>-O0</code> spills every argument) showing up as a column. And <strong>a leaf that peaks at three registers was allocated without spilling</strong> &mdash; which is <a href="/courses/compback/lessons/cb-regalloc"><code>cb-regalloc</code></a>&rsquo;s subject, recovered from the consequence rather than from the allocator. <a href="/courses/compback/lessons/cb-abi"><code>cb-abi</code></a> is the page whose frame this one finds.</p>
                <p>Across architectures, the decoders that do the reading are borrowed rather than forked, and <a href="/courses/rvpriv/lessons/rv-boundary"><code>rv-boundary</code></a> is the model for the shape of this page &mdash; <code>rvdec.py</code> and <code>a64dec.py</code> come from <a href="/courses/rvasm/lessons/rv-verify"><code>rv-verify</code></a> and <a href="/courses/a64asm/lessons/a64-verify"><code>a64-verify</code></a>, written for other courses and edited not at all. <a href="/courses/obj/lessons/obj-verify"><code>obj-verify</code></a> is where the collection established that a decoder naming every word and getting one wrong is <em>worse</em> than one that says which half of the format it implements, and that is why the fire table above prints its dead rules rather than hiding them.</p>
                <p>Forwards out of the whole course, the habit rather than the technique: <strong>label a count as a count and a reading as a reading, and print the second one with its reasoning attached.</strong> That is the whole of section 11 in one sentence, and it is why a reader can use the four numbers above even knowing that only three of them are recomputable. <a href="/courses/obj/lessons/obj-relocations"><code>obj-relocations</code></a> and <a href="/courses/link/lessons/link-order"><code>link-order</code></a> are the next link in the chain and neither of them cares how you got here &mdash; which is the argument for having an IR, stated as a fact about the rest of this collection.</p>
                <p>Outward, the boundary as a scope statement rather than an apology. <strong>15 numbered limits, then 11 things a reader therefore cannot conclude beside 11 they can</strong> &mdash; and the second list being the longer one is the finding, because a course that printed only a cannot-list teaches its reader that the subject is unknowable, which is the opposite of what 17 measured bit patterns are for. Two of the eleven on the cannot side are the ones a reader is most likely to carry in the wrong direction: <em>that the fingerprint recovers the allocation</em> (it recovers consequences) and <em>that anything here is a performance claim about AArch64 or RISC-V</em> (neither of them ran).</p>
                <p>And the last thing this page owes you is retraction <strong>R16</strong>, which is a retraction of this course&rsquo;s own roadmap claim. It ticks the <em>Compiler Debug Information</em> item in <code>docs/courses-todo.md</code>, and it ticks the <strong>second</strong> half of it &mdash; reading a backend&rsquo;s decisions out of the bytes &mdash; and not the first. Nothing here emits DWARF; the <a href="/courses/dwarf/lessons/dwarf-intro"><code>dwarf</code> course</a> owns the format. What this course adds is the question that comes <em>before</em> the format: <strong>what can you know about a compiler when you have no debug information at all?</strong> That is a smaller question and, on this host, a reachable one, and it is why the item can honestly be ticked at all.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/compback/lessons/cb-abi">The Backend and the ABI</a></span>
                <span>Next: <a href="/courses/compback">Back to the course</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
