// Dynamic Linking and Shared Libraries — Module 1: The Scope
// Concept: level-by-level or branch-by-branch, measured from the loader's own
// load order.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dyn_order_runtime() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Breadth-First, and Why It Matters — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dyn-lesson">
            <a href="/courses/dyn" class="back-link">Back to course</a>
            <h1>Breadth-First, and Why It Matters</h1>
            <div class="lesson-meta">20 min &middot; Module 1: The Scope &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The previous concept said the scope is a breadth-first walk and moved on. That is the right level of confidence for most readers and the wrong one for anyone who writes a linker, because the order is the only thing that makes interposition predictable. So here it is, measured.</p>
                <div class="hex-dump">
                    <pre>$ for f in order libd2.so libb.so liba.so libdeep.so; do
    printf "  %-11s " $f
    readelf -dW $f | sed -n 's/.*(NEEDED).*\[\(.*\)\]/[\1]/p' | tr '\n' ' '
    echo
  done

  order       [libd2.so] [libdeep.so] [libb.so] [liba.so] [libc.so.6]
  libd2.so    [libdeep.so] [libc.so.6]
  libb.so     [liba.so] [libc.so.6]
  liba.so     [libc.so.6]
  libdeep.so  [libc.so.6]
</pre>
                </div>
                <p>A tree with two branches. <code>order</code> needs <code>libd2.so</code> and <code>libb.so</code>; the first needs <code>libdeep.so</code>, the second needs <code>liba.so</code>; all three need libc. <strong>Two plausible orders exist and only one of them is correct.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Both orders, written out, so the difference is visible rather than argued.</p>
                <div class="formula">
  DEPTH-FIRST (a recursive descent)

    order
     +-- libd2.so
     |     +-- libdeep.so
     |     +-- libc.so.6          &lt;-- reached at position 3
     +-- libdeep.so               &lt;-- ALREADY SEEN, skip
     +-- libc.so.6                &lt;-- ALREADY SEEN, skip
     +-- libb.so
     |     +-- liba.so            &lt;-- reached at position 4
     |     +-- libc.so.6          &lt;-- skip

    scope:  order  libd2  libdeep  libc  libb  liba

  BREADTH-FIRST (a queue)

    order
     +-- libd2.so                  &lt;-- position 1
     +-- libdeep.so                &lt;-- position 2   (libd2's own need)
     +-- libb.so                   &lt;-- position 3
     +-- liba.so                   &lt;-- position 4   (libb's own need)
     +-- libc.so.6                 &lt;-- position 5

    scope:  order  libd2  libdeep  libb  liba  libc

                </div>
                <p><strong>The two differ in where <code>liba.so</code> lands relative to <code>libb.so</code> &mdash; and that is not a cosmetic difference.</strong> <code>liba.so</code> is a dependency <em>of</em> <code>libb.so</code>. Breadth-first puts it immediately after its parent, which reads as &ldquo;children come right after the thing that needed them&rdquo;. Depth-first finishes the whole first branch before starting the second, which spreads a parent and its child across the list with unrelated objects between them.</p>
                <p>Why the second is wrong is a single sentence:</p>
                <div class="formula">
  a library must be FULLY RELOCATED before anything
  binds to it. libb.so's calls into liba.so need
  liba.so's own relocations applied first.

  if the loader walked depth-first and processed
  relocations as it went, it would bind libb's
  references before liba was ready. breadth-first
  at least puts a parent and its direct children
  adjacent, which is the property the loader's
  relocation pass relies on.

                </div>
                <p><strong>And that is the real reason the order is specified rather than left to the implementation.</strong> It is not tidiness. It is that the loader must be able to say &ldquo;everything at depth <em>n</em> is mapped and relocated before I start depth <em>n+1</em>&rdquo;, and it can only do that if it knows the order.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>The loader&rsquo;s own load order, which is the measurement:</p>
                <div class="hex-dump">
                    <pre>$ LD_DEBUG=libs ./order 2&gt;&amp;1 | sed 's/^ *[0-9]*:\t*//' \
      | grep "find library" | sed 's/; searching.*//'
  find library=libd2.so [0]
  find library=libdeep.so [0]
  find library=libb.so [0]
  find library=liba.so [0]
  find library=libc.so.6 [0]
</pre>
                </div>
                <p><strong><code>libdeep.so</code> is loaded second, not fourth.</strong> It is a <em>transitive</em> dependency &mdash; nothing on the command line or in <code>order</code>&rsquo;s own <code>DT_NEEDED</code> names it &mdash; and breadth-first still pulls it up to position 2 because it is a direct child of <code>libd2.so</code>. A depth-first walk would have loaded <code>liba.so</code> at position 3, because it would have finished <code>libdeep.so</code>&rsquo;s subtree first.</p>
                <p>And the artifact&rsquo;s answer, computed from the files with no loader involved, is the same list:</p>
                <div class="hex-dump">
                    <pre>$ python3 dynscope.py scope ./order
    0  depth=0  order              0 exported
    1  depth=1  libd2.so           0 exported
    2  depth=1  libdeep.so         1 exported
    3  depth=1  libb.so            1 exported
    4  depth=1  liba.so            1 exported  (+1 more)
    5  depth=1  libc.so.6      3164 exported  (+4 more)
    6  depth=2  ld-linux-x86-64.so.2  38 exported
</pre>
                </div>
                <p>Same order, and the depth column makes the structure explicit: four objects at depth 1 and one at depth 2. <strong>The <code>(+1 more)</code> and <code>(+4 more)</code> are the deduplication, and they are the reason <code>libc.so.6</code> appears once despite five objects needing it.</strong></p>
                <p>Now make the order matter, because an observation that changes nothing is not worth much. <code>liba.so</code> is needed by both <code>order</code> and <code>libb.so</code>, so it is at position 4 &mdash; after <code>libb.so</code>. Put a second definition of the same symbol in <code>libb.so</code> and watch which one wins:</p>
                <div class="hex-dump">
                    <pre>$ cat shim.c
int lib_value(void){ return 999; }   /* a DIFFERENT lib_value */

$ clang -fPIC -shared -Wl,-rpath,'$ORIGIN' -o libshim.so shim.c -L. -la
$ readelf -dW libshim.so | sed -n 's/.*(NEEDED).*\[\(.*\)\]/  libshim NEEDED \1/p'
  libshim NEEDED liba.so
</pre>
                </div>
                <p>Now the scope of <code>order</code> gains <code>libshim.so</code>, and where it lands relative to <code>liba.so</code> decides the answer. <strong>That is the mechanism by which link order in a build system becomes run-time behaviour in a program</strong>, and it is why the position of a <code>-l</code> on a command line is not a style question. Two builds, same flags, different order:</p>
                <div class="hex-dump">
                    <pre>$ clang -o order_shim  order.c -L. -lshim -ld2 -ldeep -lb -la -Wl,-rpath,'$ORIGIN'
$ clang -o order_shim2 order.c -L. -ld2 -ldeep -lb -lshim -la -Wl,-rpath,'$ORIGIN'

$ for f in order_shim order_shim2; do
    printf "  %-12s " $f
    readelf -dW $f | sed -n 's/.*(NEEDED).*\[\(.*\)\]/[]/p' | grep -v libc | tr '\n' ' '
    echo
  done
  order_shim   [libshim.so] [libd2.so] [libdeep.so] [libb.so] [liba.so]
  order_shim2  [libd2.so] [libdeep.so] [libb.so] [libshim.so] [liba.so]
</pre>
                </div>
                <p><strong><code>DT_NEEDED</code> order follows the link line order, exactly.</strong> The first build lists <code>libshim.so</code> first and the second lists it fourth, and in both the shim wins &mdash; but look at the <em>margin</em>: three positions in the first build, <strong>one</strong> in the second. Move <code>-la</code> up one place and <code>liba.so</code> wins instead. <strong>Nothing about the program changed; the two definitions of <code>lib_value</code> exchanged places in a list, and that is the entire difference between the two binaries&rsquo; behaviour.</strong></p>
                <p>And a correction worth making, because the first draft of this page told a tidier and wrong story: it claimed that <code>--as-needed</code> dropped <code>liba.so</code> from the second build&rsquo;s <code>DT_NEEDED</code>. <strong>It did not</strong> &mdash; <code>liba.so</code> is in both lists. The real mechanism is the direct one above, and it is a better lesson precisely because there is nothing hidden: the order on the command line is the order in the file, and the order in the file is the order in the scope.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The case where getting this wrong produces a bug that is nearly impossible to diagnose, because the program works on the machine that built it.</p>
                <div class="hex-dump">
                    <pre>  the situation: two libraries, both exporting
  `format_error', and both needed by your program.

  order.o  ->  libnew.so   (exports format_error, version 2)
               libold.so   (exports format_error, version 1)

  link with:  -lnew -lold

  DT_NEEDED becomes [libnew.so] [libold.so]
  the scope gets libnew.so at 1 and libold.so at 2
  and libnew WINS for every reference, including
  references made from inside libold.

  now reverse the link order by accident -- a
  Makefile change, a dependency reordering, a
  -Wl,--as-needed interaction -- and libold wins.
  no diagnostic, no warning, and the program now
  formats errors the old way forever.
</pre>
                </div>
                <p><strong>The two programs are the same source, the same objects, and the same compiler flags.</strong> The only difference is the order two flags appear in, and it propagates into a behavioural difference that no test of the <em>code</em> would catch &mdash; because the code is identical.</p>
                <p>This is why the <a href="/courses/sym/lessons/sym-order">symbol-resolution course</a> spent a concept on link order for archives. That was the <em>link-time</em> version of this: which objects get pulled in. This is the <em>run-time</em> version: which definition of a duplicated symbol wins, and therefore whether the duplication is even a problem. <strong>They are the same concern at two different times, and the mechanism is order both times.</strong></p>
                <p>And the case where the order is forced on you regardless &mdash; a cycle:</p>
                <div class="hex-dump">
                    <pre>  liba.so needs libb.so
  libb.so needs liba.so

  the graph has a cycle. breadth-first handles it for
  free: when the walk reaches liba.so the second time,
  it is already in the list, so it is skipped. the cycle
  costs nothing and produces no special case in the code.

  a recursive descent would recurse forever without an
  explicit "in progress" marker. THAT is the other reason
  the queue is the right shape: it makes cycle detection a
  membership test rather than a stack-depth guard.
</pre>
                </div>
                <p><strong>Deduplication is cycle detection.</strong> They look like two requirements and they are the same line of code, which is a satisfying example of a specification that got tighter rather than more complicated.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/dyn/assets/samples
$ ./build_samples.sh 2&gt;&amp;2 | sed -n '/D3/,/D4/p'
$ python3 crosscheck.py 2&gt;&amp;2 | sed -n '/\\[3\\]/,/\\[4\\]/p'
$ python3 dynscope.py scope ./order
</pre>
                </div>
                <p>Then break the order deliberately and find out what it costs:</p>
                <div class="hex-dump">
                    <pre>  1. Reverse the link line for `order`: -lb -ld2
     instead of -ld2 -lb. Does the SCOPE change? (The
     set does not. The ORDER does.) Which object moved?

  2. Write the depth-first version of build_scope() in
     dynscope.py -- a recursive descent, about six lines
     -- and run both against ./order. They will disagree.
     Print both and look at where liba.so lands. (This is
     the exercise: you will have written the wrong
     algorithm on purpose and seen exactly why it is
     wrong.)

  3. Build a cycle: make liba.so need libb.so as well.
     Does breadth-first survive it? What would a
     recursive version do without a marker?

  4. Now the one that matters. Take the shim from the
     previous section, and link the program both ways.
     Find a symbol both libraries export, and use
     LD_DEBUG=bindings to prove which one won in each
     build. The program text is identical; only the
     order differs.

  5. Count: for ./order, how many objects does the
     graph reach, and how many are in the scope? The
     difference is deduplication. Now make the graph
     deep rather than wide and watch the number grow.
</pre>
                </div>
                <p>Exercise 2 is the one worth the twenty minutes, and it is the reason this concept exists rather than being a footnote in the first one. <strong>Writing the depth-first version yourself, seeing it disagree, and being able to say why is the difference between having read a specification and having internalised it.</strong> Six lines of recursion versus a six-line queue, and the queue is right for a reason that turns out to be two reasons at once: ordering, and cycle detection for free.</p>
                <p>Exercise 4 is the practical one, and it is the mechanism behind a class of bug that is genuinely hard: <strong>the same source producing different behaviour because the build system changed.</strong> If you have ever had a working library stop working after an unrelated dependency bump, this is usually what happened, and now you can name the mechanism and predict which build wins.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This closes module 1. <a href="/courses/dyn/lessons/dyn-scope">The Global Scope</a> gave the algorithm and <a href="/courses/dyn/lessons/dyn-interpose">Interposition</a> showed its sharpest consequence. <strong>This one supplies the one thing that makes both of them predictable rather than surprising: an order that is specified, and that you can compute before running anything.</strong> Without it, &ldquo;the executable wins&rdquo; is a fact you memorise; with it, you can derive where any symbol ends up.</p>
                <p>The connection to the <a href="/courses/sym/lessons/sym-order">symbol-resolution course&rsquo;s link-order concept</a> is the strongest in the course, and it is worth naming as a pair rather than two separate lessons. That concept found that <code>MA.a MB.a</code> links while <code>MB.a MA.a</code> fails, and that GNU ld&rsquo;s archive resolution is a fixed-point iteration rather than a single pass. <strong>That is the link-time question &mdash; which objects end up in the output.</strong> This is the run-time question &mdash; which of the objects that got in wins a duplicated symbol. Both are decided by order, both are silent when wrong, and the reason the first is more widely known is only that a link failure is louder than a behavioural difference.</p>
                <p>The third connection is to a course you finished long ago, and it is a nice loop. <a href="/courses/reloc/lessons/reloc-arch-contrast">One Relocation, or Two</a> found that AArch64 needs two relocations per reference, 4 bytes apart, and concluded that a tool must process relocations as a <em>set with an ordering constraint</em> rather than as a flat list &mdash; because a half-applied pair is still a valid instruction pointing at the wrong place. <strong>This concept is the same requirement one level up.</strong> A loader that processes its objects in the wrong order produces a fully-applied but wrong set, which is exactly the same class of silent failure, and the specification that prevents it is the one on this page.</p>
                <p>Forward into the building module, the order is about <em>which object wins</em>, and the next three concepts are about <em>whether an object is in the running at all</em>. <a href="/courses/dyn/lessons/dyn-build-so">Building a Library</a> covers what a <code>.so</code> is made of. <a href="/courses/dyn/lessons/dyn-export">Hiding Things, and the Trap</a> covers deciding what goes in <code>.dynsym</code>, which decides what is a candidate for the search. <a href="/courses/dyn/lessons/dyn-symbolic">One Instruction Called -Bsymbolic</a> covers opting out of the search from the other side. <strong>All three are about shrinking or pinning the set of candidates; this module was about the order they are searched in.</strong></p>
                <p>And the connection that motivates the artifact, which is where the course is going. A scope you can compute means a <em>resolver</em> you can write, and <a href="/courses/dyn/lessons/dyn-resolve">Rebuilding the Scope Yourself</a> writes one in about two hundred lines: read the <code>DT_NEEDED</code> lists, walk them breadth-first, read each <code>.dynsym</code>, take the first match, and then check every answer against <code>LD_DEBUG=bindings</code>. <strong>The loader is not a black box at this point, and the last concept proves it by rebuilding it.</strong></p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dyn/lessons/dyn-interpose">Previous: Interposition</a></span>
                <span>Next: <a href="/courses/dyn/lessons/dyn-build-so">Building a Library</a></span>
            </div>
        </div>
    

    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
