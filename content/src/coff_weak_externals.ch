// COFF Course — Module 5: Other Targets and Other Sections
// Concept: weak externals — a symbol that is allowed to be missing, a storage class
// that needs an auxiliary record, and a resolution rule the format does not define.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_coff_weak_externals() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Weak Externals — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson coff-lesson">
            <a href="/courses/coff" class="back-link">Back to course</a>
            <h1>Weak Externals</h1>
            <div class="lesson-meta">19 min &middot; Module 5: Other Targets and Other Sections &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every symbol in Modules 1 and 2 had one of two states: defined here, or defined somewhere else and required to be. A reference to an undefined symbol is an error. That is the rule, and it is what makes a library's API meaningful &mdash; you can only call what somebody promised to provide.</p>
                <p>But a great deal of useful code depends on a symbol that <em>might</em> be there. A program that uses a system's high-resolution timer will use one if the platform has it and fall back if not. A library that accelerates a hash function will use the platform's if it exists. A plugin host that supports an optional extension must be able to <em>ask</em> whether it is present, which is a question the linker has to be able to answer without failing the build.</p>
                <p>That is what a weak external is: <strong>a reference that the linker is permitted to leave unresolved.</strong> It is a third state, and it is not a flag on the reference &mdash; it is a <em>storage class on the symbol</em>, which means it lives in the symbol table and needs an auxiliary record to say what "unresolved" should resolve to instead. The symbol table concept decoded the 18-byte record and its auxiliary chains; this concept is the case where the auxiliary record carries information nothing else in the file can supply.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Produce one:</p>
                <p>One function declared weak, and one caller that tests it before using it:</p>
<table>
    <thead>
        <tr><th scope="col">Line</th><th scope="col">Content</th></tr>
    </thead>
    <tbody>
        <tr><td>1</td><td><code>extern int other_fn(void) __attribute__((weak))</code></td></tr>
        <tr><td>2</td><td><code>int call(void)</code> whose single-expression body is <code>other_fn ? other_fn() : 0</code></td></tr>
    </tbody>
</table>
<pre><code>$ clang --target=i686-pc-windows-msvc -c weak.c -o weak.obj</code></pre>
                <p>And read the symbol:</p>
                <pre><code>$ llvm-readobj --symbols weak.obj
  Name: _other_fn
  Value: 0
  Section: IMAGE_SYM_UNDEFINED (0)
  BaseType: Null (0x0)
  ComplexType: Null (0x0)
  StorageClass: WeakExternal (0x69)
  AuxSymbolCount: 1
  AuxWeakExternal
    Linked: .weak._other_fn.default._call (17)
    Search: Alias (0x3)</code></pre>
                <p>Four things in that, and each one is a decision:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Field</th><th scope="col">Value</th><th scope="col">Means</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>StorageClass</code></td><td><code>0x69</code> = 105</td><td>Not "external". A class of its own: this reference may go unresolved</td></tr>
                        <tr><td><code>Section</code></td><td>0 = undefined</td><td>As for any external. The weakness is <em>additional</em> to being undefined, not a replacement</td></tr>
                        <tr><td><code>AuxSymbolCount</code></td><td>1</td><td>An auxiliary record follows, and it is not optional</td></tr>
                        <tr><td><code>AuxWeakExternal</code></td><td colspan="2">The answer to "unresolved, so what instead?"</td></tr>
                    </tbody>
                </table>
                <p>The auxiliary record is the whole design. A weak reference with no fallback rule is not a decision, it is a wish, and a linker cannot act on a wish. So the record supplies one of three answers:</p>
                <table>
                    <thead>
                        <tr><th scope="col"><code>Characteristics</code></th><th scope="col">Name</th><th scope="col">If the symbol is missing</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>1</td><td><code>Library</code></td><td>Look for it in a library, as an ordinary external would be</td></tr>
                        <tr><td>2</td><td><code>Alias</code></td><td>Bind to the fallback symbol named in the same record</td></tr>
                        <tr><td>3</td><td><code>AntiDependency</code> &mdash; reported by the reader as <code>Alias</code> here</td><td>Bind to the fallback, and treat a real definition as a conflict</td></tr>
                    </tbody>
                </table>
                <p>All three name a fallback symbol in the second field, so the record is <strong>two symbol-table indices</strong>: a <code>TagIndex</code> naming the fallback, and a <code>Characteristics</code> saying how to treat it. The reader this course has available prints the characteristics value <code>0x3</code> with the label <code>Alias</code>, which is worth noting rather than glossing over &mdash; see the callout below.</p>
                <div class="callout callout-warn">
                    <strong>A tool disagrees with itself, or with the specification.</strong> The value in the file is <code>0x3</code>. The specification's three values are 1, 2 and 3, and 3 is <code>IMAGE_WEAK_EXTERN_SEARCH_ANTI_DEPENDENCY</code>. The reader prints it as <code>Alias</code>, which is the label for <code>0x2</code>. <strong>So either the reader's table is off by one, or the producer emitted 2 and the reader is displaying 3, or the producer emitted 3 and the reader's label is wrong.</strong> The bytes are the authority and they say <code>03</code>. What is <em>not</em> established here is which of the three labels is correct, because there is no second independent reader of this field on this machine to ask. So the concept states the value, states that the specification's third value is the anti-dependency case, and does not claim the reader's label is right. This is a smaller version of the <code>readelf</code>-versus-<code>llvm</code> adjudication in the loclists concept, and the discipline is the same: report the disagreement rather than picking a side.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>The fallback symbol, and what it is not</h3>
                <p>The aux record names symbol 17. Look at what that is:</p>
                <pre><code>$ llvm-nm weak.obj
00000000 A .weak._other_fn.default._call</code></pre>
                <p>An <strong>absolute</strong> symbol &mdash; section 0, value 0 &mdash; whose <em>name</em> encodes the whole mechanism in one string:</p>
                <div class="hex-dump">
                    <pre>.weak . _other_fn . default . _call
  |       |          |        |
  |       |          |        +-- a per-declaration suffix, so two weak
  |       |          |           references to the same function get
  |       |          |           different alias symbols
  |       |          +----------- "no library search" / default handling
  |       +---------------------- the symbol being made optional
  +------------------------------ "this is a synthetic alias, not code"
</pre>
                </div>
                <p>So the fallback is not a function. It is a synthetic symbol with a descriptive name and no storage, whose only job is to be the address the linker reports when the real symbol is absent. <strong>The address of a missing function is the address of a name.</strong> And because it has value 0 and no section, reading it as a location gives 0 &mdash; which is also why the calling code tests the pointer before calling it.</p>
                <h3>The three states, and what the caller does with each</h3>
                <p>Now the machine code, which is the part that makes the design make sense:</p>
                <pre><code>$ llvm-objdump -d --section=.text weak.obj
  call:
    0:  84 c0           test  %eax,%eax
    2:  74 03           je    7
    4:  ff d0           call  *%eax
    6:  c3              ret
    7:  31 c0           xor   %eax,%eax
    9:  c3              ret
</code></pre>
                <p>Two instructions of test, then a call through a register, then a zero return on the other path. The source said <code>other_fn ? other_fn() : 0</code>, and the compiler emitted exactly that: <strong>the weak reference compiles to a load, a test, and a branch, because the symbol's value is not known until link time and might be zero.</strong></p>
                <p>Compare that with an ordinary external call, which compiles to a direct relative <code>call</code> to a known offset. The difference in the generated code is the entire observable effect of weakness: <strong>weakness costs a branch.</strong> That is a real cost on a hot path, which is why a library will mark a symbol weak only when the optional path is genuinely cold, and it is the reason the storage class is a deliberate choice rather than a free annotation.</p>
                <h3>What the linker does, and where it stops being a linker job</h3>
                <p>The resolution is a short algorithm, and one of its steps is not in the linker at all:</p>
                <div class="formula">
for each undefined symbol with StorageClass WeakExternal:
    if a definition exists anywhere in the link:
        bind to it                       (the normal case)
    else:
        bind to AuxWeakExternal.TagIndex
        apply AuxWeakExternal.Characteristics:
            Library        -> also search the library archives
            Alias          -> done; the fallback is the answer
            AntiDependency -> done, and flag a real definition
                              as a conflict rather than a win
</div>
                <p>That is the whole mechanism, and it is entirely a link-time decision. So a weak external is a promise the <em>linker</em> keeps, not the loader and not the program &mdash; which is the useful thing to know when you are looking for the answer to "was this symbol actually present?".</p>
                <div class="callout callout-warn">
                    <strong>It does not survive into the image as a weak reference.</strong> By the time a binary exists, the symbol is either a normal defined symbol or the fallback's address, and nothing in the image records that it was once weak. That has a direct consequence for reverse engineering: <strong>you cannot tell from a stripped binary whether a function pointer was optional or mandatory.</strong> A null test in the disassembly is evidence of a weak reference, because an ordinary call would not compile to one &mdash; but it is evidence, not proof, since a defensive null check on an ordinary pointer looks identical.
                </div>
                <p>One more thing the record enables that is easy to miss, because it is the anti-dependency case. Marking a symbol weak does not only permit it to be missing; it can also mean <em>"if this gets defined, something has gone wrong"</em>. That is the mechanism a platform uses to detect an application accidentally defining a symbol the platform was going to supply &mdash; the definition does not silently win, it is reported. It is a debugging aid expressed in the symbol table, and it is the reason the <code>Characteristics</code> field has three values rather than a boolean.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The three real uses, and what each looks like at the symbol-table level. They differ in which field carries the meaning, which is the part worth remembering.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Intent</th><th scope="col">What the caller must do</th><th scope="col">Symbol-table mechanism</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Optional acceleration</td><td>Test the pointer, call if present</td><td>Weak, fallback = an absolute symbol; a branch in the code</td></tr>
                        <tr><td>Optional platform feature</td><td>Test the pointer, fall back if absent</td><td>Weak, <code>Characteristics = Library</code> so a library may still provide it</td></tr>
                        <tr><td>Detect an accidental definition</td><td>Nothing &mdash; it is a link-time diagnostic</td><td>Weak, <code>Characteristics = AntiDependency</code></td></tr>
                    </tbody>
                </table>
                <p>The middle row is the one with a subtlety worth spelling out, because it is the difference between "optional" and "optional but encouraged". <code>Characteristics = 1</code> tells the linker to do an ordinary library search for the symbol. If no archive provides it, the fallback applies. So the symbol <em>is</em> still resolved to a real definition when one is available, and the weak class only comes into play at the point where the search has failed. The three values are not three strengths of the same thing; they are three different questions asked at three different moments &mdash; during library search, after it, and as a conflict check.</p>
                <p>Now the tooling question, which is where a format like this usually gets misused. A tool that wants to know "is this symbol guaranteed present?" has three possible answers and must not conflate them:</p>
                <div class="formula">
"Is it DEFINED in this image?"
    -> read the symbol table of the image
    -> a weak reference resolved to a real definition
       is indistinguishable from an ordinary one. Answer: yes.

"Was it DECLARED weak in the source?"
    -> not knowable from the image
    -> only from the objects, before linking

"Does the program CHECK it before use?"
    -> not knowable from the symbol table at all
    -> only by reading the code
</div>
                <p>The middle and bottom blocks are the ones people get wrong, and they are wrong in the same direction: assuming the image remembers a property of the source that the linker resolved away. <strong>A weak reference is a link-time construct, and like every other link-time construct it leaves no trace in the output.</strong> A static analyser that wants to report "this call is to an optional function" has to read the code, find the null test, and reason about it &mdash; and even then it is inferring, not reading a fact.</p>
                <p>That is the same conclusion the <a href="/courses/coff/lessons/coff-comdat-linking">COMDAT concept</a> reached from the other side. There, a checksum in the file was a promise the linker spent and a consumer could skip; here, a storage class in the file is a decision the linker makes and then forgets. Both are cases where the interesting information exists only before the link, and a tool that runs after it is working from a file that has already thrown the answer away. <strong>The link is a boundary, and anything you need to know about the program has to be recovered on the near side of it.</strong></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ clang --target=i686-pc-windows-msvc -c weak.c -o weak.obj
$ llvm-readobj --symbols weak.obj | grep -A5 WeakExternal
$ llvm-nm weak.obj | grep weak</code></pre>
                <ul>
                    <li><strong>Build the three cases.</strong> Mark one symbol with <code>__attribute__((weak))</code>, one as a plain weak <em>definition</em> rather than an extern, and one with an explicit fallback. Compare the storage class, the <code>AuxSymbolCount</code>, and the <code>Characteristics</code> in all three. The definition case is the interesting one, because a weak definition is a promise the <em>linker</em> keeps against a duplicate rather than one it makes about a missing symbol.</li>
                    <li><strong>Read the raw 10 bytes.</strong> The <code>AuxWeakExternal</code> record is two fields: a 4-byte symbol index and a 4-byte characteristics value. Find them at the right offset after the 18-byte symbol and confirm they are <code>11 00 00 00</code> and <code>03 00 00 00</code>. Then you can adjudicate the reader's label dispute yourself, because you will be reading the specification value and the file's bytes side by side.</li>
                    <li><strong>Link it both ways.</strong> Link <code>weak.obj</code> alone, and then with a second object that defines <code>_other_fn</code>. Compare the two images: the disassembly of <code>call</code> should be identical, and only the value the fallback resolves to should differ. That is the cleanest demonstration that weakness is a link-time property with no run-time cost beyond the branch.</li>
                    <li><strong>Prove the branch is the cost.</strong> Compile a function calling a weak symbol <em>without</em> the null test &mdash; just call it &mdash; and compare the generated code. You will get a direct call and a link error or a crash, which is the point: the test is not defensive coding the programmer added, it is the mechanism, and removing it removes the mechanism.</li>
                    <li><strong>Look for weak externals in a real binary.</strong> Take any Windows PE you have and look for <code>.weak.</code> symbols or <code>StorageClass 105</code> entries. Most will have been resolved away, which is the point &mdash; but an <em>unresolved</em> one is a fascinating find, because it means a weak reference survived into the image.</li>
                    <li><strong>Check the third value carefully.</strong> The specification's value 3 is the anti-dependency case and the reader calls it <code>Alias</code>. Work out which is right from the file's bytes and the specification, and if you can find a second tool that reads the field, compare all three. A one-byte disagreement about a three-valued enum is a good exercise in how much you should trust a single reader.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: an object has a symbol with <code>StorageClass: WeakExternal (0x69)</code>, <code>Section: 0</code>, <code>AuxSymbolCount: 1</code>, and an aux record naming symbol 17 as the fallback with <code>Characteristics = 3</code>. Symbol 17 is an absolute symbol named <code>.weak._other_fn.default._call</code> at value 0. No object in the link defines <code>_other_fn</code>. What address does the linker give <code>_other_fn</code>, and what will a program that calls it do?</p>
                <div class="quiz" id="quiz-coff-weak-externals-1">
                    <button class="quiz-option" data-correct="true" data-explain="The resolution is a substitution: an unresolved weak reference binds to the fallback named in the aux record, so the symbol's value becomes whatever symbol 17 resolves to, which is 0 because it is absolute with no section. The third characteristic is the anti-dependency case, and with no definition anywhere it simply completes as the fallback binds. What the program does next is entirely up to the source, and this is where the concept meets the machine code: because the value is not known at compile time and might be zero, the weak reference compiles to a load, a test and a branch rather than a direct call. A caller that omits the test calls address zero. So the linker doing its job perfectly and the program crashing are not in tension, they are the design working as specified with a caller that skipped the mechanism." onclick="checkQuiz('quiz-coff-weak-externals-1', this)">It binds to the fallback, so the value is 0 &mdash; the address of the synthetic alias symbol. A caller that tests the pointer first takes the fallback path; one that does not test it calls address 0 and crashes</button>
                    <button class="quiz-option" data-correct="false" data-explain="That would make the mechanism a link error, which is the opposite of what a weak reference is for. The whole point of the storage class is to permit the link to succeed when the symbol is absent, and the Characteristics field chooses among three ways of handling the absence, not between succeeding and failing. The unresolved weak reference is a defined state, not an error state." onclick="checkQuiz('quiz-coff-weak-externals-1', this)">The linker reports an unresolved external, because a weak reference with no definition is still a reference to nothing</button>
                    <button class="quiz-option" data-correct="false" data-explain="This reverses which symbol is substituted. The TagIndex in the aux record names the fallback that is used when the primary symbol is missing, and that is symbol 17 here. The weak reference does not resolve to a library or to the undefined section, and the search behaviour that would consult a library is a separate Characteristics value, not something that happens to other_fn's slot." onclick="checkQuiz('quiz-coff-weak-externals-1', this)">It binds to the nearest library that provides the symbol, and since no object defines it the linker searches the archives and, finding nothing, leaves it at 0</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are auditing a shipped binary for a security review. Someone asks whether the application's use of a platform crypto function is safe, and you need to answer: is that function guaranteed present, or does the program handle its absence? You have the binary, the debug info, and the original object files. What can you actually determine, from each, and what can you not determine at all?</p>
                <div class="quiz" id="quiz-coff-weak-externals-2">
                    <button class="quiz-option" data-correct="true" data-explain="This is the concept's practical consequence and the reason it is worth a page. The linker resolved the weak reference and then forgot it, so the answer to the question that was asked is not in the image at all. From the binary you can learn that the function is present, and you can read the disassembly to see whether the call is guarded by a null test, which is strong evidence but is inference rather than a recorded fact. From the objects, before the link consumed the decision, you can read the storage class directly and get a definitive answer. The interesting part is the third case: if the objects are gone, some questions become permanently unanswerable, and no amount of cleverness recovers them, because the information was consumed by a process whose entire purpose was to consume it. That is a general property of build artefacts, and it argues for keeping objects around when the questions will be asked later rather than trying to answer them from the output." onclick="checkQuiz('quiz-coff-weak-externals-2', this)">From the binary you can see the function is present and can read a null test in the disassembly, but you cannot tell the reference was ever weak. From the objects you can read <code>StorageClass 105</code> directly and answer definitively. If the objects are gone, whether the call was optional is <strong>unanswerable</strong></button>
                    <button class="quiz-option" data-correct="false" data-explain="This overstates what the image preserves. The absence of an address in a symbol table is normal for a stripped binary and is not evidence that a reference was weak, since an ordinary undefined-in-this-object symbol is resolved the same way. What distinguishes a weak reference at run time is not its presence in the table but the null test in the code, and even that is inference. The storage class is a source-level property that the link consumed." onclick="checkQuiz('quiz-coff-weak-externals-2', this)">From the binary you can see the symbol is present and that it was weak, because a resolved weak reference keeps its storage class in the image's symbol table</button>
                    <button class="quiz-option" data-correct="false" data-explain="The debug info does not carry the storage class, because DWARF describes types, variables, functions and their locations, and it has no attribute for how a reference was declared. DW_AT_declaration marks a declaration and nothing more. This is worth noticing as a category: some properties of a program are recorded in the symbol table, some in the debug info, and some in neither, and knowing which is which is the whole of the audit question." onclick="checkQuiz('quiz-coff-weak-externals-2', this)">From the binary you can determine it by looking for the <code>.weak.</code> alias symbol, which the linker keeps in the image as a record of the fallback</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when auditing a shipped artefact, ask which build stage consumed the information you need, and go get it from before that stage. A question the linker answered cannot be asked of the linker's output.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the payoff for a detail in <a href="/courses/coff/lessons/coff-symbol-table">the symbol table concept</a> that could easily have been left as trivia: the 18-byte record has a one-byte <code>NumberOfAuxSymbols</code> field, and a value of 1 means "an auxiliary record follows, and it is not a COMDAT block". The symbol table concept decoded three auxiliary shapes; this is the fourth, and it is the one that is <em>required</em> rather than optional &mdash; a weak external with no aux record does not mean "no fallback", it means malformed.</p>
                <p>That is the same relationship <a href="/courses/coff/lessons/coff-comdat">the COMDAT concept</a> had, one level up. There, the aux record carried a checksum so a linker could merge two identical sections. Here it carries a fallback so a linker can survive a missing one. <strong>Both are the format answering the question "what should a consumer do when the expected thing is not there?"</strong> One answer is a comparison to perform, the other is a substitution to make, and neither can be defaulted because both are decisions with consequences.</p>
                <p>The generated code closes the loop with <a href="/courses/coff/lessons/coff-relocations">relocations</a>. An ordinary external call is a <code>REL32</code> fixup against a symbol the linker guarantees exists, so it compiles to a direct <code>call</code>. A weak one is the same fixup against a symbol the linker may leave at zero, so it compiles to a load, a test and an indirect <code>call</code>. The branch in the instruction stream is the storage class, made visible. That is a satisfying thing to be able to see, and it is also the honest answer to how much weakness costs.</p>
                <p>One concept left, and it is the mirror image of the TLS one. TLS carried information the loader needs, at run time, per thread. This next section carries information the <em>linker</em> needs, at link time, and which the linker throws away the instant it has read it &mdash; so the section is not in the output at all, and a reader has to know it existed to understand why something else is missing.</p>
                <p>Next: <a href="/courses/coff/lessons/coff-drectve">Linker Directives in a Section</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/coff/lessons/coff-tls">Previous: Thread Local Storage</a></span>
                <span><a href="/courses/coff/lessons/coff-drectve">Next: Linker Directives in a Section</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
