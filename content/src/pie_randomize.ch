// Relocations, PIC and PIE — Module 2: Position Independent Executables
// Concept: six runs, two builds, and the difference between a random base and a
// random address.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pie_randomize() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Does the Executable Actually Move? — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson reloc-lesson">
            <a href="/courses/reloc" class="back-link">Back to course</a>
            <h1>Does the Executable Actually Move?</h1>
            <div class="lesson-meta">18 min &middot; Module 2: Position Independent Executables &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>&ldquo;PIE enables ASLR&rdquo; is a true sentence that is easy to believe and easy to over-apply. The useful question is not whether the feature exists but <em>what it actually randomises</em>, and that has a precise answer you can measure in six runs.</p>
                <div class="hex-dump">
                    <pre>$ cat where.c
#include &lt;stdio.h&gt;
int main(void){ printf("%p\n", (void*)main); return 0; }

$ clang -O1 -o w_pie where.c
$ clang -O1 -fno-pie -no-pie -o w_nopie where.c
</pre>
                </div>
                <p>Nothing clever here &mdash; one function, one pointer, printed. The address of <code>main</code> is a fact about the load, and it is the most direct available proxy for &ldquo;where did the loader put this image&rdquo;.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>There are two different things that could be random, and confusing them is the source of most of the misconception.</p>
                <div class="formula">
  WHAT IS RANDOMISED

    the BASE      where the image is mapped. chosen by the
                  kernel at exec time. THIS is what ASLR
                  randomises, and it is the only thing
                  that matters for an exploit that
                  hard-codes an address.

    NOT the layout. Not the order of sections, not the
                  internal offsets, not the page offset
                  within the first mapping.

  CONSEQUENCE: every address inside the image shifts by
  exactly the same amount, and every DISPLACEMENT between
  two addresses inside it is unchanged.

  which is precisely why a relative relocation needs no
  runtime fixup at all: S - P is invariant under translation.

                </div>
                <p><strong>That is the deep reason relative relocations exist and why they are cheap.</strong> If the whole image is translated by <em>&Delta;</em>, then <code>(S + &Delta;) - (P + &Delta;) = S - P</code>. The displacement is an invariant of the layout, so a relative relocation can be computed entirely at link time and is <em>still correct</em> after the loader moves everything. <code>ET_EXEC</code> is not &ldquo;the version without ASLR&rdquo; in some special sense; it is the version where the loader declines to add <em>&Delta;</em>.</p>
                <p>And that in turn explains why the absolute relocations are the dangerous ones. An absolute relocation stores <code>S</code>, not <code>S - P</code>, so it is <strong>not</strong> translation-invariant and the loader has to fix every one of them after choosing <code>&Delta;</code>. That is the difference between the two relocation groups the previous module drew, and it is why a PIE still has dynamic relocations at all.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>Six runs each:</p>
                <div class="hex-dump">
                    <pre>$ for f in w_pie w_nopie; do
    printf "%-8s " $f
    for i in 1 2 3 4 5 6; do printf "%s " $(./$f); done
    echo
  done

w_pie    0x631601ffb140  0x63c0b0b59140  0x5d2cde541140
         0x64ca65330140  0x614725b95140  0x5f2b0e7c1140
w_nopie  0x401130 0x401130 0x401130 0x401130 0x401130 0x401130
</pre>
                </div>
                <p><strong>Six distinct PIE addresses. One non-PIE address, six times.</strong> That is ASLR, observed directly rather than inferred from a flag.</p>
                <p>Now the detail that makes the model precise, and it is visible if you look at the last three hex digits:</p>
                <div class="hex-dump">
                    <pre>  0x631601ffb140   low 12 bits:  140
  0x63c0b0b59140   low 12 bits:  140
  0x5d2cde541140   low 12 bits:  140
  0x64ca65330140   low 12 bits:  140
</pre>
                </div>
                <p><strong>Every single run ends in <code>140</code>.</strong> The page offset of <code>main</code> within the image is a link-time constant, and the loader randomises the base on a page boundary so that this offset stays valid. <strong>ASLR gives you a random base, not a random address</strong> &mdash; the entropy is in the high bits, and it has to be page-granular or the low bits would break every page-aligned assumption in the process.</p>
                <p>And the non-PIE address explains itself:</p>
                <div class="hex-dump">
                    <pre>$ readelf -hW w_nopie | awk '/Type:/{print "  e_type:", $2}'
  e_type: EXEC
$ readelf -lW w_nopie | grep -A1 LOAD | head -2
  LOAD  0x0000000000000000  ... vaddr 0x400000
</pre>
                </div>
                <p><strong><code>0x401130</code> is below 2<sup>31</sup>, because an <code>ET_EXEC</code> binary is mapped at a fixed address the linker chose, and the traditional choice is around 0x400000.</strong> The kernel honours that for a non-PIE executable, so the address is the same on every machine, every boot, forever. Any attacker who knows one such binary knows where its <code>main</code> is on every machine that runs it.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Why this mattered historically, because the reason PIE became the default is a specific bug class rather than a general principle.</p>
                <div class="hex-dump">
                    <pre>  THE SHAPE OF THE ATTACK, and what each defence removes

  a. hard-coded address          the executable is at a
                                  KNOWN address, so the
                                  payload address is known
       -> defeated by a PIE base

  b. a code pointer in .data      the binary contains a
                                  pointer to its own code,
                                  at a known offset
       -> defeated by a PIE base, because the pointer
          is absolute and gets RELOCATED

  c. a return address on the      not address-dependent.
     stack                        NOT defeated by PIE.

  d. a vtable or function         the pointer lives in
     pointer in .rodata           RELOCATABLE memory
       -> defeated by RELRO, not by PIE
</pre>
                </div>
                <p><strong>PIE removes (a) and (b), and only those.</strong> It does nothing for (c) or (d). A stack-based exploit works identically against a PIE; a vtable overwrite works identically against a PIE unless the page is also made read-only. That is not a criticism of PIE &mdash; it is the reason to understand what it does rather than to assume it is &ldquo;ASLR&rdquo; in the general sense.</p>
                <p>Attack (b) is the subtler one and it is worth spelling out, because it is a direct consequence of the relative/absolute distinction from the model above. A non-PIE executable stores the address of its own code <em>as an absolute value</em> in <code>.data.rel.ro</code>. A PIE stores it as <code>0</code> plus a <code>R_X86_64_RELATIVE</code> relocation, and the loader writes <code>base + 0</code> at load time. <strong>The bit pattern on disk is identical in a non-PIE binary and useless; in a PIE it is a template the loader fills in.</strong> Same source, same compiler flags for the code &mdash; the difference is entirely <code>e_type</code>.</p>
                <p>And this is where the <a href="/courses/reloc/lessons/pie-flags">previous concept</a>&rsquo;s incoherent row becomes a security fact rather than a performance one. A binary compiled <code>-fPIE</code> and linked <code>-no-pie</code> is an <code>ET_EXEC</code>, so the loader will <strong>not</strong> move it &mdash; but the code was compiled to expect a GOT and the absolute self-references were emitted for a fixed layout. It runs, it is not randomised, and the developer believed they had asked for PIE. <strong>Four flags, two processes, and a security property that depends on all four agreeing.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/reloc/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/F4/,/F5/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/\[4\]/,/\[5\]/p'
</pre>
                </div>
                <p>Then check the claims rather than the slogan:</p>
                <div class="hex-dump">
                    <pre>  1. Run w_pie 20 times. How many DISTINCT high parts
     (address >> 12) do you get? Is it 20?

  2. Print the address of a LOCAL variable, not main.
     Is its low 12 bits also constant? Should they be?

  3. Print an address in the HEAP (malloc). Is the low
     12 bits constant? If not, why is that different from
     the executable's case?

  4. cat /proc/self/maps on a PIE and a non-PIE. How many
     lines have a different start address across runs?
     Which sections are NOT randomised in either?

  5. Build with -Wl,-z,norelro as well. Does that change
     the base address at all? (It should not.)
</pre>
                </div>
                <p>Question 3 is the one that fixes the model, and the answer is instructive. <strong>The heap is page-granular random too, but an individual allocation&rsquo;s low 12 bits depend on the allocator&rsquo;s internal bookkeeping, not on where the mapping landed.</strong> The distinction you want is not &ldquo;random address&rdquo; against &ldquo;fixed address&rdquo; &mdash; it is &ldquo;does the attacker know this offset in advance&rdquo;. For the executable&rsquo;s own code the answer was yes and is now no. For a heap object it depends on how the program allocates, and no linker flag changes that.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the empirical centre of the PIE module, and it exists to make the previous concept&rsquo;s matrix mean something. <a href="/courses/reloc/lessons/pie-flags">The Flags, and Which One Is Which Kind</a> established that you can end up with a binary that is neither, and warned that the dangerous one is silent. <strong>This concept supplies the test that tells you which binary you actually have</strong>, and it is a two-line program rather than a flag.</p>
                <p>Forward, <a href="/courses/reloc/lessons/pie-cost">What Position Independence Costs</a> is the other half of the decision. This one says what PIE buys &mdash; a random base, and with it attacks (a) and (b) &mdash; and that one says what it charges, in instructions and bytes. Neither alone justifies the flag; together they are the whole argument, and the conclusion that falls out of the pair is that for a modern program the cost is small and the benefit is a removed bug class.</p>
                <p>The connection back to the vocabulary module is the sharpest technical thread in the course, and it is worth stating as a single sentence. <a href="/courses/reloc/lessons/reloc-why-so-many">Why There Are So Many Kinds</a> divided the relocations into the linker&rsquo;s and the loader&rsquo;s. <strong>This concept is why that division exists at all</strong>: a relative relocation is correct at link time forever, so it never appears in a dynamic relocation section; an absolute one is only correct for one load address, so the loader must revisit every one of them after choosing <code>&Delta;</code>. The randomised base is not a property bolted onto a fixed binary &mdash; it is what forces the absolute forms to exist at all.</p>
                <p>And the connection into the failure module is about a case this concept cannot produce. <strong>Every address in the experiments above is a <em>code</em> address, and code addresses are relative to the instruction stream.</strong> Thread-local storage is addressed relative to a thread pointer, which is per-thread and assigned at runtime, and there the &ldquo;base &Delta;&rdquo; model breaks down completely. <a href="/courses/reloc/lessons/tls-model">The One Relocation That Calls the Loader</a> is where the loader has to stop writing numbers into fields and start <em>running a function</em>, and it is the one place in this course where the answer to &ldquo;which relocation is this&rdquo; is &ldquo;it depends when you ask&rdquo;.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/reloc/lessons/pie-flags">Previous: The Flags, and Which One Is Which Kind</a></span>
                <span>Next: <a href="/courses/reloc/lessons/pie-cost">What Position Independence Costs</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
