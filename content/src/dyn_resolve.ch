// Dynamic Linking and Shared Libraries — Module 4: Rebuild It
// Concept: read DT_NEEDED, walk it breadth-first, resolve a symbol, and check
// the answer against the real loader.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dyn_resolve() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Rebuilding the Scope Yourself — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson dyn-lesson">
            <a href="/courses/dyn" class="back-link">Back to course</a>
            <h1>Rebuilding the Scope Yourself</h1>
            <div class="lesson-meta">26 min &middot; Module 4: Rebuild It &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Eight concepts of reading, and this one writes. The artifact is <code>dynscope.py</code>, in this course&rsquo;s sample directory, and it does one thing: <strong>it rebuilds the loader&rsquo;s scope from the files and resolves symbols the way <code>ld.so</code> does, without a loader.</strong></p>
                <div class="hex-dump">
                    <pre>$ python3 dynscope.py
  scope      the ordered global scope, built from DT_NEEDED
  resolve    resolve one symbol the way ld.so would
  exports    list what a library actually exports
  search     every definition of a symbol, and which wins
  tour       all of the above, verified against the real loader
</pre>
                </div>
                <p>And here is the thing that makes it worth building rather than reading about: <strong>it checks itself against the loader.</strong> Every resolution it computes is compared with what glibc actually did, obtained from <code>LD_DEBUG=bindings</code>. Two independent implementations, one reading the files and one running the code, and they have to agree.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>What it has to read, and why each is unavoidable. The list is short and that is the point.</p>
                <div class="formula">
  FOUR TABLES, and no library

  .dynamic      a TLV array. read it linearly until
                d_tag == DT_NULL. gives DT_NEEDED (an
                OFFSET into DT_STRTAB, not a string) and
                DT_STRTAB itself -- which is an ADDRESS,
                so you must find the section whose sh_addr
                matches it, not a section named "dynstr".

  .dynstr       the names. offsets, NUL-terminated.

  .dynsym       the exports. 24 bytes each: name offset,
                info (bind in the high nibble, type in the
                low one), shndx, value, size.

  the LAYOUT    not in any file. the program builds it:
                a queue, seeded with the executable,
                extending with each object's DT_NEEDED,
                deduplicated by resolved path.

  THE TRAP, and it bit four times while this was written:
  DT_STRTAB is a VIRTUAL ADDRESS and e_shstrndx is three
  HALF-WORDS at offset 58, 60 and 62. Unpack five and
  you read past the end of the ELF header into the first
  section header, and every string lookup then fails.

                </div>
                <p><strong>The four bugs it had while being written are worth more than the code</strong>, because each is a way of being confidently wrong:</p>
                <div class="formula">
  1. e_shstrndx read by unpacking FIVE half-words at
     offset 58 and taking the last three. only three
     fields live there. the other two reads land in the
     first section header. every string lookup failed
     and the error said "subsection not found".

  2. DEDUPLICATION compared a DT_NEEDED NAME against a
     list of PATHS. "liba.so" never equals
     "/home/you/.../liba.so", so liba entered the scope
     THREE times and libc FOUR.

  3. resolve_path used an absolute candidate AS the path
     instead of joining the name to it. $ORIGIN resolved
     to a directory, and the scope contained directories.

  4. THE FIRST VERSION WAS A RECURSIVE DESCENT.
     it produced DEPTH-FIRST order -- which is the exact
     error the third concept spends twenty minutes
     warning about. an artifact that demonstrates the
     mistake is worse than no artifact.

                </div>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>The whole tour, verbatim, and every step ends in a verdict:</p>
                <div class="hex-dump">
                    <pre>$ python3 dynscope.py tour
=== dynscope: the scope is not a secret ===

The global scope of ./prog
    0  depth=0  prog                           0 exported
    1  depth=1  libb.so                        1 exported
    2  depth=1  liba.so                        1 exported  (+1 more)
    3  depth=1  libc.so.6                   3164 exported  (+2 more)
    4  depth=2  ld-linux-x86-64.so.2          38 exported

   PASS the executable is scope[0]
   PASS libb.so is scope[1] (first DT_NEEDED)
   PASS liba.so comes after libb.so, because the executable listed it second
   PASS and libc.so.6 is in the scope at all

Who would mid_value bind to in ./prog?
   -&gt; libb.so   (scope index 1 of 12, value 0x1110, FUNC)

--- the interposed build ---
Who would lib_value bind to in ./prog2?
   -&gt; prog2   (scope index 0 of 12, value 0x1150, FUNC)
   also defined by liba.so -- and it lost, because index 0 is earlier

--- exports ---
What liba.so exports
   lib_value                    FUNC   bind=1  value=0x1100  size=11
   1 exported, 4 undefined.

Every definition of lib_value in scope order
    0  prog2     0x1150  &lt;== WINS
    2  liba.so   0x1100

Every step verified.
</pre>
                </div>
                <p><strong>Five PASSes, then two resolutions that each name a winner and a loser</strong>, and then a search that shows the loser. <code>liba.so</code> exports <code>lib_value</code> deliberately and loses to an executable that defined it by accident, because the executable is index 0. That is the <a href="/courses/dyn/lessons/dyn-interpose">interposition concept</a> reproduced by a program that never called the loader for anything except verification.</p>
                <p>Now the extension that makes it a real cross-check rather than a restatement of the model &mdash; a graph where the recursion and the queue disagree, which is the whole point of <a href="/courses/dyn/lessons/dyn-order-runtime">the third concept</a>:</p>
                <div class="hex-dump">
                    <pre>$ python3 dynscope.py scope ./order
    0  depth=0  order              0 exported
    1  depth=1  libd2.so           0 exported
    2  depth=1  libdeep.so         1 exported
    3  depth=1  libb.so            1 exported
    4  depth=1  liba.so            1 exported  (+1 more)
    5  depth=1  libc.so.6      3164 exported  (+4 more)
    6  depth=2  ld-linux-x86-64.so.2  38 exported

$ LD_DEBUG=libs ./order 2&gt;&amp;1 | grep "find library" | sed 's/.*=//;s/ \[.*//'
  libd2.so
  libdeep.so     &lt;-- SECOND, not fourth
  libb.so
  liba.so
  libc.so.6
</pre>
                </div>
                <p><strong>Two independent computations, same order.</strong> One from the loader walking; one from Python reading <code>DT_NEEDED</code> and using a queue. And the <code>(+N more)</code> annotations make the deduplication visible rather than implicit &mdash; <code>liba.so</code> was also needed by <code>libb.so</code>, and libc by five objects, and neither is a second entry.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What the artifact deliberately does <em>not</em> do, because the omissions are the specification.</p>
                <div class="hex-dump">
                    <pre>  IT DOES NOT                          WHY IT WOULD BE WRONG TO

  handle VERSIONED names            a version is a second key in the
  (api_v1@@V1)                       same search. resolving the bare
                                     name would give an answer that
                                     looks right and is wrong.

  handle RTLD_NEXT                  it is a RELATIVE lookup. there is
                                     no handle, so there is nothing
                                     for a file-reading program to
                                     compute.

  handle thread-local offsets       the value is (this thread's
                                     block base) + a constant. the
                                     constant is a file field; the
                                     base is a run-time fact.

  handle IFUNC resolvers            the loader CHOOSES the function,
                                     possibly by CPU feature. the
                                     "definition" in .dynsym is a
                                     resolver, and the answer depends
                                     on the machine.

  fail on a MISSING DT_NEEDED       the real loader refuses to
                                     start. this one prints
                                     NOT FOUND and carries on,
                                     because a resolver that can
                                     answer some questions is more
                                     useful than one that answers
                                     none.

  THAT LAST ONE IS A DELIBERATE
  DIVERGENCE and it is the most
  defensible: a partial answer beats
  a refusal when you are the tool
  being used to understand something.
</pre>
                </div>
                <p>And the one thing that makes the omissions safe, which is the discipline rather than the code: <strong>every one of them is a case where the file does not contain the answer.</strong> A version is a second key and both keys are in the file, so it <em>could</em> be done &mdash; but a half-implemented version lookup that silently ignores the suffix is the worst outcome available. The thread-pointer base is not in any file at all, and no amount of reading would produce it. <strong>&ldquo;I cannot compute this from the files&rdquo; is a real answer, and naming it is better than guessing.</strong></p>
                <p>What the artifact gets <em>right</em> is worth stating too, because it is the part that is easy to get subtly wrong:</p>
                <div class="hex-dump">
                    <pre>  it reports the LOSER, not just the winner.

    -&gt; prog2   (scope index 0 of 12, value 0x1150, FUNC)
       also defined by liba.so -- and it lost, because index 0
       is earlier

  a resolver that prints only the answer teaches you the
  rule. one that also prints what it beat teaches you WHY,
  and why is the part you cannot get from the source.

  and it cross-checks against LD_DEBUG, so a bug in its
  own model would have to be a bug in glibc's model at the
  same time and in the same direction to survive.
</pre>
                </div>
                <p><strong>Which is the real argument for building any of these tools: not that the answer is useful, but that two independent implementations are a test of each other.</strong> The Relocations course&rsquo; applier had the same property, and found two of its own bugs on the way. This one found four.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/dyn/assets/samples
$ python3 dynscope.py tour
$ python3 dynscope.py scope ./order
$ python3 crosscheck.py
  ALL 119 CHECKS PASS
</pre>
                </div>
                <p>Then extend it, and the order is chosen so each step is a concept from this course:</p>
                <div class="hex-dump">
                    <pre>  1. VERSIONED NAMES. It is the biggest gap and the
     most instructive. A versioned symbol needs
     .gnu.version as a third key. Make resolve() take
     "api_v1@@V1" and find BOTH. Then make it FAIL
     loudly if given a bare name when the library only
     has versioned ones -- that failure mode is the
     point of the exercise.

  2. RTLD_DEFAULT. Add a scope-wide lookup that takes no
     handle and searches everything. Then confirm it
     agrees with the loader for a symbol you know is
     global. (This is the difference the RTLD_LOCAL /
     RTLD_GLOBAL concept measured, from the other side.)

  3. A "why" mode: for any symbol, print the scope index,
     the depth, the DT_NEEDED path that put each object
     there, and the object's .dynsym index. That is
     enough to diagnose a real interposition surprise
     from a core dump or a bug report.

  4. Make it work on a dlopen'd library: resolve a
     handle to its path, then scope it the same way.
     (dlopen does not change the ALGORITHM, only when
     the object enters the list -- which is the point
     of the dlopen concept.)

  5. Finally, and this is the real test: break it
     deliberately. Turn the queue back into a recursion
     and watch the scope order change. Then write down
     which of your answers changed. A tool you have
     broken on purpose and understand is a tool you
     trust; one you have only seen work is not.
</pre>
                </div>
                <p>Exercise 1 is the one that turns the artifact from a demonstration into a tool, and the failure mode is the lesson. <strong>Resolving <code>api_v1</code> when only <code>api_v1@@V1</code> exists looks completely correct and is completely wrong</strong> &mdash; it will find the right function, because the version is an attribute of a name rather than a different name. Which means a version-unaware resolver can pass every test you write and still break the moment a library ships two versions of a symbol. <strong>Knowing which of your answers are right for the wrong reason is the difference between a tool and a coincidence</strong>, and the only way to get it is to implement the key and then test the case where you did not.</p>
                <p>Exercise 5 is the one to end on, and it is the same discipline that produced the four bugs. <strong>Turn the breadth-first walk into a depth-first one and the scope order changes</strong> &mdash; and because the artifact cross-checks against <code>LD_DEBUG</code>, it will start disagreeing with the loader on exactly the symbols whose resolution depends on position. <strong>A verification harness that can only say yes is not a verification harness.</strong> Every retraction in this course came from a check that failed, and every one of them is more valuable than the claims they replaced.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the end of the course, and it is the concept that makes the other nine into a skill. <a href="/courses/dyn/lessons/dyn-scope">The Global Scope</a> gave the algorithm; <a href="/courses/dyn/lessons/dyn-interpose">Interposition</a> showed its sharpest consequence; <a href="/courses/dyn/lessons/dyn-order-runtime">Breadth-First</a> gave the order; the building module gave <code>.dynsym</code>, visibility and <code>-Bsymbolic</code>; the run-time module gave <code>dlopen</code>, binding time and thread-local storage. <strong>And now a program that does all of it by reading files, in about two hundred lines, with no loader.</strong></p>
                <p>The chain this course sits in is nearly finished, and it is worth seeing the shape of the whole thing. The <a href="/courses/obj">Object Files</a> course wrote a 936-byte ELF object byte by byte. The <a href="/courses/sym">Symbol Resolution</a> course traced the resolution pass and read the map file. The <a href="/courses/reloc">Relocations</a> course wrote a relocation applier that accepted a layout and said in a comment that deciding the layout was somebody else&rsquo;s problem. The <a href="/courses/link">Static Linking</a> course turned <code>ld --verbose</code> into a 276-line file you could edit, and ended with a driver that verified every step. <strong>This course takes the last piece &mdash; the run-time scope &mdash; and rebuilds it.</strong> Every link in the chain now has both a reading and a writing half.</p>
                <p>Three debts the earlier courses left, settled here. <strong>The <code>map file</code></strong> from the symbol-resolution course was a resolution-time artifact; this is the load-time one, and it is the same idea applied at the next stage. <strong>The <code>-Bsymbolic</code> relocation-type change</strong> from the building module is visible in the artifact&rsquo;s scope as a missing search, which is the same fact from the other side. And the <a href="/courses/reloc/lessons/reloc-apply">applier&rsquo;s <code>build_layout()</code></a> comment is answered at last: the layout is a <a href="/courses/link/lessons/link-location-counter">location counter in a script</a>, and this course&rsquo;s scope is the other half of the same problem &mdash; <em>where</em> rather than <em>which</em>.</p>
                <p>And the connection to this course&rsquo;s own first concept, which is the loop that makes it a course rather than a list. <a href="/courses/dyn/lessons/dyn-scope">The Global Scope</a> said the loader will tell you what it decided, and asked you to believe that the scope is not a secret. <strong>This concept is the proof, and the proof is that a program with no access to the loader&rsquo;s internals reproduces its answers from the files.</strong> If a reader can only take one idea from this course, it should be that: <em>the behaviour of a dynamic linker is a consequence of data you can print, and anyone who disagrees can go and check.</em></p>
                <p>One connection outward, to the platform you are reading this on. The Underlayer server is an ELF <code>ET_DYN</code> binary served by a dynamic linker, and every mechanism on these pages is running right now: the executable is scope[0], <code>libc.so.6</code> is in the scope, and <code>LD_DEBUG=bindings</code> would print every one of its decisions. <strong>You can run the instrument on it.</strong> That is not a metaphor &mdash; it is the same command, against a real process, and it is the through-line of this whole collection: every layer of the toolchain is readable by anyone who asks.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dyn/lessons/dyn-tls-block">Previous: Where the Thread Blocks Come From</a></span>
                <span>End of course &middot; <a href="/courses/dyn">back to the course page</a></span>
            </div>
        </div>
    

    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
