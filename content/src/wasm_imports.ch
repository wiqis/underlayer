// WebAssembly Course — Module 2: Declarations
// Concept: the import section — the per-kind body, and the rule that decides
// which number a function has.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_wasm_imports() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Imports and Index Spaces — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson wasm-lesson">
            <a href="/courses/wasm" class="back-link">Back to course</a>
            <h1>Imports and Index Spaces</h1>
            <div class="lesson-meta">22 min &middot; Module 2: Declarations &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every function, table, memory and global a WebAssembly module can refer to has a number, and those numbers are the format's only name. <strong>What decides a thing's number is not where it is declared but whether it is imported</strong>, and that one rule explains more about the format than anything else in this module.</p>
                <p>Imports come before definitions in the section order, and they come before definitions in the <em>index space</em> too. A module that imports one function and defines two has three functions, numbered 0, 1 and 2, and the two it defined are 1 and 2 &mdash; <strong>not</strong> 0 and 1. The same rule holds independently for tables, memories and globals, each with its own numbering.</p>
                <p>It is worth understanding why a format would do this rather than number definitions first. An import is a claim about something outside the module, and a definition is a claim inside it. Putting the outside claims first means <strong>every index below the import count is guaranteed to exist, and everything above it is something the module can prove.</strong> A validator can check the boundary once and know the provenance of every subsequent number. It is the same reasoning as a <a href="/courses/elf/lessons/relocation-entries">linker's</a> symbol resolution order, and it is why the rule is not negotiable from a reader's point of view even though a producer could have chosen otherwise.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The section's shape, and the part that trips people:</p>
                <div class="formula">
imports:
    count                       how many imports follow

import, repeated `count` times:
    module_name                 a length-prefixed name, e.g. "env"
    field_name                  a length-prefixed name, e.g. "log"
    kind                        ONE byte: 0 func, 1 table, 2 memory,
                                           3 global, 4 tag
    ...and then a body that DEPENDS ON kind
</div>
                <p><strong>The last line is the whole difficulty.</strong> What follows the kind byte is a different structure for each kind, and a reader that treats it uniformly will read a limits flag as a type index and produce a plausible nonsense:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Kind</th><th scope="col">Body</th><th scope="col">Shape</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0 func</td><td>type index</td><td>one LEB128 &mdash; the smallest body in the format</td></tr>
                        <tr><td>1 table</td><td>element type + limits</td><td>a valtype byte, then a limits record</td></tr>
                        <tr><td>2 memory</td><td>limits</td><td>just a limits record</td></tr>
                        <tr><td>3 global</td><td>value type + mutability</td><td>two bytes &mdash; note: no initialiser, because the host supplies the value</td></tr>
                    </tbody>
                </table>
                <p>That third row deserves a sentence of its own. An imported global has <em>no</em> initial value in the file, and a <code>global.get</code> of it before the host sets it is a trap the validator cannot catch. The host owns the initial contents of everything it imports, which is the entire point of importing it.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Three imports of three different kinds in a thirty-five byte section. Here are all of them:</p>
                <div class="hex-dump">
                    <pre>001c: 03 03 65 6e 76 03 6c 6f 67 00 02 03 65 6e 76 05
002c: 74 61 62 6c 65 01 70 00 01 03 65 6e 76 02 67 76
003c: 03 7f 00
</pre>
                </div>
                <p>Walk all three, because the point of the exercise is that they are three different structures:</p>
                <div class="hex-dump">
                    <pre>03                    THREE imports

import 0 -- a function
  03 65 6e 76           module "env"
  03 6c 6f 67           field  "log"
  00                   kind 0: FUNC
  02                   type index 2

import 1 -- a table
  03 65 6e 76           module "env"
  05 74 61 62 6c 65     field  "table"
  01                   kind 1: TABLE
  70                   element type: funcref
  00                   limits flags: minimum only
  01                   minimum = 1

import 2 -- a global
  03 65 6e 76           module "env"
  02 67 76              field  "gv"
  03                   kind 3: GLOBAL
  7f                   value type: i32
  00                   mutability: const
</pre>
                </div>
                <p>Three bodies, three shapes, and the sizes alone would let you tell them apart: 10 bytes, 14 bytes, and 10 bytes. Now the consequence that matters more than any of the bytes, which is what this does to the numbering.</p>
                <h3>What the imports do to every other number</h3>
                <p>The same module also declares two functions, a table, a memory and two globals. wabt's own reading of the whole module, which numbers everything in the global index space:</p>
                <pre><code>Import[3]:
 - func[0]   sig=2 &lt;env.log&gt;
 - table[0]  type=funcref initial=1 &lt;env.table&gt;
 - global[0] i32 mutable=0 &lt;env.gv&gt;
Function[2]:
 - func[1]   sig=0 &lt;add&gt;
 - func[2]   sig=1
Table[1]:
 - table[1]  type=funcref initial=4
Memory[1]:
 - memory[0] pages: initial=2 max=8
Global[2]:
 - global[1] i32 mutable=0 - init i32=42
 - global[2] i64 mutable=1 - init i64=-1
Export[3]:
 - func[1] &lt;add&gt; -&gt; "add"
 - memory[0] -&gt; "mem"
 - global[0] -&gt; "gv"</code></pre>
                <p>Read the numbers and the rule is visible without being told:</p>
                <ul>
                    <li><strong>Functions:</strong> the import is <code>func[0]</code>, so the two defined functions are <code>func[1]</code> and <code>func[2]</code>. The export <code>"add"</code> points at <code>func[1]</code> &mdash; index 1, not 0.</li>
                    <li><strong>Tables:</strong> the import is <code>table[0]</code>, so the defined table is <code>table[1]</code>.</li>
                    <li><strong>Globals:</strong> the import is <code>global[0]</code>, so the two defined globals are <code>global[1]</code> and <code>global[2]</code>. And the export <code>"gv"</code> exports <strong><code>global[0]</code></strong>, which is the <em>imported</em> one &mdash; the module is re-exporting something the host gave it, which is legal and is how a wrapper library forwards a capability.</li>
                    <li><strong>Memories:</strong> no memory was imported, so the defined memory is <code>memory[0]</code>. The numbering is unaffected, because there was nothing to offset it.</li>
                </ul>
                <div class="callout callout-warn">
                    <strong>Four independent counters, not one.</strong> The mistake here is to assume a single numbering scheme. There are <strong>five</strong> separate index spaces &mdash; functions, tables, memories, globals and tags &mdash; and each counts its own imports first. A module can have <code>func[0]</code> be an import while <code>table[0]</code> is a definition, and there is no relationship between the two counters. A reader that keeps "the next number" in a single variable will be correct on the first kind it meets and wrong on the second, which is the most annoying possible failure: it works on simple modules and breaks on the first real one.
                </div>
                <h3>Why the count is the boundary</h3>
                <p>Because imports are counted first and definitions second, the import section's <em>count</em> is a boundary in every index space, and the boundary for each space is the number of imports <em>of that kind</em>. In this module:</p>
                <div class="hex-dump">
                    <pre>  functions   1 imported  ->  func[0]     is imported
  tables      1 imported  ->  table[0]    is imported
  memories    0 imported  ->  memory[0]   is a definition
  globals     1 imported  ->  global[0]   is imported
</pre>
                </div>
                <p>That is the property a validator exploits. It can read the import section, note that <code>func[0]</code> must be supplied by the host, and then treat every index it meets &ge; the count as something the module itself has to define. <strong>A number below the boundary is someone else's problem; a number above it is this module's.</strong> And the count also gives a free existence check: an export or a <code>call</code> naming an index below the boundary is referring to an import, which is legal, while one naming an index at or above the boundary for something that was never defined is a validation error.</p>
                <p>That is a real structural property, not a convenience. It means <strong>a validator can answer "is this index valid" without having read the whole module</strong>, for the lower half of every space, and it is the same kind of separation that lets a module be linked in stages: resolve the imports, and the definitions become a self-contained unit with a known base.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Resolving a <code>call</code>, which is the operation that makes the whole rule matter. A <code>call</code> instruction carries a function index, and the job is to turn that number into something executable:</p>
                <div class="formula">
resolve_call(module, index):
    imported = count imports of kind FUNC in the import section

    if index &lt; imported:
        # the number names something the HOST provides
        return module.imports[func_position_of(index)]

    # the number names a definition in this module
    local_index = index - imported
    if local_index &gt;= number of entries in the function section:
        error: call to a function that does not exist
    return module.function_bodies[local_index]
</div>
                <p>Two things in that are easy to get wrong, and both are silent. <strong>The subtraction is not optional</strong> &mdash; a reader that forgets it will resolve a call to the wrong function, and since the body count usually exceeds the import count the wrong function is usually a real one, so nothing complains. And <strong>the per-kind count matters</strong>: a module that imports three functions and one table has an imported function count of 3 and an imported table count of 1, and a reader that used one number for both would be off by two on every table reference after the first.</p>
                <p>That failure is worth spelling out because it is invisible in the common case. Write a module with no imports at all: the counts are all zero, the subtraction is a no-op, and a reader with no offset logic passes every test you can write. Add <em>one</em> import and every <code>call</code> in the module starts pointing one function too low &mdash; at a valid function, of a valid signature, which is why the module keeps working until something happens to make the wrong answer visible. <strong>A bug that only appears when you add data is a bug your test suite was not built to find, and the way to build for it is to test the smallest case and the boundary case, not the middle.</strong></p>
                <p>The same structure, with the kind byte selecting which counter to use, is what an <code>export</code> needs &mdash; and it is why the export section's kind byte is the mirror of the import section's. An export says "this name refers to <em>that kind</em>, at <em>that number</em>", and the two fields together pick the index space. The export of <code>"gv"</code> as <code>global[0]</code> in this module is a case where the number is below the boundary, so it names an import; exporting a definition would have said <code>global[1]</code>.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ wasm-objdump -x decls.wasm | sed -n '/^Import/,/^Function/p'
$ python3 courses/wasm/assets/samples/wasm_decode.py --hex decls.wasm</code></pre>
                <ul>
                    <li><strong>See the offset appear and disappear.</strong> Compile a module with no imports, then with one, then with five, and read the same <code>call</code> instruction each time. The opcode is identical and the index is identical; what changes is which function it names. <strong>That is the entire lesson, and three compiles is all it costs.</strong></li>
                    <li><strong>Build a reader with one shared counter and watch it break.</strong> Extend the decoder so it keeps a single "next index" across kinds, and run it on <code>decls.wasm</code>. It will be correct for the first kind it encounters and wrong for the second, which is exactly the failure signature that makes this bug so hard to find. Then fix it with five separate counters and confirm.</li>
                    <li><strong>Make the per-kind boundary visible.</strong> Import three functions and one table. Then check that a <code>table</code> instruction naming <code>table[0]</code> refers to the import while a <code>func</code> instruction naming <code>func[0]</code> refers to a different one. Two index spaces, two different meanings for the same number, one module.</li>
                    <li><strong>Re-export an import.</strong> Take this module's <code>"gv"</code> export, which forwards the host's global, and rename the local one too. Confirm both appear and that their indices are <code>global[0]</code> and <code>global[1]</code>. Forwarding a capability by re-exporting it is a common and useful pattern, and it is only possible because the index spaces are explicit.</li>
                    <li><strong>Count every kind separately from the bytes.</strong> Write a five-line program that reads the import section and prints a per-kind count, then compare against <code>wasm-objdump -x</code>. It is a tiny program and it is the exact thing a validator does first, so building it teaches the order the format expects a consumer to work in.</li>
                    <li><strong>Find a module that reorders things.</strong> Compile a large C++ file and look for a module where the import count is high and the function count is higher. Then check whether any <code>call</code> in the code section names an index below the import count &mdash; it should, if the module calls an imported function, and that is the ordinary case rather than an oddity.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a module imports two functions, one table, zero memories and one global. It then defines three functions, one table, one memory and two globals. What are the indices of the defined memory and of the third defined function, and what does the exported index <code>0</code> in the global space refer to?</p>
                <div class="quiz" id="quiz-wasm-imports-1">
                    <button class="quiz-option" data-correct="true" data-explain="Three independent counters, each offset by the imports of its own kind. Memories had no imports, so the defined memory is memory[0] and the subtraction is a no-op. Functions had two imports, so the third defined function is func[2 + 2] = func[4]. And global index 0 is below the one imported global, so it names the import rather than a definition, which is the re-export case: a module may export something the host gave it. The asymmetry between memory and function here is the whole point of separate counters, and a reader that used a single shared count would get the memory right by accident and the function wrong by two." onclick="checkQuiz('quiz-wasm-imports-1', this)">The memory is <code>memory[0]</code> (no imports to offset it), the third defined function is <code>func[4]</code> (2 imports + 2 previous definitions), and global index 0 is the <em>imported</em> global &mdash; the module is re-exporting it</button>
                    <button class="quiz-option" data-correct="false" data-explain="The function index is wrong: with two imported functions, the defined ones start at 2, so the third defined function is func[4], not func[2]. The memory is right and the re-export is right, which is the shape this error usually takes -- correct for kinds that happen not to be offset, wrong for the kind that is. Both facts come from the same rule applied per kind, and getting one of them right by luck is not evidence the other is right." onclick="checkQuiz('quiz-wasm-imports-1', this)">The memory is <code>memory[0]</code>, the third defined function is <code>func[2]</code>, and global index 0 is the imported global, which the module re-exports</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your tool links a module by replacing calls to imported functions with the module's own. It works on small modules. On a large one, several functions return values that belong to entirely different functions &mdash; plausible values, right types, wrong answers &mdash; and only for modules that import anything. Modules with no imports are fine, which is the clue. Nothing errors and the module is valid. What is the defect, and what is the shortest test that would have caught it before a user did?</p>
                <div class="quiz" id="quiz-wasm-imports-2">
                    <button class="quiz-option" data-correct="true" data-explain="The evidence is decisive and points at one thing. The failure requires an import to exist, which means the resolver is not subtracting the import count, so every local function index is shifted down by however many functions were imported. Small modules have few local functions, so a shift of one usually lands on nothing or on a trivially simple function and the damage is invisible; large modules have many, so a shift lands on a plausible neighbour and returns a plausible wrong answer. That is why the bug scales with module size and why the type system cannot catch it, since the call sites are well-typed either way. The cheapest test that would have found it is a differential one rather than a unit one: link the same source with and without an import, and assert the two linked results are identical. A unit test of the resolver in isolation tests the arithmetic against itself; a differential test tests it against reality, and the import is precisely the thing that makes the two paths differ. The general habit is that when a bug appears only when some optional structure is present, the missing branch is almost always the one that handles it." onclick="checkQuiz('quiz-wasm-imports-2', this)">The resolver is not subtracting the import count, so every local function index is shifted by the number of imported functions. The cheapest test is differential: link the same source with and without an import and assert the results are identical</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a real class of bug and it is worth ruling out, but the evidence points elsewhere. A mis-parsed signature would produce wrong behaviour regardless of whether the module imports anything, and the observed dependence on imports is the whole clue. It is also not a parser bug here: the module is valid, the signatures parse, and the calls are well-typed. What is wrong is a number after parsing, which is the import offset." onclick="checkQuiz('quiz-wasm-imports-2', this)">Your reader mis-parses the import section's per-kind body, so the limits flag byte is read as a type index and the types are wrong</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a bug only appears when an optional structure is present, find the branch that handles that structure. And prefer a differential test to a unit test &mdash; comparing two runs that should agree catches what comparing a function to itself cannot.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The index-space rule is the WebAssembly member of a family this collection has met twice. In <a href="/courses/pe/lessons/pe-imports">the PE import directory</a> and in <a href="/courses/elf/lessons/dynamic-section">ELF's dynamic symbol table</a>, the same problem appears in a different shape: a module refers to an external symbol by name at link time and by index at load time, and the loader has to build the mapping. WebAssembly inverts it &mdash; the index is the only reference that survives, and the name is resolved before the file is ever used.</p>
                <p>That inversion is what makes a WebAssembly module self-contained in a way an ELF object is not. An object file is full of undefined symbols and meaningless without a link step; a WebAssembly module is fully resolved except for its declared imports, and those are named explicitly with a module and field. <strong>The format chose to make the unresolved set explicit and small, rather than implicit and large</strong>, which is the same trade <a href="/courses/coff/lessons/coff-archives">a <code>.lib</code> archive</a> makes by carrying a symbol index so a linker can find a member without opening every member.</p>
                <p>The per-kind bodies connect to the <a href="/courses/wasm/lessons/wasm-types">type section</a> and the <a href="/courses/coff/lessons/coff-section-table">COFF section characteristics</a>. In both cases a single-byte tag selects among several record shapes, and in both cases a reader that ignores the tag will not fail loudly &mdash; it will read a byte from one structure as if it belonged to another. The reason a tag exists at all is that the format cannot be extended by adding a new structure type without one, and that is a lesson worth carrying to any format you meet next.</p>
                <p>One more thing the import section sets up, which the last module of this course returns to: <strong>an imported global has no initial value in the file.</strong> The host owns it. That is a small fact and it is the cleanest example in the format of the difference between what a file can express and what it deliberately leaves to somebody else &mdash; the same division the object format draws when it puts a linking section in a custom section the core specification knows nothing about.</p>
                <p>Next: <a href="/courses/wasm/lessons/wasm-tables-memories">Tables, Memories and Limits</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/wasm/lessons/wasm-types">Previous: The Type Section</a></span>
                <span><a href="/courses/wasm/lessons/wasm-tables-memories">Next: Tables, Memories and Limits</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
