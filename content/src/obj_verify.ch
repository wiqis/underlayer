// Object Files — Module 5: Emitting One
// Concept: the oracle loop. Three independent readers, byte-exact comparison,
// and how to know your emitter is wrong rather than the tool.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_obj_verify() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Proving Your Object File Is Right — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson obj-lesson">
            <a href="/courses/obj" class="back-link">Back to course</a>
            <h1>Proving Your Object File Is Right</h1>
            <div class="lesson-meta">18 min &middot; Module 5: Emitting One &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Here is the most uncomfortable fact in the previous concept, stated plainly: <strong>while building <code>emit_elf.py</code>, four bugs produced object files that every available tool read without a single warning.</strong></p>
                <div class="hex-dump">
                    <pre>  bug            readelf   llvm-readobj   llvm-objdump   ld    result
  -------------   -------   -----------   ------------   -----   --------------
  e_shoff wrong   ERROR     clean         clean         fail   loud, lucky
  sh_link/info    warns     clean         clean         ok     SYMBOLS EMPTY
  symbols overlap clean     clean         clean         ok     WRONG NUMBER
  add before call clean     clean         clean         ok     WRONG NUMBER
</pre>
                </div>
                <p>Read the last two rows. <code>readelf</code>, <code>llvm-readobj-21</code> and <code>llvm-objdump-21</code> all agreed completely with a file that computed the wrong answer. <strong>Agreement between readers is not evidence of correctness, because readers are being asked the wrong question.</strong> They are being asked &ldquo;is this file well formed?&rdquo; and the answer was yes. The question that mattered was &ldquo;does this file mean what I meant?&rdquo; and no reader was asked it, because no reader can be &mdash; a reader has no access to the intent.</p>
                <p>So this concept is about the difference, and about the one technique that closes it. <code>crosscheck.py</code> in this course's <code>assets/samples/</code> runs 95 checks over the specimens in this directory, and it deliberately uses three different kinds of evidence rather than three copies of the same one.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three tiers of evidence, ordered by how much they can catch and by how much they cost to set up. The ordering is the important part, because the cheapest tier catches the most.</p>
                <div class="formula">
  TIER 3   the file disagrees with ITSELF
           Two places in one object record the same fact.
           COFF puts a section's size and relocation count
           in the section header AND in the symbol table's
           auxiliary record.  ELF's symtab sh_info must be
           the index of its first GLOBAL symbol, and every
           entry before it must be LOCAL.

           Cheapest.  Catches the most.  Needs no second
           implementation and no external tool.

  TIER 2   your reader vs an UNRELATED toolchain
           Your decoder, written from the specification,
           diffed field by field against readelf and
           llvm-readobj-21.  Two implementations that
           share no code.

           Medium cost.  Catches a misreading of the spec.

  TIER 1   your EMITTER vs a reference producer
           Byte-compare your output against a file clang
           produced from equivalent source.

           Expensive.  Catches the least, because a
           reference producer and you will disagree about
           section ordering, padding and naming for
           reasons that are not bugs.
</div>
                <p><strong>Note the counter-intuitive ordering: the strongest evidence is the cheapest.</strong> That is because Tier 3 needs no second opinion at all &mdash; it is a self-consistency check, and an object file is unusually rich in redundant facts. The COFF case is the clearest: a reader that mis-parses the auxiliary records <em>disagrees with itself</em>, because the same section's size appears in the section header and in a symbol table entry, and they no longer match. That is a bug caught with no oracle at all.</p>
                <p>And the reason Tier 1 is last despite being the most obvious choice: <strong>a reference producer is not an oracle for your file, it is an oracle for <em>a</em> file.</strong> It will differ from yours in section ordering, in how much padding it inserts, in whether it emits <code>.comment</code>, in the order of the symbol table &mdash; and every one of those differences is a legitimate choice. Diffing the whole file gives you a hundred differences of which perhaps one is a bug, which is a bad signal-to-noise ratio and a test that everyone learns to ignore.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Tier 3, and why COFF is the best teacher</h3>
                <p><code>demo_coff.o</code> has <code>PointerToSymbolTable = 0x211</code> and <code>NumberOfSymbols = 26</code>. The records are 18 bytes each, so the string table begins at <code>0x211 + 26*18 = 0x3e5</code>. Now decode all 26 and count how many are symbols:</p>
                <div class="hex-dump">
                    <pre>  26 records.  14 are symbols.  12 are AUXILIARY.

  A reader that ignores NumberOfAuxSymbols prints 12
  nonsense symbols, each with a garbage Value such as
  0x672d789d, and NOTHING LOOKS WRONG.

  And the check that catches it is one line, because
  every aux record carries facts the section header
  also carries:

  $ python3 crosscheck.py
    ok  aux record for .text: Length 62 == section RawDataSize 62
    ok  aux record for .text: RelocationCount 4 == header 4
    ok  aux record for .data: Length 16 == section RawDataSize 16
    ok  aux record for .bss:  Length 4  == section RawDataSize 4
    ok  aux record for .rdata: Length 6 == section RawDataSize 6
    ok  aux record for .rdata: Length 3 == section RawDataSize 3
    ok  every one of the 7 sections has a section-definition aux record
</pre>
                </div>
                <p><strong>That is the entire technique, and it is worth noticing that the seven sections include two both named <code>.rdata</code>.</strong> So the check cannot be keyed by name &mdash; it must be keyed by index, which is itself a lesson from <a href="/courses/obj/lessons/obj-sections">Sections, Compared</a>. A validator that builds a dictionary from section name to section will silently lose one of the two <code>.rdata</code> sections, and the loss will not be an error.</p>
                <p>ELF offers a different flavour of the same thing, and it caught a real mistake while this course was being written. The spec says a symbol table's <code>sh_info</code> is the index of the first symbol whose binding is not <code>STB_LOCAL</code>, and that all locals must precede globals. So a validator can check:</p>
                <div class="hex-dump">
                    <pre>  $ python3 crosscheck.py
    ok  symtab sh_info == index of first GLOBAL symbol (4)
    ok  every symbol before sh_info is LOCAL, as the rule requires
</pre>
                </div>
                <p>Both are Tier 3: <strong>no second implementation, no external tool, just the specification's own internal consistency requirement, checked mechanically.</strong> And the ELF relocation sections give a third: <code>sh_link</code> must be a <code>SHT_SYMTAB</code> and <code>sh_info</code> must be a valid section index. <strong>Getting those two backwards &mdash; which is exactly bug 2 in the previous concept &mdash; is caught by a check that costs one line and needs no oracle.</strong></p>

                <h3>Tier 2, and the question of what &ldquo;independent&rdquo; means</h3>
                <p>The interesting problem with Tier 2 is that <em>independent</em> is doing more work than it appears. On this machine there are two genuinely separate ELF toolchains &mdash; LLVM 21 and binutils &mdash; and for COFF there are two as well. For Mach-O there is one, because binutils refuses the format. <strong>That asymmetry is a fact about the world and it is worth stating rather than hiding, because it changes how much a Mach-O claim is worth.</strong></p>
                <div class="formula">
  claim about ELF or COFF   two toolchains + hand-decoding
                            + a decoder written from the spec
                            = strong

  claim about Mach-O        one toolchain + hand-decoding
                            + a decoder written from the spec
                            = weaker, and the course says so
</div>
                <p>And here is the sharpest point in the concept, which is about the failure mode of Tier 2 itself. <strong>A reader written from a specification and a reader written from the same specification share their author's misconceptions.</strong> If you misread the <a href="/courses/obj/lessons/obj-relocations">Mach-O <code>r_info</code> bit layout</a> in your decoder, and you also misread it when you wrote the check, the two will agree perfectly and both will be wrong. Tier 2 only catches what the two implementations got <em>independently</em> right or independently wrong by different routes.</p>
                <p>Which is why the strongest form of the check is a <strong>byte-exact structural diff over every field, compared as sorted sets rather than in order</strong>. The diff that found a real problem in this course was not a value mismatch; it was that <code>readelf</code> prints a section symbol's target as the section's <em>name</em> while the file stores <code>st_name = 0</code> and the reader has to substitute one. That is a difference in <em>presentation</em>, discovered only by comparing everything, and it is exactly the kind of thing a spot check of &ldquo;does the symbol name look right?&rdquo; would have missed.</p>

                <h3>The oracle that caught the bugs the tools missed</h3>
                <p>So what actually caught bug 3, the overlapping symbols? Not a reader. <strong>The program's output.</strong> The expected answer was 41 and the program printed 389845008, and no tool in the world could have told you why &mdash; because the file was legal, the toolchain was correct, and the bug was in a description of intent that existed nowhere except in the emitter's head.</p>
                <div class="formula">
  the loop that works, in order:

  1  Tier 3 on every file, every build.
     Cheap.  Catches mis-parsed tables.

  2  Tier 2 against a toolchain you did not write.
     Catches a misread specification.

  3  EXECUTE, and compare against a value you computed
     by hand BEFORE running.
     Catches everything else, and it is the only tier
     that can catch a wrong intention.
</div>
                <p><strong>And the ordering of step 3 is not incidental.</strong> If you run the program first and then work out what it should have printed, you will rationalise whatever it printed. If you write down <code>start(5) = helper(5) + 1 = 11</code> and <code>answer = 41</code> before linking, then a mismatch is unambiguous &mdash; and in this course it was unambiguous immediately, which is how the overlapping symbols were found in minutes rather than days.</p>
                <div class="callout callout-tip">
                    <strong>The general form of this is worth carrying outside the course.</strong> A verifier that shares an assumption with the thing it verifies is not a verifier. Three tools agreeing means three tools answered the question you asked; it does not mean the question was the right one. <strong>The tiers are ordered by independence, not by how many tools were run</strong>, and the only tier that can catch an error of intention is the one where you state your intention somewhere the tools cannot see it &mdash; a test, a hand calculation, a comment you then check against reality. That is the whole discipline, and it is the same one the course has applied to itself: the <code>-0x4</code> claim, the Mach-O <code>linkonce</code> claim, and the string-table claim in <a href="/courses/obj/lessons/obj-strings">Where Names Live</a> were all found by building a specimen and measuring, not by reading a specification and believing it.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What the harness actually reports, and what each block of it is for:</p>
                <div class="hex-dump">
                    <pre>  $ python3 crosscheck.py
  ========================================================================
  Object Files -- crosscheck
  Three tiers: independent decoder, external toolchain, and the
  file's own internal invariants. Tier 3 catches the most.
  ========================================================================

  demo_elf.o  (ELF64 x86-64 relocatable)
    ok    e_type == 1 (ET_REL) -- this is a relocatable file
    ok    e_phnum == 0 -- no program headers, and that is not an omission
    ok    [3] .rela.text sh_link points at the symtab
    ok    [3] .rela.text sh_info is a valid target section (.text)
    ok    [5] .rela.data sh_link points at the symtab
    ok    [5] .rela.data sh_info is a valid target section (.data)
    ok    [12] .rela.eh_frame sh_link points at the symtab
    ok    [12] .rela.eh_frame sh_info is a valid target section (.eh_frame)
    ok    symtab sh_info == index of first GLOBAL symbol (4)
    ok    every symbol before sh_info is LOCAL, as the rule requires
    ok    TIER 2: all 8 relocations match readelf exactly
    ok    .text relocations are the ones the course claims
    ok    section names are exactly the ones the course lists
  ...
  hand.o  (emitted by emit_elf.py, no library involved)
    ok    e_type == ET_REL
    ok    e_phnum == 0
    ok    exactly 8 section headers, as emit_elf.py says
    ok    section 5 is .symtab and section 6 is .strtab
    ok    the five symbols are the ones emit_elf.py declares
    ok    answer (4 bytes at 0) does not overlap answer_ptr at 4
    ok    .data is big enough for both
    ok    TIER 2: a real linker accepts it (ld -r exit 0)
  ...
  ========================================================================
  95 passed, 0 failed
  ========================================================================
</pre>
                </div>
                <p>Two lines in that output are worth reading twice, because they are the harness doing the thing no single tool does.</p>
                <p><strong>&ldquo;answer (4 bytes at 0) does not overlap answer_ptr at 4&rdquo; is a Tier 3 check on the hand-built file</strong>, and it exists precisely because the overlapping version of that file was produced and shipped by mistake. It is not a specification requirement &mdash; ELF permits overlap &mdash; it is a check against <em>this emitter's intent</em>, written after the bug. <strong>That is the honest shape of the technique: the checks you end up with are the ones your past mistakes demanded, and the harness is a list of scar tissue.</strong></p>
                <p><strong>&ldquo;TIER 2: a real linker accepts it (ld -r exit 0)&rdquo; is the only check that involves a different program entirely</strong>, and it is one line. It is also the only check that would have caught bug 1 &mdash; the wrong <code>e_shoff</code> &mdash; instantly, because GNU ld would have refused the file rather than trying to interpret it. Which raises the obvious question: why not just always run the linker?</p>
                <p>Because <strong>a linker accepts plenty it should not, and refuses some it could cope with.</strong> It accepted the file with overlapping symbols. It accepted the file with a <code>mov</code> whose add was in the wrong place. It did not complain about a <code>.text</code> section containing something that is not instructions. <strong>The linker is a consumer with needs, not a validator</strong>, and treating its silence as approval is the same mistake as treating <code>readelf</code>'s silence as approval &mdash; one tier up.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ cd courses/obj/assets/samples
$ python3 crosscheck.py            # 95 checks
$ python3 crosscheck.py -v         # show the diffs
$ python3 ardec.py libdemo.a
$ sh build_samples.sh              # rebuild every specimen</code></pre>
                <ul>
                    <li><strong>Break something Tier 3 and confirm it is caught.</strong> Take a copy of <code>demo_elf.o</code> and swap <code>sh_link</code> and <code>sh_info</code> on <code>.rela.text</code>. <strong>Run <code>crosscheck.py</code> and count how many checks fail</strong> &mdash; the two internal-invariant checks should fire immediately, before any external tool is consulted. Then run <code>readelf -rW</code> on it and note what it says. <strong>The order of the failure is the lesson: the cheapest oracle speaks first.</strong></li>
                    <li><strong>Break something Tier 3 does <em>not</em> cover, and find out how long it takes to notice.</strong> Overlap two symbols in <code>demo_elf.o</code> &mdash; set <code>answer</code>'s <code>st_value</code> to 0 and <code>answer_ptr</code>'s to 0 as well. <strong>Every Tier 3 check still passes and <code>readelf</code> is silent.</strong> Now find out what it takes to notice: linking and running, and comparing against a hand-computed expected value. <strong>Write down how many steps that was, because the answer is the argument for the third tier.</strong></li>
                    <li><strong>Write a Tier 2 check for a format the course does not cover, and feel the independence problem.</strong> Pick a fourth object format from the <a href="/courses/wasm">WebAssembly</a> or <a href="/courses/jvm">JVM</a> courses, write fifty lines of decoder from its specification, and diff it against <code>wasm-objdump</code> or <code>javap</code>. <strong>Then deliberately introduce a misreading into your own decoder that the specification's wording genuinely permits, and check whether the diff catches it.</strong> If it does not &mdash; and for an ambiguous point it may not &mdash; you have just measured the real limit of Tier 2, which is more instructive than any amount of theory about it.</li>
                    <li><strong>Add a Tier 3 check to the harness for a fact nothing currently checks.</strong> Candidates: every section's <code>sh_addralign</code> is a power of two; every <code>sh_entsize</code> is a multiple of the structure size; no symbol's <code>st_value</code> exceeds its section's <code>sh_size</code>; every relocation's offset is inside the section its <code>sh_info</code> names. <strong>Pick one, add it, and then try to find a real object that violates it.</strong> If you find one, you have learned something about the format that no specification states.</li>
                    <li><strong>Measure the byte-reproducibility of the specimens, because the whole course rests on it.</strong> <code>sh build_samples.sh</code> rebuilds everything and <code>cmp</code>s the three-format specimen against the staged copy. <strong>It currently reports IDENTICAL.</strong> Then change one compiler flag, rebuild, and see which specimens change. <strong>The ones that change are the ones whose recorded byte values you must re-verify, and knowing which is the difference between updating a course correctly and quietly making it wrong.</strong></li>
                    <li><strong>Apply the three tiers to something that is not a binary format.</strong> Pick a structured text format you consume &mdash; a config file, a lockfile, a CSV export &mdash; and ask: what are its redundant facts, what is my independent second reader, and what is the executable test? <strong>Most text formats have no Tier 3 at all</strong>, which is why they are so easy to misparse, and noticing that is the general lesson rather than a fact about object files.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: you have written a decoder for an object format from its specification, and a second tool on your machine also reads the format. Both agree on every field of all 400 files in your corpus. Your decoder is nonetheless wrong about one field, in a way that makes it report a plausible but incorrect value. How is that possible, and what would have caught it?</p>
                <div class="quiz" id="quiz-obj-verify-1">
                    <button class="quiz-option" data-correct="true" data-explain="It is possible because two readers of the same specification share their author's reading of it, and agreement between them is evidence about the files, not about the reading. The misreading is a property of the interpretation, so it is reproduced identically in both implementations and cancels out of the comparison. The comparison can only catch a difference, and this is not a difference. Note carefully what the agreement does establish: the two implementations are not making independent arithmetic slips, so the files are at least being read consistently, and the corpus is at least self-coherently described. That is worth having and it is much weaker than it looks. What would have caught it comes from a different kind of evidence entirely. A Tier 3 check would, if the specification has a redundant fact: some object formats record the same quantity in two places, and a misreading that makes the two disagree is caught by the file disagreeing with itself. This is the case that works, and it is why the COFF auxiliary-record check in this course's harness is the most valuable line in it. Failing that, a third independent source would: a second toolchain written by people who had not read your reading, or a specification erratum or a maintainer's mailing list, or a test that asserts a value you derived by some route other than your decoder. What would not have caught it is more of the same kind: a fourth tool, or a second pass over the same specification, or reading your own decoder more carefully. The general habit is to ask what class of error you are hunting before choosing an oracle, because the number of oracles you run is not the property that matters." onclick="checkQuiz('obj-verify-1', this)">Because both readers share <em>your reading of the specification</em>, and a misreading is a property of the interpretation rather than of the file &mdash; so it is reproduced identically in both and cancels out of the comparison. Agreement is evidence about the <em>files</em>, not about the <em>reading</em>. What catches it is a different class of evidence: <strong>a Tier 3 check against a fact the file records twice</strong> (as COFF's aux records and ELF's <code>sh_info</code> allow), or a third independent source &mdash; another toolchain, a specification erratum, or a test whose expected value you derived by some route other than your own decoder</button>
                    <button class="quiz-option" data-correct="false" data-explain="The conclusion is right and the second half of the reasoning is right, but the diagnosis of why the agreement is uninformative is wrong, and it is wrong in a way that points at the wrong remedy. It is not that both readers are 'likely to make the same misreading' as a matter of luck. They are reading the same document, and a specification resolves most ambiguities one way; two competent readers who both understood it correctly will agree, and two who both misunderstood it the same way will also agree. The agreement carries no information about which happened, and that is the real limitation. The proposed remedy is also misdirected. Adding more tools of the same kind does not help even in principle, because the tools are not the source of the error -- the shared reading is. What helps is a source of evidence whose failure modes are different from yours. A Tier 3 check is the strongest available, because it uses a redundancy inside the file itself and your misreading of it would have to coincide with a second misreading of the same passage for the check to pass falsely. Failing that, the value has to come from outside the format's documentation entirely: an executable test whose expected value you computed by hand, or a second toolchain from a different project. The general lesson is about independence of failure modes rather than about counting implementations, and the distinction is the difference between an oracle and a colleague who read the same book." onclick="checkQuiz('obj-verify-1', this)">Because two implementations written from the same specification are likely to make the same misreading of an ambiguous point, so their agreement is not independent evidence. <strong>Adding a third and fourth tool would not help either</strong>, since all of them read the same document. What catches it is a Tier 3 check against a redundant fact in the file, or a specification erratum</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You maintain a tool that reads a binary format, and a user reports that it misparses one file out of ten thousand. You have checked the file with your own reader, with the reference implementation, and with a second third-party library &mdash; all three agree, field for field. The file is well formed by every tool available. Given the tiers in this concept, what is the most likely explanation, what is the first thing you should do, and what is the thing you are most likely to do instead that will waste a day?</p>
                <div class="quiz" id="quiz-obj-verify-2">
                    <button class="quiz-option" data-correct="true" data-explain="The most likely explanation is that your reader and both libraries share a misreading, or that the file exercises a case the specification leaves open and all three resolved it the same way, or some combination. Agreement across three implementations narrows the fault to their common assumptions rather than to any one of them, and the user is the only source of information you do not already share with them. So the first thing to do is get the bytes rather than the conclusions: ask for the failing file, or failing that the exact byte offset and the values all three tools printed at it, and work out what the specification permits there. The offset and the reported values are often enough, because a value that all three agree on and that is nonetheless wrong is a strong hint that the field's meaning is being misread rather than misparsed. Then the productive move is a Tier 3 check: look for a fact this format records twice, in the file or in a sibling structure, and see whether the two copies disagree at exactly this offset. That is a genuinely independent test because it uses a redundancy your misreading would have had to be blind to in two places at once. The thing you are most likely to do instead is add a fourth reader, or re-read the specification more carefully, or instrument your own decoder and confirm it is behaving as written. All three confirm that your reading is self-consistent, which was never in doubt. The tell is that all of them feel productive and none of them can fail, and an investigation where nothing can fail is not an investigation." onclick="checkQuiz('obj-verify-2', this)">The three implementations share a misreading, so their agreement is evidence about the files and not about the reading &mdash; and the user is your only source you do not already share assumptions with. <strong>Get the bytes, not the conclusions: ask for the failing file or the exact offset and the values all three printed there.</strong> Then look for a fact the format records twice and check whether the two copies disagree at that offset. <strong>What you will waste a day on is adding a fourth reader or re-reading your own decoder more carefully</strong> &mdash; both only confirm your reading is self-consistent, which was never in doubt</button>
                    <button class="quiz-option" data-correct="false" data-explain="The instinct to get the bytes is right and is the most important thing in this answer, but the ranking that follows is wrong, and it will send you down the most expensive road available. It puts a Tier 3 check second, behind looking for an erratum. An erratum is a search through someone else's documentation for an admission of a mistake, and the odds are strongly against one existing: the specification is a description of a format, not a record of the mistakes made while writing readers, and a field that all three implementations read the same way is more likely to be genuinely unambiguous than to be a documented-but-wrong reading. Worse, the search has no stopping condition -- you can spend days reading mailing lists and finding nothing, and then you are back where you started with less time. A Tier 3 check is better than that for three reasons. It is cheap, because it is a comparison of two numbers you have already decoded. It is decisive, because it uses a redundancy inside the file, and your misreading would have to be wrong about the same field in two structurally different places for the check to pass falsely. And it is bounded: you either find the two copies disagreeing or you do not, and both outcomes tell you something. The erratum search is worth doing if the Tier 3 check comes back clean, but it is a fallback for when the cheap decisive test has already failed, not the thing to try second. The right order is bytes, then self-consistency, then everything else." onclick="checkQuiz('obj-verify-2', this)">The three implementations are probably all wrong in the same way, so the first move is to obtain the failing file and the exact byte offset rather than any further tool comparison. <strong>The second move is to search the specification's errata and the format's mailing list for a known misreading.</strong> The thing most likely to waste a day is writing a fourth independent reader from scratch and diffing that, since the fourth reader will share the same assumptions as the first three</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when every tool agrees and the answer is wrong, the tools are not the variable. Go get the bytes, then look for a fact the format records twice, and treat any investigation in which nothing can fail as a signal that you are in the wrong place.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the last concept of the course, and it is the one that makes the other seventeen safe to trust. <strong>Everything asserted in this course was measured on committed, byte-reproducible specimens, and the three claims that were wrong &mdash; the addend's location, Mach-O's <code>linkonce</code> mechanism, and ELF's two string tables &mdash; were all wrong in the same way: they were plausible readings of a specification that had been consulted rather than a file that had been opened.</strong> That is the argument for the whole method, stated as three corrections.</p>
                <p>The connection to <a href="/courses/obj/lessons/obj-emit">Writing One From Scratch</a> is direct, and the four bugs are the evidence. <strong>Every one of them got past every reader</strong>, and two of them produced a program that ran and printed a plausible wrong number. <a href="/courses/obj/lessons/obj-arch-table">The encodings concept</a> adds the fifth that did not happen &mdash; a relocation offset one byte off the field &mdash; which on x86-64 produces a binary that links and jumps slightly wrong, because a fixed four-byte field gives nothing to signal the mistake. <strong>Between the two concepts is the whole argument for a verification discipline: agreement is cheap, and it is cheap precisely because readers are answering &ldquo;is this well formed?&rdquo; rather than &ldquo;is this what you meant?&rdquo;</strong></p>
                <p>The connection to <a href="/courses/obj/lessons/obj-archives">The archive</a> is a Tier 3 opportunity that the format hands you for free, and it is the clearest one in the course. <strong>An archive's index says which member defines a symbol, and each member's own symbol table independently says what it defines.</strong> Two records of the same fact, in two different files, which is exactly the shape a self-consistency check needs &mdash; and the course uses it, cross-checking all four index entries against the members they point at. This is also where the COFF course's <code>ar_decode.py</code> and this course's version of it are the same idea applied twice, which is the <a href="/courses/obj/lessons/obj-triangulate">triangulation</a> principle at the level of tooling rather than of formats.</p>
                <p>The COFF connection is the strongest, because COFF is where redundancy is densest. <strong>The same facts appear in the section header and the auxiliary record; the same class of data appears in the symbol table and the string table; the section name appears both inline and as an escape into that table.</strong> That density is not a design virtue &mdash; it is the residue of a format that grew by accretion, and the <a href="/courses/coff">COFF course</a> documents three places where the specification and the actual emitters disagree. <strong>But the accidents of a format are often more useful than its intentions, because a redundant fact is a free consistency check that nobody had to design.</strong> The best validation harnesses are built out of the parts of a format nobody chose on purpose.</p>
                <p>And the connection outward, to the whole course collection, is the method rather than the format. <strong>Every course here claims the same thing in a different costume: that a claim is worth teaching once two implementations that share no code agree on it.</strong> The <a href="/courses/jvm">JVM course</a> has a <code>crosscheck.py</code>, the <a href="/courses/coff">COFF course</a> has one, the <a href="/courses/wasm">WebAssembly course</a> has one, and this course has one. They are not identical, and they should not be: a harness is specific to what a format makes checkable. <strong>What they share is the tiering, and the tiering is the transferable part.</strong> Run the self-consistency checks first because they are cheapest and catch the most. Diff against an unrelated toolchain second, because that catches a misreading of the specification. Execute against a hand-computed expectation last, because that is the only tier that can catch an error of intention &mdash; and an error of intention is the only kind that no amount of reading will ever find.</p>
                <div class="callout callout-tip">
                    <strong>What the course leaves you with, stated as one sentence.</strong> You can now read an ELF, COFF or Mach-O object file with nothing but the bytes and these eighteen pages; you know that every field in it exists because a linker needs it for a specific reason; and you can write one &mdash; a small one, byte by byte, with no library &mdash; that a production linker accepts and that computes the right answer. <strong>Those three sentences are the whole course, and the third one is what the first two are for.</strong> The next link in the chain is the linker itself, and you now have everything it needs to be written from scratch.
                </div>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/obj/lessons/obj-arch-table">Previous: The Encodings That Set Relocation Size</a></span>
                <span>Next: Module 5 complete &mdash; the object files course is finished</span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
