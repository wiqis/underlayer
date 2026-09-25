// COFF Course — Module 4: The Link
// Concept: COMDAT deduplication observed working — two identical copies in two
// objects, one of them discarded, with the reason visible in the bytes.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_coff_comdat_linking() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("COMDAT in the Linker — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson coff-lesson">
            <a href="/courses/coff" class="back-link">Back to course</a>
            <h1>COMDAT in the Linker</h1>
            <div class="lesson-meta">21 min &middot; Module 4: The Link &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Module 3 decoded the COMDAT mechanism: a section flag, a selection kind, a checksum in an auxiliary symbol record. That is the vocabulary. What it did not do is show it <em>deciding anything</em>, because a mechanism described in a header is a mechanism you have only read about.</p>
                <p>So here is the smallest possible instance of the problem COMDAT exists to solve, and the whole thing watched end to end. Two C++ files, each with the same <code>inline</code> function. Each compiler emits its own copy into its own object. The two copies are byte-for-byte identical. If both were linked in, the binary would contain the same function twice under the same name, and every <code>call</code> would go to one of them.</p>
                <p>This is not a contrived situation. It is what happens in any C++ program where two translation units both include a header defining an inline function, which is most of them. The linker resolves it silently, correctly, and without leaving a trace in the output file &mdash; which is exactly why it is worth deliberately creating the situation and watching it happen.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>A COMDAT group is a section plus a rule for what "the same group" means. Three ingredients, all in the object:</p>
                <ul>
                    <li><strong>A section flagged <code>IMAGE_SCN_LNK_COMDAT</code></strong> &mdash; the linker's permission to discard this section if an equivalent one already exists.</li>
                    <li><strong>An auxiliary symbol record with a selection</strong> &mdash; the rule for equivalence. <code>IMAGE_COMDAT_SELECTION_ANY</code> means "identical contents, name irrelevant"; <code>EXACT_MATCH</code> means "identical contents <em>and</em> the same name"; <code>SAME_SIZE</code> means "same size, contents ignored"; <code>NONE</code> means the section is not a COMDAT at all.</li>
                    <li><strong>A checksum</strong> &mdash; a hash of the section's contents, so the linker can answer "are these two really identical" without a full comparison.</li>
                </ul>
                <p>And the algorithm is short:</p>
                <div class="formula">
for each section with LNK_COMDAT set:
    for each group already accepted by the linker:
        if same selection kind and checksums match and the
           selection's extra condition holds:
            discard this section
            point its symbols at the accepted one
            next section
    accept this section as a new group

for each remaining symbol:
    if a COMDAT symbol and an accepted group has the same name:
        resolve the reference to the accepted group
    else:
        resolve normally, and a duplicate definition is an error
</div>
                <p>Two features of that sketch are the whole design. <strong>The linker keeps the first and discards the rest</strong>, so the winner depends on link order &mdash; which is why the choice must be content-based and not position-based, or a program would behave differently depending on the order a build system happened to pass its files. And <strong>discarding is safe only because the survivor is byte-identical</strong>, so every relocation that pointed into the discarded copy can be redirected to the kept one. The discarded section is not thrown away, it is <em>merged</em>.</p>
                <div class="callout callout-warn">
                    <strong>Why the checksum is not optional.</strong> With <code>SELECTION_ANY</code> the checksum is the <em>only</em> evidence that two sections are equivalent. Get it wrong in the direction of accepting unequal sections and the linker silently produces a binary where some call sites use one function body and others use a different one &mdash; same name, same signature, different behaviour. That is a genuinely horrible bug class, and it is why this field exists rather than the linker simply comparing bytes. The failure is silent, which is the worst property a linker bug can have.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Two files. Both define the <code>inline</code> function <code>shared</code>, which returns its argument multiplied by three; each then calls it with a different constant.</p>
                <table>
                    <thead>
                        <tr><th scope="col">File</th><th scope="col">Defines</th><th scope="col">Calls it with</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>comdat_a.cpp</code></td><td><code>inline int shared(int v)</code> &mdash; the same one-line body returning <code>v * 3</code></td><td><code>use_a</code> with <code>7</code></td></tr>
                        <tr><td><code>comdat_b.cpp</code></td><td>the identical function, character for character</td><td><code>use_b</code> with <code>11</code></td></tr>
                    </tbody>
                </table>
                <p>The bodies are on one line because they are single expressions, and the point of the exercise is that they are <em>identical</em> &mdash; so any difference in the compiled output has to come from the compiler or the linker, not from the source.</p>
                <pre><code>$ clang++ --target=i686-pc-windows-msvc -c comdat_a.cpp -o comdat_a.obj
$ clang++ --target=i686-pc-windows-msvc -c comdat_b.cpp -o comdat_b.obj</code></pre>
                <h3>The two objects each carry a copy</h3>
                <p>Read the section tables with the parser shipped with this course. Each object has <strong>two</strong> <code>.text</code> sections, and they are not interchangeable:</p>
                <div class="hex-dump">
                    <pre>comdat_a.obj
  sec1  .text   rawsize=21  char=0x60500020
        IMAGE_SCN_CNT_CODE | IMAGE_SCN_MEM_EXECUTE | IMAGE_SCN_MEM_READ
  sec4  .text   rawsize=12  char=0x60501020
        IMAGE_SCN_CNT_CODE | IMAGE_SCN_LNK_COMDAT | MEM_EXECUTE | MEM_READ

comdat_b.obj
  sec1  .text   rawsize=21  char=0x60500020     (identical)
  sec4  .text   rawsize=12  char=0x60501020     (identical)
</pre>
                </div>
                <p>Two details in those characteristic values. The only difference between the two <code>.text</code> sections in the same object is the single bit <code>0x1000</code> &mdash; <code>0x60500020</code> versus <code>0x60501020</code>. Everything else, including the alignment encoded in the high bits, is the same. And the ordinary <code>.text</code> holds <code>use_a</code> or <code>use_b</code>, which are genuinely different functions and must both be kept; the COMDAT <code>.text</code> holds <code>shared</code>, which is not.</p>
                <h3>The bytes are identical</h3>
                <p>The twelve raw bytes of section 4, from both objects:</p>
                <div class="hex-dump">
                    <pre>comdat_a.obj  sec4: 55 89 e5 8b 45 08 6b 45 08 03 5d c3
comdat_b.obj  sec4: 55 89 e5 8b 45 08 6b 45 08 03 5d c3
</pre>
                </div>
                <p>Byte for byte, the same twelve. And that is exactly what <code>shared</code> compiles to, if you want to read it as x86:</p>
                <div class="hex-dump">
                    <pre>  0: 55              push  %ebp
  1: 89 e5           mov   %esp, %ebp
  3: 8b 45 08        mov   0x8(%ebp), %eax     ; eax = v
  6: 6b 45 08 03     imul  $0x3, 0x8(%ebp), %eax ; eax = v * 3
  c: 5d              pop   %ebp
  d: c3              ret
</pre>
                </div>
                <p>Twelve bytes, no relocations, no references to anything outside the function. The smallest possible COMDAT, and the easiest possible case.</p>
                <h3>The selection and the checksum</h3>
                <p>Now the auxiliary symbol records. Each object has a section symbol for its COMDAT section, and each one's auxiliary record carries the rule and the hash:</p>
                <div class="hex-dump">
                    <pre>comdat_a.obj   .text (sec4)  Number: 4  Selection: Any (0x2)  Checksum: 0xF787F24A
comdat_b.obj   .text (sec4)  Number: 4  Selection: Any (0x2)  Checksum: 0xF787F24A
</pre>
                </div>
                <p><strong>The two checksums are identical</strong>, and the reason is now visible rather than assumed: the contents are identical, the selection is <code>ANY</code>, and <code>ANY</code> means the checksum is over the content alone. A compiler could not have produced two different hashes here without a bug, and two compilers producing the <em>same</em> hash on different <em>different</em> contents would be a hash collision &mdash; which is why the checksum algorithm has to be good, because the linker's correctness depends on it.</p>
                <p>Also note <code>Selection: Any</code> rather than <code>Exact Match</code>. <code>ANY</code> ignores the section's <em>name</em>, which matters here: the COMDAT group is named by the <em>symbol</em> <code>?shared@@YAHH@Z</code>, not by the section, and the section is just called <code>.text</code> like the non-COMDAT one. If the rule had been <code>EXACT_MATCH</code> the two sections would still qualify &mdash; they have the same name &mdash; but <code>ANY</code> is what lets a compiler put every COMDAT function into a plain <code>.text</code> section instead of inventing a name per function.</p>
                <h3>The link, and the evidence</h3>
                <pre><code>$ ld --oformat pei-i386 -m i386pe comdat_a.obj comdat_b.obj \
      -o comdat_linked.exe --entry use_a -Map comdat_linked.map
$ grep -A6 'Discarded input' comdat_linked.map
 .debug$S       0x00000000       0x5c comdat_a.obj
 .llvm_addrsig  0x00000000        0x1 comdat_a.obj
 .text          0x00000000        0xc comdat_b.obj          &lt;-- the duplicate
 .debug$S       0x00000000       0x5c comdat_b.obj
 .llvm_addrsig  0x00000000        0x1 comdat_b.obj
</code></pre>
                <p>There it is. The linker discarded <code>comdat_b.obj</code>'s twelve-byte <code>.text</code> and kept <code>comdat_a.obj</code>'s. Note the size column: <code>0xc</code> = 12, matching the raw size of the COMDAT section and not the 21-byte ordinary <code>.text</code>. The discarded thing is precisely the duplicate, not a whole file's worth of code.</p>
                <p>And the placement rows from the same map, which is the other half of the proof &mdash; the surviving copy, and where the callers went:</p>
                <div class="hex-dump">
                    <pre>   .text          0x00401000       0x15 comdat_a.obj
                    0x00401000                ?use_a@@YAHXZ
   *fill*         0x00401015        0xb
   .text          0x00401020        0xc comdat_a.obj
                    0x00401020                ?shared@@YAHH@Z
   *fill*         0x0040102c        0x4
   .text          0x00401030       0x15 comdat_b.obj
                    0x00401030                ?use_b@@YAHXZ
</pre>
                </div>
                <p><code>?use_a</code> from <code>comdat_a.obj</code>, then the survivor <code>?shared</code> &mdash; <strong>credited to <code>comdat_a.obj</code></strong> &mdash; then <code>?use_b</code> from <code>comdat_b.obj</code>. <code>comdat_b.obj</code> contributed one function, not two. And the disassembly confirms the count independently of the map's claims:</p>
                <pre><code>$ llvm-objdump -d --section=.text comdat_linked.exe
00401020 &lt;?shared@@YAHH@Z&gt;:
00401030 &lt;?use_b@@YAHXZ&gt;:</code></pre>
                <p><strong>One</strong> <code>?shared</code>. Three independent sources &mdash; the discard list, the placement rows, and the disassembly &mdash; all agreeing, and none of them derived from the others.</p>
                <h3>What the callers now point at</h3>
                <p>Here is the part that makes discarding safe rather than merely small. <code>comdat_b.obj</code>'s <code>use_b</code> called <code>shared</code> &mdash; and in <em>its own</em> object, that call was a <code>REL32</code> fixup against <code>comdat_b.obj</code>'s own COMDAT section, whose address was zero. The linker discarded that section, so it had to redirect the call to the survivor in <code>comdat_a.obj</code>, and recompute the displacement for the new distance. The fixup in <code>comdat_b.obj</code> was written expecting a different address, and the linker had to correct it after making the decision to discard.</p>
                <p>That is the reason the algorithm is stated as "discard, then <em>point the symbols at the accepted one</em>" rather than just "discard". A discarded COMDAT section is not a deletion; it is an alias. The references to it become references to a section in another file, which means the relocation step and the deduplication step have to be coordinated &mdash; and the order matters, because a relocation computed against a discarded section's address is wrong the moment the section goes away.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <h3>What actually happens when the bodies differ &mdash; and it is not what you want</h3>
                <p>Change one file so the inline functions are genuinely not the same, and the lesson stops being theoretical:</p>
                <pre><code>$ sed -i 's/v \* 3/v * 4/' comdat_b.cpp
$ diff comdat_a.cpp comdat_b.cpp</code></pre>
                <p>That is the entire change: the <code>3</code> becomes a <code>4</code> in the multiplier, in one file, leaving everything else identical.</p>
                <p>The compiler responds correctly. <code>v * 4</code> is not <code>imul</code> by an immediate at all &mdash; the compiler rewrote it as <code>mov</code> then <code>shl $2</code> &mdash; so the section grew from twelve bytes to fourteen, and the contents are now plainly different:</p>
                <div class="hex-dump">
                    <pre>a.obj  sec4: 55 89 e5 8b 45 08 6b 45 08 03 5d c3   (v * 3, 12 bytes)
b.obj  sec4: 55 89 e5 8b 45 08 8b 45 08 c1 e0 02 5d c3   (v * 4, 14 bytes)
</pre>
                </div>
                <p>And the checksums, correctly, differ:</p>
                <pre><code>a.obj   Checksum: 0xF787F24A
b.obj   Checksum: 0x3B2D87C1</code></pre>
                <p>Everything so far says the linker must refuse to merge these. <strong>It does not.</strong> Here is the discard list from that link:</p>
                <pre><code>Discarded input sections
 .text          0x00000000        0xe b.obj        &lt;-- discarded anyway</code></pre>
                <p><code>b.obj</code>'s fourteen-byte copy was discarded <em>despite the different checksum</em>, and the placement rows show only <code>a.obj</code>'s version surviving. Now the consequence, from the disassembly of the resulting binary:</p>
                <div class="hex-dump">
                    <pre>00401020 &lt;?shared@@YAHH@Z&gt;:
  401026: 6b 45 08 03     imull  $0x3, 0x8(%ebp), %eax   &lt;-- a.obj's v * 3

00401030 &lt;?use_b@@YAHXZ&gt;:
  401034: c7 04 24 0b 00 00 00   movl  $0xb, (%esp)      ; push 11
  40103b: e8 e0 ff ff ff         calll 0x401020 &lt;?shared@@YAHH@Z&gt;
</pre>
                </div>
                <p><code>use_b</code> loads <code>11</code> and calls <code>?shared</code> &mdash; and the only <code>?shared</code> in the binary multiplies by <strong>three</strong>. So <code>use_b()</code> returns <strong>33</strong>, in a program whose source says <strong>44</strong>.</p>
                <div class="callout callout-warn">
                    <strong>What was observed, stated exactly.</strong> The linker used throughout this course, GNU <code>ld</code> in PE emulation mode, deduplicated the COMDAT group on the <strong>symbol name alone</strong>, without consulting the checksum in the auxiliary record. Two different function bodies shared a name, one was discarded, and the survivor was bound to both call sites. The build produced no diagnostic: the link succeeded, the image is well-formed, every tool reads it cleanly, and the result is wrong.
                    <br /><br />
                    Three things this is <em>not</em>. It is not a statement about COFF &mdash; the format did its job, because it <em>recorded</em> the checksum and a correct consumer has everything it needs. It is not a statement about MSVC's linker, which this course has not tested. And it is not a claim that name-based deduplication is inherently wrong: it is exactly right for the identical-bodies case, which is overwhelmingly the common one. It is a statement about a consumer that skipped a check the producer explicitly provided, and about how little anyone would notice if it had.
                </div>
                <p>Now the shape of the bug, because this is the most valuable thing in the concept. No error, no warning, no malformed output. The binary is a <em>valid</em> program that computes the wrong answer. And the reason no test would catch it is not that tests are bad &mdash; it is that the failure is invisible to every layer except the one that made the mistake:</p>
                <ul>
                    <li>The <strong>compiler</strong> was right. It emitted the code it was asked to emit, and the checksum it recorded described that code accurately.</li>
                    <li>The <strong>format</strong> was right. The checksum field exists, is populated, and differs. The information needed to catch this is sitting in the object file.</li>
                    <li>The <strong>linker</strong> was wrong, silently, by omitting one comparison.</li>
                    <li>The <strong>runtime</strong> is fine &mdash; it faithfully executed a correct program.</li>
                </ul>
                <p>Every layer reported success. The bug lived entirely in the gap between "the information is present" and "the information is checked", and no amount of testing the layers individually would have found it. That is the shape of the worst class of bug there is, and it is why the discipline in this course is to verify each claim against a file rather than against a document. The document said the checksum was there. The map file said the section was discarded. Only putting the two together revealed that the second should never have happened &mdash; and the checksum, which is the whole point of the mechanism, was the evidence that made the mistake visible at all.</p>
                <p>The counterfactual is worth stating, because it is what a correct consumer does. The two sections differ in <em>both</em> size (12 against 14) and checksum. A linker honouring the checksum must decline the merge, and then <code>?shared@@YAHH@Z</code> is defined twice &mdash; which is a genuine error, because C++ does not permit two different definitions of an inline function. The correct outcome is a build failure. The one observed was a build success and a wrong answer. Between those, the loud one is infinitely preferable, and the checksum field exists to make the loud one reachable.</p>
                <p>So the earlier reading of the algorithm was optimistic in exactly one place, and it is worth seeing where. The sketch said the linker keeps the first group whose "checksums match and the selection's extra condition holds". Every part of that sentence is in the <em>object file</em>. A linker that skips the checksum is not making a different decision from the specification; it is making <strong>no</strong> decision about equivalence, and falling back on name identity &mdash; which happens to be right far more often than anyone would like.</p>
                <p>One more consequence worth seeing, because it explains why COMDAT shows up where it does. Change the selection to <code>SAME_SIZE</code> and the two twelve-byte functions still deduplicate &mdash; same size, contents ignored. That is a faster rule and a weaker one, and it is the right rule for data where a producer can cheaply guarantee equal size but not equal content. So:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Selection</th><th scope="col">Requires</th><th scope="col">Safe when</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>ANY</code></td><td>Matching checksums</td><td>Always. The contents are provably the same</td></tr>
                        <tr><td><code>EXACT_MATCH</code></td><td>Matching checksums <em>and</em> the same name</td><td>Always, and stricter &mdash; refuses merges you might have wanted</td></tr>
                        <tr><td><code>SAME_SIZE</code></td><td>Equal sizes only</td><td>Only when the producer can guarantee size equality implies content equality</td></tr>
                        <tr><td><code>ASSOCIATIVE</code></td><td>Nothing beyond being a COMDAT</td><td>Never for arbitrary content. Used for genuinely commutative data</td></tr>
                        <tr><td><code>NONE</code></td><td>&mdash;</td><td>The section is not a COMDAT and will never be discarded</td></tr>
                    </tbody>
                </table>
                <p>Read the last column as the specification of what a compiler must <em>guarantee</em> before choosing a selection. The selection is a promise, and the linker is entitled to act on it. A producer that picks <code>SAME_SIZE</code> for two functions that happen to be the same length but are not the same code has not saved anything &mdash; it has moved the bug from link time to run time, and removed the diagnostic that would have caught it.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ clang++ --target=i686-pc-windows-msvc -c comdat_a.cpp -o comdat_a.obj
$ clang++ --target=i686-pc-windows-msvc -c comdat_b.cpp -o comdat_b.obj
$ llvm-readobj --symbols comdat_a.obj | grep -A2 'Selection'
$ ld --oformat pei-i386 -m i386pe comdat_a.obj comdat_b.obj \
      -o out.exe --entry use_a -Map out.map
$ grep -A6 'Discarded input' out.map</code></pre>
                <ul>
                    <li><strong>Verify the checksum claim yourself.</strong> Read the twelve bytes of section 4 from both objects and compare them byte for byte. Then read the two checksum fields from the auxiliary records. Equal bytes and equal checksums is the whole mechanism in one screen of evidence &mdash; and it is the kind of thing worth doing once so you never have to take it on trust again.</li>
                    <li><strong>Reproduce the silent failure.</strong> Change the <code>3</code> to a <code>4</code> in <code>comdat_b.cpp</code>, relink, and disassemble. Confirm that <code>use_b</code> now calls the surviving <code>* 3</code> body and that the link produced no warning. Then read the two checksums and confirm they differ. You have just built a binary that computes a different answer from its source, and the whole experiment is four commands &mdash; that ratio is the argument for verifying link-time behaviour rather than trusting it.</li>
                    <li><strong>Find out which copy wins, and why it is not the point.</strong> Put <code>comdat_b.obj</code> first on the command line. Now <em>b</em>'s copy survives. The linked binary is byte-identical &mdash; because the contents are identical &mdash; but the map credits the section to a different file. Confirm both halves of that claim. It is the cleanest available demonstration of why the rule has to be content-based rather than order-based.</li>
                    <li><strong>Count the dedup on a real build.</strong> Link something large with a map file and count the discard rows that are ordinary code sections rather than debug data. The number is a direct measure of how much duplication inline functions cost, and it is usually much larger than people expect &mdash; because every header included in every translation unit contributes.</li>
                    <li><strong>Make one COMDAT group much larger.</strong> Put a big <code>inline</code> function in a header, include it from three files, and relink. Watch the discarded sizes scale to a third of the total. Then flip the alignment to 1 byte and watch the <code>*fill*</code> rows change while the dedup stays identical &mdash; two independent linker decisions, cleanly separable.</li>
                    <li><strong>Ask what breaks without COMDAT.</strong> Remove the <code>inline</code> keyword from both files and relink. You now have two genuinely distinct <code>shared</code> functions with the same name, and the linker will refuse. That refusal <em>is</em> the feature: COMDAT is the mechanism that makes "one definition, many copies" expressible, and its absence would make inline functions unlinkable across translation units.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: two objects each contain a twelve-byte COMDAT <code>.text</code> with <code>Selection: Any</code> and <code>Checksum: 0xF787F24A</code>. The twelve bytes are identical. The linker discards one of them. Now the caller in the <em>discarded</em> object still needs to reach that function. What has to happen, and what would go wrong if the linker simply deleted the section and left the call site alone?</p>
                <div class="quiz" id="quiz-coff-comdat-linking-1">
                    <button class="quiz-option" data-correct="true" data-explain="Discarding a COMDAT section is an alias operation, not a deletion. The caller's REL32 fixup was computed against the discarded copy's address, which was its own section's address, so the linker has to re-point the reference at the survivor and recompute the displacement for the new distance — and the new distance is across object files, so it is not a value anyone had written down. This is why deduplication and relocation have to be coordinated rather than independent passes: a relocation computed against a section that is about to be discarded is wrong the instant the discard happens, and the wrongness is silent because the fixup is still marked applied." onclick="checkQuiz('quiz-coff-comdat-linking-1', this)">The call site's relocation must be redirected to the surviving copy in the other object and its displacement recomputed for the new, cross-file distance. Deleting the section alone would leave a fixup pointing into a section that no longer exists, so the call would go to whatever now occupies that address</button>
                    <button class="quiz-option" data-correct="false" data-explain="No fixup is involved in the surviving copy's call sites — they already pointed at it. The reference that needs redirecting is in the discarded object, and it needs a recomputed displacement because the function now lives at a different address. A symbol-alias fixup with no address change would leave the call going to the old location." onclick="checkQuiz('quiz-coff-comdat-linking-1', this)">Nothing needs to change, because the two copies are byte-identical, so every call site that pointed at the discarded copy already computes the right displacement</button>
                    <button class="quiz-option" data-correct="false" data-explain="That is the failure mode, not the mechanism. A bound symbol in this object format carries a section index, and the index of the discarded section is still present in the symbol table — deleting the section without repointing the symbol leaves the index pointing at a section that is no longer in the image. The linker must repoint the symbol, and the relocation is then recomputed from the new address." onclick="checkQuiz('quiz-coff-comdat-linking-1', this)">The symbol is removed from the symbol table, and the linker resolves the call by name at fixup time, so no address needs to be recomputed</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You maintain a large C++ project. It links, it passes its tests, and it has done so for years with the same toolchain. A colleague rebuilds on a different machine, with a different linker build, and one function &mdash; <code>is_valid()</code>, in a header included by forty translation units &mdash; starts returning inconsistent results. Nothing in the source changed. The old machine still works. Given what you have just seen, what is your leading hypothesis, how would you test it cheaply, and what would the result tell you?</p>
                <div class="quiz" id="quiz-coff-comdat-linking-2">
                    <button class="quiz-option" data-correct="true" data-explain="This is the scenario the checksum exists to catch, and the machine-dependence is the tell. If the only thing that changed is the linker binary, the objects are almost certainly byte-identical, so the difference cannot be in what the compiler emitted or what the format recorded. It has to be in whether the consumer performed the equivalence check. Linking the same two objects with both linkers and diffing the map files' discard lists is the decisive experiment: one discards a section the other keeps, or both discard it, and the comparison tells you immediately which behaviour you have. The result is diagnostic in both directions. If the linkers disagree about the discard, you have a linker that ignores the checksum and you have a build you should not trust. If both discard it, the problem is upstream and the objects differ after all." onclick="checkQuiz('quiz-coff-comdat-linking-2', this)">The two linkers deduplicate differently, and one of them is discarding a COMDAT copy whose checksum does not match. Link the same objects with both and diff the <code>Discarded input sections</code> blocks of the two map files &mdash; a section discarded by one and kept by the other names the culprit immediately</button>
                    <button class="quiz-option" data-correct="false" data-explain="This predicts machine-dependence, which is a real clue, but it contradicts the fact that the function is the same across both machines and only one of them is wrong. A build-order difference would also have to produce a difference in the result, and the two copies have the same name, so a linker keeping both would report a duplicate rather than silently choosing. The evidence points at a consumer difference, not at an input difference." onclick="checkQuiz('quiz-coff-comdat-linking-2', this)">A build-order difference: the new machine lists the object files in a different order, so a different translation unit's copy of the inline function wins the COMDAT selection</button>
                    <button class="quiz-option" data-correct="false" data-explain="A compiler difference is the natural first hypothesis and it is worth ruling out, but the evidence rules it out cheaply. If the compilers differed, the source-level behaviour of the function would differ in a way that reproduced on the old machine when rebuilt with the new compiler. The stated fact is that the old machine is unchanged, which points at something in the link rather than the compile. Note that you should still verify this by diffing the objects, but you should not stop there." onclick="checkQuiz('quiz-coff-comdat-linking-2', this)">A compiler difference: the two machines have different compiler builds, so one of them miscompiles the inline function</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a hash stands in for a comparison so the comparison can be skipped. That is a fine trade until the hash's input differs from what you think it is. Whenever a system uses a cheap check as a proxy for an expensive one, find out exactly what went into the cheap check &mdash; and if the consequence of being wrong is silent, verify the proxy once by hand.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the payoff for <a href="/courses/coff/lessons/coff-symbol-table">the symbol table</a> and its auxiliary records. You decoded a <code>Selection</code> field and a <code>Checksum</code> field as numbers in a byte layout. They are a <em>contract</em>, between a compiler that promises something and a linker that spends it. A format that carries a decision in a header field you only read as data is a format whose <a href="/courses/coff/lessons/coff-section-table">section characteristics</a> and symbol table are not a description of the file but a set of instructions to whoever consumes it.</p>
                <p>The mechanism is the COFF instance of something every executable format needs. ELF has <code>.gnu.linkonce.*</code> section groups with a group signature, and the same deduplication semantics. Mach-O has <code>linker_optimized</code> and <code>dead_strip</code> sub-sections. The names differ and the storage differs and the hash algorithm differs, but the <em>problem</em> is identical, and it exists in all three for the same reason: independently compiled translation units cannot coordinate, and something has to arbitrate after the fact. Learning one instance properly is how you recognise the other two.</p>
                <p>That closes the COFF course. A COFF object was decoded field by field in Module 1, its symbol table and string table in Module 2, its container formats and the COMDAT contract in Module 3 &mdash; and now a real link was run, its five steps observed, its transcript read, and its deduplication watched working. The object side is finished.</p>
                <p>Back to the <a href="/courses/coff">course index</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/coff/lessons/coff-map-files">Previous: Map Files</a></span>
                <span><a href="/courses/coff">Back to course</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
