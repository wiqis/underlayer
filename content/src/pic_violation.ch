// Relocations, PIC and PIE — Module 3: How It Fails
// Concept: a failure class only PIC has, and a diagnostic that names both the
// relocation type and the flag that would fix it.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pic_violation() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Relocation That Cannot Be Fixed — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson reloc-lesson">
            <a href="/courses/reloc" class="back-link">Back to course</a>
            <h1>The Relocation That Cannot Be Fixed</h1>
            <div class="lesson-meta">20 min &middot; Module 3: How It Fails &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every relocation in the <a href="/courses/reloc/lessons/reloc-encoding-limits">first module</a> is a request the linker can always satisfy, because the linker chose every address. This is the one class that is different, and the difference is not subtle once you see it.</p>
                <p>One object file, and an attempt to build a shared library out of it:</p>
                <div class="hex-dump">
                    <pre>$ cat vio.c
extern int ext_data;
static int local_fn(int x){ return x*3; }
int *leak(void){ return &amp;ext_data; }
int call_local(void){ return local_fn(2); }

$ clang -O1 -fno-pic -c vio.c -o vio_nopic.o
$ clang -shared -o libvio.so vio_nopic.o
ld.bfd: vio_nopic.o: relocation R_X86_64_32 against undefined symbol
  `ext_data' can not be used when making a shared object; recompile with -fPIC
clang: error: linker command failed with exit code 1
</pre>
                </div>
                <p><strong>Read what that error is actually telling you.</strong> It does not say &ldquo;wrong code&rdquo; or &ldquo;incompatible object&rdquo;. It names the <em>relocation type</em> &mdash; <code>R_X86_64_32</code> &mdash; and the <em>symbol</em>, and then it prescribes the flag. That specificity is the whole subject of this concept: <strong>a PIC violation is not a policy disagreement, it is a fact about a relocation type, and a fact can be named.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Why can a linker not satisfy this? Work out what the relocation is asking for, and the impossibility is visible in one step.</p>
                <div class="formula">
  the reloc says:   field := S        (the ADDRESS of ext_data)

  the linker knows: S is not yet final. ext_data is
                    UNDEFINED in this object, so it
                    lives in some other module, which
                    the loader will place at an address
                    NOBODY can predict.

  so writing S into a field is not "a value we don't
  have yet" -- it is a value WE WILL NEVER HAVE.

  a shared library is not allowed to contain an
  absolute address, because "absolute" means "true
  at every possible load address", and there is no
  such address.

  THAT is what "can not be used when making a shared
  object" means. It is not a policy the linker
  enforces. It is arithmetic that has no answer.

                </div>
                <p><strong>This is why the failure is unique to PIC and shared objects.</strong> A non-PIE executable has a load address the linker picks, so every address is knowable &mdash; and <code>R_X86_64_32</code> is perfectly fine there. A shared library has no load address at all until the loader picks it, and possibly does not load it at all. <strong>The same relocation is correct in one output and impossible in the other, and the difference is entirely whether the output has a fixed address.</strong></p>
                <p>Now the trap, which is where most of the confusion actually lives. There are two ways out of the problem, and only one of them is available:</p>
                <div class="formula">
  FIX 1  DON'T STORE AN ADDRESS.  Store a DISTANCE.

         movl  disp32(%rip), %eax     ; R_X86_64_PC32
         the displacement is S - P, and translating the
         whole image by Delta leaves it unchanged.

         WORKS AT ANY LOAD ADDRESS.  No loader help
         needed. This is the whole idea.

  FIX 2  STORE THE ADDRESS OF A SLOT, and let the
         LOADER fill the slot in.

         movq  disp32(%rip), %rcx     ; R_X86_64_REX_GOTPCRELX
         the code says "the address is over there"; the
         loader decides what "over there" means.

         WORKS, but costs an indirection and a writable
         page. This is what the GOT is for.

  THE COMPILER PICKED NEITHER, because it was told
  the output would not move. It emitted FIX 0:

  FIX 0  STORE THE ADDRESS.   <-- only valid if the
         address is known NOW. Which is what -fno-pic
         told it.

                </div>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>The two builds of the same source, and the one line that differs:</p>
                <div class="hex-dump">
                    <pre>$ llvm-objdump-21 -r vio_nopic.o | sed -n '/.text/,/^$/p'
0000000000000001 R_X86_64_32      ext_data

$ llvm-objdump-21 -r vio_pic.o  | sed -n '/.text/,/^$/p'
0000000000000003 R_X86_64_REX_GOTPCRELX  ext_data-0x4
</pre>
                </div>
                <p><strong>One relocation became a different one, and the count stayed at one.</strong> That is worth pausing on, because the earlier <a href="/courses/reloc/lessons/reloc-why-so-many">group model</a> grouped <code>32</code> and <code>REX_GOTPCRELX</code> differently &mdash; and it is right to. Absolute and indirection compute different things. But <em>fixing</em> a violation is not &ldquo;add a relocation&rdquo;; it is &ldquo;change what the instruction does&rdquo;.</p>
                <p>And the offset moved from 1 to 3, which is the <code>REX</code> prefix from <a href="/courses/reloc/lessons/reloc-why-so-many">the second concept</a> showing up again:</p>
                <div class="hex-dump">
                    <pre>$ llvm-objdump-21 -d --no-show-raw-insn vio_nopic.o
0000000000000000 &lt;leak&gt;:
   0:  movl  $0x0, %eax        # R_X86_64_32 at offset 1

$ llvm-objdump-21 -d --no-show-raw-insn vio_pic.o
0000000000000000 &lt;leak&gt;:
   0:  movq  (%rip), %rax      # REX_GOTPCRELX at offset 3
</pre>
                </div>
                <p><strong>The instruction grew from 5 bytes to 7 and changed what it means.</strong> <code>mov $imm32, %eax</code> is a constant. <code>mov (%rip), %rax</code> is a load whose address is computed at link time. These are not the same operation with a different operand &mdash; the first produces a value that was decided when the program was compiled, the second produces a value decided when the program was loaded.</p>
                <p>Now the second half of the error, and the part that is genuinely <em>useful</em>:</p>
                <div class="hex-dump">
                    <pre>  "against undefined symbol `ext_data'"
        ^^^^^^^^^^^^^^^^
        tells you WHICH reference is the problem, not
        merely that there is one. useful when the object
        has 400 relocations and 3 of them are absolute.

  "can not be used when making a shared object"
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        the REASON, in terms of the output type.

  "recompile with -fPIC"
        ^^^^^^^^^^^^^^^
        the FIX, as a flag. and it is the RIGHT fix --
        not "relink with something else" -- because the
        defect is in the CODEGEN, and only the compiler
        can change the codegen.
</pre>
                </div>
                <p><strong>All three clauses are load-bearing, and the third is the one that teaches.</strong> The linker is telling you that no relinking option can rescue this, because the information it needs was destroyed at compile time. It is a genuinely rare diagnostic in that sense &mdash; most linker errors are &ldquo;this combination does not work, try another&rdquo;, and this one is &ldquo;this is unrecoverable, go back and change your source.&rdquo;</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Why <code>-fno-pic</code> produces this at all, when the obvious thing for a compiler to do with &ldquo;I may not move&rdquo; is simply to work harder.</p>
                <div class="hex-dump">
                    <pre>  -fno-pic tells the compiler: the output is an
  ET_EXEC, mapped at a FIXED address the linker picks.

  for an ET_EXEC, FIX 0 is CORRECT and it is FAST:
  the address is known at link time, so bake it in
  and save the indirection.

  so -fno-pic is not a bug. it is a correct
  optimisation for a correct premise, and the premise
  is the problem when the premise is wrong.

  the trade, in one line each:
    -fno-pic  faster, and only works for fixed layout
    -fPIC     one indirection more, works anywhere
    -fPIE     a middle answer: PC-relative data refs
              (no GOT for your OWN data) but a GOT for
              anything the dynamic linker might replace
</pre>
                </div>
                <p>The third line is the subtle one and worth dwelling on. <strong>A PIE still needs a GOT &mdash; not for its own data, which it reaches PC-relatively, but for the data the dynamic linker may have to redirect.</strong> That is why the <a href="/courses/reloc/lessons/pie-cost">cost measurement</a> showed PIE and PIC emitting the same relocation set for the same source: both need to be able to have a global replaced, and both must therefore have a slot for the replacement. The difference between PIE and PIC is not in the relocations; it is in <em>which</em> globals get slots.</p>
                <p>And now the failure mode that has no diagnostic at all, which is worse. Suppose the object is fine and the violation is somewhere you cannot see:</p>
                <div class="hex-dump">
                    <pre>  $ cat lib.h
  extern int shared_counter;
  #ifdef USE_TABLE
  static int tab[8] = {1,2,3,4,5,6,7,8};
  #define lookup shared_counter
  #else
  #define lookup tab[3]
  #endif
  int f(int i){ return lookup; }

  compiled WITHOUT -DUSE_TABLE  ->  an absolute
  relocation, which is FINE in an executable.

  the SAME header, with -DUSE_TABLE, in ONE of four
  .c files of a library, compiled by a build system
  that did not expect the difference.
</pre>
                </div>
                <p><strong>Now add a second build of the library, built with <code>-DUSE_TABLE</code>, and link them together.</strong> One object carries the absolute relocation and the other does not. The link either fails with the diagnostic above &mdash; good &mdash; or succeeds and the violation is a <em>runtime</em> problem. <strong>The failure has moved from link time to load time to run time, and it is now a debugging session rather than a message.</strong></p>
                <p>The general rule, and it is the reason to care: <strong>position independence is a property of a translation unit, and it is decided by the flags used to compile that one file.</strong> A library is only PIC if every object in it was compiled PIC. There is no flag you can pass to the linker to make a non-PIC object PIC, and searching for one is the single most common wasted afternoon in shared-library development.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/reloc/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/F7/,/F8/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/\\[7\\]/,/\\[8\\]/p'
</pre>
                </div>
                <p>Then collect violations deliberately, because once you can produce one you can recognise one:</p>
                <div class="hex-dump">
                    <pre>  1. For each of these, build -fno-pic and try to
     link it into a .so. Which reference is legal in an
     ET_EXEC and illegal here, and why?

       (a) int *f(void){ return &amp;my_global; }
       (b) int  f(void){ return my_global;   }
       (c) int  f(void){ return other_global; }
       (d) void f(void){ other_fn();          }

     Hint: (a) and (b) differ only in whether the ADDRESS
     or the VALUE is wanted, and that is the whole
     distinction.

  2. Now do the same with -fPIE. Does anything change?
     It should not -- and the reason is the same reason
     PIE still needs a GOT.

  3. Build vio.c with -fPIC and link it into a .so. It
     works. Now DELIBERATELY break it: patch the
     R_X86_64_REX_GOTPCRELX type field to 10 (R_X86_64_32)
     by hand, and relink. Read the error and check which
     clause of the original diagnostic applies to it.

  4. Find a real .so on this machine built from mixed
     objects. (Many distributions build some packages
     without -fPIC and use -fPIC only where needed.) Is
     there any way to tell from the FILE whether it was?
</pre>
                </div>
                <p>Question 3 is the one that closes the loop, and it works because the error is a property of the <em>type</em> rather than of the object&rsquo;s provenance. <strong>You can turn a legal object into an illegal one by flipping four bytes of metadata, and the linker cannot tell the difference.</strong> That is the cleanest possible demonstration that the violation lives in the relocation record and nowhere else &mdash; which is also why a build system cannot check for it, and why the compiler flag is the only defence.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the first of the two failure concepts, and it is the one that <em>has</em> a diagnostic. <a href="/courses/reloc/lessons/reloc-why-so-many">Why There Are So Many Kinds</a> split the table into the linker&rsquo;s group and the loader&rsquo;s group. <strong>This concept finds the boundary between them by walking to the edge and stepping off.</strong> An absolute relocation is a request for a value that only exists if the output has a fixed address; <code>ET_DYN</code> does not, so the request is unsatisfiable, and the error is where the two groups touch.</p>
                <p>Forward to the second failure concept is a deliberate contrast in kind. <strong>A PIC violation is detected at link time and the compiler is at fault. A TLS general-dynamic reference is legal in exactly the same place, links cleanly, and is not resolved until a function is <em>called</em> while the program is running.</strong> One is a missing answer; the other is an answer that is computed by running code. Comparing them side by side is the fastest way to understand why the relocation table has both arithmetic and non-arithmetic entries.</p>
                <p>Back to the PIE module, this is the cost of the incoherent cell the flag matrix could not legalise. <a href="/courses/reloc/lessons/pie-flags">The Flags, and Which One Is Which Kind</a> showed a 3&times;3 grid in which one cell &mdash; <code>-fno-pic</code> into <code>-shared</code> &mdash; produces a diagnostic rather than a working binary. <strong>That asymmetry is itself information</strong>: the linker is far more tolerant of &ldquo;works but suboptimal&rdquo; than of &ldquo;no answer at all&rdquo;, and the reason is that suboptimality is a judgement call while impossibility is arithmetic.</p>
                <p>And the connection into the build exercise is a check. <a href="/courses/reloc/lessons/reloc-apply">Applying Them Yourself</a> asks you to write the patcher, and this concept is the reason the patcher in <code>apply_relocs.py</code> raises on an out-of-range value instead of truncating. <strong>A <code>R_X86_64_32</code> that silently truncates and an <code>R_X86_64_32S</code> that fails are the same two policies the linker chooses between, and the applier has to choose too.</strong> A learner who implements the arithmetic without implementing the check has built a tool that produces the wrong answer instead of no answer &mdash; which is the more expensive failure, because it is silent.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/reloc/lessons/pie-cost">Previous: What Position Independence Costs</a></span>
                <span>Next: <a href="/courses/reloc/lessons/tls-model">The One Relocation That Calls the Loader</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
