// Symbol Resolution and Symbol Tables — Module 1: What a Symbol Is
// Concept: the linker is not asked about names. It is asked about definitions.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sym_intro() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("A Name Is Not a Symbol — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson sym-lesson">
            <a href="/courses/sym" class="back-link">Back to course</a>
            <h1>A Name Is Not a Symbol</h1>
            <div class="lesson-meta">16 min &middot; Module 1: What a Symbol Is &middot; Beginner</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Here is a program that does not compile, and the error message is the most informative one you will ever read:</p>
                <div class="hex-dump">
                    <pre>$ cat main.c
#include &lt;stdio.h&gt;

int main(void) {
    printf("%d\n", answer);
    return 0;
}
</pre>
                </div>
                <div class="hex-dump">
                    <pre>$ clang -o prog main.c
main.c:4:20: error: use of undeclared identifier 'answer'
</pre>
                </div>
                <p>Now the same program with the definition supplied by a different file:</p>
                <div class="hex-dump">
                    <pre>$ cat answer.c
int answer = 42;
</pre>
                </div>
                <div class="hex-dump">
                    <pre>$ clang -c answer.c -o answer.o
$ clang -o prog main.o answer.o
$ ./prog
42
</pre>
                </div>
                <p><strong>Nothing in <code>main.c</code> changed, and the program went from an error to working.</strong> No header was included. No declaration was written. The name <code>answer</code> appeared in <code>main.c</code> with no definition anywhere near it, and the only thing that changed is that some <em>other</em> file on the command line happened to define it.</p>
                <p>This is worth pausing on, because it is the whole subject of the course. <strong>A name in a program is not a thing. It is a question.</strong> And the question &mdash; <em>what does this name mean here?</em> &mdash; is not answered by the language, by the file, or by the line. It is answered by a process that runs after every file has been compiled, looks at all of them at once, and makes a decision.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Strip away the file formats for a moment and state the problem as cleanly as it can be stated. The linker is given a bag of <strong>declarations</strong> and a bag of <strong>definitions</strong>, and it must answer one question for every declaration:</p>
                <div class="formula">
  THE QUESTION

    for each name N mentioned anywhere in the link:
        which definition of N is THE definition of N?

  and then, a second question, which is the one people forget:

    for each name N that has NO definition:
        is that an error, or is it allowed?
</div>
                <p>The second question is not a corner case. <strong>An undefined symbol is legal in several quite different circumstances</strong>, and telling those circumstances apart is most of what the rest of this course is about. A <code>printf</code> in an object file is an undefined symbol and is perfectly fine &mdash; it is a request, and the request is satisfied by <code>libc.so</code> at link time or at load time. A misspelled function name is also an undefined symbol, and it is an error. <strong>Same encoding, same table, opposite outcomes.</strong></p>
                <p>So the model has two halves, and they are genuinely different halves:</p>
                <div class="formula">
  TWO INDEPENDENT QUESTIONS, EASILY CONFLATED

    Q1  RESOLUTION    which definition answers this name?
                     -&gt; needs binding, visibility, link order, archives

    Q2  PERMISSION    is having no answer allowed at all?
                     -&gt; needs weak symbols, COMMON, dynamic linking
</div>
                <p><strong>Almost every symbol concept in existence answers exactly one of these two questions, and the formats are strikingly bad at keeping them apart.</strong> ELF, for instance, answers Q1 with a binding nibble and answers Q2 with a section-index magic value &mdash; two completely different mechanisms in two completely different fields of the same 24-byte structure. You will meet that in <a href="/courses/sym/lessons/sym-visibility">Visibility Is Not Binding</a>. Hold onto the split; it is the most useful thing in this concept.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>Both questions, measured. First Q1 &mdash; the same name, two definitions, one error:</p>
                <div class="hex-dump">
                    <pre>$ cat dup_a.c
int dup(void) { return 1; }
$ cat dup_b.c
int dup(void) { return 2; }
$ clang -c dup_a.c -o dup_a.o
$ clang -c dup_b.c -o dup_b.o
$ clang -o prog dup_a.o dup_b.o dup_m.o
dup_b.c:(.text+0x0): multiple definition of `dup'
dup_a.o:dup_a.c:(.text+0x0): first defined here
</pre>
                </div>
                <p>Now reverse the two files and read the message again, carefully:</p>
                <div class="hex-dump">
                    <pre>$ clang -o prog dup_b.o dup_a.o dup_m.o
dup_a.c:(.text+0x0): multiple definition of `dup'
dup_b.o:dup_b.c:(.text+0x0): first defined here
</pre>
                </div>
                <p><strong>The defect did not change. Only the order of two filenames in the sentence did.</strong> &ldquo;first defined here&rdquo; means first <em>on the command line</em>, not first in importance, not first in some priority order. This trips up almost everyone who reads a duplicate-symbol error as though it were ranking its candidates. It is not ranking anything; it is reporting a set of size two, and it happens to print them in the order it found them.</p>
                <p>Now Q2 &mdash; an undefined symbol that is allowed, and the same shape that is not:</p>
                <div class="hex-dump">
                    <pre>$ cat weak.c
extern int maybe(void) __attribute__((weak));
int main(void) { return maybe ? maybe() : -1; }   /* legal C */

$ clang -o prog weak.c
undefined reference to `maybe'                &lt;-- ERROR

$ cat weak2.c
extern int maybe(void) __attribute__((weak));
int maybe(void) { return 7; }
$ clang -o prog weak2.c
$ ./prog ; echo $?
7
</pre>
                </div>
                <p><strong>Both files contain the identical declaration of <code>maybe</code>. In one it is an error and in the other it is fine, and the difference is entirely whether some other file supplied a definition.</strong> That is Q2, and it is a genuinely different mechanism from Q1 &mdash; a weak symbol changes what the linker is <em>allowed</em> to do, not which definition it <em>picks</em>.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Why the split matters, concretely, in a situation you will meet. Consider a program that optionally uses a library:</p>
                <div class="hex-dump">
                    <pre>/* main.c -- works with or without liboptional */
extern int opt_init(void) __attribute__((weak));

int main(void) {
    if (opt_init) {                 /* the whole feature is this test */
        return opt_init();
    }
    return 0;                       /* the fallback path */
}
</pre>
                </div>
                <p><strong>Now imagine someone links this without <code>liboptional</code>, and the link succeeds</strong> &mdash; because the symbol is weak. Nothing crashes. Nothing is printed. The program takes the fallback path and behaves as though the feature were deliberately switched off.</p>
                <p>That is the correct behaviour, and it is also the reason weak symbols are dangerous to rely on for anything you need to know about. <strong>A feature that is silently absent and a feature that is correctly disabled look identical from outside</strong>, and no amount of inspecting the output binary distinguishes them. If your build system needs to report &ldquo;this was not compiled in&rdquo;, it cannot get that information through a weak symbol; it has to come from somewhere else entirely.</p>
                <p>This is worth stating as a general engineering shape, because it recurs far outside linkers. Any optional component whose provider might be missing has this property. The three general solutions are always the same: make the absence loud, record the decision in the output so it can be inspected later, or make the provider's presence a compile-time fact. <strong>Weak symbols give you none of the three</strong>, which is exactly why they are appropriate for the cases where a silent default <em>is</em> the intent.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <p>Every measurement in this course is reproducible from one script. Run it and read the output &mdash; the numbers quoted in these lessons come from it:</p>
                <div class="hex-dump">
                    <pre>$ cd courses/sym/assets/samples
$ ./build_samples.sh
$ python3 crosscheck.py
  ALL 84 CHECKS PASS
</pre>
                </div>
                <p>For this concept, section [1] of that run is the relevant one. Now do the experiment yourself, in this order, and write down what you see before you read on:</p>
                <div class="hex-dump">
                    <pre>$ cat q1.c
int f(void) { return 1; }
$ cat q2.c
int f(void) { return 2; }
$ clang -c q1.c -o q1.o
$ clang -c q2.c -o q2.o
$ clang -r -o both.o q1.o q2.o
q2.c:(.text+0x0): multiple definition of `f'
q1.o:q1.c:(.text+0x0): first defined here
</pre>
                </div>
                <p><strong>Note that <code>-r</code> did not help.</strong> A partial link, which produces a relocatable object rather than an executable, still enforces one-definition-per-name. That is worth knowing, because &ldquo;it is only an intermediate, nothing is being decided yet&rdquo; is a very natural assumption and it is false.</p>
                <p>Then answer these three, from what you measured rather than from what you expect:</p>
                <div class="formula">
  1. Does the ORDER of q1.o and q2.o change whether the link fails?
     (It cannot. Does it change the MESSAGE? Look.)

  2. Does the order change which f() RUNS, if you make one of them weak?

  3. Make q1.c's f() weak. Now does the order matter at all? Why not?
</div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept is the frame for the course, so the connections from it are the connections between the other eleven. <a href="/courses/sym/lessons/sym-binding">Binding, and the Two Tables</a> answers Q1 with the mechanism every format agrees on &mdash; and shows that an object file carries <em>two</em> symbol tables because the linker and the loader need different things. <a href="/courses/sym/lessons/sym-visibility">Visibility Is Not Binding</a> answers Q1's harder half, and the measured surprise there is that two of the four visibility values are not stored in the visibility field at all.</p>
                <p>The other three modules are Q1 and Q2 at increasing distance from the source. <a href="/courses/sym/lessons/sym-algorithm">The Algorithm, Measured</a> and <a href="/courses/sym/lessons/sym-order">Order, Archives and the Map File</a> are Q1 executed; <a href="/courses/sym/lessons/sym-duplicate">Two Definitions and One Tentative</a> is where Q1 and Q2 collide, and the storage class that resolved the collision for thirty years is the subject of that lesson. <a href="/courses/sym/lessons/sym-hash">Two Hash Tables, One Job</a> through <a href="/courses/sym/lessons/sym-copy-reloc">Who Owns the Storage</a> are the same two questions asked again at load time by a different program, against a different table, with a different set of rules &mdash; and the loader does not have all the information the linker had, which is the source of most of the interesting behaviour in that module.</p>
                <p>One connection outside this course, because it is the strongest available. The object files course established that a relocation names a symbol <em>by index</em> and that the index is resolved to an address later. <strong>That later resolution is this course, and the symbol table is the only thing that makes it possible</strong> &mdash; the relocation says <em>which</em> name, and the table says what it means. <a href="/courses/obj/lessons/obj-relocations">Relocations</a> is where the question is asked; this course is where it is answered.</p>
            </div>

            <div class="lesson-footer">
                <span>Start of course</span>
                <span>Next: <a href="/courses/sym/lessons/sym-binding">Binding, and the Two Tables</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
