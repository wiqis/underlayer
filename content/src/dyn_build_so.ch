// Dynamic Linking and Shared Libraries — Module 2: Building a Library
// Concept: what ends up in .dynsym, and the four commands that decide it.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dyn_build_so() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Building a Library — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson dyn-lesson">
            <a href="/courses/dyn" class="back-link">Back to course</a>
            <h1>Building a Library</h1>
            <div class="lesson-meta">22 min &middot; Module 2: Building a Library &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every previous course has <em>consumed</em> shared libraries. This one builds them, and the first thing to understand is that a shared library is a much narrower thing than it looks.</p>
                <div class="hex-dump">
                    <pre>$ cat lib.c
static int static_helper(int x){ return x + 1; }   /* NOT exported */
int lib_value(void){ return static_helper(0); }     /* exported     */

$ clang -fPIC -shared -o liba.so lib.c
$ nm -D --defined-only liba.so
  0000000000001110 T lib_value
$ nm liba.so | awk '/ [tT] /{print "  " $2, $3}'
  T lib_value
  t static_helper
</pre>
                </div>
                <p><strong>One exported symbol out of two functions written.</strong> The upper-case <code>T</code> is <code>.dynsym</code> &mdash; the only table the loader searches. The lower-case <code>t</code> is in the full symbol table, where it is useful for debugging and invisible to every other process. <strong>A shared library is not a program; it is a program plus a short list of names it is offering to the world.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>What <code>-fPIC -shared</code> actually does, as four separate decisions rather than one.</p>
                <div class="formula">
  -fPIC        make every address REACHABLE without knowing
               the load address. the code cannot say
               "the address of x is 0x1234"; it has to say
               "the address of x is 0x1234 away from here".
               the reloc course measured what this costs:
               one extra instruction and one extra dependent
               load per global reference.

  -shared      change the OUTPUT TYPE to ET_DYN, and stop
               the linker resolving references the executable
               could have resolved itself. a shared object
               is not "a program that can be moved"; it is
               "a file whose undefined references are
               somebody else's problem".

  .dynsym      the export list. this is the ONLY part other
               files can see. a .so carries .symtab too,
               and nothing outside the link looks at it.

  DT_SONAME    the name this library will be known by. if
               you do not set one, a program that links
               against it records the FILE name instead,
               and renaming the file breaks every dependent.

                </div>
                <p><strong>The second bullet is the one that surprises people.</strong> <code>-fPIC</code> and <code>-shared</code> are independent, and a file with only one of them is a common mistake in both directions:</p>
                <div class="formula">
  -fPIC, no -shared   a PIE executable's worth of
                      GOT indirection, with a fixed
                      layout. the worst of both: pays the
                      position-independence cost and gets
                      no ASLR. (measured in the reloc
                      course as -fno-pie -no-pie)

  -shared, no -fPIC   a non-PIC shared object. the linker
                      REJECTS this for x86-64 the moment a
                      reference cannot be resolved
                      relatively, with the diagnostic the
                      reloc course recorded:
                        "relocation R_X86_64_32 against
                         undefined symbol X can not be
                         used when making a shared object"

                </div>
                <p>So the two flags are not alternatives. <strong>Position independence is a property of the code; sharing is a property of the file. A shared library needs both, and each is answering a different question.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>What the three names of a library are for, measured by building one with a version and a soname:</p>
                <div class="hex-dump">
                    <pre>$ cp liba.so libfoo.so.1.2.3
$ ln -s libfoo.so.1.2.3 libfoo.so.1
$ ln -s libfoo.so.1     libfoo.so
$ clang -fPIC -shared -Wl,-soname,libfoo.so.1 -o real.so lib.c
$ readelf -dW real.so | grep SONAME
  0x000000000000000e (SONAME)  Library soname: [libfoo.so.1]

$ clang -o useprog main.c -L. -l:libfoo.so.1 -Wl,-rpath,'$ORIGIN'
$ readelf -dW useprog | grep NEEDED
  0x0000000000000001 (NEEDED)  Shared library: [libfoo.so.1]
</pre>
                </div>
                <p><strong>Three names, three audiences, and the middle one is the contract.</strong> <code>libfoo.so.1.2.3</code> is the file &mdash; it changes whenever the code changes. <code>libfoo.so.1</code> is what the program records, forever. <code>libfoo.so</code> is what a developer types on a link line. Upgrading 1.2.3 to 1.4.0 changes the first and the third and must not change the second, or every program on the system stops running.</p>
                <p>And here is the demonstration that <code>-soname</code> is not decoration. The libraries in this course&rsquo;s sample directory were built <em>without</em> it:</p>
                <div class="hex-dump">
                    <pre>$ readelf -dW liba.so | grep -c SONAME
  0
$ readelf -dW prog | grep NEEDED
  (NEEDED)  Shared library: [libb.so]
  (NEEDED)  Shared library: [liba.so]
</pre>
                </div>
                <p><strong>No soname, so the program recorded the file name.</strong> Rename <code>liba.so</code> to <code>liba2.so</code> and <code>prog</code> stops finding it &mdash; not because anything is broken, but because the string in <code>.dynamic</code> no longer names a file. <strong>That is the entire reason <code>-soname</code> exists, demonstrated by its absence.</strong></p>
                <p>Now the parts of the file, and which of them other processes can see:</p>
                <div class="hex-dump">
                    <pre>$ readelf -SW liba.so | awk '$2 ~ /^\./ {printf "  %-18s %6s  %s\n", $2, $6, $3}'
  .text              000017  AX
  .dynsym            000060  WA
  .dynstr            00003c  WA
  .gnu.hash          00001c  WA
  .rela.dyn          000048  WA
  .rela.plt          000018  WA
  .init              000013  AX
  .fini              00000d  AX
  .init_array        000008  WA
  .dynamic           0000e0  WA
  .got               000010  WA
  .got.plt           000010  WA
  .data              000010  WA
  .bss               000008  WA
</pre>
                </div>
                <p><strong>Two of those are the interface and the rest is the machinery.</strong> <code>.dynsym</code> plus <code>.dynstr</code> plus <code>.gnu.hash</code> is everything another process can learn about this library. <code>.symtab</code> and <code>.strtab</code> are present too, and <em>nobody outside the link reads them</em> &mdash; which is why <code>strip</code> can remove them and why the symbol-resolution course could measure <code>.symtab</code> growing to 0xc210 bytes in a static binary without anything being able to use it.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The three-name scheme is not a convention; it is what makes upgrades possible, and the failure mode when a library gets it wrong is a system that will not boot.</p>
                <div class="hex-dump">
                    <pre>  libfoo.so.1.2.3   the real file, replaced on upgrade
  libfoo.so.1       a SYMLINK, never replaced
  libfoo.so         a SYMLINK, for the link line

  $ ls -l libfoo*
  lrwxrwxrwx  libfoo.so   -&gt; libfoo.so.1
  lrwxrwxrwx  libfoo.so.1 -&gt; libfoo.so.1.2.3
  -rwxr-xr-x  libfoo.so.1.2.3

  install a new libfoo.so.1.3.0:
    cp the new file in
    repoint libfoo.so.1 at it
    repoint libfoo.so at libfoo.so.1
    and every program linked against libfoo.so.1 gets
    the new code with NO relinking and NO change to its
    own DT_NEEDED.
</pre>
                </div>
                <p><strong>The middle symlink is the ABI contract and the only one that must be stable.</strong> Which is why &ldquo;bump the soname&rdquo; is a deliberate, disruptive act: a library that changes an interface must change the soname, and every program using it must be relinked. A patch release changes only the first name; a soname change is how you say &ldquo;these are not compatible&rdquo; in a way the loader can enforce.</p>
                <p>And the practical cost of a <code>.so</code> that is a shared object in name only &mdash; the mistake of shipping a PIC executable renamed:</p>
                <div class="hex-dump">
                    <pre>  the giveaway, and it is one command:

  $ readelf -dW libfoo.so | grep -c NEEDED
  0        &lt;-- it depends on NOTHING. so it provides
                nothing to anyone who needs it, and
                every symbol in it is undefined.

  a real library almost always needs libc, and DT_NEEDED
  is how you check whether the thing you built is a
  library or an executable that got the wrong -o flag.
</pre>
                </div>
                <p>Which is the cheapest sanity check in the subject, and worth knowing because the failure is otherwise baffling: a program links against the &ldquo;library&rdquo;, reports every symbol undefined, and there is nothing in the error message to suggest the file is not what you think it is. <a href="/courses/dyn/lessons/dyn-resolve">The artifact</a> uses exactly this: it refuses to treat an object with no <code>.dynsym</code> as a scope entry that can satisfy anything, and that is the same fact.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/dyn/assets/samples
$ ./build_samples.sh 2&gt;&amp;2 | sed -n '/D1/,/D2/p'
$ python3 crosscheck.py 2&gt;&amp;2 | sed -n '/\\[1\\]/,/\\[2\\]/p'
$ python3 dynscope.py exports liba.so
</pre>
                </div>
                <p>Then build the three-name scheme yourself, because it is four commands and it is what every packaged library on your system looks like:</p>
                <div class="hex-dump">
                    <pre>  1. Build a library with and without -soname. Link a
     program against each, and diff their DT_NEEDED.
     (One records libfoo.so.1, the other records
     libfoo.so.1.2.3. Then rename the file and see
     which program still runs.)

  2. Build with -fPIC but WITHOUT -shared, and with
     -shared but WITHOUT -fPIC. What does the linker
     say in each case, and is it the same diagnostic
     the reloc course recorded?

  3. Take liba.so and strip it: objcopy --strip-all.
     Does it still work? Which sections disappeared, and
     which of them was the interface?

  4. Build a library that references a symbol nobody
     defines. Does -shared accept it? (It must -- that
     is the point. When is the error raised instead,
     and by whom?)

  5. Count: how many sections does a trivial .so have,
     and how many of them can another process learn
     anything from? (Three: .dynsym, .dynstr, and the
     hash table that indexes them.)
</pre>
                </div>
                <p>Exercise 3 is the one that makes the interface/mechanism distinction permanent. <strong>Stripping a library removes <code>.symtab</code> and leaves <code>.dynsym</code></strong>, and the program that links against it does not notice, because it never looked at <code>.symtab</code>. The two tables have the same symbols in them and completely different audiences, and stripping is the cleanest demonstration that they really are different things rather than one table shown twice.</p>
                <p>Exercise 4 is the one that connects back to the whole course. A shared library with an unresolvable reference links cleanly &mdash; <strong>that is the definition of sharing</strong> &mdash; and the error is deferred to load time, when the scope search fails. Compare with a static link, where the same reference is an immediate error. <strong>Sharing moves the failure, and the next two modules are about what happens when it moves.</strong></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This opens the building module, and it is the mirror image of the <a href="/courses/elf/lessons/shared-libraries">ELF course&rsquo;s shared-libraries concept</a> in a way worth being explicit about. That course covered the three names and the commands that build one, and it was right to. <strong>What it could not show is what a shared library <em>is</em>, because every number in it came from a library someone else had built.</strong> This concept builds one and then looks at it: one exported symbol out of two functions, no <code>SONAME</code> because nobody set one, and a <code>DT_NEEDED</code> that records file names as a direct consequence.</p>
                <p>The connection to the <a href="/courses/reloc/lessons/pie-cost">Relocations course&rsquo;s cost measurement</a> is the reason <code>-fPIC</code> is mandatory here rather than a preference. That concept measured the exact price: 17 instructions against 9 for eight global reads, 10 bytes against 6 per reference, and a dependent load that cannot start until the address load retires. <strong>A shared library pays that cost on every global reference it makes, forever, and the alternative is not available</strong> &mdash; a non-PIC shared object is rejected by the linker with a diagnostic naming the relocation type.</p>
                <p>The second connection is to <a href="/courses/dyn/lessons/dyn-interpose">Interposition</a>, and it is the reason this concept exists in this position. Interposition works because the loader searches <code>.dynsym</code>. <strong>So the contents of <code>.dynsym</code> are not a packaging detail; they are the set of candidates for every search the loader will ever perform.</strong> A symbol in that list is reachable by any process on the system that loads this library; a symbol outside it is unreachable to everything except the debugger. This concept establishes the list, and <a href="/courses/dyn/lessons/dyn-export">the next one</a> is about controlling it.</p>
                <p>Forward within the module, the two remaining concepts split the question that &ldquo;what is in <code>.dynsym</code>&rdquo; raises into its two halves, and keeping them apart is the point of having both. <a href="/courses/dyn/lessons/dyn-export">Hiding Things, and the Trap</a> is about the <em>export</em> side: which names go in, and the flag that removes the ones you meant to keep. <a href="/courses/dyn/lessons/dyn-symbolic">One Instruction Called -Bsymbolic</a> is about the <em>binding</em> side: a name that <em>is</em> exported, and a call to it that should not be interposable. <strong>One is about who can see you; the other is about whether you can be seen.</strong></p>
                <p>And the connection forward into the run-time module is the failure this build deliberately permits. A shared library with an undefined reference is legal, which means the error is deferred to load time, and the mechanism that produces the error is the scope search. <a href="/courses/dyn/lessons/dyn-dlopen">dlopen, dlsym, and the Mode Bits</a> is the point at which the list grows at run time rather than at link time, and it is also the point at which a library can be loaded that the program never mentioned &mdash; which is a capability, an attack surface, and a debugging problem, in that order.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dyn/lessons/dyn-order-runtime">Previous: Breadth-First, and Why It Matters</a></span>
                <span>Next: <a href="/courses/dyn/lessons/dyn-export">Hiding Things, and the Trap</a></span>
            </div>
        </div>
    

    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
