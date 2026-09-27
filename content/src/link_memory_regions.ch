// Static Linking and Linker Scripts — Module 2: Placing Things
// Concept: MEMORY regions, and turning a silent overlap into a link error.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_link_memory_regions() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("MEMORY Is a Budget — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson link-lesson">
            <a href="/courses/link" class="back-link">Back to course</a>
            <h1>MEMORY Is a Budget</h1>
            <div class="lesson-meta">20 min &middot; Module 2: Placing Things &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Here is a complete linker script, and it is a shape you will meet in firmware, in kernels, and in anything that has to know where it lives in physical memory:</p>
                <div class="hex-dump">
                    <pre>MEMORY {
  rom (rx) : ORIGIN = 0x08000000, LENGTH = 1M
  ram (rw) : ORIGIN = 0x20000000, LENGTH = 8M
}
SECTIONS {
  .text : { *(.text .text.*) } &gt; rom
  .data : { *(.data .data.*) } &gt; ram
  .bss  : { *(.bss  .bss.* ) } &gt; ram
}
</pre>
                </div>
                <p>Two regions, four attributes between them, and one operator (<code>&gt; rom</code>) that says which region each output section is spending from. It links, and the result is at 0x08000000:</p>
                <div class="hex-dump">
                    <pre>$ ld -T mem.ld -o mem.out hello.o -e helper
$ readelf -SW mem.out | sed -n 's/^ *\[[ 0-9]*\] *\(\.text\|\.data\).*/  \1/p' | head -2
  .text
$ readelf -SW mem.out | awk '/ \.text /{print "  .text addr = "$4}'
  .text addr = 0000000008000000
$ readelf -hW mem.out | awk '/Entry/{print "  entry     = "$4}'
  entry     = 8000000
</pre>
                </div>
                <p><strong>It works, and the reason it works is not that the linker obeyed an address.</strong> <code>ORIGIN = 0x08000000</code> is a number, but nothing in the script asked for that address. The linker was told &ldquo;there is a region starting here, one megabyte long&rdquo; and asked to put <code>.text</code> in it. The address is a consequence of the budget, not an instruction.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>What a region is, in one sentence, and the four letters in parentheses.</p>
                <div class="formula">
  A REGION is a named range of addresses with a size,
  and (optionally) a set of attributes.

  MEMORY ...
    name (attrs) : ORIGIN = start, LENGTH = size

  (brace-delimited; braces are legal in a script and
   illegal in this box, so "..." stands for them here
   and they are quoted for real in the dumps above)

  ATTRS are a HINT to the linker, not a setting:
    (rx)  read + execute
    (w)   write
    (r)   read
    (!x)  explicitly NOT execute

  and they are a hint because the linker will not
  enforce them. put .text in a (w) region and you get
  a warning at most.

  THE OPERATOR
    .text : RULES &gt; rom        spend from rom
    .text : RULES &gt; rom AT&gt;    spend from rom AND
                                make a new segment
                                (RULES = the brace-delimited
                                 list of input patterns)
    &gt; rom AT&gt; ram             ...in a different one

  without a &gt;, a section belongs to NO region, and
  the region LENGTH does not constrain it at all.

                </div>
                <p><strong>That last line is the one that matters and almost nobody knows it.</strong> A <code>MEMORY</code> block on its own constrains nothing. It is a set of ranges; sections only get checked against them if you write <code>&gt; region</code>. A script with a <code>MEMORY</code> block and no operators is a script with a comment at the top.</p>
                <p>And the reason regions exist at all is worth stating, because it is not convenience:</p>
                <div class="formula">
  WHY A BUDGET

  on a hosted target, the linker chooses addresses
  and nothing can conflict, because the loader will
  remap. an overlap is impossible by construction.

  on a FIXED target -- firmware, a bootloader, a
  kernel -- there is no loader to remap anything. the
  addresses in the script ARE the addresses. so two
  things can be given the same address, and the
  hardware will not object. the CPU will fetch garbage
  and there is no diagnostic anywhere.

  a region turns that silent failure into a link
  error. it is the ONLY place in a link where the
  toolchain can tell you that your layout is wrong.

                </div>
                <p><strong>That is the real value, and it is easy to miss because on Linux the script &ldquo;just works&rdquo; either way.</strong> The enforcement is what you are buying, not the placement.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>The enforcement, which is the entire point. Same object, same script, one number changed:</p>
                <div class="hex-dump">
                    <pre>$ cat tiny_mem.ld &lt;&lt;'EOF'
MEMORY { rom (rx) : ORIGIN = 0x08000000, LENGTH = 64 }
SECTIONS { .text : { *(.text .text.*) } &gt; rom }
EOF
$ ld -T tiny_mem.ld -o tm.out hello.o -e helper
/usr/bin/x86_64-linux-gnu-ld.bfd: tm.out section `.eh_frame' will not fit in region `rom'
/usr/bin/x86_64-linux-gnu-ld.bfd: region `rom' overflowed by 24 bytes

$ sed 's/LENGTH = 64/LENGTH = 4M/' tiny_mem.ld &gt; big_mem.ld
$ ld -T big_mem.ld -o bm.out hello.o -e helper &amp;&amp; echo "linked"
linked
</pre>
                </div>
                <p><strong>Read the two lines of that error, because each one is doing a different job.</strong> The first names the <em>section</em> &mdash; <code>.eh_frame</code>, a section you did not mention in your one-line rule and did not know was being placed there. The second names the <em>region</em> and gives a <strong>byte count</strong>: 24 bytes over.</p>
                <p>A 64-byte region cannot hold the ELF headers, <code>.text</code>, and <code>.eh_frame</code>, and the linker says so precisely. <strong>This is the only diagnostic in a whole link that is about the script rather than about the symbols</strong>, and it is worth noticing what a plain link would have done: placed everything, overlapping nothing, and produced a binary that runs perfectly on this machine and is wrong on a device with 64 bytes of ROM.</p>
                <p>Two more behaviours worth measuring, because both are quiet:</p>
                <div class="hex-dump">
                    <pre>$ readelf -SW mem.out | awk '/ \.strtab| \.symtab| \.shstrtab/{print "  "$2" addr="$4}'
  .strtab  addr=0000000000000000
  .symtab  addr=0000000000000000
  .shstrtab addr=0000000000000000

  ^ sections that are NOT loaded into memory sit at
    address 0, and stay there. a region holds sections
    that will be MAPPED. debug sections, the symbol
    table, the string table -- none of those exist at
    run time, so ORIGIN has nothing to say about them.
    this is the same fact the default script states by
    writing `.debug_info 0 :` -- an address of 0 is a
    claim that a section is not in memory.
</pre>
                </div>
                <p>And the attribute claim, which is a hint and not a setting:</p>
                <div class="hex-dump">
                    <pre>$ cat wrong.ld &lt;&lt;'EOF'
MEMORY { rw (w) : ORIGIN = 0x08000000, LENGTH = 1M }
SECTIONS { .text : { *(.text .text.*) } &gt; rw }
EOF
$ ld -T wrong.ld -o wrong.out hello.o -e helper 2&gt;&amp;1 | head -3
$ echo "exit=$?"
exit=0                       &lt;-- no diagnostic at all
$ readelf -lW wrong.out | grep '^  LOAD'
  LOAD  0x001000 0x0000000008000000 ... R E 0x1000
                                     ^^^ R E, NOT R W E

$ # the same script with (rx) instead:
$ readelf -lW right.out | grep '^  LOAD'
  LOAD  0x001000 0x0000000008000000 ... R E 0x1000
                                     ^^^ identical
</pre>
                </div>
                <p><strong>Two results, and the second is the one I did not expect.</strong> The first is unsurprising: <code>.text</code> in a region marked <code>(w)</code> produces no diagnostic whatsoever. The second is that changing the attribute from <code>(w)</code> to <code>(rx)</code> changed <em>nothing</em> &mdash; both builds produced the same <code>R E</code> segment.</p>
                <p>So in GNU ld 2.46 the region attributes are, in this measurement, <strong>completely inert</strong>: they did not reject the mismatch, and they did not influence the program header flags either. The flags came from the <em>section</em>, not the region. <strong>A script that relies on <code>(rx)</code> to keep code out of a writable segment is relying on a field that, here, did nothing at all</strong> &mdash; and the safe thing is to treat the attributes as documentation for the reader rather than as an input to the linker.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The <code>AT&gt;</code> operator, which solves a problem that appears the moment you have two regions and one of them is not address zero.</p>
                <div class="hex-dump">
                    <pre>  MEMORY {
    rom (rx) : ORIGIN = 0x08000000, LENGTH = 1M
    ram (rw) : ORIGIN = 0x20000000, LENGTH = 8M
  }
  SECTIONS {
    .text : { *(.text .text.*) } &gt; rom
    .data : { *(.data .data.*) } &gt; ram AT&gt; rom
  }

  the two addresses are DIFFERENT and they are both
  correct:

    VMA  where the section is when the CPU runs it.
         for .data, 0x20000000 -- because that is where
         the RAM is and the CPU can only reach RAM.

    LMA  where the section's BYTES live in the file.
         for .data, 0x08000000+ -- because the bytes
         have to be stored in the flash image, and the
         flash is what the CPU boots from.

  a bootloader copies from the LMA to the VMA at
  startup. AT&gt; is how the script tells it where to
  copy FROM, and the address it writes into the binary
  is the VMA because that is what the running program
  needs.
</pre>
                </div>
                <p><strong>Two addresses for one section is the whole reason <code>AT&gt;</code> exists</strong>, and it is a genuinely different idea from anything else in the script language: a section is not a thing, it is a mapping between a file offset and an address, and on a fixed target those are allowed to disagree.</p>
                <p>Where you see it in practice, and it is a reliable marker of a real firmware build:</p>
                <div class="hex-dump">
                    <pre>  __data_load = LOADADDR(.data);
  __data_start = ADDR(.data);

  and at startup, in C:

    extern uint32_t __data_load, __data_start, __data_end;
    uint32_t *src = &amp;__data_load, *dst = &amp;__data_start;
    while (dst &lt; &amp;__data_end) *dst++ = *src++;

  LOADADDR() and ADDR() are script FUNCTIONS that become
  linker-defined SYMBOLS. the script computes two numbers
  and the C code reads them. that is the interface, and
  it is the same PROVIDE mechanism the
  <a href="/courses/sym/lessons/sym-linker-defined">symbol course</a> covered.
</pre>
                </div>
                <p>And the pattern that catches people: a script with <code>MEMORY</code> and no <code>AT&gt;</code> puts initialised data in RAM, and the RAM contents are <em>whatever was there at reset</em>, not your initialisers. The program starts, runs, and reads zeroes or garbage &mdash; and nothing warns you, because from the linker's point of view the layout is perfectly legal. <strong><code>AT&gt;</code> is not an optimisation. It is the difference between a linker script that works and one that produces a device that boots to a random number.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/link/assets/samples
$ ./build_samples.sh 2&gt;&amp;2 | sed -n '/F7/,/F8/p'
$ python3 crosscheck.py 2&gt;&amp;2 | sed -n '/\\[7\\]/,/\\[8\\]/p'
$ python3 linklab.py budget 4M
</pre>
                </div>
                <p>Then find the boundary, which is more interesting than it sounds:</p>
                <div class="hex-dump">
                    <pre>  1. Bisect LENGTH. Start at 1M, halve it, keep
     halving until the link fails. What is the exact
     size at which this object stops fitting, and how
     does that compare to .text + .eh_frame + headers?
     (Use readelf -SW on a build that DID fit.)

  2. Add a section to your rule that you did not
     measure, and watch the error name it. Then
     exclude it with EXCLUDE_FILE and watch the error
     change name. (The error tells you what it could
     not place, which is a free list of what your script
     did not account for.)

  3. Write a MEMORY block with THREE regions, and
     give two of them the same ORIGIN. Does ld object?
     If not, what happens when a section is assigned
     to each?

  4. Set (w) on a region and put .text in it. Does the
     linker object? Then change it to (rx) and compare
     the program header flags of the two builds. (The
     measured answer is on this page: no diagnostic, and
     IDENTICAL flags. Find out whether the attributes
     do anything at all, or whether the flags came from
     the section.)

  5. Add AT&gt; to your .data rule and re-read the
     binary. What are the VMA and the LMA? Which one
     appears in the section header, and where does the
     other one appear?
</pre>
                </div>
                <p>Exercise 2 is the one that pays, and for a reason that is not obvious until you run it. <strong>The overflow error is a list of the things your script did not account for</strong>, and it is the closest thing a linker has to a warning about incomplete layout. A script that has been linking for months and has never overflowed a region may simply have generous regions; try a tight one and it will tell you, in section names, exactly what it had to place.</p>
                <p>Exercise 4 has an answer that corrected a claim this page originally made. The obvious story is that the attributes drive the program header flags &mdash; <code>(rx)</code> gives <code>R E</code>, <code>(w)</code> gives <code>R W</code> &mdash; and that is certainly how they are <em>documented</em> to be read. <strong>Measured, they are inert</strong>: <code>.text</code> in a <code>(w)</code> region produced the same <code>R E</code> segment as <code>.text</code> in an <code>(rx)</code> region, and neither produced a diagnostic. The flags came from the section. The correction is above rather than deleted, because &ldquo;the documentation says X and the measurement says not-X&rdquo; is exactly the kind of thing a learner needs to see handled rather than hidden.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the second placement concept and it is the one that turns placement from a description into a <em>constraint</em>. <a href="/courses/link/lessons/link-location-counter">The Location Counter</a> gave you a variable with a value; this gives it a maximum. <strong>Together they are the difference between saying where something goes and saying what happens if it does not fit</strong> &mdash; and the second is the only one that catches a mistake.</p>
                <p>The connection to the <a href="/courses/elf/lessons/segment-types">ELF course's segment-types concept</a> is the <code>AT&gt;</code> operator, and it is a genuine gap that concept could not fill. <code>p_vaddr</code> and <code>p_paddr</code> are two different fields in a program header, and on every hosted target they are equal, so there is nothing to learn about them from a Linux binary. <strong><code>AT&gt;</code> is the one place where a real difference between them is expressed, and it is expressed in a linker script.</strong> Two addresses for one section is a real capability of the format that a course built on Linux examples cannot demonstrate, and a script is the only place it appears.</p>
                <p>The strongest connection is forward, and it is about enforcement rather than placement. <a href="/courses/link/lessons/link-phdrs">PHDRS and the -T Surprise</a> is about the other half of what a script controls: not which sections go where, but which <em>segments</em> exist. <code>&gt; region</code> picks a region and, with <code>AT&gt;</code>, a segment. <code>PHDRS</code> names the segments outright. <strong>Together they are the two ways a script says &ldquo;this is how memory is laid out&rdquo;, and the difference is that regions constrain and PHDRS describes.</strong></p>
                <p>And there is a connection back to a course you have already finished that reframes something in it. <a href="/courses/sym/lessons/sym-algorithm">The Algorithm, Measured</a> established that GNU ld resolves symbols in a demand-driven pass and that a wrong answer produces <em>no diagnostic</em> &mdash; a working binary with a wrong number in it. <strong>This concept is the same shape of failure and the same shape of defence.</strong> An unconstrained layout overlaps silently on a device and produces garbage at run time; a constrained one fails the link and names the section. Neither the resolution pass nor a plain link can tell you your layout is wrong, because as far as the linker is concerned it is not. <code>MEMORY</code> is the only mechanism in the toolchain that turns that class of bug into a message, and it is worth knowing that the safety net exists and is opt-in.</p>
                <p>One connection outward, for the hardware framing. The <code>ORIGIN = 0x08000000</code> in the example is a real convention: on STM32-family parts, flash is mapped at 0x08000000 and SRAM at 0x20000000. <strong>Those are not linker script choices; they are what the chip's memory map says.</strong> A script that puts <code>.text</code> anywhere else on such a part produces a binary that flashes cleanly and does not boot, and no tool on the machine can tell you &mdash; because the correctness of the address is a property of the silicon, and no part of the toolchain has been told what the silicon is. That is the honest limit of what a linker script can be verified against, and it is why this concept's experiments all run on a hosted target and say so.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/link/lessons/link-location-counter">Previous: The Location Counter</a></span>
                <span>Next: <a href="/courses/link/lessons/link-phdrs">PHDRS and the -T Surprise</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
