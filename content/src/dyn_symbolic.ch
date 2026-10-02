// Dynamic Linking and Shared Libraries — Module 2: Building a Library
// Concept: what -Bsymbolic binds, what it does not, and the precise thing its
// name hides.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dyn_symbolic() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("One Instruction Called -Bsymbolic — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson dyn-lesson">
            <a href="/courses/dyn" class="back-link">Back to course</a>
            <h1>One Instruction Called -Bsymbolic</h1>
            <div class="lesson-meta">21 min &middot; Module 2: Building a Library &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A library that defines a function and calls it. The most ordinary code there is, and <a href="/courses/dyn/lessons/dyn-interpose">interposition</a> means the call is not necessarily the library&rsquo;s own.</p>
                <div class="hex-dump">
                    <pre>/* self.c */
int helper(int x){ return x * 3; }        /* defined HERE */
int entry(int x){ return helper(x) + 1; } /* and called HERE */

/* selfmain.c */
extern int entry(int);
int helper(int x){ return x * 1000; }     /* the program tries to interpose */
int main(void){ printf("  entry(2) = %d\n", entry(2)); return 0; }
</pre>
                </div>
                <p>Build the library twice, once with the flag:</p>
                <div class="hex-dump">
                    <pre>$ clang -fPIC -shared                  -o libself.so     self.c
$ clang -fPIC -shared -Wl,-Bsymbolic   -o libself_sym.so self.c
$ clang -o t_plain    selfmain.c ./libself.so     -Wl,-rpath,'$ORIGIN'
$ clang -o t_symbolic selfmain.c ./libself_sym.so -Wl,-rpath,'$ORIGIN'
$ ./t_plain; ./t_symbolic
  entry(2) = 2001
  entry(2) = 7
</pre>
                </div>
                <p><strong>2001 against 7.</strong> The library&rsquo;s own <code>helper</code> returns <code>2*3</code>, plus one, so 7. The program&rsquo;s returns <code>2*1000</code>, so 2001. <code>-Bsymbolic</code> made the library win its own argument &mdash; and it is one instruction.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Find the difference between the two libraries, because it is smaller than the flag name suggests.</p>
                <div class="formula">
  $ for lib in libself.so libself_sym.so; do
      llvm-objdump-21 -d --no-show-raw-insn $lib | sed -n '/&lt;entry&gt;/,/^$/p' | grep call
    done

  libself.so       callq  0x1030 &lt;helper@plt&gt;
  libself_sym.so   callq  0x1100 &lt;helper&gt;

  ONE INSTRUCTION.

  callq &lt;helper@plt&gt;   the call goes to the PLT, which
                     jumps through a GOT slot the LOADER
                     fills. indirect, and the loader is
                     free to put anyone there.

  callq &lt;helper&gt;       the call goes straight to the
                     address the LINKER computed. no PLT,
                     no GOT slot, no loader decision.
                     There is nothing left to interpose.

                </div>
                <p><strong>That is the whole mechanism, and it is a relocation difference rather than a policy.</strong> The reference to <code>helper</code> normally gets <code>R_X86_64_PLT32</code> &mdash; a PC-relative reference that the loader resolves through a slot, precisely so it <em>can</em> choose a different answer. <code>-Bsymbolic</code> makes the linker resolve it at link time instead, to a definition it can see in the file it is producing. <strong>The relocation type changes; the search never happens.</strong></p>
                <p>And the thing the name hides, which is the part worth the concept:</p>
                <div class="formula">
  -Bsymbolic binds references to symbols THE LIBRARY
  ITSELF DEFINES.

  not:
    references to symbols in other libraries
    references to symbols it does not define
    anything about what it EXPORTS

  a library calling libc's memcpy:
    -Bsymbolic does nothing. there is nothing of the
    library's to bind; the symbol belongs to libc and
    the loader will decide where memcpy lives.

  a library calling its own internal helper:
    -Bsymbolic binds it, because the library can see
    the definition at link time.

  the flag is "bind MY symbols", read precisely. not
  "bind symbols".

                </div>
                <p><strong>The first attempt to measure this in this course got it wrong in exactly that way</strong> &mdash; it used a library calling a function from a <em>different</em> library, and the flag changed nothing at all: identical disassembly, identical behaviour, still 110. That was correct behaviour and it is the teaching point, so both experiments are below.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>First, that <code>.dynsym</code> is untouched &mdash; because this is a binding flag, not an export flag:</p>
                <div class="hex-dump">
                    <pre>$ for lib in libself.so libself_sym.so; do
    printf "  %-16s dynsym: " $lib
    llvm-nm-21 -D --defined-only $lib | awk '{printf "%s ", $3}'; echo
  done
  libself.so       dynsym: entry helper
  libself_sym.so   dynsym: entry helper
</pre>
                </div>
                <p><strong>Identical.</strong> Both libraries still export <code>helper</code>, and both are still interposable <em>by anything that wants them</em>. <code>-Bsymbolic</code> does not hide the symbol; it changes what the library&rsquo;s <em>own</em> call binds to. <strong>Those are two different questions and the previous concept was about the first one.</strong></p>
                <p>Now the negative case, which is the one that makes the rule precise. A library that calls <em>another</em> library:</p>
                <div class="hex-dump">
                    <pre>$ clang -fPIC -shared -Wl,-Bsymbolic -o libb_sym.so mid.c -L. -la
$ llvm-objdump-21 -d --no-show-raw-insn libb_sym.so | sed -n '/&lt;mid_value&gt;/,/^$/p' | grep call
  1114:  callq  0x1030 &lt;lib_value@plt&gt;
                       ^^^^^^^^^^^^^^ STILL THROUGH THE PLT

$ ./prog3        # main2 + libb_sym.so, same interposition
  prog's lib_value()=100   libb's view of it=110
</pre>
                </div>
                <p><strong>Identical to the non-symbolic build, and the interposition still happens.</strong> <code>lib_value</code> is defined in <code>liba.so</code>, not in <code>libb</code>, so <code>-Bsymbolic</code> had nothing to bind and correctly did nothing. <strong>If you reach for this flag to stop a library from being interposed on, and the interposition is coming from a symbol the library does not define, it will not work and nothing will tell you.</strong></p>
                <p>Which brings up the two flags you actually want, and the difference between them:</p>
                <div class="hex-dump">
                    <pre>  -Bsymbolic            every reference the linker can
                       resolve WITHIN this library is bound
                       locally. one instruction per call site.

  -Bsymbolic-functions   the same, but only for FUNCTIONS.
                       references to DATA still go through
                       the GOT and remain interposable.

  -fno-semantic-interposition
                       a COMPILER flag, and different in
                       kind: it tells the compiler that a
                       call to a function in the same
                       translation unit may be turned into
                       a direct call, because no interposition
                       will be allowed. it is finer-grained
                       than -Bsymbolic and it changes the
                       code the COMPILER emits, before any
                       linker is involved.

  measure the difference on a self-referential function:
    -fno-semantic-interposition  produces the SAME single
    direct callq as -Bsymbolic, and does it for a case
    -Bsymbolic cannot reach: a call the linker never sees
    as a relocation at all, because it was inlined away.
</pre>
                </div>
                <p><strong>Which of the three you want depends on a question only you can answer: do you care about being interposed on, or only about being <em>inconsistent</em>?</strong> A library that wants to be replaceable should use neither. A library whose internal helpers must be reliable wants both.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The case where a library is genuinely broken by interposition, which is rare, real, and worth recognising when you see it.</p>
                <div class="hex-dump">
                    <pre>  the shape: a library with INTERNAL STATE that
  its exported functions both read and write.

    static int counter;              /* file-static */
    int  bump(void){ return ++counter; }
    int  read(void){ return counter; }

  both bump() and read() are in .dynsym.

  a program that defines its OWN bump() -- for any
  reason, including a completely innocent one -- now has
  read() return 0 forever, because read() calls the
  program's bump(), which touches a different counter.

  this is not a security bug. it is a program that is
  correct on the build machine and wrong everywhere
  else, and the symptom is "a library function always
  returns the initial value", which is a miserable thing
  to debug.
</pre>
                </div>
                <p><strong>And note what does <em>not</em> fix it: <code>static</code> on <code>counter</code> already guarantees the library&rsquo;s two functions share one variable.</strong> The problem is not the variable, it is the <em>function call</em> between them, which goes through the PLT and can be redirected. <strong>Shared state protected by a file-static variable is still reachable through a replaceable function.</strong> That is a genuinely counter-intuitive corner, and it is the clearest argument for <code>-Bsymbolic</code> being a correctness tool.</p>
                <p>The performance side, which is real and modest and worth stating honestly rather than overselling:</p>
                <div class="hex-dump">
                    <pre>  the direct call saves:
    - the PLT stub: one indirect jump
    - the GOT load: usually already in L1, so the
      dependent-load cost is small in practice
    - for a hot leaf function called in a loop, this is
      measurable; for a function called once, it is not.

  the honest summary: -Bsymbolic is a correctness and
  predictability flag that happens to be slightly faster.
  Build it for the first reason. If you are choosing
  between "measurable speedup" and "my library behaves
  like itself", take the second every time.
</pre>
                </div>
                <p>And the cost, which nobody mentions and which is the real reason the flag is not the default. <strong>It removes a feature.</strong> A library built with <code>-Bsymbolic</code> can no longer be interposed on <em>itself</em>, which means:</p>
                <div class="hex-dump">
                    <pre>  you cannot use LD_PRELOAD to replace one of its
  internal functions in order to instrument it. profilers,
  tracers, allocators and sanitizers all work by
  interposing.

  you cannot patch a bug in an internal function
  without a source rebuild.

  the library becomes opaque to the ecosystem of tools
  that depends on being able to substitute a function.

  which is a legitimate choice for a leaf utility and a
  bad one for a widely-deployed library. there is no
  universally correct answer, and pretending otherwise
  is how people end up with libraries that cannot be
  profiled.
</pre>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/dyn/assets/samples
$ ./build_samples.sh 2&gt;&amp;2 | sed -n '/D4/,/D6/p'
$ python3 crosscheck.py 2&gt;&amp;2 | sed -n '/\\[4\\]/,/\\[6\\]/p'
</pre>
                </div>
                <p>Then map the boundary of the flag, which is the useful skill:</p>
                <div class="hex-dump">
                    <pre>  1. For each of these, does -Bsymbolic change the
     instruction, and why?

       (a) a library calls its own function
       (b) a library calls another library's function
       (c) a library calls a libc function
       (d) a library calls through a function POINTER it
           was handed
       (e) a library calls an IFUNC resolver

     (d) and (e) are the interesting ones: neither is a
     call the linker can resolve, so neither can be
     affected by a LINK-time flag.

  2. Add -Bsymbolic-functions to the -Bsymbolic build and
     diff. Which references changed and which did not? (A
     data reference cannot become a direct access, so
     only the function calls should differ.)

  3. Write the counter example from the previous section
     and run it with and without -Bsymbolic. Then WITHOUT
     any flag but with the program's bump() renamed. (All
     three behave differently and only one is right.)

  4. Take a real library with a known interposition
     problem and try to fix it with -Bsymbolic. Count the
     instrumentation tools that stop working. Is the
     trade worth it? (Answer for yourself; there is no
     general answer and anyone who claims otherwise has
     not tried to profile it.)

  5. The one to end on: build libself.so, then patch its
     PLT stub by hand with a debugger or objcopy so the
     call goes somewhere else. It is the same class of
     change -Bsymbolic makes, done after the fact. What
     does that tell you about how much of the loader's
     flexibility is a decision rather than a necessity?
</pre>
                </div>
                <p>Exercise 1 is the one that gives you the rule rather than the anecdote, and the answer is worth predicting before you run it. <strong><code>-Bsymbolic</code> can only affect a call the linker resolves, which means a call that becomes a relocation in the object file.</strong> A call through a function pointer does not &mdash; the target is a runtime value &mdash; and an <code>IFUNC</code> resolver is chosen by the loader for its own reasons. So (a) changes, (b) and (c) do not, and (d) and (e) cannot be reached by a link-time flag at all.</p>
                <p>Exercise 5 is the philosophical one, and it is the reason to understand this flag rather than just memorise it. The difference between <code>callq &lt;helper@plt&gt;</code> and <code>callq &lt;helper&gt;</code> is five bytes and a relocation type, and it is the difference between a system where tools can substitute functions and one where they cannot. <strong>Most of what looks like a technical necessity in a linker is a decision somebody made, and this is one of the clearest.</strong></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This closes the building module, and it is the exact complement of <a href="/courses/dyn/lessons/dyn-export">the previous concept</a>. That one asked <em>can anyone see this symbol</em> and answered with <code>.dynsym</code> contents. This one asks <em>does this call go through the search</em> and answers with a relocation type. <strong>Hiding removes a name from the search space; this removes a call from it.</strong> A library that hides its internals still has exported functions calling each other through the PLT, and those are still candidates &mdash; which is why one concept is not enough.</p>
                <p>The connection to the <a href="/courses/reloc/lessons/reloc-why-so-many">Relocations course&rsquo;s vocabulary concept</a> is the mechanism, and it is the clearest payoff in the course. That concept grouped the relocations into the linker&rsquo;s arithmetic and the loader&rsquo;s deferred work, and noted that <code>R_X86_64_PLT32</code> exists so a call can be indirect. <strong>This concept is what that indirection buys and what it costs.</strong> A <code>PLT32</code> reference is a request to the loader: <em>you decide where this function lives</em>. <code>-Bsymbolic</code> is a way of declining to make the request &mdash; and it is a relocation-type change, not a policy setting, which is exactly the lesson that concept taught about the <a href="/courses/reloc/lessons/pic-violation">PIC violation</a> where a diagnostic could name the type.</p>
                <p>And the connection to the <a href="/courses/sym/lessons/sym-plt">symbol-resolution course&rsquo;s PLT concept</a> closes a loop. That course decoded the six-instruction PLT entry, the <code>link_map</code> push, the resolver, and the return address adjustment. <strong>Everything it decoded is the machinery that <code>-Bsymbolic</code> turns off for a given call site.</strong> The resolver still exists, still works, and is still used for every reference that did not decline &mdash; but this one call never reaches it, and the whole sequence collapses to a direct jump.</p>
                <p>Forward into the run-time module, the subject shifts from which binding is chosen to <em>when</em>. <a href="/courses/dyn/lessons/dyn-bind-time">Lazy, Eager, and What Actually Differs</a> is about the timing of the same decision, and it contains a finding that refines what the <a href="/courses/sym/lessons/sym-binding-time">sym course measured</a>: <code>-z now</code> changes no code, exactly as that course said, but it makes <code>.got.plt</code> <em>disappear</em>. <strong>Two flags, one subject, opposite directions: one removes a call from the search, the other removes the wait.</strong></p>
                <p>One connection outward, and it is the sharpest framing in the course. <a href="/courses/dyn/lessons/dyn-interpose">Interposition</a> is a feature: it is how a program replaces a library function without cooperation, how <code>LD_PRELOAD</code> works, and how profilers have been built for thirty years. <code>-Bsymbolic</code> is how a library opts out of that feature. <strong>The whole course is a series of mechanisms for controlling one search, and this is the point at which the searcher gets a vote.</strong> A system where every library opts out would be faster and completely unprofilable, and a system where none does is flexible and occasionally baffling. Neither is the right answer, which is why the flag exists rather than a default.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dyn/lessons/dyn-export">Previous: Hiding Things, and the Trap</a></span>
                <span>Next: <a href="/courses/dyn/lessons/dyn-dlopen">dlopen, dlsym, and the Mode Bits</a></span>
            </div>
        </div>
    

    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
