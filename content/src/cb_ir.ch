// Compiler Backend: From IR to Machine Code -- concept 1: what an IR is for,
// and what it must not be.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_cb_ir() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("What an IR Is For, and What It Must Not Be — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson compback-concept">
            <a href="/courses/compback" class="back-link">Compiler Backend: From IR to Machine Code</a>
            <h1>What an IR Is For, and What It Must Not Be</h1>
            <div class="lesson-meta">24 min &middot; Concept 1 of 6 &middot; module: the representation &middot; <a href="/courses/compback">Compiler Backend: From IR to Machine Code</a></div>

            <div class="unit unit-why">
                <h2>The hole in the chain, and what a backend is for</h2>
                <p>You have an intermediate representation and you want machine code. That is the whole problem statement, and it is worth noticing how much it does not say. It does not say which instruction. It does not say which register. It does not say in what order. <strong>Those three questions are what a backend is</strong>, and a backend is not a formatter &mdash; it is three passes that each take a sequence of operations and each answer one of them.</p>
                <p>Before the first number, the thing that governs what a number is allowed to be. This host has three absences and one presence, and the artifact prints all four before it prints anything else:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/^  compiler:/,/^$/p'
  compiler:      Ubuntu clang version 21.1.8 (6ubuntu1)
  disassembler:  Ubuntu LLVM version 21.1.8
                </pre>
                </div>
                <p><strong>MEASURED</strong> for x86-64 code, because it ran. <strong>MEASURED-ON-BYTES</strong> for an AArch64 or RISC-V instruction, because a word was emitted and read back and nothing more. <strong>QUOTED</strong> for anything about what a machine would <em>do</em>, with a document named. Three labels and no fourth, because the provenance table on the last page prints a count that only adds up if the spellings are consistent.</p>
                <p>And a word about where the tool is. <strong>LLVM is the oracle and never the dependency.</strong> Read what clang emits; compare it against an allocator and a scheduler you wrote. Section 2 of the artifact prints what replaces each piece of LLVM by file name, and the reason it prints it as a table is that a learner who copies clang&rsquo;s architecture will not be able to build one &mdash; the ten files that do the work are short enough to read in an afternoon, and a finished backend tells you what finished looks like, not how to get there.</p>
            </div>

            <div class="unit unit-model">
                <h2>The ratio, and why it has to be read in both directions</h2>
                <p>The positive half of the argument for an IR is a ratio: how many IR instructions clang emitted, how many machine instructions the second reader printed, and the quotient. One source, five optimisation levels, x86-64.</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/level   IR insns/,/IS A STORY/p'
  level   IR insns   machine insns   IR/machine
  O0           260             235        1.106
  O1            99             117        0.846
  O2           207             253        0.818
  O3           207             253        0.818
  Os            99             103        0.961

  the ratio spans 0.818 to 1.106 across five levels, and it is NOT
  MONOTONIC: -O1 gives a SMALLER ratio than -O0 because -O0 emits
  MORE machine instructions than IR and -O1 emits fewer. §KEEP§A NUMBER
  THAT MOVES IN BOTH DIRECTIONS IS A MEASUREMENT; A NUMBER
  THAT ONLY FALLS AS THE COMPILER GETS BETTER IS A STORY.
                </pre>
                </div>
                <p><strong>Above 1.0 the backend deleted instructions the IR had. Below 1.0 the backend inserted them</strong> &mdash; an address computation, a zero extension, a spill reload. Both directions are decisions, and <code>-O0</code> sits above because it spills every argument while <code>-O2</code> sits below because it inserts vector setup. That is the whole reason the table has five rows and not one average: <strong>a ratio read in one direction is a score, and a score cannot move up.</strong></p>
                <p>And <code>-O1</code> gives a smaller ratio than <code>-O0</code>. Nobody writes that sentence in a tutorial. It is here because it is what the machine did.</p>
                <h3>The half nobody states</h3>
                <p>The same source, compiled for three targets at the same level. How much of the IR is common and how much is target-specific:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | grep -A 5 'AT -Os THE THREE TARGETS SHARE'
  AT -Os THE THREE TARGETS SHARE 17 OF 19 OPCODES, AND THE 2 THAT
  ARE TARGET-SPECIFIC ARE:
    insertelement      riscv64
    shufflevector      riscv64
                </pre>
                </div>
                <p>At <code>-O2</code> and <code>-O3</code> and <code>-O1</code> all three targets share every opcode. At <code>-Os</code> RISC-V emits two the others do not, <strong>from the same source at the same optimisation level</strong> &mdash; and <code>-Os</code> emits <em>more</em> IR for RISC-V than <code>-O2</code> does.</p>
                <p>So the finding is neither &ldquo;an IR is target-independent&rdquo; nor &ldquo;an IR is target-dependent&rdquo;. It is this: at <code>-O2</code> all three targets agree on every opcode, and the machine codes still differ.</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | grep -A 4 'THE MACHINE CODES AT -O2'
  target          IR insns   machine insns   IR/machine
  x86_64               207             253        0.818
  aarch64              207             190        1.089
  riscv64              203             207        0.981
                </pre>
                </div>
                <p><strong>Three targets, one opcode set, three different instruction counts: 253, 190 and 207.</strong> The IR is the same and the code is not, and every instruction of the difference is a decision the backend made. That is the sentence an IR earns its keep on, and it is the one an &ldquo;IR is portable&rdquo; slide never prints.</p>
                <div class="formula">
   DOES:      one representation every backend reads, so an
              optimisation is written once and benefits from
              targets that did not exist when it was written.
              MEASURED HERE: 17 of 19 opcodes are common to
              all three targets.

   DOES NOT:  hide the target.  The IR is target-INDEPENDENT
              in its OPERATIONS and target-DEPENDENT in its
              SHAPES, and the shapes are where a backend
              lives: vector WIDTH, the width of an integer,
              and whether a multiply is fused.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>A level of -O is not a ranking</h2>
                <p>The vectoriser is the most capability-sensitive pass in the compiler, and this corpus shows it entering at one level and not another. Measured over the whole corpus, once per level, for each target:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/level   target          IR vector ops/,/IR vector operations across/p'
  level   target          IR vector ops   machine vector insns
  O0      x86_64                       0                      0
  O0      aarch64                      0                      0
  O0      riscv64                      0                      0
  O1      x86_64                       0                      0
  O1      aarch64                      0                      0
  O1      riscv64                      0                      0
  O2      x86_64                       2                     42
  O2      aarch64                      2                     14
  O2      riscv64                      2                     20
  O3      x86_64                       2                     42
  O3      aarch64                      2                     14
  O3      riscv64                      2                     20
  Os      x86_64                       0                      0
  Os      aarch64                      0                      0
  Os      riscv64                      2                     26

  IR vector operations across all three targets:  -O1 0, -O2 6, -O3 6, -Os 2.
                </pre>
                </div>
                <p><code>-O1</code> vectorises nothing. <code>-O2</code> and <code>-O3</code> emit six IR vector operations across the three targets. <code>-Os</code> emits two &mdash; <strong>on RISC-V only</strong>, and it is a level whose whole purpose is code size.</p>
                <p>So: <strong>a level of <code>-O</code> is a set of objectives, not a ranking.</strong> A level is a request, and the compiler decides which of your requests it can honour given what the target makes cheap. <code>-Os</code> asked for small code and the RISC-V target&rsquo;s vector extension made the vector form <em>smaller</em>, so it took it.</p>
                <h3>One function, instruction by instruction</h3>
                <p>The function chosen for the disassembly is <code>walk</code>, and the choice is deliberate: it is the only one in the corpus with a reduction the vectoriser can take <em>and</em> a non-reduction it cannot, so the level at which it fires shows up as a change rather than as an absence.</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/  -O0    27 instructions/,/  -Os    16/p'
  -O0    27 instructions, 112 bytes, 0 SSE/AVX operands
  -O1    18 instructions,  64 bytes, 0 SSE/AVX operands
  -O2    59 instructions, 222 bytes, 49 SSE/AVX operands
  -O3    59 instructions, 222 bytes, 49 SSE/AVX operands
  -Os    16 instructions,  42 bytes, 0 SSE/AVX operands
                </pre>
                </div>
                <p><strong><code>-O0</code> emits 27 instructions and <code>-O2</code> emits 59 &mdash; more, not fewer.</strong> And the instructions that appeared are not random: they are the ones that existed only to give the stack a shape.</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | grep -A 5 'THE DIFFERENCE IN ONE LINE'
  THE DIFFERENCE IN ONE LINE: -O0 emits 27 instructions and -O2 emits
  59 -- MORE, NOT FEWER -- and §KEEP§THE INSTRUCTIONS THAT APPEARED
  ARE NOT RANDOM EITHER.
  §KEEP§THEY ARE THE ONES THAT EXISTED ONLY TO GIVE THE STACK A
  SHAPE: -O0 SPILLS EVERY ARGUMENT AND -O2 SPILLS NOTHING IN A LEAF.
                </pre>
                </div>
                <p>Read the <code>-O0</code> body and the extra instructions are <code>pushq %rbp</code>, <code>movq %rsp, %rbp</code>, and a run of <code>movq &lt;slot&gt;(%rbp), &lt;reg&gt;</code> that loads each argument back out of memory immediately after storing it in. Read the <code>-O2</code> body and there is no frame at all &mdash; the function is a leaf, and a leaf needs no frame.</p>
                <p>So the honest reading of &ldquo;<code>-O0</code> has more instructions&rdquo; is not &ldquo;<code>-O0</code> is worse&rdquo;. It is: <strong><code>-O0</code> spent twenty-seven instructions keeping its arguments in memory, and <code>-O2</code> kept them in registers and spent some of the difference on arithmetic that eight scalar instructions could not express.</strong> The count went up and the reason the count went up is that there is less memory traffic.</p>
            </div>

            <div class="unit unit-example">
                <h2>What replaces LLVM, by file name</h2>
                <p>This is the table that makes the mission&rsquo;s claim concrete rather than aspirational. The mission says a learner finishing the chain should be able to emit machine code for x86-64, AArch64 and RISC-V <strong>without depending on LLVM or any other backend</strong>. Here is the file that does each job:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/AND WHAT IS STILL MISSING/,/^  \* Exception/p'
  * SSA construction and PHI placement.  Our IR is straight-line and
    the reason is in cbir.py's own docstring: instruction selection,
    allocation and scheduling are three questions about a SEQUENCE of
    operations, and a branch would put a fourth question in the
    middle of them.
  * A real CFG.  No basic blocks, no dominators, no loop structure.
  * Peepholes, and the x86-64 and RISC-V compressed encodings.
  * Exception frames and debug information.
                </pre>
                </div>
                <p>Read that missing list as a design decision rather than an omission. The three passes are three questions about a <em>sequence</em>. Add a branch and you get a fourth question &mdash; <em>which of the two paths does this value reach, and is it live on both?</em> &mdash; and it sits <strong>in the middle of the other three</strong>, because liveness through a control-flow graph is what register allocation actually is. The straight-line IR is a <em>simplification of the subject, declared as one</em>, and the declarations are the three files in the table above.</p>
                <p>It is also worth being blunt about the two listings the table does not have. <strong>There is no floating point, no vectors and no atomics in this IR.</strong> Twelve integer operations, and the corpus has no <code>&lt;2 x i32&gt;</code> anywhere. The vector register file &mdash; which is where the interesting register pressure lives on a real target &mdash; is absent from every measurement in this course. The pages that use SSE operand counts are reading <em>clang&rsquo;s</em> output, not this course&rsquo;s allocator&rsquo;s.</p>
                <div class="callout callout-note">
                    <p><strong>Three labels, and the arithmetic a reader can do with a pencil.</strong> The field-width arithmetic is not in the missing list because it is not missing from the subject &mdash; it is in <a href="/courses/compback/lessons/cb-isel">concept 2</a>: four five-bit register fields in a 32-bit AArch64 word is twenty bits of thirty-two, and the remaining twelve hold <code>sf</code>, a ten-bit group selector, the MADD/MSUB bit and the shift amount. Twenty plus twelve is thirty-two, and both halves are checked against words a real assembler emitted. That kind of arithmetic is the part of backend work that survives every toolchain that ever existed.</p>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Read the ratio in both directions on purpose.</strong> <em>(Compile one function at <code>-O0</code>, <code>-O1</code>, <code>-O2</code> and <code>-Os</code>. Count the IR instructions and the machine instructions and take the quotient. Now write down what each of the two numbers means separately before you write down the ratio: at <code>-O0</code> you should find the quotient <strong>above</strong> 1.0 and the reason is a prologue and a run of reloads; at <code>-O2</code> it should be <strong>below</strong> 1.0 and the reason is inserted work. If you cannot say which direction you are in for your own function, you have a ratio and not a measurement.)</em></li>
                    <li><strong>Compile the same source for two targets at the same level and diff the opcode sets.</strong> <em>(<code>clang -S -emit-llvm -O2</code> and <code>-Os</code>, for x86-64 and for RISC-V. At <code>-O2</code> expect the opcode sets to be identical and the machine counts to differ. At <code>-Os</code> expect the RISC-V IR to carry opcodes the others do not. That is the two-named-opcodes finding reproduced on your own corpus, and it is the cheapest way to see that <strong>the IR hides the target&rsquo;s operations but not its shapes</strong>.)</em></li>
                    <li><strong>Count the -O0 frame instructions and then prove they are all frame instructions.</strong> <em>(Disassemble a leaf function at <code>-O0</code> and at <code>-O2</code>. At <code>-O0</code>, find the <code>push %rbp</code> / <code>mov %rsp, %rbp</code> pair and every <code>movq &lt;slot&gt;(%rbp), &lt;reg&gt;</code> that reloads an argument. At <code>-O2</code> confirm there is no frame at all. The count going <em>up</em> with optimisation is not a paradox and it is not the compiler regressing &mdash; it is the stack traffic disappearing. That is the sentence <code>walk</code> exists to demonstrate.)</em></li>
                    <li><strong>Add a branch to your own IR and watch what it costs you.</strong> <em>(Take the straight-line IR in <code>cbir.py</code> and put a conditional jump in the middle. Now you need a live range per path, and the allocator&rsquo;s question changes from &ldquo;is this interval live from a to b&rdquo; to &ldquo;is this interval live on <em>both</em> paths&rdquo;, and a value live on one path only can be assigned to a register that the other path overwrites. That is not a small change and it is not a bug in your code &mdash; it is the fourth question the straight-line IR was chosen to postpone. The docstring in <code>cbir.py</code> says exactly this, and this exercise is how you find out whether you believed it.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/exe/lessons/exe-latency"><code>exe-latency</code></a> is where you met the idea that an instruction is not free and that its cost depends on what it waits for. This concept deliberately does not repeat any of it: the question here is not what an instruction costs but <strong>how many of them a backend decided to emit</strong>, and a count does not know whether the instruction is fast. <a href="/courses/isa/lessons/isa-opcodes"><code>isa-opcodes</code></a> has the fourteen <code>0F xx</code> opcodes this page never names, and the encodings of all three targets are in <a href="/courses/x86asm/lessons/x86-integers"><code>x86-integers</code></a>, <a href="/courses/a64asm/lessons/a64-encoding"><code>a64-encoding</code></a> and <a href="/courses/rvasm/lessons/rv-encoding"><code>rv-encoding</code></a> &mdash; this course&rsquo;s encoder is checked <em>against</em> those courses&rsquo; decoders rather than forked from them, and <a href="/courses/compback/lessons/cb-isel">concept 2</a> prints the result.</p>
                <p>Forwards, the three questions. <a href="/courses/compback/lessons/cb-isel">Instruction selection</a> answers <em>which machine form</em>, and its central finding is a selector that never fails once and still computes a different number. <a href="/courses/compback/lessons/cb-regalloc">Register allocation</a> answers <em>which register</em>, and its central finding is that being wrong in one direction makes an allocator look <em>better</em>. <a href="/courses/compback/lessons/cb-sched">Scheduling</a> answers <em>which order</em>, and its central finding is that the worst schedule it found was the fastest one.</p>
                <p>Outward, this concept is the first half of a course whose whole subject is <strong>how you check your own work</strong>. Every ratio here is a count, and a count is only evidence because something else counted it independently &mdash; the IR reader is ours and the machine counter is <code>llvm-objdump-21</code>&rsquo;s. <a href="/courses/compback/lessons/cb-verify">The last concept</a> turns that around and asks what you can recover from bytes you did not write, and the answer is three counts and one inference, which is not the same thing.</p>
                <p>And the honesty at the end of this page is not a disclaimer, it is the finding. <strong>Every ratio in it has a denominator you can argue with.</strong> The IR reader counts one line per result-producing instruction and nothing else: it does not count inside a <code>define</code>, it does not count a <code>declare</code>, and it does not count metadata. The counts are 260 and 207 against 235 and 253, and the counting rule is stated rather than assumed, and <a href="/courses/compback/lessons/cb-verify">the last concept</a> numbers that as limit 13 among fifteen.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/compback">Compiler Backend: From IR to Machine Code</a></span>
                <span>Next: <a href="/courses/compback/lessons/cb-isel">Instruction Selection</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
