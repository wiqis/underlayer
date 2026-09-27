// Symbol Resolution and Symbol Tables — Module 4: Versions and Invented Symbols
// Concept: the symbols the linker creates, and a resolver that agrees with ld.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sym_linker_defined() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Symbols the Linker Invents — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson sym-lesson">
            <a href="/courses/sym" class="back-link">Back to course</a>
            <h1>Symbols the Linker Invents</h1>
            <div class="lesson-meta">23 min &middot; Module 4: Versions and Invented Symbols &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Ask a linker where your data segment ends and it will tell you, with a symbol it made up. Here is one that appears in a program you have never heard of, that no source file mentions, and that is nevertheless in the symbol table:</p>
                <div class="hex-dump">
                    <pre>$ cat lddef.c
#include &lt;stdio.h&gt;
extern char _end[], __bss_start[], edata[], etext[];
int main(void) {
    printf("  etext       %p\n", (void*)etext);
    printf("  edata       %p\n", (void*)edata);
    printf("  __bss_start %p\n", (void*)__bss_start);
    printf("  _end        %p\n", (void*)_end);
    return 0;
}
$ clang -O0 -o lddef lddef.c &amp;&amp; ./lddef
  etext       0x560ee68c71b9
  edata       0x560ee68ca018
  __bss_start 0x560ee68ca018
  _end        0x560ee68ca020
</pre>
                </div>
                <p><strong>Look at <code>edata</code> and <code>__bss_start</code>: the same address.</strong> That is not a bug and it is not a coincidence &mdash; <code>edata</code> is the end of the initialised data and <code>__bss_start</code> is the beginning of the zero-initialised data, and when <code>.bss</code> follows <code>.data</code> immediately, which is the normal case, those two points are the same point. A reader who sees two symbols at one address will assume a mistake, and it is worth knowing in advance that it is not one.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two families, and they are useful for different things.</p>
                <div class="formula">
  THE FOUR BOUNDARIES -- image-wide, no linker script

  etext        end of the TEXT segment   (code)
  edata        end of the INITIALISED data
  _end         end of EVERYTHING, including .bss
  __bss_start  start of .bss

  used by: kernel loaders, malloc implementations, the
  boundary between "mapped with contents" and "mapped as
  zero". _start, __libc_csu_init and the classic malloc
  all read these.

  THE PER-SECTION PAIR -- needs no script either

  __start_SECNAME   first byte of section SECNAME
  __stop_SECNAME    one past its last byte

  used by: anything that has to iterate a section it did
  not compile. Kernel modules, init arrays, and the
  trick of getting the address of a non-array object.
</div>
                <p>The <code>__start_</code>/<code>__stop_</code> pair is the more useful of the two and much less known. <strong>It gives you the bounds of a section without a linker script, which means without knowing the link layout in advance</strong> &mdash; and that is exactly what you need when the code doing the iterating is a shared object that will be linked against something you have not seen yet.</p>
                <p>There is a related pair for arrays that is worth knowing because it is the standard trick: if you declare a variable as an array, C guarantees that <code>&amp;x</code> and <code>&amp;x[0]</code> have the same address, and <code>sizeof(x)</code> gives you the length. So <code>extern int mytable[];</code> plus <code>sizeof(mytable)</code> cannot work, but <code>__start_</code>/<code>__stop_</code> can, because they come from the linker rather than from the type.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>First, they are real symbols, synthesised, and they are in the table:</p>
                <div class="hex-dump">
                    <pre>$ readelf -sW lddef | grep -E ' (_end|__bss_start|etext|edata)$'
    18: 0000000000004018     0 NOTYPE  GLOBAL DEFAULT   25 edata
    29: 0000000000004020     0 NOTYPE  GLOBAL DEFAULT   26 _end
    31: 0000000000004018     0 NOTYPE  GLOBAL DEFAULT   26 __bss_start
    33: 00000000000011b9     0 NOTYPE  GLOBAL DEFAULT   14 etext
</pre>
                </div>
                <p><strong>Three properties worth reading off that listing.</strong> <code>NOTYPE</code> &mdash; they are not functions or objects, they are addresses, and the format has a category for that. Size <strong>0</strong> &mdash; they are points, not extents. And <code>GLOBAL</code> with <code>DEFAULT</code> visibility, which is what you would expect and is <em>not</em> what the section pair does.</p>
                <p>Now the section pair, and note the section index in the last column:</p>
                <div class="hex-dump">
                    <pre>$ cat segmark.c
extern char __start_mysecd[], __stop_mysecd[];
__attribute__((section("mysecd"))) const long tbl[4] = {10,20,30,40};
int main(void) { ... }
$ readelf -sW segmark | grep -E '__start_mysecd|__stop_mysecd'
    24: 0000000000002040     0 NOTYPE  GLOBAL PROTECTED   16 __start_mysecd
    25: 0000000000002060     0 NOTYPE  GLOBAL PROTECTED   16 __stop_mysecd
</pre>
                </div>
                <p><strong><code>PROTECTED</code>, not <code>DEFAULT</code>.</strong> That is Finding 17, and it is the most carefully-chosen byte in the whole mechanism. <code>__start_mysecd</code> is a <em>per-output-file</em> boundary: it means &ldquo;the start of <code>mysecd</code> <strong>in this binary</strong>&rdquo;. If it were <code>DEFAULT</code>, a second shared object loaded later could export its own <code>__start_mysecd</code> and interpose it, and every module in the system would silently iterate the wrong section.</p>
                <p>So the linker marks them un-preemptible for the same reason it would mark an internal function: <strong>the name is an implementation detail of one output file and must not become part of the global namespace.</strong> Compare the four boundaries, which are genuinely image-wide and legitimately <code>DEFAULT</code>. Same mechanism, different question, different answer &mdash; and that difference is the entire argument for having four visibility values.</p>
                <p>Finally, the bounds are exact:</p>
                <div class="hex-dump">
                    <pre>$ ./segmark
  __start_mysecd=0x6142c803b040 __stop_mysecd=0x6142c803b060 count=4
     10
     20
     30
     40
</pre>
                </div>
                <p><code>0x...060 - 0x...040 = 0x20 = 32 bytes = 4 longs</code>, and the values are the ones in the source. The linker computed the section&rsquo;s extent and published it as two symbols, and the C code above never mentions the section by name.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The use that justifies the whole mechanism: iterating a table without knowing its size.</p>
                <div class="hex-dump">
                    <pre>/* The problem: sizeof on an extern array is not the array's size. */
extern int handlers[];               /* no length anywhere */
extern char __start_handlers[], __stop_handlers[];

static size_t nhandlers(void) {
    return (size_t)(__stop_handlers - __start_handlers) / sizeof(int);
}

void init_all(void) {
    for (int *p = (int *)__start_handlers; p &lt; (int *)__stop_handlers; p++)
        (*p)();
}
</pre>
                </div>
                <p>Every other method has a defect. <code>sizeof(handlers)</code> is the size of a <em>pointer</em>, not the array. A sentinel value works but costs a comparison in every loop and a branch in every writer. A count symbol has to be kept in sync by hand, which is a bug waiting for the next person who adds an entry. <strong>The <code>__start_</code>/<code>__stop_</code> pair makes the count a property of the link rather than of the source</strong>, so adding a table entry is a one-line change that cannot desynchronise.</p>
                <p>This is the same class of solution as <a href="/courses/sym/lessons/sym-hash">Two Hash Tables, One Job</a>&rsquo;s Bloom filter and the archive index: <strong>derive the fact from the structure instead of maintaining it separately.</strong> The general name for it is a <em>section-boundary idiom</em>, and it appears in kernel code, in embedded firmware, and in every C runtime that has to find its own initialiser array. It is also the standard answer to &ldquo;how do I find the size of something I did not allocate&rdquo;, which otherwise has no correct solution in C.</p>
                <p>One caution, because it is a real limitation. <strong>The pair works for sections the linker creates from named input sections, and it does not work for anything the compiler or assembler synthesised without a name.</strong> A <code>.bss</code> that exists only because a variable was tentative has a name, so it works. A string literal in <code>.rodata.str1.1</code> has a generated name, so <code>__start_.rodata.str1.1</code> is not something you can spell. And the mechanism requires the section to be named at all &mdash; a <code>static</code> array that the compiler kept local will not be exported into a section you can address this way. The feature is precise, not general.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/sym/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/Finding 16\/17/,/Finding 18/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/\[9\]/,/\[10\]/p'
</pre>
                </div>
                <p>Then build the resolver, which is the from-scratch half of this course. Start with the smallest useful one &mdash; given a name, find its definition, the way the loader does it:</p>
                <div class="hex-dump">
                    <pre>$ python3 symtables.py /bin/ls | head -40
</pre>
                </div>
                <p>and then extend it. The exercise is the resolution algorithm from <a href="/courses/sym/lessons/sym-algorithm">The Algorithm, Measured</a>, reimplemented against a real table:</p>
                <div class="hex-dump">
                    <pre>  1. Given .dynsym, .gnu.hash and .dynstr, write
     resolve(name) -&gt; address or NOT-FOUND.
     Constraints: no linear scan of .dynsym. You may use
     the bloom filter and the chain walk. Check it against
     every name in .dynsym and report any mismatch.

  2. Now handle versioning. A name plus a version index
     must find the right entry among several sharing a
     base name. Which structure tells you the answer, and
     what do you do when the version is 0?

  3. Now handle the linker-defined symbols. resolve("_end")
     on an arbitrary .so -- is it in .dynsym at all? If
     not, what is the right behaviour for your resolver,
     and how would a program that needs it behave?

  4. Make it agree with the dynamic linker. Run it under
     LD_DEBUG=bindings and diff the set of names each
     resolves. They should match except for the ones the
     loader resolves internally.
</pre>
                </div>
                <p>Question 3 is the one that teaches the limit of the exercise, and it is worth doing properly. <strong>The linker-defined boundary symbols are in <code>.symtab</code> and mostly not in <code>.dynsym</code></strong> &mdash; a <code>.so</code> has its own <code>_end</code> and it is not the program&rsquo;s. A resolver that faithfully searches the dynamic table will not find <code>_end</code>, and that is not a bug in the resolver: <strong>the dynamic symbol table is a list of what this file offers the world, and <code>_end</code> is not an offer, it is a local fact.</strong> A program that wants its own image&rsquo;s <code>_end</code> has to get it from its own symbol table, which is a different table with a different job &mdash; and that is the two-tables lesson from <a href="/courses/sym/lessons/sym-binding">Binding, and the Two Tables</a> arriving at the end.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This closes the course, and the closing argument is about the difference between a symbol that is <em>found</em> and a symbol that is <em>offered</em>. Every concept in the runtime module found its answer by searching <code>.dynsym</code>, and this one is the case where that search correctly fails. <strong>A resolver that is correct will tell you <code>_end</code> is not there, and a program that needs it must look elsewhere</strong> &mdash; which is not a limitation of the resolver but the whole reason two symbol tables exist.</p>
                <p>To <a href="/courses/sym/lessons/sym-binding">Binding, and the Two Tables</a> the connection is the long arc. That concept asked why there are two tables and answered that the linker needs one and the loader needs another. <strong>This concept is the case that makes the answer concrete:</strong> <code>__start_SEC</code> is <code>PROTECTED</code> because it is per-output-file, and <code>etext</code> is <code>DEFAULT</code> because it is per-image, and the two facts put those symbols in different tables for the same reason they get different visibilities.</p>
                <p>To <a href="/courses/sym/lessons/sym-visibility">Visibility Is Not Binding</a> the connection is the sharpest single fact in the course. <strong>Finding 17 is the one place where a <code>PROTECTED</code> symbol is created by the toolchain rather than requested by the author</strong>, which is the best possible demonstration of why the value exists. The author did not choose it; the linker chose it because it understood something about the symbol&rsquo;s meaning that a default would have lost.</p>
                <p>And forward out of the course, to the two things this one is a bridge between. The section-boundary idiom is the direct ancestor of every later mechanism for &ldquo;find what you did not allocate&rdquo; &mdash; linker sections in C, <code>.init_array</code> in every ELF system, the registration tables in the Java runtime, and Rust&rsquo;s <code>#[ctor]</code>. <strong>All of them are the same idea: publish the bounds of a set of things as data, so that adding to the set does not require editing the code that iterates it.</strong> And that is the general shape of the whole course. The first module asked what a name means. The second asked how a linker decides. The third asked how a loader decides with less information. The fourth asked how a name can be two things at once and how a linker can tell you where the program ends. <strong>Every one of those is a question about where a fact lives and who is allowed to see it</strong>, and that is the through-line from the first concept to this one.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/sym/lessons/sym-version">Previous: Versioned Symbols</a></span>
                <span>End of course &mdash; <a href="/courses/sym">back to the course index</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
