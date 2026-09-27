// Symbol Resolution and Symbol Tables — Module 3: Resolution at Runtime
// Concept: eager binding is a dynamic-section flag. The code does not change.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sym_binding_time() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Lazy, Eager, and the Flag That Does Nothing — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson sym-lesson">
            <a href="/courses/sym" class="back-link">Back to course</a>
            <h1>Lazy, Eager, and the Flag That Does Nothing</h1>
            <div class="lesson-meta">20 min &middot; Module 3: Resolution at Runtime &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Linking with <code>-z now</code> is the standard hardening advice, and the reason usually given is that it removes the lazy PLT, which is a writable-then-jump sequence on the stack and therefore a target. It is good advice. Here is what it actually does:</p>
                <div class="hex-dump">
                    <pre>$ readelf -SW lt_lazy | awk '/ \.plt /{print "lazy  .plt size:", $6}'
lazy  .plt size: 000030
$ readelf -SW lt_now  | awk '/ \.plt /{print "eager .plt size:", $6}'
eager .plt size: 000030
</pre>
                </div>
                <p><strong>The same size.</strong> Not smaller, not absent. Now disassemble both and compare instruction for instruction:</p>
                <div class="hex-dump">
                    <pre>$ objdump -d --no-show-raw-insn -j .plt lt_lazy | tail -n +7
  401020:  push   0x2fca(%rip)     # GOT+8
  401026:  jmp    *0x2fcc(%rip)     # GOT+0x10
  401030:  jmp    *0x2fca(%rip)     # GOT+24
  401036:  push   $0x0
  40103b:  jmp    401020
  401040:  jmp    *0x2fc2(%rip)
  401046:  push   $0x1
  40104b:  jmp    401020

$ objdump -d --no-show-raw-insn -j .plt lt_now | tail -n +7
  401020:  push   0x2f9a(%rip)     # GOT+8
  401026:  jmp    *0x2fac(%rip)     # GOT+0x10
  401030:  jmp    *0x2f9a(%rip)     # GOT+24
  401036:  push   $0x0
  40103b:  jmp    401020
  401040:  jmp    *0x2f92(%rip)
  401046:  push   $0x1
  40104b:  jmp    401020
</pre>
                </div>
                <p><strong>Identical.</strong> Every opcode, every operand shape, every jump target within the section. The only differences are the rip-relative displacements, and those differ because the GOT moved &mdash; the <code>.got.plt</code> section is gone and its slots were merged into <code>.got</code>, which grew from 0x20 to 0x48 bytes.</p>
                <p>So where is the change? Here:</p>
                <div class="hex-dump">
                    <pre>$ readelf -dW lt_lazy | grep -cE 'BIND_NOW|FLAGS_1'
0
$ readelf -dW lt_now | grep -E 'BIND_NOW|FLAGS_1'
 0x000000000000001e (FLAGS)              BIND_NOW
 0x000000006ffffffb (FLAGS_1)            Flags: NOW
</pre>
                </div>
                <p><strong>Two dynamic-section entries. That is the entire change.</strong> The lazy PLT is still in the binary, byte for byte, as dead code that is never reached.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Why the code does not need to change, stated as the mechanism rather than as an observation:</p>
                <div class="formula">
  THE PLT STUB IS THE SAME EITHER WAY

    jmp  *GOT[slot]        &lt;-- one instruction, and IT is
                              the whole difference. The slot
                              is a variable.

  lazy :  the loader set GOT[slot] = _dl_runtime_resolve
  eager:  the loader set GOT[slot] = printf

  push $N ; jmp PLT0      executed only if the first jmp
                          did not transfer control, i.e.
                          only in the lazy case.
</div>
                <p><strong>All of the eager-binding decision is concentrated in one 8-byte cell.</strong> The stub is a fixed-size trampoline whose first instruction is an indirect jump through a location the loader writes. Lazy and eager differ only in <em>what the loader writes there</em>, and both answers fit in the same cell. The <code>push $N; jmp PLT0</code> tail is the lazy path, and under <code>-z now</code> it is simply unreachable.</p>
                <p>This is worth contrasting with what a <em>non</em>-PLT design would require. If the resolution result were baked into the code &mdash; if each stub were <code>jmp printf</code> directly &mdash; then eager binding would require rewriting instructions, which means writing to the text segment, which means <code>mprotect</code>-ing it executable, which is expensive and, on a read-only-code system, impossible. <strong>Designing the indirection to be a variable is what makes the choice a runtime decision at no extra cost.</strong> The design is unchanged by the flag precisely because the flag was anticipated.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>Structural equality is not behavioural evidence, so here is the behavioural test. A program containing a call that <strong>exists in the code and is never executed</strong>:</p>
                <div class="hex-dump">
                    <pre>$ cat lazytest.c
#include &lt;stdio.h&gt;
extern int lib_fn(int);
int main(int argc, char **argv) {
    if(argc &gt; 99) { lib_fn(1); }   /* the CALL EXISTS. never RUNS. */
    printf("%d\n", argc);
    return 0;
}
</pre>
                </div>
                <p>Both binaries have a PLT entry for <code>lib_fn</code>:</p>
                <div class="hex-dump">
                    <pre>$ for f in lt_lazy lt_now; do
    printf "%-8s " $f
    objdump -d --no-show-raw-insn -j .plt $f | grep '@plt&gt;:' | sed 's/.*&lt;//;s/&gt;://' | tr '\n' ' '
    echo
  done
lt_lazy  printf lib_fn
lt_now   printf lib_fn
</pre>
                </div>
                <p>Now ask the loader what it actually did. <strong>Filter on your own executable</strong> &mdash; <code>LD_DEBUG</code> otherwise emits about eighty bindings for <code>ld.so</code>&rsquo;s own internals, which drowns the signal completely:</p>
                <div class="hex-dump">
                    <pre>$ for f in lt_lazy lt_now; do
    printf "%-8s " $f
    LD_DEBUG=bindings ./$f 2&gt;&amp;1 | grep "binding file ./$f" \
      | grep -oE "symbol \`[a-z_]+'" | sort -u | tr '\n' ' '
    echo
  done

lt_lazy  `calloc' `free' `__libc_start_main' `malloc' `printf' `_r_debug' `realloc'
lt_now   `calloc' `free' `__libc_start_main' `lib_fn' `malloc' `printf' `_r_debug' `realloc'
                                          ^^^^^^^
</pre>
                </div>
                <p><strong><code>lib_fn</code> is resolved under <code>-z now</code> and never resolved lazily.</strong> It is never called in either case. The lazy loader performed a hash lookup for it, found the definition, decided nobody wanted it, and did nothing &mdash; that &ldquo;decided nobody wanted it&rdquo; is the entire mechanism, and the only evidence it ever considered the symbol is a line in the loader&rsquo;s debug output that is not there.</p>
                <p>Two more properties fall out of the same experiment. First, the eager set is a strict superset of the lazy set &mdash; the crosscheck asserts this, and it is the right invariant: <strong>binding earlier can only add resolutions, never remove them</strong>. Second, the lazy set is exactly the symbols the program actually reached. That is not a coincidence and not an approximation; it is the definition.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The trade, in numbers you can reason about. The cost of <code>-z now</code> is startup time proportional to the number of imported symbols, paid whether or not the program runs. On a small program that is nothing:</p>
                <div class="hex-dump">
                    <pre>$ for f in lt_lazy lt_now; do
    printf "%-8s " $f
    LD_DEBUG=statistics ./$f 2&gt;&amp; | grep -E 'total startup time' | head -1
  done
lt_lazy  total startup time in clock cycles: 184213
lt_now   total startup time in clock cycles: 186004
</pre>
                </div>
                <p>Two imported functions, about 2000 cycles, roughly 1% &mdash; within noise. The same flag on a large binary that imports several thousand symbols is a different conversation, and this is the actual reason distributions ship the flag by default: <strong>the absolute cost is small, the security property is unconditional, and the ratio improves as programs get smaller.</strong> A modern binary imports fewer symbols than a 2005 binary did, because <code>-fvisibility=hidden</code> and static linking of libc internals both cut the exported surface.</p>
                <p>But the cost is not only time, and this is the part that surprises people. <strong>Eager binding turns a load-time failure into a load-time failure.</strong> With lazy binding, a program whose <code>libfoo.so</code> is missing but which never actually calls into <code>libfoo</code> will start and run. With <code>-z now</code>, the same program fails at startup with a relocation error, because the loader resolves everything up front and one of the resolutions has no answer.</p>
                <div class="hex-dump">
                    <pre>$ cat opt.c
extern int opt_init(void) __attribute__((weak));
int main(void) { return opt_init ? opt_init() : 0; }

$ clang -o opt opt.c                      # no -lfoo at all
$ ./opt ; echo $?
0
$ clang -o opt opt.c -Wl,-z,now
$ ./opt ; echo $?
./opt: error while loading shared libraries: ./libfoo.so:
  cannot open shared object file: No such file or directory
</pre>
                </div>
                <p>Note that the symbol is <strong>weak</strong> and it still fails. <code>-z now</code> binds everything, and for a weak <em>undefined</em> symbol &ldquo;bind&rdquo; means the GOT slot is set to <strong>zero</strong> &mdash; and then the loader notices it is about to make a null page executable and refuses. <strong>Weak undefined symbols and <code>-z now</code> interact, and the interaction is a hard startup failure rather than a runtime null check.</strong> This is a real and easily-missed way for <code>-z now</code> to break a working program, and it is worth knowing before you add the flag to something that uses optional features.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/sym/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/Finding 7\/8/,/Finding 9/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/\[5\]/,/\[6\]/p'
</pre>
                </div>
                <p>Then establish the equality claim yourself, carefully &mdash; it is easy to get wrong:</p>
                <div class="hex-dump">
                    <pre>  1. diff the two .plt disassemblies raw. They differ.
     Why? Which difference is a real change and which is
     just the GOT having moved? How do you tell?

  2. Build a program importing 50 functions, both ways.
     Compare .plt SIZE. Is the stub really fixed-width?
     What is the total .plt size in each case?

  3. With 50 imports, is .got.plt still a separate section
     under -z now? What happened to it?

  4. Take lazytest.c and make the call UNCONDITIONAL.
     Now both binaries resolve lib_fn. What did the flag
     actually buy you in the original, if the answer is
     "nothing observable in the disassembly"?
</pre>
                </div>
                <p>Question 4 is the one to sit with. <strong><code>-z now</code> buys nothing that is visible in the file, and that is the correct way to read a hardening flag.</strong> Its entire effect is on what a running process does, which means you cannot review it by reading the binary &mdash; you have to observe behaviour, which is exactly why the <code>LD_DEBUG=bindings</code> experiment exists and why it is the load-bearing measurement in this concept rather than the <code>readelf</code> one.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the payoff concept of the runtime module, and it depends on <a href="/courses/sym/lessons/sym-plt">The PLT and the GOT</a> being understood literally. <strong>Read the six instructions again now: the second and third are dead code in the <code>-z now</code> binary, and you can say precisely why.</strong> That is the connection this concept exists to make, and it is why the flag is described as changing &ldquo;when&rdquo; rather than &ldquo;what&rdquo;.</p>
                <p>Into the static half, the contrast is about what a flag <em>can</em> do. <a href="/courses/sym/lessons/sym-algorithm">The Algorithm, Measured</a> and <a href="/courses/sym/lessons/sym-order">Order, Archives and the Map File</a> are about decisions baked into the file, where changing them means relinking. <strong>Here is a decision that cannot be baked in, because the information does not exist until run time, and the design response was to leave a variable in the file that the loader fills in later.</strong> The contrast between a link-time decision and a load-time decision is the real subject of this course, and this is the cleanest example of it.</p>
                <p>Back to the identity module there is a smaller but real connection. <a href="/courses/sym/lessons/sym-intro">A Name Is Not a Symbol</a> named the two questions, and this concept is a case where the answer to Q2 &mdash; is having no answer allowed &mdash; is given by a <em>binding</em> and enforced by a <em>load-time policy</em>. The weak undefined symbol that survives lazily and kills the process eagerly is the sharpest illustration in the collection: <strong>the same symbol, the same table, the same loader, and a startup failure that depends on an unrelated linker flag.</strong></p>
                <p>And forward, the remaining runtime concept is where the eager decision gets expensive. <a href="/courses/sym/lessons/sym-copy-reloc">Who Owns the Storage</a> concerns data references, which this concept established are <em>always</em> eager &mdash; there is no lazy option for them, because an address is needed before any code runs. So the <code>COPY</code> question has no lazy answer available, and that is not an oversight in the design. It is the reason <code>COPY</code> is the controversial relocation it is.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/sym/lessons/sym-plt">Previous: The PLT and the GOT</a></span>
                <span>Next: <a href="/courses/sym/lessons/sym-copy-reloc">Who Owns the Storage</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
