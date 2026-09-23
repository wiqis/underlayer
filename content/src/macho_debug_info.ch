// Mach-O Course — Concept 20: Debug Info.
// dSYM companion bundles, the LC_UUID join, and what the shipped binary keeps.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_debug_info() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Debug Info — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>Debug Info</h1>
            <div class="lesson-meta">15 min · Module 7: Integrity &amp; Debug</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A crash report hands you an address — 0x100000450, say. That tells a machine exactly where you died and tells a human nothing. Turning addresses into "main() at prog.c:8" is the whole point of debug info, and Mach-O makes a deliberate choice about where that mapping lives: shipping full DWARF inside every binary would bloat the file and expose internals, so the format splits it in half.</p>
                <p>The split defines a workflow every macOS and iOS crash report assumes: the binary on the device and a <em>dSYM bundle</em> on the developer's disk are two halves of one artifact, joined by a 16-byte key the linker wrote into both. Get the join wrong and symbolication maps every address to the wrong source line — quietly, confidently, worse than having no symbols at all.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three pieces:</p>
                <ol>
                    <li><strong>The shipped binary.</strong> Code, the plain symbol table, and load commands — including <code>LC_UUID</code> and two small unwinding aids, <code>LC_FUNCTION_STARTS</code> and <code>LC_DATA_IN_CODE</code>. No DWARF.</li>
                    <li><strong>The dSYM bundle.</strong> A directory whose <code>Contents/Info.plist</code> names the target and whose <code>Contents/Resources/DWARF/</code> holds a file carrying all the debug sections.</li>
                    <li><strong>The join.</strong> <code>dsymutil</code> builds the bundle from a linked binary; every consumer — <code>dwarfdump</code>, <code>atos</code>, <code>lldb</code> — trusts a bundle only when its UUID matches the binary's.</li>
                </ol>
                <p>The model's missing piece: the UUID proves <em>identity</em>, not quality. It says "this bundle came from this exact link" — nothing more. A complete, honest dSYM from the wrong build is still useless, and the UUID is the only thing stopping tools from silently using it.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Three spec facts decide how the split works:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Mechanism</th><th scope="col">What the spec says</th><th scope="col">Effect</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>LC_UUID (0x1b)</td><td><code>uuid_command</code>: "a single 128-bit unique random number that identifies an object produced by the static link editor"</td><td>The join key — identical in binary and dSYM, one UUID per thin slice</td></tr>
                        <tr><td>S_ATTR_DEBUG (0x02000000)</td><td>"The static linker will not copy section contents from sections with this attribute into its output file. These sections generally contain DWARF debugging info."</td><td>The main binary is <em>designed</em> never to carry DWARF sections — this is format policy, not disk-space thrift</td></tr>
                        <tr><td>N_STAB (0xE0)</td><td><code>nlist.h</code>: "if any of these bits set, a symbolic debugging entry" — the actual codes live in <code>stab.h</code></td><td>The older path: debug entries stored inside the LC_SYMTAB symbol table itself, the data <code>strip</code> historically removed</td></tr>
                    </tbody>
                </table>
                <p>What the shipped half keeps instead: <code>LC_UUID</code>, a plain <code>LC_SYMTAB</code> (no line tables), and two <code>linkedit_data_command</code> blobs whose payloads sit in __LINKEDIT — <code>LC_FUNCTION_STARTS</code>, a ULEB128 delta stream of function entry addresses, enough to walk frames without a single line of DWARF; and <code>LC_DATA_IN_CODE</code>, a DICE table marking non-instruction ranges inside __text (each entry: offset, size, kind).</p>
                <div class="callout callout-warn">
                    <strong>Honest scope.</strong> Our samples were built without <code>-g</code>: <code>llvm-dwarfdump</code> reports an empty <code>.debug_info</code> in both <code>prog64.macho</code> and <code>prog64.o</code>. What we verify end-to-end here — UUIDs, the bundle structure <code>dsymutil</code> produces, the function-starts stream — is precisely the join mechanism a <code>-g</code> build fills with line tables.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The UUIDs of our samples, read from their load commands and from <code>--uuid</code>:</p>
                <table>
                    <thead>
                        <tr><th scope="col">File</th><th scope="col">Slice</th><th scope="col">UUID</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>prog64.macho</td><td>x86_64</td><td>4C4C44C9-5555-3144-A19F-1D5685FC622F</td></tr>
                        <tr><td>universal.macho</td><td>x86_64</td><td>4C4C44C9-5555-3144-A19F-1D5685FC622F</td></tr>
                        <tr><td>universal.macho</td><td>arm64</td><td>4C4C44B1-5555-3144-A130-3397BCE0A53C</td></tr>
                        <tr><td>libasyncProfiler.dylib</td><td>x86_64</td><td>DA4AFC52-D48E-39AB-B574-FE3B9CC5232F</td></tr>
                    </tbody>
                </table>
                <p>A universal file carries one <code>LC_UUID</code> <em>per thin Mach-O inside it</em> — two UUIDs from one dump, because there are two complete linked binaries in the container, and each needs its own dSYM pairing.</p>
                <p>The other half of crash recovery ships inside the binary. <code>LC_FUNCTION_STARTS</code> points at 8 bytes (dataoff 12440):</p>
                <div class="hex-dump">
                    <pre>00003098: 9008 3010 0000 0000                      ..0.....</pre>
                </div>
                <p>ULEB128 deltas from the image base: 0x410, 0x30, 0x10, then a zero terminator. Walked from 0x100000000 they land on 0x100000410 (<code>_add</code>), 0x100000440 (<code>_helper</code>), 0x100000450 (<code>_main</code>) — exactly what <code>nm</code> prints. Even with zero DWARF, an unwinder knows where every function starts.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Build the join yourself — on macOS the tools are <code>dsymutil</code> and <code>dwarfdump</code>; LLVM ships them as <code>dsymutil</code> and <code>llvm-dwarfdump</code>:</p>
                <pre><code>$ llvm-dwarfdump --uuid prog64.macho
UUID: 4C4C44C9-5555-3144-A19F-1D5685FC622F (x86_64) prog64.macho

$ dsymutil prog64.macho -o prog64.dSYM
warning: no debug symbols in executable (-arch x86_64)

$ llvm-dwarfdump --uuid prog64.dSYM
UUID: 4C4C44C9-5555-3144-A19F-1D5685FC622F (x86_64) prog64.dSYM/Contents/Resources/DWARF/prog64.macho</code></pre>
                <p>What to look for: the same UUID on both sides — that <em>is</em> the join. The warning is the honest part: this binary has no DWARF to copy, yet the bundle still gets its <code>Contents/Info.plist</code> and <code>Contents/Resources/DWARF/</code> skeleton — the same skeleton a <code>-g</code> build fills with line tables. Then try <code>--uuid universal.macho</code> and count the UUIDs.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: in the shipped-app workflow, where does the DWARF actually live, and what joins it to the running binary?</p>
                <div class="quiz" id="quiz-dbg-1">
                    <button class="quiz-option" data-correct="false" data-explain="That is the ELF convention. In Mach-O the static linker refuses to copy S_ATTR_DEBUG section contents into its output, so the main binary ships without DWARF sections by design." onclick="checkQuiz('quiz-dbg-1', this)">Inside the main binary as .debug sections, ELF-style</button>
                    <button class="quiz-option" data-correct="true" data-explain="The DWARF lives in a dSYM companion bundle under Contents/Resources/DWARF, and LC_UUID — the same 16 bytes in both artifacts — is the join key every consumer checks before trusting the pairing." onclick="checkQuiz('quiz-dbg-1', this)">In a dSYM bundle, joined to the binary by LC_UUID</button>
                    <button class="quiz-option" data-correct="false" data-explain="The string table holds symbol names, and any N_STAB debug entries are legacy records — neither carries modern DWARF line tables, which is why a dSYM is required at all." onclick="checkQuiz('quiz-dbg-1', this)">In the LC_SYMTAB string table next to the symbol names</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You run <code>llvm-dwarfdump --uuid</code> on a crash report's binary and on your stored dSYM. The UUIDs differ. What do you do?</p>
                <div class="quiz" id="quiz-dbg-2">
                    <button class="quiz-option" data-correct="false" data-explain="UUIDs identify the exact static link; tools refuse mismatched pairs precisely so addresses cannot be translated by a lookalike. Editing it would defeat the only check that exists." onclick="checkQuiz('quiz-dbg-2', this)">Patch the dSYM's UUID to match — the DWARF is probably still right</button>
                    <button class="quiz-option" data-correct="true" data-explain="A mismatch means the bundle came from a different link. Symbolicating against it maps every address to the wrong source line — plausible-looking nonsense. Rebuild the dSYM from that exact binary, or accept no symbolication." onclick="checkQuiz('quiz-dbg-2', this)">Discard it and regenerate the dSYM from that exact build</button>
                    <button class="quiz-option" data-correct="false" data-explain="The UUID is not advisory. loader.h defines it as the identifier of the object produced by the link editor, and every consumer treats a mismatch as a failed join." onclick="checkQuiz('quiz-dbg-2', this)">Proceed anyway — UUID is only a cache hint, DWARF wins</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: debug info is a two-artifact system. Identity first (UUID), content second (DWARF) — a debugger can only trust the second because it verified the first.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You can now join a crash address to a source line — when the join exists. The UUID also does humbler work: it is how <a href="/courses/macho/lessons/macho-build-version">Build Versions and UUID</a> ties an exact link to its toolchain metadata, and how <a href="/courses/macho/lessons/macho-code-signing">Code Signing</a> pins a signature to the bytes it covers. Everything in this lesson protects the binary <em>after</em> it ships; the next concept moves to the moment it runs — the region at address zero.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-hardening">__PAGEZERO and Memory Hardening</a> — the 4 GiB guard page, MH_PIE, and W^X, all declared in load commands you can read with otool.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-code-signing">Prev: Code Signing</a></span>
                <span><a href="/courses/macho/lessons/macho-hardening">Next: __PAGEZERO and Memory Hardening</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
