// Symbol Resolution and Symbol Tables — Module 2: The Resolution Algorithm
// Concept: order as a semantic input, the map file as an observation tool, and
// the fixed-point group.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sym_order() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Order, Archives and the Map File — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson sym-lesson">
            <a href="/courses/sym" class="back-link">Back to course</a>
            <h1>Order, Archives and the Map File</h1>
            <div class="lesson-meta">20 min &middot; Module 2: The Resolution Algorithm &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Almost everyone&rsquo;s first experience of link order is not a library dependency problem. It is this:</p>
                <div class="hex-dump">
                    <pre>$ clang -o prog main.o -lfoo -lbar
/usr/bin/ld.bfd: main.o:(.text+0x12): undefined reference to `helper'
</pre>
                </div>
                <p>and then, five minutes later, after moving <code>-lbar</code> one position earlier, it links. <strong>Nothing about the code changed. The order of two strings on a command line is the difference between a working program and a build failure</strong>, and the error message names a symbol that <em>is</em> defined, somewhere, in a library that <em>is</em> on the command line.</p>
                <p>That error message is actively misleading, and understanding why it is misleading is the point of this concept. The linker is not saying &ldquo;this symbol does not exist&rdquo;. It is saying &ldquo;by the time I finished reading, nothing had defined it&rdquo;, and those are different statements about the world.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The previous concept gave the algorithm. This one is about the three tools that exist because that algorithm has these properties.</p>
                <div class="hex-dump">
                    <pre>  THE TOOL           THE PROPERTY IT ADDRESSES

  command-line order   demand can only be met by something
                       to its RIGHT. order is meaning.

  -Map=file            the algorithm is invisible. the map
                       is the only place the decisions are
                       written down.

  --start-group        one pass is not always enough. the
  --end-group          group is a FIXED POINT over a set
                       of archives.
</pre>
                </div>
                <p>The map file is the one people under-use, so it is worth being concrete about what is in it. For each input, ld records which symbols that input <em>answered</em> &mdash; and the direction of that relation is the whole diagnostic value:</p>
                <div class="hex-dump">
                    <pre>  libMA.a(ma.o)      mu.o            (a_fn)
  libMB.a(db.o)      libMA.a(ma.o)   (b_data)

  read as: "ma.o, from libMA.a, is what satisfied mu.o's want for a_fn"
</pre>
                </div>
                <p><strong>The left column is the provider and the right column is the demander, which is the opposite of the order the files were listed in.</strong> That inversion is the point. A map file is not a link order listing; it is a dependency graph, and reading it left-to-right as if it were the command line is the standard misreading.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>The three cases, all measured in section [4] of the sample build:</p>
                <div class="hex-dump">
                    <pre>$ clang -o prog mu.o libMA.a libMB.a ; ./prog ; echo $?
21
$ clang -o prog mu.o libMB.a libMA.a
ma.c:(.text+0x7): undefined reference to `b_data'

$ clang -o prog mu.o -Wl,--start-group libMB.a libMA.a -Wl,--end-group
$ ./prog ; echo $?
21
</pre>
                </div>
                <p>And what the map file says about the group case, which is the interesting one because the group was scanned repeatedly:</p>
                <div class="hex-dump">
                    <pre>$ grep -E '^libM[AB]\.a\(' prog.map
libMA.a(ma.o)      mu.o            (a_fn)
libMB.a(db.o)      libMA.a(ma.o)   (b_data)
</pre>
                </div>
                <p><strong>Same two lines as the working non-group case.</strong> The fixed point converged on exactly the solution a correct single pass would have found, and the map gives no hint that four passes happened. That is a property worth knowing when you debug a slow link: <strong>the map file tells you the answer, not the work</strong>, so a pathological group looks identical to a clean one in the output.</p>
                <p>Now the performance question, because it decides when the group flag is worth its cost. The unused member is free:</p>
                <div class="hex-dump">
                    <pre>$ grep -c '^libM' prog.map
2
$ ar t libMB.a
mb.o
db.o              &lt;-- mb.o is in the archive but was never read
</pre>
                </div>
                <p>Two members pulled out of four, and <code>mb.o</code> never touched. The archive index is a sorted table of names to member offsets; the linker resolves the pending demand against that table and seeks directly to the member that matches. <strong>Cost is proportional to symbols wanted, not to library size</strong>, which is the property that makes a thousand-object static library cheap to link against.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The practical decision, stated as most build systems actually face it. You have a program, a set of internal libraries, and a third-party dependency graph. Three options, and they are not equally good:</p>
                <div class="hex-dump">
                    <pre>  1. FIX THE ORDER.  correct dependency order on the
     link line. fragile: it must be recomputed whenever
     the graph changes, and nothing enforces it.

  2. --start-group EVERYTHING. always links. costs
     repeated scanning, and DELETES THE SIGNAL that
     your libraries have a cycle.

  3. MAKE THE LINKER DO IT. lto, or --start-group on
     just the mutually-dependent set, or a response
     file generated from the real dependency graph.
</pre>
                </div>
                <p>Option 2 is what a surprising number of build systems converge on, and it is the worst of the three. The reason is not the performance. <strong>It is that a link order which works by brute force is a link order which stops working the moment the graph changes in a way brute force cannot cover</strong> &mdash; and it will fail with &ldquo;undefined reference&rdquo; on a machine you did not build on, for a library you did not change, because the group was in the wrong place or a <code>-Wl,--as-needed</code> interaction removed a demand that the ordering had been relying on.</p>
                <p>Option 3 is what the large build systems do and it is the right answer for a reason that is easy to miss: <strong>the correct order is derivable, and deriving it is a graph problem, not a linker problem.</strong> A build system that knows its own dependency graph should emit the order. Passing that work to ld via <code>--start-group</code> is a way of not doing it.</p>
                <p>There is a fourth option, and it is the one that actually fixes the class of problem. <strong>Two libraries that need each other are usually one library that was split.</strong> A mutual dependency is a design smell with a long history: it is what <code>libc</code> and the dynamic loader have, it is why static linking glibc warns, and it is why <code>--as-needed</code> exists. When a cycle appears between two archives you own, the fix is in your headers, not on your link line.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/sym/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/Finding 6/,/Finding 7/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/\[4\]/,/^$/p'
</pre>
                </div>
                <p>Now use the map file as a tool rather than as an artefact. Predict, then check:</p>
                <div class="hex-dump">
                    <pre>  1. Delete mu.o's call to a_fn. Which members are pulled
     now? (da.o is in the same archive as ma.o -- is it
     still read?)

  2. Write a link that pulls mb.o as well as ma.o and db.o.
     What single change to mu.c does that?

  3. Compile a .map for the FAILING order with --start-group
     added, and diff the two maps. What is the ONLY difference?

  4. Add a THIRD archive that defines nothing but wants a_data.
     Which orderings now work that did not before?
</pre>
                </div>
                <p>Question 1 has the answer that generalises: <strong>archive extraction is per-member but a member drags its whole <code>.o</code> in</strong>, so <code>da.o</code> comes along whether or not anything wanted it. That is a real cost of coarse-grained extraction, and it is why thin archives and <code>-ffunction-sections</code> plus <code>--gc-sections</code> exist. Question 3 has the answer that closes the concept: the maps are identical, so <strong>the group changes the search, not the result</strong>.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the second half of a pair with <a href="/courses/sym/lessons/sym-algorithm">The Algorithm, Measured</a>. That one gave the pass; this one gives the three things you do about its properties. If you read only one of them, read the algorithm one &mdash; but this is where the practical advice lives.</p>
                <p>Forward, the connection is sharp and slightly uncomfortable. <strong>Every mechanism in this concept is a workaround for the fact that a static link knows its whole world at once, and a dynamic one does not.</strong> Link order works because the linker can see every file. The map file works because the linker can report on a decision it made globally. <code>--start-group</code> works because repeating a search is possible when the search space is finite and known. <a href="/courses/sym/lessons/sym-hash">Two Hash Tables, One Job</a> is the dynamic case of the map file: a data structure the loader builds so that it can answer the same question against a set of libraries that did not exist when the program was linked. And <a href="/courses/sym/lessons/sym-binding-time">Lazy, Eager, and the Flag That Does Nothing</a> is the loader&rsquo;s answer to &ldquo;when do I do the search&rdquo; &mdash; a question that never arises in the static case because there is no &ldquo;later&rdquo;.</p>
                <p>Back to the object files course, this concept completes an argument that started there. <a href="/courses/obj/lessons/obj-archives">The Archive</a> measured the <code>.a</code> container and found that GNU ld&rsquo;s resolution is a fixed-point iteration rather than a backwards scan. This concept is the other half: it is the fixed point that makes the order matter, and the archive index that makes the search cheap. <strong>Two formats, two halves of one performance decision that nobody makes consciously.</strong></p>
                <p>And one practical thread that runs through the whole course. <a href="/courses/obj/lessons/obj-relocations">Relocations</a> established that a relocation names a symbol by index and that resolving it is a later step. This concept is the &ldquo;later step&rdquo; for the static case. <a href="/courses/sym/lessons/sym-plt">The PLT and the GOT</a> is the same later step for the dynamic case, and the reason it needs six instructions and a side table where the static case needed nothing at all.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/sym/lessons/sym-algorithm">Previous: The Algorithm, Measured</a></span>
                <span>Next: <a href="/courses/sym/lessons/sym-duplicate">Two Definitions and One Tentative</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
