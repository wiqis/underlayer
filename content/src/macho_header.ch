// Mach-O Course — Concept 4: The mach_header_64 Field by Field.
// The 32 bytes every 64-bit Mach-O starts with, fully decoded.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_header() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The mach_header_64 Field by Field — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>The mach_header_64 Field by Field</h1>
            <div class="lesson-meta">20 min · Module 2: Headers</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>After the magic, a 64-bit Mach-O file has exactly 28 more header bytes before the load commands begin. Eight fields, all fixed offsets, no pointers. Those fields answer the loader's first questions in order: what CPU does this need, what kind of file is it, how many load commands follow, how many bytes do they occupy, and which global behaviors (PIE, two-level namespace, weak binding) are in effect.</p>
                <p>If <code>ncmds</code> or <code>sizeofcmds</code> is corrupted, the load command walk goes out of bounds and the file is rejected — or worse, parsed into garbage. The header is small enough to memorize, and every Mach-O tool you will ever use starts by decoding exactly these 32 bytes.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Eight 4-byte fields, front to back — seven of them shared with the 32-bit header, plus one 64-bit-only extra:</p>
                <ol>
                    <li><strong>Identity</strong> — magic (0xFEEDFACF), cputype, cpusubtype: what machine this file is for.</li>
                    <li><strong>Purpose</strong> — filetype: object, executable, dylib, bundle, dSYM…</li>
                    <li><strong>Bounds</strong> — ncmds and sizeofcmds: the count and byte-span of the load command array that starts at offset 32.</li>
                    <li><strong>Behavior</strong> — flags (a bitmask) and reserved (must be zero on 64-bit files).</li>
                </ol>
                <p>The model's missing piece: none of these fields tells you where any segment, symbol, or string lives. The header is an identity card and a bounding box — everything with an address lives in the load commands it introduces.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><code>loader.h</code> defines <code>struct mach_header_64</code> as eight uint32-sized fields (cputype and cpusubtype are signed <code>cpu_type_t</code>/<code>cpu_subtype_t</code>, but the widths are 4 bytes):</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Size</th><th scope="col">Field</th><th scope="col">prog64.macho value</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>4</td><td>magic</td><td>0xFEEDFACF (MH_MAGIC_64)</td></tr>
                        <tr><td>4</td><td>4</td><td>cputype</td><td>0x01000007 (CPU_TYPE_X86_64)</td></tr>
                        <tr><td>8</td><td>4</td><td>cpusubtype</td><td>0x80000003 (X86_64_ALL | LIB64)</td></tr>
                        <tr><td>12</td><td>4</td><td>filetype</td><td>2 (MH_EXECUTE)</td></tr>
                        <tr><td>16</td><td>4</td><td>ncmds</td><td>14</td></tr>
                        <tr><td>20</td><td>4</td><td>sizeofcmds</td><td>968</td></tr>
                        <tr><td>24</td><td>4</td><td>flags</td><td>0x00200085</td></tr>
                        <tr><td>28</td><td>4</td><td>reserved</td><td>0 (64-bit only — the 32-bit mach_header is 28 bytes)</td></tr>
                    </tbody>
                </table>
                <p><strong>filetype</strong> (loader.h): MH_OBJECT = 1, MH_EXECUTE = 2, MH_CORE = 4, MH_DYLIB = 6, MH_DYLINKER = 7, MH_BUNDLE = 8, MH_DSYM = 0xA. Object = what <code>clang -c</code> emits; executable = your program; dylib = a .dylib; dSYM = the debug companion.</p>
                <p><strong>flags</strong> you will meet constantly (loader.h): MH_NOUNDEFS = 0x1 (no undefined references), MH_DYLDLINK = 0x4 (input to the dynamic linker), MH_TWOLEVEL = 0x80 (two-level namespace), MH_SUBSECTIONS_VIA_SYMBOLS = 0x2000 (safe dead-strip granularity), MH_WEAK_DEFINES = 0x8000, MH_BINDS_TO_WEAK = 0x10000, MH_NO_REEXPORTED_DYLIBS = 0x100000, MH_PIE = 0x200000 (load at random address).</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> You might think the load commands start "after the first segment." They start at a fixed byte 32 — always. The first segment's payload may even cover the header itself: in executables, __TEXT maps from fileoff 0, so the header sits inside segment 0 while still being the first 32 bytes of the file.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>All 32 bytes of <code>prog64.macho</code>, one field at a time:</p>
                <div class="hex-dump">
                    <pre>00000000: cffa edfe 0700 0001 0300 0080 0200 0000  ................
00000010: 0e00 0000 c803 0000 8500 2000 0000 0000  .......... ......</pre>
                </div>
                <ol>
                    <li>Bytes 0–3: <code>CF FA ED FE</code> — MH_MAGIC_64 little-endian.</li>
                    <li>Bytes 4–7: <code>07 00 00 01</code> — 0x01000007 = CPU_TYPE_X86_64.</li>
                    <li>Bytes 8–11: <code>03 00 00 80</code> — 0x80000003 = CPU_SUBTYPE_X86_64_ALL (3) with the CPU_SUBTYPE_LIB64 capability bit (0x80000000) ORed in.</li>
                    <li>Bytes 12–15: <code>02 00 00 00</code> — filetype 2 = MH_EXECUTE.</li>
                    <li>Bytes 16–19: <code>0E 00 00 00</code> — ncmds = 14.</li>
                    <li>Bytes 20–23: <code>C8 03 00 00</code> — sizeofcmds = 0x3C8 = 968, so commands occupy bytes 32–999.</li>
                    <li>Bytes 24–27: <code>85 00 20 00</code> — 0x00200085 = NOUNDEFS | DYLDLINK | TWOLEVEL | PIE.</li>
                    <li>Bytes 28–31: <code>00 00 00 00</code> — reserved = 0.</li>
                </ol>
                <p>That is the entire header: 32 bytes, eight fields, every later structure found by walking from byte 32 using the bounds in fields 4 and 5.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Dump and decode any Mach-O header in one step:</p>
                <pre><code>$ xxd -l 32 prog64.macho
00000000: cffa edfe 0700 0001 0300 0080 0200 0000  ................
00000010: 0e00 0000 c803 0000 8500 2000 0000 0000  ................

$ llvm-readobj --file-headers prog64.macho
  Magic: Magic64 (0xFEEDFACF)
  FileType: Executable (0x2)
  NumOfLoadCommands: 14
  SizeOfLoadCommands: 968</code></pre>
                <p>What to look for: <code>xxd</code> words at offsets 16 and 20 are exactly the <code>NumOfLoadCommands</code> and <code>SizeOfLoadCommands</code> that <code>llvm-readobj</code> prints — the tool is reading the same eight fields you just did, nothing more, before it walks the command area.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what are the eight mach_header_64 fields in order, and which two bound the load command area?</p>
                <div class="quiz" id="quiz-hdr-1">
                    <button class="quiz-option" data-correct="false" data-explain="ncmds is a count of commands, not a byte bound — the byte span comes from sizeofcmds. And the header has eight fields, not six." onclick="checkQuiz('quiz-hdr-1', this)">magic, cputype, cpusubtype, filetype, ncmds, flags — ncmds bounds the area</button>
                    <button class="quiz-option" data-correct="true" data-explain="Order: magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags, reserved. ncmds caps how many commands you walk; sizeofcmds caps the byte span from offset 32 — together they bound the array." onclick="checkQuiz('quiz-hdr-1', this)">magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags, reserved — ncmds and sizeofcmds</button>
                    <button class="quiz-option" data-correct="false" data-explain="flags and reserved are the last two fields, not sizeofcmds and flags — and filetype sits before ncmds, not after the counts." onclick="checkQuiz('quiz-hdr-1', this)">magic, cputype, filetype, ncmds, sizeofcmds, flags, reserved, uuid — sizeofcmds and uuid</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p><code>prog64.o</code> has ncmds = 4 and sizeofcmds = 512. Where do its load commands end, and where does the first payload byte sit?</p>
                <div class="quiz" id="quiz-hdr-2">
                    <button class="quiz-option" data-correct="false" data-explain="4 commands times any fixed size is wrong — each command has its own cmdsize. You must use sizeofcmds, not ncmds arithmetic." onclick="checkQuiz('quiz-hdr-2', this)">Commands end at byte 4; payload follows immediately</button>
                    <button class="quiz-option" data-correct="true" data-explain="Commands span bytes 32 through 32 + 512 − 1 = 543, so the first byte after the area is 544. In this MH_OBJECT file the __text section really does start at file offset 544 — header and commands, packed with no padding." onclick="checkQuiz('quiz-hdr-2', this)">Commands end at 543; first payload byte is 544</button>
                    <button class="quiz-option" data-correct="false" data-explain="32 + 4 = 46 would be right only if every command were exactly 4 bytes — but each starts with 8 bytes (cmd plus cmdsize) and carries a payload. Use sizeofcmds: 32 + 512 = 544." onclick="checkQuiz('quiz-hdr-2', this)">Commands end at 45; first payload byte is 46</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: end of commands = 32 + sizeofcmds. In object files the payload starts right there; in executables the header region is instead covered by __TEXT from fileoff 0.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Thirty-two bytes, decoded: identity, purpose, bounds, behavior. Two of those fields — cputype and cpusubtype — are the pair the kernel and dyld use to decide whether this file can run on the machine in front of them, and the pair a FAT container stores once per slice.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-cputypes">CPU Types and Subtypes</a> — how 0x01000007 is built from CPU_TYPE_X86 and the ABI64 bit, why the subtype carries a LIB64 flag, and what ARM64E means.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-magic">Previous: Magic Numbers and Byte Order</a></span>
                <span><a href="/courses/macho/lessons/macho-cputypes">Next: CPU Types and Subtypes</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
