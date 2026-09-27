// Object Files — Module 4: Merging and Selection
// Concept: the ar container, its symbol index, and why archive resolution is
// a fixed-point iteration rather than a single pass in either direction.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_obj_archives() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Archive — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson obj-lesson">
            <a href="/courses/obj" class="back-link">Back to course</a>
            <h1>The Archive</h1>
            <div class="lesson-meta">19 min &middot; Module 4: Merging and Selection &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Everything so far has assumed a flat list of object files on the command line. <strong>Real builds do not do that, and the reason is not tidiness.</strong> A C++ program links against thousands of object files and uses a small fraction of them. Hand a linker all three thousand and it drags in megabytes of code that nothing calls, and every one of those extra objects is another chance for a duplicate symbol from a library you did not know was there.</p>
                <p>The archive &mdash; <code>libfoo.a</code>, and on Windows the same container with a <code>.lib</code> extension &mdash; is the format that solves this. <strong>And the solution is a single idea: a member of an archive is a unit of <em>inclusion</em>, not a unit of storage.</strong> The bytes are all there; the linker is expected to take only the members something actually needs.</p>
                <p>Which raises the question this concept exists to answer, and it is a question about algorithms rather than bytes:</p>
                <div class="formula">
  app.o needs  add, mul, strlen_

  libdemo.a contains:
      mathlib.o   defines add, mul
      strlib.o    defines strlen_
      unused.o    defines nobody_calls_me

  Only the members that SATISFY A WANT get loaded.
  unused.o is not loaded, and there is no diagnostic,
  because not loading it is the entire point.
</div>
                <p>And the subtlety that makes it hard: <strong>a member you load can introduce a <em>new</em> want.</strong> Load <code>mathlib.o</code> because it defines <code>add</code>, and it turns out to call something in <code>strlib.o</code>. So the set of things to load is not known at the start &mdash; it is a fixed point, and getting there is the whole algorithm. <a href="/courses/obj/lessons/obj-comdat-group">The previous concept</a> was about which of two definitions survives; this one is about which of three hundred objects is loaded at all, and the two are the same question at different scales.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The container is older than almost everything else in this course and it is worth knowing why. <strong>The <code>ar</code> format is a plain sequence of 60-byte ASCII headers, each followed by a blob of bytes.</strong> No index of sections, no alignment requirement beyond &ldquo;members start on even offsets&rdquo;, and no type field for the contents. It predates ELF, COFF and Mach-O by a decade, and it has never been changed, because it does not need to be &mdash; <strong>its job is to be a bag of files, and it is a very good bag of files.</strong></p>
                <div class="hex-dump">
                    <pre>  "!&lt;arch&gt;\n"      8 bytes, no alignment, no padding
      then, repeating:
        a 60-byte ASCII header
        the member's bytes
        one pad byte if the size is ODD

  The 60 bytes, from a real file:

    offset  width  field        value in libdemo.a's first member
    ------  -----  -----------  ---------------------------------
      0      16   name          "/"               (the symbol index)
     16      12   mtime         "0"
     28       6   uid           "0"
     34       6   gid           "0"
     40       8   mode          "0"               (OCTAL)
     48      10   size          "52"              (DECIMAL)
     58       2   fmag          0x60 0x0a        ("`" then newline)
</pre>
                </div>
                <p>Two details in that table are traps, and both are still live in files produced today:</p>
                <ul>
                    <li><strong><code>size</code> is decimal and <code>mode</code> is octal, in the same header, ten bytes apart.</strong> That is not a typo in the specification; it is what <code>ar</code> has always done. A reader that parses <code>size</code> as octal turns member 1032 into 564 &mdash; and since the reader then seeks to the wrong place, <em>every subsequent member is garbage</em>, not just this one. It fails loudly if you validate, and silently if you do not.</li>
                    <li><strong>Odd-sized members need one pad byte</strong>, so that the next header starts on an even offset. Skipping the rule desynchronises the walk by exactly one byte per odd member, which is a spectacular way to spend an afternoon. <code>libdemo.a</code>'s three members are 1032, 1080 and 960 &mdash; all even, so no padding appears here &mdash; but the rule is unconditional.</li>
                </ul>
                <p>The <code>fmag</code> field is the container's one integrity check, and it is worth more than it looks. <strong>A 60-byte header whose last two bytes are not <code>0x60 0x0a</code> is not a header</strong>, which gives a reader a reliable way to know it has walked off the end &mdash; in a format with no table of contents and no total member count.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>The symbol index: the one thing an archive has that a linker needs</h3>
                <p>Opening <code>libdemo.a</code>, the very first member is not an object file at all. It is a <strong>symbol index</strong>, and it is the only piece of cleverness in the format:</p>
                <div class="hex-dump">
                    <pre>  00000008: 2f20 2020 2020 2020 2020 2020 2020 2020  /               
  00000018: 3020 2020 2020 2020 2020 2020 3020 2020  0           0   
  00000028: 2020 3020 2020 2020 3020 2020 2020 2020    0     0       
  00000038: 3532 2020 2020 2020 2020 600a            52        `.

  and its 52 bytes of body:

  00000044: 0000 0004 0000 0078 0000 0078 0000 04bc  .......x...x....
  00000054: 0000 0930 6164 6400 6d75 6c00 7374 726c  ...0add.mul.strl
  00000064: 656e 5f00 6e6f 626f 6479 5f63 616c 6c73  en_.nobody_calls
  00000074: 5f6d 6500                                _me.

    +0   count    BE u32   4          BIG-ENDIAN
    +4   offset   BE u32   0x78       add
    +8   offset   BE u32   0x78       mul
    +12  offset   BE u32   0x4bc      strlen_
    +16  offset   BE u32   0x930      nobody_calls_me
    +20  names    NUL-separated, in the SAME order:
                "add\0" "mul\0" "strlen_\0" "nobody_calls_me\0"
</pre>
                </div>
                <p>So the index is <strong>symbol name to the file offset of the member header that defines it</strong>. Note that <code>add</code> and <code>mul</code> both point at <code>0x78</code>: one member, two symbols, one entry in the array each. And note the byte order, because it is the opposite of the object files inside:</p>
                <div class="callout callout-warn">
                    <strong>The index is big-endian; the ELF objects it points at are little-endian.</strong> A reader that uses one byte order for the whole file gets offsets like <code>0x78000000</code> and finds nothing. <strong>This is a historical fossil</strong> &mdash; the format's <code>ar</code> roots are from an era when the convention for such tables was network order, and it was never worth breaking. GNU <code>ar</code> also writes a <em>second</em> index, marked by a <code>0x02</code> byte, which is little-endian; the <a href="/courses/coff/lessons/coff-archives">COFF course found both in a <code>.lib</code></a> and confirmed they disagree about the <em>order</em> of the entries as well as the byte order. So the practical rule for a reader is: try big-endian, and fall back.
                </div>

                <h3>Member names: two spellings, one of which is a trap</h3>
                <p>Here is the header of the first real member, at <code>0x78</code>:</p>
                <div class="hex-dump">
                    <pre>  00000078: 6d61 7468 6c69 622e 6f2f 2020 2020 2020  mathlib.o/      
  00000088: 3020 2020 2020 2020 2020 2020 3020 2020  0           0   
  00000098: 2020 3020 2020 2020 3634 3420 2020 2020    0     644     
  000000a8: 3130 3332 2020 2020 2020 600a            1032      `.
</pre>
                </div>
                <p><strong>The name is <code>mathlib.o/</code> &mdash; with a trailing slash and nothing after it.</strong> That slash is not part of the name, and it is not a long-name reference either. It is a <em>terminator</em>: in this format a trailing <code>/</code> marks where the name ends, and the name is space-padded to 16 bytes. The alternative spelling is <code>/NN</code>, where <code>NN</code> is a <strong>decimal</strong> offset into a long-name table held in a second special member called <code>//</code>, used for names longer than 15 characters.</p>
                <p>So a reader faces a genuine ambiguity: a name starting with <code>/</code> could be a long-name reference, and <code>mathlib.o/</code> ends in a slash. <strong>The disambiguation is that the digits must follow immediately</strong> &mdash; here they are spaces, so it is a terminator. And the second trap is that <code>NN</code> is decimal: the COFF course's <code>demo.lib</code> had a section named <code>/45</code>, and reading that as hex lands at offset 0x45 = 69, which is in the middle of the symbol names rather than at the start of the long-name string.</p>

                <h3>What the linker actually does, proven by the map file</h3>
                <p>None of the above tells you whether any of it works. <code>ld -Map=</code> does, and it prints exactly the decision:</p>
                <div class="hex-dump">
                    <pre>  $ ld -o app -Map=app.map app.o libdemo.a
  $ sed -n '/Archive member included/,/^$/p' app.map

  Archive member included to satisfy reference by file (symbol)

  libdemo.a(mathlib.o)          app.o (add)
  libdemo.a(strlib.o)           app.o (strlen_)
</pre>
                </div>
                <p><strong>Two members listed. <code>unused.o</code> is not mentioned anywhere in the map</strong> &mdash; not as included, not as discarded, not at all. The link succeeded, produced a working binary, and <code>nobody_calls_me</code> is simply not in it. That is the entire point of the format, and it is the reason the map file is such good evidence: it distinguishes <em>not loaded</em> from <em>loaded and thrown away</em>, which look identical in the output binary.</p>
                <p>And the same map answers the harder question. <code>libchain.a</code> holds three objects whose dependencies run in the opposite order to their physical arrangement in the archive:</p>
                <div class="hex-dump">
                    <pre>  $ ar rcs libchain.a l2.o l3.o l1.o     physical order
  $ ar t libchain.a
  l2.o
  l3.o
  l1.o

  $ ld -o chain -Map=chain.map main.o libchain.a

  Archive member included to satisfy reference by file (symbol)

  libchain.a(l1.o)              main.o (level1)
  libchain.a(l2.o)              libchain.a(l1.o) (level2)
  libchain.a(l3.o)              libchain.a(l2.o) (level3)
</pre>
                </div>
                <p>Read the second column. <strong><code>l2.o</code> was pulled in by a want created by <code>l1.o</code>, which was itself pulled in by a want in <code>main.o</code>.</strong> And <code>l1.o</code> is the <em>last</em> member in the file, while <code>l2.o</code>, which it needs, is the <em>first</em>. A single left-to-right pass would visit <code>l2.o</code> while nothing wanted <code>level2</code> yet, skip it, and then arrive at <code>l1.o</code> too late to go back.</p>

                <h3>So: backwards, or iterate? The decisive test</h3>
                <p>&ldquo;Linkers read archives backwards&rdquo; is a thing people say, and it is <strong>not what GNU ld does</strong>. The way to settle it is to build an archive where a backwards pass also fails, and see whether the link succeeds:</p>
                <div class="hex-dump">
                    <pre>  $ ar rcs libfwd.a l2.o l1.o l3.o
  $ ld -o fwd -Map=fwd.map main.o libfwd.a

  Archive member included to satisfy reference by file (symbol)

  libfwd.a(l1.o)                main.o (level1)
  libfwd.a(l2.o)                libfwd.a(l1.o) (level2)
  libfwd.a(l3.o)                libfwd.a(l2.o) (level3)
</pre>
                </div>
                <p>With this order, a <strong>forward</strong> pass provably cannot work: <code>l2.o</code> is passed before anything wants <code>level2</code>. And a <strong>backward</strong> pass also cannot work: reading <code>l3.o</code>, <code>l1.o</code>, <code>l2.o</code>, the <code>l1.o</code> pull happens second and wants <code>level2</code>, which is still ahead of the cursor. <strong>Both single passes fail, and the link succeeded anyway.</strong></p>
                <p>So the algorithm is a <strong>fixed-point iteration</strong>: repeat the scan until a complete pass loads no new member. The number of passes is bounded by the number of members, so the naive implementation is quadratic, and real linkers use the index plus a worklist to get close to linear. <strong>But the correctness point is the one worth keeping, and it is not an optimisation detail: any implementation that assumes one pass in a fixed direction is wrong, and it will be wrong only for archives whose members happen to be in an unlucky order.</strong> That is the worst possible failure mode &mdash; correct on almost every build you test, wrong on someone else's.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Putting it together, the whole algorithm in one block, with the archive's own data showing where each step gets its information:</p>
                <div class="formula">
  GIVEN  app.o, libdemo.a
         index: add-&gt;0x78  mul-&gt;0x78  strlen_-&gt;0x4bc
                nobody_calls_me-&gt;0x930

  PASS 1
    wants  add, mul, strlen_            from app.o's undefined syms
    for each want, in turn:
        add     -&gt; 0x78   not loaded  -&gt; LOAD mathlib.o
        mul     -&gt; 0x78   already loaded, skip
        strlen_ -&gt; 0x4bc  not loaded  -&gt; LOAD strlib.o
    loading mathlib.o adds no new wants
    loading strlib.o  adds no new wants
    nobody_calls_me is in the INDEX and is never wanted
    -&gt; nothing new was loaded.  STOP.

  RESULT: 2 of 3 members in the output.
          unused.o was indexed, never wanted, never read.
</div>
                <p>Three things in that pseudocode are worth drawing out, because each is a decision a format forced.</p>
                <p><strong>First: the index is consulted by name, and the member is only then read.</strong> A linker that read every member and discarded the useless ones would get the same answer and be dramatically slower &mdash; and would be <em>wrong</em> in one specific case, which the <a href="/courses/coff/lessons/coff-archives">COFF course</a> found: a member with no <em>external</em> symbols cannot appear in the index at all, so an index-driven linker will never load it, and a linker that reads everything will load it and may report duplicate definitions that the index-driven linker never sees. <strong>The index is not an optimisation; it is a semantic commitment about which members are eligible.</strong></p>
                <p><strong>Second: the index maps one name to one offset, and that is a claim the linker trusts.</strong> Here the claim is checkable, and the course checks it. Each member's own ELF symbol table independently lists what it defines, so the index can be cross-verified against the members &mdash; and the two agree:</p>
                <div class="hex-dump">
                    <pre>  index says            member at that offset defines
  -------------------   -----------------------------------------
  add      -&gt; 0x78      0x78 mathlib.o   [3] add   GLOBAL
  mul      -&gt; 0x78      0x78 mathlib.o   [4] mul   GLOBAL
  strlen_  -&gt; 0x4bc     0x4bc strlib.o   [3] strlen_ GLOBAL
  nobody_calls_me -&gt; 0x930  0x930 unused.o  [3] nobody_calls_me GLOBAL
</pre>
                </div>
                <p><strong>Two independent records of the same fact, so the index is verifiable without trusting the tool that wrote it.</strong> That is the property that makes an archive auditable at all, and it is the same property the <a href="/courses/obj/lessons/obj-verify">verification concept</a> is built on. Run <code>python3 ardec.py libdemo.a</code> to see the whole thing decoded field by field.</p>
                <p><strong>Third: the &ldquo;already loaded, skip&rdquo; case is not an optimisation either.</strong> <code>add</code> and <code>mul</code> both map to <code>0x78</code>. A linker that loaded a member per <em>symbol</em> would put <code>mathlib.o</code> in the output twice, and the second copy's symbols would collide with the first's &mdash; producing a <code>multiple definition</code> error for a library that is perfectly fine. <strong>Which is the whole reason the index maps to a member rather than to a symbol.</strong></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ cd courses/obj/assets/samples
$ python3 ardec.py libdemo.a          # decode every field, written from the spec
$ ar t libdemo.a ; xxd -l 128 libdemo.a
$ ld -o /tmp/app -Map=/tmp/app.map app.o libdemo.a &amp;&amp; grep -A4 'Archive member' /tmp/app.map</code></pre>
                <ul>
                    <li><strong>Decode <code>libdemo.a</code> entirely by hand before running the tool.</strong> Read the 8-byte magic, the 60-byte index header, and the 52 index bytes; confirm the count is <strong>big-endian</strong> by re-reading the first four bytes; then find each member header and read its decimal size. <strong>Verify the sizes add up</strong> &mdash; 8 + 60 + 52 + (60 + 1032) + (60 + 1080) + (60 + 960) = 3372, which is the file's exact size. That arithmetic is the format's only structural integrity check, and it is worth doing once by hand.</li>
                    <li><strong>Break the decimal-size rule and watch the reader desynchronise.</strong> Copy <code>libdemo.a</code>, and in the first member header change <code>52</code> to <code>040</code>. <strong>Run <code>ardec.py</code> on the result.</strong> The first member's body will be 40 bytes instead of 52, the next header read will start 12 bytes early, <code>fmag</code> will not be <code>0x60 0x0a</code>, and the walk will stop &mdash; if you implemented the <code>fmag</code> check. If you did not, it will keep printing garbage. <strong>This is the best possible demonstration that an integrity check in an ASCII header is worth more than it appears.</strong></li>
                    <li><strong>Prove the fixed-point claim yourself rather than taking it on trust.</strong> Build the four-member chain and make <strong>four</strong> archives with the members in four different orders, including <code>l2, l1, l3</code> where a forward pass fails and <code>l3, l1, l2</code> where a backward pass fails. <strong>Link all four and confirm all four succeed</strong> with identical output. <strong>Then, to make the point sharp, write a deliberately single-pass-forward linker over the index and show that it fails on one of the four orders and succeeds on the others.</strong> A bug that only reproduces on unlucky input is the kind that reaches production.</li>
                    <li><strong>Find a member with no external symbols and see what the index does.</strong> Compile a file containing only <code>static int helper(void)</code> returning 1, and nothing else &mdash; nothing with external linkage &mdash; put it in an archive, and look at the index. <strong>It will not appear.</strong> Then work out the consequence: <code>main</code> cannot call it, so nothing is broken, and that is exactly why the index may leave it out. <strong>The index lists what the outside world is allowed to ask for, not what is in the bag.</strong></li>
                    <li><strong>Compare the two indexes in a Windows <code>.lib</code>.</strong> The COFF course's <code>ar_decode.py</code> and <code>demo.lib</code> are in <a href="/courses/coff">the COFF samples</a>. Run it and find both index members. <strong>Confirm the byte order differs between them, and that the entry order differs too</strong> &mdash; one is link order, the other sorted. Then decide which one your reader should use, and write down the fallback rule you would implement if the first guess is wrong.</li>
                    <li><strong>Measure what the archive actually saves.</strong> Link <code>app.o</code> against <code>libdemo.a</code> and against the three objects directly, and compare the sizes of the <code>.text</code> sections in the map file. <strong>Then check that the <em>unreferenced</em> member really is absent</strong> by searching the output for <code>nobody_calls_me</code> in both the symbol table and the raw bytes. An archive that appears to work but quietly included everything would show up here and nowhere else.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a linker reads an archive's symbol index, finds that a member defines a wanted symbol, and loads it. That member's own undefined references are then resolved against the same index, which pulls in a second member, and so on. Someone tells you that &ldquo;linkers read archives backwards so that this works.&rdquo; What is wrong with that explanation, and what is the correct one?</p>
                <div class="quiz" id="quiz-obj-archives-1">
                    <button class="quiz-option" data-correct="true" data-explain="The explanation is wrong because it names a direction where the actual requirement is a fixed point, and the difference is not academic -- it is the difference between an algorithm that is always right and one that is right on most inputs. A backwards scan is a heuristic that happens to work for the common case, where members are appended in dependency order and so tend to depend on earlier members. Construct the case where it fails: put the members in the order l2, l1, l3. A forward pass visits l2 while nothing wants level2, skips it, reaches l1, which wants level2, and cannot go back. A backward pass visits l3, then l1, which wants level2, and l2 is still ahead of the cursor. Both directions fail, and yet GNU ld links this archive successfully -- which is only possible if it is not making a single pass in either direction. What it does instead is repeat the scan until a complete pass produces no new members, which is correct for every ordering. The number of passes is bounded by the member count, so the naive form is quadratic, and real linkers use the index plus a worklist to approach linear. But the correctness argument does not depend on the optimisation at all, and that is the transferable part: whenever the set of things to load is defined by the things loaded, you have a fixed point, and a single pass in a fixed order is a bet that the input happens to be sorted." onclick="checkQuiz('obj-archives-1', this)">It names a direction where the requirement is a <strong>fixed point</strong>. A backwards scan is a heuristic that works when members happen to be stored in dependency order. Build an archive in the order <code>l2.o, l1.o, l3.o</code> and <strong>both single passes provably fail</strong> &mdash; forward skips <code>l2</code> before anything wants it, backward reaches <code>l1</code> while <code>l2</code> is still ahead &mdash; yet the link succeeds, so the linker must be repeating the scan until a pass loads nothing new</button>
                    <button class="quiz-option" data-correct="false" data-explain="The conclusion is right -- it is not a single backwards pass -- but the reasoning reaches it by a route that would mislead anyone who tried to implement from it, because it treats the direction as the variable and the iteration as an optimisation. The direction is not the variable at all. What determines correctness is only whether a member loaded late in the scan can cause a member already passed to be loaded, and the moment that is possible no fixed ordering of the scan suffices. Backwards is just one particular choice of ordering, and it happens to work for archives whose members are stored in the order they were compiled, which is the common case and the reason the myth is so durable. The measurement is the part that matters and it does support the conclusion: with the order l2, l1, l3, a forward pass cannot work because l2 is passed before anything wants level2, and a backward pass cannot work either because l1 is reached while l2 is still ahead of the cursor. Both fail; the link succeeded. So the answer is a fixed point. The error is in calling the repeated scan an optimisation of the backwards strategy. It is not a faster way to do the same thing -- it is a different and strictly more general algorithm, and it is the general one that is correct. A reader who believed the optimisation framing would reasonably try to optimise the backwards scan, and would end up with a fast wrong answer." onclick="checkQuiz('obj-archives-1', this)">It is wrong because the direction is not fixed &mdash; the linker must handle the case where a member loaded late creates a want for a member already passed, and it does so by rescanning. Reading backwards is only an <em>optimisation</em> of that, valid because members are usually stored in dependency order, and a general linker cannot rely on that</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a linker and you have implemented archive resolution as a single forward pass over the index: for each symbol in your current set of undefined references, look it up, and if its member is not loaded, load it and add that member's undefined references to the set. It works on every library you have tested, and on your own machine it never fails. A user's build fails with <code>undefined reference to 'level3'</code> from a member that is demonstrably present in the archive and listed in its index. What is wrong, what would have made the bug appear in your own testing, and what is the smallest change that fixes it without making the common case slower?</p>
                <div class="quiz" id="quiz-obj-archives-2">
                    <button class="quiz-option" data-correct="true" data-explain="The bug is a single pass over a set that the pass itself mutates, and the reason it survives local testing is that it is correct on every archive whose members happen to be ordered so that each one only needs members that come later. That is the normal case, because archives are built by appending objects in compilation order and dependencies usually point backwards, so the pass gets lucky almost always. What would have exposed it is generating the order rather than inheriting it: build a small archive with a deliberate dependency chain and permute the members, and the failure appears on the permutations where a member's dependency precedes it. That is a test-design point as much as a bug point -- a test that only uses naturally ordered inputs cannot distinguish a correct algorithm from one that is correct by coincidence. The smallest change that is also not slower in the common case is to keep the single pass and add a bounded outer loop: repeat the whole pass while it loaded at least one member. In the common case where nothing new is loaded, that costs exactly one extra pass over the index, which is cheap because the index is small and already parsed. The version to avoid is the naive repeated rescan, which is quadratic in the number of members; that is the right answer to the wrong question. The general principle is that when the thing you are iterating over is modified by the body of the loop, you have written a fixed point and you must iterate to one -- checking for progress rather than assuming it." onclick="checkQuiz('obj-archives-2', this)">You mutated the set you are iterating over, so a single pass can miss a member whose want is created after it was passed. It survived because every library you tested happens to be ordered so that members only need later ones, which is the normal build order &mdash; <strong>what would have exposed it is permuting the member order in a small purpose-built archive</strong>. Fix it by keeping the single pass and wrapping it in a loop that repeats while the pass loaded something, so the common case costs one extra pass over a small index rather than a full quadratic rescan</button>
                    <button class="quiz-option" data-correct="false" data-explain="The diagnosis is right and the fix is the right shape, but the framing of why it never failed locally is wrong in a way that leads to a bad test design. The claim that the pass only fails when a member's dependency comes earlier in the archive is not what distinguishes the working cases from the failing one, and building a test that only checks that condition will not find the bug. What actually distinguishes them is whether a single forward pass happens to reach each member after every member that needs it. Those two conditions coincide often, which is why the intuition feels right, but they are not the same condition and they come apart in exactly the case that breaks. Consider a three-member chain in the order l2, l3, l1. A forward pass reaches l1 last, l1 wants level2, and l2 is already behind the cursor -- so the dependency points backwards in the array, which is the case the proposed test would exercise. Now consider the order l3, l2, l1: the pass reaches l1, l1 wants level2 which was passed, fails again. Here l3 is needed by l2 and precedes it, and the proposed test would call that a passing case, so the test would pass on an input that breaks the linker. The test needs to be a permutation sweep, generating several orderings of a small dependency chain and requiring the linker to succeed on all of them, because the property under test is not about the direction of any one dependency but about whether the algorithm reaches a fixed point at all." onclick="checkQuiz('obj-archives-2', this)">You mutated the set you are iterating over, so a single pass can miss a member whose want is created after it was passed. It survived because every library you tested happens to be ordered so that no member needs an <em>earlier</em> member. <strong>What would have exposed it is a test with one member deliberately needing an earlier one</strong>. Fix it by repeating the pass until it loads nothing new, and make the common case cheap by keeping a worklist of newly-undefined symbols rather than rescanning the whole index</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: if the body of your loop modifies the collection you are looping over, you have written a fixed point and must iterate to one. And if a bug never reproduces locally, suspect that your inputs are ordered the way your algorithm happens to require.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>An archive is a container format, and this is the first one in the course, so it is worth noticing what it shares with the three object formats and what it does not. <strong>It shares their central idea &mdash; a container with a table of contents and no schema &mdash; and it differs in having almost no structure at all.</strong> No section table, no symbol table of its own, no alignment rules, no versioning. <a href="/courses/obj/lessons/obj-strings">Where Names Live</a> found three strategies for storing a name; the archive picks the crudest possible one, a 16-byte space-padded ASCII field, because a member's name is not something anything has to look up efficiently &mdash; only the index is looked up, and the index stores offsets, not names.</p>
                <p>The connection to <a href="/courses/obj/lessons/obj-symbols">Symbol Tables, Compared</a> is the strongest one, and it is about a distinction people rarely make. <strong>An object's symbol table answers two different questions: what does this file define, and what does this file want?</strong> The archive's index answers only the first, and only for symbols that are <em>externally visible</em>. That is why a <code>static</code> function never appears in an index, and it is a genuinely different notion of &ldquo;symbol&rdquo; from the one an object file's <code>STB_LOCAL</code> entries represent. <strong>A linker resolves against the union of undefined references and index entries; an archive is a filter applied to the first before it is used to answer the second.</strong></p>
                <p>The fixed-point algorithm connects to <a href="/courses/obj/lessons/obj-the-hole">A Hole and a Record</a> in a way worth stating, because it reframes the archive. <strong>An unresolved hole does not stay a hole when the link ends &mdash; it becomes an error.</strong> So the linker must, at the end, be certain that no wanted symbol is satisfiable, and the archive index is how it establishes that without reading every member. <strong>The index is therefore not a cache; it is the evidence for a negative conclusion.</strong> If a name is in no index and not defined by any object on the command line, it is genuinely unresolvable &mdash; and a linker that skipped unread members could not draw that conclusion, which is why the index's coverage is semantic rather than incidental.</p>
                <p>On the correctness side there is a security consequence that connects to <a href="/courses/pe">the PE course</a>, and it is the reason archives are a recurring source of real bugs. <strong>Which members get loaded depends on the order, the index, and the set of undefined symbols at the time each archive is considered</strong> &mdash; so changing the order of libraries on a link line can change which code is in the binary, with no error and often no obvious symptom. That is a supply-chain surface, not just a build nuisance: it is why reproducible builds fix library order, and why <code>--start-group</code>/<code>--end-group</code> and <code>--as-needed</code> exist. <strong>An archive makes the linker's output depend on a piece of data &mdash; the index &mdash; that a reader is very likely to regenerate rather than verify.</strong></p>
                <p>And the <a href="/courses/coff/lessons/coff-archives">COFF archives</a> connection is the payoff of the whole course's cross-format method. <strong>A Windows <code>.lib</code> is the same container</strong>, with the same <code>!&lt;arch&gt;\n</code> magic, the same 60-byte headers, the same <code>//</code> long-name table, and two different symbol indexes instead of one. <strong>Which means everything in this concept applies to PE linking unchanged</strong>, and it is the clearest demonstration in the collection that a container format outlives the object formats it carries.</p>
                <p>Next: the last of the three selection mechanisms, and the one with the smallest file footprint &mdash; because unlike an archive, a weak symbol costs one bit and is always available.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/obj/lessons/obj-comdat-group">Previous: COMDAT, GROUP, linkonce</a></span>
                <span>Next: Weak and Undefined-Weak</span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
