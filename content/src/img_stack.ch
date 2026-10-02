// Executable Images and OS Loading — Module 1: The Handoff
// Concept: argc, argv, envp, auxv as raw bytes, and the off-by-one that segfaults.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_img_stack() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Reading the Initial Stack by Hand — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson img-lesson">
            <a href="/courses/img" class="back-link">Back to course</a>
            <h1>Reading the Initial Stack by Hand</h1>
            <div class="lesson-meta">26 min &middot; Module 1: The Handoff &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The previous concept said the auxv is an array. Arrays are easy. <strong>This one is about the two things that make it not easy</strong>, and both of them are traps that produce a crash rather than a wrong answer, which is the friendly kind of bug and also the reason people never find them.</p>
                <p>Trap one: <code>%rsp</code> inside <code>main</code> is not the stack pointer the kernel set. Trap two: the auxv is not the array after <code>envp</code> &mdash; it is the array after the <em>NULL that ends</em> <code>envp</code>, and the difference is one word.</p>
                <p>Neither is a C language matter. Both are facts about a data structure the kernel built, and the only way to hold them is to go and look.</p>
                <div class="hex-dump">
                    <pre>$ cd /tmp &amp;&amp; cat &gt; bad.c &lt;&lt;'EOF'
  int main(void) {
      unsigned long *sp;
      __asm__ volatile ("mov %%rsp, %0" : "=r"(sp));
      long argc = (long)sp[0];
      char **argv = (char **)&amp;sp[1];
      char **envp = argv + argc + 1;
      unsigned long *aux = (unsigned long *)envp;   /* WRONG */
      while (*aux++) { }                             /* walk to find the end */
      aux--;
      printf("%lx\n", (unsigned long)aux);
  }
  EOF
$ clang -O1 -o bad bad.c &amp;&amp; ./bad
  Segmentation fault (core dumped)
$ echo $?
  139
</pre>
                </div>
                <p><strong>That is the first version of this course&rsquo;s own code, and it is wrong in the most instructive way available.</strong> It reads <code>argc</code> and <code>argv</code> correctly &mdash; they really are at the bottom &mdash; and then it treats <code>envp</code> as if it were the auxv and scans forward looking for a zero. The scan runs off the end of the arrays and into memory that is not an array at all.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The layout, from low addresses to high. Everything the kernel built is in this one contiguous run of stack, and the order is not a matter of taste:</p>
                <div class="formula">
  LOW   +--------------------------+
        |  argc                    |  one word
        +--------------------------+
        |  argv[0]                 |  pointer
        |  argv[1]                 |  pointer
 |        |  ...                     |
        |  argv[argc-1]            |
        |  NULL                    |  <-- the terminator
        +--------------------------+
        |  envp[0]                 |  pointer
        |  ...                     |
        |  NULL                    |  <-- the terminator
        +--------------------------+
        |  AT_PHDR,   addr         |  a PAIR
        |  AT_PHENT,  56           |
        |  AT_PHNUM,  14           |
        |  ...                     |
        |  AT_NULL,   0            |  <-- the terminator
  HIGH  +--------------------------+
             ... but the STRINGS are
             ABOVE all of this:

        |  ".../imgdump"           |  <- argv[0] points here
        |  "SHELL=/bin/bash"       |
        |  16 random bytes         |  <- AT_RANDOM points here
        |  "x86_64"                |
        |  ".../imgdump"           |  <- AT_EXECFN points here
        +--------------------------+
             top of the stack mapping
                </div>
                <p>Two features of that picture cause both bugs.</p>
                <p><strong>The pointers point up, not down.</strong> The arrays are at the bottom of the frame and the strings are at the top, so walking <code>argv[i]</code> means dereferencing a pointer to a <em>higher</em> address. This is why you cannot infer the array length from where the strings start, and why the frame is not self-delimiting from the bottom alone.</p>
                <p><strong>There are three terminators, and they mean different things.</strong> <code>NULL</code> after <code>argv</code> means &ldquo;no more arguments&rdquo;. <code>NULL</code> after <code>envp</code> means &ldquo;no more environment strings&rdquo;. <code>AT_NULL</code> means &ldquo;no more auxv entries&rdquo;, and unlike the other two it is a <em>tag</em> of zero, not a pointer. <strong>Skipping one <code>NULL</code>-terminated array instead of two is the bug from the previous section</strong>, and the failure mode is specific: you land inside <code>envp</code>, read an environment string&rsquo;s <em>pointer</em> as an auxv <em>tag</em>, and since a stack address is not zero the scan never terminates. It does not stop in the wrong place. It stops when it hits a mapped page that is not mapped, which is why the symptom is a segfault and not a garbage number.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Finding the Bottom</h2>
                <p>Before any of that is usable you need the stack pointer the kernel set, and <code>%rsp</code> in <code>main</code> is not it. The kernel builds the frame, then jumps to the entry point; <code>libc</code>&rsquo;s <code>_start</code> pushes a return address and aligns the stack, then calls <code>__libc_start_main</code>, which calls <code>main</code>, which allocates a frame. By the time your first line runs, <code>%rsp</code> is kilobytes below where the kernel put it, and the relationship is not constant.</p>
                <p>The kernel keeps the answer. <code>/proc/&lt;pid&gt;/stat</code> field 28 is <code>startstack</code> &mdash; the value the kernel itself used &mdash; and it exists for precisely this purpose.</p>
                <div class="formula">
  field  2  comm        "(imgdump)"  <- may CONTAIN SPACES
  field  3  state
  ...
  field 28  startstack  <- the one you want

  so you cannot count fields from the start of
  the line: a process named "my prog" breaks
  every naive field counter. the comm field is
  parenthesised, so start from the LAST ')'.
                </div>
                <p>That last point is a real trap and it is worth stating as a rule: <strong>find the last <code>)</code> in the line, then count from there.</strong> A program whose name contains a space &mdash; which is entirely possible &mdash; desynchronises any counter that starts at the beginning of the line, and field 28 becomes some other field entirely, which is usually a small integer, which becomes a wild pointer.</p>
                <p>Now the second measurement problem, which is the one that cost this course the most time. <code>startstack</code> is the <em>low</em> end of the frame the kernel built, and the strings are <em>above</em> it, up near the top of the 8 MB stack mapping. How far up? It depends on your environment, and it is not something you can guess:</p>
                <div class="hex-dump">
                    <pre>$ printf '\n' | ./imgdump | head -1
  STACK 7ffe5b141170 11920
</pre>
                </div>
                <p><strong>11920 bytes</strong>, and that is not a number anybody chose. It is <code>high_end_of_stack_mapping - startstack</code>, which is what the dump has to be, because the strings are at the top of that mapping and reading past the high end is a fault. Two guesses both fail, and both were tried here:</p>
                <ul>
                    <li>An <strong>8 KB</strong> window truncates the strings. One measured run put <code>AT_EXECFN</code>&rsquo;s string <strong>10368 bytes</strong> above <code>startstack</code>, so the parse died on a string with no <code>NUL</code> inside the buffer.</li>
                    <li>A <strong>64 KB</strong> window reads past the end of the stack mapping and <strong>segfaults on every process</strong>, including tiny ones, because there is simply nothing up there.</li>
                </ul>
                <p>So the only correct size comes from the kernel: read <code>/proc/self/maps</code>, find the mapping containing <code>startstack</code>, and dump exactly to its high end. That is 15 lines in <code>imgdump.c</code> and it is the difference between a parser that works and one that works until the environment is large.</p>
            </div>

            <div class="unit unit-example">
                <h2>Doing It For Real</h2>
                <p>Three steps, each of which the artifact performs on every run. The <em>whole</em> program is <code>stackwalk.py</code>; this is the part that matters.</p>
                <p><strong>One: get the bytes.</strong> <code>imgdump</code> reads its own <code>startstack</code>, copies the frame out, prints it as hex, and then <strong>blocks on stdin</strong>. That block is not decoration. It means the parent can read <code>/proc/&lt;pid&gt;/maps</code> and <code>/proc/&lt;pid&gt;/cmdline</code> of a process that has printed bytes and executed nothing else &mdash; so all three observations describe the same instant, and comparing them is sound.</p>
                <div class="formula">
  /* imgdump.c, the only part that is not parsing */
  unsigned long hi = stack_end_for(read_startstack());
  size_t N = hi - ss;  if (N &gt; 65536) N = 65536;
  memcpy(raw, (void *)ss, N);
  printf("STACK %lx %zu\n", ss, N);
  ... hex ...
  fgets(line, sizeof line, stdin);   /* hold still */
                </div>
                <p><strong>Two: parse with no help.</strong> <code>argc</code> is one signed word. Then <code>argc</code> pointers. Then a word that must be zero. Then pointers until a zero. Then pairs of words until a zero tag. Every step is a check, because each one is a place to be wrong:</p>
                <div class="formula">
  argc, = u64(raw, 0)
  if argc &lt; 0 or argc &gt; 4096:   raise "implausible argc"
      # 3. the array count, and the layout, are
      # the kernel's. An argc of 3000000 means
      # you started in the wrong place, and the
      # only symptom would be a segfault.

  off = 8
  for _ in range(argc):  argv.append(cstr(u64(raw, off))); off += 8
  assert u64(raw, off) == 0;  off += 8      # the first terminator

  while u64(raw, off):  envp.append(cstr(u64(raw, off))); off += 8
  off += 8                                  # the SECOND terminator
      # ^ THIS is the line the first version
      #   did not have, and it is the whole bug.

  while True:
      tag, val = u64(raw, off), u64(raw, off + 8); off += 16
      if tag == 0: break
  # 4. step 16, not 8. step 8 and every value
  #    becomes a tag.
                </div>
                <p><strong>Three: check it against something independent.</strong> This is the step that makes the parser trustworthy rather than merely plausible. The auxv is data handed to you by the kernel; the ELF file is data on disk. If the kernel is describing a real load of a real file, the two must agree, and if they do not you have found something.</p>
                <div class="hex-dump">
                    <pre>$ python3 stackwalk.py 2&gt;&amp;1 | sed -n '/KERNEL DESC/,$p'
  [ok  ] AT_PHENT == e_phentsize in the file  -- auxv 56, file 56
  [ok  ] AT_PHNUM == e_phnum in the file  -- auxv 14, file 14
  [ok  ] AT_ENTRY - AT_PHDR == e_entry - e_phoff  -- 0x10f0 == 0x10f0
  [ok  ] AT_ENTRY lands in an r-x region  -- 0x5a9b10f0f130 in .../imgdump
  [ok  ] AT_ENTRY maps to the file offset of e_entry  -- 0x1130, 0x1130
  [ok  ] AT_PHDR maps back to e_phoff  -- 0x40 vs 0x40
  [ok  ] AT_BASE lands in the dynamic linker, not in us
  [ok  ] AT_EXECFN names the file the kernel actually ran
  [ok  ] AT_SYSINFO_EHDR == the base of the [vdso] mapping
  [ok  ] AT_RANDOM points into the initial stack we hold
  18/18 checks passed
</pre>
                </div>
                <p>Read the third line again, because it is the one that makes this a parser rather than a dump. <strong><code>AT_ENTRY - AT_PHDR == e_entry - e_phoff</code>, both <code>0x10f0</code></strong> &mdash; the left side from the kernel&rsquo;s stack, the right side from 24 bytes of an ELF header this script parsed itself. And the two checks below it close the loop the other way: it maps <code>AT_ENTRY</code> through <code>/proc/&lt;pid&gt;/maps</code> to a file offset, and that offset is <code>0x1130</code>, which is <code>e_entry</code>. <strong>Kernel &rarr; address &rarr; mapping &rarr; file offset &rarr; file. Four hops, and it lands on the number in the file.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/img/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/I8/,$p'
$ python3 stackwalk.py --dump 2&gt;&amp;1 | head -30
$ python3 crosscheck.py 2&gt;&amp;1 | tail -13
</pre>
                </div>
                <p>Then break it deliberately, which is the only way to learn where the edges are:</p>
                <div class="hex-dump">
                    <pre>  1. Change the envp skip from "e + 1" to
     "e" in parse_image. Run it. It does not
     fail cleanly -- it walks off the end. Read
     the first tag it prints and work out which
     array it came from. (It is an environment
     string's address, read as a tag. Every
     such tag is huge and unaligned, and that
     pattern in the output is the fingerprint of
     this bug.)

  2. Change the auxv loop from "a += 2" to
     "a += 1". Run it. Every VALUE is now read
     as a tag. Count how many nonsense tags you
     get before the loop stops, and check: is
     AT_ENTRY one of them? (It is. That is the
     bug that makes a working parser look like it
     has a memory problem.)

  3. Count the envp in stackwalk.py's output,
     then run the same program with a 200-entry
     environment. Re-run ./imgdump and look at
     the byte count in the STACK header. Then
     put a 4 KB window back into imgdump.c and
     try it with that environment. (It breaks.
     The window must come from the mapping.)

  4. /proc/self/stat: rename the test binary to
     one with a SPACE in its name and run it.
     Then un-harden the field counter to start at
     the beginning of the line and run it again.
     (Field 28 becomes something else, and the
     resulting pointer is small. This is why the
     rule is "start from the last ')'".)

  5. Skip the stdin block in imgdump and try to
     read /proc/&lt;pid&gt;/maps from the parent while
     the child is running. (It works -- but only
     because the child is short. The block is what
     makes the two observations simultaneous
     rather than nearly simultaneous, and
     "nearly" is not a property you want to rely
     on when ASLR is moving things.)
</pre>
                </div>
                <p>Exercise 4 is the one that generalises past this course. <strong>A process name containing a space is not exotic</strong> &mdash; it is one <code>execve</code> call with a different string &mdash; and any tool that parses <code>/proc/&lt;pid&gt;/stat</code> by counting whitespace-separated fields from column one is wrong for it. This is a bug class, not a curiosity, and it shows up in profilers, container runtimes, and anything that reads process metadata.</p>
                <p>Exercise 3 connects to the previous concept. <strong>The frame size is a function of your environment, and it is measured, not assumed</strong> &mdash; 11920 bytes here with 64 environment entries. That is the kernel doing string work proportional to what you passed it, and it is a nice illustration that the initial stack is a real allocation, not a fixed structure. A shell with a huge environment makes every process it starts measurably slower to create, and this is why that is true.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Within module 1 this is the other half. <a href="/courses/img/lessons/img-auxv">The Auxiliary Vector</a> established <em>what</em> the third array is and why no C function returns it. This concept establishes <em>where it is and how to walk it</em>, which is the difference between knowing a thing exists and being able to read it &mdash; and in this chain, the second is the point. The course mission is parsing to a working executable, and this is the first concept where the thing being parsed is produced by something that is not a compiler.</p>
                <p>The connection to the <a href="/courses/elf/lessons/memory-layout">ELF course&rsquo;s memory-layout concept</a> is the sharpest correction in the course. That concept showed a diagram of a process address space with the stack at the top, the heap below it, and a gap between. <strong>That diagram is right and it is static, and this is where it becomes real: the top of the stack is not a fixed address, the frame at the bottom of it is not a fixed size, and both are chosen at run time.</strong> <a href="/courses/img/lessons/img-place">Where the Kernel Put Everything</a> takes the diagram apart and measures it.</p>
                <p>The connection to <a href="/courses/dyn/lessons/dyn-order-runtime">the dynamic linking course&rsquo;s breadth-first concept</a> is a mechanism the reader has already used without seeing. That course measured the loader&rsquo;s load order and found it breadth-first, and the loader got its starting point from <code>AT_PHDR</code>. <strong>So the loader does exactly what <code>stackwalk.py</code> does</strong>: it reads a data structure the kernel built, by hand, with no API, at addresses it did not choose. Everything the loader does for the first few microseconds of a process&rsquo;s life is this concept&rsquo;s content, running in C, one layer down. That is worth saying plainly, because it collapses the mental distance between &ldquo;a Python script that reads a stack&rdquo; and &ldquo;the thing that starts every program on Linux&rdquo;.</p>
                <p>Two traps from this concept reappear later as the same trap in a different costume. <strong>Stepping through pairs one word at a time</strong> is the auxv loop&rsquo;s bug; it is also what happens if you assume <code>DT_*</code> entries in the dynamic section are an array of 16-byte records without checking the <em>size</em> field &mdash; which is exactly what <a href="/courses/dyn/lessons/dyn-resolve">Rebuilding the Scope Yourself</a> had to get right. And <strong>finding the last <code>)</code></strong> before counting fields is the same instinct as reading <code>e_shstrndx</code> before indexing section names: <em>the container tells you where the variable-length part starts</em>. Two different formats, one rule, and the rule is worth having as a rule.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/img/lessons/img-auxv">Previous: The Auxiliary Vector</a></span>
                <span>Next: <a href="/courses/img/lessons/img-entries">What Each Entry Is For</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
