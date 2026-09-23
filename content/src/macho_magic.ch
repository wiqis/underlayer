// Mach-O Course — Concept 3: Magic Numbers and Byte Order.
// MH_MAGIC_64, FAT_MAGIC, and reading little-endian.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_magic() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Magic Numbers and Byte Order — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>Magic Numbers and Byte Order</h1>
            <div class="lesson-meta">15 min · Module 1: Fundamentals</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every Mach-O parser — <code>dyld</code>, <code>otool</code>, <code>lldb</code>, the kernel — makes exactly one decision before it reads anything else: look at the first four bytes and decide what kind of file this is, and which byte order its fields use. Get that decision wrong and every field after the magic is scrambled: your cputype becomes nonsense, your <code>ncmds</code> becomes a billion, and the walk over the load commands runs off the end of the file.</p>
                <p>Mach-O is unusual because it has <em>two</em> byte-order regimes in one format. Thin files are little-endian on disk. FAT (universal) headers are always big-endian. Knowing which regime you are in is half the format.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Ask two questions of the first four bytes:</p>
                <ol>
                    <li><strong>Which family?</strong> If the bytes read <code>CA FE BA BE</code>, this is a FAT container — stop, parse the big-endian fat header instead of a mach_header. Otherwise it is a thin file and byte 0 opens a mach_header.</li>
                    <li><strong>Which width?</strong> Inside a thin file, 0xFEEDFACE is the 32-bit header (28 bytes), 0xFEEDFACF is the 64-bit header (32 bytes).</li>
                    <li><strong>Is the byte order swapped?</strong> The header constants come in pairs: a normal magic and a byte-swapped <em>CIGAM</em>. Read the magic, and if you see the CIGAM value instead, the file was written in the opposite byte order — swap every field from there on.</li>
                </ol>
                <p>The model's missing piece: CIGAM is not a separate file type. It is the magic read "backwards." The name is literally MAGIC spelled in reverse, and the values are the byte-swapped constants <code>loader.h</code> defines (<code>MH_CIGAM</code>, <code>MH_CIGAM_64</code>).</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Apple's <code>&lt;mach-o/loader.h&gt;</code> and <code>&lt;mach-o/fat.h&gt;</code> define the full set:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Constant</th><th scope="col">Value</th><th scope="col">Bytes on disk</th><th scope="col">Meaning</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>MH_MAGIC</td><td>0xFEEDFACE</td><td><code>CE FA ED FE</code></td><td>32-bit thin file, little-endian</td></tr>
                        <tr><td>MH_MAGIC_64</td><td>0xFEEDFACF</td><td><code>CF FA ED FE</code></td><td>64-bit thin file, little-endian — every modern sample</td></tr>
                        <tr><td>MH_CIGAM</td><td>0xCEFAEDFE</td><td><code>FE ED FA CE</code></td><td>Byte-swapped 32-bit magic</td></tr>
                        <tr><td>MH_CIGAM_64</td><td>0xCFFAEDFE</td><td><code>FE ED FA CF</code></td><td>Byte-swapped 64-bit magic (<code>NXSwapInt(MH_MAGIC_64)</code>)</td></tr>
                        <tr><td>FAT_MAGIC</td><td>0xCAFEBABE</td><td><code>CA FE BA BE</code></td><td>FAT container — <em>always written big-endian</em></td></tr>
                        <tr><td>FAT_CIGAM</td><td>0xBEBAFECA</td><td><code>BE BA FE CA</code></td><td>Byte-swapped FAT magic — what a little-endian reader that forgets to swap sees</td></tr>
                    </tbody>
                </table>
                <p>How the swap trick works, concretely: a little-endian tool reads four bytes and interprets them little-endian. Bytes <code>CF FA ED FE</code> become 0xFEEDFACF — normal. Bytes <code>FE ED FA CF</code> become 0xCFFAEDFE — exactly <code>MH_CIGAM_64</code>, the signal "this file's fields are encoded opposite to your native order; byte-swap before trusting anything." The FAT side is simpler: <code>fat.h</code> says "All structures defined here are always written and read to/from disk in big-endian order" — that single sentence is why <code>CA FE BA BE</code> reads as 0xCAFEBABE with no swap, everywhere.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> You might think the intro's phrase "0xFEEDFACF little-endian" means some files store <code>FE ED FA CF</code>. In practice every modern 64-bit Mach-O stores <code>CF FA ED FE</code> — including every sample in this course. The FE-ED-FA-CF form belongs to the byte-swapped (CIGAM) case, not to a normal file.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The first bytes of our two sample families — thin object file, then FAT container:</p>
                <div class="hex-dump">
                    <pre>00000000: cffa edfe 0700 0001 0300 0000 0100 0000  ................
00000010: 0400 0000 0002 0000 0020 0000 0000 0000  ......... ......</pre>
                </div>
                <p><code>prog64.o</code>: bytes <code>CF FA ED FE</code> read little-endian are 0xFEEDFACF — MH_MAGIC_64, thin file, fields little-endian from here on. (Full field decode is the next concept.)</p>
                <div class="hex-dump">
                    <pre>00000000: cafe babe 0000 0002 0100 0007 8000 0003  ................
00000010: 0000 1000 0000 3148 0000 000c 0100 000c  ......1H........
00000020: 0000 0000 0000 8000 0000 8300 0000 000e  ................</pre>
                </div>
                <p><code>universal.macho</code>: bytes <code>CA FE BA BE</code> are FAT_MAGIC read <em>big-endian</em>. Next word <code>00 00 00 02</code> = nfat_arch 2, and each 20-byte fat_arch that follows is big-endian too — cputype <code>01 00 00 07</code> (x86_64), then <code>00 00 10 00</code> = offset 4096. Peek at offset 4096 and the magic regime changes: the slice opens <code>CF FA ED FE</code> again — a complete little-endian thin Mach-O nested inside a big-endian envelope.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Compare a thin file and a FAT file side by side:</p>
                <pre><code>$ xxd -l 16 prog64.o
00000000: cffa edfe 0700 0001 0300 0000 0100 0000  ........

$ xxd -l 16 universal.macho
00000000: cafe babe 0000 0002 0100 0007 8000 0003  ........

$ xxd -s 4096 -l 16 universal.macho
00001000: cffa edfe 0700 0001 0300 0080 0200 0000  ........</code></pre>
                <p>What to look for: the thin file and the nested slice both start <code>cf fa ed fe</code>; only the container starts <code>ca fe ba be</code>. First four bytes tell you which parser to use, and the slice magic tells you the payload inside is ordinary little-endian Mach-O again.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what four bytes open a thin 64-bit Mach-O, a FAT container, and what byte order does each use?</p>
                <div class="quiz" id="quiz-magic-1">
                    <button class="quiz-option" data-correct="false" data-explain="CA FE BA BE is FAT_MAGIC, but it is written big-endian — not little-endian. Only the thin mach_header fields are little-endian." onclick="checkQuiz('quiz-magic-1', this)">Both open CA FE BA BE, both little-endian</button>
                    <button class="quiz-option" data-correct="true" data-explain="Thin 64-bit files open CF FA ED FE = 0xFEEDFACF little-endian; FAT containers open CA FE BA BE = 0xCAFEBABE big-endian, because fat.h mandates big-endian for all fat_header and fat_arch fields." onclick="checkQuiz('quiz-magic-1', this)">Thin: CF FA ED FE little-endian; FAT: CA FE BA BE big-endian</button>
                    <button class="quiz-option" data-correct="false" data-explain="The bytes are swapped and the orders are swapped. Thin files are CF FA ED FE little-endian; FAT files are CA FE BA BE big-endian — getting either backwards scrambles every field after the magic." onclick="checkQuiz('quiz-magic-1', this)">Thin: CA FE BA BE big-endian; FAT: CF FA ED FE little-endian</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A tool reads the first four bytes of a file as a little-endian u32 and gets 0xCFFAEDFE. Which constant did it just read, and what must the tool do next?</p>
                <div class="quiz" id="quiz-magic-2">
                    <button class="quiz-option" data-correct="false" data-explain="0xCAFEBABE is FAT_MAGIC, which is the byte pattern CA FE BA BE read big-endian. Reading CA FE BA BE little-endian gives 0xBEBAFECA (FAT_CIGAM), not 0xCFFAEDFE." onclick="checkQuiz('quiz-magic-2', this)">FAT_MAGIC — parse a FAT header, big-endian from here</button>
                    <button class="quiz-option" data-correct="true" data-explain="0xCFFAEDFE is MH_CIGAM_64, defined by loader.h as NXSwapInt(MH_MAGIC_64). It means a 64-bit Mach-O written in the opposite byte order — the tool must byte-swap every multi-byte field it reads." onclick="checkQuiz('quiz-magic-2', this)">MH_CIGAM_64 — byte-swap every subsequent field</button>
                    <button class="quiz-option" data-correct="false" data-explain="MH_MAGIC_64 is 0xFEEDFACF. 0xCFFAEDFE is its byte-swapped twin (CIGAM), the signal that this file's byte order is opposite to the reader's native order." onclick="checkQuiz('quiz-magic-2', this)">MH_MAGIC_64 — a normal little-endian 64-bit file</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: four bytes choose the parser and the byte order for everything after them. Thin = little-endian, FAT = big-endian, CIGAM = swap.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You have the layout and the regime selector: four bytes at offset 0 tell every tool which structure follows and how to read it. Once the magic says "64-bit thin, little-endian," the next 28 bytes are a fixed eight-field header — the one <code>dyld</code> decodes before anything else.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-header">The mach_header_64 Field by Field</a> — all 32 bytes decoded: cputype, filetype, ncmds, sizeofcmds, flags, and the reserved word.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-file-layout">Previous: Mach-O File Layout</a></span>
                <span><a href="/courses/macho/lessons/macho-header">Next: The mach_header_64 Field by Field</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
