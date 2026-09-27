// Symbol Resolution and Symbol Tables — Module 1: What a Symbol Is
// Concept: LOCAL / GLOBAL / WEAK, and why an object file carries two symbol
// tables rather than one.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sym_binding() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Binding, and the Two Tables — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson sym-lesson">
            <a href="/courses/sym" class="back-link">Back to course</a>
            <h1>Binding, and the Two Tables</h1>
            <div class="lesson-meta">18 min &middot; Module 1: What a Symbol Is &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Take a function and give it <code>static</code>. Then compile it and look at what changed:</p>
                <div class="hex-dump">
                    <pre>$ cat bind.c
int  shared(void) { return 1; }        /* no storage class */
static int private(void) { return 2; } /* file-local        */
int  weakish(void) __attribute__((weak));
int  weakish(void) { return 3; }

$ clang -c bind.c -o bind.o
$ readelf -sW bind.o | grep -E ' (shared|private|weakish)$'
     2: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND 
     3: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT  UND 
     4: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND 
     5: 0000000000000000     1 FUNC    GLOBAL DEFAULT    1 shared
     7: 0000000000000000     1 FUNC    LOCAL  DEFAULT    1 private
     9: 0000000000000000     1 FUNC    WEAK   DEFAULT    1 weakish
</pre>
                </div>
                <p><strong>One keyword, one letter in the binary.</strong> <code>static</code> turned a <code>GLOBAL</code> into a <code>LOCAL</code>, and that single character changes what every other file on the command line is allowed to do with the name. Nothing else about the function changed: same code, same section, same relocation, same size.</p>
                <p>Now the part that surprises people. Look at the undefined entries &mdash; indices 2, 3 and 4. There is a <code>LOCAL</code> undefined symbol in that table, and there is no such thing as a local undefined symbol. <strong>Those are not symbols; they are section and file markers</strong>, and the reader in the object-files course already established what they are. The symbol table starts with bookkeeping entries that are not definitions of anything, and a reader who counts symbols by counting entries overcounts.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Binding answers one question: <em>whose name is this?</em> There are three answers in ELF and they form a strict hierarchy.</p>
                <div class="formula">
  THE THREE BINDINGS, and what each permits

  LOCAL     this file may refer to it. NOBODY else may, and no
            other file may DEFINE it either. Two files may each
            have their own `private` and that is fine -- they are
            two different symbols that happen to share a name.

  GLOBAL    everyone may refer to it, and at most one file may
            define it. Two definitions is the "multiple
            definition" error.

  WEAK      everyone may refer to it, and a definition is
            OPTIONAL. Zero definitions is legal. More than one
            is legal, and the FIRST one on the command line
            wins. A strong definition always beats a weak one.
</div>
                <p>The interesting cell in that table is the WEAK row's second clause, because it is the only place in the entire symbol system where <strong>&ldquo;first on the command line wins&rdquo; is a real rule rather than an accident of diagnostics</strong>. You saw in the previous concept that two <em>strong</em> definitions are an error. Two <em>weak</em> definitions are not an error, they are a choice, and the choice is made by command-line order.</p>
                <p>Note also what WEAK is <em>not</em>. It is not &ldquo;lower priority&rdquo; in any general sense. It is a permission: the linker is <em>allowed</em> to leave the name unresolved. That is question Q2 from the previous concept, and binding is answering it, not Q1.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>The hierarchy, measured rather than asserted. Two files each defining a weak function, and one of them strong:</p>
                <div class="hex-dump">
                    <pre>$ cat w1.c
__attribute__((weak)) int pick(void) { return 1; }
$ cat w2.c
__attribute__((weak)) int pick(void) { return 2; }

$ clang -c w1.c -o w1.o; clang -c w2.c -o w2.o
$ clang -o prog w1.o w2.o m.o ; ./prog ; echo $?
1                      &lt;-- the FIRST weak definition won
$ clang -o prog w2.o w1.o m.o ; ./prog ; echo $?
2                      &lt;-- and now the other one
</pre>
                </div>
                <p>And a strong definition beating a weak one, regardless of order:</p>
                <div class="hex-dump">
                    <pre>$ cat s1.c
int pick(void) { return 99; }          /* strong */
$ clang -o prog w1.o s1.o m.o ; ./prog ; echo $?
99
$ clang -o prog s1.o w1.o m.o ; ./prog ; echo $?
99                     &lt;-- strong wins from EITHER side
</pre>
                </div>
                <p><strong>Order decides between equals and never decides between unequal.</strong> That is the whole rule, and it is worth internalising because the intuition that &ldquo;first wins&rdquo; is unqualified will make you predict the wrong answer in the second case.</p>
                <p>Now the part that is genuinely two tables. An object file has <code>.symtab</code>. A linked dynamic object has <code>.dynsym</code>. Here is the same library, both tables, side by side:</p>
                <div class="hex-dump">
                    <pre>$ readelf -SW libvis.so | grep -E 'symtab|dynsym'
  [ 4] .dynsym   DYNSYM   ...  000030 18  A  5   1  8
  [30] .symtab   SYMTAB   ...  0000a0 18  A 31  19  8

$ readelf -sW libvis.so | grep -cE ' (def_fn|hid_fn)$'      # .symtab sees both
2
$ readelf --dyn-syms -W libvis.so | grep -cE ' (def_fn|hid_fn)$'   # .dynsym
1
</pre>
                </div>
                <p><strong>The two tables have different sizes, different link fields, and different jobs.</strong> <code>.symtab</code> is for the things that can still be changed &mdash; it is what <code>ld -r</code> reads, what <code>nm</code> reads, and what a debugger reads. <code>.dynsym</code> is for the things that are <em>frozen</em>: the loader cannot add definitions or change bindings, so it gets a table containing only the names the dynamic world can see.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Here is a real link, and the reason it fails is that a name in <code>.symtab</code> is not automatically a name in <code>.dynsym</code>.</p>
                <div class="hex-dump">
                    <pre>$ cat d.c
int lib_data = 7;
$ clang -fPIC -shared -o libd.so d.c
$ clang -o prog main.c -L. -ld
$ nm -D libd.so | grep lib_data
0000000000004018 D lib_data        &lt;-- exported, fine

$ cat e.c
static int lib_data = 7;
int read(void) { return lib_data; }
$ clang -fPIC -shared -o libe.so e.c
$ nm -D libe.so | grep lib_data
                       (nothing)    &lt;-- static: local, and locals
                                    are not in .dynsym at all
</pre>
                </div>
                <p><strong>A <code>static</code> symbol is not merely &ldquo;less exported&rdquo; &mdash; it is not in the table the loader consults.</strong> That is a stronger statement than a visibility setting, and it is the reason the two-table design is not redundant. A single table would have to either expose local names to the dynamic world or carry a per-entry &ldquo;is this dynamic&rdquo; bit; ELF does the latter for <code>.symtab</code> and solves it for <code>.dynsym</code> by omission.</p>
                <p>The practical consequence shows up in shared libraries. If you build a <code>.so</code> and a symbol is missing from <code>nm -D</code> output, no amount of linking will recover it &mdash; there is nothing for the loader to find. The object-files course measured that COFF has no per-symbol dynamic marker at all and instead <em>renames</em> the symbol; this is the ELF answer to the same requirement, and the two are a good illustration of how differently the same problem got solved.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/sym/assets/samples
$ cat &gt; b.c &lt;'EOF'
int          g(void) { return 1; }
static int   s(void) { return 2; }
__attribute__((weak)) int w(void) { return 3; }
EOF
$ clang -c b.c -o b.o
$ readelf -sW b.o | grep -E ' [gsw]?\(?void\)?$| (g|s|w)$'
</pre>
                </div>
                <p>Then, without looking anything up, predict each of these and then check:</p>
                <div class="formula">
  1. Two files, each with its own `static int helper(void)`.
     Link them. Does it work? Why?

  2. Now delete `static` from both. Does it still work?

  3. Build b.c into a .so. Which of g, s, w appear in `nm -D`?

  4. w is in .dynsym. Is it in .dynsym for a .so that nothing
     links against? (Hint: look for --as-needed.)
</div>
                <p>Question 1 is the important one, and the answer is the reason <code>static</code> exists at all: two files can each have a <code>static helper</code> because those are two unrelated symbols that share a spelling. Binding is not about the name; it is about the <em>pair</em> of name and binding, and that is the next concept.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The obvious next step is <a href="/courses/sym/lessons/sym-visibility">Visibility Is Not Binding</a>, and the connection is sharper than the titles suggest. <strong>Binding answers &ldquo;who may refer to this name&rdquo;; visibility answers &ldquo;who may <em>replace</em> it with their own&rdquo;.</strong> They are independent, every format stores them in different fields, and the next concept contains the measured demonstration that for two of the four visibility values the answer is not stored in the visibility field at all.</p>
                <p>Backwards, the connection to <a href="/courses/obj/lessons/obj-symbols">Symbol Tables, Compared</a> is exact rather than thematic. That concept established the three formats' table designs and the ELF layout of the 24-byte entry; this one supplies the meaning of the <code>st_info</code> nibble you saw there, and adds the observation that the first entries in the table are not symbols at all. <a href="/courses/obj/lessons/obj-bss-common">COMMON and the ABI Break</a> is the other direction: that concept measured a binding value &mdash; <code>GLOBAL</code> &mdash; used to carry a storage class, which is precisely the confusion this concept's hierarchy is designed to prevent, and which <a href="/courses/sym/lessons/sym-duplicate">Two Definitions and One Tentative</a> returns to.</p>
                <p>Forward, the weak row of that table is load-bearing for the runtime half of the course. <a href="/courses/sym/lessons/sym-plt">The PLT and the GOT</a> is built entirely out of undefined GLOBAL symbols, and <a href="/courses/sym/lessons/sym-copy-reloc">Who Owns the Storage</a> is about what happens when an undefined symbol turns out to name a <em>datum</em> rather than a function. A weak undefined symbol is also the mechanism behind <code>__gmon_start__</code> and the ITM profiling hooks, which you can see in the dynamic table of literally every binary on this machine &mdash; undefined, weak, never defined, never called, and costing one PLT slot each.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/sym/lessons/sym-intro">Previous: A Name Is Not a Symbol</a></span>
                <span>Next: <a href="/courses/sym/lessons/sym-visibility">Visibility Is Not Binding</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
