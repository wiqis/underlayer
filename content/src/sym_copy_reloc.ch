// Symbol Resolution and Symbol Tables — Module 3: Resolution at Runtime
// Concept: GLOB_DAT and COPY, and the compile flag that silently picks between
// them.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sym_copy_reloc() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Who Owns the Storage — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson sym-lesson">
            <a href="/courses/sym" class="back-link">Back to course</a>
            <h1>Who Owns the Storage</h1>
            <div class="lesson-meta">21 min &middot; Module 3: Resolution at Runtime &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Functions were fine. A function lives in code, code is mapped read-only and shared, and every process that loads the library gets the same address for it. <strong>Data does not work that way, and the reason is a single bit of history about who is allowed to write.</strong></p>
                <div class="hex-dump">
                    <pre>$ cat owner.c
extern int lib_data;
extern int lib_fn(int);
int main(void) {
    printf("before           lib_data=%d\n", lib_data);
    lib_data = 999;                 /* the EXECUTABLE writes */
    printf("after exe write  lib_data=%d\n", lib_data);
    printf("library lib_fn(0)=%d\n", lib_fn(0));
    return 0;
}
</pre>
                </div>
                <p>There is one <code>lib_data</code>. It has an initial value of 7, set by the library&rsquo;s initialiser code. The program writes to it. The library reads it. <strong>Three participants, one name, and nobody has said where the bytes live.</strong> That is the question this concept is about, and the answer is chosen by a compiler flag.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>There are two defensible answers, and the linker must pick one per symbol.</p>
                <div class="formula">
  GLOB_DAT   the LIBRARY owns the storage.
             The program gets a pointer to it, in its GOT.
             Cost:  one GOT slot.
             Consequence: every reference goes through the GOT,
             so the program CANNOT assume its own address.

  COPY       the PROGRAM owns the storage.
             The linker allocates space in the program, the
             loader copies the library's initial value into
             it at startup, and the library's references are
             redirected to the program's copy.
             Cost:  no GOT slot, and a direct access.
             Consequence: the program's own address is fixed
             at link time.
</div>
                <p>Neither is universally better, and that is the difficulty. <code>GLOB_DAT</code> costs an indirection on every access. <code>COPY</code> is free at run time but spends program memory on a duplicate and creates a permanent coupling: the program can never load a library that disagrees about what <code>lib_data</code> is, because the library&rsquo;s definition has been overridden by something that was linked in earlier.</p>
                <p><strong>The trade is speed against flexibility, and the linker is not in a position to know which you want.</strong> Which is why the decision is not the linker&rsquo;s to make.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>Same source, same library, and the only difference is how the program&rsquo;s own translation unit was compiled:</p>
                <div class="hex-dump">
                    <pre>$ clang -fPIE   -pie    -o own_pie   owner.c -L. -lsym
$ clang -fno-pie -no-pie -o own_nopie owner.c -L. -lsym

$ for f in own_pie own_nopie; do
    printf "%-10s %-5s  " $f "$(readelf -hW $f | awk '/Type:/{print $2}')"
    readelf -rW $f | grep lib_data | grep -oE 'R_X86_64_[A-Z_]+'
  done
own_pie    DYN   R_X86_64_GLOB_DAT
own_nopie  EXEC  R_X86_64_COPY
</pre>
                </div>
                <p><strong>Nothing in <code>owner.c</code> chooses between them.</strong> And the code generated differs to match:</p>
                <div class="hex-dump">
                    <pre>$ objdump -d --no-show-raw-insn own_pie | grep -A1 'lib_data&gt;'
  1151:  mov  0x2e78(%rip),%rbx     # 3fd0 &lt;lib_data&gt;    the ADDRESS
  1158:  mov  (%rbx),%esi                            then the value

$ objdump -d --no-show-raw-insn own_nopie | grep -A1 'lib_data&gt;'
 401141:  mov  0x2ed9(%rip),%esi     # 404020 &lt;lib_data&gt;   the VALUE
</pre>
                </div>
                <p>Two instructions under <code>GLOB_DAT</code>, one under <code>COPY</code>. That is the cost of the indirection, and it is the whole reason the <code>COPY</code> path exists: <strong>in a non-relocatable executable the compiler knows the address cannot change, so it can encode the address directly in the instruction and skip the load entirely.</strong></p>
                <p>And here is the trap that has cost people an afternoon. <strong>Passing <code>-no-pie</code> at link time is not enough.</strong></p>
                <div class="hex-dump">
                    <pre>$ clang -no-pie -o wrong main.c -L. -lsym
$ readelf -rW wrong | grep lib_data | grep -oE 'R_X86_64_[A-Z_]+'
R_X86_64_GLOB_DAT          &lt;-- STILL GLOB_DAT
</pre>
                </div>
                <p>Because <code>-no-pie</code> only affects the link. The translation unit was compiled with the default <code>-fPIE</code>, so it emitted a GOT-indirect access, and the linker faithfully produced a <code>GLOB_DAT</code> for an access that genuinely goes through the GOT. <strong>You have to pass <code>-fno-pie</code> at compile time as well</strong>, and a build system that sets it in only one of the two places produces a non-PIE binary that still pays the PIE cost.</p>
                <p>Now the behaviour, and the claim that has to be checked rather than assumed:</p>
                <div class="hex-dump">
                    <pre>$ ./own_pie
before           lib_data=7
after exe write  lib_data=999
library lib_fn(0)=999

$ ./own_nopie
before           lib_data=7
after exe write  lib_data=999
library lib_fn(0)=999
</pre>
                </div>
                <p><strong>The library sees 999 in both cases.</strong> Under <code>COPY</code> this is the whole point: the loader redirected the library&rsquo;s references to the program&rsquo;s copy, so there is one storage under two names. The intuitive reading &mdash; &ldquo;the executable has a copy, so the library still has its own, and they can drift&rdquo; &mdash; is <strong>not what happens</strong>.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Having been told the intuitive story, the useful thing is to try to break it, because this is where a course should report what it found rather than what it expected. Three participants: a library that <em>defines</em> the datum, two libraries that <em>reference</em> it, and the program.</p>
                <div class="hex-dump">
                    <pre>$ cat libdef.c
int shared_data = 7;              /* the DEFINITION */
$ cat libA.c
extern int shared_data;
int a_read(void) { return shared_data; }
$ cat libB.c
extern int shared_data;
int b_read(void) { return shared_data; }
$ cat main2.c
extern int shared_data; extern int a_read(void); extern int b_read(void);
int main(void) {
    printf("initial  shared=%d a=%d b=%d\n", shared_data, a_read(), b_read());
    shared_data = 555;             /* the executable writes */
    printf("after    shared=%d a=%d b=%d\n", shared_data, a_read(), b_read());
    return 0;
}
</pre>
                </div>
                <div class="hex-dump">
                    <pre>$ ./two_pie
initial  shared=7 a=7 b=7
after    shared=555 a=555 b=555

$ ./two_nopie
initial  shared=7 a=7 b=7
after    shared=555 a=555 b=555
</pre>
                </div>
                <p><strong>All six values agree, in both code models.</strong> I could not produce divergence on x86-64 with glibc 2.43, and this course is not going to claim a bug that does not reproduce on the machine the course was measured on.</p>
                <p>What the divergence story <em>is</em> about, stated accurately: it is a real historical failure mode on targets where the <code>COPY</code> mechanism is implemented differently, and it is a real hazard for a case this test does not cover &mdash; <strong>a library loaded later, with <code>dlopen</code>, after the copy has been established.</strong> The <code>COPY</code> semantics are order-sensitive in a way <code>GLOB_DAT</code> is not, because a copy is a decision about which storage is canonical, and two different decisions taken at two different times cannot both be right. The reason this test does not diverge is that both libraries bind to the same canonical copy; the hazard appears when a participant is not in the initial link at all.</p>
                <p>The practical rule that follows, and it is a good rule regardless of platform: <strong>export functions, not writable data.</strong> A function has no storage question because there is nothing to write. A writable exported datum forces one of the two mechanisms above, and both have costs &mdash; an indirection for every access, or a link-order coupling that constrains what your library can be used with. Every shared library that got this right exports accessor functions and keeps the variable <code>static</code>, and that is not a stylistic preference.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/sym/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/Finding 9\/10/,/Finding 16/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/\[7\]/,/\[9\]/p'
</pre>
                </div>
                <p>Then find the boundary of the claim, which is more interesting than confirming it:</p>
                <div class="hex-dump">
                    <pre>  1. Add a FOURTH participant: dlopen a library that
     also references shared_data, AFTER main has written
     555. Does it see 555 or 7? Build it -- this is the case
     the static test cannot reach.

  2. Make the definition `const int shared_data = 7;`.
     Can the executable still get a COPY? What changes, and
     why is that a good property?

  3. Two .so files BOTH define `int shared_data`, neither
     is a copy, and the program references it. Which one
     wins? What is the rule, and is it the same rule as
     for a weak definition?

  4. Compile owner.c with -fPIE but link with -no-pie (the
     "wrong" case above). Read the disassembly. Does the
     program still work? What did it actually build?
</pre>
                </div>
                <p>Question 2 has the best answer. <strong>A <code>const</code> datum cannot be given a <code>COPY</code>, because a copy is a writable location by definition</strong> &mdash; the relocation would be patching a slot the program cannot write. The linker will use <code>GLOB_DAT</code> and the indirection is unavoidable, which is the correct outcome: the alternative would be a program that segfaults on its own initialiser. Making a library&rsquo;s interface <code>const</code> is therefore not only good style, it changes the relocation the linker must emit.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This closes the runtime module, and it connects to <a href="/courses/sym/lessons/sym-binding-time">Lazy, Eager, and the Flag That Does Nothing</a> by exclusion. <strong>Data references have no lazy option</strong>, because the address is needed before any instruction can execute, so every data reference is resolved eagerly whether or not you pass <code>-z now</code>. That is why the <code>COPY</code> question has no timing escape hatch and why it is a design decision rather than a policy setting.</p>
                <p>To <a href="/courses/sym/lessons/sym-plt">The PLT and the GOT</a> the connection is the two-instruction contrast. A function call is redirected through a stub because the <em>call instruction</em> has nowhere to put an unknown address. A data access is redirected through the GOT because the <em>access instruction</em> could, in principle, have held the address directly &mdash; and under <code>COPY</code> it does. <strong>The PLT exists because of a hardware limitation; the GOT exists because of a policy; <code>COPY</code> exists because the policy was declined.</strong></p>
                <p>Back to the static module, this is the concept where the two halves of the course collide. <a href="/courses/sym/lessons/sym-duplicate">Two Definitions and One Tentative</a> ended by observing that every mechanism in the static module is unavailable to a dynamic link, and gave the example of a <code>.so</code> that exports a writable datum. <strong>This is that example, resolved.</strong> The static answer was <code>SHN_COMMON</code> &mdash; defer the allocation to the link. The dynamic answer cannot defer, because the link that matters happens in another process at another time, and so the storage has to be decided now, by whichever of the two parties is more convenient.</p>
                <p>And forward, into versioning, the connection is about the moment the decision gets revisited. <a href="/courses/sym/lessons/sym-version">Versioned Symbols</a> exists because glibc needed to change what <code>malloc</code> does without breaking programs compiled against the old behaviour, and the mechanism it uses is to give one name several identities. <strong>That is the same problem as this one &mdash; a symbol whose meaning must change without relinking everything that uses it &mdash; solved on the name axis rather than the storage axis.</strong> The two concepts are the two answers a platform has to have: version the <em>name</em> when the behaviour changes, and avoid exporting <em>storage</em> when the ownership is ambiguous.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/sym/lessons/sym-binding-time">Previous: Lazy, Eager, and the Flag That Does Nothing</a></span>
                <span>Next: <a href="/courses/sym/lessons/sym-version">Versioned Symbols</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
