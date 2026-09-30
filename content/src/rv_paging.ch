// The RISC-V Privileged Architecture -- concept 2: Sv39, Sv48, Sv57 and satp.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rv_paging() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Sv39, Sv48, Sv57 and satp, Measured on the Compiler's Own Shifts — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson rvpriv-concept">
            <a href="/courses/rvpriv" class="back-link">The RISC-V Privileged Architecture</a>
            <h1>Sv39, Sv48, Sv57 and satp, Measured on the Compiler's Own Shifts</h1>
            <div class="lesson-meta">27 min &middot; Concept 2 of 4 &middot; module: the address, the bits, and the trap &middot; <a href="/courses/rvpriv">The RISC-V Privileged Architecture</a></div>

            <div class="unit unit-why">
                <h2>Three formats, one number&rsquo;s difference</h2>
                <p>RISC-V has three page-table formats and they differ by a single number: how many levels the walk has.</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/^  format   LEVELS/,/^$/p'
  format   LEVELS   the leaf sizes below the root        and
  Sv39     3        4 KiB, 2 MiB, 1 GiB                  and one more, 512 GiB, at the root
  Sv48     4        4 KiB, 2 MiB, 1 GiB, 512 GiB         and one more, 256 TiB, at the root
  Sv57     5        4 KiB, 2 MiB, 1 GiB, 512 GiB, 256 TiB and one more, 128 PiB, at the root
                </pre>
                </div>
                <p>That looks like a table to memorise and it is not, because each row falls out of arithmetic. Nine bits of the virtual address are consumed per level: 3 levels for Sv39, 4 for Sv48, 5 for Sv57. And the leaf sizes are not a separate fact &mdash; they are the same arithmetic read from the other end, because a leaf is <em>any</em> level whose PPN is aligned to its own size. A kernel that only uses 4 KiB pages has one leaf size available to it and is not making a choice; one that also maps 1 GiB regions is using the fact that the second level&rsquo;s entries happen to be aligned.</p>
                <div class="callout callout-note">
                    <p><strong>The geometry is not a coincidence, and this is where a kernel usually goes wrong.</strong> 512 entries of 8 bytes is <em>exactly</em> one 4 KiB page. The specification says so directly: &ldquo;Sv39 page tables contain 2<sup>9</sup> page table entries (PTEs), eight bytes each. A page table is exactly the size of a page and must always be aligned to a page boundary.&rdquo; So the alignment requirement falls out of the geometry: <strong>a page table <em>is</em> a page</strong>, and a kernel that allocates one from a page allocator gets the alignment free.</p>
                </div>
                <p>That fact has a consequence two steps later that is easy to miss. Because a page table <em>is</em> a page, <code>satp</code>&rsquo;s PPN is a <strong>page number</strong> rather than an address. Hold that thought &mdash; it is the reason the PPN field is 36 bits and not 44.</p>
            </div>

            <div class="unit unit-model">
                <h2>satp, and two masks of ours that are wrong on purpose</h2>
                <p>The layout is <code>MODE</code> at bits 63&ndash;60, <code>ASID</code> at 59&ndash;44, and the PPN below. On RV64 that leaves 44 bits, and &ldquo;what is left&rdquo; is the interesting arithmetic:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | grep -A 3 'is the interesting arithmetic'
  left" is the interesting arithmetic: 64 - 4 - 16 = 44 bits, and the PPN is
  stored DIVIDED BY THE GRANULE, so the register holds a page number rather
  than an address and the field is 44 - 8 = 36 bits of page number.
                </pre>
                </div>
                <p><strong>36 bits.</strong> And that is the point of the whole concept, because 36 is neither of the two numbers a reader reaches for. Forty-four falls out of the subtraction above, if you stop one step early. Fifty-four is the width of the PPN field in a <em>PTE</em> &mdash; a different register with a different job.</p>
                <p>Both wrong answers are natural, and <strong>both compile without a diagnostic</strong>. This course does not merely tell you so; it ships both wrong masks in its corpus so that the wrongness can be measured:</p>
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
                <p>The widths and positions in that table are <strong>recovered from the shifts, not assumed</strong>. A <code>slli by L ; srli by R</code> pair on a 64-bit value returns input bits <code>[R&minus;L : 63&minus;L]</code>, so the width is <code>64 &minus; R</code> and the low bit is <code>R &minus; L</code>. Read the <code>srli</code> column and the answer is arithmetic: <code>0x3c</code> gives 4, <code>0x30</code> gives 16, <code>0x1c</code> gives 36.</p>
                <div class="callout callout-warn">
                    <p><strong>Read the first row twice.</strong> The correct MODE mask emits <strong>no <code>slli</code> at all</strong>. The <code>&amp; 0xf</code> is gone because it is <em>provably</em> redundant: a logical right shift by 60 of a 64-bit value leaves exactly four bits, so masking with <code>0xf</code> cannot change it. And the ASID mask survives, because a right shift by 44 leaves twenty bits and the mask removes four of them. <strong>A confirmation that arrives as a missing instruction.</strong> If you wanted to know where the MODE field is, the compiler proved it for you &mdash; from the shift alone, without being told.</p>
                </div>
                <p>Now the consequence of the 54-bit row, which is the sentence this concept exists for:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | grep -A 3 'READ THE LAST ROW AGAINST'
  READ THE LAST ROW AGAINST THE THIRD. 54 bits of `satp` at [61:8]
  swallows the ENTIRE ASID, both bits of ASID's neighbours, and the low two
  bits of MODE. So `satp_ppn54_wrong` returns a value in which sixteen bits of
  address space identifier and two bits of translation mode are silently
  mixed into the page number.
                </pre>
                </div>
                <p>Silently. A caller using that to compute a physical address gets a <em>plausible</em> number &mdash; small, aligned, in range &mdash; that is wrong in a way no assertion catches. And the 44-bit mask is worse in the way that matters, because 44 is the number the manual prints for a PTE&rsquo;s PPN: the mistake <em>looks documented</em>.</p>
                <p>Retraction R5 and R6 are both this, written down before they were corrected. The file&rsquo;s own sentence for the lesson generalises past this architecture: <em>two natural mistakes with a pleasing shape are worse than one ugly one, because the ugly one gets checked.</em></p>
                <h2>The PTE, measured as an instruction sequence</h2>
                <p>The manual draws a PTE with eight named bit positions. The artifact&rsquo;s move is to write C expressions for those bits, compile them, and read the shift amounts out of the words &mdash; so the figure is checked by a compiler rather than by a second reading of the same figure.</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | grep -A 4 'EIGHT BITS, EIGHT LEFT SHIFTS'
    EIGHT BITS, EIGHT LEFT SHIFTS, AND THEY ARE 0x3e 0x3d 0x3c 0x3b 0x3a
    0x39 0x38 in the order R W X U G A D -- that is, DECREASING BY ONE as the
    bit number increases, because 63 - n decreases as n does.
    And the right shift is 0x3f = 63 in all seven, because the
    mask is a sign-extend-to-64 and not a zero-extend.
                </pre>
                </div>
                <p>63 &minus; n is the only arithmetic in it. If the manual&rsquo;s figure were wrong &mdash; if A were bit 5 and D were bit 6 &mdash; the compiler&rsquo;s <code>((p) &gt;&gt; 6) &amp; 1</code> would still emit <code>slli by 0x39</code> and the check would fail. <strong>The compiler is not an authority on the PTE layout; it is an authority on what a C expression becomes</strong>, and those are two different things, and the composition of the two is what checks the figure.</p>
                <div class="callout callout-note">
                    <p><strong>One row of the eight is a different shape, and that is the trap.</strong> A reader looking for <code>srli a0, a0, 6 ; andi a0, a0, 1</code> finds <em>neither instruction</em>: clang emitted a left shift and then a sign-extend, because that form is branch-free and constant-foldable. But <strong>bit 0 is the exception</strong> &mdash; for A and D alike, clang emitted <code>andi a0, a0, 0x1</code> and no shift at all, because shifting by zero and masking with one is the identity and the optimiser knows it. So a helper written against the uniform shape works on seven of the eight rows and returns a wrong answer on the eighth with no diagnostic.</p>
                </div>
                <p>And the reserved bits are the most dangerous field in the format, because they are a <strong>trap rather than a no-op</strong>: bits 60&ndash;54 must be zeroed by software, and if any of them is set a page-fault exception is raised. The fault&rsquo;s cause code says &ldquo;load page fault&rdquo; rather than &ldquo;reserved bit set&rdquo;, so the handler goes looking for a permissions problem and does not find one. The rule for a reader of this course: <strong>a PTE is not a struct with some padding. Every bit of it is either assigned or a trap.</strong></p>
            </div>

            <div class="unit unit-example">
                <h3>What a page-table walk emits: three relocations, and an asymmetry</h3>
                <p>Here is where this course leaves the specification and goes back to bytes. A page-table walk on RISC-V is ordinary compiled code that happens to read a table, so it emits ordinary relocations &mdash; and reading them tells you things about the encoding that no diagram does.</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/^  offset    code    name                  the symbol/,+8p'
  offset    code    name                  the symbol it names        addend
  0x0       23      R_RISCV_PCREL_HI20    root_pte                  +0
  0x4       24      R_RISCV_PCREL_LO12_I  .Lpcrel_hi0               +0
  0xe       23      R_RISCV_PCREL_HI20    l1_pte                    +0
  0x12      24      R_RISCV_PCREL_LO12_I  walk_three                +0
                </pre>
                </div>
                <p>Read the symbol column. <strong>The HI20 records name the TARGET</strong> &mdash; <code>root_pte</code>, <code>l1_pte</code>, <code>l2_pte</code>, the three page tables, which is what you would expect. The LO12 records name something else entirely: they name the <strong>address of the AUIPC</strong>, and one of them names <code>.Lpcrel_hi0</code>, a label that is not in the source at all. The compiler created it so the <code>ld</code> four bytes later has something to point at.</p>
                <p>That asymmetry is the load-bearing fact about a RISC-V relocation, and it is what makes the mechanism legible: <strong>a PC-relative address on RISC-V is a two-instruction arithmetic expression, and the object file stores one half of it in the instruction word and the other half in the relocation table.</strong> <code>auipc</code> puts the high 20 bits of (target &minus; pc) in a U-type immediate; <code>ld</code> then has to add the low 12 bits, and the low 12 bits of a run-time address is not a compile-time constant. So the <code>ld</code>&rsquo;s own immediate is left at zero and a record says &ldquo;fill this in later&rdquo;.</p>
                <p>A reader who has only seen x86-64&rsquo;s <code>mov rax, [rip+X]</code> will assume the RISC-V pair is a convenience and that the target&rsquo;s address is somewhere in the record. <strong>It is not.</strong> That is why the corpus asks for <code>%pcrel_lo(&lt;the auipc&rsquo;s own label&gt;)</code> rather than <code>%pcrel_lo(target)</code>, and why getting it wrong is a linker error rather than a wrong number.</p>
                <div class="callout callout-note">
                    <p><strong>And the numbers in the words really are zero.</strong> Every immediate the LO12 records attach to is <code>0x000</code>, read out of the object, cross-checked against <code>llvm-objdump-21</code>. That is the literal sense in which the address is half in the instruction and half in the table &mdash; and it is why a reader who hexdumps a RISC-V <code>.o</code> and computes an address from the instructions alone gets zero, with nothing in the file to say that the zero is a placeholder rather than a value.</p>
                </div>
                <h3>The pairing rule, and the fact that nothing checks it here</h3>
                <p>The psABI requires each <code>LO12</code> to be paired with a <code>HI20</code> at a label it names, and the value that has to fit is the offset from that AUIPC to the target. A signed 12-bit field holds &minus;2048 to 2047, so the AUIPC must be within 2048 bytes. And a 4 KiB granule is 4096, and <strong>4096 &gt; 2047</strong> &mdash; which is where the familiar &ldquo;the pair has to be in the same page&rdquo; rule comes from, by arithmetic rather than by convention.</p>
                <p>The artifact asks the assembler to violate it, six times, at six distances, and reads the records back:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/^  pad       HI20/,+6p'
  pad       HI20    LO12_I    HI20 at   farthest LO12 at  that distance  fits 12-bit?
  0x0       1       2         0x0       0x8               8              YES
  0x40      1       2         0x0       0x48              72             YES
  0x800     1       2         0x0       0x808             2056           NO
  0xffc     1       2         0x0       0x1004            4100           NO
  0x1000    1       2         0x0       0x1008            4104           NO
  0x2000    1       2         0x0       0x2008            8200           NO
                </pre>
                </div>
                <p>Every one has one HI20 and two LO12s, including the case where the two LO12s are 8 KiB apart, and the assembler diagnosed none of them. Read the last column too: <strong>every immediate in every word is <code>0x000</code> at every distance</strong>, because the value is not knowable at assembly time and the assembler does not pretend otherwise.</p>
                <div class="callout callout-warn">
                    <p><strong>What this course does not claim, and why that sentence is here.</strong> There is <strong>no RISC-V linker on this host</strong>, so whether that object is valid is a quoted claim and not a measured one, and the section says so rather than claiming a bug it cannot demonstrate. What it claims is narrower and worth more: the assembler <em>produces</em> the records and does not check them; the bound is arithmetic; and a linker is the only thing that can check it.</p>
                </div>
                <p>And the practical consequence for a kernel is the reason to care: the pairing rule is a constraint on <strong>code layout</strong> that the assembler will not tell you about, and a page-table walk is exactly the code most likely to violate it, because its references are spread across a data section and the author has no reason to think about where the AUIPC is. Real kernels keep the walk and its tables in one page, or accept the linker&rsquo;s error. Neither can be tested here.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What was measured here, and what was not</h2>
                <p>This page has more measured bytes than any other in the course and <strong>not one page has been walked</strong>. The two facts are not in tension and it is worth being explicit about why.</p>
                <ul>
                    <li><strong>MEASURED-ON-BYTES:</strong> the three relocation codes 23/24/25 and that they are consecutive; every record&rsquo;s code cross-checked against the psABI table <em>by name</em>, so a record claiming code 99 under the name <code>R_RISCV_PCREL_HI20</code> would fail the harness; which symbol each record names, including <code>.Lpcrel_hi0</code>; every instruction immediate; the six pairing distances and the record counts at each; the satp widths and positions, recovered from the compiler&rsquo;s own shifts; the PTE shift amounts.</li>
                    <li><strong>MEASURED:</strong> that the wrong 44- and 54-bit masks <em>compile</em>, and the exact instructions they produce.</li>
                    <li><strong>QUOTED:</strong> the three formats&rsquo level counts and leaf sizes; the <code>satp</code> field layout; the two A/D management schemes; that reserved PTE bits raise a page fault.</li>
                    <li><strong>NOT MEASURED:</strong> that a page walk translates anything; that a TLB is ever consulted; which of the two A/D schemes any hart implements; what a linker does with an out-of-range pair; how many faults a first touch costs.</li>
                </ul>
                <p>Two findings on this page were <strong>retracted before they were published</strong>, which is the best kind. R9: the number of relocations a walk produces is not a property of the walk at all &mdash; it is a property of the <em>data layout</em>, and the same source at the same optimisation level emits one HI20 when three tables are adjacent and three when they are 4 KiB apart. The change is the merged-globals pass, and the evidence is in the symbol names. R13: the experiment that showed this holds the instruction count constant in the <code>-fno-pic</code> pair only; the default pair is confounded by a factor of four, and the section prints the confounding number in its own column rather than choosing the flattering pair.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Compile the wrong masks and read the widths out of the machine code.</strong> <em>(Open <code>assets/samples/bits.c</code>, find <code>satp_ppn54_wrong</code>, and compile it for <code>riscv64-linux-gnu</code> at <code>-O2</code>. Read the two immediate fields of the emitted <code>slli</code> and <code>srli</code> and compute the width as <code>64 &minus; srli</code>. You should get 54. Now ask what a 54-bit mask of <code>satp</code> returns when <code>ASID</code> is 0x1234 &mdash; and whether anything in the emitted code would tell a reader that answer was wrong.)</em></li>
                    <li><strong>Find the missing instruction.</strong> <em>(The correct MODE extractor emits <code>srli a0, a0, 0x3c</code> and <strong>no mask</strong>. Work out, from the ISA alone, why the optimiser was entitled to delete the <code>&amp; 0xf</code> &mdash; and then check that the ASID extractor, three lines away, was <em>not</em> entitled to. Two neighbouring expressions, same compiler, same optimisation level, opposite outcomes, and the reason is the width of the shift.)</em></li>
                    <li><strong>Break the pairing rule and find out who notices.</strong> <em>(The corpus already does this at <code>0x2000</code>. Read <code>sp_0x2000.relocs</code> in this directory: one <code>R_RISCV_PCREL_HI20</code>, two <code>R_RISCV_PCREL_LO12_I</code>, addends unchanged, and no diagnostic anywhere. Now write down what a linker <em>would</em> have to do to catch it, and mark that sentence QUOTED rather than measured. Being able to say <em>which</em> of your two sentences is a quotation is the actual skill.)</em></li>
                    <li><strong>Move a page table 4 KiB and count the relocations again.</strong> <em>(In <code>sp2.c</code>, the three tables are declared adjacent or separated by 4 KiB depending on which build you ask for. Compile both ways at <code>-fno-pic</code> &mdash; the clean pair, because the default pair also unrolls the fill paths and confounds the count. Watch the HI20 count double with the instruction count essentially unchanged, and then look at the symbol names: <code>.L_MergedGlobals</code> becomes <code>root</code>, <code>l1tab</code>, <code>l2tab</code>. <strong>The author of the walk is not in the conversation.</strong> The compiler is.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Back to <a href="/courses/rvpriv/lessons/rv-modes">concept 1</a>, where the twelve-bit CSR address was decomposed and <code>satp</code>&rsquo;s address appeared as one row among many &mdash; and where the accessibility and privilege bits explained why a user-mode program may not touch it. Forward to <a href="/courses/rvpriv/lessons/rv-traps">concept 3</a>, which is what happens when the translation fails and something has to be told about it.</p>
                <p>Out to <a href="/courses/mem/lessons/mem-translation"><code>mem-paging</code></a>, which is the neutral course and owns the <em>idea</em> of a multi-level walk; nothing on this page re-teaches it. Out to <a href="/courses/a64sys/lessons/a64-pagetables"><code>a64-paging</code></a> and <a href="/courses/x86sys/lessons/x86-paging"><code>x86-paging</code></a> for the same subject on machines this collection can run &mdash; and read them for the contrast in method. Those two courses could observe a walk. This one counted the relocations it emits, which is a weaker fact about a different thing, and the weaker fact is the one that is checkable here.</p>
                <p>And out to <a href="/courses/obj/lessons/obj-relocations"><code>obj-relocations</code></a> and <a href="/courses/reloc/lessons/reloc-why-so-many"><code>reloc-types</code></a>, which own what a relocation record <em>is</em>. The HI20/LO12 asymmetry on this page is a RISC-V fact and belongs here; the fact that the record has an offset, a type and a symbol is theirs.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/rvpriv/lessons/rv-modes">The CSR Address and the Twelve Instructions That Touch It</a></span>
                <span>Next: <a href="/courses/rvpriv/lessons/rv-traps">ecall, the Five Registers, and Why the Mode Is Not in the Instruction</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}