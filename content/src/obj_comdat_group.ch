// Object Files — Module 4: Merging and Selection
// Concept: one problem, three independent inventions, in three different
// places in the file -- a group table, a section flag, and a symbol bit. And
// why the mechanism is a C++ requirement that C never had.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_obj_comdat_group() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("COMDAT, GROUP, linkonce — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson obj-lesson">
            <a href="/courses/obj" class="back-link">Back to course</a>
            <h1>COMDAT, GROUP, linkonce</h1>
            <div class="lesson-meta">19 min &middot; Module 4: Merging and Selection &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Here is a C++ program that is perfectly legal, correct, and which a naive linker refuses to build:</p>
                <div class="hex-dump">
                    <pre>  // comdat_a.cpp                    // comdat_b.cpp

  inline int shared_inline(int x)         inline int shared_inline(int x)
      return x + 1;                            return x + 1;

  int a(int v)                            int b(int v)
      return shared_inline(v);                 return shared_inline(v);
</pre>
                </div>
                <p class="code-note">Braces omitted for the width; the two definitions are otherwise identical, which is the entire point of the example.</p>
                <p>Two translation units, each with its own copy of <code>shared_inline</code>, each wanting it at a global name. <strong>A linker that reports a duplicate symbol is not broken &mdash; it is being told the truth about a file format that has no way to say &ldquo;these two definitions are the same definition.&rdquo;</strong> C++ says they are: an <code>inline</code> function with external linkage may be defined in any number of translation units, and every one of those definitions must be identical. The language has made a promise that the object file has to be able to <em>record</em>, or the toolchain cannot keep it.</p>
                <p>Every format here has an answer, and the surprising part is that <strong>the three teams put the answer in three completely different places in the file</strong>:</p>
                <div class="hex-dump">
                    <pre>  ELF      a whole EXTRA SECTION   (SHT_GROUP), plus a weak symbol
  COFF     a FLAG on an existing section (IMAGE_SCN_LNK_COMDAT), plus a
           selection policy and a content checksum in the symbol table
  Mach-O   NO SECTION MECHANISM AT ALL -- one bit in the symbol table
           (N_WEAK_DEF) and an ordinary .text
</pre>
                </div>
                <p>That last one is the finding, and it runs against the name you already know. <strong>There is no <code>linkonce</code> section type in Mach-O.</strong> Modern clang does not emit one, and the term does not appear in LLVM's own Mach-O format definitions at all &mdash; which is checkable, and the check is in the exercise below. The mechanism is a symbol-table bit. <strong>Three teams, one problem, and the answer that survived is the one that needed the least new machinery.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Before the three mechanisms, the decisions they all encode, because a linker has to make four separate decisions and the formats differ on which of them the file records and which the linker infers.</p>
                <div class="formula">
  GIVEN  two definitions of symbol S, one from each of two objects

  Q0  IS THERE EVEN A DEFINITION TO MERGE?

      If the symbol is UNDEFINED in the object there is
      nothing to merge, and a group would have nothing to
      own.  This is the C inline trap, and it is the most
      common reason a learner expects a COMDAT and finds
      none.

  Q1  WHICH DEFINITION WINS?

      Only one copy may survive.  ELF and Mach-O answer
      this the same way -- it does not matter, because the
      definitions are required to be identical.  COFF goes
      further and records a SELECTION policy explicitly.

  Q2  HOW DO I KNOW THEY ARE THE SAME DEFINITION?

      The hard one.  The three formats answer it three
      different ways, or do not answer it at all.
        ELF     nobody checks.  The name is the claim.
        COFF    a 32-bit CHECKSUM of the section contents.
        Mach-O  nobody checks.  The name is the claim.

  Q3  WHICH BYTES SURVIVE?

      The winner's, and every relocation against the loser
      has to be re-pointed.  Same in all three.
</div>
                <p><strong>Mark the model as a model.</strong> The four decisions are real, but no format states them as a checklist. ELF's group section records Q0 implicitly (a group with one member section and a weak symbol) and Q1 as a flag bit. COFF records all four explicitly, in three different fields, across two different tables. Mach-O records only Q0 and Q1, and leaves Q2 entirely to the language lawyer.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>ELF: a group is its own section, and the name is the signature</h3>
                <p><code>ca_elf.o</code> has a section called <code>.group</code>. All eight bytes of it:</p>
                <div class="hex-dump">
                    <pre>  Hex dump of section '.group':
    0x00000000 01000000 05000000                   ........

  +0  flags     u32   0x00000001   GRP_COMDAT
  +4  shndx     u32   0x00000005   section 5 is a member

  and readelf renders the whole structure:
    COMDAT group section [4] `.group' [_Z13shared_inlinei] contains 1 sections:
       [Index]    Name
       [    5]   .text._Z13shared_inlinei
</pre>
                </div>
                <p>Three things to notice, and the third is the one that matters most.</p>
                <ul>
                    <li><strong>The signature is the symbol name.</strong> <code>_Z13shared_inlinei</code> is the Itanium C++ mangling of <code>shared_inline(int)</code> &mdash; <code>_Z</code>, then <code>13</code> for the length, then the characters. <strong>Nothing else in the group identifies it.</strong> The group section has no name of its own that means anything; the <em>symbol</em> is the key.</li>
                    <li><strong>The member section is named after the signature too.</strong> <code>.text._Z13shared_inlinei</code>. So the key appears twice, in two tables, and both had better agree &mdash; which is a real invariant a validator can check for free.</li>
                    <li><strong>The member carries the <code>G</code> group flag, and the symbol is demoted to <code>WEAK</code>.</strong> From the symbol table:</li>
                </ul>
                <div class="hex-dump">
                    <pre>       Num:    Value          Size Type    Bind   Vis      Ndx Name
         3: 0000000000000000     0 SECTION LOCAL  DEFAULT    5 .text._Z13shared_inlinei
         5: 0000000000000000     4 FUNC    WEAK   DEFAULT    5 _Z13shared_inlinei
</pre>
                </div>
                <p><strong>So ELF answers the &ldquo;which wins&rdquo; question by demoting the symbol to <code>STB_WEAK</code>.</strong> That is the whole trick, and it is worth noticing that it is the <em>same mechanism</em> <a href="/courses/obj/lessons/obj-weak-undef">the next-but-one concept</a> covers for ordinary weak symbols. COMDAT is not a fourth weak-symbol design; it is weak symbols plus a section, so a linker can throw away the section and everything in it. <strong>That is the reason the body has to be in its own section: without a section boundary, a linker cannot discard it.</strong></p>

                <h3>COFF: a flag, a duplicate name, a policy and a checksum</h3>
                <p><code>ca_coff.o</code> has <strong>six</strong> sections, and two of them are named <code>.text</code>:</p>
                <div class="hex-dump">
                    <pre>  Number: 1   Name: .text   RawDataSize: 5   Characteristics 0x60500020
  Number: 4   Name: .text   RawDataSize: 4   Characteristics 0x60501020
                                                        ^^^^^^^^
                        the difference is 0x1000 = IMAGE_SCN_LNK_COMDAT
</pre>
                </div>
                <p>And the COMDAT section's own bytes are <code>8d 41 01 c3</code> &mdash; the same four bytes as in the other object. But the interesting data is not in the section header. It is in the symbol table's auxiliary record:</p>
                <div class="hex-dump">
                    <pre>  ca_coff.o: COMDAT aux: Length=4  nrel=0  Checksum=0x751D2B5A  Number=4  Selection=2
  cb_coff.o: COMDAT aux: Length=4  nrel=0  Checksum=0x751D2B5A  Number=4  Selection=2

  Selection 2 = IMAGE_COMDAT_SELECT_ANY
  "any of these copies will do"
</pre>
                </div>
                <p>So COFF's answer is scattered across <strong>three fields in two tables</strong>, and every one of them is doing something the other two formats do not do:</p>
                <ul>
                    <li><strong><code>IMAGE_SCN_LNK_COMDAT</code> in the section header</strong> &mdash; the flag that says &ldquo;this section is discardable.&rdquo; ELF expresses the same idea with the <code>G</code> flag, so this one is a tie.</li>
                    <li><strong><code>Selection</code> in the aux record</strong> &mdash; the policy. <strong>This is the part ELF and Mach-O simply do not have.</strong> <code>SELECT_ANY</code> means any copy will do; <code>SELECT_NODUPLICATES</code> means &ldquo;only discard this if there is an identical one elsewhere&rdquo;; <code>SELECT_ASSOCIATIVE</code> means &ldquo;discard me together with the section named in the next field.&rdquo; <strong>A linker therefore has three policies available and the producer gets to choose, which is strictly more expressive than picking one for everybody.</strong></li>
                    <li><strong><code>Checksum</code> in the aux record</strong> &mdash; the only mechanism among the three formats that attempts Q2 at all. Both objects here hash to <code>0x751D2B5A</code>, which is what makes the merge safe. <strong>And it is advisory, which matters enormously.</strong></li>
                </ul>
                <div class="callout callout-warn">
                    <strong>The checksum is not an integrity check, and treating it as one is how you ship a miscompilation.</strong> The <a href="/courses/coff/lessons/coff-comdat-linking">COFF course measured this</a>: changing one character of an inline function's body makes the checksum differ, and GNU ld in PE mode <strong>discards the differing copy anyway</strong>, with no diagnostic. The result is a program that returns the wrong answer. <strong>So the honest statement is that COFF gives a linker the <em>information</em> to notice a disagreement and does not oblige it to act on that information</strong> &mdash; a real improvement over having nothing, and not the guarantee the word &ldquo;checksum&rdquo; suggests. ELF and Mach-O do not even have that much, and the language's promise that the definitions are identical is what makes the gap tolerable.
                </div>

                <h3>Mach-O: one bit, and no section at all</h3>
                <p>Here is the surprise. <code>ca_macho.o</code> has <strong>two</strong> sections &mdash; <code>__text</code> and <code>__eh_frame</code>. There is no <code>__text</code> member section, no <code>linkonce</code> section, no group. Both functions sit in the ordinary <code>__text</code>:</p>
                <div class="hex-dump">
                    <pre>  __text       seg=__TEXT  addr=0x0000 size=0x0019 off=0x0180 flags=0x80000400
  __eh_frame   seg=__TEXT  addr=0x0020 size=0x0068 off=0x01a0 flags=0x6800000b

  and the symbol table:
    [0] __Z13shared_inlinei  n_type=0x0f  sect=1  n_desc=0x0080  value=0x10
                             N_EXT  N_SECT  N_WEAK_DEF
    [1] __Z1ai               n_type=0x0f  sect=1  n_desc=0x0000  value=0x00
                             N_EXT  N_SECT
</pre>
                </div>
                <p><strong><code>n_desc = 0x0080</code> is <code>N_WEAK_DEF</code>, and that is the entire mechanism.</strong> The symbol is a weak definition in a normal code section. A Mach-O linker resolving two weak definitions of the same name picks one, exactly as it does for any other weak symbol, and needs to know nothing about sections.</p>
                <p>Confirm the absence rather than taking it on trust:</p>
                <div class="hex-dump">
                    <pre>  $ grep -i "linkonce" /usr/lib/llvm-21/include/llvm/BinaryFormat/MachO.h
  (no output)

  $ clang -target x86_64-apple-macosx -O1 -fno-inline -c comdat_a.cpp
  $ llvm-nm-21 ca_macho.o
  0000000000000010 T __Z13shared_inlinei        'T', not 't', and no section
  0000000000000000 T __Z1ai
</pre>
                </div>
                <p>So the honest comparison is this, and it is the most useful thing in the concept:</p>
                <div class="formula">
                    answer lives    ELF   a whole new section type
  -----------------     -------------------------------------------
  where it lives        ELF   the section header table
                       COFF  the section header + the symbol table
                       Mach-O nowhere -- a bit in a symbol

  cost of the mechanism  ELF   +1 section per group, +1 symbol
                       COFF  +1 section, +1 aux record
                       Mach-O +0 sections, +0 aux records, 1 bit

  can it detect that
  two copies disagree?  ELF   no
                       COFF  yes, but the linker need not care
                       Mach-O no
</div>
                <p><strong>Mach-O is the cheapest answer and it is also the one that makes the compiler work hardest</strong>, because the linker cannot throw away a section it was never given &mdash; so the compiler must be certain the body is emitted identically everywhere, or must accept that a discarded weak symbol leaves dead bytes behind. <a href="/courses/obj/lessons/obj-weak-undef">The weak-symbol concept</a> measures exactly what that costs, and it is a real cost.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Does It Actually Work?</h2>
                <p>All of the above is structure. The thing that matters is the behaviour, so here it is &mdash; the C++ pair and the counterfactual side by side, same machine, same linker:</p>
                <div class="hex-dump">
                    <pre>  $ ld -r ca_elf.o cb_elf.o -o merged.o
  (silent)

  $ readelf -gW merged.o
  COMDAT group section [1] `.group' [_Z13shared_inlinei] contains 1 sections:
       [    7]   .text._Z13shared_inlinei

  $ llvm-nm-21 merged.o
  0000000000000000 W _Z13shared_inlinei     still WEAK, now in the merged file
  0000000000000000 T _Z1ai
  0000000000000010 T _Z1bi

  ONE copy of the body survived.
</pre>
                </div>
                <p>And the counterfactual &mdash; the same two translation units, the same collision, but with a plain (non-<code>inline</code>) function, so there is no group:</p>
                <div class="hex-dump">
                    <pre>  $ ld -r dup_a.o dup_b.o -o dup_merged.o
  ld.bfd: dup_b.o: in function `collide':
  dup_b.c:(.text+0x0): multiple definition of `collide';
      dup_a.o:dup_a.c:(.text+0x0): first defined here
  exit status 1
</pre>
                </div>
                <p><strong>So the mechanism is not decorative: it is the difference between a legal C++ program that links and a hard error.</strong> Worth pausing on the error message, though, because it names the reason precisely. <code>multiple definition</code> &mdash; not <code>duplicate symbol</code>. The linker is not confused about the symbol; it has found two definitions and has been given no information authorising it to discard one. <strong>The group is precisely that authorisation, and it is 8 bytes wide.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Now the part that catches people, and the reason this concept is in the course's &ldquo;Merging and Selection&rdquo; module rather than somewhere more comfortable. <strong>Write the same function four ways in C and see which ones produce a group:</strong></p>
                <div class="hex-dump">
                    <pre>  source                          nm says        group?  two TUs link?
  -------------------------------  -------------  -------  ----------------
  inline int f(int x) ...        U f            NO      n/a: nothing exists
                                    (C99: no
                                     definition)

  static inline int f(int x) ...   t f            NO      n/a: private to
                                    (local text)            one file

  inline int f(int x) ...
  extern int f(int x);              T f            NO      FAILS:
  (the C89 idiom)                                  (global)  multiple definition
                                                                of `f'

  inline int f(int x) ...        T f + WEAK     YES     links silently
  (C++, external linkage)          + SHT_GROUP
</pre>
                </div>
                <p><strong>Read the third row carefully, because it is the whole point of the concept.</strong> In C, the standard's <code>inline</code>/<code>extern inline</code>/<code>static inline</code> rule means that <code>inline</code> alone provides <em>no</em> external definition, so adding an <code>extern</code> declaration is how you get one. And having got one, you have <strong>no mechanism to merge it with another translation unit's</strong> &mdash; because the merge is a C++ language feature and C never got one.</p>
                <p>Measured, on the same machine:</p>
                <div class="hex-dump">
                    <pre>  $ ld -r ce_a.o ce_b.o -o ce_merged.o
  ld.bfd: ce_b.o: in function `f_e':
  ce_b.c:(.text+0x0): multiple definition of `f_e'; ...

  $ ld -r ca_elf.o cb_elf.o -o cxx_merged.o
  (silent)
</pre>
                </div>
                <p>So the rule, stated once: <strong>a COMDAT group exists only for a symbol with external linkage that more than one translation unit is allowed to define.</strong> C's <code>static inline</code> is private, so there is nothing to merge. C's plain <code>inline</code> provides no definition at all, so there is nothing to own. C's <code>inline</code> + <code>extern</code> does have a definition, but C does not license the duplication, so a collision is the correct answer. C++'s <code>inline</code> has an external definition <em>and</em> licenses the duplication, <strong>which is exactly the situation a group exists to resolve.</strong></p>
                <div class="callout callout-tip">
                    <strong>The first row is the one that costs people an afternoon.</strong> Plain C <code>inline</code> produces an <strong>undefined</strong> symbol &mdash; <code>U f</code> &mdash; and the error you get is <code>undefined reference to 'f'</code>, pointing at a function that is <em>right there in the source, on the line above</em>. Nothing in the object file hints that a definition was expected and omitted; the file faithfully records the C semantics, which is that there is none. <strong>The rule to remember: in C, <code>inline</code> without an <code>extern</code> declaration means &ldquo;do not emit a definition&rdquo;; in C++ it means &ldquo;emit one, and let the linker merge the copies.&rdquo;</strong> One keyword, two languages, opposite meanings, and the object file is the only place the difference is visible.
                </div>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ cd courses/obj/assets/samples
$ readelf -gW ca_elf.o ; readelf -x .group ca_elf.o
$ llvm-readobj-21 --sections ca_coff.o | grep -B4 LNK_COMDAT
$ llvm-nm-21 ca_macho.o ; grep -i linkonce /usr/lib/llvm-21/include/llvm/BinaryFormat/MachO.h</code></pre>
                <ul>
                    <li><strong>Build the four C variants yourself and read all three formats for each.</strong> Write <code>inline</code>, <code>static inline</code>, <code>inline</code> + <code>extern</code>, and the C++ version. For each, run <code>llvm-nm-21</code> and <code>readelf -gW</code>. <strong>Fill in the table above from your own output rather than from this page</strong> &mdash; and notice that the group appears for exactly one of the four, and that the reason is a linkage question, not an optimisation one.</li>
                    <li><strong>Prove the absence claims rather than believing them.</strong> <code>grep -i linkonce</code> in LLVM's <code>MachO.h</code> returns nothing. Then check what <em>is</em> there: <code>N_WEAK_DEF</code> is <code>0x80</code> and <code>N_WEAK_REF</code> is <code>0x40</code>. <strong>Find the bit in <code>ca_macho.o</code>'s <code>n_desc</code> yourself and confirm it is <code>0x80</code>.</strong> A claim of absence is only worth as much as the check that established it, and this one takes ten seconds.</li>
                    <li><strong>Change one character of the inline body and re-measure the checksum.</strong> Edit <code>comdat_b.cpp</code> so the two bodies differ, rebuild, and read the COMDAT <code>Checksum</code> from both aux records. <strong>They will differ</strong>, and the ELF and Mach-O files will show you nothing at all &mdash; no group change, no symbol change. Then link the two COFF objects with <code>ld -m i386pe</code> and see whether the linker cares. <strong>This is the experiment that separates &ldquo;has a checksum&rdquo; from &ldquo;checks the checksum&rdquo;.</strong></li>
                    <li><strong>Test <code>SELECT_NODUPLICATES</code> against <code>SELECT_ANY</code>.</strong> Hand-edit the <code>Selection</code> byte in a copy of <code>ca_coff.o</code> from 2 to 1, fix the <code>Checksum</code> field to match whatever the file now contains, and link. <strong>Work out what &ldquo;only discard this if an identical one exists&rdquo; means for an object that is the only definition in the link</strong> &mdash; the answer is that the copy must be kept, and the <code>SELECT_ANY</code> version would have let it be thrown away. This is the clearest demonstration in the course that these fields are load-bearing rather than decorative.</li>
                    <li><strong>Look for the group in a real binary rather than a synthetic one.</strong> Link a C++ program against <code>libstdc++</code> and run <code>readelf -gW</code> on the result. <strong>Count the groups, and then check what the linker did with them</strong> &mdash; the groups survive into an executable, because a fully linked image may still be fed to another linker, and the <code>GRP_COMDAT</code> flag is what tells it they are still discardable.</li>
                    <li><strong>Answer the &ldquo;what is this for a linker author&rdquo; question.</strong> You must handle a group, a COMDAT section, and a weak symbol. <strong>Write the three-line pseudocode for each</strong> and compare. Then decide which of the three needs the most machinery &mdash; and check your answer against the table at the end of the REALITY unit, because the intuition that the section-based mechanisms are heavier is right, and knowing <em>why</em> is the point.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a Mach-O object and an ELF object both contain two translation units' copies of the same C++ <code>inline</code> function, and both link silently. The ELF object has an extra section in its section header table that the Mach-O object does not have, and yet the Mach-O one is the smaller and simpler mechanism. What does ELF's extra section buy that Mach-O's symbol bit does not, and what does it cost?</p>
                <div class="quiz" id="quiz-obj-comdat-group-1">
                    <button class="quiz-option" data-correct="true" data-explain="What ELF's extra section buys is discardability at section granularity, and that is the whole of it. A linker that keeps one copy of a weak definition has to decide what happens to the other copy's bytes. Mach-O's answer, via N_WEAK_DEF alone, is that it cannot throw the losing body away, because the body was never in a section of its own -- it was interleaved in an ordinary __text with the rest of the translation unit's code. So the dead bytes stay in the output, and the symbol is simply re-pointed. ELF's answer is to give the definition its own section, flag it with G, and record its membership in a group section keyed on the symbol name. Now the linker has a unit it can drop wholesale: the section, its relocations, and its symbol. The cost is a whole new section header, a whole new section type in the file's type space, a group section, and a second appearance of the signature in two tables that must agree. And there is a second cost this course measured directly, which is the one that makes the choice genuinely hard rather than merely expensive: with the body in its own section, dead-code elimination and linker garbage collection can reclaim it, and without it they cannot. So the extra section is not overhead for its own sake -- it is what makes the discard possible at all, and it is the reason a C++ binary linked with garbage collection is much smaller than one linked without. The Mach-O design is smaller in the object and pays for it in the output." onclick="checkQuiz('obj-comdat-group-1', this)">It buys <strong>discardability at section granularity</strong>. A linker that keeps one copy of a weak definition has to decide what happens to the losing copy's bytes, and <code>N_WEAK_DEF</code> alone cannot tell it: the body was never in a section of its own, so it sits interleaved in an ordinary <code>__text</code> and can only be re-pointed, not dropped. ELF's extra section gives the linker a unit it can discard wholesale &mdash; the section, its relocations, its symbol &mdash; which is also what makes <code>--gc-sections</code> able to reclaim the loser. The cost is a new section type, a section header, a group section, and the signature appearing twice in two tables that must agree</button>
                    <button class="quiz-option" data-correct="false" data-explain="The mechanism is right but the benefit is attributed to the wrong party, and the distinction matters because it inverts which design you would defend in a code-size argument. Discardability is not a property of the section itself; it is a property of what a linker is permitted to do with it, and the permission has to be recorded somewhere. ELF records the permission twice -- the G flag on the member section says 'this section is group discardable', and the SHT_GROUP section says which group it belongs to and what the group's key is. Mach-O records neither, because it does not use sections for this at all: the mechanism is a bit in the symbol table, and there is no section whose contents a linker could remove. So the accurate statement is that ELF's mechanism is what makes discardability expressible, not that ELF's mechanism is discardable. The consequence for garbage collection is the same either way, and it is the strongest practical argument for the section-based design: with the definition in its own section, a linker that discards unused sections reclaims the losing body, and with a bare symbol bit it cannot, because no section boundary marks the body as separable. A C++ binary linked with --gc-sections is substantially smaller than one linked without, and that difference is created by the group, not by the weak symbol." onclick="checkQuiz('obj-comdat-group-1', this)">It buys the ability to detect that two copies disagree, by putting both the definition and its identity in a place a linker can check. Without the section, Mach-O has no way to know whether the two bodies match, so a linker using only the symbol bit must trust the language rule and may merge two different functions. The cost is a new section type, a section header, and 8 bytes of group section per group</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a linker for ELF, COFF and Mach-O. You have implemented symbol resolution: strong beats weak, a strong definition beats a weak one, two strong definitions are an error. Everything works. Then a C++ program fails to link, and the error is <code>multiple definition of '_Z10cxx_inlinei'</code> &mdash; between two objects that both came from clang, on the same machine, from the same source pattern. Your symbol resolution is not wrong. What is it missing, and what is the smallest change that makes it correct without regressing the cases that already work?</p>
                <div class="quiz" id="quiz-obj-comdat-group-2">
                    <button class="quiz-option" data-correct="true" data-explain="What is missing is a third binding category, and the reason it cannot be expressed with the two you have is the format's, not yours. A group member is not a normal definition and it is not a plain weak definition either: it is a definition that is additionally discardable, and the discardability is recorded on a section, not on a symbol. So the smallest correct change has two parts, and the second is easy to forget. First, group members must be resolved as weak, which stops the duplicate-definition error. Second -- and this is the part that a purely symbol-level fix misses -- the losing member's section must actually be removed from the output, together with its relocations and its symbol. Resolve the conflict but keep the bytes and you have produced a binary with dead code in it, which links and runs correctly and is quietly larger than it needs to be; that is a real and observable regression, not a cosmetic one, and it is exactly what happens if you implement only the first half. Why the second part cannot be skipped: the group is keyed on the symbol name, so you can find the winner, but only the section structure tells you which bytes belonged to the loser. And why the three formats need three implementations rather than one flag: ELF names the membership in an SHT_GROUP section and marks the member with G, so you walk a table; COFF puts a 0x1000 bit in the section header and the policy and checksum in a symbol-table aux record, so you walk the section table and then consult a different table for the policy; Mach-O has no section mechanism at all, so there is nothing to remove and the correct behaviour is to resolve the symbol and leave the bytes. One flag cannot express 'discard this section', 'discard this section unless an identical one exists', and 'there is no section to discard'." onclick="checkQuiz('obj-comdat-group-2', this)">You are missing a third binding category, and it is not a symbol-table concept &mdash; the discardability is recorded on a <em>section</em>. So the fix is two-part: resolve group members as weak, <em>and</em> discard the losing member's section along with its relocations and symbol. Skip the second half and you link cleanly but ship dead bytes. And the three formats need three separate implementations of the second half: ELF walks an <code>SHT_GROUP</code> table, COFF checks a <code>0x1000</code> bit in the section header and reads the policy from the symbol table's aux record, and Mach-O has nothing to discard at all</button>
                    <button class="quiz-option" data-correct="false" data-explain="The diagnosis is right and the fix is the right shape, but the framing of why it never failed locally is wrong in a way that leads to a bad test design. The claim that the pass only fails when a member's dependency comes earlier in the archive is not what distinguishes the working cases from the failing one, and building a test that only checks that condition will not find the bug. What actually distinguishes them is whether a single forward pass happens to reach each member after every member that needs it. Those two conditions coincide often, which is why the intuition feels right, but they are not the same condition and they come apart in exactly the case that breaks. Consider a three-member chain in the order l2, l3, l1. A forward pass reaches l1 last, l1 wants level2, and l2 is already behind the cursor -- so the dependency points backwards in the array, which is the case the proposed test would exercise. Now consider the order l3, l2, l1: the pass reaches l1, l1 wants level2 which was passed, fails again. Here l3 is needed by l2 and precedes it, and the proposed test would call that a passing case, so the test would pass on an input that breaks the linker. The test needs to be a permutation sweep, generating several orderings of a small dependency chain and requiring the linker to succeed on all of them, because the property under test is not about the direction of any one dependency but about whether the algorithm reaches a fixed point at all." onclick="checkQuiz('obj-comdat-group-2', this)">Treat group members as weak, so the two definitions resolve instead of colliding, and pick whichever body arrives first. The three formats are tricky rather than fundamentally different: ELF has a group section, COFF has a COMDAT flag plus a selection byte, and Mach-O uses a symbol bit, but all three reduce to &quot;resolve it as weak and move on&quot; once the symbol table has told you which definition is in a group</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when two definitions of a symbol are allowed to coexist, ask separately <em>which one wins</em> and <em>what happens to the loser</em>. The format records the first explicitly and the second structurally &mdash; and the second is where dead code comes from.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the clearest case in the course of an essential idea being reinvented independently, and it is worth connecting to <a href="/courses/obj/lessons/obj-triangulate">One Source, Three Formats</a>, which proposed the triangulation test: compile the same thing three ways and see what stays constant, because the constants are the essentials and the differences are the accidents. <strong>This is that test returning a positive result.</strong> The constant is: two objects that each define the same external symbol, where the language has promised the definitions are identical. The accidents are: a group section, a section flag, a symbol bit, three different names for the concept, and a checksum that only one of the three formats bothers with.</p>
                <p>The connection to <a href="/courses/obj/lessons/obj-weak-undef">the weak-symbol concept</a> is immediate and load-bearing. <strong>ELF implements a COMDAT group by demoting the symbol to <code>STB_WEAK</code> and putting the body in its own section</strong> &mdash; so the group is weak symbols plus a discard boundary, and Mach-O's <code>N_WEAK_DEF</code> is the same answer with the boundary omitted. The two concepts are one mechanism at two levels, and the reason they are separate concepts is that the boundary has consequences: a weak definition that loses is <em>re-pointed</em>, and a group member that loses is <em>removed</em>. <a href="/courses/obj/lessons/obj-weak-undef">That concept</a> measures the difference, including the fact that GNU ld leaves the losing weak body in the section as unowned dead bytes.</p>
                <p>The COFF checksum connects to <a href="/courses/pe">the PE course</a> and to a security property rather than a correctness one. <strong>A COMDAT section that is silently discarded when it should have been kept is a compiler-emitted miscompilation with no diagnostic</strong> &mdash; and the <a href="/courses/coff/lessons/coff-comdat-linking">COFF course reproduced exactly that</a>, with a function returning the wrong constant and no warning. The general lesson is one the formats teach repeatedly: <strong>an advisory integrity field is worse than none, because it converts an undetectable failure into a detectable one that the toolchain then chooses to ignore.</strong> That is the same shape as the ELF <code>TYPE</code> flag's overflow check, which exists so a linker <em>can</em> fail loudly, and the same shape as the JVM attribute mechanism's design rule of letting a reader skip rather than misread.</p>
                <p>The C-versus-C++ finding connects back to <a href="/courses/obj/lessons/obj-bss-common">COMMON and the ABI Break</a>, and the connection is sharper than it first appears. <strong>Both mechanisms exist because C lets a symbol's storage or definition be decided somewhere other than where it is written</strong> &mdash; COMMON because the definition might be in another object, COMDAT because it might be in <em>this</em> object but also in another. <strong>And in both cases the C language specified the rule and the object format had to invent a way to record it.</strong> The COMMON story ended in the GCC 9 to 10 break, because the format recorded a decision each side made locally and nothing said the two decisions were incompatible. COMDAT's story ended better, because the C++ standard said the definitions are identical &mdash; so the format could record the promise and the linker could act on it. <strong>Same problem, opposite outcomes, and the difference was whether the language had done its job first.</strong> That is a genuinely useful thing to carry out of a format course and into any design work.</p>
                <p>And the archive concept that follows is the same question one level up. <strong>A group answers &ldquo;which of these two definitions survives&rdquo;; an archive answers &ldquo;which of these three objects is loaded at all.&rdquo;</strong> Both are selection decisions, both are made by the linker, and both have a failure mode that looks like success: a group that discards the wrong copy, and an archive that pulls in a member nothing needed. <a href="/courses/obj/lessons/obj-archives">The next concept</a> is about the second, and the two make a natural pair because they share the property that <strong>the default is conservative and the linker is the only thing that can be smarter</strong> &mdash; and the format's job is to give it the information to be smarter with.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/obj/lessons/obj-pic">Previous: Position Independence</a></span>
                <span>Next: The Archive</span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
