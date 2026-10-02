// Dynamic Linking and Shared Libraries — Module 1: The Scope
// Concept: the executable's definition wins, including inside libraries that
// did nothing unusual.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dyn_interpose() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Interposition — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson dyn-lesson">
            <a href="/courses/dyn" class="back-link">Back to course</a>
            <h1>Interposition</h1>
            <div class="lesson-meta">23 min &middot; Module 1: The Scope &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Add one function to the previous concept&rsquo;s program. That is the entire change:</p>
                <div class="hex-dump">
                    <pre>/* main2.c -- ONE extra line compared with main.c */
extern int lib_value(void);
extern int mid_value(void);
int lib_value(void){ return 100; }   /* &lt;-- the only difference */
int main(void){ printf("  %d %d\n", lib_value(), mid_value()); return 0; }
</pre>
                </div>
                <p>And here is what it does:</p>
                <div class="hex-dump">
                    <pre>$ ./prog
  lib_value()=1    mid_value()=11
$ ./prog2
  prog's lib_value()=100   libb's view of it=110
</pre>
                </div>
                <p><strong><code>mid_value()</code> is 110, not 11.</strong> And <code>mid_value</code> is not in the program at all &mdash; it lives in <code>libb.so</code>, which knows nothing about <code>main2.c</code> and was compiled and linked without it. <strong>A function inside a library, calling another function by name, reached a definition in the executable that neither of them mentions.</strong></p>
                <p>This is interposition, and it is the mechanism behind an enormous amount of otherwise-unexplainable behaviour: why a program can replace <code>malloc</code> without asking, why <code>LD_PRELOAD</code> works, and why the same binary behaves differently on two machines.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>There is nothing mysterious here, and that is the point. Walk the algorithm from the previous concept on this exact case.</p>
                <div class="formula">
  prog2's scope:

    0  prog2          &lt;-- the executable. ALWAYS index 0.
    1  libb.so
    2  liba.so
    3  libc.so.6

  libb.so has an undefined reference to `lib_value'.
  the loader searches the scope in order:

    index 0  prog2     defines lib_value?  YES  -&gt; STOP
                          |
                          +-- and prog2 was searched BEFORE liba.so,
                              the library that actually exports it

  result: libb.so's call is bound to prog2.

  that is the whole thing. no policy, no special case,
  no flag. an ordinary search that found an earlier match.

                </div>
                <p><strong>&ldquo;The executable is index 0&rdquo; is the entire design decision.</strong> Put it anywhere else and this stops happening; put it first and the program can override any library without the library&rsquo;s cooperation. That is not an accident of glibc &mdash; it is what every ELF dynamic linker does, and it is the answer to the question &ldquo;why can a program replace a library function?&rdquo;.</p>
                <p>Why the design goes that way, which is a design question rather than a fact:</p>
                <div class="formula">
  the alternative -- libraries first, executable last --

    would make it IMPOSSIBLE for a program to fix a bug
    in a library, override a slow function, or substitute
    a stub for one it cannot run. every one of those is
    something people genuinely need to do.

  the cost of the choice:

    a library cannot rely on its own functions. any symbol
    it exports and calls is a candidate for replacement by
    whoever is loaded before it. that is a real constraint
    on library design, and it is why the next concepts in
    this module are about controlling what a library
    exports and what its internal calls bind to.

                </div>
                <p><strong>So interposition is a feature with a price, and the price is paid by library authors rather than by program authors.</strong> A library that wants a call to be truly its own has to ask for it &mdash; and <a href="/courses/dyn/lessons/dyn-symbolic">that request is a flag</a>.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>The loader&rsquo;s own account, which is the evidence that nothing unusual happened:</p>
                <div class="hex-dump">
                    <pre>$ LD_DEBUG=bindings ./prog 2&gt;&amp;1 | grep lib_value
  binding file ./prog    [0] to .../liba.so [0]: normal symbol `lib_value'

$ LD_DEBUG=bindings ./prog2 2&gt;&amp;1 | grep lib_value
  binding file .../libb.so [0] to ./prog2 [0]: normal symbol `lib_value'
</pre>
                </div>
                <p><strong>Read the two lines as a pair, because the difference is the whole concept.</strong> In the first, <code>libb.so</code> bound to <code>liba.so</code> &mdash; the natural answer. In the second, <code>libb.so</code> bound to <code>./prog2</code>, the executable, and the line is otherwise identical. <strong>The loader is not reporting an anomaly. It is reporting a search that succeeded earlier than expected.</strong></p>
                <p>Now the part that makes the point land. It is not just the program&rsquo;s own call that was redirected &mdash; the <em>library&rsquo;s</em> was:</p>
                <div class="hex-dump">
                    <pre>$ python3 dynscope.py search ./prog2 lib_value
Every definition of lib_value in scope order
    0  prog2       0x1150  &lt;== WINS
    2  liba.so     0x1100
</pre>
                </div>
                <p><strong>Two definitions, and the loser is the one that exports it deliberately.</strong> The library is not being asked politely; it is simply later in the list. And the loader&rsquo;s answer and the artifact&rsquo;s answer agree, computed from completely different inputs.</p>
                <p>Now the same thing at scale, because one function is not a mechanism. <code>LD_PRELOAD</code> is interposition with the scope edited rather than the source:</p>
                <div class="hex-dump">
                    <pre>$ cat myprintf.c
#define _GNU_SOURCE
#include &lt;stdio.h&gt;
#include &lt;dlfcn.h&gt;
int printf(const char *fmt, ...){
  static int (*real)(const char *, ...) = NULL;
  if (!real) real = dlsym(RTLD_NEXT, "printf");
  fputs("[mine] ", stderr);
  return real(fmt);
}

$ clang -shared -fPIC -o myprintf.so myprintf.c -ldl
$ LD_PRELOAD=$PWD/myprintf.so ./prog
  [mine]   lib_value()=1    mid_value()=11
</pre>
                </div>
                <p><strong>The library&rsquo;s internal <code>printf</code> call went through the preloaded one.</strong> Two things in that program are worth noticing, and both are mechanisms this course covers later:</p>
                <ul class="lesson-list">
                    <li><code>RTLD_NEXT</code> in <code>dlsym</code> is not &ldquo;the next one after this handle&rdquo;. It is <strong>&ldquo;start the scope search <em>after</em> the object that asked&rdquo;</strong>. Without it, the preloaded <code>printf</code> would find itself and recurse forever. <a href="/courses/dyn/lessons/dyn-dlopen">The dlopen concept</a> covers what <code>RTLD_NEXT</code> actually means.</li>
                    <li>The symbol is named <code>printf</code> and defined in the preload, and it is found <em>before libc</em> &mdash; because <code>LD_PRELOAD</code> libraries are placed at the front of the scope, ahead of the executable. That is the same rule as &ldquo;executable first&rdquo; with one more step in front of it.</li>
                </ul>
                <p>And the honest measurement of the cost, which is a real number and not a slogan:</p>
                <div class="hex-dump">
                    <pre>$ LD_DEBUG=bindings ./prog 2&gt;&amp;1 | grep -c "binding file"
  99                                  (nothing preloaded)
$ LD_PRELOAD=/lib/x86_64-linux-gnu/libm.so.6 LD_DEBUG=bindings ./prog 2&gt;&amp;1 \
      | grep -c "binding file"
  117                                 (eighteen MORE)
</pre>
                </div>
                <p><strong>Interposition is not free, and the first draft of this page claimed it was.</strong> The measurement says 99 bindings normally and 117 with a library preloaded, and the extra eighteen are the reason: <strong>a preloaded library brings its own undefined references with it</strong>, and the loader has to resolve those too. You did not just retarget one answer; you added an object to the scope and the object brought work.</p>
                <p>What <em>is</em> true, and worth separating from what is not: retargeting a single symbol costs nothing measurable, because a search that succeeds at index 0 is not slower than one that succeeds at index 3. The cost is the whole library, not the interposition.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The case that makes this a security property rather than a curiosity: an attacker-supplied library that wins a name and is never linked against anything.</p>
                <div class="hex-dump">
                    <pre>  a program runs, unprivileged, and somewhere a
  writable directory is on its search path.

  attacker drops libsqlite3.so.6.10.0 there, exporting
  every name the real one exports, and every one of
  them runs attacker's code.

  the program's DT_NEEDED says "libsqlite3.so.6". the
  loader finds the ATTACKER's file first, because of
  where it is looking, and from that moment every
  sqlite call in the program -- including the ones
  inside the real library, if the real library got
  loaded at all -- is attacker's.

  nothing in the program changed. no flag, no
  environment variable the program set, no
  relinking. the same binary, run as the same user,
  with the same arguments.
</pre>
                </div>
                <p><strong>This is the direct consequence of the two measured facts above, and it is why &ldquo;search the scope in order, executable first&rdquo; is a design decision with a security cost.</strong> The mitigations are all about narrowing the search rather than changing the rule:</p>
                <div class="hex-dump">
                    <pre>  DT_RUNPATH not DT_RPATH   RUNPATH is searched AFTER
                         LD_LIBRARY_PATH, so a set
                         LD_LIBRARY_PATH overrides it.
                         RPATH is searched BEFORE, so
                         the binary wins -- and a
                         directory the attacker controls
                         earlier in RPATH wins over
                         everything. that ordering
                         difference is the whole reason
                         the deprecation happened.

  -z nodefaultlib    drop /lib and /usr/lib from
                     the search, forcing everything
                     to be named.

  absolute soname    a DT_NEEDED of "/opt/x/libfoo.so"
                     is not searched for at all.

  and the real fix, which is not a linker flag:
  do not have a writable directory on the path.
</pre>
                </div>
                <p>Which is the honest place to end the security thread: <strong>the mechanism is a search order, and the defence is mostly about the directories the search covers.</strong> The <a href="/courses/reloc/lessons/pie-randomize">Relocations course</a> argued that PIE removes address-prediction attacks and does nothing for a stack pointer or a vtable; this is the same shape. Interposition is not address randomisation and is not fixed by it, because there is no address to randomise &mdash; there is a <em>name</em>, and the name is resolved by order.</p>
                <p>One more thing worth measuring, because it is the boundary of the effect. <strong>Only symbols the library actually exports are candidates.</strong> A <code>static</code> function, or one marked <code>hidden</code>, is not in <code>.dynsym</code>, so nothing can interpose on it:</p>
                <div class="hex-dump">
                <pre>$ nm -D --defined-only liba.so | awk '{print "  exported: "$3}'
  exported: lib_value
$ nm liba.so | awk '/ t /{print "  local:    "$3}'
  local:    deregister_tm_clones
  local:    _fini
  local:    static_helper
</pre>
                </div>
                <p><strong>Three local symbols that the loader will never consider</strong> &mdash; two of them the C runtime&rsquo;s, and <code>static_helper</code> is the one this course put in <code>lib.c</code> to make the point checkable. All three are in the full symbol table with a lower-case <code>t</code> and none is in <code>.dynsym</code>.</p>
                <p>The loader searches <code>.dynsym</code> and only <code>.dynsym</code>, so a symbol that is not in that list is not a candidate for anything &mdash; not for interposition, not for <code>dlsym</code>, not for another library to bind against. And that single fact is the subject of <a href="/courses/dyn/lessons/dyn-export">the next module</a>, which is entirely about deciding what lands in that list.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/dyn/assets/samples
$ ./build_samples.sh 2&gt;&amp;2 | sed -n '/D2/,/D3/p'
$ python3 crosscheck.py 2&gt;&amp;2 | sed -n '/\\[2\\]/,/\\[3\\]/p'
$ python3 dynscope.py search ./prog2 lib_value
</pre>
                </div>
                <p>Then interpose on something real, which is where it stops being a demonstration:</p>
                <div class="hex-dump">
                    <pre>  1. Interpose on `puts` using LD_PRELOAD, the way
     the concept does. Now interpose on MALLOC. Count
     the allocations before and after: a counting
     malloc is a real tool and this is how it is built.

  2. Remove RTLD_NEXT and replace it with dlsym(h,
     "printf"). What happens? (It recurses until the
     stack runs out. Predict the failure before you run
     it, then run it in a subshell.)

  3. The executable defines lib_value and gets 100. Now
     give liba.so a WEAKER definition of the same name
     and link prog2 against it. Does the executable
     still win? (It should -- weak vs strong is a
     LINK-time rule, and this is a run-time search.
     Working out why is the exercise.)

  4. Build a library with -fvisibility=hidden and try
     to interpose on a function in it. Can you? (You
     cannot, and the reason is one line of the previous
     concept.)

  5. LD_PRELOAD a library that exports a symbol the
     program does not even reference. Does anything
     change? (No, and checking WHY -- the loader only
     binds symbols that are actually undefined somewhere
     -- is the point.)
</pre>
                </div>
                <p>Exercise 3 is the one that teaches the boundary between the two passes, and it is a question people get wrong with confidence. <strong>Weak and strong is a link-time decision, made by <code>ld</code>, about which definition ends up in the output.</strong> The run-time scope search has no opinion about weak symbols at all &mdash; it takes the first object that defines the name, and by the time it runs the question has already been settled. <code>prog2</code> wins because it is <em>index 0</em>, not because it is strong.</p>
                <p>Exercise 1 is the one that is worth doing for its own sake. A counting allocator built as an <code>LD_PRELOAD</code> is about thirty lines, it needs no cooperation from the program, and it is how profilers, tracers and leak checkers have been built for thirty years. <strong>Interposition is not a curiosity you will read about again; it is a tool you will write.</strong></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the second of three scope concepts and the one with the most consequences. <a href="/courses/dyn/lessons/dyn-scope">The Global Scope</a> gave the algorithm; this one walks through its first consequence and shows that it reaches further than anyone expects. <a href="/courses/dyn/lessons/dyn-order-runtime">Breadth-First</a> takes the second. <strong>All three are one idea, and after this module the phrase &ldquo;resolved at run time&rdquo; should mean &ldquo;first match in an ordered list&rdquo; rather than &ldquo;looked up somehow&rdquo;.</strong></p>
                <p>The connection to the <a href="/courses/sym/lessons/sym-visibility">symbol-resolution course&rsquo;s visibility concept</a> is the one that makes this a design tension rather than a curiosity. That concept found that <code>visibility("hidden")</code> and <code>visibility("internal")</code> <em>demote the binding to local</em> and remove the symbol from <code>.dynsym</code> entirely, so that for two of the four visibility values the answer is not in <code>st_other</code> at all. <strong>That is the mechanism this concept depends on.</strong> Hidden is not a weaker kind of visible; it is the mechanism by which a symbol stops being a candidate, and therefore the way a library opts out of being interposed on.</p>
                <p>The second connection is to <code>LD_PRELOAD</code> and therefore to the whole family of runtime tricks, and the <a href="/courses/elf/lessons/ld-so">ELF course</a> already stated that the variable exists without explaining what it does. Now it can: <strong><code>LD_PRELOAD</code> puts libraries at the front of the scope</strong>, ahead of the executable, which is the same rule as &ldquo;executable first&rdquo; with one more step in front. A reader who has this concept does not need to be told which of two symbols will win; they can derive it.</p>
                <p>And the connection that closes the module is the security framing, which links forward rather than back. <a href="/courses/reloc/lessons/pie-randomize">Does the Executable Actually Move?</a> in the Relocations course listed the attack classes PIE removes and, pointedly, the ones it does not: a return address on the stack, a vtable pointer in read-only data. <strong>Interposition is a fifth class, and it is the only one with no address involved at all.</strong> There is nothing to randomise: there is a name, and the name is resolved by order. That is why the mitigations in this concept are all about directories and flags rather than about entropy, and why a course that taught only PIE would leave this one wide open.</p>
                <p>Forward into the building module, this concept creates the problem the next three solve. <strong>If a library&rsquo;s exported symbols are all interposition candidates, then a library author needs control over two separate things: what it exports, and what its own internal calls bind to.</strong> Those are different questions with different answers, and <a href="/courses/dyn/lessons/dyn-export">Hiding Things, and the Trap</a> is the first and <a href="/courses/dyn/lessons/dyn-symbolic">One Instruction Called -Bsymbolic</a> is the second. Keeping them apart is the point of having both.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dyn/lessons/dyn-scope">Previous: The Global Scope</a></span>
                <span>Next: <a href="/courses/dyn/lessons/dyn-order-runtime">Breadth-First, and Why It Matters</a></span>
            </div>
        </div>
    

    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
