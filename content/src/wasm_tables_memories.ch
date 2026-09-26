// WebAssembly Course — Module 2: Declarations
// Concept: tables, memories and the limits record — one flag byte that three
// proposals share, and the field-width trap inside it.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_wasm_tables_memories() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Tables, Memories and Limits — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson wasm-lesson">
            <a href="/courses/wasm" class="back-link">Back to course</a>
            <h1>Tables, Memories and Limits</h1>
            <div class="lesson-meta">20 min &middot; Module 2: Declarations &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Two of the four things a module can declare are spaces: a <strong>table</strong> of indirect function references, and a <strong>memory</strong> of bytes. They look unrelated and share almost all of their encoding, which makes them a good place to learn something that will be true for the rest of the format.</p>
                <p>Both are declared with a <em>limits record</em>, and the limits record is one flag byte followed by one or two counts. That is the whole thing. And the flag byte is a small case study in how a format that started minimal accumulates, because <strong>it now carries three independent bits and they were not all there on day one.</strong></p>
                <p>The idea underneath is a resource bound, and it is the format's answer to "how much can this module ask for". A memory is a minimum number of pages, optionally a maximum. A table is a minimum number of elements, optionally a maximum. <strong>No upper bound unless the module states one</strong>, which is a decision the module gets to make and a host gets to override &mdash; and the reason the maximum is optional is that a module should be able to grow to whatever the host can give it.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The two sections, both tiny, both using the same record:</p>
                <div class="hex-dump">
                    <pre>table section:                          memory section:
  count                                 count
  elemtype, limits   repeated           limits       repeated

elemtype is ONE byte:
  70  funcref                      a table holds function references
  6f  externref                    a table holds opaque host references
</pre>
                </div>
                <p>And the limits record, which is where the flags are:</p>
                <div class="hex-dump">
                    <pre>  00                      01                      02                     03
  |                       |                       |                      |
  |                       |                       |                      +-- shared AND has max
  |                       |                       |                      +----- has a maximum
  |                       |                       +------------------------------ SHARED
  |                       +-------------------------------------- HAS A MAXIMUM
  +-------------------------------------------------- minimum only
</pre>
                </div>
                <p>Two bits, and the third arrived later. Bit 0 is "there is a maximum, and it follows"; bit 1 is "this memory is shared between threads"; bit 2 is "the counts are 64-bit" &mdash; the memory64 proposal.</p>
                <p><strong>Read the flag byte as a set of independent bits, never as an enumeration.</strong> There are only four combinations in use today, and they are 0, 1, 2 and 3, which makes an enum tempting. It is the wrong model, because a reader written as a switch will have no case for bit 2 and will reject a valid 64-bit memory rather than reading it. <strong>The same mistake the <a href="/courses/coff/lessons/coff-characteristics">COFF characteristics</a> invites and this course has already documented once</strong> &mdash; a bitfield whose values happen to be contiguous right now.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Both sections from the declarations module, in full:</p>
                <div class="hex-dump">
                    <pre>0046: 01 70 00 04          table section: 1 table
      |  |  |  |
      |  |  |  +------ minimum = 4
      |  |  +--------- flags = 0x00: minimum only
      |  +------------ 0x70 = funcref
      +--------------- count = 1

004c: 01 01 02 08          memory section: 1 memory
      |  |  |  |
      |  |  |  +------ maximum = 8
      |  |  +--------- minimum = 2
      |  +------------ flags = 0x01: HAS A MAXIMUM
      +--------------- count = 1
</pre>
                </div>
                <p>Four bytes each, and every byte is load-bearing. The memory section is the more instructive of the two because it is the only place in the core format where <strong>a flag bit changes the shape of what follows</strong>: with flags <code>0x00</code> the record is one count, and with <code>0x01</code> it is two. A reader that reads a count and then unconditionally reads a second one will consume the first byte of the <em>next</em> record as a maximum, and the damage propagates silently.</p>
                <div class="hex-dump">
                    <pre>  read flags = 0x00, read min = 2, and then?
    wrong: assume a maximum follows, read 0x08 as it
           the next byte is the MEMORY SECTION's count, not a maximum
    right: flags & 0x01 is 0, so there is no maximum
</pre>
                </div>
                <p>So the flag byte is not decoration and not a type tag. <strong>It is a length in disguise</strong>, and a reader that treats it as anything else will desynchronise. This is the third instance of that pattern in three sections: a <a href="/courses/wasm/lessons/wasm-leb128">LEB128</a> is self-delimiting, a <a href="/courses/wasm/lessons/wasm-code">body size</a> delimits a body, and a limits flag delimits a record. <strong>Almost every field in this format says how long the next thing is, and that is what makes a streaming reader possible.</strong></p>
                <h3>The shared and 64-bit bits</h3>
                <p>The two bits beyond the maximum are worth reading even though this course's samples do not use them, because they change the record's arithmetic and not just its shape:</p>
                <ul>
                    <li><strong><code>shared</code> (bit 1).</strong> The memory is shared between threads, which means it must be declared <code>shared</code> in the import and at instantiation, and a shared memory cannot have a maximum &mdash; because growth would race. The threads proposal requires exactly that pairing, so the flag is not decorative: it changes what a legal module looks like.</li>
                    <li><strong><code>memory64</code> (bit 2).</strong> The two counts are 64-bit rather than 32-bit, which is a proposal rather than core. It is here to illustrate a general point: <strong>a bitfield lets a format add a feature without adding a field, but it does so by making old readers wrong on the new values.</strong> A reader written before bit 2 existed sees flag <code>0x04</code>, tests bit 0 (clear), reads one 32-bit count, and carries on with a memory that is really 64-bit. It will not error; it will produce a memory a quarter the intended size.</li>
                </ul>
                <p>That last failure is the sharpest argument for reading flags as bits and validating what you read. A reader that <em>checks</em> the flag against the bits it knows about, and rejects a value with a bit it does not recognise, turns that silent wrong answer into a rejected module. <strong>Reject what you do not understand is the rule; it is the one place where being strict costs nothing, because a module using a feature you have not implemented was never going to run correctly anyway.</strong></p>
                <h3>Why a maximum is optional at all</h3>
                <p>It is tempting to read the optional maximum as laziness in the specification. It is not &mdash; it is a deliberate split of responsibility. <strong>The module says what it needs; the host says what it will give.</strong> A module that writes <code>(memory 2)</code> has declared a minimum of two pages and no ceiling, so it will accept whatever the host hands it, up to the host's own limit. A module that writes <code>(memory 2 8)</code> has asked for a bounded resource, and a host that cannot give it eight pages should refuse at instantiation rather than at validation.</p>
                <p>This is the same division as <a href="/courses/wasm/lessons/wasm-imports">an imported global having no initial value</a>. The file states requirements; the environment supplies resources. And it is why a <code>memory.grow</code> instruction at run time can fail: <strong>the module asked for a minimum and the host said yes, and growth is where the answer can change.</strong> A growth request beyond a declared maximum is a trap, and one beyond the host's limit is a return value rather than an exception, because growing a memory that other code may be reading is not something a runtime can do by force.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The instantiation-time checks, and why each one is a different kind of failure. A host is handed a module and must decide whether to run it, and the tables and memories give it four questions to ask:</p>
                <div class="formula">
for each memory in the module, in index space order:
    if declared_minimum > what_this_host_can_provide:
        reject the module        a resource question, decided by the host

for each table:
    same check

for each import of kind TABLE or MEMORY:
    if the import is SHARED and the host's object is not shared:
        reject                  a type agreement, not a size question
    if the host's object is larger than the declared maximum:
        reject                  the module asked for at most this much

at run time, memory.grow:
    if current + delta > declared_maximum (if any):
        return -1               not a trap: the caller may handle it
    if the host cannot back it:
        return -1               also not a trap
</div>
                <p>Look at the two failure modes at the bottom. <strong>Instantiation failures reject the module; <code>memory.grow</code> failures return a value.</strong> That asymmetry is a design decision about who is in a position to handle the error, and it generalises across the whole format: a <a href="/courses/wasm/lessons/wasm-code">function body</a> that does something invalid traps, because the code cannot be trusted to check; a resource request returns a code, because the code asked and can look.</p>
                <p>And the shared check is the interesting one, because it is a <em>type</em> agreement rather than a size one. A <code>shared</code> import must be satisfied by a <code>shared</code> object, and the reason is a race rather than a budget: the threads proposal makes a shared memory's contents visible to several agents at once, and satisfying a shared import with an unshared object would let the module observe that and reason about it. <strong>The type system is doing a memory-safety job here, which is the first time in this course a type has carried a property that is not about arithmetic.</strong></p>
                <p>One more thing the tables concept has to earn, and the reason the two sections share an encoding. <strong>A table of <code>funcref</code> is the only indirection in the core format</strong>, and that is a security decision as much as a design one. In <a href="/courses/pe/lessons/pe-base-relocations">a native image</a> a function pointer is an address, and storing one is storing the ability to call anything at all &mdash; which is why control-flow integrity is a separate, large feature on native platforms. A WebAssembly table stores an <em>index</em>, and the only thing index <code>n</code> can do is call the function at index <code>n</code>. A table entry cannot be forged into an arbitrary address, so <code>call_indirect</code> through a validated table is a bounded operation.</p>
                <p>That is the deep reason the table exists rather than "so you can have a switch statement". It gives the format a way to express indirect calls that a validator can check, and it is the reason <a href="/courses/coff/lessons/coff-weak-externals">weak externals</a> and table entries feel related: both are about referring to something that may not be there.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ wasm-objdump -x decls.wasm | sed -n '/^Table/,/^Global/p'
$ wasm-objdump -x decls.wasm | sed -n '/^Memory/,/^Global/p'</code></pre>
                <ul>
                    <li><strong>Emit all four limit shapes.</strong> Write a module with <code>(memory 1)</code>, <code>(memory 1 2)</code>, <code>(table 1 funcref)</code> and <code>(table 1 2 funcref)</code> and read all four back. Two flag bytes, two lengths, and seeing them side by side is what makes the "flag is a length" idea stick.</li>
                    <li><strong>Build a reader that ignores the flag bit and watch it desynchronise.</strong> Remove the <code>flags &amp; 0x01</code> test, so it always reads a maximum. Run it on the declarations module and confirm it consumes the memory section's count byte as a maximum and then goes wrong. <strong>A desync that is silent is the worst kind, and producing one on purpose teaches you to recognise it.</strong></li>
                    <li><strong>Find a shared memory.</strong> Write a module using the threads proposal &mdash; <code>(memory 1 1 shared)</code> &mdash; and check whether this wabt accepts it. If it does, read the flags byte and confirm bit 1 is set. If it does not, the rejection message tells you the tool predates the proposal, which is itself a useful data point about what a toolchain supports.</li>
                    <li><strong>Prove the memory64 bit changes the arithmetic.</strong> If your wabt supports <code>memory64</code>, emit one and read the counts. If it does not, hand-build the record with bit 2 set and confirm that <code>wasm-validate</code> rejects it &mdash; which is the correct behaviour, and the rejection is the point.</li>
                    <li><strong>Try to exceed a declared maximum at run time.</strong> Take a module with <code>(memory 1 2)</code> and call <code>memory.grow</code> by 5. The result is a return value, not a trap, and the module keeps running. Confirm both halves, because a host that traps instead of returning has changed the module's semantics.</li>
                    <li><strong>Compile real code and read the memories.</strong> A C program with a large array or an allocator will ask for a memory with a specific minimum. Read it, and then look at the <code>memory.grow</code> calls the compiled code emits. <strong>Seeing that a compiler emits grow loops is what makes the optional maximum make sense</strong> &mdash; it is a dynamic request, not a fixed allocation.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a memory section is the three bytes <code>01 01 02</code>. What do they say, and what does a reader that unconditionally reads both a minimum and a maximum do with the file?</p>
                <div class="quiz" id="quiz-wasm-tables-memories-1">
                    <button class="quiz-option" data-correct="true" data-explain="Every byte is accounted for. The first is the section's entry count, so one memory follows. The second is the limits flag, and 0x01 is bit 0 set, which is the has-a-maximum bit -- so the record is a minimum and a maximum. The third byte is therefore the minimum, 2, and the maximum is whatever follows it, which is the start of the next section. So the record is not two bytes but three, and a reader that assumes a maximum is present after every flag will read the following section's first byte as a maximum and then start the next section one byte late. The desynchronisation is silent, it compounds through the rest of the file, and it is caused by a flag bit that is not a type tag but a length. The general rule is that a bit saying 'more follows' has to be tested before the field is read, and that almost every structure in this format has one." onclick="checkQuiz('quiz-wasm-tables-memories-1', this)">One memory, flags <code>0x01</code> meaning "has a maximum", minimum 2. A reader that always reads a maximum will consume the <em>next</em> section's first byte as the maximum and desynchronise from there on</button>
                    <button class="quiz-option" data-correct="false" data-explain="The flag byte is 0x01 and not 0x04, so this is not a 64-bit memory, and reading the counts as 32-bit is correct here. What is wrong is the claim that the record is complete: with bit 0 set, a maximum follows, and the three bytes shown are count, flags and minimum. The next byte is the maximum, so a reader that treats the record as finished after the minimum will start the following section one byte early. The error is about the length of the record, not the width of its numbers." onclick="checkQuiz('quiz-wasm-tables-memories-1', this)">One memory, flags <code>0x01</code> meaning "64-bit counts", minimum 2 read as a 64-bit LEB128, and a reader that assumes a maximum is present reads one byte too few</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your runtime loads a module from a toolchain you do not recognise. It reports the module as valid, allocates a memory, and the program then behaves as if it had a quarter of the address space it was written for &mdash; writing past the end of what it thinks is a page, into memory the host never gave it, with no error. Everything else in the module decodes correctly. What is the most likely cause, and what is the one-line change that would have turned this into a clean rejection?</p>
                <div class="quiz" id="quiz-wasm-tables-memories-2">
                    <button class="quiz-option" data-correct="true" data-explain="The symptom pins it down unusually well. A memory a quarter the intended size is exactly what you get when a 64-bit count is read as 32-bit, since a 64-bit value with a small magnitude still has its low four bytes read and the rest left in the stream for the next field. Nothing else in the module being correct is consistent with a bug in the expression evaluator or the type checker, both of which would break far more than one limit. The one-line fix is to validate the flag against the bits the reader knows about and reject anything with an unrecognised bit set, which is the difference between rejecting a module you cannot correctly interpret and silently misinterpreting one. That rule is worth more than the specific fix: for an untrusted input, a format that grows new features into a spare bit will hand you exactly this situation eventually, and the only defence is to insist on knowing every bit you are about to act on." onclick="checkQuiz('quiz-wasm-tables-memories-2', this)">The module uses a 64-bit memory, and your reader treats the limits flags as an enum so bit 2 is unhandled: it reads 32-bit counts and allocates a quarter of the intended memory. Reject any flag byte containing a bit your reader does not implement</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is worth ruling out and it is a reasonable first guess, but the quarter-size symptom is specific in a way that an ordinary bitfield bug is not. Any mishandling of the shared or maximum bits changes the number of counts or their meaning, not their width. A 64-bit count read as 32-bit produces exactly a factor-of-four address space, and the program then indexes past the end of a real page into memory the host did not allocate, which is the described behaviour." onclick="checkQuiz('quiz-wasm-tables-memories-2', this)">The module declares a shared memory and your host does not support threads, so the memory is silently allocated unshared</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: on untrusted input, reject any bit you do not understand rather than ignoring it. A spare bit in a flag is a promise that someone will eventually use it, and your reader is the thing that has to notice.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The limits record is the WebAssembly version of something every executable format has to express, and the comparison makes the differences legible. <a href="/courses/pe/lessons/pe-section-table">A PE section's <code>VirtualSize</code> and <code>SizeOfRawData</code></a> are a required size and an allocated size, and the two may differ. <a href="/courses/elf/lessons/program-header-table">An ELF program header's <code>p_memsz</code> and <code>p_filesz</code></a> are the same idea: what the program will use, and how much of it is in the file. WebAssembly's limits record is the degenerate case, where there is no file backing at all &mdash; every page is zero until written.</p>
                <p>What is new here is the <em>optional</em> maximum, and that has no counterpart in those formats. A PE section and an ELF segment are bounded by the file; a WebAssembly memory is bounded by the host, and the module states a preference rather than a requirement. <strong>It is the same division of responsibility as an imported global having no initial value</strong>, and it is why a module can be written once and run in a browser tab and in a 512&nbsp;MB sandbox without either of them being wrong.</p>
                <p>The flag-as-length pattern connects to <a href="/courses/wasm/lessons/wasm-leb128">LEB128</a> and to <a href="/courses/wasm/lessons/wasm-code">the body size field</a>, and to the same idea in <a href="/courses/dwarf/lessons/dwarf-loclists">the DWARF <code>offset_entry_count</code></a>, where a count determines the shape of everything after it. The recurring lesson is that a field which is a count, a size, or a "more follows" bit is not a field you can read and forget &mdash; it is the field that tells you what the reader's position should be afterwards. <strong>Position is derived, and these are the fields that derive it.</strong></p>
                <p>The security point about tables is a good one to carry into the <a href="/courses/wasm/lessons/wasm-elements">element section</a>, which is what fills them. A table is only as safe as its initial contents and as the checks a <code>call_indirect</code> performs, and the element section is where the initial contents come from &mdash; which is eight different encodings, and the reason is a long history of proposals.</p>
                <p>Next: <a href="/courses/wasm/lessons/wasm-globals">Globals and Initialisers</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/wasm/lessons/wasm-imports">Previous: Imports and Index Spaces</a></span>
                <span><a href="/courses/wasm/lessons/wasm-globals">Next: Globals and Initialisers</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
