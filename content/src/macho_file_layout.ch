// Mach-O Course — Concept 2: Mach-O File Layout.
// The full map from byte 0 to the end of __LINKEDIT.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_file_layout() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Mach-O File Layout — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>Mach-O File Layout</h1>
            <div class="lesson-meta">15 min · Module 1: Fundamentals</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The intro showed you the first 32 bytes of a Mach-O file. That is the entry point into the format — not the format itself. Before decoding any single field, you need the whole map: which regions exist, in what order they sit on disk, and where one ends and the next begins.</p>
                <p>Everyone who touches a Mach-O needs this map. <code>dyld</code> walks it to map segments and find the entry point. A debugger walks it to find symbols. A code-signing tool rewrites part of it. Get one size wrong — trust a stale <code>sizeofcmds</code>, misread a <code>fileoff</code> — and every region after it is garbage and the file will not load.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of a thin Mach-O file as four zones front to back:</p>
                <ol>
                    <li><strong>A fixed 32-byte header</strong> — magic, CPU type, file type, and the two counts that bound everything else: <code>ncmds</code> and <code>sizeofcmds</code>.</li>
                    <li><strong>The load command area</strong> — exactly <code>sizeofcmds</code> bytes starting at offset 32, a flat array of variable-length commands telling the loader what to do.</li>
                    <li><strong>Segment payload</strong> — the code and data itself, carved up by segments, each declaring its own <code>fileoff</code> and <code>filesize</code>.</li>
                    <li><strong>__LINKEDIT</strong> — always last: symbol tables, strings, rebase/bind info, export trie, code signature.</li>
                </ol>
                <p>The model's missing piece: there is no master pointer to any of this. The header carries counts, not addresses. The only fixed fact is that load commands begin at byte 32 — every other region is discovered by walking outward from there. (ELF at least stores <code>e_phoff</code> and <code>e_shoff</code> pointers; Mach-O makes you earn it.)</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Here is the exact byte map of <code>prog64.macho</code> (12616 bytes, MH_EXECUTE, x86_64), read from its four <code>LC_SEGMENT_64</code> commands:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Region</th><th scope="col">File range</th><th scope="col">Size</th><th scope="col">What it is</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>mach_header_64</td><td>0x0000–0x001F</td><td>32</td><td>magic, cputype, filetype 2 (EXECUTE), ncmds 14, sizeofcmds 968, flags 0x00200085</td></tr>
                        <tr><td>Load commands</td><td>0x0020–0x03E7</td><td>968</td><td>14 commands; area ends at byte 1000 (32 + 968)</td></tr>
                        <tr><td>__PAGEZERO</td><td>—</td><td>0</td><td>vmaddr 0, vmsize 0x100000000, filesize 0 — memory only, no file bytes</td></tr>
                        <tr><td>__TEXT</td><td>0x0000–0x1FFF</td><td>8192</td><td>fileoff 0 — the header and load commands live <em>inside</em> this segment, plus __text, __unwind_info, __eh_frame</td></tr>
                        <tr><td>__DATA</td><td>0x2000–0x2FFF</td><td>4096</td><td>fileoff 8192 — __data, __common</td></tr>
                        <tr><td>__LINKEDIT</td><td>0x3000–0x32D7</td><td>328</td><td>fileoff 12288 — chained fixups, exports, symbols, strings; 12288 + 328 = 12616 = file size</td></tr>
                    </tbody>
                </table>
                <p>Notice two things. First, <code>__TEXT</code> maps from file offset 0, so the header itself is part of the first segment — <code>loader.h</code> says the first segment of MH_EXECUTE and MH_DYLIB files contains the mach_header and load commands. Second, <code>__PAGEZERO</code> occupies the low 4 GiB of memory with <code>filesize 0</code>: a segment can be pure address space with no file behind it.</p>
                <div class="callout callout-warn">
                    <strong>Object files play by different rules.</strong> MH_OBJECT files are compact: <code>loader.h</code> says all sections sit in "one unnamed segment with no segment padding." In <code>prog64.o</code> (992 bytes) the header is 32 bytes, the four load commands span 512, so the payload starts at exactly 544 = 32 + 512 — and <code>otool</code> prints the segment's segname as blank, while each section still carries its own <code>__TEXT</code>/<code>__DATA</code> segname.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Three cuts through <code>prog64.macho</code>, one per zone boundary:</p>
                <div class="hex-dump">
                    <pre>00000000: cffa edfe 0700 0001 0300 0080 0200 0000  ................
00000010: 0e00 0000 c803 0000 8500 2000 0000 0000  .......... .....</pre>
                </div>
                <p>Bytes 16–23: ncmds = 14, sizeofcmds = 0x3C8 = 968 — so the load command area is bytes 32 through 999, and the flags word 0x00200085 unpacks to NOUNDEFS | DYLDLINK | TWOLEVEL | PIE.</p>
                <div class="hex-dump">
                    <pre>00002000: 2a00 0000 0000 0000 0000 0000 0000 0000  *...............</pre>
                </div>
                <p>At file offset 8192 — the <code>fileoff</code> of __DATA — the first word is <code>2A 00 00 00</code> = 42. That is the source file's <code>int global_counter = 42;</code>, which <code>nm</code> reports as <code>D _global_counter</code> at vmaddr 0x100002000. Segment vmaddr 0x100002000 maps file byte 8192: the disk-to-memory contract in one line.</p>
                <div class="hex-dump">
                    <pre>00003000: 0000 0000 2000 0000 3800 0000 3800 0000  .... ...8...8...
00003010: 0000 0000 0100 0000 0000 0000 0000 0000  ................</pre>
                </div>
                <p>At file offset 12288 — __LINKEDIT's <code>fileoff</code> — metadata begins. The first blob is the <code>LC_DYLD_CHAINED_FIXUPS</code> payload (dataoff 12288, datasize 56): <code>fixups_version</code> = 0, <code>starts_offset</code> = 0x20. Symbols, strings, and the code signature all live further inside this same segment, each located by its own load command.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Any Mach-O works — on macOS use <code>otool</code>, on Linux <code>llvm-otool</code>:</p>
                <pre><code>$ llvm-otool -l prog64.macho | grep -E "segname|fileoff|filesize"
  segname __PAGEZERO ... fileoff 0      filesize 0
  segname __TEXT     ... fileoff 0      filesize 8192
  segname __DATA     ... fileoff 8192   filesize 4096
  segname __LINKEDIT ... fileoff 12288  filesize 328</code></pre>
                <p>What to look for: the four fileoffs tile the file with no gaps and no overlaps (0, 8192, 12288, end 12616), and the last segment's <code>fileoff + filesize</code> equals the file size exactly — __LINKEDIT always finishes the job. If your numbers do not tile, you are reading the wrong fields.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: where does the load command area start and end, and which header fields bound it?</p>
                <div class="quiz" id="quiz-flay-1">
                    <button class="quiz-option" data-correct="false" data-explain="ncmds is a count of commands, not a byte offset — the area does not end at byte 14." onclick="checkQuiz('quiz-flay-1', this)">Starts at byte 4; ncmds tells you the ending byte</button>
                    <button class="quiz-option" data-correct="true" data-explain="Load commands always start at byte 32, right after the 32-byte mach_header_64, and span exactly sizeofcmds bytes — so bytes 32 through 32 + sizeofcmds − 1. ncmds only bounds how many commands you may walk inside that span." onclick="checkQuiz('quiz-flay-1', this)">Starts at byte 32; ends at 32 + sizeofcmds − 1</button>
                    <button class="quiz-option" data-correct="false" data-explain="The header has no pointer field that stores the end of the load commands — only ncmds (count) and sizeofcmds (byte span). You compute the end; it is never stored." onclick="checkQuiz('quiz-flay-1', this)">Starts at byte 32; the last load command stores a next-pointer</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>In <code>prog64.macho</code>, __LINKEDIT has fileoff 12288 and filesize 328. The file is 12616 bytes. What does that tell you?</p>
                <div class="quiz" id="quiz-flay-2">
                    <button class="quiz-option" data-correct="true" data-explain="12288 + 328 = 12616, which is exactly the file size. The segment's last byte is 12615 — __LINKEDIT reaches EOF and nothing follows it." onclick="checkQuiz('quiz-flay-2', this)">__LINKEDIT ends exactly at end of file</button>
                    <button class="quiz-option" data-correct="false" data-explain="There is no padding: fileoff + filesize equals the file size precisely. Any leftover bytes would mean either a missed segment or a wrong filesize field." onclick="checkQuiz('quiz-flay-2', this)">There are trailing padding bytes after __LINKEDIT</button>
                    <button class="quiz-option" data-correct="false" data-explain="fileoff is a position on disk, not a vmaddr. The vmaddr of this segment is 0x100003000 — mixing the two coordinate systems is the classic layout mistake." onclick="checkQuiz('quiz-flay-2', this)">Cannot tell — fileoff is a vmaddr, so EOF is elsewhere</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: segments tile the file through their fileoff/filesize pairs, the last one landing exactly on EOF. Header, commands, payload, __LINKEDIT — in that order, every time.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You have the map now: fixed header at 0, load commands from 32, payload located per segment, __LINKEDIT last. The header region starts with four bytes that decide how every subsequent field is read — they are not the same four bytes in every Mach-O file.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-magic">Magic Numbers and Byte Order</a> — why a thin file opens <code>CF FA ED FE</code>, a universal file opens <code>CA FE BA BE</code>, and only one of them is little-endian.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-intro">Previous: Why Mach-O Exists</a></span>
                <span><a href="/courses/macho/lessons/macho-magic">Next: Magic Numbers and Byte Order</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
