// Static Linking and Linker Scripts — Module 1: The Script You Already Use
// Concept: ld will print the exact script it is using, and this is what it
// does and does not decide.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_link_default_script() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Program That Placed Your Binary — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson link-lesson">
            <a href="/courses/link" class="back-link">Back to course</a>
            <h1>The Program That Placed Your Binary</h1>
            <div class="lesson-meta">22 min &middot; Module 1: The Script You Already Use &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>You have run a linker several thousand times. It has never shown you the program it was running. One flag does:</p>
                <div class="hex-dump">
                    <pre>$ ld --verbose 2&gt;/dev/null | sed -n '/^====/,$p' | sed '1d;$d' &gt; default.ld
$ wc -l default.ld
276 default.ld
$ grep -nE '^[A-Z_]+' default.ld
6:OUTPUT_FORMAT("elf64-x86-64", "elf64-x86-64", "elf64-x86-64")
7:OUTPUT_ARCH(i386:x86-64)
8:ENTRY(_start)
9:SEARCH_DIR("=/usr/local/lib/x86_64-linux-gnu"); SEARCH_DIR("=/lib/x86_64-linux-gnu"); ...
10:SECTIONS
</pre>
                </div>
                <p><strong>That is the whole program that decided where your code went.</strong> Five top-level commands, 276 lines, and it is shipped as text &mdash; the only layer of the toolchain that is. Your compiler is a binary, your dynamic loader is a binary, but the thing that turns a pile of objects into an image is source you can read, edit, and save in your repository.</p>
                <p>So the plan for this course is unglamorous and, if the numbers hold up, worth it: <strong>read the script, then use it.</strong> Not &ldquo;learn linker script syntax&rdquo; &mdash; learn <em>this</em> one, on this machine, because it is the one that has been running your builds.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Before reading it, it helps to know what a script is and is not, because the most common confusion is about scope.</p>
                <div class="formula">
  WHAT THE SCRIPT DECIDES

    which INPUT sections go into which OUTPUT section
    the order of the input sections within one output
    the ADDRESS of every output section
    which output sections become which SEGMENTS
    the entry point
    what survives garbage collection

  WHAT IT DOES NOT DECIDE

    which symbols are defined            (that is the
                                          resolution pass)
    what a relocation computes           (that is
                                          reloc-apply)
    which bytes end up in a segment      (the kernel
                                          loader, at run time)

  the division is: the SCRIPT IS LAYOUT. everything
  else is somebody else's job.

                </div>
                <p><strong>That is the whole reason a script is a separate language rather than more command-line flags.</strong> The resolution algorithm and the relocation arithmetic are both fixed once you have chosen a target and an output format. Layout is the part that genuinely varies per project &mdash; and it is the part that has to be <em>describable</em>, because the people who need it (firmware engineers, kernel people, anyone placing code at an address) cannot change the linker.</p>
                <p>Which is also why the syntax is a language and not a flag set. There is no way to express &ldquo;put this section after that one, aligned to the next page&rdquo; as a command-line flag, and pretending otherwise is what makes <code>ld</code> command lines unreadable.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>Save the script and feed it back. If the script is the program, this must reproduce the binary:</p>
                <div class="hex-dump">
                    <pre>$ cat &gt; hello.c &lt;&lt;'EOF'
int helper(void){ return 7; }
int main(void){ return helper() - 7; }
EOF
$ clang -O1 -c hello.c -o hello.o
$ clang -O1 -fno-pie -no-pie hello.o -o rt_exec.out
$ clang -O1 -fno-pie -no-pie hello.o -o rts_exec.out -T default.ld
$ cmp rt_exec.out rts_exec.out &amp;&amp; echo BYTE IDENTICAL
BYTE IDENTICAL
</pre>
                </div>
                <p><strong>Byte for byte. Not the same size &mdash; the same file.</strong> That is a strong claim and it is worth pausing on, because it means the script really is the whole of the layout decision: same section order, same addresses, same padding, same everything. <code>ld</code> is not adding a secret step after the script runs.</p>
                <p>Now the part that makes the claim more interesting than it first looks, because the same experiment with different flags does <em>not</em> round-trip:</p>
                <div class="hex-dump">
                    <pre>  flags                  ld's own default    with -T default.ld
  ---------------------  ------------------  ------------------
  (none)                 DYN                 EXEC     differ
  -fPIE -pie             DYN                 EXEC     differ
  -fno-pie -no-pie       EXEC                EXEC     BYTE IDENTICAL
</pre>
                </div>
                <p><strong>The first version of this measurement got it wrong, and the way it got it wrong is the lesson.</strong> It compared <em>sizes</em>, found them all equal at 15912, and concluded &ldquo;IDENTICAL&rdquo;. Comparing <em>files</em> shows the two PIE rows differ &mdash; at byte 16, which is the <code>e_type</code> field:</p>
                <div class="hex-dump">
                    <pre>$ cmp -l rt.out rts.out | head -3
  17   3   2
  27   0 100
  83   0 100
       ^  0x03 = ET_DYN      0x02 = ET_EXEC
</pre>
                </div>
                <p>So the honest claim is narrower and more useful than the one I started with: <strong>the script round-trips exactly when the command-line flags and the script agree about the code model.</strong> Supplying a script selects a fixed, non-relocatable model, and on a toolchain where PIE is the default, adding <code>-T</code> silently changes the output type. <a href="/courses/link/lessons/link-phdrs">The sixth concept</a> is entirely about that, because it is the most surprising property of <code>-T</code> I found.</p>
                <p>One more thing to establish before the module continues: the script is not decoration, it is the thing the CPU obeys. Change one number in it and the binary moves:</p>
                <div class="hex-dump">
                    <pre>$ sed 's/SEGMENT_START("text-segment", 0x400000)/SEGMENT_START("text-segment", 0x800000)/g' \
      default.ld &gt; b.ld
$ clang -O1 hello.o -o moved -T b.ld
$ readelf -lW moved | awk '/LOAD/{print $3; exit}'
0x0000000000800000
$ ./moved; echo "exit=$?"
exit=0
</pre>
                </div>
                <p><strong>0x800000 is an unremarkable address that nothing reserves, and the program ran there and got the right answer.</strong> The number in the script is not documentation the loader may reinterpret. It is where the CPU jumps on entry.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What is actually in those 276 lines, because the shape of the file tells you what the linker is doing and in what order.</p>
                <div class="hex-dump">
                    <pre>  lines   what
  -----   ------------------------------------------------------------
    1-5    a comment naming the -z flags the script is FOR
    6      OUTPUT_FORMAT: three names, because you can ask for
           one format and get a different one back
    7      OUTPUT_ARCH: the target
    8      ENTRY(_start): the root symbol for gc-sections
    9      thirteen SEARCH_DIR calls, in priority order
   10-12   SECTIONS opens; two SEGMENT_START lines place the
           image and skip the headers
   13+     the output sections, in LOAD order:
           notes, .interp, hash, dynsym, dynstr, .rela.*,
           .init, .plt, .text, .fini, .rodata, .eh_frame,
           .tdata, .tbss, .init_array, .ctors, .data, .bss
  ~215     the debug sections, every one at address 0
  273      /DISCARD/
  276      }
</pre>
                </div>
                <p><strong>Three structural facts fall out of that, and each is a lesson.</strong> First, the output sections appear in <em>segment</em> order, not section-name order &mdash; the read-only headers come first, then code, then read-only data, then writable. That is the order the <a href="/courses/elf/lessons/segment-types">ELF course</a> taught you to expect, which is a nice confirmation that the format and the tool agree.</p>
                <p>Second, every debug section is written as <code>.debug_info 0 :</code> &mdash; an explicit <strong>address of zero</strong>. That is not a placeholder; it is a statement that these sections are not loaded into memory at all, and setting the VMA to 0 is how the script says so. <strong>The address field in a script is not only where to put something; it is a claim about whether it is in memory.</strong></p>
                <p>Third, and this is the one that pays off across the whole course: the script is <em>cumulative</em>. Every `PROVIDE` and `PROVIDE_HIDDEN` line is inventing a symbol, and every one of them is conditional. The <a href="/courses/sym/lessons/sym-linker-defined">Symbol Resolution course</a> covered those symbols; this course covers the <em>line of script</em> that creates them, which is the first thing the reader has been reading without knowing it.</p>
                <div class="hex-dump">
                    <pre>  PROVIDE (__executable_start = SEGMENT_START("text-segment", 0x400000));
  PROVIDE (__etext = .);
  PROVIDE_HIDDEN (__init_array_start = .);
  PROVIDE_HIDDEN (__init_array_end = .);
  _edata = .;

  ^ PROVIDE means "define this ONLY IF something referenced
    it". _edata = . has no PROVIDE, so it is defined
    UNCONDITIONALLY. That is the difference, and it is why
    some of these symbols are missing from your binary and
    some are not.
</pre>
                </div>
                <p>And a trap worth knowing before you try it yourself, which cost me a debugging session. <code>PROVIDE</code> is conditional, so a symbol nothing references is never emitted &mdash; which means you cannot discover a script's values by asking for them politely:</p>
                <div class="hex-dump">
                    <pre>$ python3 - &lt;&lt;'PY'
s = open('default.ld').read()
s = s.replace('SECTIONS\n{', 'SECTIONS\n{\n'
  '  PROVIDE(__probe = SEGMENT_START("text-segment", 0xDEADBEEF));', 1)
open('probe.ld','w').write(s)
PY
$ clang -O1 hello.o -o p.out -T probe.ld
$ readelf -sW p.out | grep __probe
$ echo "(nothing)"
$ clang -O1 hello.o -o p.out -T probe.ld -Wl,-u,__probe
$ readelf -sW p.out | grep __probe
    1: 0000000000000000     0 OBJECT  LOCAL  DEFAULT  UND __probe
    2: 00000000deadbeef     0 OBJECT  LOCAL  DEFAULT    1 __probe
                                    ^^^^^^^^^^ THERE it is
</pre>
                </div>
                <p><strong><code>-u</code> makes the symbol undefined-but-referenced, which is exactly the condition <code>PROVIDE</code> waits for.</strong> That is a general technique for interrogating a linker script: if you want to read one of its values out of the binary, you have to make something need it first.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/link/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/F1/,/F2/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/\\[1\\]/,/\\[2\\]/p'
$ python3 linklab.py show | head -12
</pre>
                </div>
                <p>Then go and read it, which is the exercise:</p>
                <div class="hex-dump">
                    <pre>  1. Read the whole 276 lines once, without looking
     anything up. Then read OUTPUT_FORMAT's THREE arguments
     in the ld manual. Why would a script need to name a
     fallback format?

  2. Count the output sections the script creates. Now
     count the sections in a linked binary that the
     script did NOT name. (The answer is the next
     concept, and it is not zero.)

  3. Delete the ENTRY(_start) line and link. What
     changes? Then delete /DISCARD/ and link. What
     changes? (One of these is a link error, one is
     silent, and the silent one is the interesting one.)

  4. Find every PROVIDE in the script. How many of them
     appear in your binary? For the ones that do not,
     use nm to check whether anything references them.

  5. Change the 0x400000 to 0x200000 and run the binary.
     Now change it to something page-unaligned, like
     0x400123. What happens, and which part of the
     script rounds it up for you?
</pre>
                </div>
                <p>Question 5 is the one that teaches the most, and it is a trap I would rather you hit deliberately than in production. <strong>The script does not place your first section at exactly the address you typed.</strong> There is a <code>SIZEOF_HEADERS</code> and a page-alignment step between the literal and the first byte of your code, and the `<a href="/courses/link/lessons/link-location-counter">location counter</a>` concept is exactly about that arithmetic. The binary still runs either way &mdash; but the address you wrote and the address you got will not be the same, and knowing the size of the gap is the difference between a script you wrote and a script you understand.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the first concept of the course and it exists to remove a blind spot rather than to add a topic. <strong>Three previous courses have taught the resolution pass, the relocation arithmetic, the archive format and the segment layout, and not one of them mentioned that there is a program sitting between &ldquo;the objects&rdquo; and &ldquo;the image&rdquo;.</strong> It was doing all the placing the whole time, in a file you could have read with one command.</p>
                <p>The two connections that matter most are to the courses either side. <a href="/courses/sym/lessons/sym-algorithm">The Algorithm, Measured</a> traced GNU ld's demand-driven resolution pass and showed that the map file is the <em>output</em> of a pass that ran before layout. <strong>This concept is the input to the pass that came after it</strong> &mdash; and the reason order matters is now visible: you cannot place a symbol whose value is not yet decided, and you cannot decide values without knowing which objects got pulled in, and you cannot know that until the resolution pass has run. The script runs last, which is why it can talk about addresses at all. <a href="/courses/sym/lessons/sym-order">Link Order</a> answered &ldquo;which object files get used&rdquo;; this course answers &ldquo;and then where do they go&rdquo;.</p>
                <p>The second connection is to the <a href="/courses/reloc/lessons/reloc-apply">relocation applier</a> the Relocations course ended with. That program was deliberately incomplete in a specific way: it accepted a <em>layout</em> as an input and did not decide one. <code>apply_relocs.py</code> has a <code>build_layout()</code> function with a comment saying that deciding the layout is a different program with a much harder problem. <strong>That different program is this one.</strong> The line between them is the line this course is about, and it is the reason the applier could be 250 lines and correct while a real linker is 250,000.</p>
                <p>And the connection into the rest of this module is narrow and specific. <a href="/courses/link/lessons/link-script-language">The Language, in the Order It Runs</a> gives the grammar you need to read the remaining 270 lines, and <a href="/courses/link/lessons/link-order">Which Rule Wins</a> answers the one question that reading the script raises immediately: the `.text` rule has six wildcard patterns in it, in a deliberate order, and the order is the whole point. <strong>Those three concepts together are enough to read any linker script in the wild</strong>, and reading one is the single most useful thing a systems programmer can do when a build behaves strangely.</p>
                <p>One connection outward, for the hardware framing. The addresses in this script &mdash; <code>0x400000</code> and the <code>ALIGN(MAXPAGESIZE)</code> steps between segments &mdash; are not arbitrary. They are chosen to avoid the region the kernel reserves for <em>shared libraries</em>, which is why a non-PIE executable can live at a fixed address and still coexist with <code>.so</code> files mapped far above it. <a href="/courses/reloc/lessons/pie-randomize">Does the Executable Actually Move?</a> measured the random base a PIE gets instead; the number in this script is the price of refusing it, and <code>ALIGN</code> is what keeps the price from colliding.</p>
            </div>

            <div class="lesson-footer">
                <span>Start of course</span>
                <span>Next: <a href="/courses/link/lessons/link-script-language">The Language, in the Order It Runs</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
