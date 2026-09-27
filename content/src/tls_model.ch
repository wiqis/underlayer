// Relocations, PIC and PIE — Module 3: How It Fails
// Concept: four thread-local models, and the one case where resolving a symbol
// means running code.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_tls_model() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The One Relocation That Calls the Loader — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson reloc-lesson">
            <a href="/courses/reloc" class="back-link">Back to course</a>
            <h1>The One Relocation That Calls the Loader</h1>
            <div class="lesson-meta">25 min &middot; Module 3: How It Fails &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every relocation so far had the same shape: read three numbers, do arithmetic, write four bytes. This one does not, and the reason is not an oddity of the encoding. It is because <strong>a thread-local variable has no address until a thread exists</strong>, and threads are created at run time, long after every program that could resolve it has exited.</p>
                <p>Here is the smallest specimen that shows it, and the relocations the compiler emits:</p>
                <div class="hex-dump">
                    <pre>$ cat tls2.c
extern __thread int ext_tls;      /* another module */
static __thread int my_tls;       /* THIS module     */
int rd_ext(void){ return ext_tls; }
int rd_mine(void){ return my_tls; }

$ clang -O0 -fPIC -c tls2.c -o tls2_pic.o
$ llvm-objdump-21 -r tls2_pic.o | sed -n '/.text/,/^$/p'
0000000000000008 R_X86_64_TLSGD        ext_tls-0x4
0000000000000010 R_X86_64_PLT32        __tls_get_addr-0x4
0000000000000027 R_X86_64_TLSLD        my_tls-0x4
000000000000002c R_X86_64_PLT32        __tls_get_addr-0x4
0000000000000033 R_X86_64_DTPOFF32     my_tls
</pre>
                </div>
                <p><strong>Two <code>__tls_get_addr</code> calls, in one function, in one object file.</strong> Not one relocation each that the loader patches &mdash; two <em>function calls</em>, to a function the object file imports from somewhere else. Nothing in the previous two modules prepares you for a relocation list that contains a call.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Why the address is unknowable, stated so the impossibility is obvious rather than technical.</p>
                <div class="formula">
  a normal global:  one address, decided by the LINKER
                    and true for the life of the process.

  a thread-local:   one address PER THREAD.

  so "the address of my_tls" is not a value. It is a
  FUNCTION of which thread is asking.

  and the offset of a thread's TLS block depends on:
    - which modules are loaded
    - in what ORDER they were loaded
    - how big each module's TLS block is
    - WHICH THREAD (each thread gets its own copy)

  none of which exist when the linker runs, and the last
  of which does not exist even when the loader runs.

                </div>
                <p><strong>So the address is not a constant to be written into a field; it is a computation to be performed later, on a specific machine, about a specific thread.</strong> That is why this is the one relocation class where the loader must execute code rather than store a number, and it is the reason the type name says &ldquo;get addr&rdquo;.</p>
                <p>Which raises the obvious question: if the answer is expensive and dynamic, why does any program use thread-locals at all? The honest answer is that thread-locals are cheap <em>at run time</em> and expensive <em>to set up</em>, and the four models are four different answers to &ldquo;how much setup does this program want&rdquo;.</p>
                <div class="formula">
  THE FOUR MODELS, in order of increasing speed
  and decreasing generality

  1. GENERAL-DYNAMIC   the loader is asked about the
                       SYMBOL, one call per reference
     relocs: TLSGD + PLT32 __tls_get_addr
     works for: a symbol in ANY module, loaded or
                not yet loaded, at ANY time
     cost: a function call per access

  2. LOCAL-DYNAMIC     the loader is asked about the
                       MODULE, once, then a module-relative
                       offset is added
     relocs: TLSLD + PLT32 __tls_get_addr + DTPOFF32
     works for: a symbol in THIS module only
     cost: one call for N symbols, so it amortises

  3. INITIAL-EXEC      the loader assigns an offset at
                       load time; the code reads the GOT
     relocs: GOTTPOFF
     works for: a module that is loaded AT STARTUP
     cost: no call at run time

  4. LOCAL-EXEC        the offset is known AT LINK TIME;
                       code reads it straight from the
                       thread pointer
     relocs: TPOFF32, and nothing else
     works for: the executable's OWN thread-locals
     cost: no call, no GOT, no indirection at all

                </div>
                <p><strong>Read that as one sentence: the more you assume about the load, the faster the access.</strong> General-dynamic assumes nothing. Local-exec assumes the module is the executable and is the first thing mapped &mdash; which is why it is only usable for a program&rsquo;s own thread-locals and never for a library&rsquo;s.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>The whole ladder, measured. <code>-O0</code> is deliberate and the reason matters, so read the note under the table:</p>
                <div class="hex-dump">
                    <pre>$ for fl in "-fPIC" \
           "-fPIC -ftls-model=local-dynamic" \
           "-fPIC -ftls-model=initial-exec" \
           "-fPIC -ftls-model=local-exec" \
           "-fPIE" \
           "-ftls-model=local-dynamic"; do
    clang -O0 $fl -c tls2.c -o y.o
    printf "%-38s " "$fl"
    llvm-objdump-21 -r y.o | grep -oE "R_X86_64_[A-Z0-9_]+" | sort -u | tr "\n" " "
    echo
  done

-fPIC                              TLSGD TLSLD DTPOFF32 PLT32
-fPIC -ftls-model=local-dynamic   TLSLD DTPOFF32 PLT32
-fPIC -ftls-model=initial-exec    GOTTPOFF
-fPIC -ftls-model=local-exec      TPOFF32
-fPIE                              GOTTPOFF TPOFF32
-ftls-model=local-dynamic         GOTTPOFF TPOFF32   &lt;-- OVERRIDDEN
</pre>
                </div>
                <p><strong>Three things to take from that table.</strong> First, the ladder is <em>monotone</em>: each step down removes a loader call, and the last step removes the GOT as well. <code>local-exec</code> is a single <code>TPOFF32</code> &mdash; one relocation, no call, no slot, nothing to initialise.</p>
                <p>Second, and this is the part that surprises people: <strong><code>-fPIC</code> chooses per symbol, not per file.</strong> Row one has <em>both</em> <code>TLSGD</code> and <code>TLSLD</code>, because the extern symbol needs general-dynamic and the module-local one can use local-dynamic. The compiler is not picking a model for the file; it is picking, per access, the cheapest model that is valid.</p>
                <p>Third, look at the last row. <strong><code>-ftls-model=local-dynamic</code> without <code>-fPIC</code> is silently overridden</strong> &mdash; no <code>TLSLD</code>, no call. You asked for local-dynamic and did not get it. The reason is worth stating as a general rule about compiler flags:</p>
                <div class="hex-dump">
                    <pre>  THE FLAG IS A REQUEST.  PIC-NESS IS A CONSTRAINT.

  without -fPIC, the compiler knows the output is an
  ET_EXEC, which is loaded FIRST and at a KNOWN
  position in the TLS layout. Under that constraint
  local-dynamic is not merely unnecessary -- it is
  WRONG, because the module id of the executable is
  known at link time and asking the loader for it is
  pure overhead.

  so the compiler picks for itself and ignores you.

  and the models only become selectable at all when
  -fPIC is present, because only then is the answer
  genuinely unknown.
</pre>
                </div>
                <p><strong>This is the same shape as the finding in <a href="/courses/reloc/lessons/pie-flags">the PIE module</a> that a codegen flag and a link flag can disagree</strong>, and it is the same lesson: the compiler answers a question about the <em>output</em>, and it has to guess the output from the flags it was given. Here the guess is wrong in a way that costs performance rather than correctness, which makes it easy to miss.</p>
                <p>Now the note on <code>-O0</code>, because it is a measurement lesson and not a formality:</p>
                <div class="hex-dump">
                    <pre>  the first version of this test used:
      static __thread int my_tls = 7;
  compiled at -O1, and concluded that local-dynamic
  and initial-exec "emit the same relocations".

  the truth: -O1 folded `return my_tls;` to the
  constant 7. the memory access disappeared, and the
  TLSLD relocation disappeared with it. there was
  nothing left to distinguish the two models.

  and the extern-only specimen could not have shown
  the difference anyway, because local-dynamic
  REQUIRES the symbol to be in the same module.

  two mistakes, in the same test, pointing the same
  way. the crosscheck now builds both specimens at
  -O0 precisely so this cannot recur.
</pre>
                </div>
                <p><strong>The general form of that mistake is worth carrying: an optimiser that removes the code removes the evidence.</strong> When a measurement is &ldquo;these two things look the same&rdquo;, the first hypothesis should always be <em>my optimiser deleted the difference</em>, not <em>they really are the same</em>.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What the two loader calls actually do, and why general-dynamic takes two arguments.</p>
                <div class="hex-dump">
                    <pre>  __tls_get_addr is a real exported function.
  find it:

  $ nm -D /lib/x86_64-linux-gnu/libc.so.6 | grep tls_get_addr
  0000000000a1b30 T __tls_get_addr@@GLIBC_2.34
                ^ a global, in libc, versioned

  GENERAL-DYNAMIC asks a QUESTION ABOUT A SYMBOL:
      __tls_get_addr(&amp;modid, &amp;offset, &amp;ext_tls)
      "this is the module id I think it is; this is
       the offset I think it is; here is the symbol.
       correct me."

  LOCAL-DYNAMIC asks A QUESTION ABOUT A MODULE:
      __tls_get_addr(&amp;modid, &amp;offset, 0)
      "same question, but the symbol is in THIS module,
       so I do not need to look it up -- just tell me
       where my module's block is, once."

  the loader compares what you claimed against its own
  tables and fixes you up if you guessed wrong. it
  caches the answer, which is why the SECOND access
  in a thread is cheap even in general-dynamic.
</pre>
                </div>
                <p><strong>That &ldquo;claim and correct&rdquo; protocol is the actual mechanism</strong>, and it explains a property that surprises everyone the first time they see it. The compiler emits the module id and offset <em>it believes</em>, the loader checks, and the answer is usually right. That is what makes a <code>PLT32</code> against <code>__tls_get_addr</code> safe even though the offset is genuinely unknowable at link time: the value in the file is a <em>guess</em>, and there is a protocol for being wrong.</p>
                <p>And the reason general-dynamic cannot be optimised away even when the symbol <em>is</em> in the same module is exactly the claim in the table above &mdash; the compiler cannot know whether something will later interpose a definition. <code>-fPIC</code> means &ldquo;assume it might&rdquo;, and that assumption is what forces the general model.</p>
                <p>What the linker cannot do is catch a misapplied model. Forcing <code>-ftls-model=local-dynamic</code> on a symbol defined in <em>another</em> module links without a diagnostic:</p>
                <div class="hex-dump">
                    <pre>$ clang -O0 -fPIC -ftls-model=local-dynamic -c tls3.c -o t3ld.o
$ clang -o t3ld t3ld.o t3def.o        # t3def.c DEFINES ext_tls
$ echo $?
0
$ ./t3ld; echo $?
42
</pre>
                </div>
                <p><strong>It linked, and it ran, and it was right.</strong> And that last part needs a caveat, because it is easy to over-read: this test contains exactly <em>one</em> thread-local module, so the module id the code guessed and the offset the linker assigned happen to agree. <strong>I did not construct a case where it gives the wrong answer.</strong> The honest claim is that the misuse is <em>latent</em> here, not observable &mdash; the linker has no mechanism to detect it, which is the part that matters. A tool that cannot detect a class of misuse is a tool where the misuse is a debugging session rather than a message.</p>
                <p>And the practical reason to care about all four models is that choosing badly is silent. A library compiled with general-dynamic because it might be <code>dlopen</code>ed pays a function call per thread-local access forever; one compiled initial-exec because the author was in a hurry crashes at load time on a <code>dlopen</code>, with a message that points at the caller rather than the model.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/reloc/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/F6/,/F7/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/\\[6\\]/,/\\[7\\]/p'
</pre>
                </div>
                <p>Then derive the model rather than memorise it:</p>
                <div class="hex-dump">
                    <pre>  1. Add a third thread-local, module-local, and
     compile -fPIC. How many __tls_get_addr calls now?
     (Answer: still TWO, not three. Why is that the
     whole point of the local-dynamic model?)

  2. Compile tls2.c at -O1 and at -O0 and diff the
     relocations. Whatever differs, explain the
     optimiser step that removed it.

  3. Make a THREAD-LOCAL MODULE. Two .so files, each
     with its own __thread int, linked into one program.
     Then force local-dynamic on a cross-module symbol
     in a third file, and see whether you can now make
     it give a wrong answer. (This is the case the
     concept says was not constructed here. Try it.)

  4. Add a static __thread int with an initialiser,
     compiled at each -O level. At which level does the
     access vanish, and what is the smallest initialiser
     that survives? (The answer is not zero, and finding
     out why is the exercise.)

  5. Find the __tls_get_addr PLT entry in a real
     binary. Does it exist even in a program that never
     calls it? What does that tell you about when the
     decision to call the loader was made?
</pre>
                </div>
                <p>Question 3 is the one that closes the loop, and it is deliberately the measurement this course <em>declined</em> to make. <strong>The claim on this page is that the misuse is latent under a one-module test and that the linker cannot detect it; whether it is actually wrong under two modules is a separate experiment with a separate answer.</strong> A course that quietly turns &ldquo;I did not test this&rdquo; into &ldquo;it is broken&rdquo; is teaching you to trust a number nobody checked.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the second failure concept and it is the deliberate contrast to <a href="/courses/reloc/lessons/pic-violation">The Relocation That Cannot Be Fixed</a>. <strong>Both are relocations the linker cannot finish, and they fail in opposite ways.</strong> A PIC violation is a request with no answer, so the link fails and the message names the relocation type. A general-dynamic TLS reference is a request with a deferred answer, so the link succeeds and the answer is computed by calling a function while the program runs. One is a compile-time constraint enforced at link time; the other is a run-time protocol. Holding both in your head is what makes the phrase &ldquo;the loader resolves dynamic relocations&rdquo; stop sounding like a catch-all.</p>
                <p>It also amends the group model from <a href="/courses/reloc/lessons/reloc-why-so-many">the vocabulary module</a>, and the amendment is worth isolating. That concept put <code>TLSGD</code>, <code>GOTTPOFF</code> and <code>TPOFF32</code> in group 4 &mdash; the loader&rsquo;s relocations &mdash; alongside <code>GLOB_DAT</code> and <code>JUMP_SLOT</code>. <strong>Group 4 has to be split.</strong> <code>GLOB_DAT</code> is a number to store; <code>TLSGD</code> is a function to call. The unifying idea is not &ldquo;the loader does it&rdquo; but &ldquo;the answer is not available until run time&rdquo;, and that criterion admits both the arithmetic and the non-arithmetic cases.</p>
                <p>The connection to the AArch64 contrast in <a href="/courses/reloc/lessons/reloc-arch-contrast">the first concept</a> is structural and quite pleasing. AArch64 needs two relocations per reference because one instruction cannot reach far enough. TLS general-dynamic needs <em>two</em> relocations &mdash; a <code>TLSGD</code> and a <code>PLT32</code> &mdash; and here it is not about range at all. <strong>Same shape, different reason: when one relocation record cannot carry the whole answer, the format allows a sequence.</strong> A tool author reading a relocation list has to be prepared for entries that are only meaningful in pairs, and the two architectures fail in opposite directions &mdash; AArch64 pairs by proximity, TLS pairs by role.</p>
                <p>Forward to the build exercise, this concept is the one case the applier cannot handle, and knowing why is the point. <a href="/courses/reloc/lessons/reloc-apply">Applying Them Yourself</a> builds a patcher that does arithmetic on three numbers. <code>R_X86_64_TLSGD</code> has no arithmetic to perform &mdash; the <em>value</em> is a runtime function result, and the file contains a guess plus a protocol for correcting it. <strong>So the applier has to recognise the class and decline, and declining correctly is part of applying relocations correctly.</strong> A patcher that wrote a number into a <code>TLSGD</code> field would produce a binary that links, runs, and returns garbage for a thread-local read &mdash; the most expensive kind of bug, because nothing reports it.</p>
                <p>And one connection out to the platform layer, for the security framing. <a href="/courses/reloc/lessons/pie-randomize">Does the Executable Actually Move?</a> listed the attacks PIE removes, and attack (c) was a return address on the stack, &ldquo;not address-dependent, not defeated by PIE.&rdquo; <strong>Thread-local storage is a second, subtler instance of that</strong>: an offset from a thread pointer, where the pointer changes per thread and the offset is a claim the loader may correct. An attacker who can read or write a thread pointer is in the same position as one who can read a stack pointer, and PIE does nothing for either.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/reloc/lessons/pic-violation">Previous: The Relocation That Cannot Be Fixed</a></span>
                <span>Next: <a href="/courses/reloc/lessons/reloc-apply">Applying Them Yourself</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
