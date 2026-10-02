// Static Linking and Linker Scripts — Module 3: Roots and Selection
// Concept: orphan placement, and the five sections even the default script
// guesses at.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_link_orphans() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Sections the Script Forgot — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson link-lesson">
            <a href="/courses/link" class="back-link">Back to course</a>
            <h1>The Sections the Script Forgot</h1>
            <div class="lesson-meta">18 min &middot; Module 3: Roots and Selection &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Add a section to your program that the linker script does not mention. Nothing happens. That is the surprising part, and the surprising part is that <em>nothing happening</em> is the documented, intended behaviour.</p>
                <div class="hex-dump">
                    <pre>$ cat orph.c &lt;&lt;'EOF'
__asm__(".section .my_odd_section,\"ax\",@progbits\n .globl odd_fn\nodd_fn: ret\n");
int main(void){ return 0; }
EOF
$ clang -O1 -c orph.c -o orph.o
$ readelf -SW orph.o | grep my_odd
  [ 4] .my_odd_section   PROGBITS  0000000000000000  000040  000001  00  AX  0  0  1
$ clang -O1 orph.o -o orph.out
$ echo "exit=$?  and no warning at all"
exit=0
$ readelf -SW orph.out | grep my_odd
  [15] .my_odd_section  PROGBITS  0000000000001133  000440  000001  00  AX  0  0 16
                                     ^^^^^^^^ placed, silently
</pre>
                </div>
                <p><strong>Placed at 0x1133, flagged executable (<code>AX</code>), and the linker said nothing.</strong> It put a section you did not ask for, in a place you did not choose, and did not tell you. That behaviour has a name &mdash; the section is an <em>orphan</em> &mdash; and there is a flag that makes the linker admit what it did.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>What the fallback does, and why the default script needs it.</p>
                <div class="formula">
  AN ORPHAN is an input section that no rule in the
  SCRIPT block matched.

  the fallback, in the order ld tries it:
    1. match the section's NAME against a naming
       CONVENTION, for a list ld hard-codes
    2. if the name is recognised, create an output
       section with the same name and put it there
    3. otherwise, put it in a section of the same name
       as the input, after everything the script
       placed, and warn -- only if asked to

  step 1 is the part people do not know about. there
  is a table INSIDE ld, and it is not in the script.
  the default script does not have to name .tm_clone_table
  because ld has heard of .tm_clone_table.

                </div>
                <p><strong>And this is the direct consequence of the <a href="/courses/link/lessons/link-keep-gc">previous concept</a>.</strong> If the linker removed every unmatched section, the default script would be wrong the moment a new toolchain added a section name it had not anticipated &mdash; the section would be silently deleted, which is far worse than silently misplaced. The orphan fallback is the price of enabling garbage collection, and it is why &ldquo;write a complete script&rdquo; is not really achievable for a general-purpose toolchain.</p>
                <p>The flag that turns the silence into a message:</p>
                <div class="formula">
  --orphan-handling=place    the default. place and
                             stay quiet.
  --orphan-handling=warn     place AND say so. for
                             every orphan, naming the
                             input section, the file it
                             came from, and where it
                             went.
  --orphan-handling=error    refuse. for a script you
                             believe is complete.

                </div>
                <p><strong><code>--orphan-handling=error</code> is the useful one and almost nobody uses it</strong>, because it is the only mode that can tell you a script is incomplete. Every other mode assumes you might be.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>Here is the measurement that makes this concept worth eighteen minutes. A trivial program whose <code>main</code> just returns zero &mdash; plus one custom section, linked with <code>--orphan-handling=warn</code>:</p>
                <div class="hex-dump">
                    <pre>$ clang -O1 orph.o -o orph.out -Wl,--orphan-handling=warn 2&gt;&amp;1 | grep -i orphan
  warning: orphan section `.rela.fini_array' from `/lib/x86_64-linux-gnu/Scrt1.o' being placed in section `.rela.dyn'
  warning: orphan section `.rela.init_array' from `/lib/x86_64-linux-gnu/Scrt1.o' being placed in section `.rela.dyn'
  warning: orphan section `.tm_clone_table' from `/usr/lib/gcc/x86_64-linux-gnu/15/crtbeginS.o' being placed in section `.tm_clone_table'
  warning: orphan section `.my_odd_section' from `orph.o' being placed in section `.my_odd_section'
  warning: orphan section `.tm_clone_table' from `/usr/lib/gcc/x86_64-linux-gnu/15/crtendS.o' being placed in section `.tm_clone_table'
</pre>
                </div>
                <p><strong>Five orphans. Four of them from the C runtime.</strong> And the crucial detail: these are orphans of the <em>default 276-line script</em> &mdash; the file maintained by the linker authors, shipped with every link on this machine. <code>.tm_clone_table</code> is not mentioned anywhere in it, and neither are the two <code>.rela.*_array</code> sections.</p>
                <p>So the conclusion, which is the concept: <strong>the default script is not complete, and it does not claim to be.</strong> It leans on the fallback for five sections in the simplest program you can write. If yours orphans five, it is not worse than the default. If yours orphans six, you have added one, and the warning is telling you which.</p>
                <p>What it does with them, and the two interesting cases in that list:</p>
                <div class="hex-dump">
                    <pre>  .rela.init_array  from Scrt1.o  -&gt; placed in .rela.dyn
  ^ a RELOCATION section, describing the relocations
    for .init_array. it was not named, so it went into
    the catch-all relocation section. harmless, and
    probably intentional: relocation sections are
    interchangeable in a way data sections are not.

  .tm_clone_table   from crtbeginS.o AND crtendS.o
  ^ TWO orphans with the SAME NAME, and they were
    placed in ONE output section. the two files bracket
    the program's other objects, and the table is the
    trick GCC uses to emit a null terminator between
    them. an output section of the same name is exactly
    what makes that work.

  ^ and notice: it was placed in a section named
    .tm_clone_table -- a name the script never wrote.
    step 2 of the fallback, creating an output section
    that the script does not contain.
</pre>
                </div>
                <p>And the negative case, which is the one to try yourself: <strong><code>--orphan-handling=error</code> makes the trivial program fail to link.</strong></p>
                <div class="hex-dump">
                    <pre>$ clang -O1 orph.o -o orph.err -Wl,--orphan-handling=error 2&gt;&amp;1 | head -3
  ld.bfd: error: orphan section `.rela.fini_array' from `.../Scrt1.o' found
  ld.bfd: error: orphan section `.rela.init_array' from `.../Scrt1.o' found
  ld.bfd: error: orphan section `.tm_clone_table' from `.../crtbeginS.o' found
$ echo "exit=$?"
exit=1
</pre>
                </div>
                <p><strong>A program that links perfectly well by default cannot be linked at all with <code>--orphan-handling=error</code>.</strong> That is not a bug in the flag; it is the honest answer to the question &ldquo;is my script complete?&rdquo;, and the answer for the default script is <em>no</em>.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Why this is not a pedantic corner. Here is a section that every real program has, that the default script does not name, and whose correct placement nobody would guess:</p>
                <div class="hex-dump">
                    <pre>  .tm_clone_table

  a C++ feature with no C equivalent. the pattern is:

    class T;                       // has a destructor
    T* get();                      // returns a pointer to
                                   // ONE static instance

    (the real declaration has braces; they are legal in
     a script and illegal in this box, so the shape is
     described rather than quoted)

  GCC needs to run a destructor for `t` at exit, but
  it cannot add a reference to a destructor in a
  function -- that would create an UNDEFINED symbol
  the program did not ask for.

  so instead it emits this table into crtbeginS.o:

    .tm_clone_table:   .quad  0        &lt;-- null, end marker
    .tm_clone_table:   .quad  destructor
    .tm_clone_table:   .quad  0        &lt;-- null, from crtendS.o

  and the startup code walks it looking for the nulls.
  the table is TWO objects' worth of section with a
  terminator in the middle, and it only works if both
  halves end up adjacent -- which the orphan fallback
  guarantees by putting them in one output section of
  the same name.
</pre>
                </div>
                <p><strong>So the mechanism that "forgot" <code>.tm_clone_table</code> is what makes the C++ static-destructor feature work at all.</strong> If the default script named it explicitly, it would have to know about the crtbegin/crtend bracketing; by leaving it to the fallback, the behaviour comes from the naming convention instead, and works for any object that emits the section.</p>
                <p>That is a fair defence of the design, and it is also the design's cost: <strong>the fallback has to guess, and the guess is sometimes load-bearing.</strong> The second cost is the one you pay as a user, and it is a specific and predictable one &mdash; ordering.</p>
                <div class="hex-dump">
                    <pre>  an orphan is placed AFTER everything the script
  placed, in a section of its own name. so:

    .text   the script put it here
    .rodata the script put it here
    .data   the script put it here
    .mything   &lt;-- orphan, goes here, at 0x1133

  if .mything needs to be adjacent to .data for
  performance or correctness, the script cannot say so.
  the only way is to NAME it in the script, and then
  it stops being an orphan and you are back in control.
</pre>
                </div>
                <p>And the trap that follows from that, which is worth knowing because it looks like a linker bug and is not: <strong>an orphan's position depends on how many orphans there are.</strong> Add a second unmentioned section and the first one moves. There is no diagnostic, the binary is a different size, and the only way to make the position deterministic is to name every section you care about.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/link/assets/samples
$ ./build_samples.sh 2&gt;&amp;2 | sed -n '/F11/,/F12/p'
$ python3 crosscheck.py 2&gt;&amp;2 | sed -n '/\\[11\\]/,/\\[12\\]/p'
</pre>
                </div>
                <p>Then turn the silence into a signal, which is the actual skill:</p>
                <div class="hex-dump">
                    <pre>  1. Run every program in this course with
     -Wl,--orphan-handling=warn. Which ones warn?
     (The ones you would not expect are the point --
     a bigger program is not automatically a cleaner
     one.)

  2. Add a second custom section to orph.c and re-run.
     Did the FIRST section move? By how much? (Its
     address will shift by exactly the size of the new
     one, and nothing will say so.)

  3. Now name .my_odd_section in your own script, with
     a rule placing it where you want. Re-run with
     --orphan-handling=warn: does the warning go away?
     Then add KEEP to the rule and try --gc-sections:
     does the section survive? (Two mechanisms, one
     script, and they are not the same thing.)

  4. Find the hard-coded convention table. Hint: the
     warning message for .tm_clone_table says it was
     "placed in section .tm_clone_table" -- a section
     the script does not contain. Ask ld what it knows:
       ld --verbose | grep -i tm_clone
     (Nothing. The table is compiled in. That is the
     answer to this exercise and it is the point: some
     of the linker's behaviour is not in any file you
     can read.)

  5. Write a script that names .tm_clone_table
     explicitly, and see whether the two halves from
     crtbeginS.o and crtendS.o still bracket correctly.
     (This is a genuine C++ correctness experiment, not
     a linker one, and it is the most interesting thing
     on this page.)
</pre>
                </div>
                <p>Exercise 4 is the one that reframes the whole course, and it is deliberately a dead end. <strong>The convention table is inside the binary.</strong> You can read the 276-line script, you can read your own script, and you still cannot read <em>this</em> &mdash; a hard-coded list of section names in <code>ld</code> that decides placement for anything you forgot. That is the boundary of the "read the source" approach, and knowing where it is matters more than the list would.</p>
                <p>Exercise 3 is the practical takeaway. <strong>Naming a section in your script takes it out of the fallback entirely</strong> &mdash; you lose nothing and gain determinism, plus the ability to <code>KEEP</code> it. The cost is a script that has to be maintained as the toolchain adds section names, which is exactly the cost the fallback exists to avoid. There is no correct answer, only a decision about whether you want to be in charge.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This closes the selection module, and it exists because the <a href="/courses/link/lessons/link-keep-gc">previous concept</a> created a problem. <code>--gc-sections</code> removes every section a rule does not reach, so a script that forgot a section would <em>delete</em> it. The orphan fallback is the direct consequence: <strong>miss a section and it is misplaced, rather than destroyed.</strong> Both mechanisms are the price of the same design decision, and a linker that offered neither would be less useful than one that offers both badly.</p>
                <p>That makes the two concepts a matched pair, and the way to hold them is as a pair. <strong>Orphan handling answers &ldquo;the script did not mention this &mdash; where does it go?&rdquo; and <code>KEEP</code> answers &ldquo;the script mentioned this and nothing reaches it &mdash; does it stay?&rdquo;</strong> One is a fallback for being incomplete, one is an override for being conservative. A script that both names every section it cares about and <code>KEEP</code>s the ones the linker cannot see through has made itself the authority, and at that point it should be read with the same attention as the source it was written alongside.</p>
                <p>The connection to the <a href="/courses/elf/lessons/section-vs-segment">ELF course's section-versus-segment concept</a> is about who decides what, and it is worth reading that concept again with this in mind. It established that a linker invents the program headers by working out which output sections can share a mapping. <strong>This concept is the other half of the same division of labour: the linker also invents the output sections for anything the script omitted.</strong> Both are conveniences that move work away from the person who knows the intent, and both have the same failure mode &mdash; the linker guesses, the guess is usually right, and the guess is never checked.</p>
                <p>And the connection to the <a href="/courses/sym/lessons/sym-order">symbol-resolution course's map-file finding</a> is practical rather than thematic, and it is the tool that solves the problem this concept creates. The map file records where every section and every symbol ended up, <em>including the orphans</em>. So when a build behaves strangely and you suspect a section is in the wrong place, the answer is not to reason about the fallback algorithm &mdash; it is to look at the map, where the linker already told you. <strong>Two features of the same tool, one that guesses quietly and one that records its guesses, and you should reach for the second whenever the first might be wrong.</strong></p>
                <p>Forward into the final module, both of these mechanisms are about what ends up in the binary, and the last concept measures what a deliberate policy of including <em>everything</em> costs. <a href="/courses/link/lessons/link-static-real">What -static Actually Does</a> pulls in all of libc, at 52 times the size, with 0xc210 bytes of symbol table &mdash; and the honest reading of that number is that most of it is describing code that <code>--gc-sections</code> could remove and that <a href="/courses/link/lessons/link-static-real">static linking</a> deliberately keeps, because a static binary cannot load anything at run time and so must be self-contained. <strong>Orphan placement, <code>KEEP</code>, and <code>--gc-sections</code> are three answers to one question: how much of what the compiler produced should be in the image?</strong> The next concept picks a different answer and measures it.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/link/lessons/link-keep-gc">Previous: Reachability, and Who the Roots Are</a></span>
                <span>Next: <a href="/courses/link/lessons/link-static-real">What -static Actually Does</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
