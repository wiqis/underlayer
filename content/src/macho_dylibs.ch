// Mach-O Course — Concept 13: Dynamic Libraries and Install Names.
// LC_LOAD_DYLIB, LC_ID_DYLIB, LC_RPATH, and the ordinals dyld binds with.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_dylibs() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Dynamic Libraries and Install Names — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>Dynamic Libraries and Install Names</h1>
            <div class="lesson-meta">18 min · Module 5: Dynamic Linking</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Almost no macOS program is self-contained: real binaries borrow printf, malloc, and the C++ runtime from shared libraries. libasyncProfiler.dylib declares two such loans — /usr/lib/libSystem.B.dylib and /usr/lib/libc++.1.dylib — and before main() runs anywhere, dyld must open every image the file depends on, in order, by the exact paths recorded in the load commands. Those paths are the install names: the Mach-O answer to ELF's DT_NEEDED plus SONAME, and to a PE import table's DLL strings.</p>
                <p>Install names are also a policy. A library that names itself /usr/lib/libfoo.1.dylib can never move; one that names itself @rpath/libfoo.dylib lets each consumer decide where it lives. Getting this wrong is the macOS equivalent of DLL hell — and the numbers you will decode next lesson (bind ordinals) are nothing more than positions in this list.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Four load command kinds describe the whole dependency story:</p>
                <ol>
                    <li><strong>LC_ID_DYLIB</strong> (0xd) — a dylib's own name: "I am build/lib/libasyncProfiler.dylib." Executables do not have one.</li>
                    <li><strong>LC_LOAD_DYLIB</strong> (0xc) — one per dependency: "open /usr/lib/libSystem.B.dylib." WEAK (0x80000018) variants may be missing; REEXPORT (0x8000001f) re-exports the dependency's symbols too.</li>
                    <li><strong>LC_RPATH</strong> (0x8000001c) — search paths to try when a dependency starts with @rpath, such as @executable_path/../lib.</li>
                    <li><strong>LC_LOAD_DYLINKER</strong> (0xe) — the dynamic linker itself (/usr/lib/dyld), exactly once, executables only.</li>
                </ol>
                <p>Every dylib-related command is the same shape: cmd, cmdsize, then a 16-byte dylib struct (name offset, timestamp, current_version, compatibility_version), then the path string living inside the command — the name field is an offset from the command's start, not a file offset. cmdsize covers that header plus the string, and loader.h requires cmdsize to be a multiple of 8 in 64-bit files, padded with zeros: this dylib's LC_ID_DYLIB is 64 bytes, where the 24-byte header plus the 32-character path and its NUL would otherwise end at 57.</p>
                <p>The model's missing piece: paths may contain tokens. loader.h says LC_RPATH adds "to the current run path used to find @rpath prefixed dylibs" — dyld expands @rpath against the rpath list, @executable_path to the main executable's directory, and @loader_path to the directory of the image containing the command. The install name is a template; the opened file is the substitution result.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The command constants from loader.h: LC_LOAD_DYLIB = 0xc, LC_ID_DYLIB = 0xd, LC_LOAD_DYLINKER = 0xe, and the dyld-required variants carry LC_REQ_DYLD = 0x80000000 — LC_LOAD_WEAK_DYLIB = 0x80000018, LC_RPATH = 0x8000001c, LC_REEXPORT_DYLIB = 0x8000001f. Version fields pack three 8-bit-ish parts into one u32: major shift 16, minor shift 8, patch in the low byte.</p>
                <p>The dependency list of <code>libasyncProfiler.dylib</code>, exactly as otool prints it (first line is the LC_ID_DYLIB):</p>
                <pre><code>$ otool -arch x86_64 -L libasyncProfiler.dylib
libasyncProfiler.dylib:
    build/lib/libasyncProfiler.dylib (compatibility version 0.0.0, current version 0.0.0)
    /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1319.100.3)
    /usr/lib/libc++.1.dylib (compatibility version 1.0.0, current version 1500.65.0)</code></pre>
                <p>Decode libSystem's current_version 1319.100.3 = 0x05276403: major = 0x0527 = 1319, minor = 0x64 = 100, patch = 0x03. Its compatibility_version 0x00010000 = 1.0.0 — and loader.h states the rule: a user's compatibility number must be greater than or equal to the library's, so any 1.x-compatible build satisfies this check. LC_ID_DYLIB for this dylib sits at cmdsize 64 with name offset 24 — the 24-byte dylib_command header, then the path bytes.</p>
                <p>Then the ordinals, which nlist.h defines precisely: library ordinals count the LC_LOAD_DYLIB, LC_LOAD_WEAK_DYLIB, LC_REEXPORT_DYLIB (and siblings) load commands in header order, starting at 1 — LC_ID_DYLIB is excluded. Each value lives in the high byte of an undefined symbol's n_desc (GET_LIBRARY_ORDINAL). Specials from the header: 0 = self, 0xfe = flat-namespace lookup, 0xff = the main executable.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Confusing timestamp with version. loader.h says timestamp records when the library was built and copied into the user — it lets tools check that the runtime library is the same build that was linked against; API compatibility is judged by current_version and compatibility_version instead. Second trap: treating the install name as a guarantee the file exists there. It is the name dyld will try, after token substitution — @rpath names are promises that LC_RPATH commands will complete the path.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The two LC_RPATH commands inside the same dylib (command 13 and 14 of 18):</p>
                <pre><code>          cmd LC_RPATH
      cmdsize 40
         path @executable_path/../lib (offset 12)
          cmd LC_RPATH
      cmdsize 48
         path @executable_path/../lib/server (offset 12)</code></pre>
                <p>Offset 12 is the path's position inside the command: cmd(4) + cmdsize(4) + path.offset field(4). So if a future dependency is named @rpath/libfoo.dylib, dyld tries executable-dir/../lib/libfoo.dylib, then executable-dir/../lib/server/libfoo.dylib — two tries, in command order, before giving up.</p>
                <p>The symbol-side record: an undefined symbol's n_desc proves the ordinal is stored, not computed. In this dylib, __Unwind_Resume has n_desc = 0x0100 — high byte 1 = the first LC_LOAD_DYLIB (/usr/lib/libSystem.B.dylib) — while a basic_string::find reference carries 0x0200 — high byte 2 = /usr/lib/libc++.1.dylib. Two-level namespace binding: each undefined symbol already knows which library must answer it.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <pre><code>$ otool -arch x86_64 -l libasyncProfiler.dylib | grep -A2 LC_RPATH
          cmd LC_RPATH
      cmdsize 40
         path @executable_path/../lib (offset 12)
--
          cmd LC_RPATH
      cmdsize 48
         path @executable_path/../lib/server (offset 12)

$ otool -arch x86_64 -l prog64.macho | grep -A2 LC_LOAD_DYLINKER
      cmd LC_LOAD_DYLINKER
      cmdsize 32
         name /usr/lib/dyld (offset 12)</code></pre>
                <p>What to look for: cmdsize always covers the 12-byte rpath header plus the path and zero padding out to a multiple of 8; every LC_LOAD_DYLIB shares the version-packing scheme with LC_ID_DYLIB; and LC_LOAD_DYLINKER (/usr/lib/dyld) appears in the executable but never in the dylib — libraries are loaded <em>by</em> dyld, they do not name it. (prog64.macho itself declares no dylibs at all — a dependency-free executable still names its dylinker.)</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a dylib records current_version = 0x05276403. Which version is that?</p>
                <div class="quiz" id="quiz-dylibs-1">
                    <button class="quiz-option" data-correct="false" data-explain="5.39.16387 treats the u32 as one number — but the field packs three parts: high 16 bits, next byte, low byte." onclick="checkQuiz('quiz-dylibs-1', this)">5.39.16387</button>
                    <button class="quiz-option" data-correct="true" data-explain="0x0527 = 1319 (major, high 16 bits), 0x64 = 100 (minor, bits 8-15), 0x03 = 3 (patch, low byte): 1319.100.3 — exactly what otool prints for libSystem.B.dylib." onclick="checkQuiz('quiz-dylibs-1', this)">1319.100.3</button>
                    <button class="quiz-option" data-correct="false" data-explain="1319.3.100 swaps minor and patch — the order is major shift 16, minor shift 8, patch last, not the reverse." onclick="checkQuiz('quiz-dylibs-1', this)">1319.3.100</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>An undefined symbol's n_desc = 0x0200, and the image's load commands list LC_LOAD_DYLIB libSystem first, then LC_LOAD_DYLIB libc++. Which library is this symbol meant to bind against?</p>
                <div class="quiz" id="quiz-dylibs-2">
                    <button class="quiz-option" data-correct="false" data-explain="Ordinal 0 is SELF_LIBRARY_ORDINAL — the image itself. The high byte of 0x0200 is 2, not 0." onclick="checkQuiz('quiz-dylibs-2', this)">It binds against this image itself</button>
                    <button class="quiz-option" data-correct="true" data-explain="GET_LIBRARY_ORDINAL takes n_desc high byte: 0x0200 gives ordinal 2, the second LC_LOAD_DYLIB in header order — /usr/lib/libc++.1.dylib. (Ordinal 1 would be libSystem.)" onclick="checkQuiz('quiz-dylibs-2', this)">Ordinal 2: /usr/lib/libc++.1.dylib</button>
                    <button class="quiz-option" data-correct="false" data-explain="The ordinal is the high byte (n_desc shift right 8), so 0x0200 means 2 — the whole 0x0200 would be 512 libraries, which no header could address." onclick="checkQuiz('quiz-dylibs-2', this)">Ordinal 0x0200 = 512, so any library may answer</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: load-command order is the numbering. Add or reorder a dylib load command and every ordinal after it shifts — which is why the linker fixes this list once, in a stable order.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Ordinals give the "which library" half of an extern reference from <a href="/courses/macho/lessons/macho-relocations">Relocation Entries</a>; the "which symbol and where" half is about to be rewritten for load time instead of link time.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-dyld-info">Rebase and Bind Opcodes</a> — the compressed streams in __LINKEDIT that tell dyld which pointers to slide and which symbols (by ordinal!) to resolve, now that every library in the list is open.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-relocations">Prev: Relocation Entries</a></span>
                <span><a href="/courses/macho/lessons/macho-dyld-info">Next: Rebase and Bind Opcodes</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
