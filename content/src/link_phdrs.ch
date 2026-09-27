// Static Linking and Linker Scripts — Module 2: Placing Things
// Concept: writing program headers by hand, and the flag that silently changes
// your output type.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_link_phdrs() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("PHDRS and the -T Surprise — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson link-lesson">
            <a href="/courses/link" class="back-link">Back to course</a>
            <h1>PHDRS and the -T Surprise</h1>
            <div class="lesson-meta">22 min &middot; Module 2: Placing Things &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Everything so far has been about <em>sections</em>: which input sections go into which output section, and where. A linker script also controls the <em>segments</em>, and that is a different table in a different part of the file, written by a different command.</p>
                <p>Here is a script that builds a complete executable and says so explicitly:</p>
                <div class="hex-dump">
                    <pre>PHDRS {
  code PT_LOAD FLAGS(5);
  data PT_LOAD FLAGS(6);
}
SECTIONS {
  .text 0x08000000 : { *(.text .text.*) } :code
  .data 0x20000000 : { *(.data .data.*) } :data
}
</pre>
                </div>
                <p>Two commands, and they are the whole of segment control. <code>PHDRS</code> <em>declares</em> the segments that will exist. The <code>:code</code> and <code>:data</code> at the end of each rule <em>assign</em> sections to them. <strong>And <code>FLAGS(5)</code> is not a mnemonic: it is the literal <code>p_flags</code> bitmask, where <code>PF_X = 1</code> and <code>PF_W = 2</code>.</strong> 5 is <code>R|X</code>. 6 is <code>R|W</code>.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Why there are two tables at all, and what each one is actually for.</p>
                <div class="formula">
  SECTIONS   the LINKER's view. a partition of the
             input, with addresses. this is what a
             linker computes.

  PROGRAM    the KERNEL's view. what to mmap, with
  HEADERS    what permissions, and where in the file
             the bytes are.

  a hosted ld INVENTS the program headers: it looks at
  the output sections, works out which can share a
  mapping, and emits PT_LOADs. you never see that.

  PHDRS turns the invention off. you list the segments,
  and the linker emits exactly those. which is what
  you need when the layout is not the usual one -- a
  bootloader, a kernel, anything where the segments
  have to be exactly as written.

                </div>
                <p><strong>So <code>PHDRS</code> is not an optimisation. It is a handover.</strong> It is the point where you stop describing sections and start telling a program that has never seen your script what to map into memory. The <a href="/courses/elf/lessons/segment-types">ELF course</a> taught what a <code>PT_LOAD</code> is; this is where you write one.</p>
                <div class="formula">
  THE FULL FORM

  PHDRS ...
    name type [ FILEHDR PHDRS ] [ FLAGS(n) ]
          [ AT ( address ) ] [ ALIGN(n) ] [ SIZE(n) ]

  (the block is brace-delimited; braces are legal in a
   script and illegal in this box, so they are written
   "..." here and quoted for real in the dump above)

  FILEHDR  include the ELF header in this segment
  PHDRS    include the program header table itself
           (this is why a tiny script needs it: if no
            segment covers the headers, you get
            "PHDR segment not covered by LOAD segment")
  FLAGS    the p_flags bits
  AT       give the segment its own address
  ALIGN    the segment's p_align
  SIZE     an explicit size

                </div>
                <p>That <code>PHDRS</code> keyword is worth pausing on, because it explains an error you will otherwise hit within an hour of writing a minimal script. <strong>Without a segment that covers the program header table, the file is malformed</strong> &mdash; the kernel reads the headers to find out where the headers are.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>Two segments requested, two segments delivered, at the addresses requested:</p>
                <div class="hex-dump">
                    <pre>$ ld -T ph.ld -o ph.out hello.o -e helper
$ readelf -lW ph.out | sed -n '/^  LOAD/p'
  LOAD  0x001000 0x0000000008000000 0x0000000008000000 0x000058 0x000058 R E 0x1000
  LOAD  0x0000b0 0x0000000000000000 0x0000000000000000 0x000000 0x000000 RW  0x1000
</pre>
                </div>
                <p><strong>One <code>R E</code> at 0x80000000 and one <code>RW</code> at zero, exactly as declared.</strong> Note that the second is empty &mdash; <code>hello.o</code> has no <code>.data</code>, so the segment has nothing in it. The linker emitted it anyway, because <code>PHDRS</code> says the segment exists. <strong>You asked for two, you got two, and one of them is a segment with no contents.</strong></p>
                <p>That is the honest difference between a script that lists segments and one that lets the linker invent them, and it is worth making explicit: <strong>with <code>PHDRS</code> the segment list is a specification, not a summary.</strong> The default script has no <code>PHDRS</code> block at all and produces fourteen program headers for a trivial program, every one of them inferred.</p>
                <p>Now the part of this concept that will actually cost you an afternoon, and it is not about <code>PHDRS</code> at all:</p>
                <div class="hex-dump">
                    <pre>$ for args in "-fPIE -pie" "-fPIE -pie -T default.ld" "-fPIE -T default.ld -pie"; do
    clang -O1 $args hello.o -o pie.out
    printf "  %-28s e_type=%-5s first LOAD=%s\n" "$args" \
      "$(readelf -hW pie.out|sed -n 's/.*Type: *\([A-Z]*\).*/\1/p')" \
      "$(readelf -lW pie.out|awk '/LOAD/{print $3;exit}')"
  done

  -fPIE -pie                   e_type=DYN   first LOAD=0x0000000000000000
  -fPIE -pie -T default.ld     e_type=EXEC  first LOAD=0x0000000000400000
  -fPIE -T default.ld -pie     e_type=EXEC  first LOAD=0x0000000000400000
</pre>
                </div>
                <p><strong><code>-T</code> turns a PIE into a non-PIE, and the order of the flags does not matter.</strong> Not &ldquo;mostly ignores&rdquo; &mdash; overrides. <code>-fPIE -pie -T default.ld</code> and <code>-fPIE -T default.ld -pie</code> produce the same <code>ET_EXEC</code> at 0x400000, and putting <code>-pie</code> first does not help.</p>
                <p>This is the same effect that made the <a href="/courses/link/lessons/link-default-script">round trip</a> fail to reproduce a PIE build byte-for-byte, and it is the single most surprising property of <code>-T</code> I found. The reason is that the code model is not a linker <em>flag</em> at all on this target &mdash; it is inferred from what the script and the emulation describe:</p>
                <div class="formula">
  a script that lays the image out at a FIXED address
  is describing a non-relocatable output. ld takes the
  script as the statement of intent and sets e_type to
  ET_EXEC accordingly. -pie is not consulted, or is
  consulted and overridden.

  so the rule is:

    -pie and -T are not two ways to say the same
    thing. -pie asks for a relocatable output.
    -T asks the script to decide. and the default
    script decides EXEC.

  if you want a PIE from a script, the SCRIPT has to
  ask for it -- which is why a real PIE linker script
  names the DYN output format and sets up the segment
  structure itself.

                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The minimal script that does not work, and why &mdash; because the failure is the fastest way to learn what a linker script owes the format.</p>
                <div class="hex-dump">
                    <pre>$ printf '/* nothing but this */\n' &gt; empty.ld
$ clang -O1 hello.o -o out -T empty.ld
/usr/bin/x86_64-linux-gnu-ld.bfd: out: error: PHDR segment not covered
  by LOAD segment
clang: error: linker command failed with exit code 1
</pre>
                </div>
                <p><strong>The very first complaint, before it says anything about your sections, is about the program headers.</strong> That is the phase order from <a href="/courses/link/lessons/link-script-language">the language concept</a> showing up as an error message: ld tried to build the program header table, found that no segment covered it, and stopped. An empty script does not mean &ldquo;no headers&rdquo; &mdash; it means &ldquo;headers I cannot account for&rdquo;.</p>
                <p>Three ways to fix it, and the differences matter:</p>
                <div class="hex-dump">
                    <pre>  1. SAY IT

     PHDRS { headers PT_PHDR PHDRS; text PT_LOAD FLAGS(5); }
     SECTIONS { .text : { *(.text) } :text }
                                       ^ and add :headers
                                       ^ to something, or use
                                         FILEHDR PT_PHDR PHDRS
                                         on the LOAD

  2. DELEGATE

     SECTIONS {
       . = 0x400000 + SIZEOF_HEADERS;
       .text : { *(.text) }
     }

     no PHDRS block at all, so ld infers the headers
     as it normally does. THIS is what the eleven-line
     script does, and it links.

  3. EXTEND THE DEFAULT

     SECTIONS { .mytext : { *(.mytext) } }
     INCLUDE

     ^ and this DOES NOT WORK. INCLUDE with no argument
       is a syntax error in GNU ld 2.46:

     $ printf 'INCLUDE\n' &gt; justinc.ld
     $ ld -T justinc.ld ...
     ld.bfd:justinc.ld:0: syntax error

     THERE IS NO "extend the default script" MECHANISM.
     -T REPLACES it. the only way to extend is to
     save the default and edit the copy, which is what
     this course's build script does:

       ld --verbose | sed -n '/^====/,$p' | sed '1d;$d' > my.ld
</pre>
                </div>
                <p><strong>That last one is the practical lesson of this concept and it is worth internalising.</strong> There is no <code>INCLUDE</code>-the-default, no <code>--extend-script</code>, and no partial override. <code>-T</code> gives the script total authority over layout, which is exactly what you want for firmware and exactly what surprises people who expected an override mechanism.</p>
                <p>And because there is no extend mechanism, the round-trip identity from the first concept becomes the tool you actually want. Save <code>ld --verbose</code>, edit one number, and you have a script that is provably equivalent to the default except where you changed it:</p>
                <div class="hex-dump">
                    <pre>$ ld --verbose 2&gt;/dev/null | sed -n '/^====/,$p' | sed '1d;$d' &gt; default.ld
$ sed 's/SEGMENT_START("text-segment", 0x400000)/SEGMENT_START("text-segment", 0x800000)/g' \
      default.ld &gt; mine.ld
$ clang -O1 -fno-pie -no-pie hello.o -o a.out
$ clang -O1 -fno-pie -no-pie hello.o -o b.out -T mine.ld
$ cmp a.out b.out &amp;&amp; echo IDENTICAL
IDENTICAL
$ ./b.out; echo "  and it runs, exit=$?"
  and it runs, exit=0
</pre>
                </div>
                <p><strong>Identical to the default build, and running from the address you chose.</strong> That is the whole workflow for changing one thing about a link, and it is available because the linker ships its own program as text.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/link/assets/samples
$ ./build_samples.sh 2&gt;&amp;2 | sed -n '/F8/,/F10/p'
$ python3 crosscheck.py 2&gt;&amp;2 | sed -n '/\\[8\\]/,/\\[10\\]/p'
$ python3 linklab.py base 0x3000000
</pre>
                </div>
                <p>Then break the header table, which is the fastest route to understanding it:</p>
                <div class="hex-dump">
                    <pre>  1. Take the two-segment ph.ld and add a third:
       bss PT_LOAD FLAGS(6);
     but do NOT add a :bss to any rule. What does the
     linker say, and does it link? (Compare with the
     empty data segment in the main example.)

  2. Add PHDRS to the code segment and re-link. Then
     add FILEHDR. What changes in the offsets? Watch
     p_offset of the first LOAD -- it should move.

  3. Write a script with PHDRS but NO SECTIONS block
     at all. What is the error, and is it the same one
     as the empty script?

  4. Now the important one. Take default.ld, and add
     a PHDRS block declaring exactly the segments it
     already produces (4 LOADs: R, RE, R, RW). Does
     the binary still come out identical? If not, what
     is the smallest difference, and which part of the
     default's inferred layout is PHDRS making
     explicit?

  5. Try to get a PIE out of a script. Start from
     default.ld, add PHDRS, and see how far you get.
     (You will need the DYN output format AND you will
     find the script's fixed 0x400000 has to go. The
     full fix is in the ld manual under "PIC" and it
     is genuinely fiddly -- which is why people write
     PIE binaries without scripts.)
</pre>
                </div>
                <p>Exercise 4 is the one that closes the module, and its result is the payoff. <strong>If a hand-written <code>PHDRS</code> block that matches the default&rsquo;s inferred layout produces an identical binary, then the default layout is fully specified by what a script could say</strong> &mdash; the linker is not making choices a script could not have made, and everything ld does is available to you. If it does <em>not</em> produce an identical binary, the difference tells you exactly which of ld&rsquo;s choices are conveniences rather than requirements, and that is genuinely useful knowledge.</p>
                <p>Exercise 5 is the honest one to attempt and the honest one to give up on partway. <strong>&ldquo;How do I make a script that produces a PIE&rdquo; is a real question with an awkward answer</strong>, and discovering that is more instructive than being handed the answer, because it shows that the default script is not a template you can adapt &mdash; it is a specific choice of fixed-layout output, and PIE is a different choice with a different set of requirements.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This closes the placement module, and the three concepts in it are one argument in three parts. <a href="/courses/link/lessons/link-location-counter">The Location Counter</a> gave you the variable. <a href="/courses/link/lessons/link-memory-regions">MEMORY Is a Budget</a> gave it a limit, and showed the only diagnostic a link produces about layout. <strong>This one gave the layout away from the linker entirely</strong>, with <code>PHDRS</code> for the table and the <code>-T</code> finding for who decides the code model.</p>
                <p>The connection to the <a href="/courses/elf/lessons/memory-mapping">ELF course's memory-mapping concept</a> is the deepest in the course, and it is a loop closing. That concept measured how a Linux kernel maps a <code>PT_LOAD</code>: page granularity, one set of permissions per mapping, and the consequence that segments must be page-aligned. <strong>This concept is the place you write the <code>PT_LOAD</code> that has to satisfy those rules</strong> &mdash; and the <code>ALIGN</code> calls that <a href="/courses/link/lessons/link-location-counter">the previous concept</a> justified are visible in the measured output above as the <code>0x1000</code> in the last column of every segment. The rule and the mechanism that enforces it are now in the same head, which is where a format stops being a table of fields and becomes something you can construct.</p>
                <p>The <code>-T</code> finding is a correction to the PIE module of the Relocations course, and it is worth being precise about what it does and does not change. <a href="/courses/link/lessons/pie-flags">The Flags, and Which One Is Which Kind</a> drew a 3&times;3 matrix of <code>-f</code> codegen flags against <code>-pie</code>/<code>-no-pie</code> link flags, and found four cells where the two disagree and the result is neither thing. <strong>That matrix has a fifth column it did not know about: the script.</strong> A <code>-T</code> flag is a third participant, it is not a codegen flag or a link flag, and it can override both. The <a href="/courses/reloc/lessons/pie-cost">cost measurement</a> in that course showed that <code>-fno-pie -no-pie</code> is &ldquo;the worst of both worlds&rdquo; because you pay the PIC cost and get no ASLR; supplying a script is the same failure with a different mechanism, and this concept is where it is explained.</p>
                <p>Forward into the selection module, this concept completes the picture of what a script can decide. Placement is done &mdash; addresses, budgets, segments. What is left is <em>membership</em>: which sections are in the output at all, and which of those are kept when the linker throws most of them away. <a href="/courses/link/lessons/link-keep-gc">Reachability, and Who the Roots Are</a> is that question, and it is the one place where a single word inside a rule &mdash; <code>KEEP</code> &mdash; is the only reason a piece of code exists in your binary.</p>
                <p>And the connection to <a href="/courses/link/lessons/link-default-script">the round trip</a> is the practical one. Because <code>-T</code> replaces rather than extends, <strong>the only maintainable way to change a link is to start from ld&rsquo;s own script and edit it</strong> &mdash; and the reason that works is the byte-identical round trip. Without that identity you would be maintaining a fork of a 276-line program with no way to tell whether it had drifted; with it, a one-line diff is provably the only change. That is what an <a href="/courses/reloc/lessons/reloc-apply">applier you can verify by hand</a> buys you, applied to a linker rather than to a relocation.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/link/lessons/link-memory-regions">Previous: MEMORY Is a Budget</a></span>
                <span>Next: <a href="/courses/link/lessons/link-keep-gc">Reachability, and Who the Roots Are</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
