// Dynamic Linking and Shared Libraries — Module 1: The Scope
// Concept: the ordered list every undefined symbol is answered from.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dyn_scope() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Global Scope — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dyn-lesson">
            <a href="/courses/dyn" class="back-link">Back to course</a>
            <h1>The Global Scope</h1>
            <div class="lesson-meta">24 min &middot; Module 1: The Scope &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Here is a shared library calling a function it does not define. It is not a mistake, not an optimisation, and not a portability hack &mdash; it is what shared libraries <em>are</em>:</p>
                <div class="hex-dump">
                    <pre>/* lib.c  ->  liba.so */
int lib_value(void){ return 1; }

/* mid.c  ->  libb.so, which NEEDS liba.so */
extern int lib_value(void);
int mid_value(void){ return lib_value() + 10; }

/* main.c -> prog, which needs both */
extern int lib_value(void);
extern int mid_value(void);
int main(void){ printf("  %d %d\n", lib_value(), mid_value()); return 0; }
</pre>
                </div>
                <p><code>libb.so</code> has a reference to a symbol it does not contain. The linker cannot resolve it &mdash; the answer is in another file. <strong>Something has to answer it, and that something is the loader, and the way it decides is the subject of this course.</strong></p>
                <p>And here is the thing that makes this teachable: <strong>the loader will tell you what it decided.</strong></p>
                <div class="hex-dump">
                    <pre>$ LD_DEBUG=bindings ./prog 2&gt;&amp;1 | grep lib_value
  binding file ./prog    [0] to .../liba.so [0]: normal symbol `lib_value'
  binding file .../libb.so [0] to .../liba.so [0]: normal symbol `lib_value'
</pre>
                </div>
                <p>One line per binding, naming the object that wanted the symbol and the object that supplied it. Everything in this course is either that output or a file that output predicts &mdash; which means the whole subject can be measured rather than described.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The scope, stated so precisely that you can implement it in an afternoon. Because you will, in the last concept.</p>
                <div class="formula">
  THE SCOPE is an ORDERED LIST of loaded objects.

  built like this:
    scope[0] = the EXECUTABLE        always, unconditionally,
                                     and it is never in its own
                                     DT_NEEDED
    then, breadth-first, every DT_NEEDED of the
    executable, then every DT_NEEDED of THOSE, and
    so on. an object already in the list is not
    added again.

  used like this, for every undefined reference:
    for object in scope, in order:
      if object DEFINES the symbol:
        bind to it and STOP

  that is the whole algorithm.

  two consequences fall out of it and both are
  load-bearing:
    1. the executable is searched FIRST, always
    2. earlier in DT_NEEDED beats deeper in the
       dependency graph

                </div>
                <p><strong>That is the entire mechanism of dynamic linking, and it is about fifteen lines of C.</strong> The <a href="/courses/elf/lessons/ld-so">ELF course</a> described the load <em>sequence</em> and the search <em>paths</em>; this is the other half. Search paths answer &ldquo;where do I look for <code>libfoo.so</code>&rdquo;. The scope answers &ldquo;I have found four files that could supply this name &mdash; which one?&rdquo; Those are different questions, and the second one is where all the behaviour lives.</p>
                <p>The graph makes it a real structure rather than a list, so the walk order matters:</p>
                <div class="formula">
  prog
   |
   +-- libb.so ---- liba.so ---- libc.so.6
   |                  \             /
   +-- liba.so --------\-----------/
   |
   +-- libc.so.6

  is it a LIST? no. libc.so.6 is needed by three objects and must appear
  ONCE, or a symbol would have three chances to win and the "first match"
  rule would depend on how many times you walked.

  is it a TREE? no. the same library reached by two paths is still one
  object, loaded once, in one place in memory. if it were in the scope
  twice, a version of a function in it could be bound from either entry
  and the program's behaviour would depend on link order.

  so: a graph, flattened, breadth-first, deduplicated. that is the
  entire data structure.

                </div>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>Build the graph, then watch the loader walk it. First the <code>DT_NEEDED</code> lists, which are the only thing the scope is built from:</p>
                <div class="hex-dump">
                    <pre>$ for f in liba.so libb.so prog; do
    printf "  %-9s " $f
    readelf -dW $f | sed -n 's/.*(NEEDED).*\[\(.*\)\]/[\1]/p' | tr '\n' ' '
    echo
  done
  liba.so   [libc.so.6]
  libb.so   [liba.so] [libc.so.6]
  prog      [libb.so] [liba.so] [libc.so.6]
</pre>
                </div>
                <p><strong>Three facts in three lines.</strong> Every object needs libc, so libc would be reached three times. <code>liba.so</code> is reached from both <code>prog</code> and <code>libb.so</code>. And the executable lists <code>liba.so</code> <em>explicitly</em>, which is a consequence of the link line rather than of the dependency graph &mdash; and the reason is worth knowing, because it is a very common link failure:</p>
                <div class="hex-dump">
                    <pre>$ clang -o prog main.c -L. -lb -Wl,-rpath,'$ORIGIN'
ld.bfd: prog: undefined reference to `lib_value'
ld.bfd: ./liba.so: error adding symbols: DSO missing from command line

$ clang -o prog main.c -L. -lb -la -Wl,-rpath,'$ORIGIN'   # note the -la
</pre>
                </div>
                <p><strong><code>--as-needed</code> is on by default on this toolchain</strong>, and it drops a library from <code>DT_NEEDED</code> if nothing needed it <em>at the moment the linker saw it</em>. <code>-lb</code> is read before anything has referenced <code>liba</code>'s symbols, so it is dropped, and then the reference to <code>lib_value</code> has nowhere to go. The fix is to list <code>-la</code> too. This is not a linker bug; it is an optimisation that changes the file, and the <a href="/courses/link/lessons/link-order">linker scripts course</a> already taught that <code>DT_NEEDED</code> is a list the script does not control.</p>
                <p>Now the scope itself, from the artifact rather than from the loader:</p>
                <div class="hex-dump">
                    <pre>$ python3 dynscope.py scope ./prog
The global scope of ./prog
    0  depth=0  prog                           0 exported
    1  depth=1  libb.so                        1 exported
    2  depth=1  liba.so                        1 exported  (+1 more)
    3  depth=1  libc.so.6                   3164 exported  (+2 more)
    4  depth=2  ld-linux-x86-64.so.2          38 exported
</pre>
                </div>
                <p><strong>Five objects, not nine.</strong> The graph has nine edges and the naive answer would list libc three times and liba twice. The <code>(+1 more)</code> and <code>(+2 more)</code> annotations are the deduplication being visible: <code>liba.so</code> was also needed by <code>libb.so</code>, libc by all three, and neither is a second object. <strong>An object appears in the scope once, at the position where it was first reached.</strong></p>
                <p>And the loader agrees, which is the check that matters:</p>
                <div class="hex-dump">
                    <pre>$ LD_DEBUG=libs ./prog 2&gt;&amp;1 | grep "find library"
  find library=libb.so [0]; searching
  find library=liba.so [0]; searching
  find library=libc.so.6 [0]; searching
  find library=ld-linux-x86-64.so.2 [0]; searching
</pre>
                </div>
                <p>Same four, same order, computed two completely different ways &mdash; one from the loader&rsquo;s own walk and one by reading the files. <strong>That agreement is the proof that the scope is not a secret,</strong> and it is why the last concept of this course is a two-hundred-line program rather than a page of theory.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Why a list would be wrong, demonstrated with a program that breaks under one. Here is a scope built by naive recursive descent instead of a queue:</p>
                <div class="hex-dump">
                    <pre>  WRONG (recursive)                 RIGHT (a queue)
  prog                                 prog
   +-- libb.so                          +-- libb.so
   |     +-- liba.so  <- 3rd            |     +-- liba.so   <- 3rd
   |     +-- libc      <- 4th            |     +-- libc     <- 4th
   +-- liba.so  <- 5th, AGAIN           +-- liba.so   already seen
   +-- libc      <- 6th, AGAIN           +-- libc      already seen

  both "work". but the wrong one re-resolves libc.so.6 at position 6, and
  a symbol defined in libc would then have TWO chances to win depending
  on which libc you found. the two versions can differ -- and they do,
  on a machine with more than one libc in the search path.
</pre>
                </div>
                <p><strong>That is the concrete reason the order is specified rather than left to the implementation.</strong> The <a href="/courses/reloc/lessons/reloc-apply">Relocations course</a> ended with an applier that had a <code>build_layout()</code> function and a comment saying that deciding the layout was &ldquo;a different program with a much harder problem&rdquo;. This is that program. The scope is fifteen lines; <em>agreeing with the loader about every symbol in a large program</em> is the hard part, and it is hard precisely because the order has to be right or every answer is wrong in a way nothing reports.</p>
                <p>Two details that are easy to get wrong and that the artifact had to be taught by its own bugs:</p>
                <div class="hex-dump">
                    <pre>  1. DEDUPLICATE BY PATH, NOT BY NAME.
     a DT_NEEDED entry is a NAME. the scope holds PATHS.
     comparing the name against the list of paths never matches, and
     libc.so.6 enters the scope three times. (dynscope.py did exactly
     this on its first run.)

  2. THE EXECUTABLE IS NOT IN ITS OWN DT_NEEDED.
     there is no DT_NEEDED that says "prog". it is scope[0] because it
     is scope[0], and that is the whole reason an executable can
     interpose on a library.
</pre>
                </div>
                <p>And the honest limit of the model, which is that it explains <em>which</em> object wins and not everything about <em>how</em>. Versioned symbols add a second dimension &mdash; a name plus a version &mdash; and the <a href="/courses/sym/lessons/sym-version">symbol-resolution course</a> measured the tables that make that work. Undefined-weak symbols have their own rule, and so do <code>IFUNC</code> resolvers, which are a function that decides which function you get. <strong>First match in scope order is the rule; the corner cases are refinements of it, not replacements.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/dyn/assets/samples
$ ./build_samples.sh 2&gt;&amp;2 | sed -n '/D1/,/D2/p'
$ python3 crosscheck.py 2&gt;&amp;2 | sed -n '/\\[1\\]/,/\\[2\\]/p'
$ python3 dynscope.py scope ./prog
</pre>
                </div>
                <p>Then build a scope and check your prediction against the loader:</p>
                <div class="hex-dump">
                    <pre>  1. Make libb.so ALSO need libd2.so. Predict the
     scope of prog before you run it. Then run
     dynscope.py scope and LD_DEBUG=libs and see whether
     the prediction was right. (The interesting question
     is where liba.so lands, not whether it is present.)

  2. Add the same library twice on the link line:
     -la ... -la. How many times is it in DT_NEEDED? How
     many times in the scope? (--as-needed will collapse
     the second, which is its job.)

  3. Delete the -la from the link line and get the DSO
     error. Then find out WHERE --as-needed is decided:
     is it the linker, or the compiler? (It is a linker
     default, and you can see it with
     -Wl,--no-as-needed.)

  4. Now build the scope WITHOUT dynscope.py, using
     readelf -dW and a shell loop. You should get the
     same list. This is the exercise: if you can do it
     with readelf and grep, you understand the scope.

  5. Make a library that needs a library that does not
     exist. What does dynscope.py print, and what does
     the real loader do? (They are NOT the same, and
     finding out how they differ is the point.)
</pre>
                </div>
                <p>Exercise 4 is the one that matters, because it is the difference between reading about a data structure and having one. <strong>Twenty lines of shell using <code>readelf -dW</code> will produce the scope, because the scope is not a hidden thing &mdash; it is a breadth-first walk of a list you can print.</strong> Every course in this collection that has handed you a structure has eventually let you rebuild it; this is the one that takes fifteen lines, and the reason it is worth a course rather than a paragraph is everything <em>else</em> that hangs off it.</p>
                <p>Exercise 5 is where the artifact is honest about its limits. <code>dynscope.py</code> prints <code>NOT FOUND</code> and carries on, because a missing transitive dependency is recoverable &mdash; you can still resolve what you can. The real loader treats a missing <code>DT_NEEDED</code> as fatal and refuses to start. <strong>Being more robust than the thing you are modelling is a design decision, not a bug, and it is the kind of thing you should notice and decide rather than inherit.</strong></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the first concept, and it is the one the other nine depend on. <strong>Every mechanism in dynamic linking is a variation on &ldquo;search the scope in order and take the first match&rdquo;.</strong> Interposition is the executable being first. <code>-Bsymbolic</code> is removing entries from the search. Versioning is a second key in the same search. Lazy binding is deciding <em>when</em> to run it. <code>dlopen</code> is appending to the list. There is no second idea.</p>
                <p>The connection to the <a href="/courses/elf/lessons/ld-so">ELF course's loader concept</a> is the difference between the two halves of the same subject, and it is worth stating precisely because the earlier course could not. That concept gave the load sequence and the search paths: map the <code>DT_NEEDED</code> libraries, then relocate, then call init functions, then jump to <code>e_entry</code>. <strong>It could say <em>which files</em> get loaded and never <em>which one wins</em>, because answering that needs the scope, and the scope needs the deduplicated breadth-first walk &mdash; which is this concept.</strong> Search paths and the scope are the two halves of &ldquo;dynamic symbol resolution&rdquo;, and only the second one has behaviour in it.</p>
                <p>The second connection is to the <a href="/courses/sym/lessons/sym-algorithm">symbol-resolution course's algorithm concept</a>, and it is the sharpest comparison in the collection. That course traced a <em>link-time</em> pass that is demand-driven and left-to-right, and found that the same archive in a different order links or fails to link. <strong>The runtime pass is the same shape with one crucial difference: it cannot fail.</strong> A linker that cannot find a symbol reports an error; a loader that cannot find one either has it in the scope already (because the executable would not have started) or the reference was never reached. That is why the loader&rsquo;s search order is <em>specified</em> rather than left free in the way a linker&rsquo;s mostly is &mdash; the search must agree with itself, not merely succeed.</p>
                <p>Forward within the module, the two consequences named in the model are the next two concepts, in order. <a href="/courses/dyn/lessons/dyn-interpose">Interposition</a> takes consequence 1 &mdash; the executable is first &mdash; and shows that it reaches <em>inside</em> libraries, which is the single most surprising measured fact in the course. <a href="/courses/dyn/lessons/dyn-order-runtime">Breadth-First, and Why It Matters</a> takes consequence 2 and shows that depth-first would produce a different, wrong answer.</p>
                <p>And the connection into the artifact, which is the last concept and the reason this course exists. <a href="/courses/dyn/lessons/dyn-resolve">Rebuilding the Scope Yourself</a> is this concept implemented: read <code>DT_NEEDED</code>, walk it breadth-first, read each <code>.dynsym</code>, take the first match, and then check the answer against <code>LD_DEBUG=bindings</code>. <strong>A loader is not mysterious; it is a graph walk over files you can print, and the exercise is to do it before believing that.</strong></p>
            </div>

            <div class="lesson-footer">
                <span>Start of course</span>
                <span>Next: <a href="/courses/dyn/lessons/dyn-interpose">Interposition</a></span>
            </div>
        </div>
    

    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
