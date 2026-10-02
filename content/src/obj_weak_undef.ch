// Object Files — Module 4: Merging and Selection
// Concept: the may-be-zero contract, and three completely different answers to
// it -- a binding nibble, a symbol rename, and a bit in a symbol's descriptor.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_obj_weak_undef() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Weak and Undefined-Weak — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson obj-lesson">
            <a href="/courses/obj" class="back-link">Back to course</a>
            <h1>Weak and Undefined-Weak</h1>
            <div class="lesson-meta">18 min &middot; Module 4: Merging and Selection &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Here is C code that is the single most useful idiom in systems programming, and it looks like it should not compile:</p>
                <div class="hex-dump">
                    <pre>  extern int optional_hook(int) __attribute__((weak));

  ... the whole of probe() is these three lines ...

      if (optional_hook)                  /* may be NULL -- this is the idiom */
          return optional_hook(5);
      return -1;
</pre>
                </div>
                <p><strong>Testing a function pointer for null is legal C and it is the standard way to write an optional feature.</strong> The declaration says the symbol may be absent, and the <code>if</code> is the code saying &ldquo;I know it might be.&rdquo; Now look at what the object file has to record for that sentence to be true. The symbol is not defined here, and the linker must not treat its absence as an error. <strong>That is a third kind of symbol, distinct from both &ldquo;defined&rdquo; and &ldquo;wanted&rdquo;, and the three formats record it in three unrelated ways.</strong></p>
                <p>Measured on the same machine, same source, three targets. The weak <em>definition</em> and the undefined-weak <em>reference</em> side by side:</p>
                <div class="hex-dump">
                    <pre>                    ELF                  COFF                        Mach-O
  weak definition    Bind = WEAK         the NAME is rewritten:       n_desc = 0x0080
                     (st_info nibble)    .weak.maybe.default.uses_weak   N_WEAK_DEF
                                         NO weak bit exists

  undefined weak     Bind = WEAK         NAME rewritten:              n_desc = 0x0040
                     + Ndx = UND        .weak.optional_hook.default.   N_WEAK_REF
                                         probe, Section = ABSOLUTE      + n_type = 0x01
                                         (-1), Value = 0                (N_EXT | N_UNDF)
</pre>
                </div>
                <p><strong>Read the COFF column twice, because it is the surprise.</strong> There is no weak flag anywhere in a COFF object. No bit, no storage class, no aux field. <strong>The entire mechanism is that the symbol's <em>name</em> is rewritten to something that cannot possibly collide with anything another object would define</strong> &mdash; and the rewrite even embeds the name of the function that referenced it, which is the detail that will make you stop and reread the specification.</p>
                <p>Three teams, one contract, and the answers are placed in three different tables: ELF in a binding nibble inside <code>st_info</code>, Mach-O in the <code>n_desc</code> field of a symbol, and COFF <strong>nowhere at all</strong>. That last one is the finding this concept is built around, and it is the clearest case in the course of a format solving a problem by using a field that was already there.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two questions, and it is worth keeping them apart because the formats answer them with different mechanisms and a reader who merges them will get both wrong.</p>
                <div class="formula">
  Q1  MAY THIS DEFINITION BE OVERRIDDEN?

      A weak DEFINITION says: if anyone else defines this
      name too, use theirs and throw mine away.  It is a
      statement about conflict resolution.

  Q2  IS IT AN ERROR IF NOBODY DEFINES IT?

      An undefined WEAK says: no.  Resolve me to zero and
      carry on.  It is a statement about the link SUCCEEDING.

  They are independent.  A weak definition whose name is
  never defined elsewhere is just a definition.  An
  undefined-weak reference is only ever a reference.
</div>
                <p>And Q2 has a consequence that is the whole reason the feature exists, and it is worth being concrete about the C semantics, because it is what makes the resulting binary safe rather than merely linkable:</p>
                <div class="formula">
  the linker resolves the undefined-weak symbol to
  the address 0.

  so   if (optional_hook)     is  if (0), which is FALSE
       &amp;optional_hook          is  (void*)0

  the code that dereferences it is on a path the author
  proved is unreachable, because the test is right there.

  The guarantee is only as good as the test.  Nothing
  stops a program calling it unconditionally, and then
  the CPU jumps to address 0 and the process dies.
</div>
                <p><strong>So the format's contribution is precisely one bit of information &mdash; &ldquo;absence is not an error, absence is zero&rdquo; &mdash; and everything else about safety is the programmer's.</strong> That is worth stating because it is the difference between a feature that is a language guarantee and one that is a linker behaviour. It is a linker behaviour. A linker that ignored the bit would report an error, and a program written against the feature would stop building &mdash; loudly, which is the good failure mode. A linker that honoured the bit but resolved the symbol to something non-zero would be far worse, and nothing in the object file would let a tool detect it.</p>
                <div class="callout callout-tip">
                    <strong>Mark the model as a model.</strong> &ldquo;Resolve to zero&rdquo; is the behaviour on the targets measured here. It is not a universal law of the formats: a linker that must produce a position-independent binary cannot simply write the absolute address 0 into a field meant to hold an address, and the correct answer there is a relocation against the load base with an addend of zero. <strong>The contract is &ldquo;absence is a defined value, not an error&rdquo;; what that value is depends on whether the output is position-independent</strong>, and <a href="/courses/obj/lessons/obj-pic">Position Independence</a> is where that becomes visible. This is the third time in the course that a simple-looking constant turns out to be a position-dependent value, and the pattern is worth noticing as a pattern.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>ELF: one nibble, used twice</h3>
                <p>Both cases from the staged specimens. <code>w_elf.o</code> defines <code>maybe</code> weakly; <code>uw_elf.o</code> references <code>optional_hook</code> without defining it:</p>
                <div class="hex-dump">
                    <pre>  $ readelf -sW w_elf.o
     3: 0000000000000000  4 FUNC   WEAK  DEFAULT   2  maybe

  $ readelf -sW uw_elf.o
     4: 0000000000000000  0 NOTYPE WEAK  DEFAULT  UND  optional_hook
</pre>
                </div>
                <p><strong>So ELF uses the high nibble of <code>st_info</code> &mdash; the binding &mdash; and that is the whole mechanism, for both questions.</strong> The undefined-weak case is then just the same nibble plus <code>st_shndx == SHN_UNDEF</code>, and the two are genuinely independent: a weak <em>definition</em> has a real <code>st_shndx</code>, an undefined-weak <em>reference</em> has <code>SHN_UNDEF</code> and a weak binding. Four combinations, and all four are meaningful.</p>
                <p>The cost of this design is a three-level dependency, and it is the same one <a href="/courses/obj/lessons/obj-bss-common">the COMMON concept</a> found. <strong>Because <code>SHN_UNDEF</code> is what makes a weak reference may-be-zero, a reader that checks the binding without checking the section index will treat a strong undefined symbol as a weak one and silently resolve it to zero.</strong> Getting &ldquo;absence is not an error&rdquo; right requires reading <code>st_shndx</code> and <code>st_info</code> together, and there is no single field that answers it.</p>

                <h3>Mach-O: two bits, and one of them is a different question</h3>
                <div class="hex-dump">
                    <pre>  decoded from the nlist_64 entries by hand

  w_macho.o
    [0] _maybe           n_type=0x0f  sect=1  n_desc=0x0080  N_EXT N_SECT N_WEAK_DEF
    [1] _uses_weak       n_type=0x0f  sect=1  n_desc=0x0000  N_EXT N_SECT

  uw_macho.o
    [0] _probe           n_type=0x0f  sect=1  n_desc=0x0000  N_EXT N_SECT
    [1] _optional_hook   n_type=0x01  sect=0  n_desc=0x0040  N_EXT N_UNDF N_WEAK_REF
</pre>
                </div>
                <p><strong>Mach-O gives the two questions different bits: <code>0x80</code> for &ldquo;my definition may be discarded&rdquo; and <code>0x40</code> for &ldquo;do not error if I am unresolved&rdquo;.</strong> That is cleaner than ELF's scheme in one respect &mdash; each bit answers exactly one question, so there is no inference from a combination &mdash; and it is what <a href="/courses/obj/lessons/obj-comdat-group">the COMDAT concept</a> found Mach-O using for its entire group mechanism, with no section involved at all.</p>
                <p>Note also <code>n_type = 0x01</code> on the undefined-weak entry: bit 0 is <code>N_EXT</code> and bits 1&ndash;3 are <code>N_UNDF</code>. <strong>So &ldquo;undefined&rdquo; here is a value of the type field, not a sentinel in a separate field</strong> &mdash; the same trick <a href="/courses/obj/lessons/obj-relocations">the relocation record's <code>r_extern</code> bit</a> plays, and a reminder that a format with spare bits in an existing field rarely adds a new field.</p>

                <h3>COFF: no mechanism, only a name</h3>
                <p>Now the interesting one. <code>w_coff.o</code> defines <code>maybe</code> weakly. Here is every symbol in the file:</p>
                <div class="hex-dump">
                    <pre>  Name: .weak.maybe.default.uses_weak
  Value: 0
  Section: .text (1)
  BaseType: Null (0x0)
  ComplexType: Function (0x2)
  StorageClass: External (0x2)      the SAME as any normal function
  AuxSymbolCount: 0

  Name: uses_weak
  Value: 16
  Section: .text (1)
  ...StorageClass: External (0x2)
</pre>
                </div>
                <p><strong>There is no weak flag. The storage class is <code>IMAGE_SYM_EXTERNAL</code>, exactly as for a strong function, and the section is the ordinary <code>.text</code> with no <code>IMAGE_SCN_LNK_COMDAT</code> bit.</strong> The only difference in the entire file is that the name is <code>.weak.maybe.default.uses_weak</code> instead of <code>maybe</code>. And the undefined-weak case is the same trick:</p>
                <div class="hex-dump">
                    <pre>  Name: .weak.optional_hook.default.probe
  Value: 0
  Section: IMAGE_SYM_ABSOLUTE (-1)    not UNDEF(0): an absolute 0
  StorageClass: External (0x2)
</pre>
                </div>
                <p>Three parts, and each one is doing work:</p>
                <ul>
                    <li><strong><code>.weak.</code></strong> &mdash; the marker. A leading dot means the name is in a namespace no C identifier can reach, so it <em>cannot</em> collide with another object's <code>maybe</code>. The weak definition is made un-collidable by renaming rather than by resolving.</li>
                    <li><strong><code>.default.</code></strong> &mdash; the policy, in the name. There is a default that will be used if this one is discarded.</li>
                    <li><strong><code>.uses_weak</code> / <code>.probe</code></strong> &mdash; <strong>the referring function's name. And this is the part that stops you.</strong> COFF has no per-symbol COMDAT mechanism, so its way of making a weak definition both un-collidable and replaceable is to give it a name unique to the (definition, referrer) pair. Two translation units each with their own weak <code>maybe</code> and different callers produce <em>different</em> names &mdash; so they are not merged, they coexist, and the references resolve to whichever the linker picks by the rewritten name.</li>
                </ul>
                <p>And the undefined-weak case is the most elegant accident in the course. <strong><code>Section = IMAGE_SYM_ABSOLUTE (-1)</code> with <code>Value = 0</code> is a structural encoding of &ldquo;the address zero&rdquo;.</strong> <a href="/courses/obj/lessons/obj-symbols">Symbol Tables, Compared</a> found that <code>ABS</code> is a genuinely third thing: the value is a constant, not an address and not an offset, and adding a section base to it produces a pointer that was not intended. <strong>Here that semantic turns out to be exactly right &mdash; the may-be-zero contract <em>is</em> an absolute zero, expressed by choosing the one section index that means &ldquo;absolute&rdquo; and setting the value to zero.</strong> No new field, no new flag: the format says &ldquo;this is the constant 0&rdquo; by pointing at the category that already means constants.</p>
                <div class="callout callout-warn">
                    <strong>And the cost of the COFF design is severe enough to name.</strong> Because the rewrite is a <em>name</em> rewrite, <strong>a tool cannot ask &ldquo;is this symbol weak?&rdquo; &mdash; it can only notice that the name begins with <code>.weak.</code></strong> Any tool that reads COFF symbol names for a different purpose is broken by this: a symbol browser shows <code>.weak.maybe.default.uses_weak</code> instead of <code>maybe</code>; a rewriter that tries to rename <code>maybe</code> finds no such symbol; and &ldquo;which function is weak?&rdquo; becomes a string operation on a name that was never meant to be parsed. <strong>Compare ELF, where the answer is one nibble, and Mach-O, where it is one bit</strong> &mdash; and understand that this is why the other two are better, and that COFF got there by having a symbol table with no spare room.
                </div>

                <h3>What actually happens: strong beats weak, silently, and the bytes stay</h3>
                <p>The behaviour matters more than the encoding, so here it is end to end. <code>w_elf.o</code> has a weak <code>maybe</code>; <code>w2_elf.o</code> has a strong one. Merge them:</p>
                <div class="hex-dump">
                    <pre>  $ ld -r w_elf.o w2_elf.o -o rw.o
  (silent -- no warning, no diagnostic)

  $ readelf -sW rw.o | grep maybe
       8: 0000000000000020  4 FUNC  GLOBAL  DEFAULT  1  maybe

  The symbol is now GLOBAL -- promoted from WEAK -- and
  points at offset 0x20.  There is no second `maybe`.

  $ llvm-objdump-21 -d rw.o
    0000000000000000 &lt;.text&gt;:
         0: 8d 47 ff       leal  -0x1(%rdi), %eax      the WEAK body
         3: c3             retq
        10: e9 00 00 00 00  jmp   uses_weak+0x5        the CALLER
        20: 8d 47 64       leal  0x64(%rdi), %eax      the STRONG body
        23: c3             retq
        30: b8 65 00 00 00  movl $0x65, %eax           `other`
</pre>
                </div>
                <p><strong>Look at offset 0.</strong> The weak definition's bytes &mdash; <code>8d 47 ff c3</code>, the <code>x - 1</code> version &mdash; are <em>still in the merged section</em>, at the start, with <strong>no symbol pointing at them and nothing that will ever execute them</strong>. The symbol table no longer contains the weak <code>maybe</code> at all. <strong>Weak defeat removes the symbol; it does not remove the code.</strong></p>
                <p>That is the finding, and it is not a curiosity. <strong>The only way to reclaim those five bytes is for the weak definition to have been in a section of its own</strong> &mdash; which is exactly what a COMDAT group provides, and exactly what plain <code>__attribute__((weak))</code> does not. <a href="/courses/obj/lessons/obj-comdat-group">The COMDAT concept's</a> group section and this concept's weak symbol are the same mechanism with and without the section boundary, and this is the measurement of what the boundary is worth.</p>
                <p>And the numbers behind that: <code>w_elf.o</code>'s <code>.text</code> is 21 bytes and <code>w2_elf.o</code>'s is 22, but the merged <code>.text</code> is <strong>54</strong>. 21 + 22 = 43, so 11 bytes were added &mdash; and 5 of them are the dead weak body, with the rest alignment padding. <strong>Both inputs' code is present in the output.</strong></p>
                <p>Finally the undefined-weak case, verified by running it:</p>
                <div class="hex-dump">
                    <pre>  $ ld -r uw_elf.o -o ruw.o      # nothing defines optional_hook
  (silent)

  $ readelf -sW ruw.o | grep optional
       8: 0000000000000000  0 NOTYPE  WEAK  DEFAULT  UND  optional_hook
  ^^^^^^ still WEAK, still UND, and that is not an error

  and the C idiom, linked and run both ways:

  $ gcc t.o -o t        &amp;&amp;  ./t
  hook ABSENT -&gt; the weak reference resolved to 0, and the test was false

  $ gcc t.o h.o -o t2   &amp;&amp;  ./t2
  hook present, returned 55
</pre>
                </div>
                <p><strong>Same source, same binary layout, two different answers depending on whether another object supplied the symbol.</strong> And note what the first link did <em>not</em> say: no warning, no note, no marker in the output. An undefined-weak that stays unresolved is completely invisible in the linked product. <strong>Which is a real operational hazard, because &ldquo;the feature silently did not get compiled in&rdquo; and &ldquo;the feature is correctly disabled because nothing provided it&rdquo; are the same binary.</strong> A tool that wants to tell them apart has to look at the input objects, not the output.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The three mechanisms, side by side, scored on the things an implementer has to get right. Every row of it is measured on the specimens in this course's <code>assets/samples/</code>:</p>
                <div class="hex-dump">
                    <pre>                        ELF         COFF              Mach-O
  ----------------------   ----------   ---------------   -----------
  where the answer is     st_info      the symbol's      n_desc
                          high nibble   NAME

  bits needed               1 nibble      0              1 (def)
                                                     1 (ref)

  can a tool ask          yes           no -- only by    yes
  "is this weak?"                      parsing a name

  two independent
  questions                one nibble    one name        two bits
                          + st_shndx    prefix          N_WEAK_DEF
                                                     N_WEAK_REF

  undef-weak encoded as    st_shndx =    Section =       n_type =
                          SHN_UNDEF      ABSOLUTE(-1)    N_UNDF(0)
                          + WEAK         Value = 0
                                         structural

  what happens to a        the symbol   both copies      both copies
  defeated definition     is dropped;   coexist under    coexist
                          the BYTES     rewritten       unowned
                          stay
</pre>
                </div>
                <p>Three rows deserve a second look, because each is a design lesson rather than a fact.</p>
                <p><strong>&ldquo;Can a tool ask is this weak?&rdquo; &mdash; ELF yes, Mach-O yes, COFF no.</strong> That is the strongest argument against the COFF design, and it is not about the linker at all. A linker only needs to resolve names, and COFF's renaming achieves that. <strong>Every <em>other</em> tool &mdash; a symbol browser, a coverage tool, a rewriter, a debugger, a linker that wants to report which definitions were discarded &mdash; is worse off.</strong> The general principle: <strong>encoding a property in a name makes the property unavailable to anyone who is not willing to parse the name</strong>, and the number of tools willing to parse a name is small and falling.</p>
                <p><strong>&ldquo;What happens to a defeated definition&rdquo; &mdash; ELF keeps the bytes, COFF keeps both copies, Mach-O keeps the bytes.</strong> All three leak, and only the COMDAT-group variant does not. So a toolchain that cares about this has to arrange for weak definitions to be group members, which is a <em>policy</em> layered on top of the format's <em>mechanism</em>. <strong>Which is the honest summary of weak symbols in every format: they make a name optional, they do not make its storage free.</strong></p>
                <p>And <strong>&ldquo;undef-weak encoded as&rdquo; &mdash; three different structural answers to the same question.</strong> ELF says &ldquo;the value is not a value; it is a constraint on placement.&rdquo; Mach-O says &ldquo;the symbol is a promise, and a promise has its own type bit.&rdquo; COFF says &ldquo;this is a constant, and the constant is zero, and I already have a category for constants.&rdquo; <strong>Given a choice between inventing a sentinel and finding a category that already means the right thing, COFF found the category</strong> &mdash; and that is the most elegant thing in this module, and also the reason its design has the sharpest edges.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ cd courses/obj/assets/samples
$ readelf -sW w_elf.o uw_elf.o | grep -E 'WEAK|maybe|optional'
$ llvm-readobj-21 --symbols w_coff.o uw_coff.o | grep -A3 'Name: .weak'
$ llvm-objdump-21 -d --syms uw_macho.o</code></pre>
                <ul>
                    <li><strong>Read all three encodings out of the files yourself before reading anything else.</strong> For ELF, take the binding from <code>st_info &gt;&gt; 4</code> and the section index from <code>st_shndx</code>. For Mach-O, mask <code>n_desc</code> against <code>0x40</code> and <code>0x80</code>. For COFF, look for the prefix in the name and then confirm that nothing else in the record differs. <strong>Then write the four-line predicate that answers &ldquo;is this symbol allowed to be absent?&rdquo; for each format</strong> &mdash; and notice that for ELF it needs two fields and for Mach-O one, which is the whole design difference compressed into a predicate.</li>
                    <li><strong>Measure the dead bytes properly, because &ldquo;they stay&rdquo; is a claim about a number.</strong> <code>ld -r w_elf.o w2_elf.o</code>, then compare the merged <code>.text</code> size with the sum of the two inputs'. <strong>21 + 22 = 43, and the merged section is 54.</strong> Work out how much of the 11-byte difference is the 5 bytes of dead weak body and how much is alignment padding, by dumping the merged bytes and counting the <code>nop</code> runs. <strong>Then delete the dead body by hand and confirm the linker produces identical results</strong> &mdash; which is the cleanest possible proof that it is dead.</li>
                    <li><strong>Find out whether the bytes can be reclaimed, and by what.</strong> <code>ld -r --gc-sections w_elf.o w2_elf.o</code> and see whether the weak body survives. <strong>The answer is no</strong>, and the reason is that <code>--gc-sections</code> works on sections and the weak body is not in one of its own. <strong>Now compile the same source as C++ with an <code>inline</code> function so it becomes a group member, and repeat.</strong> The difference between those two experiments is exactly what <a href="/courses/obj/lessons/obj-comdat-group">the COMDAT concept</a> is about, measured rather than argued.</li>
                    <li><strong>Test the COFF rename against a second referrer.</strong> Add a second function to <code>w.c</code> that also calls <code>maybe</code>, rebuild, and look at the symbol name. <strong>You will get two differently-named symbols</strong>, and that is the answer to &ldquo;why is the referrer's name in there?&rdquo; &mdash; the name has to be unique per (definition, referrer) because COFF has nothing else to make it unique. Then add a third function in a <em>different</em> translation unit that also calls it, and confirm you now have three. <strong>Three weak definitions that all mean &ldquo;maybe&rdquo;, coexisting, none of them merged.</strong></li>
                    <li><strong>Find a real use of undefined-weak in a system you own.</strong> <code>grep -rn 'attribute.*weak' /usr/include</code> turns up a handful. <strong>Pick one, find the object that defines it, and find the flag that switches it on</strong> &mdash; which is always a <code>-D</code> or a configure test. Then work out what happens if the object is present but the flag was not passed: does the weak reference resolve to zero and disable the feature, or does something else happen? <strong>That is the operational hazard stated concretely, and it is worth seeing once in the wild.</strong></li>
                    <li><strong>Test the ELF three-level dependency by breaking it.</strong> Take a copy of <code>w2_elf.o</code>, find the strong <code>maybe</code>'s <code>st_info</code>, and change its binding nibble from <code>GLOBAL</code> to <code>WEAK</code>. <strong>Now two weak definitions collide</strong>, and the linker must pick one &mdash; watch which it picks, and whether it says anything. Then do the same to <code>uw_elf.o</code>'s <code>st_shndx</code>, changing it from <code>SHN_UNDEF</code> to a real section index, and confirm the undefined-weak is now treated as a genuine undefined symbol. <strong>Both edits are single nibbles, and both change the program's meaning completely.</strong></li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a COFF object contains a weak definition of <code>maybe</code>, and you are writing a symbol browser. Its symbol table shows <code>.weak.maybe.default.uses_weak</code> with <code>StorageClass = IMAGE_SYM_EXTERNAL</code> and the section being the ordinary <code>.text</code>. There is no weak flag, no storage class for weak, and no COMDAT bit. Meanwhile the equivalent ELF object has <code>st_info &gt;&gt; 4 == STB_WEAK</code> and the Mach-O object has <code>n_desc == 0x80</code>. Why can your browser answer the question for two of the three formats and not the third, and what is the cost of the third format's choice?</p>
                <div class="quiz" id="quiz-obj-weak-undef-1">
                    <button class="quiz-option" data-correct="true" data-explain="The reason is that ELF and Mach-O store the property in a field and COFF stores it in the name, and a browser can read a field but has to parse a string to read a name. Specifically: in ELF the property is the high nibble of st_info, a value the browser already has in hand because it had to read the binding to display it at all. In Mach-O it is a bit in n_desc, a field whose entire purpose is descriptor bits, so masking it is free. In COFF the storage class is IMAGE_SYM_EXTERNAL -- identical to a strong function -- and the only signal is the literal prefix in the name, so the browser would have to hard-code the string '.weak.' and the segment grammar around it. The cost is not merely that this browser cannot do its job. It is that the property has become unavailable as data, and every tool that wants it must re-derive the same convention independently, in a language with no way to declare that convention, and get it exactly right. That list includes debuggers, coverage tools, rewriters, linkers that report which definitions were discarded, and anything that wants to rename or intercept the symbol -- all of which see a name that no C identifier can produce and none of which can ask what it means. The deeper cost is that the information is present in the file but not in a form the file's own structure makes addressable, and that is a different and more serious kind of loss than omitting it. A linker still resolves correctly, so the format works for its primary purpose; it fails every secondary purpose at once, silently." onclick="checkQuiz('obj-weak-undef-1', this)">Because ELF and Mach-O store the property in a <strong>field</strong> and COFF stores it in the <strong>name</strong>. Your browser already has <code>st_info</code> and <code>n_desc</code> in hand to display a symbol at all, so masking out <code>STB_WEAK</code> or <code>0x80</code> is free; in COFF the storage class is the ordinary <code>EXTERNAL</code> and the only signal is the literal prefix <code>.weak.</code>, so the browser must hard-code a string convention. The cost is that the property has become <strong>unavailable as data</strong> &mdash; every secondary tool has to re-derive the same convention independently and get it exactly right, and none of them can ask the file what a name means</button>
                    <button class="quiz-option" data-correct="false" data-explain="The conclusion is right and the mechanism is named correctly in the first sentence, but the explanation of why the field-based designs are easier is wrong, and it is wrong in a way that inverts the real trade-off. The claim is that a browser must parse a name to learn what it means, and that is true. What is not true is the implication that a browser could not do the same with a flag field -- it could, trivially, and the ELF and Mach-O cases demonstrate exactly that. So the framing makes it sound as though field-based storage were the thing forcing the parse, when in fact it is the absence of a field that does. That matters because it hides where the real difficulty lies. The real difficulty is not that names are harder to read than fields. It is that a name is a value other things are keyed on. The symbol '.weak.maybe.default.uses_weak' is what every relocation, every archive index entry and every other object's reference is matched against, so the rename is not a label applied for display -- it is a change to the symbol's identity in the format's primary namespace. And that has a consequence the display framing hides entirely: a COFF weak definition and a COFF strong definition of maybe are two different symbols as far as every consumer of the file is concerned, so they do not conflict, do not merge, and do not override one another. They coexist. The cost is therefore not that a browser has to parse a string; it is that the mechanism changes what the symbol means to the rest of the toolchain." onclick="checkQuiz('obj-weak-undef-1', this)">COFF has no weak flag, so your browser has to parse the name &mdash; and that is fine, because ELF and Mach-O make a browser parse their symbol tables too, so the extra work is trivial. The real cost is only the few extra lines of string handling</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a size-optimising linker for ELF. It drops unreferenced sections before resolving symbols, which is a large win on C++ binaries with thousands of <code>.text._Z...comdat</code> sections. It works. Then a program that uses <code>__attribute__((weak))</code> for an optional platform feature silently stops providing that feature, with no diagnostic, and only on one machine. Given what the previous concepts measured, what is happening, and what is the smallest change that fixes it without giving up the size win?</p>
                <div class="quiz" id="quiz-obj-weak-undef-2">
                    <button class="quiz-option" data-correct="true" data-explain="What is happening is that the linker dropped the section holding the weak definition before resolving the reference, so when resolution ran, the symbol was genuinely undefined, and because it was an undefined WEAK the linker was required to resolve it to zero rather than report an error. Every step of that was correct behaviour, which is exactly why it is silent. The section was unreferenced at the time the sweep ran, because the only reference to it is a relocation from a section that is itself still marked live -- so the sweep saw an incoming edge from a live section but the weak definition's own section was not itself reachable in the usual sense, and depending on the order of operations it went first. The catch is that the correct fix is not in the sweep at all, and recognising that is the substance of the question. Marking the weak definition's section live would work, but it is a special case bolted onto a general algorithm, and it is a special case that will be wrong again the next time some other kind of deferred reference appears. The general fix is ordering: resolve symbols first, using a sweep that treats an unresolved weak reference as a reason to keep whatever might satisfy it, and only then drop sections that nothing reachable needs. At that point the optional feature's section is still present, resolves, and the feature works; and on a machine where nothing provides the feature, the same pass resolves it to zero and the drop happens on the next sweep, which is where the size win still comes from. So the general habit is that deferred-reference mechanisms -- weak, COMMON, COMDAT -- all break naive reachability sweeps, and the fix is a phase ordering that makes resolution authoritative rather than a special case per mechanism." onclick="checkQuiz('obj-weak-undef-2', this)">The sweep dropped the section holding the weak definition <em>before</em> resolution ran, so the reference became genuinely undefined &mdash; and because it was an undefined <strong>weak</strong> reference, the linker was then <em>required</em> to resolve it to zero instead of reporting an error. Every step was correct, which is why it is silent. Do not special-case weak in the sweep: <strong>reorder the passes so symbol resolution is authoritative and unreferenced-section dropping happens after</strong>, with a sweep that treats an unresolved weak reference as a reason to retain what could satisfy it. The size win is unaffected, because the drop still happens on the following pass for anything nothing reaches</button>
                    <button class="quiz-option" data-correct="false" data-explain="The mechanism is half right and the fix is exactly the thing to avoid, so this answer would make the program correct once and keep it fragile thereafter. What is right: the weak definition's section was dropped, the reference became undefined, and the undefined weak resolved to zero instead of erroring, which is why there was no diagnostic. What is wrong: the proposed fix. Marking the weak definition's section live is a special case bolted onto a reachability sweep, and reachability sweeps are exactly the kind of algorithm that acquires special cases. The next mechanism with the same shape will not be handled -- COMMON is one, since a tentative definition has no section at all and cannot be marked live by section index; COMDAT selection is another, since a group member is retained because of a group relationship rather than an incoming relocation edge; and a linkonce section in a format that has one is retained because of a flag. Each would need its own rule, each rule would need to be ordered correctly against the sweep, and the interactions between them are where the remaining bugs live. Worse, the special case is stated too weakly to be correct even on its own: a weak definition can lose to a strong one, in which case its section is genuinely dead and should be dropped, and 'mark it live' would retain it forever. The right framing is that resolution has to become authoritative -- resolve symbols first, letting an unresolved weak reference retain whatever might satisfy it, and only then drop what nothing reachable needs. That handles COMMON, COMDAT and weak in one ordering rather than in three exceptions." onclick="checkQuiz('obj-weak-undef-2', this)">The sweep dropped the weak definition's section before resolution, so the reference became undefined and &mdash; being weak &mdash; resolved to zero instead of erroring. <strong>Fix it by marking the section containing a weak definition as always-live in the reachability sweep</strong>, so it is never dropped. The size win is unaffected, because a section nobody references is still dropped</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: weak, COMMON and COMDAT all break a naive reachability sweep, because each is a reference whose satisfier is not obvious from the relocation graph. Fix the phase ordering once rather than adding a special case per mechanism.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept closes the selection module, and the three concepts in it are worth reading together as one argument. <a href="/courses/obj/lessons/obj-comdat-group">COMDAT</a> answered &ldquo;which of two definitions survives&rdquo;. <a href="/courses/obj/lessons/obj-archives">The archive</a> answered &ldquo;which of three hundred objects is loaded at all&rdquo;. This one answers &ldquo;what if nothing supplies it at all&rdquo; &mdash; and the three together are the complete set of answers a linker has to a symbol that is not simply there. <strong>The shape of all three is the same: the format gives the linker permission to make a decision the language otherwise forbids, and records enough for the decision to be made the same way twice.</strong> That is the design pattern, and it recurs in every format in the collection.</p>
                <p>The connection to <a href="/courses/obj/lessons/obj-symbols">Symbol Tables, Compared</a> is where the COFF <code>ABS</code> encoding connects up. <strong>An undefined-weak reference in COFF is a symbol with <code>SectionNumber = IMAGE_SYM_ABSOLUTE</code> and <code>Value = 0</code></strong> &mdash; and that concept found <code>ABS</code> to be a genuinely third category, distinct from both &ldquo;undefined&rdquo; and &ldquo;defined in a section&rdquo;, with the warning that adding a section base to it produces a pointer that was not intended. <strong>Here is a case where the format's own semantics are exactly right and the warning's consequence is the feature.</strong> The may-be-zero contract <em>is</em> an absolute zero, so the format says it by pointing at the category that already means constants. Compare ELF, which had to invent <code>SHN_COMMON</code> for its version of the same idea, and Mach-O, which spent a whole section on it. <strong>Three answers again, and the one that reused an existing category is the shortest.</strong></p>
                <p>There is a direct link to <a href="/courses/obj/lessons/obj-bss-common">COMMON and the ABI Break</a> that is more than thematic. <strong>Both mechanisms exist because C has a symbol whose definition is not in the file you are looking at</strong> &mdash; COMMON because a tentative definition may be satisfied by another object, undefined-weak because the definition may never exist. And both had the same fate in the same decade: the format recorded a decision each producer made locally, and nothing in the format said the two decisions were incompatible, so GCC 9 and GCC 10 broke every prebuilt library on every Linux distribution. <strong>The lesson generalises past COMMON: a format that lets producers record an optionality decision needs a way to make two <em>different</em> optionality decisions interoperate, or the decision has to be made by the language instead.</strong> C++ did that for inline functions; C never did for tentative definitions, and the bill came due.</p>
                <p>On the operational side the invisible-unresolved case is worth connecting to something outside the course entirely, because it is a general engineering shape. <strong>A feature that is silently disabled when its provider is missing looks exactly like a feature that is correctly disabled when nothing provides it</strong>, and no amount of inspecting the output binary will tell you which happened. Every build system that supports optional components has this problem, and the general solutions are the same three: make the absence loud (a warning that survives), record the decision in the output so it can be inspected later, or make the provider's presence a compile-time fact rather than a link-time one. <strong>Weak symbols give you none of the three, which is why they are used for exactly the cases where a silent default is the desired behaviour &mdash; and why a platform feature built on them should have a way to report &ldquo;this was not compiled in&rdquo; that does not go through the weak symbol.</strong></p>
                <p>Finally, the dead-bytes finding connects straight to the module that follows. <a href="/courses/obj/lessons/obj-emit">Writing One From Scratch</a> is about the smallest complete object file, and it turns out that the hand-built one needs a concept this module has just finished supplying: <strong>a weak symbol is how you make a definition optional, and an undefined symbol is how you make a reference deferred</strong> &mdash; and the object file being built there has one of each, an undefined <code>helper</code> and a <code>PLT32</code> against it. <strong>Module 3 gave the arithmetic and Module 4 gave the selection rules; the next module asks you to write both down.</strong></p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/obj/lessons/obj-archives">Previous: The Archive</a></span>
                <span>Next: Writing One From Scratch</span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
