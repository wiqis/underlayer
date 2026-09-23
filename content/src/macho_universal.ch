// Mach-O Course — Concept 6: Universal (FAT) Binaries.
// fat_header, fat_arch, and multiple architecture slices.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_universal() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Universal (FAT) Binaries — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>Universal (FAT) Binaries</h1>
            <div class="lesson-meta">15 min · Module 2: Headers</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Apple transitioned Macs from Intel to Apple Silicon without splitting the ecosystem in two: one download, one <code>.dylib</code>, both architectures. The file format that made that possible is the FAT (or "universal") container — a small big-endian table up front pointing at two or more complete Mach-O slices inside the same file. <code>file(1)</code> on our samples prints it plainly: "Mach-O universal binary with 2 architectures."</p>
                <p>Every tool in the chain speaks FAT: <code>lipo</code> creates and inspects them, the kernel reads the arch table to pick a slice before <code>dyld</code> ever runs, and code-signing signs each slice independently. If you have ever wondered where "does not contain a binary compatible with your CPU" comes from, it starts here.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of a FAT file as a table of contents followed by stacked payloads:</p>
                <ol>
                    <li><strong>A fat_header</strong> — 8 bytes: magic 0xCAFEBABE, then <code>nfat_arch</code>, the number of table rows that follow.</li>
                    <li><strong>nfat_arch fat_arch rows</strong> — 20 bytes each: cputype, cpusubtype, offset, size, align. Row N says "a complete thin Mach-O lives at file offset X, Y bytes long, aligned to 2^align."</li>
                    <li><strong>The slices</strong> — each one a normal thin Mach-O (magic <code>CF FA ED FE</code>, mach_header_64, its own load commands), padded to its declared alignment. The gaps read as zeros — <code>fat.h</code> allows them to be filesystem holes.</li>
                </ol>
                <p>The model's missing piece: every fat field is <strong>big-endian</strong> — the opposite regime from the little-endian slices they describe. <code>fat.h</code>: "All structures defined here are always written and read to/from disk in big-endian order." Read the table little-endian and every offset lands in the wrong place.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The two structs from <code>&lt;mach-o/fat.h&gt;</code>, all big-endian:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Struct</th><th scope="col">Field</th><th scope="col">Size</th><th scope="col">What it says</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>fat_header</td><td>magic</td><td>4</td><td>0xCAFEBABE (FAT_MAGIC)</td></tr>
                        <tr><td>fat_header</td><td>nfat_arch</td><td>4</td><td>number of fat_arch rows</td></tr>
                        <tr><td>fat_arch</td><td>cputype</td><td>4</td><td>slice architecture (e.g. 0x01000007)</td></tr>
                        <tr><td>fat_arch</td><td>cpusubtype</td><td>4</td><td>slice variant (e.g. 0x80000003)</td></tr>
                        <tr><td>fat_arch</td><td>offset</td><td>4</td><td>file offset of the slice's mach magic</td></tr>
                        <tr><td>fat_arch</td><td>size</td><td>4</td><td>byte length of the whole slice</td></tr>
                        <tr><td>fat_arch</td><td>align</td><td>4</td><td>alignment exponent: offset must honor 2^align</td></tr>
                    </tbody>
                </table>
                <p>Verified on our samples — <code>universal.macho</code> (66304 bytes, built with <code>llvm-lipo -create</code>):</p>
                <table>
                    <thead>
                        <tr><th scope="col">Row</th><th scope="col">cputype</th><th scope="col">cpusubtype</th><th scope="col">offset</th><th scope="col">size</th><th scope="col">align</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>arch 0</td><td>0x01000007 (x86_64)</td><td>0x80000003</td><td>4096</td><td>12616</td><td>2^12 = 4096</td></tr>
                        <tr><td>arch 1</td><td>0x0100000C (arm64)</td><td>0</td><td>32768</td><td>33536</td><td>2^14 = 16384</td></tr>
                    </tbody>
                </table>
                <p>Slice 0 is byte-for-byte the 12616-byte <code>prog64.macho</code>, slice 1 the 33536-byte <code>prog_arm64.macho</code> — verify by reading offset 4096: <code>CF FA ED FE</code> again, a full little-endian thin file nested in the big-endian table. The signed production sample <code>libasyncProfiler.dylib</code> (1446144 bytes) follows the same shape: x86_64 slice at 0x4000 (size 0xB2890, align 2^14), arm64 at 0xB8000 (size 0xA9100, align 2^14), with the zero padding between the 48-byte arch table and offset 0x4000 there to honor that 2^14-byte alignment.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> align is an <em>exponent</em>, not a byte count. align = 12 means 4096-byte alignment (2^12), not "aligned to 12 bytes." Reading it as a raw size is the fastest way to compute a wrong slice boundary.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The first 48 bytes of <code>universal.macho</code> — the header and both arch rows:</p>
                <div class="hex-dump">
                    <pre>00000000: cafe babe 0000 0002 0100 0007 8000 0003  ................
00000010: 0000 1000 0000 3148 0000 000c 0100 000c  ......1H........
00000020: 0000 0000 0000 8000 0000 8300 0000 000e  ................</pre>
                </div>
                <ol>
                    <li>Bytes 0–3: <code>CA FE BA BE</code> — FAT_MAGIC, read big-endian.</li>
                    <li>Bytes 4–7: <code>00 00 00 02</code> — nfat_arch = 2 slices follow.</li>
                    <li>Bytes 8–27 (arch 0): cputype 0x01000007, subtype 0x80000003, offset <code>00 00 10 00</code> = 4096, size <code>00 00 31 48</code> = 12616, align <code>00 00 00 0C</code> = 12.</li>
                    <li>Bytes 28–47 (arch 1): cputype 0x0100000C, subtype 0, offset <code>00 00 80 00</code> = 32768, size <code>00 00 83 00</code> = 33536, align <code>00 00 00 0E</code> = 14.</li>
                </ol>
                <p>Both rows fit in 48 bytes: 8-byte fat_header + 2 × 20-byte fat_arch. The table ends at offset 48; everything until 4096 is zero padding to arch 0's alignment.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Inspect any FAT file two ways — raw bytes and the tool built for the job:</p>
                <pre><code>$ xxd -l 48 universal.macho
00000000: cafe babe 0000 0002 0100 0007 8000 0003  ........

$ llvm-lipo -info universal.macho
Architectures in the fat file universal.macho are: x86_64 arm64

$ xxd -s 4096 -l 4 universal.macho
00001000: cffa edfe ....</code></pre>
                <p>What to look for: nfat_arch and lipo's architecture count agree (2), each fat_arch cputype matches the slice's own mach_header cputype at its offset, and the slice magic flips back to little-endian <code>CF FA ED FE</code>. Big-endian table, little-endian payloads — both facts visible in three commands.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what byte order do fat_header and fat_arch use, how big is a fat_arch, and where does the first slice's magic live?</p>
                <div class="quiz" id="quiz-fat-1">
                    <button class="quiz-option" data-correct="false" data-explain="Thin mach_header fields are little-endian, but fat.h explicitly writes fat_header and fat_arch big-endian — the container and its payloads use opposite orders." onclick="checkQuiz('quiz-fat-1', this)">Little-endian, like the slices; first slice magic at byte 8</button>
                    <button class="quiz-option" data-correct="true" data-explain="fat.h mandates big-endian for all FAT structures: fat_header is 8 bytes, each fat_arch is 20 bytes (cputype, cpusubtype, offset, size, align), so the table ends at 8 + 20×nfat_arch. The first slice's mach magic sits wherever fat_arch[0].offset points — 4096 in universal.macho." onclick="checkQuiz('quiz-fat-1', this)">Big-endian; fat_arch is 20 bytes; slice magic at fat_arch[0].offset</button>
                    <button class="quiz-option" data-correct="false" data-explain="nfat_arch is a count, not an offset — and a fat_arch is 20 bytes, not 8. The header is 8 bytes total (magic + nfat_arch); rows follow immediately after." onclick="checkQuiz('quiz-fat-1', this)">Mixed order; fat_arch is 32 bytes; first slice magic at byte nfat_arch</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>fat_arch[0] of universal.macho reads offset 4096, size 12616, align 12. Which statement is true?</p>
                <div class="quiz" id="quiz-fat-2">
                    <button class="quiz-option" data-correct="true" data-explain="The slice spans file bytes 4096 through 4096 + 12616 − 1 = 16711, ending just before 16712. And 4096 is divisible by 2^12 = 4096, so the alignment constraint holds — which is exactly why lipo put the slice there." onclick="checkQuiz('quiz-fat-2', this)">Slice runs from byte 4096 through byte 16711, 4096-aligned</button>
                    <button class="quiz-option" data-correct="false" data-explain="align = 12 is an exponent: 2^12 = 4096 bytes, not 12. The slice is padded to the 4096-byte boundary — you can see the zeros between the 48-byte table and offset 4096." onclick="checkQuiz('quiz-fat-2', this)">Slice starts at byte 12 because align = 12</button>
                    <button class="quiz-option" data-correct="false" data-explain="offset is the start, size the length — the slice cannot begin at 0, because bytes 0 through 47 are the fat header and arch table. It ends at 4096 + 12616 − 1 = 16711, not at byte 12616." onclick="checkQuiz('quiz-fat-2', this)">Slice runs from byte 0 through byte 12616</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: table first (big-endian), payload at declared offset (little-endian inside), each slice self-contained down to its own magic.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You can now enter a Mach-O from either door: thin files at magic <code>CF FA ED FE</code>, containers at <code>CA FE BA BE</code> pointing into slices with that same thin magic. Once inside a slice, the 32-byte header hands you off to the region where the format's real instructions live — the flat array of load commands at byte 32.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-load-commands">The Load Command Area</a> — the cmd/cmdsize walk, the LC constants every tool knows, and the real 14-command list of <code>prog64.macho</code>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-cputypes">Previous: CPU Types and Subtypes</a></span>
                <span><a href="/courses/macho/lessons/macho-load-commands">Next: The Load Command Area</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
