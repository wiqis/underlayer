// Executable Security and Hardening — Module 2: The GOT
// Concept: a compile-time fact turned into a runtime argument, and a retraction.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sec_fortify() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("FORTIFY Leaves a Trace — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson sec-lesson">
            <a href="/courses/sec" class="back-link">Back to course</a>
            <h1>FORTIFY Leaves a Trace</h1>
            <div class="lesson-meta">23 min &middot; Module 2: The GOT &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every other hardening feature in this course leaves a bit in a header: a segment flag, a dynamic tag, a property note. <strong>FORTIFY leaves nothing, and that is why it is the one most often assumed rather than verified.</strong> There is no <code>FORTIFY</code> bit anywhere in an ELF file. What there is, is a different set of imports.</p>
                <div class="hex-dump">
                    <pre>$ cd courses/sec/assets/samples &amp;&amp; ./build_samples.sh 2&gt;&amp;1 | sed -n '/H4/,/H5/p'
  which libc entry points each level calls:
   level 0  printf read strcpy strlen
   level 1  printf __read_chk __strcpy_chk strlen
   level 2  __read_chk __strcpy_chk strlen __vprintf_chk
   level 3  __read_chk __strcpy_chk strlen __vprintf_chk
</pre>
                </div>
                <p>That table is the whole feature. <strong>Level 1 replaces <code>strcpy</code> with <code>__strcpy_chk</code> and <code>read</code> with <code>__read_chk</code>. Level 2 adds <code>__vprintf_chk</code>, because <code>%n</code> is a write primitive wearing a format-string costume.</strong> And if your binary calls <code>__strcpy_chk</code> you are fortified; if it calls <code>strcpy</code> you are not, whatever your build script says.</p>
                <p>That makes FORTIFY the cheapest thing in this course to audit and the easiest to get wrong. <a href="#unit-example">One <code>objdump</code> and a pattern</a>, no flags, no build system, no cooperation from the person who compiled it.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>What the compiler is actually able to do, and why the mechanism is arithmetic rather than inspection:</p>
                <div class="formula">
  the check libc performs is trivial:

      if (length &gt; known_size) __chk_fail();

  the hard part is that libc has NO idea
  how big your buffer is. it cannot. the
  information exists only in the COMPILER,
  which saw the declaration.

  so the compiler passes it:

      mov $0x20, %edx          &lt;-- 32
      call __strcpy_chk@plt

      0x20 is sizeof of the destination
      local. a fact the compiler knew
      statically, now an ARGUMENT.

  this is the whole trick. FORTIFY does not
  inspect anything at run time. it moves a
  compile-time fact across the boundary so a
  runtime check can use it.
                </div>
                <p>And that immediately gives the precondition, which is the part that decides whether FORTIFY applies to your code at all:</p>
                <div class="formula">
  FORTIFY needs a KNOWN OBJECT SIZE.

    char b[32]; strcpy(b, s);
        -> 32 is known. CHECKED.

    void g(char *d, char *s, unsigned n)
        -> memcpy(d, s, n), where d's size is
           unknown to the compiler. nothing to
           check. left ALONE.

    char *p = malloc(n); strcpy(p, s);
        -> same. malloc's size is a run-time
           value, so the compiler has nothing.

  so FORTIFY protects FIXED-SIZE objects.
  heap buffers, which are where the really
  dangerous overflows live, are largely
  outside its reach -- and no amount of
  -D_FORTIFY_SOURCE changes that.
                </div>
                <p>So the feature has a shape worth memorising: <strong>it is a compile-time technique with a compile-time precondition.</strong> It cannot be retrofitted, it cannot be applied dynamically, and it declines to act whenever the information it needs is not there. Declining to act is the correct behaviour &mdash; a check against a guessed size would be worse than none.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Measured, Including Where It Did Not Fire</h2>
                <p>The levels, from a specimen whose destination is a real local:</p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/H4/,/H5/p'
  level 0  no checks at all
  level 1  strcpy -&gt; __strcpy_chk, read -&gt; __read_chk (size known)
  level 2  adds printf -&gt; __vprintf_chk, because %n is a write primitive
  level 3  adds compile-time DIAGNOSIS for a known-too-large count;
          this specimen has no such call, so 2 and 3 agree here.
</pre>
                </div>
                <p>Level 3 agreeing with level 2 is a fact about <em>this specimen</em>, not about level 3, and the distinction is the point. <strong>Level 3 differs from level 2 for a set of functions this program does not call.</strong> A reader who concluded &ldquo;level 3 adds nothing&rdquo; from this table would be wrong in general and right by accident, which is the most dangerous way to be wrong.</p>
                <p>And now the retraction, which is in the build script and the crosscheck and here:</p>
                <div class="hex-dump">
                    <pre>  A RETRACTION, kept because it is the honest result: a known-size
  destination was expected to produce __memcpy_chk. clang 21 does
  NOT emit it -- both rows call plain memcpy. strcpy becomes
  __strcpy_chk reliably; memcpy does not, even with a statically
  known 4096-byte destination. The rule was not determined from
  source and is not claimed here.
</pre>
                </div>
                <p><strong>The claim retracted was: a compile-time-known destination size makes FORTIFY substitute <code>__memcpy_chk</code>.</strong> Measured, it does not on clang 21. <code>char b[4096]; memcpy(b, s, 2048);</code> compiles to a plain <code>memcpy</code> call at <code>_FORTIFY_SOURCE=3</code>. <code>strcpy</code> is reliable; <code>memcpy</code> was not, for a reason this course did not determine from source and therefore does not assert.</p>
                <p>This is worth dwelling on, because it is the most important methodological point in the course. <strong>&ldquo;FORTIFY works&rdquo; is a claim about a set of functions, and the set is not the set you would guess from the function names.</strong> If this course had asserted the tidy version, every reader would have learned a false thing that happens to be false in a way that is invisible until you look for the <code>__memcpy_chk</code> that is not there. A retraction in a build script is more useful than a caveat in prose, because <strong>the crosscheck asserts the retraction and will fail if a future compiler starts emitting it.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>Auditing a Binary You Did Not Build</h2>
                <p>Since the trace is the imports, the audit is one pattern. And it is worth doing on binaries you have no build system for:</p>
                <div class="hex-dump">
                    <pre>$ objdump -d /usr/bin/somebinary | grep -oE '&lt;[a-z_]+@plt&gt;' \
    | sort -u | grep -E 'str(cpy|cat|cmp|ncpy)|mem(cpy|set)|sprintf|read|printf'

$ python3 harden.py /usr/bin/somebinary | grep FORTIFY
  FORTIFY _chk imports               __memcpy_chk, __printf_chk, __sprintf_chk, __strcpy_chk
</pre>
                </div>
                <p>Two observations worth making about that output. <strong>The set is mixed</strong> &mdash; a binary can import both <code>strcpy</code> and <code>__strcpy_chk</code>, because FORTIFY applies per call site and only where the size is known. And <strong>the presence of one <code>_chk</code> import says nothing about the calls that were left alone.</strong> A report that prints &ldquo;FORTIFY: yes&rdquo; is summarising four <code>_chk</code> calls as if they covered the program. The honest report is the list, which is what the artifact prints.</p>
                <p>Now connect it to <a href="/courses/sec/lessons/sec-canary">the canary</a>, because the H2 table gives the comparison and it is the most useful thing in the course:</p>
                <div class="formula">
            case  what overflows        canary   FORTIFY
            ----  ------------------    ------   -------
             a    a global             silent   CAUGHT
             b    its own local        CAUGHT   CAUGHT
             c    a global, no local   silent   CAUGHT

  the canary is a property of WHERE THE
  CHECK LIVES -- the frame.

  FORTIFY is a property of WHAT THE CODE
  SAYS -- this copy, this known size.

  so they are not nested and not
  redundant. they have different reach, and
  a hardened build wants both. gcc at -O1
  gives you both by default, which is the
  best default in this entire course and is
  also the most likely to be lost by
  switching compilers.
                </div>
                <p>That table is the argument for reading a binary rather than a build script, stated as a mechanism. <strong>A policy that says &ldquo;FORTIFY on&rdquo; is a policy about an unknown fraction of your call sites; the table tells you which fraction.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/sec/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/H4/,/H5/p'
$ python3 harden.py fort_0 fort_2
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/H4/,/H5/p'
</pre>
                </div>
                <p>Then find the boundary, which is the better exercise:</p>
                <div class="hex-dump">
                    <pre>  1. Take the FORTIFY table and make level 3
     differ from level 2. You need a call
     whose count the compiler knows and can
     see is too large:
       char b[8];
       memcpy(b, huge_known_array, 4096);
     Level 3 should DIAGNOSE it rather than
     emit a check. What exactly does it say,
     and is it an error or a warning? (This is
     the difference between the two levels and
     the table in H4 could not show it.)

  2. Now make FORTIFY vanish without touching
     any flag. Add -U_FORTIFY_SOURCE, or
     compile at -O0. Which one removes it?
     (Optimisation level: at -O0 the compiler
     does not know the object sizes, so
     FORTIFY has nothing to work with. FORTIFY
     REQUIRES optimisation, which is a strange
     and important dependency: your hardening
     gets weaker when you compile for
     debuggability.)

  3. Heap buffers. Write:
       char *p = malloc(16);
       strcpy(p, argv[1]);
     at every level. What appears in the
     imports? (Nothing changes. FORTIFY cannot
     help here, and this is the single most
     important limitation to know -- because
     heap overflows are what most real
     exploitation looks like.)

  4. Take a real system binary and count its
     fortified and unfortified string calls
     separately:
       objdump -d /usr/bin/ls | grep -c 'strcpy@plt'
       objdump -d /usr/bin/ls | grep -c '__strcpy_chk@plt'
     Both may be non-zero. Report the ratio,
     not a verdict.

  5. Read the FORTIFY header on this system --
     /usr/include/bits/fortify*.h -- and find
     which functions are redirected at which
     level. Then check your level-1 specimen
     against that list. Does the specimen
     match the header's table? (It should, and
     if it does not, the header is describing a
     different compiler than the one you have.
     That is a real and common situation, and
     it is why the course measures rather than
     cites.)
</pre>
                </div>
                <p>Exercise 2 has the most valuable answer in the course, and it is not a bug. <strong>FORTIFY gets weaker when you lower the optimisation level.</strong> At <code>-O0</code> the compiler does not track object sizes the way it does at <code>-O1</code>, so it has nothing to pass to <code>__strcpy_chk</code> and the substitution does not happen. Your debug build is therefore <em>less</em> fortified than your release build, using the same source, the same flags, and the same headers &mdash; and the difference is invisible unless you look at the imports.</p>
                <p>Exercise 3 is the limitation that matters most in practice, and the course states it plainly rather than leaving it implied. <strong>FORTIFY is close to useless against heap overflows</strong>, because <code>malloc</code>&rsquo;s size is a run-time value and the compiler has nothing to check against. If your threat model is heap corruption &mdash; and for most real exploitation it is &mdash; then the canary and RELRO are doing the work and FORTIFY is a bonus. Knowing which mechanism covers which bug class is the point of the H2 table, and it is a better answer than a list of flags.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The connection to <a href="/courses/sec/lessons/sec-canary">the canary concept</a> is the whole of the previous unit and it is the closest thing in this course to a genuine result rather than a survey. <strong>Two mechanisms, two different kinds of check, measurably different reach.</strong> That is only visible because both were turned on in one build and off in another, and the same three overflows were run against both. The general lesson is the one this collection keeps teaching in a new costume: <em>to know what a feature covers, measure it against the thing it is supposed to catch</em> &mdash; do not read its documentation.</p>
                <p>The connection to <a href="/courses/sym/lessons/sym-version">the symbol-resolution course&rsquo;s versioned-symbols concept</a> is a nice piece of ABI plumbing. That course measured <code>__strcpy_chk@GLIBC_2.3.4</code> as a versioned symbol and asked why the version matters. <strong>Here is the answer in a different key: <code>__strcpy_chk</code> is only a legal call if the runtime libc is new enough to provide it, and the version tag is how the dynamic linker enforces that.</strong> Adding a fortified call to a binary changes its minimum glibc requirement &mdash; a real deployment consequence of a compile-time flag, and one that belongs to the ABI rather than to the security story.</p>
                <p>Two connections that close the module. <a href="/courses/sec/lessons/sec-relro">The RELRO concept</a> explained that <code>-z now</code> is what makes sealing the GOT possible, because the loader must finish writing first. <strong>FORTIFY is the same shape one layer down: it makes a check possible by moving a fact across a boundary.</strong> Both are &ldquo;do the expensive thing at compile time so a cheap thing is possible at load or run time&rdquo;, and both have a precondition that is easy to forget &mdash; a loader that has finished, a compiler that knew the size. And <a href="/courses/sec/lessons/sec-posture">the posture concept</a> is where this row of the report comes from, and it is a row that has to be an <em>import list</em> rather than a bit, which is the awkward one.</p>
                <p>Finally, the honest boundary. <strong>This concept is glibc and x86-64 Linux.</strong> The <code>__*_chk</code> naming, which functions are covered, and the level structure are all glibc conventions; a different libc spells the idea differently and may cover a different set. The <em>mechanism</em> &mdash; pass a compile-time-known size across the ABI boundary so the library can check &mdash; is portable and the method transfers, but the retraction above is a reminder that <strong>the specific set is a property of a specific compiler version and has to be re-measured when that changes.</strong> The crosscheck does exactly that, which is the point of having written it.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/sec/lessons/sec-relro">Previous: The Two Tiers of RELRO</a></span>
                <span>Next: <a href="/courses/sec/lessons/sec-wx">W^X, and Why TEXTREL Died</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
