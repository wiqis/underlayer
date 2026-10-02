// Exceptions, Privilege and Mode Changes — Concept 1: the gate table
public namespace underlayer_content {

using std::string

using std::string_view

public func render_priv_table() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("A Table You Can Locate and Not Read — Underlayer")
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
            <h1>A Table You Can Locate and Not Read</h1>
            <div class="lesson-meta">26 min &middot; <a href="/courses/priv">Exceptions, Privilege and Mode Changes</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Something happens every time your program asks for a thing it cannot do for itself &mdash; read a file, change a page's permissions, ask the clock. Every one of those events passes through a hardware table, and on x86-64 that table has a name, an address, and a size. <strong>You can read two of those three from user mode.</strong></p>
                <p>That sounds like a curiosity. It is not. It is the entire privilege story in one asymmetry, and the rest of this course is a consequence of it. A process that knows where the gates are, and cannot read one, can still <em>name</em> a vector and get a fault &mdash; which is exactly what lets a program ask a question and get an answer, and exactly what stops it choosing the answer. Understanding that difference, precisely, is what separates &ldquo;the operating system trusts this process&rdquo; from &ldquo;the hardware refuses to let this process do that&rdquo;, and only the second kind survives a compromised kernel.</p>
                <p>There is also a trap here that has caught the author of this course, and it is worth stating up front because it is the sort of error that does not announce itself.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: a register, a ten-byte slot, and a table</h2>
                <p><code>SIDT</code> stores the IDT register into a ten-byte region of memory. That region has a fixed layout, and <strong>the order is the base first and the limit second</strong>:</p>
                <div class="formula">
   offset 0  ....  7   the 64-bit IDT base address
   offset 8  ....  9   the 16-bit IDT limit, in bytes

   10 bytes total.  This is the "pseudo-descriptor" that
   LIDT, LGDT, SIDT and SGDT all use.

   THE ORDER IS BASE FIRST.  See the Reality unit: getting
   it backwards produces no fault at all.
                </div>
                <p>The limit is a <em>byte</em> count and every entry is 16 bytes, so the number of entries the hardware will look up is <code>limit/16 + 1</code>. On the machine this course was written for:</p>
                <div class="hex-dump">
                <pre>$ ./privbench | sed -n '/the ten bytes SIDT/,/entries of 16 bytes/p'
   the ten bytes SIDT actually wrote: 00 00 00 00 ff ff ff ff ff ff
   SIDT  base  = 0xffffffff00000000
   SIDT  limit = 65535  ->  4096 entries of 16 bytes
</pre>
                </div>
                <p>Three things to take from those ten bytes.</p>
                <p><strong>First, the base is not an allocation.</strong> <code>0xffffffff00000000</code> is exactly 2<sup>32</sup> below the top of a 48-bit address space, and it is the address the x86-64 architecture itself uses. A kernel <em>may</em> choose another; this one did not. Notice that the artifact does not <em>assume</em> this &mdash; it prints the number it read and then checks whether the number has the expected shape, because a course that hard-codes the answer teaches the answer.</p>
                <p><strong>Second, 4096 entries is not a claim that 4096 interrupts exist.</strong> It is a <em>bound</em>, and it is a deliberately conservative one: 65535 is the largest limit a 16-bit field can express, so setting it to the maximum means that <code>int 0xNN</code> with any possible byte is a bounds check against the table and not a wild read. A kernel that set the limit to 64 would be faster to reason about and would turn every stray <code>int</code> into memory corruption. <strong>4096 entries is a security decision wearing a number's clothes.</strong></p>
                <p><strong>Third, and this is the concept:</strong> the register is readable and the table is not.</p>
                <div class="hex-dump">
                <pre>$ ./privbench | sed -n '/Reading the first 8 bytes/,/cost a fork/p'
   Reading the first 8 bytes of the IDT from ring 3: FAULTED
      the child died of signal 11 (SIGSEGV)
   The register is readable; the TABLE is not.  SIDT tells a process where
   the gates are, and gives it no way to read one.  That asymmetry is the
   whole privilege story in one line, and it cost a fork to establish.
</pre>
                </div>
                <p>Note the method. The read runs in a <strong>forked child</strong>, not in the benchmark itself, and the child is reported by the signal it died from. This is not caution for its own sake: an earlier version of this course's artifact read an MSR in the parent process and killed every measurement in the run with it. <strong>Any experiment whose expected outcome is a fault belongs in a child process, and the harness should be built that way from the start rather than after it has cost you a run.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: the layout has a trap in it</h2>
                <p>Almost every prose description of the pseudo-descriptor says &ldquo;the 16-bit limit and the 64-bit base&rdquo;, in that order. It is wrong. And &mdash; here is what makes it a genuinely dangerous error rather than a merely embarrassing one &mdash; <strong>reading it the documented way does not fault. It returns numbers.</strong></p>
                <div class="hex-dump">
                <pre>$ ./privbench | sed -n '/read the other way round/,/not loud/p'
   read the other way round -- limit first, then base:
      base  = 0xffffffffffff0000   limit = 0
      No fault.  No obviously impossible value.  A tool written that way
      reports a limit of 0 and a base in the middle of nowhere, and a
      limit of 0 is INDISTINGUISHABLE from a kernel that installed an
      empty IDT.  This is the worst kind of wrong: it is not loud.
</pre>
                </div>
                <p>This is worth pausing on, because it generalises past descriptors. A struct declared <code>&#123; uint16_t limit; uint64_t base; &#125;</code> and marked <code>packed</code> is 10 bytes and looks correct, and the compiler will not warn you, and the program will run, and the output will be a plausible base in the middle of nowhere with a limit of zero. The failure mode is silent, it is stable, and it is <em>indistinguishable from a legal state</em>.</p>
                <p><strong>The general rule: prefer a reading that fails loudly to one that returns a plausible wrong answer.</strong> A parser that validates its input and rejects it can be debugged. A parser that confidently reports a limit of zero will be believed, and the belief will propagate.</p>
                <h3>What a gate actually is</h3>
                <p>Each of the 4096 slots is a 16-byte descriptor. In long mode it is:</p>
                <div class="formula">
   byte  0.. 1   offset 15:0  of the handler address
   byte  2.. 3   segment selector
   byte  4.. 5   offset 31:16, and in the same 16-bit word:
                    bits  4:0   IST index  (which stack to switch to)
                    bits 11:8   type      (0xE interrupt, 0xF trap)
                    bit  12     P         present
                    bits 14:13  DPL       descriptor privilege level
   byte  8..11   offset 63:32 of the handler address
   byte 12..15   reserved
                </div>
                <p>And here is a second thing that the tables in textbooks get wrong, in a way that is easy to miss because the error is a <em>missing</em> term rather than a wrong one. The rule most courses state for &ldquo;gates&rdquo; is</p>
                <div class="formula">
   MAX(CPL, RPL) &lt;= DPL
                </div>
                <p>That is the <strong>call-gate</strong> rule, and it is correct &mdash; for call gates. It is <em>not</em> the interrupt-gate rule, because an IDT entry is reached by a <em>vector number</em> and a vector number has no RPL field to carry. Intel's own pseudocode is one-sided:</p>
                <div class="formula">
   IF gate.DPL &lt; CPL THEN #GP(vector, 1, 0)
                </div>
                <p>and AMD states the reason explicitly in its privilege-checks section: <em>&ldquo;unlike call gates, no RPL comparison takes place. This is because the gate descriptor is referenced in the IDT using the interrupt vector number rather than a selector, and no RPL field exists in the interrupt vector number.&rdquo;</em></p>
                <p>Where does the folklore come from, then? From the manuals themselves, being internally inconsistent: Intel's <em>task-gate</em> pseudocode includes the RPL comparison, and the task gate is also reached by a vector number. So the manuals disagree with each other in the same volume, and the widely-repeated two-sided rule is a synthesis that fits one gate type and not the other. <strong>If you are writing a kernel and you use the two-sided rule for IDT gates, you will reject transitions you were supposed to allow, and the symptom will be a system that will not boot for reasons nobody can find.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: three questions with the artifact</h2>
                <p>Build it and ask it things. The three below are the ones worth asking first, and the third is the one that teaches the most.</p>
                <div class="formula">
  Q1. Where does this kernel put its IDT?
     $ ./privbench | grep -A2 "the ten bytes"
     -> base 0xffffffff00000000, limit 65535

     Do NOT conclude from this that every kernel
     chooses the same base.  A kernel may choose
     another.  Read the number; do not assume it.

  Q2. How many vectors can the hardware even look up?
     limit / 16 + 1 = 4096.
     That is an upper bound the hardware enforces,
     not an inventory of what exists.  On a machine
     with 12 threads and one APIC there might be
     forty vectors in use.

  Q3. Break the field order on purpose.
     Change struct pseudo_desc from
         &#123; uint64_t base; uint16_t limit; &#125;
     to
         &#123; uint16_t limit; uint64_t base; &#125;
     rebuild, and rerun the cross-check.  Group B
     fails on three named checks:
         the entry count is limit/16 + 1
         the base is 2^32 below the top of a 48-bit space
         reading the pseudo-descriptor backwards is shown wrong
     Note WHICH three and WHY.  A harness that just
     goes red has told you nothing.
                </div>
                <p>Q3 is the one to do. <strong>Exercise 3 exists because a check that has never been seen to fail is a check nobody has reason to believe</strong> &mdash; and the memory course made the same argument about its own verification. Break it, watch the specific checks fail, then put it back.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Write the ten bytes out by hand and decode them.</strong> From the ten bytes <code>00 00 00 00 ff ff ff ff ff ff</code>, write the base and the limit, then explain why the base is <code>00 00 00 00 ff ff ff ff</code> and not <code>ff ff ff ff 00 00 00 00</code>. <em>(Little-endian, offset 0 first &mdash; and the "offset 0 first" is the whole lesson.)</em></li>
                    <li><strong>Name the four fields you would check before believing any IDT dump.</strong> You are looking at a core dump or a hypervisor trace. Which bytes tell you the gate is present, which tell you its type, which tell you its DPL, and where is the handler address assembled from? <em>(P is bit 12 of bytes 4&ndash;5; type is bits 11:8 of the same word; DPL is bits 14:13; the offset is three separate fields at bytes 0&ndash;1, 8&ndash;11, and the top of bytes 4&ndash;5.)</em></li>
                    <li><strong>Explain why <code>int $0x80</code> is a memory-safety question and not a style question.</strong> Hint: what does the hardware do with a vector for which <code>(vector &lt;&lt; 4) + 15</code> exceeds the limit?</li>
                    <li><strong>Find the limit on a machine you have.</strong> <code>SGDT</code> is the same shape and has the same field order; use it on a 32-bit bootloader or read it under a hypervisor. Then explain why the GDT's limit is a different kind of number from the IDT's.</li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Forward, <a href="/courses/priv/lessons/priv-vectors">the next concept</a> asks what is in the 4096 slots &mdash; and finds that eight of the thirty-two defined numbers mean different things to Intel and AMD, which is a stronger statement about the boundary than anything in this one. <a href="/courses/priv/lessons/priv-doors">The doors concept</a> then shows that two of the three ways into the kernel never consult this table at all, which is why they are faster and why they are also unchecked by hardware. <a href="/courses/priv/lessons/priv-three">The three-architectures concept</a> is where the DPL-vs-RPL subtlety reappears as a genuinely different design: RISC-V makes the delegation a writable field the firmware owns.</p>
                <p>Backwards, <a href="/courses/sec/lessons/sec-posture">the security course's posture concept</a> enumerated the control-register bits as flags a hardening policy can set, and never asked who is allowed to read them. <strong>Answer: nobody in ring 3</strong>, which is why this course reports SMEP and SMAP as a <em>report</em> rather than a measurement. And <a href="/courses/mem/lessons/mem-translation">the memory course's translation concept</a> measured what happens when an address reaches the page tables with nothing there &mdash; this concept is the layer above that, where the address is rejected before it ever gets the chance.</p>
                <p>Outward: if you are writing a compiler backend, this is the point where &ldquo;the program runs&rdquo; stops being a metaphor. Your code will eventually execute <code>syscall</code>; someone has to have put a gate in that table, and the DPL on that gate is what makes your program's request reach a handler instead of a wall. <strong>You do not need to know the answer to build the next course in this chain. You do need to know the question exists.</strong></p>
            </div>

            <div class="lesson-footer">
                <span>First: <a href="/courses/priv">course home</a></span>
                <span>Next: <a href="/courses/priv/lessons/priv-vectors">Numbers, and the Ones That Are Not Numbers</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
