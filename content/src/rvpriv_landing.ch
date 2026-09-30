// The RISC-V Privileged Architecture -- course landing page.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rvpriv_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The RISC-V Privileged Architecture — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson rvpriv-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>The RISC-V Privileged Architecture</h1>
            <div class="lesson-meta">4 concepts &middot; 2 modules &middot; 101 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
                <p>Everything in the two RISC-V courses before this one was about the base instruction set. This course is about the part that is <em>not</em> the base instruction set &mdash; and the first thing to understand is that on RISC-V that part is <strong>a document</strong>. There are three privilege modes and they are not a hardware feature with a name so much as four bits of a CSR address and a rule in a specification saying what those bits do.</p>
                <p>Here is the whole convention in one twelve-bit number:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | grep -A 2 'The top two bits'
  The top two bits (csr[11:10]) indicate whether the register is read/write
  (00, 01, or 10) or read-only (11). The next two bits (csr[9:8]) encode the
  lowest privilege level that can access the CSR.
                </pre>
                </div>
                <p>Four bits. <code>stvec</code> is <code>0x105</code> and <code>mtvec</code> is <code>0x305</code>, and the artifact puts them side by side to make the whole convention visible:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | grep -A 3 'So `stvec` at 0x105'
  So `stvec` at 0x105 is 00 / 01 / 0x05: read/write, lowest privilege S,
  number 5. `mtvec` at 0x305 is 00 / 11 / 0x05: read/write, lowest privilege
  M, number 5. THE SAME NUMBER, FIVE, IN BOTH, AND THE ONLY DIFFERENCE IS TWO
  BITS OF PRIVILEGE.
                </pre>
                </div>
                <p>Two bits. Both registers want a trap vector; both call it number 5; and the privilege bits are the only thing that makes them different registers. And encoding 2 in that field is <strong>a hole</strong>: the artifact prints a <code>RESERVED</code> row in its own address table rather than omitting it, because a table with a gap and a table with a hole are different tables and a reader who has not seen both cannot tell which one they are looking at.</p>
                <p>That is the shape of the subject. A privileged architecture is not mostly logic; it is mostly <em>addresses, and rules about addresses</em>. And the rules are not observable on a build machine, which is the honest difficulty of the whole subject and the reason this course is built the way it is.</p>
            </div>

            <div class="unit unit-model">
                <h2>Read this before the first number: four absences</h2>
                <p>This course has <strong>no runtime claim of any kind</strong>. Not because it is shy, but because it cannot: there is no RISC-V machine, no emulator, and not even a RISC-V linker on the build host.</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/FOUR ABSENCES/,/ABSENT, so/p'
  * NO RISC-V MACHINE.  The host is x86-64.
  * NO EMULATOR.  `qemu-riscv64` and `spike` are both ABSENT.
  * NO RISC-V BINUTILS.  `riscv64-linux-gnu-{gcc,as,ld}` are all ABSENT, so
    there is not even a RISC-V LINKER and no relocation in this course is
    ever resolved.
  * NO SECOND ASSEMBLER.  GNU binutils has no RISC-V target here, so both
    readers of the two-reader check come from ONE LLVM TREE.
                </pre>
                </div>
                <p>So, in the file&rsquo;s own words: <strong><code>NOT ONE INSTRUCTION IN THIS COURSE HAS BEEN RUN</code></strong>. No exception has ever been taken. No page has ever been walked. No TLB has ever been consulted. No <code>ecall</code> has ever been observed doing anything.</p>
                <p>And this is a <em>different</em> absence from the two courses before it, which is worth being explicit about because a reader who has just finished <a href="/courses/rvabi/lessons/rv-calling">the ABI course</a> arrives expecting a milder version of the same caveat:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | grep -A 3 'lost the ability to TIME'
  ABI course lost the ability to TIME. This course loses the ability to
  OBSERVE THE SUBJECT. Every claim about what a trap DOES is a quotation from
  a document, and every claim about what the toolchain EMITS is a measurement,
  and the sentence that separates them appears on every page.
                </pre>
                </div>
                <p>The previous two RISC-V courses measured a compiler&rsquo;s <em>choices</em>, and a choice is visible in bytes. This course&rsquo;s subject is largely a specification&rsquo;s <em>rules</em>, and a rule is not visible in bytes at all. What is left is the part that both is: <strong>the encodings, the address arithmetic, the relocation records, and the size arithmetic</strong>. Every page below says which of those a given claim is.</p>
                <p>One exception to the exception, and it is the interesting one. The <code>ecall</code> convention is measured <em>as emitted</em> &mdash; the compiler emits the constant <code>0x00000073</code>, and <code>a7</code> is the register the ABI names. That is a real measurement of a real thing. It is <strong>not</strong> a measurement that the trap is taken, that supervisor mode is entered, that <code>a7</code> is ever read, or that anything comes back. The pages label this distinction in their own sentences rather than in a footer, and the harness pins both halves.</p>
            </div>

            <div class="unit unit-example">
                <h2>What the four concepts measure</h2>
                <ul>
                    <li><strong><a href="/courses/rvpriv/lessons/rv-modes">The CSR Address and the Twelve Instructions That Touch It</a></strong> &mdash; 26 min. Four bits of privilege, then twelve instructions, then the finding that the register forms and the immediate forms differ by <strong>one bit of <code>funct3</code></strong>: 1&harr;5, 2&harr;6, 3&harr;7, and all three XORs are <code>0x04</code>. Then the boundaries, measured by refusal in the assembler&rsquo;s own words, and the Zicsr split &mdash; where <code>-march=rv64i</code> emits <code>csrr</code> and writes <code>Tag_RISCV_arch = rv64i2p1</code>, so the ISA string does not notice.</li>
                    <li><strong><a href="/courses/rvpriv/lessons/rv-paging">Sv39, Sv48, Sv57 and satp</a></strong> &mdash; 27 min. Three formats, one number&rsquo;s difference, and <code>4096 / 8 = 512</code>, <code>3 &times; 9 + 12 = 39</code>, <code>64 &minus; 4 &minus; 16 &minus; 8 = 36</code>. The trap is that 36 is neither of the two widths a reader reaches for, and <strong>both wrong widths compile</strong> &mdash; measured here on the compiler&rsquo;s own shifts rather than asserted. Then the relocations a page-table walk emits, and the asymmetry that is the load-bearing fact about a RISC-V relocation.</li>
                    <li><strong><a href="/courses/rvpriv/lessons/rv-traps">ecall, the Five Registers, and Why the Mode Is Not in the Instruction</a></strong> &mdash; 24 min. The convention quoted and then measured as emitted; the five trap CSR addresses decomposed; and the finding that <code>set_stvec_direct</code>, <code>set_stvec_vectored</code> and <code>set_stvec_misaligned</code> all emit <strong>the same 32 bits</strong>, so the mode is a property of the value and the enforcement is hardware this host does not have.</li>
                    <li><strong><a href="/courses/rvpriv/lessons/rv-boundary">What This Course Measured, and What It Refused To</a></strong> &mdash; 24 min. The measured/quoted boundary as a 44-row table with the count printed. Sixteen numbered limits. <strong>Eight</strong> things a reader therefore cannot conclude beside <strong>ten</strong> they can, pinned sentence by sentence by the harness. Seventeen retractions, each with a source &mdash; including the two that are not about the reader at all.</li>
                </ul>
                <p>One number to carry into the first page, and it is arithmetic rather than a measurement, which is the only kind of claim on this course that needs no toolchain at all:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | grep -B 1 -A 2 '64 - 4 - 16 = 44 bits'
  left" is the interesting arithmetic: 64 - 4 - 16 = 44 bits, and the PPN is
  stored DIVIDED BY THE GRANULE, so the register holds a page number rather
  than an address and the field is 44 - 8 = 36 bits
                </pre>
                </div>
                <p>Forty-four is the number a reader reaches for first, because 44 falls out of the subtraction above and stops there. Fifty-four is the width of the PPN field in a <em>PTE</em> &mdash; a different register with a different job. Both are wrong for <code>satp</code>, and this corpus <strong>ships both wrong masks on purpose</strong> so the mistake can be measured on the compiler&rsquo;s own shifts instead of merely described:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/THE FIVE satp EXTRACTORS/,/^$/p' | tail -6
  field               slli    srli     asked for  emitted   bits it keeps    verdict
  MODE                (none)   0x3c     4          4         satp[63:60]      CORRECT
  ASID                0x4      0x30     16         16        satp[59:44]      CORRECT
  PPN                 0x14     0x1c     36         36        satp[43:8]       CORRECT
  PPN, 44-bit mask    0xc      0x14     44         44        satp[51:8]       WRONG by +8 bits
  PPN, 54-bit mask    0x2      0xa      54         54        satp[61:8]       WRONG by +18 bits
                </pre>
                </div>
                <p>The widths and positions in that table are <strong>recovered from the shifts</strong>, not assumed: a <code>slli by L ; srli by R</code> pair on a 64-bit value returns input bits <code>[R&minus;L : 63&minus;L]</code>, so the width is <code>64 &minus; R</code>. And notice the first row: the correct MODE mask emits <strong>no shift left at all</strong>. The mask is optimised away because the shift right already does the work &mdash; and that is the honest signature of a correct field.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What this course owes its neighbours</h2>
                <p>A privileged architecture is the third time this collection has asked whether an architecture <em>enforces</em> something, and the first time where the answer cannot be measured at all. <strong>Every course named below was verified present by a live route check</strong> &mdash; and the list is printed as text first, so the identical list can sit inside the artifact, where a link the toolchain cannot resolve would be a different claim from a link the server cannot serve.</p>
                <div class="hex-dump">
                <pre>  why privilege exists, and what a ring is -- the neutral course
      /courses/priv/lessons/priv-vectors  /courses/priv/lessons/priv-doors
      /courses/priv/lessons/priv-convention
  what a page table is and why the levels exist
      /courses/mem/lessons/mem-translation
  the same subject for the other two architectures, where it IS measurable
      /courses/x86sys/lessons/x86-syscall   /courses/x86sys/lessons/x86-rings
      /courses/x86sys/lessons/x86-paging
      /courses/a64sys/lessons/a64-syscall   /courses/a64sys/lessons/a64-pagetables
  what a relocation record IS
      /courses/obj/lessons/obj-relocations /courses/reloc/lessons/reloc-why-so-many
  the `auipc` immediates, measured by the first RISC-V course
      /courses/rvasm/lessons/rv-immediate
  what a linker does with a pair once it has one
      /courses/rvabi/lessons/rv-calling
                </pre>
                </div>
                <p>Anchored, so a route check can prove it rather than take it on trust: <a href="/courses/priv/lessons/priv-vectors">priv-vectors</a>, <a href="/courses/priv/lessons/priv-doors">priv-doors</a>, <a href="/courses/priv/lessons/priv-convention">priv-convention</a>, <a href="/courses/mem/lessons/mem-translation">mem-translation</a>, <a href="/courses/x86sys/lessons/x86-syscall">x86-syscall</a>, <a href="/courses/x86sys/lessons/x86-rings">x86-rings</a>, <a href="/courses/x86sys/lessons/x86-paging">x86-paging</a>, <a href="/courses/a64sys/lessons/a64-syscall">a64-syscall</a>, <a href="/courses/a64sys/lessons/a64-pagetables">a64-pagetables</a>, <a href="/courses/obj/lessons/obj-relocations">obj-relocations</a>, <a href="/courses/reloc/lessons/reloc-why-so-many">reloc-why-so-many</a>, <a href="/courses/rvasm/lessons/rv-immediate">rv-immediate</a>, <a href="/courses/rvabi/lessons/rv-calling">rv-calling</a>.</p>
                <p>The one overlap worth naming is <a href="/courses/rvasm/lessons/rv-isa"><code>rvasm</code>&rsquo;s <code>rv-isa</code></a>, which measured the <code>Tag_RISCV_arch</code> string across eight <code>-march</code> settings. Concept 1 re-measures it for a different reason &mdash; not &ldquo;what does the string contain&rdquo; but &ldquo;does the toolchain agree with itself&rdquo; &mdash; and finds the opposite, which is why it belongs here and not there. <code>rv-isa</code> showed the string is <em>rich</em>; concept 1 shows it is a <em>record of the request</em>.</p>
                <p>And the decoder is <strong>borrowed, not forked</strong>. The instruction reader comes from <code>rvasm</code>&rsquo;s <code>rvdec.py</code> and this course prepends exactly two models of its own &mdash; one that decomposes a CSR address, one that names <code>SFENCE.VMA</code>, which the inherited decoder could not name at all &mdash; and edits no sibling. Two harnesses that both pass while reading different code is the failure mode this collection keeps paying for.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Ship a wrong <code>satp</code> mask and watch it compile.</strong> <em>(Open <code>courses/rvpriv/assets/samples/bits.c</code> and look at <code>satp_ppn44_wrong</code> and <code>satp_ppn54_wrong</code> &mdash; they are in the corpus ON PURPOSE. Compile the file for <code>riscv64-linux-gnu</code> and read the shifts in the disassembly: <code>0x14</code> and <code>0x1c</code> for 44, <code>0x2</code> and <code>0xa</code> for 54. Then work out what a 54-bit mask of <code>satp</code> returns when <code>ASID</code> is non-zero. There is no diagnostic, because there is nothing for the assembler to diagnose: the C is well-formed and the widths are the programmer&rsquo;s arithmetic.)</em></li>
                    <li><strong>Change a privilege bit and watch nothing happen at compile time.</strong> <em>(Change <code>mtvec</code> to <code>0x305</code> and <code>stvec</code> to <code>0x105</code> in <code>csr.s</code>, assemble, and confirm the toolchain accepts both with no complaint. Then read the specification&rsquo;s rule: a write to <code>mtvec</code> from S-mode raises an illegal-instruction exception. That rule is QUOTED with its section, because this host has no S-mode to be refused by. This is the third place in the course where a constraint is enforced by hardware this build machine does not have.)</em></li>
                    <li><strong>Put the two <code>LO12</code>s on opposite sides of a page and see the assembler say nothing.</strong> <em>(The corpus already builds six objects at six distances, including <code>0x2000</code> &mdash; 8200 bytes. Read the relocation list for that one: still one <code>R_RISCV_PCREL_HI20</code> and two <code>R_RISCV_PCREL_LO12_I</code>, addends unchanged, <strong>no diagnostic</strong>. The rule is that the LO12 distance must fit a signed 12-bit field, so 2048 bytes is the bound and 4096 &gt; 2047. There is no RISC-V linker here, so whether a linker would <em>reject</em> it is quoted rather than measured, and the page says so in its own words.)</em></li>
                    <li><strong>Break the artifact&rsquo;s reader and watch the cross-check catch it.</strong> <em>(Remove the <code>_m_csr_address</code> model from the dispatch and re-run. Expect the named count to fall by 146, the disagreement count to rise by 141, and the unmodelled count to fall by 146 &mdash; two of those moving in OPPOSITE directions over one removal, which is poison 1&rsquo;s whole claim. That is also the number the file used to retract, as R1, which is why both are printed.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/rvasm/lessons/rv-encoding"><code>rv-encoding</code></a> measured the base instruction set and <a href="/courses/rvasm/lessons/rv-verify"><code>rv-verify</code></a> built the two-reader cross-check this course borrows wholesale. <a href="/courses/rvabi/lessons/rv-noflags"><code>rv-noflags</code></a> is where <code>a7</code> and <code>a6</code> were introduced as ordinary argument registers; on this course they acquire a job, and the fact that <code>li a7, 0x40</code> and <code>li a6, 0x40</code> differ in one bit is a measurement about the ABI&rsquo;s choice of register as much as about the encoder.</p>
                <p>Across architectures, <a href="/courses/a64sys/lessons/a64-syscall"><code>a64-syscall</code></a> and <a href="/courses/x86sys/lessons/x86-syscall"><code>x86-syscall</code></a> are the same subject measured where the machine exists. Read them beside concept 3 and the difference is the whole course: there, the question was which register the ABI named and what the kernel does with it; here, the question is what the compiler emitted, and the answer is <strong>one 32-bit word that does not contain the mode</strong>.</p>
                <p>Forwards within the chain: this is the last RISC-V course. What it hands to the next architecture is not an instruction but a habit &mdash; <strong>when a specification says a field is reserved, ask what the compiler does with the value and then ask what the hardware does with the result</strong>, because on RISC-V the second question has a real answer this host cannot reach, and the gap between the two answers is where privileged code goes wrong.</p>
            </div>

            <div class="lesson-footer">
                <span>Start: <a href="/courses/rvpriv/lessons/rv-modes">The CSR Address and the Twelve Instructions That Touch It</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}