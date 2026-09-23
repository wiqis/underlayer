// Mach-O Course — Concept 17: The Dynamic Linker and Entry Point.
// LC_LOAD_DYLINKER, LC_MAIN, entryoff arithmetic, and the legacy thread command.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_entry() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Dynamic Linker and Entry Point — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>The Dynamic Linker and Entry Point</h1>
            <div class="lesson-meta">15 min · Module 6: Modern Linking &amp; Entry</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The kernel maps your segments and then stops — it does not resolve a single symbol. Before any of your code runs, someone must load the dylibs, walk the fixups from the last lesson, and run initializers. That someone is <code>dyld</code>, and the executable has to say where it lives: this is Mach-O's <code>PT_INTERP</code>, the interpreter path ELF carries in a program header. And when dyld finishes, it needs a target to jump to — Mach-O's answer to ELF's <code>e_entry</code> and PE's AddressOfEntryPoint.</p>
                <p>Two load commands answer both questions. Get either wrong and nothing runs: no dylinker name means dyld is never found; no entry command means dyld has nowhere to transfer control.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two commands, two directions of the same handshake:</p>
                <ol>
                    <li><strong>LC_LOAD_DYLINKER</strong> (0xe) — one per executable, never in a dylib: "the dynamic linker's path is <code>/usr/lib/dyld</code>." loader.h: "A file can have at most one of these."</li>
                    <li><strong>LC_MAIN</strong> (0x80000028) — "replacement for LC_UNIXTHREAD": a 24-byte entry_point_command with <code>entryoff</code>, "file (__TEXT) offset of main()", and <code>stacksize</code>, "if not zero, initial stack size for the main thread".</li>
                </ol>
                <p>The runtime target is arithmetic, never a stored address:</p>
                <p class="formula">jump target = image vmaddr + entryoff + slide</p>
                <p>vmaddr is fixed by the linker, entryoff is fixed by the linker, and only slide varies per launch — which is why MH_PIE binaries recompute this every time and why dyld, not the kernel, performs the jump. Legacy binaries pre-dating LC_MAIN used LC_UNIXTHREAD (0x5) instead, embedding the full thread-state registers (including the starting RIP) directly in the load commands.</p>
                <p>The model's missing piece: entryoff is a <em>file</em> offset, and only equals a __TEXT-relative position because __TEXT.fileoff is 0 in practice — the arithmetic adds vmaddr, never fileoff.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><code>dylinker_command</code> = &#123;cmd, cmdsize, name&#125;: an lc_str offset from the command's start, then the path inside the command — the same in-command string layout LC_LOAD_DYLIB uses, so the name offset is 12 (cmd 4 + cmdsize 4 + the offset field 4), not a file offset. <code>entry_point_command</code> = &#123;cmd, cmdsize 24, entryoff u64, stacksize u64&#125;. Both commands carry LC_REQ_DYLD on LC_MAIN, so an old dyld refuses rather than skips.</p>
                <p>The header flags of our sample decode the policy around the jump — prog64.macho: ncmds 14, sizeofcmds 968, flags 0x00200085:</p>
                <table>
                    <thead><tr><th scope="col">Bit</th><th scope="col">Value</th><th scope="col">loader.h says</th></tr></thead>
                    <tbody>
                        <tr><td>MH_NOUNDEFS</td><td>0x1</td><td>no undefined references (all binds resolved internally or empty)</td></tr>
                        <tr><td>MH_DYLDLINK</td><td>0x4</td><td>input for the dynamic linker — must be loaded by dyld</td></tr>
                        <tr><td>MH_TWOLEVEL</td><td>0x80</td><td>two-level namespace bindings (ordinals, from Module 5)</td></tr>
                        <tr><td>MH_PIE</td><td>0x200000</td><td>"the OS will load the main executable at a random address" — ASLR, MH_EXECUTE only</td></tr>
                    </tbody>
                </table>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Treating entryoff as a runtime address or as nm's raw number. On disk it is 1104 (0x450); nm prints 0x100000450 because nm shows the preferred vmaddr. At runtime you must add the slide as well — and loader.h's comment says the field is main()'s file offset, which our samples satisfy exactly, but the guarantee you should rely on is "the offset dyld jumps to", verified against nm, not assumed.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Both commands from prog64.macho, as otool prints them:</p>
                <pre><code>     cmd LC_LOAD_DYLINKER
      cmdsize 32
         name /usr/lib/dyld (offset 12)

      cmd LC_MAIN
   cmdsize 24
  entryoff 1104
 stacksize 0</code></pre>
                <p>Check the arithmetic: __TEXT vmaddr 0x100000000 + entryoff 1104 = 0x100000450, and nm agrees — <code>0000000100000450 T _main</code>. The arm64 twin of the same program carries entryoff 1052 against the same preferred base: 0x100000000 + 1052 = 0x10000041C, and <code>nm -arch arm64</code> prints <code>000000010000041c T _main</code>. Different slices, different code generation, same contract — the entry command is per-arch, which is why FAT files store complete load-command sets per slice.</p>
                <p>Note the LCs that are <em>absent</em>: no LC_UNIXTHREAD (LC_MAIN replaced it), and — because prog.c defines no library calls and links no dylibs — LC_LOAD_DYLINKER is the only loader-related command. The dylib sample shows the inverse: libraries never name the dylinker ("they are loaded <em>by</em> dyld"), so libasyncProfiler.dylib has neither command.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <pre><code>$ /usr/lib/llvm-21/bin/llvm-otool -arch x86_64 -l prog64.macho | grep -A3 -E "LC_LOAD_DYLINKER|LC_MAIN"
$ /usr/lib/llvm-21/bin/llvm-nm prog64.macho | grep " T _main"
0000000100000450 T _main

$ python3 -c "print(hex(0x100000000 + 1104))"
0x100000450</code></pre>
                <p>What to look for: name offset is always 12 for LC_LOAD_DYLINKER (in-command layout, same as dylib names); stacksize 0 means the linker did not request a specific stack — the platform default applies; and python's sum lands on nm's _main exactly. Then subtract: if you ever get a number nm does not print, you added fileoff or forgot the vmaddr base.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what kind of value is LC_MAIN's entryoff — a file position, a load-command index, or a runtime address?</p>
                <div class="quiz" id="quiz-entry-1">
                    <button class="quiz-option" data-correct="false" data-explain="A runtime address would differ every launch — MH_PIE is set — yet entryoff is a constant written by the linker. dyld computes the runtime target by adding vmaddr and slide." onclick="checkQuiz('quiz-entry-1', this)">A runtime virtual address, already slide-adjusted</button>
                    <button class="quiz-option" data-correct="true" data-explain="loader.h says it directly: 'file (__TEXT) offset of main()'. With __TEXT.fileoff 0 it doubles as the offset from image start; the runtime jump is vmaddr + entryoff + slide." onclick="checkQuiz('quiz-entry-1', this)">A file offset within the __TEXT segment</button>
                    <button class="quiz-option" data-correct="false" data-explain="The load commands end at byte 32 + 968 = 1000; entryoff 1104 sits past them inside __text. An index would also be bounded by ncmds = 14." onclick="checkQuiz('quiz-entry-1', this)">An index into the load command array</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>entryoff is 1104, __TEXT's vmaddr is 0x100000000, and at runtime dyld slid the image by 0xAB00000. Where does the process jump?</p>
                <div class="quiz" id="quiz-entry-2">
                    <button class="quiz-option" data-correct="false" data-explain="0x100000450 is the preferred address — right only before the slide. MH_PIE means the running image sits 0xAB00000 higher." onclick="checkQuiz('quiz-entry-2', this)">0x100000450 — base plus entryoff, no slide</button>
                    <button class="quiz-option" data-correct="true" data-explain="0x100000000 + 1104 = 0x100000450, then add the slide 0xAB00000: 0x10AB00450. vmaddr and entryoff are link-time constants; only the slide is per-launch." onclick="checkQuiz('quiz-entry-2', this)">0x10AB00450 — vmaddr + entryoff + slide</button>
                    <button class="quiz-option" data-correct="false" data-explain="0x450 is the raw file offset; at runtime that value falls inside __PAGEZERO and would fault. File offsets are never jumped to directly." onclick="checkQuiz('quiz-entry-2', this)">0x450 — the file offset alone</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: entryoff is written once at link time; the jump target is recomputed every launch — vmaddr + entryoff + slide — after fixups and initializers have all succeeded.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Control transfer is the last thing dyld does with load commands before your code runs — but the commands themselves still carry the metadata macOS uses to decide <em>whether</em> this image may run at all: which OS floor it declares, which SDK built it, and the UUID that ties it to its dSYM.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-build-version">Build Versions and UUID</a> — platform, minos, sdk, the tools that produced the file, and the 16 bytes every crash report is keyed by.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-chained-fixups">Prev: Chained Fixups</a></span>
                <span><a href="/courses/macho/lessons/macho-build-version">Next: Build Versions and UUID</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
