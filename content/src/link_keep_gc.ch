// Static Linking and Linker Scripts — Module 3: Roots and Selection
// Concept: --gc-sections as a graph walk, rooted at ENTRY and KEEP, and why
// inlining changes the answer.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_link_keep_gc() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Reachability, and Who the Roots Are — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson link-lesson">
            <a href="/courses/link" class="back-link">Back to course</a>
            <h1>Reachability, and Who the Roots Are</h1>
            <div class="lesson-meta">25 min &middot; Module 3: Roots and Selection &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>You have a function that nothing calls. A linker with <code>--gc-sections</code> will delete it, and most people take that as an optimisation they can have or not have. It is more interesting than that: <strong>the decision is a graph walk, and the graph is drawn by the optimiser, not by you.</strong></p>
                <p>One source file, compiled four ways:</p>
                <div class="hex-dump">
                    <pre>$ cat gc.c &lt;&lt;'EOF'
#include &lt;stdio.h&gt;
int used(int x){ return x + 1; }
int unused(int x){ return x * 999; }
int also_unused(int x){ return unused(x) * 2; }
int main(void){ printf("%d\n", used(41)); return 0; }
EOF
$ for opt in -O1 -O0; do
    clang $opt -ffunction-sections -c gc.c -o gc$opt.o
    clang $opt gc$opt.o -o gc$opt.off
    clang $opt -Wl,--gc-sections gc$opt.o -o gc$opt.on
    printf "  %s  input sections: " $opt
    readelf -SW gc$opt.o | sed -n 's/^ *\[[ 0-9]*\] \(\.text\.[a-z_]*\).*/\1 /p'
    for m in off on; do
      printf "     --gc-sections %-3s .text=%s  funcs: " $m \
        "$(readelf -SW gc$opt.$m|awk '/ \.text /{print $6}')"
      readelf -sW gc$opt.$m | awk '$4=="FUNC" &amp;&amp; $7!="UND" &amp;&amp; $8!~/^(_start|_init|_fini|frame_dummy|register_tm|deregister_tm|__do_global)/{printf "%s ", $8}'
      echo
    done
  done
</pre>
                </div>
                <p><strong>Read the two &ldquo;on&rdquo; rows against each other:</strong></p>
                <div class="hex-dump">
                    <pre>  -O1  on   .text=000108  funcs: main
  -O0  on   .text=000131  funcs: used main
                        ^^^^
                        at -O1 the collector removed `used`.
                        at -O0 it KEPT it.
</pre>
                </div>
                <p>Same source. Same flag. Same linker. <strong>The only difference is the optimisation level, and the only thing that changed is whether the compiler inlined <code>used</code> into <code>main</code>.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The algorithm, in full. It is four steps and about forty lines of real linker code.</p>
                <div class="formula">
  1. FIND THE ROOTS
     the ENTRY symbol (ENTRY(_start) in the script)
     every symbol marked KEEP by a script rule
     sections the emulation insists on
     --export-dynamic symbols, if you asked

  2. WALK
     from each root, follow every relocation.
     a relocation marks the section it points at
     as live. add it to the worklist.

  3. FIXPOINT
     repeat until the worklist is empty. a section
     made live in step 2 can bring in more sections.

  4. DROP
     every section not marked live is removed, and
     the relocations that pointed at it go with it.

                </div>
                <p><strong>Step 4 is the one with teeth: the relocation is removed too, not just the target.</strong> That is why the removal is safe in a way that deleting a function by hand is not &mdash; if anything still pointed at the deleted code, the pointer would already have marked it live.</p>
                <p>Now the two words that decide everything, and they come from <em>different files</em>:</p>
                <div class="formula">
  ENTRY(_start)          a SCRIPT line. line 8 of the
                         default script. it names the
                         root, and it is why a --gc-sections
                         build of a normal program keeps
                         main at all.

  KEEP (*(.init_array))  a SCRIPT line, inside a rule.
                         makes that section a root
                         REGARDLESS of reachability.

                </div>
                <p><strong>And neither of them is a command-line flag in the normal case</strong> &mdash; they are lines in the 276-line file the reader has never opened. A constructor that nothing calls survives garbage collection because of a word inside parentheses in a script. Delete the <code>KEEP</code> and it is gone; add <code>--gc-sections</code> and you find out.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>The inlining, shown at the instruction level, because this is the part that is not obvious:</p>
                <div class="hex-dump">
                    <pre>$ objdump -d gc-O1.off --section=.text | sed -n '/&lt;main&gt;:/,/ret/p'
0000000000001170 &lt;main&gt;:
    1170:  50                    push   %rax
    1171:  48 8d 3d 8c 0e 00 00  lea    0xe8c(%rip),%rdi
    1178:  be 2a 00 00 00        mov    $0x2a,%esi
                                   ^^^^^^^^^^^^^^^^
                                   0x2a = 42 = used(41)
    117d:  31 c0                 xor    %eax,%eax
    117f:  e8 ac fe ff ff        call   1030 &lt;printf@plt&gt;
    1184:  31 c0                 xor    %eax,%eax
    1186:  59                    pop    %rcx
    1187:  c3                    ret
</pre>
                </div>
                <p><strong><code>mov $0x2a,%esi</code>. That is <code>used(41)</code> computed at compile time.</strong> The out-of-line <code>used</code> in <code>.text.used</code> is still in the object file, still correct, and now has <em>no caller anywhere</em>. The collector did not decide it was dead code. It decided nothing points at it.</p>
                <p>And at <code>-O0</code> the same function is genuinely called, so it genuinely is live:</p>
                <div class="hex-dump">
                    <pre>  -O1  off .text=000138  funcs: used unused main also_unused
  -O1  on  .text=000108  funcs: main                    (-0x30)
  -O0  off .text=000161  funcs: used unused main also_unused
  -O0  on  .text=000131  funcs: used main               (-0x30)
</pre>
                </div>
                <p><strong>Both collect exactly 0x30 bytes and it is the same 0x30</strong> &mdash; the two dead functions in both cases. The difference is entirely whether one more function was on the list. <code>--gc-sections</code> is a <em>reachability</em> walk and reachability is a property of the graph the compiler handed over, not of the source you wrote.</p>
                <p>Now the root, moved. <code>ENTRY</code> is the only thing making <code>main</code> reachable, so change it:</p>
                <div class="hex-dump">
                    <pre>$ grep -n '^ENTRY' default.ld
8:ENTRY(_start)

$ clang -O1 -Wl,--gc-sections -Wl,-e,used gc-O1.o -o gc.root
$ readelf -sW gc.root | awk '$4=="FUNC" &amp;&amp; $7!="UND"{printf "%s ", $8}'
   ... used ...
$ echo "  main is GONE."
</pre>
                </div>
                <p><strong>One flag, and the survivor set inverts.</strong> <code>used</code> is now the root so it obviously survives; <code>main</code> is now unreachable so it is deleted. The program still links, the binary is smaller, and it does nothing anyone asked for. <strong>Nothing warns you that you just removed <code>main</code> from your program</strong> &mdash; <code>-e used</code> is a perfectly reasonable thing to type.</p>
                <p>And <code>KEEP</code>, which is the other half. A constructor is called by nobody:</p>
                <div class="hex-dump">
                    <pre>$ cat ctor.c &lt;&lt;'EOF'
#include &lt;stdio.h&gt;
__attribute__((constructor)) static void c1(void){ puts("c1"); }
int main(void){ puts("main"); return 0; }
EOF
$ clang -O1 -ffunction-sections -c ctor.c -o ctor.o
$ clang -O1 -o ctor.off ctor.o
$ clang -O1 -Wl,--gc-sections -o ctor.on ctor.o
$ for m in off on; do
    printf "  --gc-sections %-3s funcs: " $m
    readelf -sW ctor.$m | awk '$4=="FUNC" &amp;&amp; $7!="UND" &amp;&amp; $8!~/^(_start|_init|_fini|frame_dummy|register_tm|deregister_tm|__do_global)/{printf "%s ", $8}'
    echo
  done
   --gc-sections off funcs: c1 main
   --gc-sections on  funcs: c1 main       &lt;-- c1 SURVIVES
$ objdump -d ctor.on | grep -c 'call.*&lt;c1&gt;'
0                                        &lt;-- and NOTHING calls it
</pre>
                </div>
                <p><strong><code>c1</code> survives garbage collection and nothing in the program calls it.</strong> The only reason it is in the binary is a line in the default script:</p>
                <div class="hex-dump">
                    <pre>  .init_array    :
  {
    PROVIDE_HIDDEN (__init_array_start = .);
    KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) SORT_BY_INIT_PRIORITY(.ctors.*)))
    KEEP (*(.init_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .ctors))
    PROVIDE_HIDDEN (__init_array_end = .);
  }
</pre>
                </div>
                <p><strong>Nothing in the program's control flow reaches <code>c1</code>. The C runtime reaches it by walking a table of function pointers</strong>, and the only thing the linker knows about that table is that a rule said <code>KEEP</code>. <code>KEEP</code> exists precisely for this: <em>it is how you tell a reachability walk about a reference the linker cannot see</em>, because the reference is data, not a relocation.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The failure this whole mechanism is defending against, because it is the classic linker-script bug and it is silent.</p>
                <div class="hex-dump">
                    <pre>  /* a perfectly ordinary C++ file */

  static int table[16];              /* .data.rel.ro.local */
  int  lookup(int i) { return table[i &amp; 15]; }

  /* a header-only thing, compiled into ONE .o */
  /* with -fdata-sections, so its table is: */
  __attribute__((section(".mystuff"))) int mine[4] = {1,2,3,4};
  int get_mine(int i){ return mine[i &amp; 3]; }

  link with -Wl,--gc-sections and your OWN script, which
  does not mention .mystuff.

  get_mine() is called -&gt; get_mine survives.
  mine[] is in a section the script never named.
  if .mystuff is NOT an orphan that got placed, and is
  not matched by any wildcard, it is DISCARDED.

  result: get_mine() reads whatever is at that address.
  no error. no warning. the program returns garbage.
</pre>
                </div>
                <p><strong>That is the bug, and the fix is one word.</strong> Either give the section a rule that <code>KEEP</code>s it, or add <code>KEEP(*(.mystuff))</code> to an existing rule, or use <code>KEEP (*(.mystuff))</code> in your own script. The <code>--gc-sections</code> flag is what made the bug possible, and the <code>KEEP</code> is what makes it survivable.</p>
                <p>Which raises the question every linker-script author asks: <em>how do I know which sections need <code>KEEP</code>?</em> And there is a real answer, and it is not &ldquo;all of them&rdquo;:</p>
                <div class="formula">
  SECTIONS THAT NEED KEEP, and why

  .init_array  .fini_array   the C runtime walks these
                             as TABLES OF POINTERS. no
                             relocation, so reachability
                             cannot see them.

  .preinit_array  .ctors  .dtors    same reason.

  .eh_frame        unwinding tables. referenced by
                   word, not by a relocation.

  .gcc_except_table  ditto, for C++ exceptions.

  .note.GNU-stack  flags, not code.

  the common thread: these are places where a pointer
  to code or data is stored AS DATA. a reachability
  walk follows RELOCATIONS. data that looks like a
  pointer is invisible to it.

                </div>
                <p><strong>That is the principle, and it generalises past the list.</strong> <code>KEEP</code> is needed exactly where a reference is encoded as a <em>value in an array</em> rather than as a relocation. A vtable, a plugin registry, a jump table of function addresses, a constructor list &mdash; all invisible to the walk, all needing <code>KEEP</code>. And note that the default script <code>KEEP</code>s every one of the list above: it is not being careful, it is being correct, and it was written by people whose programs broke without it.</p>
                <p>One more measured consequence, because it is a nice illustration that <code>--gc-sections</code> is not free. The collected sections leave <em>gaps</em> in the symbol table, and the symbol table is a large fraction of a small binary:</p>
                <div class="hex-dump">
                    <pre>  s_dyn (dynamic, no gc):
    000348 .symtab
    0001c9 .strtab

  s_static (-static, libc linked in):
    000348 -&gt; 00c210 .symtab     &lt;-- 0xc210, 48 KB of symbols
    08497d .text
    01c57c .rodata
    00966c .eh_frame
</pre>
                </div>
                <p>That is the next concept&rsquo;s territory, and the honest summary of the trade is this: <code>--gc-sections</code> makes your <em>code</em> smaller and your binary honest about what it uses, at the cost of a build step whose output depends on the optimisation level in a way that is not obvious from the source. <strong>A function can be live in the source and absent from the binary, and the compiler decides.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/link/assets/samples
$ ./build_samples.sh 2&gt;&amp;2 | sed -n '/F10/,/F11/p'
$ python3 crosscheck.py 2&gt;&amp;2 | sed -n '/\\[10\\]/,/\\[11\\]/p'
$ python3 linklab.py gc
</pre>
                </div>
                <p>Then build the graph yourself and check your prediction against it:</p>
                <div class="hex-dump">
                    <pre>  1. Write a function whose ONLY caller is another
     function that is itself unreachable. Does it
     survive? (Predict before running. The answer is
     the interesting one: reachability is not
     transitive backwards from roots, it is transitive
     FORWARD from them, and a dead island is dead.)

  2. Put a function pointer in a global array and call
     through the array. Does it survive --gc-sections?
     If not, what is the smallest script change that
     saves it? (This is the .init_array case by
     hand, and it is the exercise that teaches the
     principle.)

  3. Add a .text.unlikely function to gc.c and re-run
     at -O1. Is it kept? (Rule 1 of the .text block is
     .text.unlikely -- does rule ORDER affect survival,
     or only position?)

  4. Take the ctor.c case and remove the KEEP from
     .init_array in your own copy of the script. Now
     c1 is collected. Does the link warn? Does the
     program still run? Does it still print "c1"?

  5. Compile gc.c WITHOUT -ffunction-sections and with
     --gc-sections. How much is collected now? (This is
     why the flag is nearly useless without
     -ffunction-sections, and the reason is worth being
     able to state.)
</pre>
                </div>
                <p>Exercise 2 is the one that matters, and it is the closest thing to a real bug you can build in five minutes. <strong>A function called only through a table is invisible to the walk, and the program compiles, links, and returns wrong answers.</strong> If you have ever had a plugin registry, a vtable, or a callback table mysteriously stop working after a linker flag change, this is the mechanism, and you now have the five-word fix.</p>
                <p>Exercise 5 has the answer that makes the flag&rsquo;s real requirement explicit. <strong><code>--gc-sections</code> collects <em>sections</em>, not functions.</strong> Without <code>-ffunction-sections</code> the compiler puts every function in one <code>.text</code>, that one section is live because anything in it is live, and the flag does nothing at all. The two flags are a pair: one creates the granularity, the other exploits it. That is not documented as a dependency anywhere obvious and it is the reason a build can add <code>--gc-sections</code> for a size win and measure no change.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the first selection concept and it is the answer to the question <a href="/courses/link/lessons/link-script-language">the language concept</a> planted. <code>KEEP</code> was listed there as one of five operators and deferred with &ldquo;this is where it earns its keep&rdquo;. <strong>It earns it here, and it earns it by being the only thing standing between a constructor and deletion.</strong> The previous two module&#39;s concepts were about <em>where</em> things go; this one is about whether they are there at all, which is a bigger difference than it sounds.</p>
                <p>The connection to the <a href="/courses/sym/lessons/sym-linker-defined">linker-defined symbols concept</a> is exact and worth spelling out. That concept introduced <code>__start_INIT_ARRAY</code> and <code>__stop_INIT_ARRAY</code> and asked where they come from. The answer, visible twice on this page, is the two lines in the same script block as the <code>KEEP</code>:</p>
                <div class="hex-dump">
                    <pre>  PROVIDE_HIDDEN (__init_array_start = .);
  KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) ...))
  PROVIDE_HIDDEN (__init_array_end = .);
       ^                                    ^
       the symbols a C startup file walks         the reason the
       from one address to the other             contents survive
</pre>
                </div>
                <p><strong>The same three lines define the symbols and protect the data, and a program that only wanted the symbols would break if you deleted the <code>KEEP</code>.</strong> That is a design where one line is load-bearing for a reason that has nothing to do with the line above it, and it is the clearest example in the course of why reading a script end to end is worth the twenty minutes.</p>
                <p>The strongest connection is to the <a href="/courses/reloc/lessons/reloc-arch-contrast">AArch64 relocation pair</a> in the Relocations course, and it is the same lesson twice. There, a tool author was told a relocation list must be processed as a <em>set</em> with an ordering constraint, because a half-applied <code>ADRP</code>/<code>ADD</code> pair is still a valid instruction pointing at the wrong place. Here, a tool author is told a section list must be processed as a <em>graph</em> with a fixpoint, because processing sections independently gives a plausible file rather than an error. <strong>Both failures are silent, both are caused by treating a structure with dependencies as a flat list, and both are the reason &ldquo;read the format properly&rdquo; is a correctness requirement rather than a style preference.</strong></p>
                <p>Forward within the module, the question of <em>which</em> sections exist at all is the natural next step. <a href="/courses/link/lessons/link-orphans">The Sections the Script Forgot</a> is about sections the script never names &mdash; and its measurement is that <strong>even the 276-line default script orphans five of them in a trivial hello-world</strong>, four of them from the C runtime. The relationship between the two concepts is exact: <code>--gc-sections</code> removes what is unreachable, orphan handling places what was never mentioned, and <strong>the default script needs the second mechanism precisely because the first exists</strong>. A script that named every section would not need orphan handling; a script that garbage-collects must rely on the fallback for anything it forgot.</p>
                <p>One connection outward, to the static-linking module. <a href="/courses/link/lessons/link-static-real">What -static Actually Does</a> measures 0xc210 bytes of <code>.symtab</code> in a statically linked binary, against 0x348 in a dynamic one. <strong>Garbage collection is the tool that addresses exactly that</strong> &mdash; it removes the code those symbols describe. But as this page&rsquo;s last measurement shows, it is not free: it depends on <code>-ffunction-sections</code>, and its output depends on the optimisation level in a way that is not visible in the source. That trade, measured rather than asserted, is what the next two concepts put numbers on.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/link/lessons/link-phdrs">Previous: PHDRS and the -T Surprise</a></span>
                <span>Next: <a href="/courses/link/lessons/link-orphans">The Sections the Script Forgot</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
