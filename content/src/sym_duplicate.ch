// Symbol Resolution and Symbol Tables — Module 2: The Resolution Algorithm
// Concept: multiple definition, and the storage class that made the same source
// legal for thirty years and then was withdrawn.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sym_duplicate() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Two Definitions and One Tentative — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson sym-lesson">
            <a href="/courses/sym" class="back-link">Back to course</a>
            <h1>Two Definitions and One Tentative</h1>
            <div class="lesson-meta">21 min &middot; Module 2: The Resolution Algorithm &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Here is a header, and it is completely ordinary C:</p>
                <div class="hex-dump">
                    <pre>/* config.h -- included by forty source files */
int   debug_enabled;
int   verbosity;
</pre>
                </div>
                <p>Forty translation units include it. Each one gets its own <code>config.o</code>. Each of those forty object files contains a definition of <code>debug_enabled</code>. <strong>And this linked, every day, for about thirty years, on every Linux distribution ever shipped.</strong></p>
                <p>Then a compiler changed its default, and this is the build error that appeared in thousands of projects at once:</p>
                <div class="hex-dump">
                    <pre>$ make
cc -c a.c -o a.o
cc -c b.c -o b.o
cc -o prog a.o b.o
b.o:(.bss+0x0): multiple definition of `debug_enabled'
a.o:(.bss+0x0): first defined here
cc -o prog c.o a.o b.o
c.o:(.bss+0x0): multiple definition of `debug_enabled'
a.o:(.bss+0x0): first defined here
make: *** [prog] Error 1
</pre>
                </div>
                <p><strong>Not one line of the project&rsquo;s source changed.</strong> No header was edited. No dependency was mis-declared. The same forty object files that had linked yesterday did not link today, and the difference is a compiler default that flipped from <code>-fcommon</code> to <code>-fno-common</code>.</p>
                <p>This is the most consequential ordinary fact in this course, and it is a fact about <em>symbol binding</em> rather than about linking technique. Understanding it requires seeing that <code>int x;</code> at file scope was never one thing. It was two, and only one of them survived.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>C has three ways to declare a file-scope object, and the difference between them is not obvious from the syntax:</p>
                <div class="hex-dump">
                    <pre>  extern int x;      a DECLARATION. "x exists somewhere."
                               emits nothing. Undefined symbol.

  int x = 5;        a DEFINITION with an initialiser.
                               Real storage, real bytes.

  int x;            a TENTATIVE DEFINITION. This is the one
                               that is not what it looks like.
</pre>
                </div>
                <p>The third form is the entire subject of this concept. In C, a file-scope object declared without <code>extern</code> and without an initialiser is a <em>tentative</em> definition: the translation unit declares an intent to define it, but explicitly does not say where. C99 6.9.2p2 says each tentative definition &ldquo;is a definition&rdquo; &mdash; but then 6.9.2p5 says if there is more than one, <strong>the behaviour is undefined</strong>. The standard hands the decision to the implementation, and for thirty years the implementations all made the same one.</p>
                <p>What they made it do was give the tentative definition a <strong>different storage class</strong>:</p>
                <div class="hex-dump">
                    <pre>  -fcommon (the old default)      -fno-common (since GCC 10)

  SHN_COMMON, size 4               a real definition in
  an unallocated run in .bss       .bss, exactly like
  that the linker may satisfy       int x = 5; except
  from somewhere else               there are no bytes
                                    initialised
</pre>
                </div>
                <p><strong>That is the whole trick, and it is not a weakening of the one-definition rule &mdash; it is a relocation of the definition.</strong> Under <code>-fcommon</code>, forty tentative definitions do not collide because they are not forty definitions. They are forty requests to share one, and the linker satisfies all forty from one allocation. Under <code>-fno-common</code> each tentative definition <em>becomes</em> a definition, and forty definitions of one name is precisely the error the rule exists to catch.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>The flag is the only difference. Same three files, same compiler, two invocations:</p>
                <div class="hex-dump">
                    <pre>$ cat tent_x.c
int cvar;
$ cat tent_y.c
int cvar;
$ cat tent_z.c
int cvar = 5; int main(void) { return cvar; }

$ clang -fcommon -c tent_x.c -o tent_x.o
$ readelf -sW tent_x.o | grep cvar
     2: 0000000000000000     4 OBJECT  GLOBAL DEFAULT  COM cvar
                              ^^^^^^^ SHN_COMMON

$ clang -o prog tent_x.o tent_y.o tent_z.o &amp;&amp; ./prog ; echo $?
5                       &lt;-- two tentative + one real: links, and 5 is correct

$ clang -fno-common -c tent_x.c -o tent_xn.o
$ readelf -sW tent_xn.o | grep cvar
     2: 0000000000000000     4 OBJECT  GLOBAL DEFAULT    3 cvar
                                                 ^ section 3 = .bss, a REAL definition

$ clang -o prog tent_xn.o tent_yn.o tent_zn.o
tent_yn.o:(.bss+0x0): multiple definition of `cvar'
   tent_xn.o:(.bss+0x0): first defined here
tent_zn.o:(.data+0x0): multiple definition of `cvar'
   tent_xn.o:(.bss+0x0): first defined here
</pre>
                </div>
                <p><strong>Read the section index column, because that single character is the entire mechanism.</strong> Under <code>-fcommon</code> the index is <code>COM</code> &mdash; a pseudo-section meaning &ldquo;not in any section yet&rdquo;, a request rather than a fact. Under <code>-fno-common</code> it is <code>3</code>, which is <code>.bss</code>, which means the bytes exist and their address is decided.</p>
                <p>Note also that the <em>real</em> definition in <code>tent_z.c</code> now conflicts too. <code>cvar = 5</code> puts it in <code>.data</code>; the tentative ones are in <code>.bss</code>; and two different sections means two different storage. <strong>Before the change, the tentative definitions deferred to the real one and everyone got <code>5</code>. After it, they do not defer to anything, because a tentative definition is no longer a thing that can be deferred.</strong></p>
                <p>And the merge, in the case where it still works, is by name and requires the strong definition to exist:</p>
                <div class="hex-dump">
                    <pre>$ cat only_x.c
int lonely;            /* tentative, nothing else defines it */
$ clang -fcommon -c only_x.c -o only_x.o
$ readelf -sW only_x.o | grep lonely
     2: 0000000000000000     4 OBJECT  GLOBAL DEFAULT  COM lonely
</pre>
                </div>
                <p><strong>Even with nothing to merge with, <code>-fcommon</code> leaves it in <code>SHN_COMMON</code> in the object file.</strong> The decision to allocate is deferred all the way to the link. That is the design: the object file does not claim to have decided anything.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Why a compiler was entitled to break this, and why the fallout was as large as it was. C99 6.9.2p5 says multiple tentative definitions are undefined behaviour, so a compiler that stops merging them is conforming and was always entitled to do it. The correctness argument is also straightforward: <strong>under <code>-fno-common</code>, a tentative definition is a real definition, and a real definition is initialised to zero, which is exactly what <code>int x;</code> was always promised to do</strong>. The old behaviour was arguably the buggy one, because it meant the value of <code>x</code> could depend on whether some other translation unit happened to assign it.</p>
                <p>The compatibility argument is what nobody had an answer for. <strong>The break did not happen in a source file; it happened in a prebuilt binary.</strong> Someone&rsquo;s <code>libfoo.a</code>, compiled in 2004 with tentative definitions, was linked in 2024 against a 2024 object that also has a tentative definition of the same name. One of them is now a definition and the other is now a definition, and they collide. No source change, no recompile of the library, no way for the application to fix it.</p>
                <p>That is the general shape, and it recurs. <strong>A format that lets each producer record a local decision needs a way to make two different local decisions interoperate, or the decision has to be made by the language instead.</strong> C made it the compiler&rsquo;s decision and then changed its mind. C++ never had the problem, because <code>inline</code> variables have real semantics from the start. Rust has no tentative definitions at all. And the object-files course measured a third answer in a different format: COFF has no <code>SHN_COMMON</code> and instead solves the same problem with <code>.bss</code> plus a COMDAT group, which is why the same C source that broke every ELF project in 2020 does not break COFF projects.</p>
                <p>The practical advice, and it is the advice that is actually correct: <strong>do not put tentative definitions in a header.</strong> Write <code>extern int x;</code> in the header and exactly one <code>int x = 0;</code> in one <code>.c</code> file. That is correct under every flag, has been since 1989, and makes the number of definitions in your build a property you chose rather than a property of how many files included a header.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/sym/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/Finding 5/,/Finding 6/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/\[3\]/,/^$/p'
</pre>
                </div>
                <p>Then separate the three cases, which is the whole skill:</p>
                <div class="hex-dump">
                    <pre>  1. a.c:  extern int v;  int get(void){return v;}
     b.c:  int v = 9;
     Link under BOTH flags. Does it ever fail? Why not?

  2. a.c:  int v;   int get(void){return v;}
     b.c:  int v = 9;
     Link under BOTH flags. What changes, and what does the
     program PRINT in each case?

  3. a.c:  static int v;  int get(void){return v;}
     b.c:  static int v;  int get2(void){return v;}
     Link. Two symbols named v, or one? How would you tell
     from the binary?

  4. Question 2 is the famous one. Under -fcommon, what does
     the program print, and WHY is that arguably a bug in
     the old behaviour rather than a feature?
</pre>
                </div>
                <p>Question 4 is the one to spend time on, and the answer is the most interesting thing in this concept. <strong>Under <code>-fcommon</code>, <code>int v;</code> in <code>a.c</code> does not get you zero &mdash; it gets you whatever <code>b.c</code> put there</strong>, and the value of a variable depended on link order. The C standard never promised that; it promised the tentative definition was a definition, and a definition with no initialiser is zero-initialised. The old behaviour was the one that departed from the standard, and <code>-fno-common</code> is the fix.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This closes the algorithm module, and the closing argument is about decisions made in the wrong place. <a href="/courses/sym/lessons/sym-algorithm">The Algorithm, Measured</a> and <a href="/courses/sym/lessons/sym-order">Order, Archives and the Map File</a> described how a decision is reached; this one is a case where <strong>the decision should never have been left to the reader of the object file at all</strong>, and thirty years of toolchains deferred it to the last possible moment.</p>
                <p>Into the identity module, the connection is exact. <a href="/courses/sym/lessons/sym-binding">Binding, and the Two Tables</a> presented the three bindings as a hierarchy and said WEAK is a permission rather than a priority. <code>SHN_COMMON</code> is a second permission, in a different field, answering the same question Q2 from <a href="/courses/sym/lessons/sym-intro">A Name Is Not a Symbol</a>. <strong>Two mechanisms for &ldquo;this definition is optional&rdquo; in the same 24-byte structure &mdash; a binding nibble and a section index &mdash; is the clearest evidence that ELF does not separate the two questions cleanly.</strong></p>
                <p>Back to the object files course, this is where two of its findings meet. <a href="/courses/obj/lessons/obj-bss-common">COMMON and the ABI Break</a> measured this exact phenomenon and located it in the ELF format; this concept explains the mechanism and shows that the break was a <em>compiler default</em> rather than a format change, which is the more precise and more useful account. <a href="/courses/obj/lessons/obj-comdat-group">COMDAT</a> is the other answer to the same problem in the same language &mdash; C++ reached it through <code>inline</code> and solved the identical issue with a different structure, and the object-files course found that C has no mechanism for it at all.</p>
                <p>And the connection forward is the one that makes the module hang together. <strong>Every mechanism in this module is a static-link mechanism, and every one of them is unavailable to a dynamic link</strong> &mdash; because a shared object cannot be edited after the fact, so a tentative definition in a <code>.so</code> has to become a real one, and two <code>.so</code> files that both have <code>SHN_COMMON</code> for the same name are two unrelated variables with the same spelling. That is the same class of failure as the copy-relocation question in <a href="/courses/sym/lessons/sym-copy-reloc">Who Owns the Storage</a>, and it is why a library that exports a writable datum is a substantially harder problem than one that exports functions.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/sym/lessons/sym-order">Previous: Order, Archives and the Map File</a></span>
                <span>Next: <a href="/courses/sym/lessons/sym-hash">Two Hash Tables, One Job</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
