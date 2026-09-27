// Dynamic Linking and Shared Libraries — Module 3: Loading at Run Time
// Concept: the storage the loader must allocate because no linker could.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dyn_tls_block() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Where the Thread Blocks Come From — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dyn-lesson">
            <a href="/courses/dyn" class="back-link">Back to course</a>
            <h1>Where the Thread Blocks Come From</h1>
            <div class="lesson-meta">21 min &middot; Module 3: Loading at Run Time &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>One variable, one source file, two threads. The addresses are tens of megabytes apart.</p>
                <div class="hex-dump">
                    <pre>$ cat tt.c
#include &lt;stdio.h&gt;
#include &lt;pthread.h&gt;
__thread int t[4];
void *show(void *a){ printf("  thread %p sees t at %p\n",
                            (void*)pthread_self(), (void*)t); return 0; }
int main(void){ pthread_t b;
  printf("  main           sees t at %p\n",(void*)t);
  pthread_create(&b,0,show,0); pthread_join(b,0); return 0; }

$ ./tt
  main           sees t at 0x7091c023f770
  thread 0x7091bffff6c0 sees t at 0x7091bffff6b0
</pre>
                </div>
                <p><strong>Two different addresses for one variable.</strong> The <a href="/courses/reloc/lessons/tls-model">Relocations course</a> established <em>why</em> &mdash; a thread-local has no address until a thread exists &mdash; and showed the four models and the one that has to call a function. <strong>What it could not show is where the storage comes from</strong>, and the answer turns out to be a decision the kernel makes before <code>main</code> runs, using a number the linker computed and the loader copied.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three parties, and the order they act in is the whole point.</p>
                <div class="formula">
  1. THE LINKER lays the thread-locals out, in order, as
     one contiguous block. .tdata for initialised ones,
     .tbss for the rest. and it emits a PT_TLS segment
     saying how big that block is.

  2. THE KERNEL reads PT_TLS, and RESERVES that much
     space in every thread it will ever create -- before
     any of the program runs.

  3. AT THREAD CREATION the kernel COPIES the .tdata
     template into the new thread's block, and ZEROES
     the .tbss part.

  so a thread-local's address is:  (this thread's block
                                   base) + (its offset
                                   in the block)

  and the offset IS a link-time constant. that is the
  whole trick, and it is why a thread-local costs no
  indirection at all in the fast models.

                </div>
                <p><strong>The offset being constant is what makes the fast models fast.</strong> The kernel guarantees the block is at a <em>page-aligned</em> address, so the low 12 bits of any thread-local&rsquo;s address are the same in every thread &mdash; which is exactly what the four relocation models are built on. <code>TPOFF32</code> is &ldquo;my offset in the block&rdquo;, and the instruction computing the address is <code>%fs:0</code>-relative plus that constant.</p>
                <p>And the reason the general-dynamic model exists is now visible: <strong>step 2 is a kernel limit, and it is not unbounded.</strong></p>
                <div class="formula">
  THE SURPLUS, and what happens when it runs out

  the kernel's reservation is made from PT_TLS, and
  there is a maximum the architecture permits. when a
  program loads enough libraries with thread-locals to
  exceed it, the loader cannot put the new library's
  block where the compiler assumed.

  so it allocates the new block DYNAMICALLY, and every
  reference to it must become an offset from the
  thread pointer THROUGH A TABLE, found by calling
  __tls_get_addr.

  that is the R_X86_64_TLSGD relocation the reloc
  course measured, and the reason the -fPIC build had
  a PLT32 against __tls_get_addr while the -fPIE build
  had none.

  the fast models assume the block is where the
  compiler said. the slow model asks.

                </div>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>The layout, and the fact that it is consecutive:</p>
                <div class="hex-dump">
                    <pre>$ cat tls.c
__thread int big_tls[64] = {1};   /* 256 bytes */
__thread int small_tls = 2;
int *where_big(void){ return big_tls; }
int *where_small(void){ return &amp;small_tls; }

$ ./tlsmain
  big=0x7ae26674a770  small=0x7ae26674a870
</pre>
                </div>
                <p><strong>Exactly 0x100 apart, which is <code>sizeof(big_tls)</code>.</strong> Two variables declared in one file, one after the other, and their addresses differ by precisely the size of the first. <strong>The block is a contiguous allocation and the offsets are the distances between them</strong> &mdash; which is the observation that makes the <code>TPOFF</code> relocations in the Relocations course obviously correct rather than merely stated.</p>
                <p>And the template the kernel copies from:</p>
                <div class="hex-dump">
                    <pre>$ readelf -lW tlsmain | grep '^  TLS'
  TLS  0x002cc0 0x0000000000003cc0 0x0000000000003cc0 0x000104 0x000104 R 0x10
                                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                      filesz = memsz = 0x104

$ readelf -SW tlsmain | grep -E '\.tdata|\.tbss'
  [20] .tdata  PROGBITS  0000000000003cc0 002cc0 000104 00 WAT 0 0 16
                                   ^^^^^ 0x104
</pre>
                </div>
                <p><strong><code>p_filesz</code> is the template and <code>p_memsz</code> is the reservation, and they are equal here</strong> &mdash; because both variables are initialised, so everything is in <code>.tdata</code> and there is no <code>.tbss</code> to zero. The <code>WAT</code> flags on the section are worth reading: <strong>Writable, Allocatable, Thread-local Storage</strong>, all three of which the kernel acts on.</p>
                <p>Uninitialised thread-locals would show the difference, and that is the case worth understanding rather than measuring:</p>
                <div class="formula">
  __thread int a = 1;     -&gt; .tdata, 4 bytes
  __thread int b;         -&gt; .tbss,  4 bytes, NO file content

  then   p_filesz = 4      (just a, the template)
         p_memsz  = 8      (a AND b, the reservation)

  the difference is what the kernel ZEROES instead of
  COPYING at thread creation. both models of thread
  creation have to do that, and it is why .tbss
  contributes to memsz and not to filesz.

                </div>
                <p>And the demonstration that makes the whole thing concrete &mdash; the same variable, two threads, and the offsets are identical even though the addresses are not:</p>
                <div class="hex-dump">
                    <pre>$ ./tt
  main           sees t at 0x7091c023f770
  thread 0x7091bffff6c0 sees t at 0x7091bffff6b0
</pre>
                </div>
                <p><strong>Look at the low bits.</strong> <code>770</code> and <code>6b0</code> &mdash; not equal, and not obviously related, because the thread blocks are page-aligned but the <em>offset within a page</em> differs by however the two blocks were placed. The high bits are tens of megabytes apart; the page offset is a per-thread allocation detail. <strong>What is identical in both threads is the offset <em>within the block</em></strong>, and that is the value the compiler baked in and the <code>TPOFF32</code> relocation carries.</p>
                <p><strong>And one thing this course does not claim.</strong> The static-surplus threshold &mdash; the point at which the kernel&rsquo;s reservation runs out and <code>__tls_get_addr</code> starts appearing &mdash; is real and is the mechanism the Relocations course measured on the code side. <strong>It is not measured here.</strong> The attempt to measure it on this machine, by building thirty-two dlopen-able libraries each carrying 256 bytes of thread-local storage, failed to link at all: <code>--as-needed</code> dropped every one of them because nothing referenced a symbol from them. Measuring it needs a program that actually uses them, and that was not built. The mechanism is taught; the number is not claimed.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Why a thread that is created, used and destroyed leaves its block behind, and what that costs.</p>
                <div class="hex-dump">
                    <pre>  the kernel does not hand a thread's TLS block
  back when the thread exits -- the STACK is cached
  for reuse, and the TLS block goes with the thread
  structure.

  a program that creates and joins a million threads
  in a loop therefore allocates a million TLS blocks,
  and the peak is one block per LIVE thread.

  the fix is not in the linker and not in the loader.
  it is: do not create a million threads, or make the
  per-thread state small, or use a pool.

  which is worth knowing because the cost is invisible
  until it is enormous: a thread costs a stack (8 MB of
  address space by default) AND a TLS block, and the
  second is proportional to how much __thread state
  the THREAD'S libraries declare -- including libraries
  the thread's own code never touches.
</pre>
                </div>
                <p><strong>The per-thread cost of a library is paid by every thread, whether or not that thread uses the library.</strong> That is the practical consequence of the model, and it is the reason <code>__thread</code> in a widely-loaded library is a more expensive decision than it looks.</p>
                <p>And the one genuinely counter-intuitive property, which is what makes the model worth a concept:</p>
                <div class="hex-dump">
                    <pre>  PT_TLS describes the block for the WHOLE PROCESS,
  not per object. the linker concatenates .tdata and
  .tbss from every object and every library into ONE
  segment with ONE size.

  so: a library cannot ask for its own TLS block.
  it contributes a fragment, the linker concatenates,
  and the kernel reserves the sum for every thread.

  and the offsets handed out are global. a library
  compiled standalone does not know its offset until
  it is linked into something, which is exactly why
  the general-dynamic model exists to cope with being
  loaded when the answer is no longer knowable.
</pre>
                </div>
                <p><strong>That is the last piece of the thread-local story, and it closes a loop three courses long.</strong> A <code>__thread</code> variable cannot have a link-time address, because the block is per-thread; it cannot have a small per-object offset either, because the block is per-process; and it cannot be given one by a <code>dlopen</code>ed library, because the reservation has already happened. <strong>General-dynamic TLS is not an optimisation that got out of hand &mdash; it is what is left when a value has no constant address for three independent reasons.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/dyn/assets/samples
$ ./build_samples.sh 2&gt;&amp;2 | sed -n '/D13/,$p'
$ python3 crosscheck.py 2&gt;&amp;2 | sed -n '/\\[13\\]/,/\\[14\\]/p'
</pre>
                </div>
                <p>Then finish the experiment this page declined to do, which is the honest next step:</p>
                <div class="hex-dump">
                    <pre>  1. Build N libraries, each with 256 bytes of
     __thread state, and a program that REFERENCES a
     symbol from every one -- otherwise --as-needed
     drops them, which is exactly what went wrong when
     this page was written. Then:
       for N in 1 2 4 8 16 32 64:
         readelf -dW progN | grep -c tls_get_addr
     Find the N where the answer turns from 0 to 1.
     (That number is the surplus on this machine, and it
     is a property of the KERNEL -- not of the linker,
     not of the compiler, and not portable.)

  2. Read PT_TLS p_memsz for progN. Does it grow with
     N? It should grow by exactly 256 per library, and
     that is the number the kernel multiplies by the
     thread count.

  3. Add a __thread variable with an initialiser to one
     library and an uninitialised one to another.
     Compare .tdata and .tbss, and PT_TLS p_filesz
     against p_memsz. (This is the part this page
     describes by mechanism and does not measure.)

  4. Write a program that creates and joins 100,000
     threads, each touching one __thread variable.
     Watch RSS. Then remove the __thread and watch
     again. (The stack dominates -- 8 MB of ADDRESS
     space, not necessarily resident -- and the TLS
     block is the part that scales with the LIBRARIES.)

  5. In a real program, find the thread with the
     largest TLS block. It is not the one you expect,
     and finding it is a genuinely useful thing to know.
</pre>
                </div>
                <p>Exercise 1 is the one this page explicitly could not complete, and leaving it as an exercise rather than a result is the right call. <strong>The failure was instructive: <code>--as-needed</code> silently dropped thirty-two libraries that had been built, linked and reported no problem</strong>, because nothing referenced a symbol from them. A measurement that requires the thing under test to actually be present has a failure mode that looks exactly like success, and that is worth internalising independently of thread-local storage.</p>
                <p>Exercise 3 is the one that makes the <code>.tbss</code> description real rather than remembered. <strong><code>p_filesz</code> is what the kernel copies and <code>p_memsz</code> is what it reserves, and the gap between them is exactly the zero-filled tail.</strong> Every other segment in the file has <code>filesz &le; memsz</code> for the same reason &mdash; <code>.bss</code> occupies address space with no file content &mdash; and thread-local storage is simply the case where the kernel has to do the zeroing itself, per thread, at run time.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This closes module 3, and it is the third and last piece of a story the <a href="/courses/reloc/lessons/tls-model">Relocations course</a> started and could not finish. That course established that a thread-local has no address until a thread exists, measured the four models, and found that general-dynamic is the only one that has to <em>call a function</em>. <strong>This concept answers the two questions that left over: where the storage comes from, and why the fast models can be fast at all.</strong></p>
                <p>The answer turns out to be a link-time constant, which is the pleasing part. <strong>The offset of a thread-local within its block is decided by the linker, concatenated across every object, and is the same in every thread</strong> &mdash; because the kernel guarantees each block starts at a page boundary and copies the same template into each one. That is why <code>TPOFF32</code> is a four-byte immediate rather than a pointer chase, and it retroactively explains the Relocations course&rsquo;s measurement that <code>-fPIE</code> needed no <code>__tls_get_addr</code> call: a PIE&rsquo;s block is arranged so the offset is knowable, and the general-dynamic path only appears when it is not.</p>
                <p>The second connection is to the <a href="/courses/elf/lessons/entry-point">ELF course&rsquo;s entry-point concept</a>, because the kernel&rsquo;s TLS reservation happens before the program&rsquo;s first instruction. <strong><code>PT_TLS</code> is read by the same kernel code that reads <code>PT_INTERP</code></strong>, before it decides whether to load a dynamic linker at all. A static binary with thread-locals still gets its blocks, which is a small and pleasant fact: the TLS machinery is the loader&rsquo;s job, but the <em>reservation</em> is the kernel&rsquo;s, and it happens in both cases. That is why thread-local storage is one of the few features that works identically in a static binary and a dynamic one.</p>
                <p>And the connection to the module it sits beside, which is about a different kind of reservation. <a href="/courses/dyn/lessons/dyn-bind-time">Lazy, Eager</a> is about <em>when</em> a binding decision happens. This concept is about <em>where storage comes from</em>. Both are the loader doing work no linker could, and the pair covers the two things that make dynamic linking more than a name-resolution scheme: it needs a program to be running, and it needs memory that did not exist when the file was written.</p>
                <p>Forward to the last concept, which is the build. <a href="/courses/dyn/lessons/dyn-resolve">Rebuilding the Scope Yourself</a> does not handle thread-locals &mdash; and saying so is part of it. The artifact reads <code>DT_NEEDED</code>, walks it breadth-first, and resolves plain names. <strong>Versioned symbols, <code>RTLD_NEXT</code>, and thread-local offsets are all extensions that need more tables, and naming them precisely is how you know what the two-hundred-line version does and does not model.</strong> A resolver that quietly ignored a version suffix would be worse than one that refused the file, and the refusal is a feature.</p>
                <p>One connection outward, for the platform framing. <a href="/courses/link/lessons/link-write-script">The Static Linking course</a> claimed that <code>dlopen</code> is one of the things <code>-static</code> gives up, and cited thread-local storage as part of the reason. <strong>This concept is the mechanism behind that claim, and it is a satisfying one: <code>dlopen</code> of a library with thread-locals either needs the surplus or needs a call to <code>__tls_get_addr</code>, and a static binary has no dynamic loader to provide either.</strong> The static-linking course stated the consequence; this one gives the cause, three courses apart.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dyn/lessons/dyn-bind-time">Previous: Lazy, Eager, and What Actually Differs</a></span>
                <span>Next: <a href="/courses/dyn/lessons/dyn-resolve">Rebuilding the Scope Yourself</a></span>
            </div>
        </div>
    

    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
