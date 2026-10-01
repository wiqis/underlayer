// RISC-V Atomics and the Vector Extension -- course landing page.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rvat_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("RISC-V Atomics and the Vector Extension — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson rvat-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>RISC-V Atomics and the Vector Extension</h1>
            <div class="lesson-meta">4 concepts &middot; 2 modules &middot; 101 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Three designs, and they differ in kind</h2>
                <p>This is the fourth RISC-V course in this section and the only one whose subject is the hardware's <em>concurrency</em> semantics rather than its bytes. Three things are on the table and they are not three degrees of the same idea:</p>
                <ul>
                    <li><strong>Where atomicity lives.</strong> On x86-64 it lives in a <em>prefix</em>. On RISC-V it lives in an <em>opcode</em>. That is not a naming difference; it decides what a reader can see in a disassembly and what a programmer is allowed to forget.</li>
                    <li><strong>Where ordering lives.</strong> x86-64 has a baseline and barriers on top. AArch64 gives every access a mode. RISC-V <em>defines the model as a relation between two sets inside one instruction</em> &mdash; and the fence is the primitive, not the exception hatch.</li>
                    <li><strong>Where the vector length lives.</strong> Not in the vector instruction. Not in a register file width. In a CSR the program has to go and read.</li>
                </ul>
                <p>Each of those is a design, and each of them is measurable on a host with no RISC-V hardware at all &mdash; because each is a statement about an <strong>encoding</strong> and about <strong>a compiler&rsquo;s choice</strong>, and those are the two things bytes are made of.</p>
            </div>

            <div class="unit unit-model">
                <h2>Read this before the first number: a third kind of absence</h2>
                <p>This course has <strong>no timing of any kind</strong>, and that is deliberate where its siblings have some. The <a href="/courses/simd/lessons/simd-width">SIMD course</a> measured speedups; <a href="/courses/smp/lessons/smp-atomic"><code>smp</code></a> measured them for ordering; <a href="/courses/a64simd/lessons/a64-neon"><code>a64simd</code></a> measured three of its own. Those are numbers about something a machine <em>did</em>. Here there is nothing to do them with:</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | sed -n '/FOUR ABSENCES/,/ONE LLVM TREE/p'
  * NO RISC-V MACHINE.  The host is x86-64.
  * NO EMULATOR.  qemu-riscv64 ABSENT, and spike ABSENT.
  * NO RISC-V LINKER.  `riscv64-linux-gnu-ld IS NOT INSTALLED` on this host, and
    neither are `riscv64-linux-gnu-gcc` or `riscv64-linux-gnu-as`, so there is
    not even a RISC-V LINKER to produce a running image.
  * NO SECOND ASSEMBLER.  GNU binutils has no RISC-V target here, so both
    readers of the two-reader check come from ONE LLVM TREE.
                </pre>
                </div>
                <p>So, in the file&rsquo;s own words: <strong><code>NOTHING IN THIS COURSE IS EVER EXECUTED</code></strong>. No reservation is ever <em>held</em>. No store-conditional is ever observed to succeed or to fail. No AMO is ever observed to be atomic. No fence is ever observed to order anything. No vector instruction is ever executed, so <code>vl</code> is never set by anything except a word in a file.</p>
                <p>And this is a <em>third</em> kind of absence, which is worth saying out loud because a reader arriving from the previous RISC-V course is expecting a milder version of the same caveat:</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | grep -A 4 'THIRD KIND OF ABSENCE'
  The ABI course lost the ability to TIME.  The privileged course lost the
  ability to OBSERVE THE SUBJECT and got a CSR address in its place.  This
  one loses the ability to OBSERVE WHETHER ANY OF ITS INSTRUCTIONS DOES THE
  THING IT EXISTS TO DO -- because an atomic instruction is a PROMISE about
  observable behaviour and a fence is a RELATION between two sets of
  operations, and neither promise nor relation is a bit pattern.
                </pre>
                </div>
                <p>That is the deeper reason the missing timings are not a shame. <strong>An atomic instruction is a promise about observable behaviour</strong>, and every measurement available here is a measurement about the promise&rsquo;s <em>text</em>: the bit that carries it, the pair of instructions that implements it, the number of bits the encoding has left over, and the compiler&rsquo;s decision about whether to emit it at all. What replaces a ratio is an instruction count, a bit position, or a refusal from a real assembler &mdash; and the sentence that goes with it is that <strong>a count does not know whether the instruction is fast</strong>.</p>
            </div>

            <div class="unit unit-example">
                <h2>The zero, counted on both sides</h2>
                <p>Here is the first measurement, and it is the one this course exists for. x86-64 has a LOCK prefix and it is a property of the <em>encoding</em>: ordinary arithmetic becomes atomic by carrying one, and <strong>forgetting it is silent</strong> &mdash; the instruction still assembles, still runs, and simply is not atomic. RISC-V has no such thing. Here is both counts, measured on the same host in the same session:</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | grep -A 2 'THE COUNT:'
  THE COUNT: 0 instructions in the RISC-V corpus take a lock prefix.
  ... and on the other side ...
  22 lock-prefixed instructions assembled, and 0 unprefixed
  line in the file.
                </pre>
                </div>
                <p>Zero. And a zero on its own is a fact about a search, not about an architecture. The artifact refuses to leave it there, and prints what it <em>replaced</em> instead &mdash; the count of instructions that are atomic with no prefix at all, which on RISC-V is nine operations plus a reservation pair, at two widths and four orderings. <strong>The zero is not an absence of features; it is a design decision, and the way to tell the difference is to print the number beside it.</strong></p>
                <p>And the x86-64 side is measured rather than quoted, which is the only honest way to run a contrast. The same host&rsquo;s assembler accepts twenty-two <code>lock</code> spellings against the SDM&rsquo;s quoted eighteen, and the twenty-second is a trap worth a page of its own: <code>lock bt</code> <strong>assembles</strong>, and <code>bt</code> is not one of the eighteen.</p>
            </div>

            <div class="unit unit-model">
                <h2>The one experiment that needs no clock</h2>
                <p>Here is the course&rsquo;s centre, and it is visible in a disassembly with nothing executed at all. The same C11 file, compiled twice, one letter apart:</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | sed -n '/WITH the A extension/,/0 CALLS/p'
  WITH the A extension  (-march=rv64ima)
    TOTAL 29 instructions: 2 lr, 2 sc, 5 amo*, 0 CALLS.
  ...
  WITHOUT it          (-march=rv64im)
    TOTAL 111 instructions: 0 lr, 0 sc, 0 amo*, 9 CALLS.
                </pre>
                </div>
                <p>With the letter, every C11 atomic in the file is an inline instruction. Without it, every one is a call into <code>__atomic_*_4</code> &mdash; and the <strong>4</strong> in the name is the width story arriving from the opposite direction to concept 1: one bit at <code>inst[12]</code> in the hardware path, a template parameter in a symbol name in the fallback path.</p>
                <p>This is what makes &ldquo;atomics are the compiler&rsquo;s choice&rdquo; mean something you can check. <strong>It is not that the compiler prefers one form. It has one form, and the form is a function of the <code>-march</code> string</strong> &mdash; decided before the compiler looks at your code.</p>
            </div>

            <div class="unit unit-why">
                <h2>And a vector length that is not in the instruction</h2>
                <p>The last thing worth knowing before you start is the sharpest result in the course. <code>vsetvli</code> programmes the element width, the register-group count and the tail and mask policies <em>at run time</em>, and that is how <strong>one fixed 32-bit encoding describes a vector whose length is not in the instruction at all</strong>. It sounds like a defect and it is the design.</p>
                <p>The compiler proves it, by going to read the length somewhere else:</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | sed -n '/PROVES THE LENGTH IS NOT/,/csrr t0/p' | head -8
    -O2  vadd_d   0xc22028f3  csrr a7, vlenb
    -O2  vmac_l   0xc22026f3  csrr a3, vlenb
    -O2  vmul_s8  0xc2202873  csrr a6, vlenb
    -O2  vsum_d   0xc22026f3  csrr a3, vlenb
    -Os  vmac_l   0xc22022f3  csrr t0, vlenb
    -Os  vsum_d   0xc22028f3  csrr a7, vlenb
                </pre>
                </div>
                <p><code>csrr a7, vlenb</code> &mdash; an ordinary Zicsr read, the same encoding as <code>csrr a7, cycle</code> with a different number. <strong>What VLEN is is a runtime value in a read-only register, and the instruction that configures the vector does not contain it.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>What this course owes its siblings, and does not re-teach</h2>
                <p>Every link below was verified present by a live route check before it was written, and the identical list is in the harness &mdash; which asserts <em>both</em> that each id is present and that each id this course has already retired is <strong>absent</strong>. A positive link list passes on any set of ids that exist and says nothing about the ones that do not, and the previous course in this section shipped four ids that 404&rsquo;d while its own artifact claimed every one had been verified.</p>
                <div class="hex-dump">
                <pre>  what a race is and what "atomic" has to mean for it -- the neutral course:
    /courses/smp/lessons/smp-atomic, /courses/smp/lessons/smp-ordering
  what a vector lane is, and what a reduction is -- the neutral course:
    /courses/simd/lessons/simd-width, /courses/simd/lessons/simd-reduce
  why a vectorised loop needs a remainder, and why it is hard to do
  portably -- /courses/simd/lessons/simd-boundaries
  what the vectoriser does and does not do
      /courses/simd/lessons/simd-compiler
  the SAME SUBJECT on x86-64, where it IS measurable on hardware:
    /courses/x86simd/lessons/x86-atomics, /courses/x86simd/lessons/x86-order
  the SAME SUBJECT on AArch64, where acquire and release are ACCESS MODES
  rather than two bits -- /courses/a64simd/lessons/a64-atomic,
    /courses/a64simd/lessons/a64-order
  and the section's spine, why there are no condition codes:
    /courses/rvabi/lessons/rv-noflags
                </pre>
                </div>
                <p><strong>Nothing on this course is neutral about vectors, atomics or ordering.</strong> <code>simd</code> and <code>smp</code> taught the principles; <a href="/courses/x86simd/lessons/x86-atomics"><code>x86simd</code></a> and <a href="/courses/a64simd/lessons/a64-atomic"><code>a64simd</code></a> gave the other two references. What is left for RISC-V is not a fourth statement of the same principle &mdash; it is the set of places where RISC-V made a <strong>different choice</strong>, and each of those is a place where the principle is expressed by a different mechanism.</p>
            </div>

            <div class="unit unit-connect">
                <h2>The four concepts</h2>
                <div class="concept-grid">
                    <div class="concept-card">
                        <h3><a href="/courses/rvat/lessons/rv-amo">1. The Reservation, and Why the Retry Is the Instruction</a></h3>
                        <p>26 min &middot; module: atomic</p>
                        <p>The zero, counted on both sides. Then the encoding: eleven operations under one opcode, the width as <strong>one bit</strong> of <code>funct3</code>, and <code>aq</code> and <code>rl</code> as two adjacent bits proved by XOR. Then <code>lr</code>/<code>sc</code>, where the retry is not syntax around the instruction &mdash; it is what the instruction is.</p>
                    </div>
                    <div class="concept-card">
                        <h3><a href="/courses/rvat/lessons/rv-fence">2. fence, and an Ordering Model Defined in Terms of It</a></h3>
                        <p>26 min &middot; module: atomic</p>
                        <p>Four fields, fifteen named spellings of two four-bit sets, and the sixteenth printed as a hole. Then the compiler&rsquo;s translation of the six C11 strengths, including the one that surprises everybody: an acquire-release fence compiles to an instruction that is not <code>fence</code> at all.</p>
                    </div>
                    <div class="concept-card">
                        <h3><a href="/courses/rvat/lessons/rv-vector">3. vsetvli and the Four Fields It Carries</a></h3>
                        <p>27 min &middot; module: vector</p>
                        <p>How one 32-bit word describes a vector of a length it does not contain, the three bits of the eleven-bit type field that no reachable instruction ever moves, and the tail policy that makes portable vector code hard &mdash; because the specification declines to require the fast one to be deterministic.</p>
                    </div>
                    <div class="concept-card">
                        <h3><a href="/courses/rvat/lessons/rv-dataflow">4. Decode the Data Path</a></h3>
                        <p>22 min &middot; module: vector</p>
                        <p>The mask as one bit in three instruction groups and a register that is not in the encoding; what the compiler emits at five optimisation levels; two readers on the same bytes; four poisons; and the measured/quoted boundary with eighteen retractions.</p>
                    </div>
                </div>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
