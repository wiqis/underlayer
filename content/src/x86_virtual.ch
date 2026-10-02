// The x86-64 Machine — Concept 6: the 48-bit split, LA57 and LAM
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_virtual() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The 48-Bit Split, LA57 and LAM — Underlayer")
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
                    <button onclick="closeShortcuts()" class="a11y-close">Close</button>
                </div>
            </div>
            <div class="reading-controls">
                <label>Font: <select id="font-size" onchange="setFontSize(this.value)"><option value="small">Small</option><option value="medium" selected>Medium</option><option value="large">Large</option></select></label>
                <label>Spacing: <select id="line-height" onchange="setLineHeight(this.value)"><option value="compact">Compact</option><option value="normal" selected>Normal</option><option value="relaxed">Relaxed</option></select></label>
                <label>Letters: <select id="letter-spacing" onchange="setLetterSpacing(this.value)"><option value="tight">Tight</option><option value="normal" selected>Normal</option><option value="loose">Loose</option></select></label>
                <label>Width: <select id="content-width" onchange="setContentWidth(this.value)"><option value="narrow">Narrow</option><option value="normal" selected>Normal</option><option value="wide">Wide</option></select></label>
            </div>
            <h1>The 48-Bit Split, LA57 and LAM</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/x86sys">The x86-64 Machine</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Half of the 64-bit address space on this machine is not an address. Not &ldquo;is not mapped&rdquo; &mdash; not an address, in the sense that the CPU refuses to form one and no page table is ever consulted. That is a different kind of unavailability from an unmapped page, and it is the reason a fault handler that reads <code>si_addr</code> before <code>si_code</code> reports a null-pointer dereference for what was actually an arithmetic mistake.</p>
                <p>This concept <strong>re-derives the rule on five access widths</strong> where the privilege course derived it on three, and the extension earned its place: it found a wrong constant in the first draft, and the constant was one that half the documentation quotes. The rule is <code>first rejected = 2^47 - (access size - 1)</code>, and the constant is <code>2^64 - 2^47</code> and <em>not</em> <code>0xffffffff80000000</code>.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: bit 47 chooses the half, and nothing else does</h2>
                <p>A linear address is canonical when bit 47 equals bit 63. That is the whole rule, and it has an immediate consequence that is easy to get wrong: <strong>the two halves are each 2<sup>47</sup> bytes wide</strong>, because the split is down the middle of a 2<sup>48</sup>-bit space and 2<sup>48</sup>/2 is 2<sup>47</sup>. The upper half therefore begins at 2<sup>64</sup> &minus; 2<sup>47</sup>.</p>
                <div class="formula">
   THE TWO HALVES, and the arithmetic that
   settles them.

   low    0x0000000000000000 .. 0x00007fffffffffff
   HOLE   0x0000800000000000 .. 0xffff7fffffffffff
   upper  0xffff800000000000 .. 0xffffffffffffffff

   The hole is not one number, it is a
   RANGE, and it is 2^64 - 2^48 bytes wide
   out of 2^64: 93.75% of the address
   space is not an address on this machine.

   And note where the upper half STARTS.
   It is 2^64 - 2^47.  It is NOT
   0xffffffff80000000, which is 2^31
   bytes INSIDE it and which appears in a
   great deal of documentation and in the
   GDT base of every Linux kernel you have
   ever read about.
                </div>
                <p>That last paragraph is the correction, and the reason it survived so long is worth naming: <code>0xffffffff80000000</code> is a plausible-looking address that falls in the upper half, so a claim that &ldquo;addresses starting with <code>0xffffffff8</code> are kernel addresses&rdquo; is <em>true</em> while the claim that &ldquo;the upper half starts at <code>0xffffffff80000000</code>&rdquo; is false. Two claims, one address, and the difference between them is 2<sup>31</sup> bytes of address space that a program could use and cannot.</p>
                <p>And the check itself, because getting it wrong is the commonest way to be wrong about x86-64 addressing:</p>
                <div class="formula">
   IS CANONICAL(a)  =  ((a &gt;&gt; 47) &amp; 1) == ((a &gt;&gt; 63) &amp; 1)

   NOT  (a &amp; 0xFFFF000000000000) == 0
   or   (a &amp; 0xFFFF000000000000) == 0xFFFF000000000000

   The second form is what half the code on
   the internet writes, and it calls
   0x0000800000000000 canonical.  It is
   not.  That address has bit 47 = 1 and
   bit 63 = 0, so it is in the hole.

   The first version of the artifact's own
   helper had this bug, and the artifact
   prints the correct test beside it.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: five widths, and the row that is the whole concept</h2>
                <p>The privilege course measured this with 1-, 4- and 8-byte reads. This course adds a 2-byte and a 16-byte arm, and the 2-byte arm is the one that matters: <strong>a 1-byte read fails <em>nowhere</em> before the line and a 2-byte read fails one byte before it</strong>, which is a difference no rule stated as &ldquo;the boundary is 2<sup>47</sup>&rdquo; can survive.</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/^  MATRIX | 2\^47  -3/,/^  MATRIX | 2\^47  +0/p'
  MATRIX | 2^47  -3 | 0x00007ffffffffffd | 1       1       128     128     128
  MATRIX | 2^47  -2 | 0x00007ffffffffffe | 1       1       128     128     128
  MATRIX | 2^47  -1 | 0x00007fffffffffff | 1       128     128     128     128
  MATRIX | 2^47  +0 | 0x0000800000000000 | 128     128     128     128     128     NON-canonical
                </pre>
            </div>
                <p>Columns left to right: 1, 2, 4, 8 and 16 bytes. Read the top row. A 1-byte read at 2<sup>47</sup>&minus;3 succeeds. A 2-byte read at the same address succeeds. A 4-byte read fails, because the four bytes it would touch run from 2<sup>47</sup>&minus;3 to 2<sup>47</sup>, and the last of them is past the line. <strong>Same address, four different outcomes, decided entirely by how many bytes the instruction reads.</strong></p>
                <p>Then the rule, derived by bisection independently for each width:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/^  BISE | width/,/first rejected/p'
  BISE | width | first rejected address | 2^47-(size-1) | holds
  BISE | 1-byte | 0x0000800000000000          | 0x0000800000000000 | YES
  BISE | 2-byte | 0x00007fffffffffff          | 0x00007fffffffffff | YES
  BISE | 4-byte | 0x00007ffffffffffd          | 0x00007ffffffffffd | YES
  BISE | 8-byte | 0x00007ffffffffff9          | 0x00007ffffffffff9 | YES
  BISE | 16-byte | 0x00007ffffffffff1          | 0x00007ffffffffff1 | YES
  BISE | the rule, on five widths: 5 of 5
  BISE | first rejected = 2^47 MINUS (access size - 1)
                </pre>
            </div>
                <p>Five bisections, five matches, and the address column is <em>the measurement</em> rather than a restatement: each one converged by asking a forked child whether a given address was an address, twenty times per width, halving a 16 KiB window each step. The formula in the fourth column is the artifact computing 2<sup>47</sup>&minus;(size&minus;1) and the third is what the hardware said, and the harness asserts they are the same number.</p>
                <h3>And the same rule in the other half</h3>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/^  BISEL | width/,/^  BISEL | 2\^64/p'
  BISEL | width | first address of the upper half | 2^64 - 2^47 | holds
  BISEL | 1-byte | 0xffff800000000000                 | 0xffff800000000000 | YES
  BISEL | 2-byte | 0xffff800000000000                 | 0xffff800000000000 | YES
  BISEL | 4-byte | 0xffff800000000000                 | 0xffff800000000000 | YES
  BISEL | 8-byte | 0xffff800000000000                 | 0xffff800000000000 | YES
  BISEL | 16-byte | 0xffff800000000000                 | 0xffff800000000000 | YES
  BISEL | 2^64 - 2^47 on 5 of 5 widths
                </pre>
            </div>
                <p><strong>The same address for all five widths</strong>, and that asymmetry is the other half of the result. The rule &ldquo;first rejected = 2<sup>47</sup> &minus; (size&minus;1)&rdquo; is about the <em>end</em> of a half, and each half has its own end. The <em>start</em> of a half is one address and does not depend on the access width, because a read that starts there goes upward into legal territory.</p>
                <div class="formula">
   TWO RULES, NOT ONE, and the artifact
   measures both.

   the START of a half is one address and
     is width-independent

   the END of a half is width-dependent, and
     the first rejected access is the
     highest address whose byte range still
     fits

   A page that quotes only the second and
   calls it "the canonical boundary" has
   quoted half a rule and will be caught by
   the first access whose size is not the
   one it had in mind.
                </div>
                <h3>One asymmetry the artifact reports and does not explain</h3>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/^  WRAP | 16-byte/,/^  WRAP | 8-byte/p'
  WRAP | 16-byte read at 0xffffffffffffffff | si_code 1
  WRAP | 16-byte read at 0xfffffffffffffff0 | si_code 1
  WRAP | 8-byte read at 0xffffffffffffffff    | si_code 1
  WRAP | So the LOW half's end is range-checked, on five widths, and
  WRAP | the TOP of the space is not observed to be.  This file does
  WRAP | not say why, because the two candidate explanations -- that
  WRAP | the implementation compares the offset within the half and
  WRAP | the high half's offset arithmetic cannot overflow, or that
  WRAP | the top of the space is simply never used and the hardware
  WRAP | never agreed to define it -- need a CPUID bit or a manual
  WRAP | sentence this process has no way to check.  Named as an
  WRAP | OPEN QUESTION, which is a different thing from being wrong.
                </pre>
            </div>
                <p>A 16-byte read whose range runs off the end of the address space and wraps comes back as a real address rather than a rejection. <strong>The artifact names this as an open question rather than a finding</strong>, and the reason is worth copying: there are two plausible mechanisms, this process has no instrument that distinguishes them, and a page that picks one and states it as a fact is exactly the page that has to be retracted later.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: LA57 and LAM, both reported as zero, and the difference between them</h2>
                <p>Both are extensions that widen the address space, and the CPU reports both in the same breath:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | grep -E 'LA57|LAM '
  CPUID | 0x00000007 subleaf 0 | ECX | LA57 0 RDPID 1 KeyLocker 0
  CPUID | 0x00000007 subleaf 1 | EAX 0x00000000 | LAM 0 MOVRS 0
  CPUID | 0x80000008 | EAX | physical address bits = 48
  CPUID | 0x80000008 | EAX | five-level paging (LA57) = 0
  CPUID | 0x80000008 | EAX | bits 13:12, the linear-address field = 3
  CPUID | 0x80000008 | EAX | of which 0 means 48-bit and 1 means 57-bit;
  CPUID | 0x80000008 | EAX | values 2 and 3 are RESERVED and this machine
  CPUID | 0x80000008 | EAX | reports 3.  A first version of this file read
  CPUID | 0x80000008 | EAX | that field as a COUNT OF BITS and printed 51.
                </pre>
            </div>
                <p>Three readings, and they are three different kinds of statement about the same machine.</p>
                <ul>
                    <li><strong><code>LA57 = 0</code> in <code>0x80000008:EAX</code> bit 21 and in <code>7.0:ECX</code> bit 16.</strong> Five-level paging is not present. This is a <strong>fact about the CPU</strong>, read with an unprivileged instruction by any process on earth.</li>
                    <li><strong><code>LAM = 0</code> in <code>7.1:EAX</code> bit 26.</strong> Linear address masking is not present. Also a fact about the CPU. And the subleaf matters: a first version of this file read <em>subleaf 0</em> <code>ECX</code> bit 26 &mdash; the same number, a different register, a different subleaf &mdash; got zero, and reported LAM as unsupported for a reason that had nothing to do with LAM. <strong>It happened to be right and it was still wrong</strong>, which is retraction R5.</li>
                    <li><strong>Bits 13:12 of the same EAX word read 3, and the manual says 0 means 48-bit, 1 means 57-bit, and 2 and 3 are reserved.</strong> So the field is a reserved value. And a first version of the artifact read it as a <em>count of bits</em> and printed &ldquo;51 bits&rdquo;, which is a plausible-looking number with nothing behind it. The right reading is that the field is reserved and this part puts 3 in it, and the bits that software actually consult &mdash; bit 21 and <code>7.0:ECX</code> bit 16 &mdash; both say 48. <strong>Three fields in one register, and the one that is easiest to read wrong is the one that is reserved.</strong></li>
                </ul>
                <div class="formula">
   AND HERE IS WHY A REPORT IS NOT A READING.

   LA57 = 0 in CPUID says the SILICON has no
   fifth level.  It does NOT say what
   CR4.LA57 is set to on this machine, and
   reading CR4 is a fault.

   The distinction matters because the two
   questions have different answers on a
   machine that supports five-level paging:
   a kernel may leave CR4.LA57 clear on a
   part that could do it, and then
   everything above 2^48 is unavailable for
   a reason that has nothing to do with the
   hardware.  The number you want is the
   second one and the number you can read
   is the first one.
                </div>
                <p>And a fourth reading, the only one about the <em>kernel's</em> intent rather than the metal:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/PRCTL | ARCH_GET_XCOMP/,/cannot check it/p'
  PRCTL | ARCH_GET_XCOMP_PERM rc=0 | perms 0x207
  PRCTL | bit0 SMEP=1 bit1 SMAP=1 bit2 SHSTK=1
  PRCTL | that is the KERNEL'S REPORT and not a measurement of the
  PRCTL | CR4 bits, which are privileged and unreadable.  A kernel
  PRCTL | can report anything here and this process cannot check it.
                </pre>
            </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce the five-width matrix.</strong> <code>cd courses/x86sys/assets/samples &amp;&amp; ./build_samples.sh</code>, then read section 5. <em>(Expect 20 rows by 5 columns, five bisections, and 5 of 5. If a column comes out constant the whole way down, you have written the 16-byte arm in C rather than in <code>movdqu</code> and the compiler has handed you an alignment requirement &mdash; see exercise 2.)</em></li>
                    <li><strong>Break the 16-byte arm on purpose.</strong> Change the <code>movdqu</code> in <code>rd16</code> to <code>movdqa</code> and re-run. <em>(Expect every unaligned address in the column to report 128, at every offset, which is a table with a pattern and no rule behind it. Then run <code>objdump -d sysdump | sed -n '/&lt;rd16&gt;/,/ret/p'</code> and find the instruction that explains it. A measurement harness that is not read is not evidence, and this is the fourth time in this course that a compiler has quietly changed what was being measured.)</em></li>
                    <li><strong>Find the constant in the documentation.</strong> Grep a kernel source tree and a set of manuals for <code>0xffffffff80000000</code> as a claimed upper-half base. <em>(Expect to find it described as &ldquo;the kernel half&rdquo;, which is a statement about <em>where the kernel is mapped</em> and is true, next to statements that treat it as the canonical boundary, which is false. The two get confused because they are the same number and only one of them is a rule.)</em></li>
                    <li><strong>Write the canonicality test three ways and compare.</strong> The bit-equality test, the masked-ranges test, and the &ldquo;is it below 2<sup>47</sup> or at least 2<sup>64</sup>&minus;2<sup>47</sup>&rdquo; test. <em>(Expect the first to be correct and the second to accept <code>0x0000800000000000</code>. A bound that is one bit wrong in the middle is a bound that lets a program build a pointer the hardware will refuse, which is a bug that survives testing because the test only ever used valid pointers.)</em></li>
                    <li><strong>Decide what your compiler should do about it.</strong> If you are writing a backend, the interesting question is not how to test canonicity but <strong>when it is worth checking at all</strong>. <em>(Expect the answer to be &ldquo;when a pointer is truncated to 32 bits, and on every address computed from untrusted input&rdquo;, and expect the second of those to be a real security boundary rather than a portability measure. A 64-bit machine with a hole in the middle of its address space has to treat that hole as unaddressable, and the only way to get that wrong is to test the wrong bits.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, this concept <strong>extends rather than repeats</strong>: <a href="/courses/priv/lessons/priv-canonical">the privilege course's canonical-addressing concept</a> derived the same rule on three widths and this one adds two. The retraction is the credit, and the credit is in the artifact in the form the plan asks for &mdash; the neutral course owns the principle and the per-architecture course owns the width table. <a href="/courses/mem/lessons/mem-hierarchy">The memory course's address-space concept</a> is where the 48-bit decision was made and what it cost; this page is what the number <em>is</em>.</p>
                <p>Forwards. The next concept asks what happens to a legal address: four index fields, fourteen flag bits, and the two the hardware sets. The connection is <strong>the hole in the middle of the address space and the top-level structure that would have to cover it</strong> &mdash; five-level paging exists because the canonical form grew to 57 bits, and every entry in every table gained a level. And the pagemap measurement in the next concept is the only place in this course where a user process observes a page-table entry directly.</p>
                <p>Outward. The same idea on AArch64 is a 48-bit VA with top-byte-ignore, where the &ldquo;hole&rdquo; is the top <em>byte</em> rather than the top half, and a tagged-pointer scheme in a low byte rather than a high one. The comparison belongs to <a href="/courses/mem/lessons/mem-hierarchy">the memory course</a>; what this course owns is the x86-64 table, and the reason the constant is wrong so often is that the number people quote is a <em>placement</em> rather than a <em>rule</em>, and only one of those two is architecture.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86sys/lessons/x86-debug">DR0 to DR7 and the Mask a Debugger Must Program</a></span>
                <span>Next: <a href="/courses/x86sys/lessons/x86-paging">The Four Entries and Every Flag in One</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
