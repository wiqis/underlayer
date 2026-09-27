// Symbol Resolution and Symbol Tables — Module 1: What a Symbol Is
// Concept: four visibility values, and the measured fact that two of them are
// not recorded in the visibility field at all.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sym_visibility() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Visibility Is Not Binding — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson sym-lesson">
            <a href="/courses/sym" class="back-link">Back to course</a>
            <h1>Visibility Is Not Binding</h1>
            <div class="lesson-meta">20 min &middot; Module 1: What a Symbol Is &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Four attributes, one per visibility. Compile them and look at the result:</p>
                <div class="hex-dump">
                    <pre>$ cat vis.c
int          def_fn(int x)  { return x + 1; }
__attribute__((visibility("hidden")))    int hid_fn(int x)  { return x + 2; }
__attribute__((visibility("protected"))) int prot_fn(int x) { return x + 3; }
__attribute__((visibility("internal")))  int int_fn(int x)  { return x + 4; }

int          def_data = 1;
__attribute__((visibility("hidden")))    int hid_data = 2;

$ clang -O1 -fPIC -shared -o libvis.so vis.c
$ llvm-nm libvis.so | grep -E 'def_fn|hid_fn|prot_fn|int_fn|def_data|hid_data'
0000000000004008 D def_data
000000000000400c d hid_data
0000000000001100 T def_fn
0000000000001110 t hid_fn
0000000000001130 t int_fn
0000000000001120 T prot_fn
</pre>
                </div>
                <p><strong>Read the case of those letters.</strong> Uppercase means <code>GLOBAL</code>, lowercase means <code>LOCAL</code>. And <code>hid_fn</code> and <code>int_fn</code> are <strong>lowercase</strong> &mdash; they are LOCAL symbols.</p>
                <p>So <code>visibility("hidden")</code> and <code>visibility("internal")</code> did not set a field. <strong>They demoted the binding from <code>GLOBAL</code> to <code>LOCAL</code>.</strong> The information is not in the two low bits of <code>st_other</code> where a reader expects to find visibility; it is in the binding nibble of <code>st_info</code>, alongside the answer to a completely different question.</p>
                <p>That is a genuinely surprising result and it is the reason this concept exists. It is also the cleanest available demonstration that <strong>binding and visibility are not two strengths of the same idea</strong>, because the mechanism that implements two of the four visibility values is the mechanism that implements a different concept entirely.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Visibility answers: <em>if another shared object already defines this name, does it win over me?</em> That is a question about <em>conflict</em>, and only <code>DEFAULT</code> permits a conflict.</p>
                <div class="formula">
  THE FOUR VALUES -- measured, not quoted

  value       in .dynsym?   preemptible by an earlier DSO?   stored as
  ---------   ----------   ------------------------------   ----------
  DEFAULT     yes           YES                              visibility
  PROTECTED   yes           no                               visibility
  HIDDEN      NO            no (nothing to preempt)          BINDING
  INTERNAL    NO            no (nothing to preempt)          BINDING
</div>
                <p>Two columns deserve emphasis because they are the counter-intuitive ones.</p>
                <p><strong>Column two.</strong> <code>HIDDEN</code> and <code>INTERNAL</code> are not preemptible, but not because of any rule &mdash; because there is nothing there to preempt. The name is absent from <code>.dynsym</code>, so no loader can bind to it. A symbol that is not in the table cannot be interposed. If you were checking preemption safety by looking for &ldquo;not preemptible&rdquo; you would mark these two as safe for a reason that has nothing to do with the visibility attribute you wrote.</p>
                <p><strong>Column three.</strong> This is the one that trips people. If you dump <code>st_other</code> expecting to find <code>STV_HIDDEN</code>, you will not find it, and if you dump <code>st_info</code> expecting to find it you will find a <code>LOCAL</code> binding and probably not connect the two. The compiler has <em>resolved</em> the visibility into a binding before emitting the table. <strong>The attribute is a source-level request; the table records the decision that satisfied it.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>Confirm the <code>.dynsym</code> column directly, because that is the column the table above claims:</p>
                <div class="hex-dump">
                    <pre>$ readelf --dyn-syms -W libvis.so | grep -cE ' (hid_fn|int_fn|hid_data)$'
0
$ readelf --dyn-syms -W libvis.so | grep -E ' (def_fn|prot_fn|def_data)$'
     5: ... FUNC    GLOBAL DEFAULT   12 def_fn
     8: ... FUNC    GLOBAL DEFAULT   12 prot_fn
     9: ... OBJECT  GLOBAL DEFAULT   19 def_data
</pre>
                </div>
                <p>Three exported, three not, and the split is exactly the one predicted. Now the measurement that makes the distinction between <code>HIDDEN</code> and <code>PROTECTED</code> real rather than definitional &mdash; both are un-preemptible, but only one of them is findable:</p>
                <div class="hex-dump">
                    <pre>$ cat u.c
#include &lt;stdio.h&gt;
extern int def_fn(int);
extern int prot_fn(int);
int main(void) { return def_fn(1) + prot_fn(1); }
$ clang -o prog u.c -L. -lvis -Wl,-rpath,'$ORIGIN'
$ readelf -rW prog | grep -E 'prot_fn|def_fn'
 ...JUMP_SLOT  prot_fn + 0
 ...JUMP_SLOT  def_fn + 0
</pre>
                </div>
                <p>Both are bound the same way at link time, through a PLT slot. The difference only becomes visible when a <em>second</em> shared object is loaded and offers its own definition. For <code>def_fn</code> the loader is permitted to bind the program's reference to that other definition; for <code>prot_fn</code> it is not, because the reference was resolved inside the library that owns it.</p>
                <p><strong>That is the whole practical content of <code>PROTECTED</code>: it is the only value that lets a name stay exported while being immune to interposition.</strong> For a library whose internal calls must not be diverted by an unrelated <code>LD_PRELOAD</code>, that is exactly the property you want, and it is the reason the fourth value exists rather than the third being enough.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Here is a real interposition, measured, so that &ldquo;preemptible&rdquo; stops being abstract. Build two libraries that both export <code>describe</code>:</p>
                <div class="hex-dump">
                    <pre>$ cat a_desc.c
const char *describe(void) { return "from A"; }
$ clang -fPIC -shared -o liba.so a_desc.c

$ cat b_desc.c
const char *describe(void) { return "from B"; }
$ clang -fPIC -shared -o libb.so b_desc.c

$ cat uses.c
#include &lt;stdio.h&gt;
extern const char *describe(void);
int main(void) { printf("%s\n", describe()); }
$ clang -o prog uses.c -L. -la -Wl,-rpath,'$ORIGIN'
$ ./prog
from A

$ LD_PRELOAD=./libb.so ./prog
from B                   &lt;-- the DEFAULT-visibility call was diverted
</pre>
                </div>
                <p>Now mark <code>describe</code> in <code>liba.so</code> protected and repeat:</p>
                <div class="hex-dump">
                    <pre>$ cat a_desc.c
__attribute__((visibility("protected")))
const char *describe(void) { return "from A"; }
$ clang -fPIC -shared -o liba.so a_desc.c
$ LD_PRELOAD=./libb.so ./prog
from A                   &lt;-- protected: NOT diverted
</pre>
                </div>
                <p><strong>Same program, same preload, opposite result, and the only difference is one attribute on a function in a library the program never mentions.</strong> This is also the security shape: a <code>LD_PRELOAD</code> can divert any <code>DEFAULT</code>-visibility call, which is why a setuid program ignores the variable, and why hardened builds compile with <code>-fvisibility=hidden</code> as a blanket measure.</p>
                <p>And here is where that blanket measure collides with another feature, which is worth seeing because it is a real interaction rather than a hypothetical one. Build the same library with a version script:</p>
                <div class="hex-dump">
                    <pre>$ cat ver/vmap
V1 { global: describe; local: *; };
$ clang -fPIC -shared -fvisibility=hidden \
      -Wl,--version-script=ver/vmap -o libh.so a_desc.c
$ llvm-nm -D --defined-only libh.so
0000000000000000 A V1@@V1        &lt;-- the version node, and NOTHING else
</pre>
                </div>
                <p><strong>The script says <code>global: describe</code> and <code>describe</code> is still not exported.</strong> A version script can only <em>narrow</em> visibility; it cannot confer it. <code>-fvisibility=hidden</code> has already demoted the binding to <code>LOCAL</code>, and a <code>LOCAL</code> symbol cannot be re-exported by a filter that operates on the exported set. <a href="/courses/sym/lessons/sym-version">Versioned Symbols</a> takes this apart in full, because it is the single most surprising interaction in the course.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <p>Section [1] of the sample build is this concept&rsquo;s evidence:</p>
                <div class="hex-dump">
                    <pre>$ cd courses/sym/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/Finding 1\/2/,/Finding 3/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/\[1\]/,/^$/p'
</pre>
                </div>
                <p>Then extend it. The interesting question is not the four values but which mechanism each uses:</p>
                <div class="formula">
  1. Add a fifth symbol with visibility("default") explicitly.
     Is it distinguishable in the binary from plain `int f()`?
     (Look at st_other AND st_info. One of them will differ
     from what you expect, and it is not the interesting one.)

  2. Which of the four values can a SHARED OBJECT still be
     interposed for? Answer by table, not by intuition.

  3. protected_fn is GLOBAL and exported. Construct a case where
     two .so files BOTH export protected_fn. Does the link fail?
     Should it?
</div>
                <p>Question 3 is the one to think hardest about, and it has no answer in this course. <strong>Two libraries exporting the same <code>PROTECTED</code> name link silently, and each one's internal calls go to its own copy.</strong> Whether that is correct depends on whether the two were meant to be substitutable for one another, and the format cannot tell you. Compare <code>GLOBAL</code>, where the same situation is a link error for a dynamic symbol only if you ask for it &mdash; and the asymmetry is the reason <code>PROTECTED</code> is a tool for libraries rather than a default for programs.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This closes the identity module, and the three concepts together make one argument: <a href="/courses/sym/lessons/sym-intro">A Name Is Not a Symbol</a> supplied the two questions, <a href="/courses/sym/lessons/sym-binding">Binding, and the Two Tables</a> answered the first with three bindings and two tables, and this one answered the second with four values and two mechanisms. <strong>The shape to carry forward is that each format records the <em>decision</em>, not the request</strong> &mdash; a <code>static</code> request becomes a <code>LOCAL</code> binding, a <code>hidden</code> request becomes a <code>LOCAL</code> binding, and in both cases the source-level vocabulary is not recoverable from the table.</p>
                <p>Into the algorithm module: binding and visibility together are what make <a href="/courses/sym/lessons/sym-algorithm">The Algorithm, Measured</a> a decision procedure rather than a search. A <code>LOCAL</code> name is not a candidate for anything outside its file, a <code>WEAK</code> definition is a candidate that may lose, and a <code>DEFAULT</code> definition is one that may lose to something loaded later. <a href="/courses/sym/lessons/sym-duplicate">Two Definitions and One Tentative</a> is where those rules produce the two outcomes you saw at link time and the third one you did not.</p>
                <p>Into the runtime module, the connection is direct and is the reason the interposition experiment above matters. Everything in that module is the loader asking the same questions against <code>.dynsym</code> alone &mdash; which is to say, against the <em>exported</em> subset that this concept just measured. <strong>That is why <code>hid_fn</code> being absent from <code>.dynsym</code> is a stronger statement than &ldquo;not exported&rdquo;: it is not merely unfindable by another library, it is unfindable by the loader, so the compiler&rsquo;s demotion to <code>LOCAL</code> is what makes the guarantee possible in the first place.</strong> <a href="/courses/sym/lessons/sym-hash">Two Hash Tables, One Job</a> then shows that the loader&rsquo;s entire index over that table is built on the names that survived this concept&rsquo;s filtering.</p>
                <p>One outside connection, because it is the design lesson rather than the mechanism. A format that lets a producer record a decision locally &mdash; <code>static</code>, <code>hidden</code>, <code>COMMON</code> &mdash; needs those decisions to be mutually compatible, and nothing in the format guarantees it. <a href="/courses/sym/lessons/sym-duplicate">Two Definitions and One Tentative</a> is the case where that guarantee was missing for thirty years and cost every prebuilt library on the platform when it was withdrawn. <strong>Visibility has the same shape and got lucky: <code>PROTECTED</code> and <code>DEFAULT</code> coexisted for years precisely because the safe choice happened to also be the narrow one.</strong></p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/sym/lessons/sym-binding">Previous: Binding, and the Two Tables</a></span>
                <span>Next: <a href="/courses/sym/lessons/sym-algorithm">The Algorithm, Measured</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
