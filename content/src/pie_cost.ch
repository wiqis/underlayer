// Relocations, PIC and PIE — Module 2: Position Independent Executables
// Concept: nine instructions against seventeen, byte by byte.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pie_cost() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("What Position Independence Costs — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson reloc-lesson">
            <a href="/courses/reloc" class="back-link">Back to course</a>
            <h1>What Position Independence Costs</h1>
            <div class="lesson-meta">21 min &middot; Module 2: Position Independent Executables &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Eight additions. That is the whole program, and it is enough to make the cost of position independence exact rather than rhetorical:</p>
                <div class="hex-dump">
                    <pre>$ cat sum8.c
extern int a,b,c,d,e,f,g,h;
int f1(void){ return a+b+c+d+e+f+g+h; }
</pre>
                </div>
                <p>Build it twice and disassemble the same function. This is the whole comparison, and it is worth reading the two side by side rather than being told about it.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Non-PIC and PIC differ in <em>one</em> step, and everything else follows from it.</p>
                <div class="formula">
  NON-PIC: the displacement points AT THE DATA

      8b 05 disp32        movl (%rip), %eax
      6 bytes, one instruction, one memory access
      the value arrives in %eax

  PIC: the displacement points AT A GOT SLOT,
       and a second instruction follows

      48 8b 0d disp32     movq (%rip), %rcx     7 bytes
      8b 00                movl (%rcx), %eax     3 bytes
      10 bytes, two instructions, TWO memory accesses
      the ADDRESS arrives in %rcx, then the value

  the extra cost is not "an indirection" in the
  abstract. it is a DEPENDENT load: the second load
  cannot start until the first one retires.

                </div>
                <p><strong>And the second cost is the one that actually shows up in a profile.</strong> A dependent load serialises: the address load must complete before the value load can issue. On a machine where the first load misses to DRAM, the second load is then issued against a just-discovered address, and it misses too. A non-PIC access is one miss; a PIC access is two <em>serialised</em> misses.</p>
                <p>There is also a code-size cost, and it is the smaller of the two but it is not zero. The PIC form is 10 bytes against 6, so the extra is 4 bytes per reference &mdash; not the 1 byte you might predict from the <code>REX</code> prefix alone, because the second instruction is the bulk of it.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>Non-PIC first, in full &mdash; nine instructions, one per global:</p>
                <div class="hex-dump">
                    <pre>$ llvm-objdump-21 -d --no-show-raw-insn s_nopie.o
0000000000000000 &lt;f1&gt;:
   0:  movl  (%rip), %eax      # 0x6 &lt;f1+0x6&gt;
   6:  addl  (%rip), %eax      # 0xc
   c:  addl  (%rip), %eax      # 0x12
  12:  addl  (%rip), %eax      # 0x18
  18:  addl  (%rip), %eax      # 0x1e
  1e:  addl  (%rip), %eax      # 0x24
  24:  addl  (%rip), %eax      # 0x2a
  2a:  addl  (%rip), %eax      # 0x30
  30:  retq
</pre>
                </div>
                <p>And PIC, first eight lines &mdash; note the register juggling, which is <em>not</em> free either:</p>
                <div class="hex-dump">
                    <pre>$ llvm-objdump-21 -d --no-show-raw-insn s_pic.o
0000000000000000 &lt;f1&gt;:
   0:  movq  (%rip), %rcx      # 0x7      &lt;-- address of a
   7:  movq  (%rip), %rax      # 0xe         different global
   e:  movl  (%rax), %eax                    &lt;-- then its value
  10:  addl  (%rcx), %eax
  12:  movq  (%rip), %rcx      # 0x19
  19:  addl  (%rcx), %eax
  1b:  movq  (%rip), %rcx      # 0x22
  ...
</pre>
                </div>
                <p>Now the count, and the reason it is not simply double:</p>
                <div class="hex-dump">
                    <pre>$ printf "non-pic=%s  pic=%s\n" \
  "$(llvm-objdump-21 -d s_nopie.o | sed -n '/&lt;f1&gt;/,/ret/p' | grep -cE '^ +[0-9a-f]+:')" \
  "$(llvm-objdump-21 -d s_pic.o    | sed -n '/&lt;f1&gt;/,/ret/p' | grep -cE '^ +[0-9a-f]+:')"
non-pic=9  pic=17
</pre>
                </div>
                <p><strong>9 against 17, not 9 against 18.</strong> The reason is visible in the listing: the compiler <em>hoisted</em> the address load for <code>b</code> above the value load for <code>a</code>, because the two are independent. Eight globals produce 8 address loads and 8 value loads, but the <code>movl (%rax), %eax</code> for the first global was folded into the <code>addl (%rcx), %eax</code> of the second. <strong>The overhead is one extra instruction per global, minus the cases the scheduler can fold.</strong> The asymptotic cost is still one extra instruction and one extra dependent load per reference; the constant is 1.9 rather than 2.0 for this function.</p>
                <p>And the memory side of the ledger:</p>
                <div class="hex-dump">
                    <pre>$ readelf -SW s_pic.so | grep -E ' \.got '
  [21] .got   PROGBITS  ...  000060 08  WA
                                 ^^^^^ 0x60 = 96 bytes = 12 words
                                 8 globals + 4 words of overhead
</pre>
                </div>
                <p><strong>Twelve words of GOT for eight integers.</strong> Four of them are the reserved words the PLT needs, which the <a href="/courses/sym/lessons/sym-plt">symbol-resolution course</a> measured. The point is that the cost is not only time: a PIC binary has a data structure proportional to its number of global references, and it is writable, which means the page it lives on cannot be shared with read-only code.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Where the cost stops being negligible, and it is not where people expect. The expensive pattern is <strong>not many globals</strong> &mdash; it is <strong>globals in a hot loop</strong>, because that is where the serialised dependency chain has nothing to hide behind.</p>
                <div class="hex-dump">
                    <pre>  /* the pathological shape: a global read per iteration */
  for (i = 0; i < n; i++) sum += counter;      /* PIC: 2 dependent
                                                    loads per iteration */

  /* the same loop with the value hoisted */
  int c = counter;
  for (i = 0; i < n; i++) sum += c;             /* 2 loads, total */
</pre>
                </div>
                <p><strong>The fix is not <code>-fno-pie</code>. It is to let the compiler hoist the load</strong>, which it will do if the source makes the loop-carried value explicit. A PIE binary that is 40% slower because of PIC is almost always a program that has asked the compiler not to optimise, not a program for which position independence is expensive.</p>
                <p>The other case where it genuinely matters is memory footprint, and the reason is specific: <strong>the GOT is a writable page, and a writable page per process is a real cost on a system running thousands of them.</strong> A non-PIE binary has the addresses baked in and needs no writable page for them at all. On a machine with a page cache pressure problem and thousands of processes, that difference is measurable; on a desktop with two processes it is not.</p>
                <p>And there is one place the cost is <em>paid back</em>, which is worth knowing because it is the reason the two costs are not independent. <strong>PIE reduces the size of the resident mapping for a PIE relative to a hypothetical fixed-layout binary of the same code</strong>, because pages shared between the executable and its children stay shared, and because the ELF header is mapped rather than reserved. This is a real effect and it is the reason some large deployments prefer PIE for footprint reasons alone &mdash; though on a machine with <code>CONFIG_ARCH_WANTS_XPCV_QUEUE</code>-style zero-page behaviour the effect can be null or negative. <strong>The honest answer is that this depends on the kernel, and I have not measured it here.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/reloc/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/F5/,/F6/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/\[5\]/,/\[6\]/p'
</pre>
                </div>
                <p>Then separate the three costs, which are routinely conflated:</p>
                <div class="hex-dump">
                    <pre>  1. CODE SIZE. Add a 9th global. Does the gap
     between 9 and 17 widen by 2 instructions or by
     less? Why?

  2. INSTRUCTION COUNT. Add a global that is read TWICE.
     Now how many extra instructions, and why is it
     not two?

  3. MEMORY. What is .got for 20 globals? Subtract the
     4 words of PLT overhead. Is it still 1 word per
     global, or fewer?

  4. DEPENDENCY. For sum8, is every PIC load dependent on
     the one before it? Count the independent chains in
     the listing above. (Hint: look at what %rax and
     %rcx are doing.)

  5. Does -fno-pie (without -fPIC) reduce ANY of these
     three? Check with the crosscheck's F3 finding.
</pre>
                </div>
                <p>Question 5 is the one that ties the module together, and the answer is <strong>no</strong>. <code>-fno-pie</code> without <code>-fPIC</code> leaves the codegen alone, so all three costs remain. <strong>Which means <code>-fno-pie -no-pie</code> is the worst of both worlds: you pay the full PIC cost and get no ASLR.</strong> That configuration is a very common build-system setting and almost nobody intends it. It is the configuration the <a href="/courses/reloc/lessons/pie-flags">first concept of the previous module</a> warned about, and here it is with a price tag.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This closes the PIE module, and it is deliberately the argument-completing concept rather than the most interesting one. <a href="/courses/reloc/lessons/pie-flags">The Flags</a> gave the matrix and <a href="/courses/reloc/lessons/pie-randomize">Does the Executable Actually Move?</a> gave the benefit, measured over six runs. <strong>This one gives the price, measured to the instruction and the byte, so the decision has three quantified inputs instead of one slogan.</strong></p>
                <p>The mechanism connects straight back to the vocabulary module. <a href="/courses/reloc/lessons/reloc-why-so-many">Why There Are So Many Kinds</a> put <code>R_X86_64_REX_GOTPCRELX</code> in group 3 &mdash; indirection &mdash; and noted that the <code>REX</code> prefix exists because the instruction was originally a <code>call</code> opcode. <strong>Every number on this page is the cost of that group-3 choice</strong>, and the 7-byte <code>movq</code> against the 6-byte <code>movl</code> is the <code>REX</code> prefix showing up in a size measurement. A format decision made in 2003 for compatibility is a byte in every reference today.</p>
                <p>Forward into the failure module, this concept sets up the sharpest contrast in the course. <strong>PIC is not free, and it is not optional either &mdash; it is a trade, and a trade has a failure mode when you get it wrong.</strong> <a href="/courses/reloc/lessons/pic-violation">The Relocation That Cannot Be Fixed</a> is what happens when the trade is refused rather than made: an object that paid for neither, containing a relocation the linker has no way to satisfy. And <a href="/courses/reloc/lessons/tls-model">The One Relocation That Calls the Loader</a> is a case where the cost is not instructions or bytes at all but a <em>function call</em>, which is why it needed its own concept rather than a paragraph here.</p>
                <p>One connection outside the course, because the shape is general. <strong>Hoisting a load out of a loop is the oldest optimisation in compilers, and this concept is an argument for keeping it available even in the presence of an indirection.</strong> The same reasoning explains why <code>const</code> local data is faster than <code>static</code> in C &mdash; a <code>const</code> local can be put in a register, and a <code>static</code> cannot, because the compiler cannot prove nothing else writes it. The general rule: <strong>every indirection you add is a load the compiler has to prove is safe to move, and each such proof is a place where the source language can help or hinder.</strong> Writing <code>const</code> locals, and avoiding <code>volatile</code> where you do not mean it, is the same advice as hoisting a GOT load &mdash; and both are about giving the compiler a fact rather than asking it to discover one.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/reloc/lessons/pie-randomize">Previous: Does the Executable Actually Move?</a></span>
                <span>Next: <a href="/courses/reloc/lessons/pic-violation">The Relocation That Cannot Be Fixed</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
