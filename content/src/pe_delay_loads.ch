// PE Course — Concept 15: Delay-Load Imports.
// Eager versus lazy DLL binding, the delay descriptor, and the runtime helper.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_delay_loads() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Delay-Load Imports — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>Delay-Load Imports</h1>
            <div class="lesson-meta">15 min · Module 5: Imports &amp; Exports · Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every DLL in the ordinary import directory is mapped and resolved before your entry point runs — even the one used only by a rarely-taken error path. That costs startup time, and it makes an optional dependency fatal: if the DLL is absent, the process fails to launch, whether or not your program ever needed it.</p>
                <p>Delay-load imports change both facts. The spec states the purpose directly: the tables were added "to support a uniform mechanism for applications to delay the loading of a DLL until the first call into that DLL". Startup gets faster, an unused optional DLL is never opened, and a missing DLL turns a launch failure into a first-call failure. For anyone analyzing binaries it also matters that this second import machinery exists at all — a file can carry two parallel sets of import information, and only one of them is walked by the loader at process start.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Compare the two schemes:</p>
                <ul>
                    <li><strong>Eager (ordinary imports).</strong> The OS loader reads directory index 1, loads each DLL, fills the IAT. Cost is paid at process start, every time.</li>
                    <li><strong>Lazy (delay-loads).</strong> The delay IAT slots start out pointing at stubs generated into your own image. The first call lands in the helper, the helper loads the DLL, resolves the symbol, rewrites the slot to the real address, and jumps through it. Every later call goes straight to the function.</li>
                </ul>
                <p>The descriptor mirrors the ordinary import descriptor: a DLL name RVA, a name table (like the ILT), an address table (like the IAT), plus fields the ordinary table does not need — a place to store the DLL's module handle, and an unload table used to undo everything.</p>
                <p>The model's missing piece: the OS loader does not read this table. The helper linked into your image does, at call time. That is the entire point — resolution work moves from "always, at startup" to "only if used, on first call".</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Data directory index 13 (Delay Import Descriptor) points to an array of 32-byte descriptors. The spec's layout:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Size</th><th scope="col">Field</th><th scope="col">What it says</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>4</td><td>Attributes</td><td>Bit 0 is <code>RvaBased</code>; all other bits reserved and must be zero</td></tr>
                        <tr><td>4</td><td>4</td><td>Name</td><td>RVA of the ASCII DLL name to delay-load</td></tr>
                        <tr><td>8</td><td>4</td><td>Module Handle</td><td>RVA of an HMODULE slot in .data where the helper stores the loaded module</td></tr>
                        <tr><td>12</td><td>4</td><td>Delay Import Address Table</td><td>RVA of the delay IAT the helper patches with real entry points</td></tr>
                        <tr><td>16</td><td>4</td><td>Delay Import Name Table</td><td>RVA of the delay INT — same layout as the ordinary import lookup table</td></tr>
                        <tr><td>20</td><td>4</td><td>Bound Delay Import Table</td><td>Optional RVA of a pre-bound thunk table</td></tr>
                        <tr><td>24</td><td>4</td><td>Unload Delay Import Table</td><td>Optional RVA of a pristine copy of the delay IAT, for unload</td></tr>
                        <tr><td>28</td><td>4</td><td>Time Stamp</td><td>Timestamp of the DLL this image was bound to</td></tr>
                    </tbody>
                </table>
                <p>The <strong>Attributes</strong> bit is the compatibility hinge. In <code>winnt.h</code> the field is <code>IMAGE_DELAYLOAD_DESCRIPTOR.Attributes</code> whose low bit is <code>RvaBased</code>; in <code>delayimp.h</code> it is <code>grAttrs</code> with the <code>dlattrRva</code> flag (value <code>0x1</code>). When set, every address field above is an RVA — the form Visual C++ 7.0 and later emit. When clear, those fields are raw virtual addresses (the pre-VC7 form), and a reader must interpret them differently. The data directory's Size tells you how many descriptors there are, and readers also stop at an all-zero descriptor, the same convention as the ordinary import directory.</p>
                <p>The unload table exists because the process can unbind: on an unload request the helper frees the DLL, clears the module handle, and copies the unload table back over the delay IAT so subsequent calls fall into the thunks again instead of jumping into a freed module.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> "Delay-loading hides the import." It does not. The DLL name and every function name still sit in the file as plain strings in the name table, and a zero Attributes or directory entry is easy to spot — static analysis sees delay-loads as clearly as ordinary imports. The real difference is <em>when</em> and <em>whether</em> resolution happens: cost and failure move from process start to first call. Also do not confuse it with hand-written <code>LoadLibrary</code>/<code>GetProcAddress</code> code, which records no static table at all.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Neither sample image delay-loads anything. In <code>cli-64.exe</code> and <code>conpty.dll</code>, data directory index 13 is all zeros:</p>
                <div class="hex-dump">
                    <pre>cli-64.exe:
Entry d 0000000000000000 00000000 Delay Import Directory

conpty.dll:
Entry d 0000000000000000 00000000 Delay Import Directory</pre>
                </div>
                <p>That is the honest state of most ordinary binaries — delay-loading only exists when the linker is asked for it (the MSVC linker's <code>/DELAYLOAD:dllname.dll</code> switch, whose helper ships in <code>delayimp.h</code>/<code>delayimp.lib</code>). So this lesson's example is the structure itself, taken from the spec above. Picture one descriptor for a hypothetical <code>PRINTER.dll</code> with four imported names: Attributes <code>0x00000001</code> (RVA-based), Name pointing at the string <code>PRINTER.dll</code> in read-only data, Module Handle pointing at an eight-byte zero in .data, Delay IAT holding four slots that currently contain helper-stub addresses, Delay INT holding four thunk entries exactly like ordinary ILT entries (hint/name RVAs or the ordinal flag), Bound and Unload tables zero, Time Stamp zero.</p>
                <p>Reading that descriptor tells you: nothing has been loaded yet, the helper knows where to write the four resolved addresses, and the ordinary import directory (index 1) will show none of these four symbols — they live only here.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Check any PE for a delay directory in one command:</p>
                <pre><code>$ objdump -p cli-64.exe | grep "Delay Import"
Entry d 0000000000000000 00000000 Delay Import Directory</code></pre>
                <p>Or read data directory index 13 directly. The data directories start at optional-header offset 112 in PE32+, and each entry is 8 bytes, so index 13 sits at offset <code>112 + 13*8</code> = 216:</p>
                <pre><code>$ python3 -c "import struct;d=open('cli-64.exe','rb').read();e=struct.unpack_from('&lt;I',d,0x3c)[0];oh=e+24;rva,sz=struct.unpack_from('&lt;II',d,oh+112+13*8);print(hex(rva),hex(sz))"
0x0 0x0</code></pre>
                <p>Swap in a binary built with <code>/DELAYLOAD</code> and both numbers become non-zero; then walk the descriptor array <code>rva</code>-by-32-bytes until an all-zero row, and you have the list of deferred DLLs.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what does bit 0 of the delay descriptor's Attributes field decide?</p>
                <div class="quiz" id="quiz-delay-1">
                    <button class="quiz-option" data-correct="false" data-explain="Import-by-ordinal is a property of individual thunk entries (the high bit of each 8-byte slot), not of the descriptor header." onclick="checkQuiz('quiz-delay-1', this)">Whether the symbols are imported by ordinal instead of by name</button>
                    <button class="quiz-option" data-correct="true" data-explain="Bit 0 is RvaBased (dlattrRva = 0x1). Set means the Name, Module Handle, Delay IAT, Delay INT, Bound and Unload fields are RVAs; clear means they are raw virtual addresses, the pre-VC7 form." onclick="checkQuiz('quiz-delay-1', this)">Whether the descriptor's address fields hold RVAs or raw virtual addresses</button>
                    <button class="quiz-option" data-correct="false" data-explain="Whether the DLL has already been loaded is runtime state, recorded in the Module Handle slot at run time, not a static attribute bit." onclick="checkQuiz('quiz-delay-1', this)">Whether the DLL is already loaded</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You open a PE and data directory index 13 reads <code>VirtualAddress = 0</code>, <code>Size = 0</code>. What can you conclude?</p>
                <div class="quiz" id="quiz-delay-2">
                    <button class="quiz-option" data-correct="false" data-explain="Delay-load descriptors are only present when the linker was given /DELAYLOAD. Ordinary imports live in index 1 and are unaffected." onclick="checkQuiz('quiz-delay-2', this)">Every import in the file is delay-loaded instead</button>
                    <button class="quiz-option" data-correct="true" data-explain="An empty directory entry (both address and size zero) means the image declares no delay-load descriptors. Its DLLs are resolved eagerly through the ordinary import directory." onclick="checkQuiz('quiz-delay-2', this)">The image declares no delay-loaded imports</button>
                    <button class="quiz-option" data-correct="false" data-explain="A zero VirtualAddress is not a valid RVA to a hidden table; with Size also zero there is nothing to walk." onclick="checkQuiz('quiz-delay-2', this)">The delay table exists at RVA 0 in the headers</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: an empty data directory entry means "this feature is absent", not "look harder". Every PE table in this course is announced by an address/size pair — read the pair first.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Imports, exports, and delay-loads all assume the image loads exactly where the linker put it — ImageBase <code>0x140000000</code> in our exe. Windows would rather randomize that address, and the addresses baked into .data and .text break the moment it moves. Module 6 starts with the table that repairs them.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-base-relocations">Base Relocations</a> — the .reloc blocks that make ASLR possible.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-exports">Previous: The Export Tables</a></span>
                <span><a href="/courses/pe/lessons/pe-base-relocations">Next: Base Relocations</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
