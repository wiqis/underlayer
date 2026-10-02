// Static Linking and Linker Scripts — Module 4: Static, and Build One
// Concept: generate a script, place the binary, verify the result, run it.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_link_write_script() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Writing One Yourself — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson link-lesson">
            <a href="/courses/link" class="back-link">Back to course</a>
            <h1>Writing One Yourself</h1>
            <div class="lesson-meta">26 min &middot; Module 4: Static, and Build One &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Nine concepts of reading, and this one writes. The tool is <code>linklab.py</code>, in this course&rsquo;s sample directory, and it is deliberately shaped around the three things the course established rather than around convenience:</p>
                <div class="formula">
  1. A LINKER SCRIPT IS A PROGRAM YOU CAN EDIT.
     So get the source first, with ld --verbose, and
     edit a copy. Never maintain a fork from memory.

  2. ITS EFFECT IS CHECKABLE, NOT ASSUMED.
     So every subcommand VERIFIES its own result and
     prints PASS or FAIL. A driver that only printed
     the linker's output would teach nothing the
     linker does not already print.

  3. THE LINKER WILL NOT TELL YOU YOUR EDIT DID
     NOTHING. So VERIFY THE EDIT, before linking.

                </div>
                <p>Point 3 is the one that came from a scar. During the writing of this course, two separate measurements produced right-sized but wrong files, and both were caught only by comparing bytes or by checking the generated script actually contained what it was supposed to. <strong>That is now a standing assertion in the build script and the crosscheck</strong>, and it is the first thing <code>linklab.py</code> does when you ask it to move a binary.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The tool, and what each subcommand demonstrates.</p>
                <div class="hex-dump">
                    <pre>$ python3 linklab.py
  show      print the default linker script ld is using
  base      move the whole binary to an address,
            verify, and RUN it
  budget    a MEMORY script with a real, enforced budget
  order     the four-cell first-match-wins experiment
  gc        reachability with and without --gc-sections
  tour      all of the above, each step verified
</pre>
                </div>
                <p>Every one of those is a concept in this course, expressed as an operation that ends in a <code>PASS</code> or a <code>FAIL</code>. The interesting part is what each one has to check, because <strong>the check is the content</strong>:</p>
                <div class="formula">
  base     the edit changed 2 occurrences, and we
           say so -- because 0 would mean the default
           script changed shape and we would be
           silently doing nothing.

           then: did the link succeed? is the first
           PT_LOAD at the address we asked for? is the
           e_type EXEC? DOES IT RUN?

           and the last one is not decoration. a script
           is a claim about the machine, and the machine
           gets a vote.

  budget   does LENGTH=4M link? did .text land at the
           rom ORIGIN? did the NON-allocated sections
           stay at 0?

           then LENGTH=64: does it REFUSE, does the
           error name the region, and does it say by
           how many bytes?

  order    the four cells, and it prints each result
           before judging them, so a wrong conclusion
           is visible rather than summarised.

                </div>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>The whole tour, verbatim:</p>
                <div class="hex-dump">
                    <pre>$ python3 linklab.py tour

=== linklab: a linker script is a program ===

The script ld is using right now is 276 lines long.

Move the whole binary to 0x3000000
   replaced 2 occurrence(s)
   PASS link succeeded
   PASS first PT_LOAD is at 0x3000000
   PASS e_type is EXEC (a script implies a fixed model)
   PASS and the program RUNS at that address (exit 0)
   PASS some PT_LOAD is marked executable
   PASS and it is at or above the first load (headers come first)

A MEMORY script with a 4M budget
   PASS LENGTH=4M links
   PASS   .text landed at the rom ORIGIN
   PASS   and non-allocated sections stayed at 0
   PASS LENGTH=64 refuses the link
   PASS   and the error names the region
   PASS   and says by how much

Which rule wins? Four cells, and the answer is not what I expected
   keep only              .labnote kept: True
   discard only           .labnote kept: False
   keep FIRST, discard 2nd .labnote kept: True
   discard 1st, keep 2nd  .labnote kept: False
   PASS first-match-wins in all four cells
   so /DISCARD/ is NOT special: in cell 3 it is simply the last
   rule, and in cell 4 simply the first.

--gc-sections is reachability, not liveness
   -O1 --gc-sections off      lab_* survivors: lab_also_dead lab_dead lab_used  .text=0x123
   -O1 --gc-sections on       lab_* survivors:                              .text=0xf3
   -O0 --gc-sections off      lab_* survivors: lab_also_dead lab_dead lab_used  .text=0x152
   -O0 --gc-sections on       lab_* survivors: lab_used                     .text=0x122
   PASS at -O1 the collector removed lab_used
   PASS at -O0 the collector KEPT lab_used
   the only difference is inlining: at -O1 main folds lab_used(41) to 42,
   so the out-of-line copy has no caller.
   PASS and .text shrank by exactly the collected functions (0x30)

Every step verified.
</pre>
                </div>
                <p><strong>Twenty checks, all green, from a directory containing two files.</strong> And notice the two <code>PASS</code> lines that are really about the tool rather than the linker: &ldquo;the program RUNS at that address&rdquo; and &ldquo;some <code>PT_LOAD</code> is marked executable&rdquo;. The first existed because the tool initially asserted the <em>first</em> load was executable, which is wrong &mdash; the first load is the read-only ELF headers. The check caught its own author.</p>
                <p>Now the exercise, and it is a real one rather than a demonstration. Write a script from an empty file:</p>
                <div class="hex-dump">
                    <pre>$ printf '/* mine */\n' &gt; mine.ld
$ clang -O1 hello.o -o out -T mine.ld
ld.bfd: out: error: PHDR segment not covered by LOAD segment
</pre>
                </div>
                <p>Add <code>OUTPUT_FORMAT</code> and <code>ENTRY</code>, and link again &mdash; the next complaint is about your sections, not the headers. Add a <code>SECTIONS</code> block with <code>.text</code> only, and it links and runs. Then one section at a time:</p>
                <div class="hex-dump">
                    <pre>  . = 0x400000 + SIZEOF_HEADERS;
  .text   : { *(.text .stub .text.*) }
  .rodata : { *(.rodata .rodata.*) }
  .data   : { *(.data .data.*) }
  .bss    : { *(.bss  .bss.* ) }
</pre>
                </div>
                <p><strong>Eleven lines, and it is a complete, working linker script for a hosted Linux program</strong> &mdash; smaller than a tenth of the default, and every line in it is one you chose. The exercise is to reach that file from an empty one by letting the linker&rsquo;s errors tell you what is missing.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The difference between a script you wrote and a script you understand, expressed as one experiment. Add a section to your program that your script does not name:</p>
                <div class="hex-dump">
                    <pre>  /* four sections named. add a fifth. */

  __attribute__((section(".mystuff"), used))
  static int mine[4] = {1,2,3,4};
  int get_mine(int i){ return mine[i &amp; 3]; }

  $ clang -O1 -T mine.ld hello.o -o out
  $ ./out; echo "exit=$?"
  exit=0                       &lt;-- IT WORKS. and that is the problem.

  $ readelf -SW out | grep mystuff
  [15] .mystuff  PROGBITS  0000000000900f0 ... 00  A  0  0  8

  ^ the orphan fallback placed it, at the END of
    everything your script placed. it ran because
    nothing was wrong yet.
</pre>
                </div>
                <p><strong>It works, which is exactly what makes it dangerous.</strong> The section is allocated, its address is valid, the program reads the right values, and there is no diagnostic. Now turn on the one mechanism that would have caught it:</p>
                <div class="hex-dump">
                    <pre>  $ clang -O1 -T mine.ld hello.o -o out -Wl,--orphan-handling=warn 2&gt;&amp;1
  warning: orphan section `.mystuff' from `hello.o' being placed
  in section `.mystuff'

  $ clang -O1 -T mine.ld hello.o -o out -Wl,--gc-sections -Wl,--orphan-handling=warn
  warning: orphan section `.mystuff' from `hello.o' being placed
  in section `.mystuff'
  $ ./out; echo "exit=$?"
  exit=139                    &lt;-- SEGFAULT
</pre>
                </div>
                <p><strong>Add <code>--gc-sections</code> and the program now crashes.</strong> Because <a href="/courses/link/lessons/link-orphans">the orphan fallback</a> and <a href="/courses/link/lessons/link-keep-gc">garbage collection</a> interact: the fallback placed the section, but the reachability walk did not mark it live, and <code>--gc-sections</code> removed it. <strong>Two features that each work correctly, composing into a failure</strong> &mdash; and the fix is one line:</p>
                <div class="hex-dump">
                    <pre>  .mystuff : { KEEP (*(.mystuff)) }
                               ^^^^^
  and now both mechanisms agree: your script owns the
  section, it is placed where you said, and it survives.
</pre>
                </div>
                <p><strong>That composition is the most useful thing in this concept</strong>, because it is the shape of real linker-script bugs. You will not be handed a script that is missing a section and a build with <code>--gc-sections</code> on the same day on purpose; you will add the section in March, and somebody will add the flag in September, and the program will start crashing in a build that nobody touched. <strong>Neither change was wrong. The composition was.</strong> And a one-line script that names and <code>KEEP</code>s the section makes the class impossible.</p>
                <p>Which is the argument for owning your script. The default script would have handled the section by the fallback, and the fallback and <code>--gc-sections</code> would have disagreed in exactly the same way &mdash; so <strong>the danger is not having a custom script, it is having an implicit one</strong>. A script you wrote is a script you can read.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/link/assets/samples
$ python3 linklab.py tour
$ python3 linklab.py base 0x2000000
$ python3 crosscheck.py
  ALL 124 CHECKS PASS
</pre>
                </div>
                <p>Then extend the tool, which is the exercise rather than the demonstration:</p>
                <div class="hex-dump">
                    <pre>  1. Add a `stack` subcommand that puts .bss at a
     fixed address with a KEEP, using a MEMORY region.
     Then check that the section really is there, not
     just that the link succeeded.

  2. Add a `probe` subcommand that reads any
     SEGMENT_START or CONSTANT out of a script and
     prints it. It needs the -u trick from the first
     concept -- PROVIDE is conditional, so a symbol
     nothing references is never emitted. Verify the
     -u is in there before you wonder why it prints 0.

  3. Add a `diff` subcommand: dump two scripts and
     show only the lines that differ. This is the tool
     you actually want when a build changes size and
     you do not know why, and it is about fifteen lines.

  4. Make `order` print a warning if any of its four
     generated scripts does NOT contain the rule it is
     supposed to. That check is the direct descendant of
     the bug that made this course briefly claim
     /DISCARD/ overrides rule order -- a no-op string
     replace looks exactly like a linker obeying you.

  5. Finally, and this is the real test: delete
     build_samples.sh, keep the three scripts, and check
     that crosscheck.py still passes from an empty
     directory. It should not -- the specimens are
     generated -- which tells you exactly which files are
     sources and which are products. Knowing that about
     your own build is the same skill.
</pre>
                </div>
                <p>Exercise 3 is the one that becomes useful immediately and forever. <strong>A diff of two linker scripts is the fastest way to answer &ldquo;why did my binary get 4 KB bigger&rdquo; when you cannot remember what you changed</strong> &mdash; and it works because both scripts are text, which is the property that made this course possible. Before <code>ld --verbose</code> existed as a workflow, that question had exactly one answer, which was &ldquo;read the linker source&rdquo;.</p>
                <p>Exercise 4 is the one that makes the tool trustworthy, and it is deliberately placed here rather than earlier. <strong>A tool that generates inputs must verify the inputs it generated</strong>, because the failure mode of a no-op edit is indistinguishable from correct behaviour. That is a lesson about verification rather than about linkers, and it is the one that has bitten this course twice.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the end of the course, and it is the concept that makes the other nine into a skill rather than knowledge. <a href="/courses/link/lessons/link-default-script">The script is source you can read</a>; <a href="/courses/link/lessons/link-script-language">eight constructs</a>; <a href="/courses/link/lessons/link-order">first-match-wins</a>; <a href="/courses/link/lessons/link-location-counter">the dot</a>; <a href="/courses/link/lessons/link-memory-regions">budgets</a>; <a href="/courses/link/lessons/link-phdrs">segments, and the <code>-T</code> trap</a>; <a href="/courses/link/lessons/link-keep-gc">reachability and <code>KEEP</code></a>; <a href="/courses/link/lessons/link-orphans">the fallback</a>; <a href="/courses/link/lessons/link-static-real">what static costs</a>. <strong>And now a tool that does all of it and checks the answer.</strong></p>
                <p>The chain this course sits in is almost complete, and it is worth seeing where each piece ended up. The <a href="/courses/obj">Object Files</a> course established what a relocation record is and, at the end, wrote a 936-byte ELF object byte by byte. The <a href="/courses/sym">Symbol Resolution</a> course established who decides what a name means, and traced the map file. The <a href="/courses/reloc">Relocations</a> course established the vocabulary and wrote a relocation applier that accepted a <em>layout</em> as input and said so in a comment. <strong>This course is that comment's subject.</strong> <code>apply_relocs.py</code> had a <code>build_layout()</code> function and a note that deciding the layout is &ldquo;a different program with a much harder problem&rdquo; &mdash; and a linker script <em>is</em> that program, written in a language with eight constructs and no control flow.</p>
                <p>The next link in the chain is <a href="/courses/link/lessons/link-write-script">the one this course hands on</a>, and it is not another course. <strong>It is a thing you can run.</strong> <code>linklab.py</code> is 250 lines, needs nothing but a compiler and <code>ld</code>, and every subcommand ends in a verdict. If the mission of the collection is a learner who can build a compiler that targets any architecture and emits executables without a backend, then this is one of the small pieces of that: a placement engine you can read end to end and change, driving a real linker and verifying the result by running it.</p>
                <p>Three debts the earlier courses left, settled here. <strong>The <code>-. != 0</code> conditional inside <code>.bss</code></strong> from <a href="/courses/link/lessons/link-location-counter">the location-counter concept</a> is a real unsolved question with a two-line answer written after it &mdash; which is what ordinary source code looks like, and worth knowing that the toolchain is ordinary. <strong>The <code>PROVIDE</code> conditionality</strong> from <a href="/courses/sym/lessons/sym-linker-defined">the linker-defined symbols concept</a> is the <code>-u</code> trick, and it is now a documented feature of the tool rather than a surprise. And <strong>the <code>map file</code></strong> from <a href="/courses/sym/lessons/sym-algorithm">the resolution algorithm concept</a> is where the linker records every decision this course makes about placement, including the ones it guessed &mdash; which makes it the tool you reach for when any of this has gone wrong in a build you did not write.</p>
                <p>And the last connection, to the platform you are reading this on. The Underlayer server is built with this toolchain, in Chemical, and it serves these pages. <a href="/courses/link/lessons/link-phdrs">Module 2&rsquo;s finding</a> &mdash; that <code>-T</code> overrides the code model &mdash; is a fact that applies to the binary running right now, and the fact that you can read the script driving it is a property of the toolchain, not of the language. <strong>Nothing prevents the same inspection here</strong>: the server is an ELF file, <code>ld --verbose</code> is one command, and the 276 lines that placed it are readable. That is the through-line of the whole collection, and it is not a metaphor.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/link/lessons/link-static-real">Previous: What -static Actually Does</a></span>
                <span>End of course &middot; <a href="/courses/link">back to the course page</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
