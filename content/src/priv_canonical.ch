// Exceptions, Privilege and Mode Changes — Concept 5: the canonical hole
public namespace underlayer_content {

using std::string

using std::string_view

public func render_priv_canonical() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Hole Has No Fixed Address — Underlayer")
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
            <h1>The Hole Has No Fixed Address</h1>
            <div class="lesson-meta">28 min &middot; <a href="/courses/priv">Exceptions, Privilege and Mode Changes</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Ring 3 is usually taught as &ldquo;less privileged,&rdquo; which is vague. Here is what it actually is, and it is not a permission. <strong>A ring-3 process cannot name more than half the address space, and the reason is that the other half is not an address.</strong></p>
                <p>Every course in this collection that has mentioned canonical addressing has given you a one-line rule &mdash; &ldquo;bits 63:48 must be all zero or all one&rdquo; &mdash; and that rule is not wrong, but it is incomplete, and the incompleteness has a measurable consequence that will produce a wrong answer in a debugger, in a crash report, and in a fuzzing harness.</p>
                <p><strong>The consequence:</strong> a non-canonical access is not a page fault. It is not a permission failure. It is the CPU refusing to form an address at all. And when that happens, the address you would need to debug it <em>is not delivered to anyone</em>.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: one comparison, not a range</h2>
                <p>A 64-bit linear address is canonical when bit 47 equals bit 63. That is the complete rule for the 48-bit configuration, and it is one equality test:</p>
                <div class="formula">
   canonical(a)  ==  ((a &gt;&gt; 47) &amp; 1) == ((a &gt;&gt; 63) &amp; 1)

   0x0000_0000_0000_1000   bit47=0 bit63=0   canonical
   0x0000_3fff_ffff_ffff   bit47=0 bit63=0   canonical
   0x0000_7fff_ffff_ffff   bit47=0 bit63=0   canonical   <- top of low half
   0x0000_8000_0000_0000   bit47=1 bit63=0   NOT         <- 2^47
   0xffff_7fff_ffff_ffff   bit47=1 bit63=1   canonical
   0xffff_8000_0000_0000   bit47=0 bit63=1   canonical   <- bottom of high half
   0xffff_ffff_ffff_ffff   bit47=1 bit63=1   canonical

   The gap is [2^47, 2^64 - 2^47) -- 53% of the space,
   and none of it names memory.
                </div>
                <p><strong>And here is the trap in the familiar phrasing.</strong> &ldquo;Bits 63:48 are all zero or all ones&rdquo; is <em>not</em> the same rule. Test that phrasing against <code>0x0000800000000000</code>: bits 63:48 are all zero, so the familiar phrasing calls it canonical, and it is not &mdash; bit 47 is set and bit 63 is clear. The correct statement of the rule is that bits above the implemented width must be a <em>sign extension</em> of the top implemented bit, and a parity test is how you say that. <strong>Every course in this collection that has written the shorter version has been wrong in a way that only shows up at exactly one address, which is the worst possible place to be wrong.</strong></p>
                <p>Two further wrinkles the manuals flag and short treatments omit. With five-level paging (<code>CR4.LA57</code>) the implemented width is 57 bits and the test is against bit 56. And <code>CR3</code> has two Linear Address Masking bits, <code>LAM_U48</code> and <code>LAM_U57</code>, which permit a <em>user-mode</em> address to have bits above the boundary non-zero. Both are real. Neither is on in the configuration this course measures, and <strong>the honest statement is that the 48-bit rule above is the baseline rather than the universal case.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: the boundary is a function of the access</h2>
                <p>Probe it the obvious way &mdash; one 4-byte read, either side of 2<sup>47</sup> &mdash; and the boundary looks like it is at 2<sup>47</sup>. It is not. Here is the same address probed three ways:</p>
                <div class="hex-dump">
                <pre>$ ./privbench | sed -n '/address  *1 byte/,/THE RULE/p'
   address                    1 byte   4 byte   8 byte
   2^47 -10 0x00007ffffffffff6       1        1        1
   2^47  -7 0x00007ffffffffff9       1        1      128
   2^47  -4 0x00007ffffffffffc       1        1      128
   2^47  -3 0x00007ffffffffffd       1      128      128
   2^47  -1 0x00007fffffffffff       1      128      128
   2^47  +0 0x0000800000000000     128      128      128
   2^47  +1 0x0000800000000001     128      128      128

   Bisecting separately for each width:
      1-byte  first rejected address 0x0000800000000000   2^47 minus it = 0
      4-byte  first rejected address 0x00007ffffffffffd   2^47 minus it = 3
      8-byte  first rejected address 0x00007ffffffffff9   2^47 minus it = 7
</pre>
                </div>
                <p><code>si_code</code> 1 is <code>SEGV_MAPERR</code>: the CPU accepted the address and the page tables said no. <code>si_code</code> 128 is <code>SI_KERNEL</code>: the CPU rejected the address itself.</p>
                <p><strong>The rule, exactly:</strong></p>
                <div class="formula">
   first rejected address  =  2^47  MINUS  (access size MINUS 1)

     1-byte  ->  2^47 - 0
     4-byte  ->  2^47 - 3
     8-byte  ->  2^47 - 7
                </div>
                <p>A read that <em>starts</em> below 2<sup>47</sup> still fails if it <em>reaches</em> 2<sup>47</sup>. The CPU validates the whole byte range of the operand, not merely its first byte. That is why an 8-byte read dies seven bytes early and a 1-byte read gets right up to the line, and it is confirmed here three independent ways: by a twelve-row matrix and by a separate bisection per width, all agreeing.</p>
                <h3>Why this is the whole concept</h3>
                <p>Because it explains why a non-canonical access <strong>cannot</strong> produce a page fault. There is nothing for the page tables to look up, because there is no address. No present bit to clear, no protection key to check, no <code>CR2</code> to load with anything meaningful, and no <code>si_addr</code> for the kernel to hand back. The kernel reports the fault with an <strong>address of zero</strong>:</p>
                <div class="formula">
   What a handler actually receives:

     unmapped canonical address   SIGSEGV  si_code=1    si_addr = the address
     non-canonical address        SIGSEGV  si_code=128  si_addr = 0
                </div>
                <p>Two faults. One signal number. The same <code>si_addr</code> a program is told is &ldquo;the address that faulted.&rdquo; <strong>And a fault handler that reads <code>si_addr</code> before checking <code>si_code</code> receives a null pointer and concludes the program dereferenced <code>NULL</code> &mdash; which is a completely different bug, in a completely different file, with a completely different fix.</strong> If you are writing a crash reporter, a fuzzer harness, or a debugger, this is the single most expensive distinction in this course.</p>
                <p>There is a second-order version of the same trap, worth knowing because it will look like a contradiction. Intel's manual specifies that a non-canonical memory reference using <code>RSP</code> or <code>RBP</code> as the base raises <code>#SS</code>, not <code>#GP</code>, and that a segment override changes that back to <code>#GP</code>. So the vector a non-canonical access produces <em>depends on which register formed the address</em>. Nothing in the signal tells you which &mdash; the kernel has already collapsed it &mdash; and this course does not measure it, because from ring 3 the only observable is the same <code>si_code</code> 128 either way. <strong>It is listed in the artifact's limits rather than quietly omitted.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: how the measurement nearly went wrong, three times</h2>
                <p>This result took three corrections to reach, and the corrections are the most useful part.</p>
                <div class="formula">
  1. THE PREDICATE WAS WRONG.
     The first version tested "bits 63:48 all zero or all
     one", which calls 0x0000800000000000 canonical.  The
     printed matrix therefore labelled the one address
     that mattered as fine.

  2. THE BISECTION WAS BISECTING THE WRONG QUESTION.
     It searched for where the fault STOPS, on a machine
     where every candidate address faults.  It converged
     on 0x0 / 0x1 -- a true statement about an unmapped
     page and a completely irrelevant one.  It had to
     bisect on the si_code TRANSITION instead.

  3. AND THE BISECTION THEN REPORTED A BOUNDARY INSIDE
     A SINGLE PAGE.
     0x00007ffffffffffc / ...d.  Impossible: nothing in
     x86 page granularity produces a 3-byte boundary.
     The cause was memset(&g, 0, sizeof g) on a struct
     that a signal handler writes.  memset takes void*,
     so its writes are not volatile-qualified, the
     compiler elided them, and the record held values
     from a PREVIOUS probe.

     The lesson is wider than volatile: a measurement
     harness whose intermediate state is not volatile
     will hand you a plausible wrong answer rather than
     a warning.  This one printed its result with total
     confidence and a two-row-tidy summary beside it.
                </div>
                <p>What finally produced the matrix is not cleverer code. It is the observation that <strong>if the answer depends on the access, then ask with different accesses</strong> &mdash; which is the same move the memory course made when it stopped measuring one thing and started comparing two. A single probe gives one number; a probe repeated across a parameter gives a rule.</p>
                <p>Try it. Add a 16-byte read to the three arms, rebuild, and check the prediction: the boundary should land at 2<sup>47</sup>&minus;15. <strong>If it does not, the course is wrong and you have found it in four lines.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Add the 2-byte and 16-byte arms and test the rule.</strong> Predicted boundaries: 2<sup>47</sup>&minus;1 and 2<sup>47</sup>&minus;15. <em>(The harness group F asserts the existing three widths exactly, so a fourth width that breaks the rule will not be caught by it &mdash; you will have to extend the harness too, which is the point of exercise 2.)</em></li>
                    <li><strong>Extend the harness, then break the rule on purpose.</strong> Add the two widths to the artifact, rebuild, confirm the harness still passes, then change the access to a masked load that only touches one byte. <strong>Which group fails, and does the failure name the width or just say &ldquo;the shape is wrong&rdquo;?</strong> A check that cannot name what broke is a check you will spend an hour learning to trust.</li>
                    <li><strong>Write the crash-reporter rule.</strong> Your handler receives a <code>siginfo_t</code>. Write the exact sequence of tests that distinguishes: null dereference, unmapped read, write to a read-only page, and non-canonical access. <em>(The answer: check <code>si_code</code> first, and treat 128 as &ldquo;the CPU rejected the address; there is no address; do not trust <code>si_addr</code>&rdquo;.)</em> Then state what your reporter prints in each case.</li>
                    <li><strong>Work out how much of the address space ring 3 can reach, and check it against the page tables.</strong> With 48-bit canonical addressing and a 47-bit userspace limit, the practical figure is smaller than the architectural one. Read <code>/proc/self/maps</code>, find your highest mapping, and explain the gap between it and 2<sup>47</sup>. <strong>Whose decision is each of the two boundaries, and which one does the CPU enforce?</strong></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Forward, <a href="/courses/priv/lessons/priv-errorcode">the error-code concept</a> takes the <code>si_code</code> values this one produces and asks what else the CPU told the kernel that a process cannot see. <a href="/courses/priv/lessons/priv-three">The three-architectures concept</a> is where this stops being a hole: AArch64 uses the same implemented-bits-above-the-split idea, and the top half there is a device region rather than nothing, which is a different design answering the same question.</p>
                <p>Backwards, the chain is direct and worth tracing. <a href="/courses/priv/lessons/priv-convention">The convention concept</a> established what happens when a ring-3 program asks for something; this one covers the space it asks from. Before that, <a href="/courses/priv/lessons/priv-doors">the doors concept</a> measured the cost of the crossing, and the two together are the complete story of a system call: <em>here is what it costs, and here is the world you are allowed to name from where you land.</em></p>
                <p>To earlier courses, this is the concept that gives the memory course's numbers their boundary. <a href="/courses/mem/lessons/mem-translation">The translation concept</a> measured what happens when a canonical address reaches the page tables with nothing there &mdash; a translation cost, a TLB cliff, a 3.29&times; ratio. All of that presumes the address is real. <strong>This concept is the layer above it, where the address is rejected before the page tables are ever consulted, and where &ldquo;rejecting an address&rdquo; turns out to be a surprisingly large part of what a privilege boundary does.</strong></p>
                <p>Outward, for anyone writing a kernel or a hypervisor, the practical consequence is short. If your fault handler reads <code>CR2</code> and assumes it is a valid address, you will crash. And if you report the faulting address to userspace without checking whether the address was canonical, <strong>you will hand a user program a null pointer and a lie about what happened</strong> &mdash; which is a bug that will be reported as &ldquo;my program dereferences null on some inputs&rdquo; and will be unfixable from the other side of the boundary.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/priv/lessons/priv-convention">The Convention, in the Kernel's Own Bytes</a></span>
                <span>Next: <a href="/courses/priv/lessons/priv-errorcode">Three Error Codes and None of Them Visible</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
