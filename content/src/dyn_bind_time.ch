// Dynamic Linking and Shared Libraries — Module 3: Loading at Run Time
// Concept: one binding either way, and the .got.plt section that disappears.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dyn_bind_time() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Lazy, Eager, and What Actually Differs — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dyn-lesson">
            <a href="/courses/dyn" class="back-link">Back to course</a>
            <h1>Lazy, Eager, and What Actually Differs</h1>
            <div class="lesson-meta">20 min &middot; Module 3: Loading at Run Time &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Build the same program twice and diff it. Most people expect a difference in the code, because &ldquo;resolve everything at startup&rdquo; sounds like it should produce different instructions.</p>
                <div class="hex-dump">
                    <pre>$ clang -O2                        -o lazy     lazy.c -L. -llazy -Wl,-rpath,'$ORIGIN'
$ clang -O2 -Wl,-z,now         -o lazy_now lazy.c -L. -llazy -Wl,-rpath,'$ORIGIN' -Wl,-z,now

$ for f in lazy lazy_now; do
    printf "  %-9s .plt=%s  .got.plt=%-6s .got=%s  dyn entries=%s\n" $f \
      "$(readelf -SW $f | awk '/ \.plt /{print $6}')" \
      "$(readelf -SW $f | awk '/\.got\.plt/{print $6}')" \
      "$(readelf -SW $f | awk '/ \.got /{print $6}')" \
      "$(readelf -dW $f | sed -n 's/.*contains \([0-9]*\) entries.*/\1/p')"
  done
  lazy      .plt=000020  .got.plt=000020 .got=000028  dyn entries=28
  lazy_now  .plt=000020  .got.plt=       .got=000048  dyn entries=29
</pre>
                </div>
                <p><strong>The <code>.plt</code> is byte-identical, and a whole section disappeared.</strong> The <a href="/courses/sym/lessons/sym-binding-time">symbol-resolution course</a> established that <code>-z now</code> changes no code, and that is exactly right. What that course could not show is the second half: <strong><code>.got.plt</code> is gone, and <code>.got</code> grew from 0x28 to 0x48 to absorb it.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>What the two PLT slots do, because the difference is entirely about what a slot is <em>for</em>.</p>
                <div class="formula">
  a PLT GOT slot holds one of TWO things, and the
  difference is one bit:

    the linker put a RESOLVER ADDRESS there
        the loader has not run yet. first time this call
        is executed, the slot is the "go to the
        resolver" address, and calling through it runs
        dl_runtime_resolve, which finds the real
        function, writes it into the slot, and jumps
        there. every SUBSEQUENT call goes straight
        through.

    the loader put the REAL ADDRESS there
        because -z now made it resolve everything
        before the program started. the slot has no
        other job, so it does not need its own section.

  which is why .got.plt vanishes under -z now: it
  exists to hold slots that have TWO states. a slot
  with one state is just .got.

                </div>
                <p><strong>So <code>.got.plt</code> is not &ldquo;the GOT for PLT entries&rdquo;; it is the part of the GOT that is not yet resolved.</strong> That is a much better way to hold it, and it explains the section disappearing exactly rather than approximately. The reloc course measured the default script&rsquo;s rule for it &mdash; <code>.got.plt : ... *(.got.plt) *(.igot.plt) </code> &mdash; without knowing that on this toolchain the section can be empty.</p>
                <p>And the decision itself, in the form the loader reports it:</p>
                <div class="formula">
  DT_FLAGS     BIND_NOW     added under -z now
  DT_FLAGS_1   NOW          the NOW bit added too
                       (the lazy build has PIE only)

  and the environment equivalent, which is a different
  mechanism entirely:

  LD_BIND_NOW=1   the loader resolves everything
                  regardless of what the file said

                </div>
                <p><strong>Which brings up the distinction the <code>dlopen</code> concept already introduced, at the loader level rather than the library level.</strong> <code>DT_FLAGS</code> is a property of the <em>file</em> and the loader obeys it; <code>LD_BIND_NOW</code> is a property of the <em>environment</em> and overrides it; <code>RTLD_NOW</code> is a property of one <code>dlopen</code> call. Three levels, one decision, and it is worth being able to say which is which.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>The structural claim first, and it is the one that distinguishes this page from a restatement of the earlier course:</p>
                <div class="hex-dump">
                    <pre>$ readelf -dW lazy_now | grep -E 'BIND_NOW|FLAGS'
  0x000000000000001e (FLAGS)      BIND_NOW
  0x000000006ffffffb (FLAGS_1)    Flags: NOW PIE
$ readelf -dW lazy | grep -E 'BIND_NOW|FLAGS'
  0x000000006ffffffb (FLAGS_1)    Flags: PIE
</pre>
                </div>
                <p><strong>One bit added to <code>DT_FLAGS</code>, one to <code>DT_FLAGS_1</code>, and that is the entire difference in the dynamic section.</strong> Everything else about the file is the same, and the <code>.plt</code> is identical to the byte.</p>
                <p>Now the question the earlier course could not ask, because it is about counting: <strong>how many binding decisions does the loader make?</strong></p>
                <div class="hex-dump">
                    <pre>$ for f in lazy lazy_now; do
    printf "  %-9s %s binding(s) for libfn\n" $f \
      "$(LD_DEBUG=bindings ./$f 2&gt;&amp;1 | grep -c libfn)"
  done
  lazy       1
  lazy_now   1
$ LD_BIND_NOW=1 LD_DEBUG=bindings ./lazy 2&gt;&amp;1 | grep -c libfn
  1
</pre>
                </div>
                <p><strong>One, in all three configurations.</strong> This is the finding, and it is worth sitting with: lazy binding does not make <em>more</em> decisions and does not make a <em>cheaper</em> decision later. It makes the <strong>same single decision</strong>, at a different time. The program calls <code>libfn</code> a thousand times and the loader is involved exactly once in every configuration &mdash; at load time for two of them and at the first call for the third.</p>
                <p>So what does lazy binding actually buy, and what does it cost? Both are narrow:</p>
                <div class="formula">
  IT BUYS   the loader does not have to resolve a
            symbol the program never calls. a library
            with 3000 exports linked into a program
            that calls 12 of them does 12 resolutions,
            not 3000.

  IT COSTS  the first call to each function is a call
            through the resolver: push the link_map,
            push the symbol name, call, patch the
            slot, jump. a few hundred cycles, ONCE.

  IT ALSO   .got.plt stays as a section, because its
  COSTS     slots have two states. (measured: 0x20
            bytes here, and the section is absent
            entirely under -z now)

                </div>
                <p><strong>And the honest limit: no timing claim.</strong> A two-million-call microbenchmark on this machine gave 5.1, 3.8 and 4.5 nanoseconds per call across lazy, <code>-z now</code>, and <code>LD_BIND_NOW=1</code> on the lazy binary. <strong>That is noise, and this course does not teach it as a result.</strong> The structural facts above are exact and reproducible; the wall-clock difference on a modern machine for a single function call is not a claim anybody could defend. The <a href="/courses/reloc/lessons/pie-cost">Relocations course</a> declined a similar claim for the same reason.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Where the choice actually matters, which is not where most people expect.</p>
                <div class="hex-dump">
                    <pre>  lazy binding is a SECURITY decision more than a
  performance one, and the reason is historical.

  the resolver runs arbitrary code at the moment of
  the first call, from inside what looks like an
  ordinary call instruction. a process that has been
  checked by a sandbox and an audit tool has not yet
  run any of that code when the check happens.

  so: -z now is what makes a binary's entire dynamic
  behaviour happen at a moment you can name -- exec, or
  the first instruction -- rather than at a moment
  determined by which branches the program happens to
  take.

  what it costs: a slow start proportional to the
  number of PLT entries, and a failure at startup
  rather than at first call, which for a library with
  an optional dependency is a real behaviour change:

    a plugin that is PRESENT   -> works either way
    a plugin that is MISSING  -> -z now: the program
                                refuses to start
                              -> lazy: the program
                                runs, and dies if it
                                ever calls in
</pre>
                </div>
                <p><strong>That second case is the one to hold on to, and it is a genuine trade rather than a &ldquo;security is always better&rdquo;.</strong> A program that optionally uses a library should be lazy, because eager binding turns a missing optional feature into a fatal startup error. A program whose entire job is to be auditable should be eager, because the audit is worthless if the interesting code runs later.</p>
                <p>And the modern development, which is a good illustration of how this area has moved: <strong>lazy binding is losing ground because <code>RELRO</code> and <code>-z now</code> together are better, and the combination is now the default on most distributions.</strong></p>
                <div class="hex-dump">
                    <pre>  $ readelf -lW lazy_now | grep -E 'GNU_RELRO|GNU_STACK'
    GNU_RELRO  0x0000000000003db8 ... R      0x1
    GNU_STACK  0x0000000000000000 ... RW     0x10

  $ readelf -lW lazy | grep -E 'GNU_RELRO|GNU_STACK'
    GNU_RELRO  0x0000000000003db8 ... R      0x1
    GNU_STACK  0x0000000000000000 ... RW     0x10

  the relocations are RELATIVE either way -- they are
  resolved by the loader at startup REGARDLESS of
  -z now, because there is no PLT involved. -z now
  only changes the PLT ones, and those are the ones
  that stay writable.
</pre>
                </div>
                <p><strong>Which is the important structural point and the reason <code>-z now</code> helps hardening at all.</strong> <code>R_X86_64_RELATIVE</code> &mdash; the relocation for every absolute pointer in the program &mdash; is applied at load time either way, and the page containing those slots can therefore be made read-only afterwards. That is <code>GNU_RELRO</code>. The PLT slots are the exception, because under lazy binding they are still holding resolver addresses and must stay writable. <strong>Close that hole and you have to have resolved them already, which is exactly what <code>-z now</code> does.</strong> The two flags are the same decision seen from a performance angle and a security angle.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/dyn/assets/samples
$ ./build_samples.sh 2&gt;&amp;2 | sed -n '/D7/,/D8/p'
$ python3 crosscheck.py 2&gt;&amp;2 | sed -n '/\\[7\\]/,/\\[8\\]/p'
</pre>
                </div>
                <p>Then find the boundary of the claim, which is a better exercise than repeating it:</p>
                <div class="hex-dump">
                    <pre>  1. Count the bindings in a program that calls
     libfn ZERO times. Now one that calls it once.
     Now once a million times. Plot the three. (This
     is what "one decision" means, and the numbers are
     0, 1, 1.)

  2. Build a .so with 3000 exported symbols and a
     program that calls two of them. How many bindings?
     (Two, under lazy. Under -z now, 3000.) That is the
     real argument for lazy binding and it is worth
     seeing the number.

  3. Now add -Wl,-z,now and look at .got.plt again for
     the 3000-symbol library. Does the section come
     back? (It should not -- the slots still have one
     state each, just a different one.)

  4. With a shared library present, compare
     readelf -lW on the lazy and -z now builds and
     check GNU_RELRO's p_memsz. Does it change? (It
     should NOT, because RELATIVE relocations are
     resolved either way. Understanding why is the
     exercise.)

  5. Take an optional plugin: load it with dlopen
     RTLD_LAZY, call a function, and let it be missing.
     Then with RTLD_NOW. (The second fails at load, the
     first fails at the call. Which behaviour does a
     program want? It depends entirely on whether the
     plugin is a dependency or a feature -- and working
     out which is the design question.)
</pre>
                </div>
                <p>Exercise 2 is the one that gives lazy binding a real justification, and it is the argument its proponents actually make. <strong>Under <code>-z now</code> the loader resolves all 3000 exported symbols; under lazy it resolves the two that are called.</strong> That is a 1500&times; difference in loader work, and on a system with hundreds of libraries it is the difference between a fast start and a slow one. The cost is the opposite for a library with few exports and many calls, which is why the honest answer is &ldquo;it depends on the shape of the program&rdquo;.</p>
                <p>Exercise 4 is the one that connects this concept to the security thread, and the surprising answer is that <code>GNU_RELRO</code>&rsquo;s size does <em>not</em> change. <strong>Because <code>R_X86_64_RELATIVE</code> is resolved at load time either way.</strong> The reloc course measured that relocation type as the loader&rsquo;s most common job, and this is where its necessity becomes obvious: a program full of absolute pointers has hundreds of them, and the only reason the page can be read-only afterwards is that the loader finished with it before <code>main</code>. <strong>Eager binding is not about performance; it is about closing the one gap that RELRO cannot close on its own.</strong></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the timing half of module 3, and it is the smallest correction in the course &mdash; which is itself worth noting. <a href="/courses/sym/lessons/sym-binding-time">The symbol-resolution course</a> said &ldquo;<code>-z now</code> changes no code&rdquo; and proved it. <strong>That is true and it is incomplete, and this concept supplies the missing half: <code>.got.plt</code> disappears and <code>.got</code> grows to absorb it.</strong> A course that stopped at &ldquo;no code&rdquo; would have left the reader thinking nothing at all happens, which is the wrong mental model for a flag whose purpose is security.</p>
                <p>The connection to the <a href="/courses/reloc/lessons/reloc-why-so-many">Relocations course&rsquo;s four-group model</a> is the mechanism. That concept put <code>JUMP_SLOT</code> in the loader&rsquo;s group &mdash; group 4, the relocations that exist so something can be decided later &mdash; and this concept is the measurement of <em>how much later</em>. A <code>JUMP_SLOT</code> is a number the loader writes into a slot; <code>-z now</code> changes only <em>when</em>. <strong>The relocation type is identical, the count of decisions is identical, and the section layout changes anyway</strong> &mdash; which is the clearest demonstration in the course that a relocation record describes a computation and not a moment.</p>
                <p>The second connection is to the <a href="/courses/dyn/lessons/dyn-dlopen">dlopen concept</a>, and the three-level distinction it set up. <code>RTLD_LAZY</code>/<code>RTLD_NOW</code> at <code>dlopen</code>, <code>LD_BIND_NOW</code> in the environment, <code>DT_FLAGS</code> in the file. <strong>Three levels of the same decision, and the precedence runs from weakest to strongest.</strong> A program linked with <code>-z now</code> still gets lazy behaviour for a library it <code>dlopen</code>&rsquo;s with <code>RTLD_LAZY</code>, because the file&rsquo;s flag applies to the file&rsquo;s own PLT and the call-site flag applies to the call. That is worth being able to state, and it is exactly the kind of thing that becomes obvious once you have the two concepts side by side.</p>
                <p>And the connection forward, which completes the module, is the one place the loader does something no linker could. <a href="/courses/dyn/lessons/dyn-tls-block">Where the Thread Blocks Come From</a> is about storage: the <a href="/courses/reloc/lessons/tls-model">Relocations course</a> established that a thread-local variable has no address until a thread exists, and that general-dynamic TLS is the one relocation resolved by <em>calling a function</em>. <strong>Resolving the symbol is only half of it; something also has to allocate the block</strong>, and the loader is doing that with a static-surplus-versus-dynamic decision that has no link-time analogue at all.</p>
                <p>One connection outward, for the security framing that runs through the course. <a href="/courses/reloc/lessons/pie-randomize">The PIE concept</a> listed the attack classes PIE removes and the ones it does not, and named a vtable or function pointer in read-only data as needing <code>RELRO</code> rather than ASLR. <strong>This concept is where <code>RELRO</code> gets its teeth</strong>: the reason the GOT can be read-only is that its only unresolved occupant is the <code>RELATIVE</code> slots, and the reason that is true is that the loader finished with them before <code>main</code>. <code>-z now</code> is not a separate hardening measure bolted on afterwards &mdash; it is what makes the existing one complete.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dyn/lessons/dyn-dlopen">Previous: dlopen, dlsym, and the Mode Bits</a></span>
                <span>Next: <a href="/courses/dyn/lessons/dyn-tls-block">Where the Thread Blocks Come From</a></span>
            </div>
        </div>
    

    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
