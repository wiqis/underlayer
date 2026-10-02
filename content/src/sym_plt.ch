// Symbol Resolution and Symbol Tables — Module 3: Resolution at Runtime
// Concept: the six instructions that turn a call into a lookup.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sym_plt() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The PLT and the GOT — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson sym-lesson">
            <a href="/courses/sym" class="back-link">Back to course</a>
            <h1>The PLT and the GOT</h1>
            <div class="lesson-meta">22 min &middot; Module 3: Resolution at Runtime &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A call to a function in another shared library cannot be a <code>call</code> instruction, because at link time nobody knows where that function is. It might be in a library that does not exist yet, loaded from a path chosen by configuration, on a machine with a different set of packages installed.</p>
                <p>So the call site is redirected. Here is a real one, from a program built a moment ago:</p>
                <div class="hex-dump">
                    <pre>$ objdump -d --no-show-raw-insn prog | grep -A2 'call'
  114c:	call   401030 &lt;printf@plt&gt;
  1154:	call   401040 &lt;lib_fn@plt&gt;
</pre>
                </div>
                <p><strong>The call does not go to <code>printf</code>. It goes to <code>printf@plt</code>, a sixteen-byte stub in a section called <code>.plt</code>, which is a different name for the same function.</strong> Following that stub is the whole concept, and it is six instructions long.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two tables and a stub. The names are unfortunate and worth pinning down before anything else, because &ldquo;GOT&rdquo; means two different things depending on who is talking.</p>
                <div class="hex-dump">
                    <pre>  .got          the Global Offset Table: every address the
                  linker knew at link time. Data references
                  point here so the loader can rewrite them.

  .got.plt      three reserved words, then one slot per PLT
                  entry. THE ONLY PART THAT IS WRITABLE BY
                  THE LOADER AT STARTUP on a lazy-binding
                  binary. This is what people mean when they
                  say "the GOT".

  .plt          executable stubs. One 16-byte stub per
                  imported function, plus a 16-byte PLT0
                  that is not a function at all.
</pre>
                </div>
                <p>That distinction is the one that trips people, so state it as a rule: <strong><code>.got.plt</code> is where an <em>address of a function</em> goes, and it is writable; <code>.got</code> is where an <em>address of data</em> goes, and it is also writable, but for a different reason.</strong> Both are patched by the loader. Only <code>.got.plt</code> is patched <em>by the PLT mechanism</em>, and only on a lazy-binding binary.</p>
                <p>Now the two relocation types, because they are what put the program and the library in the same conversation:</p>
                <div class="hex-dump">
                    <pre>  R_X86_64_JUMP_SLOT   the loader writes the real address of
                       lib_fn into .got.plt[slot]. One slot
                       per imported FUNCTION.

  R_X86_64_GLOB_DAT    the loader writes the real address of
                       lib_data into .got[slot]. One slot
                       per imported DATA OBJECT.
</pre>
                </div>
                <p><strong>Same shape, different table, different reason.</strong> A function needs a stub because the <em>call instruction</em> has to be redirected and there is no room in it. A datum needs a slot because the <em>address</em> is what is unknown, and the access instruction can encode an address. One needs indirection in the control flow, the other in the data.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>Read the stubs. This is the actual disassembly, nothing elided:</p>
                <div class="hex-dump">
                    <pre>$ objdump -d --no-show-raw-insn -j .plt prog

0000000000401020 &lt;printf@plt-0x10&gt;:          &lt;-- PLT0. Not a function.
  401020:	push   0x2fca(%rip)        # 403ff0 &lt;GOT+0x8&gt;
  401026:	jmp    *0x2fcc(%rip)        # 403ff8 &lt;GOT+0x10&gt;
  40102c:	nopl   0x0(%rax)

0000000000401030 &lt;printf@plt&gt;:
  401030:	jmp    *0x2fca(%rip)        # 404000        &lt;-- the slot
  401036:	push   $0x0                         &lt;-- reloc index 0
  40103b:	jmp    401020 &lt;PLT0&gt;

0000000000401040 &lt;lib_fn@plt&gt;:
  401040:	jmp    *0x2fc2(%rip)        # 404008
  401046:	push   $0x1                         &lt;-- reloc index 1
  40104b:	jmp    401020 &lt;PLT0&gt;
</pre>
                </div>
                <p>Now execute it, twice, and watch the state change.</p>
                <div class="hex-dump">
                    <pre>  FIRST CALL to printf@plt

    1.  jmp *GOT[printf]      the slot holds the address of
                             _dl_runtime_resolve, because the
                             loader WROTE it there at startup
    2.  push $0               the index of printf's relocation
                             record, i.e. "look up record 0"
    3.  jmp PLT0
    4.  push GOT+8           the link_map pointer
    5.  jmp *GOT+0x10         _dl_runtime_resolve

    ... ld.so finds printf, writes its real address into
        GOT[printf], and jumps to it. The return lands on
        the instruction AFTER `call`.

  SECOND CALL to printf@plt

    1.  jmp *GOT[printf]      the slot NOW holds printf
    2.  push $0              never executed
    3.  jmp PLT0             never executed
</pre>
                </div>
                <p><strong>The second call is three times shorter and never touches the resolver.</strong> The self-modifying part is the GOT slot, and it is the only thing that changes. Notice also what the first call costs: a <code>push</code>, a <code>push</code>, an indirect jump into the loader, a string comparison against every candidate symbol in every candidate library, a write to the GOT, and a jump back. <strong>That is the price of lazy binding, paid once per symbol, and it is why the second call is a single indirect jump.</strong></p>
                <p>And the security consequence, which is the reason <code>-z now</code> exists at all. Those two instructions between the jump and the PLT0 jump are <strong>an unconditional write to the stack followed by a jump to a fixed address</strong>. If an attacker can predict where the return address goes and write a value there, they own the instruction stream on the next call. The next concept measures what <code>-z now</code> actually does about it, and the answer is not what you would guess.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The GOT layout, read from a real binary, and note that the three reserved words are at the front:</p>
                <div class="hex-dump">
                    <pre>$ readelf -SW prog | grep -E '\.got|\.plt '
  [11] .plt      PROGBITS  0000000000401020 001020 000030 10  AX
  [22] .got      PROGBITS  0000000000403fc8 002fc8 000020 08  WA
  [23] .got.plt  PROGBITS  0000000000403fe8 002fe8 000028 08  WA

  .got.plt  = 0x28 = 40 bytes = 5 words:
      +0x00  _DYNAMIC            the linker's pointer to .dynamic
      +0x08  link_map            pushed by PLT0
      +0x10  _dl_runtime_resolve jumped to by PLT0
      +0x18  printf              <- JUMP_SLOT 0
      +0x20  lib_fn              <- JUMP_SLOT 1
</pre>
                </div>
                <p><strong>Three words of overhead for five imported functions is a terrible ratio, and it is why the overhead is a fixed cost rather than a per-symbol one.</strong> A program importing fifty functions has 53 words of <code>.got.plt</code>. The design has no way to avoid the three, because PLT0 needs them and PLT0 exists as soon as there is one import.</p>
                <p>Now the data side, and the contrast is the point. Here is <code>lib_data</code> being read in the same program:</p>
                <div class="hex-dump">
                    <pre>$ objdump -d --no-show-raw-insn prog | grep -A1 'lib_data&gt;'
  1151:	mov    0x2e78(%rip),%rbx        # 3fd0 &lt;lib_data&gt;
  1158:	mov    (%rbx),%esi
</pre>
                </div>
                <p>Two instructions where the function needed a stub: load the <em>address</em> of <code>lib_data</code> from the GOT, then load the value through it. <strong>There is no PLT entry for data, no resolver call, and no lazy/eager distinction</strong> &mdash; <code>lib_data</code> is resolved during relocation processing at startup, unconditionally, because the address is needed before any code can run. A function&rsquo;s address is needed only if the function is called; a datum&rsquo;s address is needed by any instruction that touches it, and if no instruction touches it, there is no datum reference to resolve.</p>
                <p><strong>That asymmetry is the reason lazy binding can exist at all.</strong> If data references were lazy too, a program would need a check before every single memory access. Instead the loader resolves all data eagerly and all functions lazily, and the cost model falls out of that choice. <a href="/courses/sym/lessons/sym-copy-reloc">Who Owns the Storage</a> is the concept where this choice stops being free.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/sym/assets/samples
$ objdump -d --no-show-raw-insn -j .plt lt_lazy
$ readelf -SW lt_lazy | grep -E '\.got'
$ readelf -x .got.plt lt_lazy
</pre>
                </div>
                <p>Then count, rather than assume:</p>
                <div class="hex-dump">
                    <pre>  1. lt_lazy imports 2 functions. How many words is
     .got.plt, and how many of them are the three
     reserved words? Now import 20 functions and recompute
     the overhead fraction.

  2. `push $0x0` and `push $0x1` are relocation INDICES.
     Read .rela.plt and confirm the mapping from index to
     symbol. Which file decides that numbering?

  3. Compile a program that imports a function and NEVER
     calls it. Does it still get a PLT entry? (Hint:
     -ffunction-sections and --gc-sections.)

  4. Take the PLT0 sequence: push GOT+8, jmp *GOT+0x10.
     ld.so must find a function taking (link_map, index)
     and returning the address. What are the C declarations?
</pre>
                </div>
                <p>Question 2 is the one that connects this concept back to the file format. <strong>The <code>push $N</code> is an index into <code>.rela.plt</code>, and <code>.rela.plt</code> is a section like any other</strong> &mdash; so the number is not a PLT property at all, it is a relocation-table property that the PLT is merely quoting. Change the relocation table and the <code>push</code> operand changes with it. That is why the stub is sixteen bytes of fixed shape: the operand has to fit in the same space every time.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the centre of the runtime module and both of its neighbours are prerequisites. <a href="/courses/sym/lessons/sym-hash">Two Hash Tables, One Job</a> built the structure on the far end of the <code>jmp *GOT</code>; this concept is the code that gets there. <a href="/courses/sym/lessons/sym-binding-time">Lazy, Eager, and the Flag That Does Nothing</a> is about the second instruction in each stub, and it contains the measurement that overturns the obvious assumption about what <code>-z now</code> does &mdash; so read it immediately after this one, or the six instructions above will be half-understood.</p>
                <p>Back to the static half, the connection is that <strong>none of this machinery exists for a static link, and the reason is the previous module&rsquo;s central property.</strong> <a href="/courses/sym/lessons/sym-algorithm">The Algorithm, Measured</a> gave a linker that knows every input file, so it can put a direct <code>call</code> in the code and write the resolved address into the instruction stream at link time. <a href="/courses/sym/lessons/sym-order">Order, Archives and the Map File</a> gave the same thing from the other side: order mattered because the answer was computable. <strong>The PLT is what you have to build when the answer is not computable yet</strong>, and the six instructions are the smallest thing that works.</p>
                <p>Forward, the third concept in the runtime group is where the data side of this one becomes a problem. Here we saw that a data reference needs no stub and is resolved eagerly, and that seemed like the cheaper option. <a href="/courses/sym/lessons/sym-copy-reloc">Who Owns the Storage</a> shows what the eager path does when the library&rsquo;s copy and the program&rsquo;s copy cannot both be right &mdash; and that the choice between them is made by a compile flag that has nothing to do with linking. <strong>Read the two instruction sequence above and the <code>COPY</code> case side by side; the contrast is the concept.</strong></p>
                <p>And the connection out of the course. The layout here &mdash; fixed-width stub, index operand, side table &mdash; is the same shape as a vtable, an exception landing pad, and a <code>tail call</code> thunk, and for the same reason: <strong>each is a case where the target is not known when the code is emitted, and the fix is to put the variable part somewhere the emitted code can reach indirectly and keep the emitted code fixed-width.</strong> The difference here is that the indirection is resolved once and then bypassed, which is why the steady-state cost of a resolved PLT call is a single indirect jump &mdash; and why the second and subsequent calls are indistinguishable in cost from a static call.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/sym/lessons/sym-hash">Previous: Two Hash Tables, One Job</a></span>
                <span>Next: <a href="/courses/sym/lessons/sym-binding-time">Lazy, Eager, and the Flag That Does Nothing</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
