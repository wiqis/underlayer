// Executable Images and OS Loading — Module 2: Reading the Values
// Concept: the three that matter, the arithmetic that ties them to the file,
// and the pointer-versus-size trap.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_img_entries() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("What Each Entry Is For — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson img-lesson">
            <a href="/courses/img" class="back-link">Back to course</a>
            <h1>What Each Entry Is For</h1>
            <div class="lesson-meta">24 min &middot; Module 2: Reading the Values &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>You can now read the auxv. You cannot yet use it, because knowing that <code>AT_PHNUM</code> holds <code>0xe</code> and knowing what to <em>do</em> with <code>0xe</code> are different skills, and the second one is where programs go wrong.</p>
                <p>Here is the trap, stated as a bug you can write today:</p>
                <div class="hex-dump">
                    <pre>$ cd courses/img/assets/samples
$ cat &gt; trap.c &lt;&lt;'EOF'
  #include &lt;stdio.h&gt;
  int main(void) {
      /* found AT_PAGESZ, value 0x1000, and helpfully
         printed it as a pointer */
      unsigned long v = 0x1000;
      printf("%s\n", *(char **)v);
  }
  EOF
$ clang -O1 -o trap trap.c &amp;&amp; ./trap
  Segmentation fault (core dumped)
</pre>
                </div>
                <p><strong><code>AT_PAGESZ</code> is 4096, not an address.</strong> It is a size. And the auxv gives you no way to tell, from the tag alone, which kind of value you are holding. This is not a subtlety in the documentation &mdash; it is a property of the data structure, and it is the single most common way an auxv reader produces garbage.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Twenty-two entries fall into four groups, and the groups differ in what you may <em>do</em> with the value. This is the classification that makes the auxv usable:</p>
                <div class="formula">
  1. ADDRESSES INTO THE IMAGE
     AT_PHDR  3   where the program headers are
     AT_ENTRY 9   where to jump
     AT_BASE  7   where the LOADER went
     AT_SYSINFO_EHDR 33  where the vDSO went
     AT_EXECFN 31  -> a path string
     AT_PLATFORM 15 -> "x86_64"
     -> you may dereference. and you must check
        the region first, because 0 is not the only
        way to be wrong.

  2. COUNTS AND SIZES
     AT_PHENT  4    56, the size of one phdr
     AT_PHNUM  5    14, how many there are
     AT_PAGESZ 6    4096
     AT_CLKTCK 17   100
     AT_MINSIGSTKSZ 51  3376
     -> you may NOT dereference. 4096 is not an
        address. it is a SIZE.

  3. IDENTITY
     AT_UID 11  AT_EUID 12  AT_GID 13  AT_EGID 14
     AT_SECURE 23
     -> facts about the run, not the image.
        constant across runs; see img-auxv.

  4. CAPABILITIES
     AT_HWCAP 16   AT_HWCAP2 26
     AT_RSEQ_FEATURE_SIZE 27  AT_RSEQ_ALIGN 28
     -> a bitmask or a size, depending. the tag
        does not tell you which. neither does
        the type: both are unsigned long.
                </div>
                <p>The reason this is dangerous is worth stating precisely, because it is a property of C and not of the kernel: <strong>every value in the auxv is one <code>unsigned long</code>. There is no type information, no length, and no discriminant.</strong> The kernel could not have made it otherwise &mdash; the array is <code>(tag, value)</code> pairs of machine words, and that is the ABI. So a reader that assumes &ldquo;the value is an address because the auxv is addresses&rdquo; is not making a small error. It is making an error that a compiler cannot warn about and a type system cannot prevent.</p>
                <p>The practical consequence: <strong>you must know which tag you asked for.</strong> There is no way to ask the array &ldquo;is this a pointer?&rdquo; You write <code>AT_PHDR</code> and you know it is a pointer, because that is what <code>AT_PHDR</code> means. Every reference implementation keeps a static table saying so, and the table is the interface.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Three That Carry the Load</h2>
                <p>Twenty-two entries, and three of them do the work the previous five courses cared about. Everything else is context.</p>
                <div class="formula">
  AT_PHDR   3   the program header table
                   -> what the loader reads first
                   -> what "parse DT_NEEDED" means
                   -> an address, so it MOVES per run

  AT_ENTRY  9   where to jump
                   -> e_entry, made absolute
                   -> an address, so it MOVES per run

  AT_BASE   7   the dynamic linker's base
                   -> a DIFFERENT FILE entirely
                   -> an address, so it MOVES per run
                </div>
                <p><strong>The load-bearing arithmetic.</strong> All three move on every run, because the kernel randomises where it puts things. That is fine &mdash; and it is checkable, because their <em>differences</em> are not supposed to move. They are pure file quantities:</p>
                <div class="hex-dump">
                    <pre>$ python3 stackwalk.py 2&gt;&amp;1 | grep -E 'AT_ENTRY - AT_PHDR|AT_PHDR maps back'
  [ok  ] AT_ENTRY - AT_PHDR == e_entry - e_phoff  -- 0x10f0 == 0x10f0
  [ok  ] AT_PHDR maps back to e_phoff  -- 0x40 vs 0x40
</pre>
                </div>
                <p>Three of the moving values, then, and one relationship that holds across every run. <strong>That relationship is the proof that the kernel translated the file rather than recomputed it</strong>, and it is the most useful single check in this course. Note the arithmetic, because it is not arbitrary:</p>
                <div class="formula">
  AT_PHDR  = base + e_phoff
  AT_ENTRY = base + e_entry
  ------------------------------------
  AT_ENTRY - AT_PHDR = e_entry - e_phoff

  the base CANCELS. so a test that never learns
  the base can still verify the kernel did its
  job -- and the base is exactly the thing a
  naive reader gets wrong by assuming 0.
                </div>
                <p><strong><code>AT_BASE</code> is a different object, and conflating it with the others is the second big trap.</strong> It is not a field about your program at all. It is where the kernel put the dynamic linker &mdash; a separate file, <code>/usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2</code>, that your program never names. The artifact checks that <code>AT_BASE</code> lands in a mapping whose path contains <code>ld-linux</code> and <em>not</em> in your own executable:</p>
                <div class="hex-dump">
                    <pre>$ python3 stackwalk.py 2&gt;&amp;1 | grep -E 'AT_BASE|ET_DYN'
  [ok  ] AT_BASE lands in the dynamic linker, not in us
         -- /usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2
  [ok  ] ld.so is ET_DYN, so it must be given a base  -- e_type 3
</pre>
                </div>
                <p>And the reason it <em>has</em> to be passed separately is in that second line. <strong>Both your program and the loader are <code>ET_DYN</code></strong> &mdash; the relocations course measured that a PIE is a shared object with a preferred base of zero &mdash; so neither has an entry point the CPU can use directly. The kernel loads each at a base of its choosing and has to tell someone. <code>AT_BASE</code> is how it tells the loader where the loader is.</p>
                <p>That closes a loop the last two courses left open. <a href="/courses/reloc/lessons/pie-randomize">The relocations course</a> said a PIE cannot have absolute addresses in its data. <strong>This is why the kernel is the one who has to tell the program anything at all</strong> &mdash; and it is why a statically linked, non-PIE binary needs none of <code>AT_BASE</code>, <code>AT_PHDR</code>, or <code>AT_ENTRY</code> to be meaningful. The auxv is not overhead. For a position-dependent executable it is close to empty, and the kernel still builds it, because the kernel does not know what the program linked against.</p>
            </div>

            <div class="unit unit-example">
                <h2>Reading One Properly</h2>
                <p>The reference pattern, which is what <code>stackwalk.py</code> does and what any correct reader should look like. The important part is the table, not the loop:</p>
                <div class="formula">
  /* the table IS the interface. there is no
     way to ask the auxv whether a value is an
     address, so you have to know. */
  static const int IS_POINTER[] = ... /* the tags whose
     values you may dereference: */
      3,    /* AT_PHDR            */
      7,    /* AT_BASE            */
      9,    /* AT_ENTRY           */
      15,   /* AT_PLATFORM        */
      24,   /* AT_BASE_PLATFORM   */
      25,   /* AT_RANDOM          */
      31,   /* AT_EXECFN          */
      32,   /* AT_SYSINFO         */
      33,   /* AT_SYSINFO_EHDR    */
  ...   <- the table ends here; there is no
           closing brace, because this is a
           picture of a table, not a file

  unsigned long v;
  int is_ptr = 0;
  for (i = 0; i &lt; n; i++) if (IS_POINTER[i] == tag) is_ptr = 1;
  if (is_ptr &amp;&amp; !in_a_mapped_region(v))
      die("tag %d: %#lx is not mapped", tag, v);
                </div>
                <p>That last line is not decoration, and it is the difference between a reader that fails and a reader that fails informatively. <strong><code>AT_PHDR</code> being unmapped is a real failure mode</strong> &mdash; a statically linked binary on a system with no loader will have <code>AT_BASE == 0</code>, and a program that unconditionally dereferences it gets a fault at address zero. Checking before dereferencing converts a crash into a message, and for the auxv specifically it is nearly free because you can validate against <code>/proc/self/maps</code>, which the artifact already does for <code>AT_ENTRY</code> and <code>AT_SYSINFO_EHDR</code>.</p>
                <p>Now the measurement, and it is the one that ties the kernel to the file with no slack in it at all. Read <code>AT_ENTRY</code> out of the auxv. Find which mapping contains it. That mapping has a file offset. The address&rsquo;s offset within the mapping is its offset within the file. <strong>It must equal <code>e_entry</code>.</strong></p>
                <div class="hex-dump">
                    <pre>$ python3 stackwalk.py 2&gt;&amp;1 | grep -E 'AT_ENTRY'
  [ok  ] AT_ENTRY lands in an r-x region  -- 0x5a9b10f0f130 in .../imgdump
  [ok  ] AT_ENTRY maps to the file offset of e_entry  -- offset 0x1130, e_entry 0x1130
</pre>
                </div>
                <p><strong>Four independent hops and it lands exactly on the number in the file.</strong> Kernel &rarr; auxv &rarr; address &rarr; mapping &rarr; file offset. Nothing in that chain trusts anything else, and every step is a place the previous five courses taught you to read: the <code>r-xp</code> permissions are the <code>PT_LOAD</code> flags from <a href="/courses/elf/lessons/segment-types">the segment-types concept</a>, the file offset is the program header field from <a href="/courses/elf/lessons/program-header-table">the program-header concept</a>, and <code>e_entry</code> is the header field from <a href="/courses/elf/lessons/elf-header-fields">the header-fields concept</a>. This course adds no new file format. <strong>It supplies the one thing all of them were missing: the addresses.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/img/assets/samples
$ python3 stackwalk.py 2&gt;&amp;1 | sed -n '/KERNEL DESC/,$p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/G2/,/G3/p'
$ clang -O1 -o trap trap.c &amp;&amp; ./trap; echo $?
</pre>
                </div>
                <p>Then find the boundaries, which is the better exercise:</p>
                <div class="hex-dump">
                    <pre>  1. Build the same program -static -no-pie and
     run stackwalk.py's auxv dump against it.
     Which of AT_PHDR, AT_ENTRY, AT_BASE still
     work? (PHDR and ENTRY do -- they are about
     YOUR file. AT_BASE should be 0, because
     there is no loader. Now read that 0. This
     is the concrete shape of "the auxv is a
     kernel structure, not a linker one".)

  2. Set the IS_POINTER table in stackwalk.py
     to empty and run it. Count the crashes.
     Then add ONLY tag 6 (AT_PAGESZ) and run
     again. (This is the trap.c bug inside the
     artifact, and seeing which check catches it
     is the point.)

  3. AT_ENTRY - AT_PHDR == e_entry - e_phoff is
     the course's central check. Break it
     deliberately: subtract AT_BASE instead of
     AT_PHDR and see how far off you are. Then
     compute what the correct base actually is:
       base = AT_PHDR - e_phoff
     and confirm AT_ENTRY == base + e_entry.
     (You have just recovered the load base from
     two auxv entries and a file header, with no
     /proc involved at all. That is the kernel's
     address-decision, solved.)

  4. Print AT_HWCAP and look up which bits are
     which. Then compare against /proc/cpuinfo's
     flags. (They are the same feature set in
     different vocabularies. AT_HWCAP is what a
     program should use, because it is a machine
     word and cpuinfo is text. This is a small
     lesson that carries: use the interface that
     was designed for the consumer.)

  5. Run a setuid-root binary and diff the whole
     auxv against a normal run. AT_SECURE and the
     credential entries are the interesting ones.
     (This is what AT_SECURE exists for, and it
     is the only entry in the array that is a
     WARNING rather than a fact.)
</pre>
                </div>
                <p>Exercise 3 is the best exercise in the course and it is worth doing slowly. <strong>Two auxv entries and 24 bytes of an ELF header are enough to recover the address the kernel chose</strong> &mdash; no <code>/proc</code>, no debugger, no <code>readelf</code>. That is the kernel&rsquo;s entire ASLR decision, extracted arithmetically. And it reframes what ASLR is: not a mystery, but one number that a program can compute for itself and that an attacker cannot predict, which is exactly the property that makes it worth having and exactly why the <a href="/courses/reloc/lessons/pie-randomize">relocations course</a> treated it as a cost to be paid rather than a feature.</p>
                <p>Exercise 1 is the one that closes the chain. <strong>A static binary needs no dynamic linker and still gets a full auxv.</strong> The kernel builds it unconditionally because the kernel is not a linker and does not know what the program will need. So the correct statement of the boundary is not &ldquo;static binaries skip loading&rdquo; &mdash; it is &ldquo;static binaries skip the <em>loader</em>, and the kernel&rsquo;s handoff is not the loader&rsquo;s work.&rdquo;</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is where module 1&rsquo;s two concepts become usable. <a href="/courses/img/lessons/img-auxv">The Auxiliary Vector</a> said the array exists and that it is unordered. <a href="/courses/img/lessons/img-stack">Reading the Initial Stack</a> showed how to walk it. <strong>This concept says what the words mean, and the answer &mdash; four groups, three of which you may not dereference &mdash; is why a correct parser needs a table rather than a loop.</strong> The three concepts together are what &ldquo;parse a process image&rdquo; actually means, and a reader who has all three can do it from nothing.</p>
                <p>The connection to <a href="/courses/dyn/lessons/dyn-resolve">Rebuilding the Scope Yourself</a> is a direct dependency, and the dependency runs in the direction people expect. That exercise asks the reader to parse <code>DT_NEEDED</code> out of a live process, and the only way to know where the program headers are is <code>AT_PHDR</code>. <strong>So the artifact in this course is a prerequisite for that one, not a repeat of it</strong> &mdash; it stops at the program header table, and the dyn course starts there and goes on to the dynamic section, the symbol tables, and the scope. Two artifacts, two layers, one program. That is the chain working the way the mission describes.</p>
                <p>The connection to <a href="/courses/reloc/lessons/pie-flags">the PIE concepts</a> is the deepest one in the course, and it corrects something. Both the program and the loader are <code>ET_DYN</code>, which the relocations course measured and this course explains the <em>consequence</em> of: <strong>a shared object has no entry point until someone gives it a base, and the kernel is the only one who can.</strong> The reloc course showed what that costs the compiler (one relocation per datum on x86-64, two on AArch64). This concept shows what it costs the <em>kernel</em>: it must communicate the base, and the only channel is an array on the stack.</p>
                <p>And the security thread gets its sharpest statement here. <code>AT_SECURE</code> sits in group 3 &mdash; identity, not addresses &mdash; and it is the only entry in the array that is a warning. <strong>The kernel randomises the base and then tells the program whether the environment can be trusted.</strong> Those are the two halves of the same defence, and putting them in one array is a reminder that ASLR is a property of a <em>process image</em>, not of an instruction stream: the same binary gets a different layout every run, and the program is told enough to know whether to believe the strings it was handed.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/img/lessons/img-stack">Previous: Reading the Initial Stack by Hand</a></span>
                <span>Next: <a href="/courses/img/lessons/img-vdso">The vDSO: An ELF File With No File</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
