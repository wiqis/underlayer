// The AArch64 Machine: Modes, Memory and Faults -- Concept 1: SVC #imm16,
// the x8 convention, and the difference between an encoding and an ABI.
//
// The page order matters: this is the FIRST concept because the syscall is the
// simplest way a program at EL0 asks the machine for something, and because
// the subject splits cleanly in two -- half of it is a field in a 32-bit word
// and half of it is a convention the compiler has never heard of.  The
// retraction on the last page of the course lives in the middle of this one
// (R5, R6), and both of them are cases where the plan was right about a fact
// and wrong about a reason.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_syscall() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("SVC #imm16, and x8 Is a Convention and Not an Architecture — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
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
            <h1>SVC #imm16, and x8 Is a Convention and Not an Architecture</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/a64sys">The AArch64 Machine: Modes, Memory and Faults</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Everything in the last two courses happened while your code was <em>running</em>. This is the first instruction in the course that leaves the program, and it is the cheapest possible way to see the difference between the two things a course like this has to keep apart: <strong>the machine's encoding</strong>, which is architecture and which is in the instruction word, and <strong>the operating system's convention</strong>, which is a contract between a kernel and a compiler and which is in a register.</p>
                <p>The trap is that the two arrive as a single line of assembly. <code>svc #0</code> is one instruction and it looks like one fact, and a reader who has just been taught that AArch64 bakes a 16-bit constant into the instruction will naturally conclude that the constant <em>is</em> the syscall number. It is not. Both are true, they are different claims, and the page exists to make the difference measurable rather than asserted.</p>
                <div class="formula">
   TWO KINDS OF CLAIM ON ONE LINE OF ASSEMBLY

   svc #0

   ENCODING      the 16 bits at bits[20:5] are IN the
                 instruction, unsigned, range [0, 65535].
                 This is architecture.  A decoder
                 reads it with no operating system
                 involved at all.

   CONVENTION    x8 holds the same number, and the
                 KERNEL decides what it means.  This
                 is ABI.  A compiler has never heard
                 of it and will use x8 as a scratch
                 register in a function that never
                 executes a syscall.

   Reading one without the other is the mistake this
   page exists to make impossible.
                </div>
                <p>And before anything else, the constraint that decides what this page may claim at all: <strong>there is no AArch64 machine on the machine that wrote this course, no AArch64 emulator, and no AArch64 linker.</strong> Not one instruction here has been run. Every number below is a bit pattern, a count of bit patterns, an arithmetic identity, or a refusal from a real assembler. <a href="/courses/a64sys/lessons/a64-evidence">The last concept</a> prints the whole measured/quoted boundary, and <a href="/courses/priv/lessons/priv-convention">the neutral course's syscall concept</a> owns the principle.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: read the instruction word, not the mnemonic</h2>
                <p>Here is the whole encoding, measured from five real assembler outputs. Every word below is <span class="label label-bytes">MEASURED-ON-BYTES</span>: it came out of <code>clang</code> and it was read twice, by the decoder in the artifact and by <code>llvm-objdump-21</code>.</p>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 4 | sed -n '/the immediate is a FIELD/,/^$/p'
  [MEASURED-ON-BYTES] the immediate is a FIELD, and the assembler says how wide
     svc #0       0xd4000001  imm16 at bits[20:5] = 0x0000   svc      #0
     svc #1       0xd4000021  imm16 at bits[20:5] = 0x0001   svc      #1
     svc #63      0xd40007e1  imm16 at bits[20:5] = 0x003f   svc      #63
     svc #64      0xd4000801  imm16 at bits[20:5] = 0x0040   svc      #64
     svc #65535   0xd41fffe1  imm16 at bits[20:5] = 0xffff   svc      #65535
                </pre>
                </div>
                <p>Sixteen bits, at bits[20:5], and the fifth row is the interesting one because it is the boundary the assembler drew for us. Four more probes find it exactly:</p>
                <div class="hex-dump">
                <pre>$ for t in "svc #65536" "svc #-1" "brk #65536" "hlt #-1"; do ...
  svc #65536   REFUSED  error: immediate must be an integer in range [0, 65535].
  svc #-1      REFUSED  error: immediate must be an integer in range [0, 65535].
  brk #65536   REFUSED  error: immediate must be an integer in range [0, 65535].
  hlt #-1      REFUSED  error: immediate must be an integer in range [0, 65535].
                </pre>
                </div>
                <p><strong>The field is UNSIGNED, in an architecture where every other displacement is signed</strong> — and the diagnostic names a <em>range</em> rather than a signedness, so it reads like a complaint about a value that was negative to begin with. <code>svc #-1</code> is the same sixteen bits as <code>svc #65535</code>, and the assembler takes the second and refuses the first. If you have ever written <code>svc #-1</code> expecting the usual "all ones" idiom, you have met this and the diagnostic did not tell you what was wrong.</p>
                <p>Now the field map, which is the part a backend author needs and the part <code>llvm-objdump</code> will not print for you:</p>
                <div class="hex-dump">
                <pre>  1101 0100 000 0 0000 0000000000000000 00001
   |     |    |  | |   |                        |
   |     |    |  | |   the SIXTEEN-BIT IMMEDIATE, bits[20:5]
   |     |    |  | op0 = 0b00, and op1 = 0b000
   |     |    the L bit: 0 here, 1 for a privileged read
   bits[31:24] = 0xd4, the exception-generating group
                                     bits[4:0] = 0b00001 selects SVC

  The SAME five bits are SVC, HVC and SMC:
      svc 0xd4000001   bits[4:0] = 0b00001
      hvc 0xd4000002   bits[4:0] = 0b00010
      smc 0xd4000003   bits[4:0] = 0b00011
  ...and DCPS1 is 0xd4a00001, which has the SAME bits[4:0]
  and differs only in bits[23:22] and bit 21.
                </pre>
                </div>
                <p>So the operation field is <strong>not a mnemonic on its own</strong>. It is local to a table, and the table is selected by a two-bit field plus one more bit above it. That is the shape of the whole SYSTEM class and it is why a decoder has to be dispatched on a group before it can read a field — <a href="/courses/a64asm/lessons/a64-encoding">the encoding course's field map</a> stops at bits[28:25] and this is what is on the other side of that boundary.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The measurement: the same syscall, both architectures, and the relocations</h2>
                <p>Here is the cross-architecture comparison this course makes, and it is the <strong>only</strong> one. <a href="/courses/x86sys/lessons/x86-syscall">The x86-64 course measured 4.92&times; and 27.65&times;</a>; nothing on this page has a counterpart for either number, because there is no AArch64 clock on this host to read one with, and <strong>a fabricated ratio is worse than an admitted absence.</strong></p>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 4 | sed -n '/the same syscall, both arch/,/^$/p'
  [MEASURED-ON-BYTES] the same syscall, both architectures, hand-written
     THIS IS A COMPILE-TIME INSTRUCTION COUNT COMPARISON AND NOT
     A TIMING ONE.  NOTHING HAS BEEN EXECUTED ON EITHER SIDE.

     AArch64 (aarch64-linux-gnu)             x86-64 (host, variable length)
     0  0xd2800808 mov x8, #0x40             0  48 c7 c0 3c 00 00 00 movq
     1  0xd2800020 mov x0, #0x1              1  48 c7 c7 01 00 00 00 movq
     2  0x90000001 adrp x1, 0x0 &lt;a64&gt;        2  48 8d 35 00 00 00 00 leaq
     3  0x91000021 add x1, x1, #0x0          3  48 c7 c2 06 00 00 00 movq
     4  0xd28000c2 mov x2, #0x6              4  0f 05              syscall
     5  0xd4000001 svc #0                    5  c3                 retq
     6  0xd65f03c0 ret

     instructions: AArch64 7, x86-64 6
     bytes of CODE: AArch64 28, x86-64 31
     relocations:   AArch64 2, x86-64 1
                </pre>
                </div>
                <p>Three things in that block, and the third is the real one.</p>
                <ul>
                    <li><strong>The syscall is one instruction on both.</strong> Four bytes on AArch64, two on x86-64 — <code>0f 05</code>. Everything else in the block is the two architectures disagreeing about where the <em>number</em> goes and about how to name a string.</li>
                    <li><strong>The reason AArch64 can afford a 16-bit immediate is the fixed 32-bit length.</strong> The obvious explanation — "x86-64 has no immediate so it must use a register" — is a statement about <code>SYSCALL</code> and not about the argument. The deeper one is that AArch64 already spent four bytes on the instruction, so a constant inside it is free, while on x86-64 a 7-byte <code>movq $60, %rax</code> in front of a 2-byte syscall costs more than the syscall itself. <strong>The encoding fixes the economics and the economics picks the design.</strong></li>
                    <li><strong>Two relocations against one.</strong> AArch64 spends two instructions <em>and two relocations</em> to name a string; x86-64 spends one of each. That is a fact about an object file and it is checkable with <code>llvm-readelf-21 -r</code> on a machine that has never run either. <a href="/courses/reloc/lessons/reloc-arch-contrast">The relocation course</a> owns what a relocation <em>is</em>; <a href="/courses/a64sys/lessons/a64-pagetables">concept 5</a> measures why a page table always pays the pair.</li>
                </ul>
                <h3>Now the part that separates the two claims</h3>
                <p>The corpus has a function in which <strong>x8 is not mentioned at all</strong>. Not "is not used" — <em>not mentioned in the source</em>. And here is what the compiler does with it, at every optimisation level:</p>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 4 | sed -n '/the x8 CONVENTION/,/^$/p'
  [MEASURED] the x8 CONVENTION, and what the compiler does with x8
     -O0  sys_const        20 instructions   x8 named: YES
     -O0  sys_global       21 instructions   x8 named: YES
     -O0  sys_no_number    17 instructions   x8 named: YES
     -O1  sys_const         9 instructions   x8 named: YES
     -O2  sys_global       10 instructions   x8 named: YES
     -O2  sys_no_number     8 instructions   x8 named: YES
     -O2  sys_arg6        15 instructions   x6 named: YES
                </pre>
                </div>
                <p><code>sys_no_number</code> never mentions x8 in its C, and the compiler uses it anyway — as the <code>adrp</code> base for the next address it has to form. <strong>So x8 is an ordinary caller-saved temporary to the compiler.</strong> It is the AAPCS64 Indirect Result Location Register and an ordinary scratch, and the syscall convention <em>reuses</em> it.</p>
                <div class="formula">
   THE RETRACTION, and it is R6

   DRAFT      "x8 is the syscall-number register, so
               a compiler must treat it as reserved
               across a `svc`."

   MEASURED   clang uses x8 as a scratch register in
               every one of the four functions that do
               not mention it, at every one of the four
               optimisation levels -- including inside
               the same function that later issues
               `svc #0`.

   The two sentences have different consequences.
   The first says a compiler has a rule.  The second
   says the compiler has none, and that the rule
   lives somewhere else entirely.

   A page that said "x8 is reserved" would produce a
   wrapper that is correct and a reader who is wrong,
   and the reader is what carries forward.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the argument audit, and the level where the contract is invisible</h2>
                <p>Every argument in the corpus is a <code>volatile</code> global with its own distinctive constant, so the disassembly <strong>names</strong> the argument: the load of <code>0x4444</code> <em>is</em> argument three. A census would say "seven registers were written"; an audit says which argument was in which register, and can therefore disagree with a specification instead of merely agreeing with itself.</p>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 4 | sed -n '/the ARGUMENT AUDIT/,/^$/p' | tail -34
     function         x0  x1  x2  x3  x4  x5  x6  x7  9th

     --- O2 ---
     sys_arg1         VA0  .  .  .  .  .  .  .   -
     sys_arg2         VA0  VA1  .  .  .  .  .  .   -
     sys_arg5         VA0  VA1  VA2  VA3  VA4  .  .   -
     sys_arg6         VA0  VA1  VA2  VA3  VA4  VA5  .  .   -
     sys_arg7         VA0  VA1  VA2  VA3  VA4  VA5  VA6  .   -
     sys_arg8         VA0  VA1  VA2  VA3  VA4  VA5  VA6  VA7   -
     sys_arg9_stack   VA0  VA1  VA2  VA3  VA4  VA5  VA6  VA7   stack

     --- O0 ---   every argument is SPILLED, so the assignment the ABI names is
     sys_arg1         .  .  .  .  .  .  .  .   -
     sys_arg2         .  .  .  .  .  .  .  .   -
     sys_arg8         .  .  .  .  .  .  .  .   -
     sys_arg9_stack   .  .  .  .  .  .  .  .   stack

  [RESULT]           111 of 111 argument placements land in the register whose
                     NUMBER is the argument's, at -O1, -O2 and -Os, and the
                     ninth is never a register
                </pre>
                </div>
                <p>Four results, and the third is the one to remember.</p>
                <ul>
                    <li><strong>111 of 111, at three levels.</strong> Argument zero in <code>x0</code>, argument seven in <code>x7</code>, and the name matches the number every time. That is the AAPCS64 rule, audited rather than quoted.</li>
                    <li><strong>The ninth argument is not a register.</strong> It is a <code>volatile</code> C object reached through an <code>"m"</code> constraint, so the compiler materialises its <em>address</em> into a register and the value stays in memory. Eight argument registers, and after that the stack — showing up inside a <em>syscall</em> rather than inside a function call, which is a thing a reader does not expect, because a Linux syscall has at most six arguments and the eighth register is dead weight the architecture supplies and the kernel ignores.</li>
                    <li><strong>At <code>-O0</code> the contract is not visible at all.</strong> Every argument is spilled to the stack and reloaded immediately before the <code>svc</code>. The contract still holds — the reloads target <code>x0</code> through <code>x7</code> — but a reader auditing an ABI from a <code>-O0</code> build is auditing the compiler's spill slots and not the contract. <strong>This is a negative result and the artifact prints it as one</strong>, and the harness asserts the audit at the three levels where the contract is legible rather than pretending <code>-O0</code> is a fourth.</li>
                    <li><strong>The six-argument limit is <span class="label label-quoted">QUOTED</span>, and the compiler does not know it.</strong> It fills <code>x6</code> and <code>x7</code> for <code>sys_arg7</code> and <code>sys_arg8</code> because the source named them. That limit lives in a kernel, and no part of the language or of the ABI this compiler implements mentions it.</li>
                </ul>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 4 | sed -n '/the compiler emits x6/,/^$/p'
  [MEASURED] the compiler emits x6 and x7 for a syscall that has six
     -O2  sys_arg6        15 insn   mentions x6 0 times, x7 0 times
     -O2  sys_arg7        16 insn   mentions x6 2 times, x7 0 times
     -O2  sys_arg8        18 insn   mentions x6 2 times, x7 2 times
                </pre>
                </div>
                <p>A literal number and a loaded number, for the last measurement on the page — and the reason it matters is that it makes the next concept's subject appear without warning:</p>
                <div class="hex-dump">
                <pre>     sys_const, -O2:                    sys_global, -O2:
       adrp x0, VA0                          adrp x8, VN
       ldr x0, [x0, :lo12:VA0]              adrp x9, VA0
       adrp x8, VA1                          ldr x8, [x8, :lo12:VN]
       ldr x1, [x8, :lo12:VA1]              adrp x9, VA1
       adrp x8, VRET                         ldr x0, [x9, :lo12:VA0]
       svc #0                                adrp x9, VA1
       str x0, [x8, :lo12:VRET]              ldr x1, [x9, :lo12:VA1]
       ret                                    svc #0
                                            adrp x8, VRET
                                            str x0, [x8, :lo12:VRET]
                                            ret
                </pre>
                </div>
                <p><code>sys_const</code> gets 64 from an immediate and costs no memory access. <code>sys_global</code> gets it from a <code>volatile</code> and costs an <code>adrp</code> and an <code>ldr</code> — and that is the same <strong>pair of two relocations</strong> the x86-64 comparison in the previous section was about. A syscall number that is a variable is indistinguishable from a page-table address in the instruction stream, and <strong>the only thing that tells them apart is a relocation.</strong></p>
                <h3>What this page cannot show</h3>
                <p>It cannot show that <code>svc #0</code> traps, that the kernel reads x8, that 64 means <em>write</em>, that the result comes back in <code>x0</code>, or that a wrong number produces <code>ENOSYS</code>. <strong>All five are <span class="label label-quoted">QUOTED</span> and all five would need an AArch64 machine or an emulator, and this host has neither.</strong> The syscall numbers themselves — 64 for write, 63 for read, 222 for mmap — are quoted from <code>include/uapi/asm-generic/unistd.h</code> in the Linux tree, and a number confirmed only by a header file is a weaker kind of claim than one confirmed by a return value. What the page <em>can</em> show is that the compiler puts the number where the convention says, that the argument registers are filled in the order the ABI names, that the ninth argument is not a register, that <code>-O0</code> hides the contract, and that the encoding carries a sixteen-bit unsigned constant. Five results, and every one of them is checkable in a file on this disk.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Find the boundary yourself, with the assembler as the oracle.</strong> Write a <code>.s</code> file with <code>svc #0</code>, <code>svc #65535</code>, <code>svc #65536</code> and <code>svc #-1</code> and assemble it for <code>aarch64-linux-gnu</code>. <em>(Expect the first two to assemble and the last two to be refused with the identical message <code>immediate must be an integer in range [0, 65535]</code>. Then add <code>svc #-1</code> in a <em>comment</em> and notice that the <code>#</code> on AArch64 is ambiguous: it is a comment marker and it is the immediate prefix, which is a small trap in every assembler language and a large one in this one.)</em></li>
                    <li><strong>Prove the two claims are two claims.</strong> Write two functions: one that puts 64 in <code>x8</code> and issues <code>svc #0</code>, and one that issues <code>svc #64</code> and does not touch <code>x8</code> at all. Disassemble both. <em>(Expect the same 32-bit shape with the number in a different place, and then ask the question this page exists for: on a real machine, which of those two does a Linux kernel read? The answer is <em>neither alone</em> — the Linux syscall path reads <code>x8</code> and the immediate is what the exception handler sees in <code>ESR_EL1</code> bits 24:5. A field and a convention, both present, doing different jobs.)</em></li>
                    <li><strong>Audit your own code for the -O0 trap.</strong> Compile a function that takes nine arguments at <code>-O0</code> and at <code>-O2</code> and diff the disassembly. <em>(Expect at <code>-O0</code> that the argument registers are spilled and reloaded and that a reader cannot tell which slot is which argument from the code; at <code>-O2</code> that the placement is direct. Then compile at <code>-O1</code> and <code>-Os</code> and check you get the same answer — because a claim about an ABI that holds at one optimisation level and not another is a claim about the compiler.)</em></li>
                    <li><strong>Count the relocations your own program needs, on both architectures.</strong> A function that returns the address of a static 4 KiB-aligned array, compiled for <code>aarch64-linux-gnu</code> and for the host, and then <code>llvm-readelf-21 -r</code> on each. <em>(Expect two relocations against one. Then move the array into <code>.data</code> and try again, and then delete the <code>adrp</code> and write <code>adr</code> by hand, and expect the assembler to refuse it past 1&nbsp;MiB. That refusal is the boundary concept 4 measures properly, and it is a <em>different</em> boundary from the one that makes the pair necessary.)</em></li>
                    <li><strong>Break the poison and watch the number move.</strong> Run <code>python3 a64sys.py --run</code>, note that section 9 reports <code>1516 named, 0 DISAGREEMENTS</code>, then delete <code>m_sysreg</code> from the dispatch in <code>a64sys.py</code> and run it again. <em>(Expect 1459 named and 57 disagreements, and every one of the 57 is an <code>mrs</code> or an <code>msr</code> printed by name. That is the whole argument for section 9B in one command: a cross-check that has never been seen to fail is a check with no reason to be believed.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, three. <a href="/courses/a64abi/lessons/a64-registers">Concept 2 of the ABI course</a> is the hinge for the argument audit: <code>x0</code> and <code>w0</code> are the same register and a 32-bit write zeroes the top half, so a reader who has not read that page will read <code>sys_arg1</code>'s <code>x0</code> as a 64-bit slot when it is a value the kernel will widen. <a href="/courses/a64asm/lessons/a64-immediate">The immediate chapter of the encoding course</a> owns the <code>MOVZ</code>/<code>MOVK</code> pair that puts a literal in <code>x8</code>, and the <code>adrp</code>/<code>:lo12:</code> pair that <code>sys_global</code> needs. <a href="/courses/a64asm/lessons/a64-verify">The encoding course's cross-check</a> is where the decoder this course imports was poisoned on purpose, and the poison you just reproduced is the same experiment with a different guard.</p>
                <p>Sideways, three neighbours that own the edges. <a href="/courses/priv/lessons/priv-convention">The neutral course owns the principle</a> — that a syscall is a controlled transfer to a more privileged level — and this page owes it the idea and owns only the AArch64 reference. <a href="/courses/x86sys/lessons/x86-syscall">The x86-64 syscall concept</a> is the sibling reference for the same subject, and the table at the top of this page is the honest place the two meet: a compile-time instruction count and a relocation count, and no timing anywhere. <a href="/courses/priv/lessons/priv-doors">The neutral course's privilege concept</a> owns what EL0 and EL1 <em>mean</em>; read it first if the names are new, because this page assumes you know that <code>svc</code> traps upward.</p>
                <p>Outward, and the general form is worth carrying out of here. <strong>A constant in an instruction and a value in a register look identical in the assembly and are different kinds of claim.</strong> The same distinction shows up three more times in this course: <a href="/courses/a64sys/lessons/a64-exceptions">the syndrome</a> is a field with a documented layout in one register and a convention for reading it in another; <a href="/courses/a64sys/lessons/a64-virtual">TCR_EL1</a> is a register whose fields are quoted and whose address is not; and <a href="/courses/a64sys/lessons/a64-pagetables">a page-table descriptor</a> is an ordinary 64-bit word that means something only under a convention. A learner writing a backend meets this on day one and it does not go away, and the habit of asking <em>"which of the two is this?"</em> is worth more than any of the specific numbers on this page.</p>
                <p>And the last honest word: this page is <em>about a machine that does not exist here</em>, and every claim on it says which of the three kinds it is. <a href="/courses/a64sys/lessons/a64-evidence">Concept 6</a> is the full table, and it is the concept that makes the other five trustworthy.</p>
            </div>

            <div class="lesson-footer">
                <span>Start: <a href="/courses/a64sys/lessons/a64-exceptions">One Register, Three Fields, and Thirty-Nine Meanings</a></span>
                <span>End of concept 1 &middot; <a href="/courses/a64sys">course index</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
