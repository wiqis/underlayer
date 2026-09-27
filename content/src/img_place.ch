// Executable Images and OS Loading — Module 3: The Layout
// Concept: the process map, the 64 KB floor, and why a hint is not a request.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_img_place() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Where the Kernel Put Everything — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson img-lesson">
            <a href="/courses/img" class="back-link">Back to course</a>
            <h1>Where the Kernel Put Everything</h1>
            <div class="lesson-meta">25 min &middot; Module 3: The Layout &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The <a href="/courses/elf/lessons/memory-layout">ELF course showed a picture</a> of a process address space: stack at the top, heap below it, a gap, the program image at the bottom. That picture is right, and it is a diagram, and diagrams do not have addresses in them.</p>
                <p>This concept replaces the diagram with the real thing, and the real thing has three properties the diagram cannot show:</p>
                <ul>
                    <li><strong>It is not fixed.</strong> Every region moved, because the kernel chose where to put each one, and it chooses differently every run.</li>
                    <li><strong>It has a floor.</strong> There is an address the kernel refuses to map, and it is not zero, and the number is not 64 KB by accident.</li>
                    <li><strong>You cannot ask for a specific address.</strong> <code>mmap</code> takes one and treats it as a suggestion, and the difference between a suggestion and a demand is the <code>MAP_FIXED</code> flag.</li>
                </ul>
                <p>Each of those is a small thing. Together they are the difference between a mental model of memory and an accurate one, and getting them wrong is how a program ends up with a null-pointer bug that only appears sometimes.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p><code>/proc/&lt;pid&gt;/maps</code> is the kernel&rsquo;s own list. One line per mapped region, and the format is worth reading once properly because every column is a fact about a decision the kernel made:</p>
                <div class="formula">
  7f81f7609000-7f81f7621000 rw-p 00000000 00:00 0     [anon]

  |  |   |    |        |      |     |
  |  |   |    |        |      |     +-- the PATH. square
  |  |   |    |        |      |        brackets = the kernel
  |  |   |    |        |      |        made this, no file
  |  |   |    |        |      +-- inode
  |  |   |    |        +-- device, MAJOR:MINOR in hex
  |  |   |    +-- file OFFSET this region starts at
  |  |   +-- PERMISSIONS. four letters:
  |  |      r read  w write  x execute  p shared
  |  +-- the ADDRESS RANGE
  +-- the kernel's table of its own decisions

  the address range is the decision.
  everything else is bookkeeping.
                </div>
                <p>Two columns carry more meaning than they look like they do.</p>
                <p><strong><code>r-xp</code> versus <code>rw-p</code> is the <code>PT_LOAD</code> flags from your file, verbatim.</strong> The trailing <code>p</code> is <code>MAP_PRIVATE</code>, which is the default for everything a loader maps, and it is why a library&rsquo;s data is copied if you write to it. <a href="/courses/elf/lessons/segment-types">The segment-types concept</a> read these four flags out of a file; here they are as the kernel applied them, and the application is where <code>GNU_RELRO</code> becomes visible &mdash; a region that shows up as <code>r--p</code> because the loader asked for read-only after finishing its writes.</p>
                <p><strong>The <code>p</code> is the whole copy-on-write story in one character.</strong> Not <code>s</code>, which is <code>MAP_SHARED</code>, and which you will see on exactly one region &mdash; the one that maps libc&rsquo;s data so that a <code>printf</code> internal counter is shared with every process using that library. The <a href="/courses/reloc/lessons/pie-randomize">relocations course</a> introduced COW as a cost PIE pays; this is where you can see which regions chose it and which did not.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Measured, in a Real Process</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/img/assets/samples &amp;&amp; ./build_samples.sh 2&gt;&amp;1 | sed -n '/I7/,$p'
     the map of a process that IS the process asking:
  5bd505393000-5bd505394000 r--p  00000000 .../samples/maps
  5bd505394000-5bd505395000 r-xp  00001000 .../samples/maps
  5bd505395000-5bd505396000 r--p  00002000 .../samples/maps
  5bd505396000-5bd505397000 r--p  00002000 .../samples/maps
  5bd505397000-5bd505398000 rw-p  00003000 .../samples/maps
  5bd520ccd000-5bd520cee000 rw-p  00000000 [heap]
  7f81f7400000-7f81f7428000 r--p  00000000 /usr/lib/.../libc.so.6
  7f81f7428000-7f81f75c0000 r-xp  00028000 /usr/lib/.../libc.so.6
  7f81f7609000-7f81f7621000 rw-p  00000000 [anon]

     the regions that matter, and who owns each:
  \[stack\]    7ffff8299000-7ffff82bb000
  \[heap\]     5c17e1e83000-5c17e1ea4000
  \[vdso\]     71e4c0d45000-71e4c0d47000
  ld-linux     7881a3b73000-7881a3b74000
</pre>
                </div>
                <p>Now the floor, which is the measurement people are surprised by. <code>mmap</code> will not map below <code>0x10000</code>, and it reports that as <code>EPERM</code> rather than <code>ENOMEM</code>:</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/I5/,/I6/p'
    FIXED  0x100000 = 0x100000             ok
    FIXED   0x10000 = 0x10000              ok
    FIXED    0x8000 = 0xffffffffffffffff   Operation not permitted
    FIXED    0x1000 = 0xffffffffffffffff   Operation not permitted
    hint   0x100000 = 0x7763b1205000       ok
    hint    0x10000 = 0x7763b1204000       ok
    hint     0x8000 = 0x7763b1203000       ok
    hint     0x1000 = 0x7763b1202000       ok
</pre>
                </div>
                <p><strong>Read the last four lines against the first four. The identical low addresses fail with <code>MAP_FIXED</code> and succeed without it.</strong> Nothing was rejected for being too low &mdash; the kernel simply put it somewhere else. That is not a quirk, that is the contract:</p>
                <div class="formula">
  mmap(addr, len, prot, flags, fd, off)

  addr != NULL   a HINT. "I would prefer here."
                  the kernel may ignore it, and
                  usually will if it cannot honour
                  it. you must CHECK the return.

  MAP_FIXED      a DEMAND. "Put it exactly here,
                  or fail." it will overwrite
                  whatever was there.

  MAP_FIXED_NOREPLACE   the safe version: honour
                  it if free, fail with EEXIST
                  if occupied. added in Linux
                  4.17 precisely because plain
                  MAP_FIXED is dangerous.
                </div>
                <p>And the reason for the floor is not arbitrary &mdash; it is the oldest attack in the book. <strong>A null-pointer dereference that only writes is often not exploitable; one that also maps something at address zero turns a bug into arbitrary code execution.</strong> Refusing to map below 64 KB removes the bottom of that technique by construction, and it is why a &ldquo;can I map page zero?&rdquo; experiment gives <code>EPERM</code> rather than succeeding. The address is not reserved; nothing can be put there, which is a stronger guarantee.</p>
                <p>Two features of the map above are worth reading off directly. <strong>The program image is five lines, not three</strong>, and two of them are <code>r--p</code> with the <em>same</em> offset <code>0x2000</code>. That is section-to-segment padding: the file has a <code>.rodata</code> and a <code>.eh_frame</code> with different alignments, and the gap between them is mapped as a separate read-only region because the <code>PT_LOAD</code>s demand it. <a href="/courses/link/lessons/link-phdrs">The linker script course</a> produced that padding; here is why it is visible at all, and it is visible only because the kernel honours the alignment rather than rounding the permissions up.</p>
                <p>And <strong>the heap is nowhere near the program.</strong> It is at <code>0x5c17e1e83000</code> while the binary is at <code>0x5bd505393000</code> &mdash; a gap of tens of terabytes. The <a href="/courses/elf/lessons/memory-layout">diagram</a> showed the heap above the program image; the truth is that the heap is wherever <code>brk</code> was first called, which is a decision, and the diagram is a cartoon of it.</p>
            </div>

            <div class="unit unit-example">
                <h2>The Trap That Cost a Day</h2>
                <p>Here is the single most misleading thing in this area, and this course shipped a version of it before fixing it.</p>
                <div class="hex-dump">
                    <pre>$ awk '{print $1, $NF}' /proc/self/maps | head -3
  75481304a000-75481304b000
  7ce75aa1c000-7ce75aa1d000  /usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2
  7ce75aa1d000-7ce75aa4c000  /usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2
  $ echo "that looks completely reasonable."
</pre>
                </div>
                <p><strong>Those addresses are not the shell&rsquo;s. They are <code>awk</code>&rsquo;s.</strong> <code>/proc/self</code> means &ldquo;the process doing the reading&rdquo;, and in a pipeline the process doing the reading is <code>awk</code>. The output is a perfectly valid address space &mdash; a PIE binary, a heap, a loader, everything in the right places &mdash; and it is <em>the wrong process&rsquo;s</em>. Nothing in the output says so.</p>
                <p>The fix is to have a program read its own map, which is three lines:</p>
                <div class="hex-dump">
                    <pre>$ cat &gt; maps.c &lt;&lt;'EOF'
  #include &lt;stdio.h&gt;
  int main(void) {
      FILE *f = fopen("/proc/self/maps", "r");
      char l[1024];
      while (fgets(l, sizeof l, f)) fputs(l, stdout);
      fclose(f); return 0;
  }
  EOF
$ clang -O1 -o maps maps.c &amp;&amp; ./maps | head -2
  5bd505393000-5bd505394000 r--p 00000000 .../samples/maps
  5bd505394000-5bd505395000 r-xp 00001000 .../samples/maps
</pre>
                </div>
                <p>Now the paths say <code>maps</code>, because they <em>are</em> this process&rsquo;s. The general rule is short and worth memorising: <strong>in a shell pipeline, <code>/proc/self</code> is the last stage, not the first.</strong> <code>cat /proc/self/maps</code> is the shell&rsquo;s own map; <code>awk &hellip; /proc/self/maps</code> is awk&rsquo;s; <code>grep proc /proc/self/maps</code> is grep&rsquo;s. Every one of them a different process, every one of them a plausible-looking answer.</p>
                <p>This is why the artifact in this course holds its child process still. <code>imgdump</code> blocks on <code>stdin</code> precisely so the parent can read <code>/proc/&lt;pid&gt;/maps</code> and <code>/proc/&lt;pid&gt;/cmdline</code> of a process it knows the state of. <strong>The path is explicit there, which is the whole fix</strong> &mdash; <code>/proc/1234/maps</code> cannot be ambiguous, and <code>/proc/self/maps</code> is only correct when the reader is the subject.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/img/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/I5/,$p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/G5/,$p'
$ ./maps | head -30
</pre>
                </div>
                <p>Then measure the parts the build script does not:</p>
                <div class="hex-dump">
                    <pre>  1. Run ./maps twenty times and collect the
     first line's address. Plot it. Then run
     with setarch -R (which disables ASLR) and
     plot that. (That is the whole of ASLR, in
     two curves, and setarch is the switch. The
     relocations course measured WHY PIE needs a
     base; this measures the base MOVING.)

  2. Find the MAP_SHARED region in ./maps output.
     There is exactly one, and it maps libc's
     data. Now count how many regions are r--p,
     r-xp, rw-p. Then read readelf -lW on the
     same libc and count its PT_LOADs. (The
     numbers will not match, and the reason is
     alignment: each LOAD becomes several
     mappings. This is the padding effect from
     the concept, measured.)

  3. mmap a region, write to it, and watch it
     become [anon] with a file offset of 0. Then
     mmap a FILE and watch it get the file's
     path and a non-zero offset. Those two lines
     in /proc/maps are the difference between
     "memory" and "a window onto a file", and it
     is the distinction the whole file-backed
     paging mechanism exists to make.

  4. cat /proc/self/maps | head -1
     grep proc /proc/self/maps | head -1
     awk 'END{print}' /proc/self/maps
     Three commands, three different processes,
     three different answers to "where is the
     stack". Confirm with the PID each one
     reports. (The first is bash, the second is
     grep, the third is awk. None is the shell
     you typed into if you piped.)

  5. Read /proc/self/limits and find the stack
     size limit. Compare it to the size of the
     [stack] mapping. Now write a recursive
     function that overflows it and watch the
     address it die at -- it should be the end
     of the stack mapping, not a random place.
     (The kernel put a guard at the boundary.
     That guard is why the crash is a clean
     SIGSEGV and not silent corruption.)
</pre>
                </div>
                <p>Exercise 1 is the measurement that ties this concept to the <a href="/courses/reloc/lessons/pie-randomize">relocations course&rsquo;s randomisation concept</a> and closes the security thread. <strong>Twenty curves versus one flat line</strong> is what &ldquo;the base is randomized&rdquo; means when you stop describing it and start plotting it. And <code>setarch -R</code> is the switch, which makes the mechanism concrete: it is one flag in one program, and it turns a defence off completely. A defence you can disable with a flag on the same machine is a defence against a class of attacker, not against a determined one, and knowing which is which is the whole point of measuring it.</p>
                <p>Exercise 5 has the best payoff. <strong>The stack grows down until it hits the guard, and then it dies exactly there</strong> &mdash; not wherever the overflow wandered, not at a corrupted pointer. That is the kernel enforcing a boundary it chose, and it is the difference between a crash that is diagnosable and a security problem. It is also the reason the stack is mapped the way it is: the growth direction is a convention the ABI picked, and the kernel honours it so that overflow becomes a fault instead of a corruption.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept is the load-bearing correction to a diagram the <a href="/courses/elf/lessons/memory-layout">ELF course</a> drew and a fact the <a href="/courses/link/lessons/link-phdrs">linker script course</a> produced. <strong>The <code>PT_LOAD</code> rows in a program header table are requests, and this is where they are granted.</strong> The linker wrote down that a segment should be readable, executable at <code>p_vaddr</code>, with <code>p_align</code> of <code>0x1000</code>; the kernel read that table, chose a base, and produced five mappings where the file asked for three. The extra two are alignment padding, and they are visible in <code>/proc/&lt;pid&gt;/maps</code> as duplicate <code>r--p</code> lines at the same offset. <strong>Nothing in the file mentions them. They exist only because the kernel honoured the alignment.</strong></p>
                <p>The connection to the <a href="/courses/dyn/lessons/dyn-order-runtime">dynamic linking course&rsquo;s load-order concept</a> is a mechanism made visible. That course measured the order the loader mapped libraries in &mdash; breadth-first, from <code>DT_NEEDED</code>. <strong>This is what each of those steps looks like from outside</strong>: a new run of <code>r--p</code>, <code>r-xp</code>, <code>rw-p</code> lines appearing in the map, in the order the loader chose, at addresses the kernel picked. The loader decided the order; the kernel decided the addresses. Two different decisions, two different tools, and <code>/proc/&lt;pid&gt;/maps</code> is the single place both of them are written down.</p>
                <p>The <code>MAP_FIXED</code> result connects to the <a href="/courses/dyn/lessons/dyn-dlopen">dlopen concept</a> and to a security idea the dyn course could not reach. <code>MAP_FIXED</code> is the reason a plugin system can be a security problem: <strong>load a library whose code you did not audit, and it can map a page over anything in your address space, including the GOT.</strong> The dyn course covered <code>-z now</code> and <code>RELRO</code>, which close the window by making the GOT read-only &mdash; and <code>MAP_FIXED_NOREPLACE</code> is the same instinct applied to mapping itself, added to Linux in 4.17 because plain <code>MAP_FIXED</code> had proven too sharp an edge. Both are the same lesson: <em>an interface that can silently do something surprising will eventually do it on purpose.</em></p>
                <p>And the trap connects to everything, because it is a lesson about method rather than about memory. <strong>A measurement that reads <code>/proc/self</code> in a pipeline is not a slightly wrong measurement &mdash; it is a confident, well-formatted, entirely wrong one</strong>, with a PIE binary and a heap and a loader all in the right places. It is exactly the shape of a correct answer. Every crosscheck in this course asserts against a value obtained by a <em>different route</em> for this reason: <code>AT_ENTRY</code> from the kernel versus <code>e_entry</code> from the file, <code>AT_SYSINFO_EHDR</code> against a mapping in the same process, <code>AT_EXECFN</code> against <code>/proc/&lt;pid&gt;/cmdline</code>. A checker that reads the same source twice will agree with a wrong answer, and agreeing is not the same as being right.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/img/lessons/img-vdso">Previous: The vDSO: An ELF File With No File</a></span>
                <span>Next: <a href="/courses/img/lessons/img-walk">Rebuilding the Image Reader</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
