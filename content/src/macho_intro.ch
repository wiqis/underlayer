// Mach-O Course — Concept 1: Why Mach-O Exists.
// The Mach heritage and the map of the course.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_intro() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Why Mach-O Exists — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>Why Mach-O Exists</h1>
            <div class="lesson-meta">15 min · Module 1: Fundamentals · Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Double-click an app on macOS and it runs. The file on disk — whether an app bundle's main executable, a framework, or a command-line tool — is a Mach-O file. How does the kernel know where the code starts, which libraries it must load first, where the symbols live, and which bytes are signed?</p>
                <p>The Mach Object (Mach-O) format answers all of those questions. It is the contract between Apple's toolchain (clang, ld64) and the dynamic linker <code>dyld</code>, which runs before your program's <code>main()</code> ever executes. If you have ever wondered what <code>otool</code> or <code>nm</code> actually reads, or how code signing and ASLR work at the byte level, this format is the whole story.</p>
                <p>Without a defined layout, no program could be loaded — every compiler would invent its own structure, and macOS could not run any of them.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of a Mach-O file as a header followed by a list of instructions for the loader:</p>
                <ol>
                    <li><strong>A 32-byte header</strong> — starts with the magic <code>CF FA ED FE</code> (0xFEEDFACF), then the CPU type, file type, and counts.</li>
                    <li><strong>A stream of load commands</strong> — each one tells the loader something: which segments to map, which symbols exist, which dylibs to load, where the entry point is.</li>
                    <li><strong>Segment data and __LINKEDIT</strong> — the actual code and data segments, followed by the <code>__LINKEDIT</code> segment holding symbol tables, string tables, rebase/bind info, and code signatures.</li>
                </ol>
                <p>The model's missing piece: those load commands are variable-length, so the header's <code>ncmds</code> and <code>sizeofcmds</code> fields are what let the loader walk them safely. Get those two wrong and the file will not load.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Apple's <code>&lt;mach-o/loader.h&gt;</code> defines the on-disk order exactly:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Region</th><th scope="col">Starts at</th><th scope="col">Size</th><th scope="col">What it says</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>mach_header_64</td><td>File offset 0</td><td>32 bytes</td><td>magic = 0xFEEDFACF, cputype, filetype, ncmds, sizeofcmds, flags</td></tr>
                        <tr><td>Load commands</td><td>Offset 32</td><td>sizeofcmds bytes</td><td>LC_SEGMENT_64, LC_SYMTAB, LC_LOAD_DYLIB, LC_MAIN, ...</td></tr>
                        <tr><td>Segment data</td><td>Per-segment fileoff</td><td>Per-segment filesize</td><td>__TEXT, __DATA_CONST, __DATA, __LINKEDIT contents</td></tr>
                        <tr><td>__LINKEDIT</td><td>Last segment's fileoff</td><td>filesize</td><td>Symbols, strings, rebase/bind opcodes, export trie, code signature</td></tr>
                    </tbody>
                </table>
                <p>Unlike PE (which hides the real header behind an MS-DOS stub) or ELF (which has two header tables), Mach-O puts its single header at byte 0 and follows it with one flat array of load commands. The vocabulary you will use all course: <strong>file offset</strong> is a position on disk; <strong>vmaddr</strong> is where a segment lands in memory; <strong>__LINKEDIT</strong> is the trailing metadata segment that dyld and the kernel both read.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> You might think Mach-O always starts with <code>feedface</code> as a single big-endian word. It does not — the bytes on disk are <code>CF FA ED FE</code>, which is 0xFEEDFACF read <em>little-endian</em>. FAT (universal) binaries are the exception: they start <code>CA FE BA BE</code> (0xCAFEBABE big-endian).
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>First 32 bytes of a real 64-bit Mach-O object file (<code>prog64.o</code>, built with <code>clang -target x86_64-apple-darwin -c</code>):</p>
                <div class="hex-dump">
                    <pre>00000000: cffaedfe 07000001 03000000 01000000  ................
00000010: 04000000 00020000 00200000 00000000  ......... ......</pre>
                </div>
                <p>Walk-through:</p>
                <ol>
                    <li>Bytes 0-3: <code>CF FA ED FE</code> — MH_MAGIC_64 (0xFEEDFACF little-endian), so this is a 64-bit Mach-O.</li>
                    <li>Bytes 4-7: <code>07 00 00 01</code> — cputype 0x01000007 = CPU_TYPE_X86_64.</li>
                    <li>Bytes 8-11: <code>03 00 00 00</code> — cpusubtype 3 = CPU_SUBTYPE_X86_64_ALL.</li>
                    <li>Bytes 12-15: <code>01 00 00 00</code> — filetype 1 = MH_OBJECT (a relocatable object, not an executable).</li>
                    <li>Bytes 16-19: <code>04 00 00 00</code> — ncmds = 4 load commands follow.</li>
                    <li>Bytes 20-23: <code>00 02 00 00</code> — sizeofcmds = 0x200 = 512 bytes.</li>
                    <li>Bytes 24-27: <code>00 20 00 00</code> — flags = 0x2000 = MH_SUBSECTIONS_VIA_SYMBOLS.</li>
                </ol>
                <p>That is a complete header decode from 32 bytes — the pattern every Mach-O parse starts with.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Any Mach-O file works — app binaries, dylibs, or object files. On Linux or macOS:</p>
                <pre><code>$ file /usr/bin/ls
/usr/bin/ls: Mach-O 64-bit executable arm64

$ xxd -l 32 /usr/bin/ls
00000000: cffaedfe 0c000001 00000000 02000000  ................
...</code></pre>
                <p>What to look for: the first four bytes are always <code>CF FA ED FE</code> for thin 64-bit files, and <em>every</em> multi-byte field you read from the file is little-endian — the lowest-address byte is the least significant. That single rule decodes half the format (FAT headers are the big-endian exception).</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what four bytes open a thin 64-bit Mach-O file, and what 32-bit value do they form little-endian?</p>
                <div class="quiz" id="quiz-intro-1">
                    <button class="quiz-option" data-correct="false" data-explain="CA FE BA BE is FAT_MAGIC (0xCAFEBABE), used only by universal binaries, not thin files." onclick="checkQuiz('quiz-intro-1', this)">CA FE BA BE (FAT_MAGIC)</button>
                    <button class="quiz-option" data-correct="true" data-explain="CF FA ED FE read little-endian is 0xFEEDFACF (MH_MAGIC_64), the 64-bit Mach-O magic." onclick="checkQuiz('quiz-intro-1', this)">CF FA ED FE = 0xFEEDFACF</button>
                    <button class="quiz-option" data-correct="false" data-explain="CF FA ED FE is correct, but 0xFEEDFACE (without the 64) is the 32-bit magic — the 64-bit one is 0xFEEDFACF." onclick="checkQuiz('quiz-intro-1', this)">CF FA ED FE = 0xFEEDFACE</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A Mach-O header has ncmds = 14 and sizeofcmds = 968. The header is 32 bytes. At what file offset does the first load command start, and where does segment data begin?</p>
                <div class="quiz" id="quiz-intro-2">
                    <button class="quiz-option" data-correct="false" data-explain="ncmds is a count, not a byte size — you cannot add it to 32 to get an offset." onclick="checkQuiz('quiz-intro-2', this)">First command at 14; data at 46</button>
                    <button class="quiz-option" data-correct="true" data-explain="Load commands start right after the 32-byte header (offset 32). They span sizeofcmds bytes, so segment data starts at 32 + 968 = 1000." onclick="checkQuiz('quiz-intro-2', this)">First command at 32; data at 1000</button>
                    <button class="quiz-option" data-correct="false" data-explain="ncmds=14 commands but each is variable-length — you must use sizeofcmds (968), not 14 × some fixed size." onclick="checkQuiz('quiz-intro-2', this)">First command at 32; data at 32 + 14 = 46</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: header is always 32 bytes, load commands start at 32, and the first segment's fileoff is normally 32 + sizeofcmds (though segments can declare any fileoff).</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This course follows the same spine the ELF and PE courses did: headers first (what the loader reads), then addressing (how disk maps to memory), then segments and the tables inside them (symbols, dynamic linking, exports), and finally the loader (dyld) itself.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-file-layout">Mach-O File Layout</a> — the full map from byte 0 to the last byte of __LINKEDIT, before any individual field is decoded.</p>
            </div>

            <div class="lesson-footer">
                <span></span>
                <span><a href="/courses/macho/lessons/macho-file-layout">Next: Mach-O File Layout</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
