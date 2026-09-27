// Static Linking and Linker Scripts — Module 2: Placing Things
// Concept: the dot, ALIGN, SIZEOF, and one number that moves the whole binary.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_link_location_counter() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Location Counter — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson link-lesson">
            <a href="/courses/link" class="back-link">Back to course</a>
            <h1>The Location Counter</h1>
            <div class="lesson-meta">23 min &middot; Module 2: Placing Things &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>You write an address into a script and you do not get that address. This is the most common surprise in the whole subject and it has one cause.</p>
                <div class="hex-dump">
                    <pre>$ python3 - &lt;&lt;'PY'
s = open('default.ld').read()
s = s.replace('  .text           :\n', '  .text 0x900000 :\n', 1)
open('abs.ld','w').write(s)
PY
$ readelf -SW place_abs | awk '/ \.text /{print "  .text addr = "$4}'
  .text addr = 0000000000900000
$ readelf -sW place_abs | awk '/ answer$/{print "  answer   = "$2}'
  answer   = 00000000009000f0
</pre>
                </div>
                <p><strong><code>.text</code> is at 0x900000, exactly as written, and <code>answer</code> is at 0x9000f0 &mdash; 240 bytes further on.</strong> Setting the address of an output section sets the address of its <em>first byte</em>, and the first byte belongs to whatever the first matching rule put there. In this binary that is <code>_start</code> and the C runtime, not your function.</p>
                <p>But that is only half the gap, and the other half is the one this concept is about. Ask a smaller question: <em>how far is the image base from the first byte of <code>.text</code>?</em> Because that is a number the script computes, and it is not zero.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>There is exactly one mutable variable in a linker script and it is spelled as a full stop.</p>
                <div class="formula">
  THE DOT

  . = EXPR;                assign it (any expression)
  .text : RULES              the output section starts
                              WHEREVER THE DOT IS NOW
  .text 0x900000 : RULES     ...or at 0x900000, and the
                              dot MOVES THERE

  RULES stands for a brace-delimited list of input
  section patterns. braces are legal in a script but
  not in this box, so they are named here and quoted
  for real in the hex dumps below.

  the dot is also readable:
  PROVIDE (__etext = .);

  the default script's first two statements are the
  whole story:

    . = SEGMENT_START("text-segment", 0x400000)
        + SIZEOF_HEADERS;

  meaning: the image goes at the text segment's start,
  then SKIP FORWARD BY THE SIZE OF THE HEADERS, because
  the headers live at the front of the image and the
  code cannot start on top of them.

  measured on this build: SIZEOF_HEADERS = 0x350.

                </div>
                <p><strong>So the distance between &ldquo;where the image is&rdquo; and &ldquo;where your code is&rdquo; is <code>SIZEOF_HEADERS</code>, and it is a real number you can read out of the binary.</strong> That is the answer to the surprise at the top of the page, and it is not a linker quirk: an ELF image is headers followed by content, and the headers have to go somewhere.</p>
                <p>What <code>SIZEOF_HEADERS</code> contains is worth knowing, because it is not a constant &mdash; it changes with your build:</p>
                <div class="formula">
  SIZEOF_HEADERS = ehdr (64 bytes on 64-bit)
                 + phdrs (56 bytes each, x the count)
                 + shdrs (64 bytes each, x the count)

  this is why it is a FUNCTION and not a literal.
  add a program header with PHDRS and it grows. add a
  section with a rule and it grows. that is why a
  script that hard-codes 0x350 is wrong the moment
  anything changes.

                </div>
                <p>And the three things you can do with the dot that actually matter in practice:</p>
                <div class="formula">
  MOVE IT EXPLICITLY
     . = 0x80000000;              jump somewhere absolute

  ALIGN IT
     . = ALIGN(0x1000);           round UP to a multiple
     . = ALIGN(0x1000, 0x8000);  ...or DOWN to one

  READ IT
     __etext = .;                  the end of the text
     _edata = .;                   the end of the data

  the real script uses all three, and the ALIGNs are
  the load-bearing ones: an ALIGN(MAXPAGESIZE) between
  segments is what makes each PT_LOAD start on a page
  boundary, which is what lets the loader mmap it.

                </div>
                <p><strong>Alignment between segments is not tidiness &mdash; it is a requirement of the loading mechanism.</strong> A <code>PT_LOAD</code> is mapped a page at a time. If one segment ended at 0x401234 and the next began there, the loader would have to map a page containing the end of one and the start of the next with two different sets of permissions, and the kernel cannot do that. <code>ALIGN</code> is what prevents the situation from arising, and it is why the <a href="/courses/elf/lessons/memory-mapping">ELF course</a> measured four <code>PT_LOAD</code>s all with <code>0x1000</code> alignment.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>Three measurements. First, the gap, read out of the binary rather than reasoned about:</p>
                <div class="hex-dump">
                    <pre>$ python3 - &lt;&lt;'PY'
s = open('default.ld').read()
s = s.replace('SECTIONS\n{', 'SECTIONS\n{\n'
  '  PROVIDE(__p_hdr = SIZEOF_HEADERS);\n'
  '  PROVIDE(__p_txt = SEGMENT_START("text-segment", 0xDEADBEEF));', 1)
open('probe.ld','w').write(s)
PY
$ clang -O1 -fno-pie -no-pie hello.o -o probe.out -T probe.ld \
      -Wl,-u,__p_hdr -Wl,-u,__p_txt
$ readelf -sW probe.out | grep __p_
  __p_txt = 00000000deadbeef      &lt;-- the SECOND argument, verbatim
  __p_hdr = 0000000000000350      &lt;-- 848 bytes of headers
</pre>
                </div>
                <p><strong>848 bytes, and it moved.</strong> 64 for the ELF header, then program headers, then section headers. Add a section with a rule and it grows, which is exactly why it is a function.</p>
                <p>Second, the surprise about <code>SEGMENT_START</code>, which is the more interesting of the two probes and the one that corrects a natural assumption. The name reads like a query to the target emulation, with the literal as a fallback:</p>
                <div class="hex-dump">
                    <pre>  SEGMENT_START("text-segment", 0xDEADBEEF)  -&gt;  0xdeadbeef

  the obvious story: "it asked the emulation where the
  text segment starts, found no answer, used mine."

  the measurement says otherwise, because the SAME
  probe proves the mechanism works:

  CONSTANT(MAXPAGESIZE)  -&gt;  0x1000     the real page size
                                     ^ a real answer, from
                                       the emulation

  so CONSTANT() demonstrably queries the emulation, and
  SEGMENT_START() demonstrably did not. on x86-64 Linux
  this emulation has NO opinion about "text-segment", so
  the second argument IS the answer.

  and that means the 0x400000 you have been reading in
  every script is not a format constant. it is a
  fallback that happens to be used. the name is a hook
  for targets that genuinely have named segments.
</pre>
                </div>
                <p><strong>Reading <code>0x400000</code> as &ldquo;where ELF executables go&rdquo; is therefore a coincidence of this target, not a fact about the format.</strong> Change it and everything moves &mdash; which is the third measurement, and the one that makes the point unarguable:</p>
                <div class="hex-dump">
                    <pre>$ for base in 0x400000 0x10000000 0x800000; do
    sed "s/SEGMENT_START(\"text-segment\", 0x400000)/SEGMENT_START(\"text-segment\", $base)/g" \
        default.ld &gt; b.ld
    clang -O1 hello.o -o moved_$base -T b.ld
    printf "  base=%-12s first LOAD=%s  " $base \
      "$(readelf -lW moved_$base|awk '/LOAD/{print $3;exit}')"
    ./moved_$base; echo "ran, exit=$?"
  done

  base=0x400000     first LOAD=0x0000000000400000  ran, exit=0
  base=0x10000000   first LOAD=0x0000000010000000  ran, exit=0
  base=0x800000     first LOAD=0x0000000000800000  ran, exit=0
</pre>
                </div>
                <p><strong>Two occurrences replaced, and the whole image moved &mdash; and ran correctly at all three.</strong> The third is the one worth noting: 0x800000 is an unremarkable address that nothing reserves, and the binary executed there and returned the right answer. <strong>The number in the script is not documentation the loader may reinterpret. It is where the CPU jumps on entry.</strong></p>
                <p>Now the other half of the surprise from the top of the page, which is about rule order rather than the dot, and the two are independent:</p>
                <div class="hex-dump">
                    <pre>$ readelf -SW place_abs | awk '/ \.text /{print "  .text starts at "$4}'
  .text starts at 0000000000900000
$ readelf -sW place_abs | awk '/ answer$/{print "  answer at   "$2}'
  answer at   00000000009000f0
$ nm -n place_abs | head -4
  00000000009000f0 T answer
  ...
</pre>
                </div>
                <p><strong>240 bytes of <code>_start</code> and C-runtime code sit between the address you set and the function you were thinking of.</strong> And <a href="/courses/link/lessons/link-order">the previous concept</a> is what explains it: <code>.text</code> is placed by the <em>first rule that matches</em>, and in the default script that is rule 1 &mdash; <code>*(.text.unlikely ...)</code> &mdash; not your function.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The form the <code>ALIGN</code> takes in the real script, and why the expression is so contorted that it looks like a mistake:</p>
                <div class="hex-dump">
                    <pre>  /* Adjust the address for the rodata segment.  We want to adjust
     up to the same address within the page on the next page up.  */
  . = SEGMENT_START("rodata-segment",
        ALIGN(CONSTANT(MAXPAGESIZE)) + (. &amp; (CONSTANT(MAXPAGESIZE) - 1)));
</pre>
                </div>
                <p>Unpack it. <code>. &amp; (MAXPAGESIZE - 1)</code> is the current offset <em>within</em> the page. Adding it to the next page boundary gives an address with <strong>the same offset within a page, on the following page</strong>. The comment says exactly that.</p>
                <p><strong>Why preserve the offset?</strong> Because of the <a href="/courses/reloc/lessons/reloc-encoding-limits">&plusmn;2GB displacement limit</a>. A read-only data segment that starts at a page-aligned address pushes the distance from code to data up to a full page, and doing that repeatedly, in a large program, eats the budget. Keeping the intra-page offset constant means every <code>PC32</code> reference to read-only data stays exactly as short as it was.</p>
                <p>That is a genuinely subtle line and it is the strongest single argument for reading linker scripts: <strong>someone measured a binary that was growing too large, traced it to read-only data being page-aligned away from the code, and wrote an expression that looks like line noise to preserve an offset nobody would think to check.</strong> The <code>ALIGN(MAXPAGESIZE)</code> on its own is required (the loader needs page boundaries). The <code>+ (. &amp; (MAXPAGESIZE - 1))</code> on the end is an optimisation layered on top, and the comment is the only thing in the file that tells you which part is which.</p>
                <p>And the <code>ALIGN</code> inside <code>.bss</code> carries a FIXME, which is worth reproducing because it is an honest unsolved question in a file maintained by the linker authors:</p>
                <div class="hex-dump">
                    <pre>  .bss :
  {
    *(.dynbss)
    *(.bss .bss.* .gnu.linkonce.b.*)
    *(COMMON)
    /* Align here to ensure that in the common case of there only being one
       type of .bss section, the section occupies space up to _end.
       Align after .bss to ensure correct alignment even if the
       .bss section disappears because there are no input sections.
       FIXME: Why do we need it? When there is no .bss section, we do not
       pad the .data section.  */
    . = ALIGN(. != 0 ? 64 / 8 : 1);
  }
</pre>
                </div>
                <p><strong>That is a conditional expression inside an <code>ALIGN</code> inside a section, written by the people who wrote the linker, with a comment asking themselves why it is there.</strong> It is also a good demonstration that linker scripts are ordinary source code: somebody can leave a question in a comment and a later version can answer it. The <code>. != 0</code> guard exists so the alignment is skipped when the counter is still zero, which is the case when the section disappears entirely &mdash; the two lines of comment before the FIXME are the answer, written after the question.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/link/assets/samples
$ ./build_samples.sh 2&gt;&amp;2 | sed -n '/F2/,/F4/p'
$ python3 crosscheck.py 2&gt;&amp;2 | sed -n '/\\[2\\]/,/\\[4\\]/p'
$ python3 linklab.py base 0x3000000
</pre>
                </div>
                <p>Then measure the gap, which is the exercise that makes the number real:</p>
                <div class="hex-dump">
                    <pre>  1. Write a script that PRINTS SIZEOF_HEADERS as a
     PROVIDE'd symbol, at three different link sizes
     (a tiny program, hello, and a -static one). What
     changes, and which of the three terms (ehdr,
     phdrs, shdrs) is responsible?

  2. Now print the ADDRESS of .text and subtract the
     image base. Is the difference exactly
     SIZEOF_HEADERS, or is there more? (There is more,
     and finding what it is is the exercise.)

  3. Put a page-unaligned base in: 0x400123 instead of
     0x400000. Does .text land at 0x400123 + 0x350,
     or somewhere rounded? Which line of the script
     rounded it?

  4. Add a PHDRS block with one extra PT_LOAD, and
     re-measure SIZEOF_HEADERS. By how much did it
     grow? (It should be 56 bytes, the size of one
     Elf64_Phdr. Count the terms in the formula above
     and check.)

  5. Delete the ALIGN(MAXPAGESIZE) between .text and
     .rodata in your own script. Does the link still
     succeed? Does the program still run? Now make
     .text big enough that .rodata would cross a page
     boundary mid-section. What happens?
</pre>
                </div>
                <p>Exercise 3 is the one that teaches the most, because it is where the interaction between &ldquo;the address you wrote&rdquo; and &ldquo;the address you got&rdquo; becomes visible as arithmetic. <strong>You wrote 0x400123, and something rounded it &mdash; and the only way to know which line did it is to read the script looking for a rounding.</strong> That is the whole skill this concept teaches: <em>when a number is not the number you wrote, the script has a line that adjusted it, and it is either an <code>ALIGN</code> or an <code>sh_addralign</code> the linker applied for you.</em></p>
                <p>Exercise 5 is the one that shows why the <code>ALIGN</code>s are load-bearing rather than tidy. On a hosted Linux target the loader is forgiving enough that removing them often appears to work &mdash; the kernel rounds mappings up for you. <strong>On the targets the alignment is actually for, it does not.</strong> That is the honest limitation of measuring a requirement on a platform that papers over it, and it is why the script has the <code>ALIGN</code>s in it regardless of what Linux tolerates.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the first placement concept, and it answers the question <a href="/courses/link/lessons/link-order">the ordering concept</a> set up: the dot says <em>where the output section starts</em>, rule order says <em>who is at the start</em>, and the two are independent. The 0x900000-versus-0x9000f0 gap at the top of this page is the first phenomenon; the 240 bytes after it is the second. <strong>Conflating them is the mistake, and it is the one that produces scripts which work until the input changes.</strong></p>
                <p>The connection to the <a href="/courses/elf/lessons/memory-mapping">ELF course's memory-mapping concept</a> is the mechanism behind the <code>ALIGN</code>s, and it is the same mechanism the ELF course measured rather than asserted. A <code>PT_LOAD</code> is mapped a page at a time; a page has one set of permissions; therefore each loadable segment must begin on a page boundary. <strong>That is not a linker convention, it is a consequence of how a kernel maps a file into an address space</strong>, and it is the clearest example in the course of a file-format constraint that exists because of an operating-system implementation detail.</p>
                <p>And the <code>ALIGN</code>-plus-offset expression for the rodata segment connects straight back to the Relocations course, which is the payoff. <a href="/courses/reloc/lessons/reloc-encoding-limits">The Limits That Shaped the Table</a> established that a PC-relative displacement is a signed 32-bit field and therefore reaches &plusmn;2GB, and that a reference which does not fit needs a jump stub. <strong>This concept is where that budget is spent.</strong> Page-aligning the read-only data segment pushes every code-to-data distance up by up to a page; doing it naively in a large program spends megabytes of a 2GB budget for no reason, and the linker authors added <code>+ (. &amp; (MAXPAGESIZE - 1))</code> specifically to stop that. A relocation-format limit, discovered at link time, mitigated by an expression in a script &mdash; that is the chain working as intended.</p>
                <p>Forward within the module, the dot is the mechanism and the next two concepts are about constraining it. <a href="/courses/link/lessons/link-memory-regions">MEMORY Is a Budget</a> gives the dot a <em>limit</em>: regions with an <code>ORIGIN</code> and a <code>LENGTH</code>, and an overflow that fails the link rather than silently overlapping. <a href="/courses/link/lessons/link-phdrs">PHDRS and the -T Surprise</a> is about the other half &mdash; where the sections go is only half a program header table, and the script has to say which segments exist at all.</p>
                <p>One connection outward, for the hardware framing that keeps recurring in this course. The three addresses in the last experiment are all in the low 4GB, and that is not an accident of the numbers I chose. <a href="/courses/reloc/lessons/pie-randomize">Does the Executable Actually Move?</a> measured a PIE loaded at 0x631601ffb140 &mdash; in the high half of the address space &mdash; and explained that the low 32GB are kept free for shared libraries. <strong>A script that pins the image at 0x400000 is spending the other half of a 64-bit address space to get a layout a human wrote down, and the two approaches are not equally free.</strong> The PIE pays a relocation and an indirection per global; the script pays a fixed address and a <code>&plusmn;2GB</code> budget it has to stay inside. Neither is a default; they are two answers to the same question, and the linker script is the older one.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/link/lessons/link-order">Previous: Which Rule Wins</a></span>
                <span>Next: <a href="/courses/link/lessons/link-memory-regions">MEMORY Is a Budget</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
