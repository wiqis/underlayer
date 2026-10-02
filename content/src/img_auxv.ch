// Executable Images and OS Loading — Module 1: The Handoff
// Concept: the third array on the initial stack, the one no C library gives you.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_img_auxv() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Auxiliary Vector — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson img-lesson">
            <a href="/courses/img" class="back-link">Back to course</a>
            <h1>The Auxiliary Vector</h1>
            <div class="lesson-meta">25 min &middot; Module 1: The Handoff &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Five courses into this chain you can read a relocation record, a linker script, a <code>DT_NEEDED</code> entry, and the loader&rsquo;s own symbol bindings. Every one of those facts lives in a <em>file</em>. Now ask the question none of them could answer: <strong>when the kernel runs that file, how does the program find out where it landed?</strong></p>
                <p>The program header table is at some address. The entry point is at some address. The dynamic linker is at some address. The page size is 4096. The hardware capabilities are a bitmask. None of that is in the C language, none of it is in <code>main</code>&rsquo;s signature, and <strong>no function in the C library will hand it to you.</strong> It is passed anyway, in a third array, and the reason you have never seen it is that the array has no name.</p>
                <div class="hex-dump">
                    <pre>$ cd courses/img/assets/samples &amp;&amp; ./build_samples.sh 2&gt;&amp;1 | sed -n '/I1/,/I2/p'
  argc = 1   argv[0] = ./stack   envp[0] = SHELL=/bin/bash
  AUX 33 0x00007b98c83c7000
  AUX 51 0x0000000000000d30
  AUX 16 0x00000000178bfbff
  AUX  6 0x0000000000001000
  AUX 17 0x0000000000000064
  AUX  3 0x0000577a01179040
  AUX  4 0x0000000000000038
  AUX  5 0x000000000000000e
  AUX  7 0x00007b98c83c9000
  AUX  8 000000000000000000
  AUX  9 0x0000577a0117a0a0
  AUX 11 0x00000000000003e8
</pre>
                </div>
                <p><strong>Twenty-two entries, and not one of them is reachable from C.</strong> That is the whole point of this concept, and everything else in the course is a consequence of it.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>What the kernel is doing, in one picture. This is not a diagram from a textbook; it is the shape of the bytes the previous five courses already taught you to read.</p>
                <div class="formula">
  the kernel gets a file and a list of strings.
  it must produce two things:

    an ADDRESS SPACE   the PT_LOAD segments, mapped
    an ENTRY POINT     where to jump

  and then it must TELL the program both, plus
  everything else the program cannot know.

  it could not put any of it in a register: the
  ABI at process entry is not defined to carry
  anything. so it builds a DATA STRUCTURE on the
  stack, in the one piece of memory both sides
  agree on, and points %rsp at it.

  the structure is three arrays:

    argv    what the user typed        (you know)
    envp    the environment            (you know)
    auxv    what the kernel knows       (you do not)

  and the third is the handoff.
                </div>
                <p>So the auxiliary vector is not a convenience and not a legacy. <strong>It is the only channel between the kernel and the program at process start, and it exists because the ELF file cannot contain the answer.</strong> The file says <code>e_entry = 0x1130</code>, which is an <em>offset</em>. The program needs an <em>address</em>. Something has to add the load base, and the kernel is the only thing that knows what it chose.</p>
                <p>The same argument explains the other entries. <code>AT_PHDR</code>: the program header table&rsquo;s address, which again is an offset in the file. <code>AT_BASE</code>: where the <em>dynamic linker</em> was put &mdash; a fact about a completely different file that your program never mentions. <code>AT_PAGESZ</code>: not in the file, because the file is portable and the page size is not.</p>
                <div class="formula">
  what the FILE knows        what the KERNEL knows
  -----------------         -------------------
  e_entry   = 0x1130         the load base it chose
  e_phoff   = 0x40                    |
  e_phnum   = 14                     v
  AT_PAGESZ is absent          the page size
  AT_BASE is absent           where ld.so went
  AT_HWCAP is absent          the CPU's features

  the file is the same on every machine.
  the answer is not. so the answer
  travels separately, at run time.
                </div>
                <p>And this is exactly why the entries are <em>not</em> in the file. <a href="/courses/elf/lessons/elf-header-fields">The ELF course established the header fields</a> and their job of describing the file. <strong>The auxv describes the same file <em>as loaded</em>, and those are different objects.</strong> A PIE executable has <code>e_entry = 0x1130</code> in the file and is entered at <code>0x55d4883a7130</code> in memory. The gap is the kernel&rsquo;s decision, and the auxv is where it is reported.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What the Kernel Actually Passes</h2>
                <p>Twenty-two entries on this kernel, x86-64, no <code>setuid</code>. Here they are with names, and every one is reproduced by <code>python3 stackwalk.py</code>:</p>
                <div class="hex-dump">
                    <pre>$ python3 stackwalk.py 2&gt;&amp;1 | sed -n '/THE IMAGE/,/KERNEL DESC/p'
  argc    1
  argv[0] /home/.../samples/imgdump
  envp    64 entries, first: SHELL=/bin/bash
  auxv    22 entries, 912 bytes of stack

    AT_SYSINFO_EHDR        33    0x000072982688e000
    AT_MINSIGSTKSZ         51    0x0000000000000d30
    AT_HWCAP               16    0x00000000178bfbff
    AT_PAGESZ              6     0x0000000000001000
    AT_CLKTCK              17    0x0000000000000064
    AT_PHDR                3     0x0000575f08dcf040
    AT_PHENT               4     0x0000000000000038
    AT_PHNUM               5     0x000000000000000e
    AT_BASE                7     0x0000729826890000
    AT_FLAGS               8     0x0000000000000000
    AT_ENTRY               9     0x0000575f08dd0130
    AT_UID                 11    0x00000000000003e8
    AT_EUID                12    0x00000000000003e8
    AT_GID                 13    0x00000000000003e8
    AT_EGID                14    0x00000000000003e8
    AT_SECURE              23    0x0000000000000000
    AT_RANDOM              25    0x00007ffcba0335e9
    AT_HWCAP2              26    0x0000000000000002
    AT_EXECFN              31    0x00007ffcba034faa -&gt; '.../imgdump'
    AT_PLATFORM            15    0x00007ffcba0335f9 -&gt; 'x86_64'
    AT_RSEQ_FEATURE_SIZE   27    0x0000000000000021
    AT_RSEQ_ALIGN          28    0x0000000000000040
</pre>
                </div>
                <p>Three things in that dump are worth stopping on, because each is a small trap.</p>
                <p><strong>It is not sorted.</strong> The kernel appends entries as various subsystems notice they need to say something, so the order is <code>33, 51, 16, 6, 17, 3, 4, 5, 7, 8, 9, 11&hellip;</code>. <strong>Any code that reads the auxv must search for the tag it wants</strong>, exactly as it must search a hash table for a symbol. Assuming position is a bug, and the &ldquo;missing&rdquo; <code>AT_PHDR</code> that results is the kind of crash that looks like memory corruption.</p>
                <p><strong>Some values are addresses and some are numbers, and the tag does not tell you which.</strong> <code>AT_PAGESZ</code> is tag 6 and its value is <code>0x1000</code>. That is a size, not an address. <code>AT_PHNUM</code> is tag 5 and its value is <code>0xe</code> &mdash; fourteen, not an address. <code>AT_PHENT</code> is <code>0x38</code>, which is 56, the size of a 64-bit program header. <strong>Dereferencing <code>AT_PAGESZ</code> gives you whatever is mapped at address 4096</strong>, which on this machine is nothing, and on a machine with a different floor might be something else entirely. The next concept takes this apart properly because it is the most common auxv bug.</p>
                <p><strong>Three entries are pointers to strings that live on the stack itself.</strong> <code>AT_PLATFORM</code> points at <code>&quot;x86_64&quot;</code> and <code>AT_EXECFN</code> at the pathname the kernel actually ran. The <a href="/courses/img/lessons/img-stack">next concept</a> shows where those strings sit in the byte layout, and the artifact asserts that <code>AT_EXECFN</code> matches <code>/proc/&lt;pid&gt;/cmdline</code> read at the same instant.</p>
                <p>And two numbers deserve a note because they look like mistakes. <code>AT_CLKTCK</code> is 100, which is <em>not</em> a frequency &mdash; it is <code>sysconf(_SC_CLK_TCK)</code>, the kernel&rsquo;s fixed unit for the times() accounting, and it has been 100 on Linux for its entire history. <code>AT_MINSIGSTKSZ</code> is 3376, and that one <em>has</em> moved: it was 2048 for most of Linux&rsquo;s life and rose for the unwinder work. A program that hardcoded 2048 and allocated a signal stack that size is relying on a number the kernel has already changed once.</p>
            </div>

            <div class="unit unit-example">
                <h2>Working With It</h2>
                <p>There is no API, so you read the array yourself. The whole of it, in C, once you have the stack pointer &mdash; which is its own problem, and the subject of the next concept:</p>
                <div class="formula">
  unsigned long *sp = ...;              /* startstack, not %rsp in main */
  long   argc  = (long)sp[0];
  char **argv  = (char **)&sp[1];
  char **envp  = argv + argc + 1;
  char **e     = envp;  while (*e) e++;      /* skip envp  */
  unsigned long *aux = (unsigned long *)(e + 1);

  for (unsigned long *a = aux; a[0] != 0; a += 2)
      handle(AT_name(a[0]), a[1]);

  /* there is no handle() in the C library.
     this is the entire interface. */
                </div>
                <p>Ten lines, and the shape is fixed by the kernel. Three details carry the whole thing:</p>
                <ul>
                    <li><strong>You search, you do not index.</strong> The array is unordered. A loop over tags is mandatory.</li>
                    <li><strong>You test <code>a[0] != 0</code>, not <code>a[0] != AT_NULL</code></strong> &mdash; those are the same thing, but the first is what the termination rule actually is: a zero tag ends the array, and the value in the next word is also zero.</li>
                    <li><strong>Step by two words, not one.</strong> Each entry is a (tag, value) pair. Stepping one word at a time turns every value into a tag, which produces entries like <code>type=4076743392</code> and a crash three lines later. This is the single most common auxv bug and it produces output that looks like corruption rather than like a mistake.</li>
                </ul>
                <p>Now the check that makes it trustworthy. The kernel claims the program headers are at <code>AT_PHDR</code> and the entry point is at <code>AT_ENTRY</code>. The file says where they are <em>relatively</em>. If the kernel is telling the truth about a file it loaded at one base, the two absolute addresses must differ by exactly what the file says the two offsets differ by:</p>
                <div class="hex-dump">
                    <pre>$ python3 stackwalk.py 2&gt;&amp;1 | grep 'AT_ENTRY - AT_PHDR'
  [ok  ] AT_ENTRY - AT_PHDR == e_entry - e_phoff  -- 0x10f0 == 0x10f0
</pre>
                </div>
                <p><strong>Both are <code>0x10f0</code>, and neither is derivable from the other.</strong> The left side came from the kernel walking the stack; the right side came from this script reading 24 bytes of an ELF header. Two independent sources, one number. That is the check worth building, and it is the spine of the whole course.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/img/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/I1/,/I2/p'
$ python3 crosscheck.py 2&gt;&amp;1 | tail -14
$ python3 stackwalk.py -v 2&gt;&amp;1 | grep '16 bytes'
</pre>
                </div>
                <p>Then push on the claims rather than repeating them:</p>
                <div class="hex-dump">
                    <pre>  1. Run stackwalk.py twenty times and diff the
     auxv dumps. Which entries are CONSTANT
     across runs, and which change? You should
     find AT_RANDOM, AT_EXECFN, AT_PLATFORM
     and the four credential entries constant,
     and every address moving. Then explain the
     credential entries: why would AT_UID be the
     same every time while AT_ENTRY moves?

  2. Delete the "step by two words" and change
     the loop to a += 1. Run it. Write down the
     first nonsense tag you see and where it came
     from. (It is an ADDRESS, read as a tag.
     This is the bug, and seeing it once is worth
     more than being told about it.)

  3. Add a new entry the kernel does not set,
     say tag 999, to the table in stackwalk.py.
     It will never appear. Now add tag 23 if you
     removed it, run under "setpriv --reuid=0
     --regid=0 --clear-groups" and see what
     AT_SECURE does. (That is the entry that
     tells a program the environment is
     untrustworthy, and it is the reason
     AT_SECURE exists at all.)

  4. Compare the entry count across a static
     binary (-static) and a dynamic one. The
     auxv is a KERNEL structure, not a linker
     one, so it cannot vanish -- but check
     whether AT_BASE does.
</pre>
                </div>
                <p>Exercise 1 has the best answer in it. <strong><code>AT_UID</code> is constant while <code>AT_ENTRY</code> is not</strong>, and the reason is that the first is a fact about <em>who you are</em> and the second is a fact about <em>where the kernel put you</em>. Those are different kinds of fact, and the auxv carries both without distinguishing them &mdash; which is precisely why the pointer-versus-size problem in the next concept exists, and why a program that treats the auxv as an array of addresses is wrong often enough to matter.</p>
                <p>Exercise 4 is the one that ties this to the whole chain. <a href="/courses/link/lessons/link-static-real">The static linking course</a> established that <code>-static</code> removes the dynamic loader from a program. <strong>It does not remove the kernel&rsquo;s handoff, because the kernel does not know or care what the program will link against.</strong> The auxv is built before the loader exists. That is a good thing to be able to state precisely, because &ldquo;static binaries skip the loading step&rdquo; is true in the userspace sense and misleading in the kernel sense.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept is the floor the previous five courses stood on without mentioning. <a href="/courses/obj/lessons/obj-intro">The object-file course</a> established that <code>e_entry</code> is a number in a header. <a href="/courses/reloc/lessons/pie-randomize">The relocations course</a> established that a PIE gets loaded at a randomized base and therefore cannot have absolute addresses in its data. <strong>Both are consequences of the fact this concept measures: the base is chosen by the kernel, after the file is complete, and the only way it is reported is through this array.</strong></p>
                <p>The connection to <a href="/courses/dyn/lessons/dyn-scope">the dynamic linking course</a> is the sharpest one. That course described the loader&rsquo;s global scope &mdash; the ordered list every undefined symbol is answered from &mdash; and never said where that scope comes from. <strong>It comes from here.</strong> The kernel decides which files to map, maps them, and then hands the loader two addresses: <code>AT_BASE</code> for itself and <code>AT_PHDR</code> for the program. The loader&rsquo;s first job is to read the program headers <em>at the address in the auxv</em>, not at an address it computed. The scope is then built from the <code>DT_NEEDED</code> entries it finds there.</p>
                <p>That makes <code>AT_PHDR</code> load-bearing for a program the reader has already met. <a href="/courses/dyn/lessons/dyn-resolve">Rebuilding the Scope Yourself</a> asks the reader to parse <code>DT_NEEDED</code> out of a running process &mdash; and a real implementation of that exercise gets its program header address from the auxv, because there is nowhere else to get it. The artifact in this course is the same exercise, one layer down, and it is the reason <code>AT_PHDR</code> is checked against <code>/proc/&lt;pid&gt;/maps</code> rather than merely printed.</p>
                <p>And the connection forward is inside this module. The auxv is on the stack, and the stack has a <em>layout</em> that the previous concept glossed as &ldquo;an array&rdquo;. <a href="/courses/img/lessons/img-stack">Reading the Initial Stack by Hand</a> takes the three arrays apart byte by byte, and it starts from a segfault &mdash; because the layout has an off-by-one in it that catches everyone, including the person who wrote this course&rsquo;s first version.</p>
                <p>One connection outward, because it explains a flag. <code>AT_SECURE</code> is 0 on every run in this course, and the <a href="/courses/reloc/lessons/pie-randomize">PIE concept</a> measured randomisation as a hardening measure. <strong>The two are the same mechanism seen from two sides</strong>: the kernel randomises the base <em>and</em> tells the program whether the environment is trustworthy, so a program that is told &ldquo;not secure&rdquo; can choose to stop trusting its own environment strings. A statically linked, position-dependent program gets a fixed address at <em>no</em> <code>AT_BASE</code> and no <code>AT_PHDR</code> surprise; that is the trade the two courses are making, and seeing both entries in one array is what makes it concrete.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dyn/lessons/dyn-resolve">Previous: Rebuilding the Scope Yourself</a></span>
                <span>Next: <a href="/courses/img/lessons/img-stack">Reading the Initial Stack by Hand</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
