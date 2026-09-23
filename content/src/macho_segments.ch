// Mach-O Course — Concept 8: LC_SEGMENT_64.
// The load command that maps file bytes into memory, with protections.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_segments() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("LC_SEGMENT_64 — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>LC_SEGMENT_64</h1>
            <div class="lesson-meta">18 min · Module 3: Load Commands</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>ELF spreads mapping decisions across program headers; PE hides them behind its section table. Mach-O puts every mapping decision in one explicit command: LC_SEGMENT_64 tells the kernel and dyld exactly which run of file bytes to map, where it lands in memory, and with which read/write/execute permissions. Nothing in a Mach-O file becomes memory without one of these commands.</p>
                <p>This is also where the famous names live — __TEXT, __DATA, __LINKEDIT, __PAGEZERO. When someone says "the __TEXT segment is read-execute," they are quoting fields in this structure. Sections, symbols, and fixups all hang off segments declared here.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>One command per contiguous region, answering four questions:</p>
                <ul>
                    <li><strong>Where in the file?</strong> — <code>fileoff</code> and <code>filesize</code>.</li>
                    <li><strong>Where in memory?</strong> — <code>vmaddr</code> and <code>vmsize</code>. The file supplies the first filesize bytes; if vmsize is larger, the tail is zero-filled. That is how uninitialised space exists without costing disk.</li>
                    <li><strong>Which permissions?</strong> — <code>maxprot</code> (the ceiling) and <code>initprot</code> (what the mapping actually starts with): read = 1, write = 2, execute = 4.</li>
                    <li><strong>What is inside?</strong> — <code>nsects</code> section records follow the struct (next lesson).</li>
                </ul>
                <p>The model's missing piece: the conventional segments have jobs. __PAGEZERO maps no file bytes (filesize 0) and holds the lowest 4 GiB with no permissions, so NULL dereferences fault — loader.h says it "catches NULL references for MH_EXECUTE files". __TEXT carries code, __DATA carries mutable data, and __LINKEDIT is the trailing metadata pile dyld reads.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>loader.h defines <code>segment_command_64</code> as exactly 72 bytes before any section records:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Size</th><th scope="col">Field</th><th scope="col">What it says</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>4</td><td>cmd</td><td>Always 0x19 (LC_SEGMENT_64)</td></tr>
                        <tr><td>4</td><td>4</td><td>cmdsize</td><td>This struct plus nsects × 80-byte section records</td></tr>
                        <tr><td>8</td><td>16</td><td>segname</td><td>NUL-padded name such as "__TEXT"</td></tr>
                        <tr><td>24</td><td>8</td><td>vmaddr</td><td>Memory address the segment loads at</td></tr>
                        <tr><td>32</td><td>8</td><td>vmsize</td><td>Memory size; may exceed filesize (zero fill)</td></tr>
                        <tr><td>40</td><td>8</td><td>fileoff</td><td>File offset of the segment contents</td></tr>
                        <tr><td>48</td><td>8</td><td>filesize</td><td>Bytes mapped from the file</td></tr>
                        <tr><td>56</td><td>4</td><td>maxprot</td><td>Maximum protection (vm_prot_t)</td></tr>
                        <tr><td>60</td><td>4</td><td>initprot</td><td>Initial protection actually applied</td></tr>
                        <tr><td>64</td><td>4</td><td>nsects</td><td>Number of section_64 records that follow</td></tr>
                        <tr><td>68</td><td>4</td><td>flags</td><td>SG_* bits (for example SG_READ_ONLY = 0x10)</td></tr>
                    </tbody>
                </table>
                <p>The protection bits come from Apple's vm_prot.h: VM_PROT_READ = 1, VM_PROT_WRITE = 2, VM_PROT_EXECUTE = 4. So 5 is read+execute, 3 is read+write, 7 is everything, 0 is a trap page.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Treating cmdsize as "just the struct." loader.h says cmdsize "includes sizeof section_64 structs" — a __TEXT command with 3 sections is 72 + 3×80 = 312 bytes. Second mistake: expecting every file to have named segments. MH_OBJECT files pack all sections into one anonymous segment; prog64.o's single command has an empty segname and prot 7/7 (rwx) because the linker has not assigned final permissions yet.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The first load command of <code>prog64.macho</code>, all 72 bytes starting at file offset 32:</p>
                <div class="hex-dump">
                    <pre>00000020: 1900 0000 4800 0000 5f5f 5041 4745 5a45  ....H...__PAGEZE
00000030: 524f 0000 0000 0000 0000 0000 0000 0000  RO..............
00000040: 0000 0000 0100 0000 0000 0000 0000 0000  ................
00000050: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000060: 0000 0000 0000 0000                      ........</pre>
                </div>
                <ol>
                    <li><code>19 00 00 00</code> = cmd 0x19, <code>48 00 00 00</code> = cmdsize 72 — no sections follow.</li>
                    <li>Bytes 8-23: <code>__PAGEZERO</code> padded with NULs to 16.</li>
                    <li>vmsize at offset 32 reads <code>00 00 00 00 01 00 00 00</code> little-endian = 0x100000000 = 4 GiB of guarded address space.</li>
                    <li>fileoff, filesize, maxprot, initprot, nsects, flags are all zero — 4 GiB of memory, zero bytes of file, no permissions. The guard page, stated in binary.</li>
                </ol>
                <p>The executable's four segments, decoded from the same file:</p>
                <table>
                    <thead>
                        <tr><th scope="col">segname</th><th scope="col">vmaddr / vmsize</th><th scope="col">fileoff / filesize</th><th scope="col">initprot</th><th scope="col">nsects</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>__PAGEZERO</td><td>0 / 0x100000000</td><td>0 / 0</td><td>0</td><td>0</td></tr>
                        <tr><td>__TEXT</td><td>0x100000000 / 0x2000</td><td>0 / 8192</td><td>5 (r-x)</td><td>3</td></tr>
                        <tr><td>__DATA</td><td>0x100002000 / 0x1000</td><td>8192 / 4096</td><td>3 (rw-)</td><td>2</td></tr>
                        <tr><td>__LINKEDIT</td><td>0x100003000 / 0x148</td><td>12288 / 328</td><td>1 (r--)</td><td>0</td></tr>
                    </tbody>
                </table>
                <p>The segments tile memory end to end (0x100000000, then +0x2000, then +0x1000), and __TEXT covers the header and load commands itself — fileoff 0, because they are mapped with the code.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Pull just the segment fields out of the load-command dump (samples directory):</p>
                <pre><code>$ otool -arch x86_64 -l prog64.macho | grep -E "^  segname|^   vmaddr|^   vmsize|^  fileoff|^ filesize|^ initprot|^   nsects"
  segname __PAGEZERO
   vmaddr 0x0000000000000000
   vmsize 0x0000000100000000
  fileoff 0
 filesize 0
 initprot 0x00000000
   nsects 0
  segname __TEXT
   vmaddr 0x0000000100000000
   vmsize 0x0000000000002000
  fileoff 0
 filesize 8192
 initprot 0x00000005
   nsects 3
  ...</code></pre>
                <p>What to look for: initprot values only ever combine bits 1, 2, and 4; filesize never exceeds vmsize; and __LINKEDIT is last with nsects 0 — link-edit metadata is one blob, not sections.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: otool prints <code>initprot 0x00000005</code> for __TEXT. Which access does that grant?</p>
                <div class="quiz" id="quiz-segments-1">
                    <button class="quiz-option" data-correct="false" data-explain="Write is bit 2 (value 2), and 5 has no bit 2 set — __TEXT is deliberately not writable." onclick="checkQuiz('quiz-segments-1', this)">Read and write</button>
                    <button class="quiz-option" data-correct="true" data-explain="VM_PROT_READ = 1 plus VM_PROT_EXECUTE = 4 equals 5: code can be read and run but never written." onclick="checkQuiz('quiz-segments-1', this)">Read and execute</button>
                    <button class="quiz-option" data-correct="false" data-explain="Read+write+execute is 1|2|4 = 7. That is what prog64.o's anonymous object segment uses before linking, not a mapped executable." onclick="checkQuiz('quiz-segments-1', this)">Read, write, and execute</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A segment_command_64 reports nsects = 3. What is its cmdsize, and why?</p>
                <div class="quiz" id="quiz-segments-2">
                    <button class="quiz-option" data-correct="false" data-explain="80 is the size of one section_64 record alone — it ignores the 72-byte segment struct that comes first." onclick="checkQuiz('quiz-segments-2', this)">80 bytes, one section record</button>
                    <button class="quiz-option" data-correct="true" data-explain="loader.h: cmdsize includes the section structs — 72 bytes for segment_command_64 plus 3 × 80 = 312. That is exactly what otool prints for prog64.macho's __TEXT command." onclick="checkQuiz('quiz-segments-2', this)">312 bytes: 72 + 3 × 80</button>
                    <button class="quiz-option" data-correct="false" data-explain="240 counts only the sections. Walking to the next load command at struct-start + 240 would land 72 bytes early, inside the section array." onclick="checkQuiz('quiz-segments-2', this)">240 bytes: 3 × 80</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: cmdsize is the whole command's footprint. Add it to the current offset to reach the next load command — that is the walk the loader performs ncmds times.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You now know how a segment claims memory. The previous concept, <a href="/courses/macho/lessons/macho-load-commands">The Load Command Area</a>, showed how the header points at this command stream; the segment command is simply its most important member.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-sections">Sections</a> — the nsects records packed behind this command, where names, alignment flags, and the S_* type bits live.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-load-commands">Prev: The Load Command Area</a></span>
                <span><a href="/courses/macho/lessons/macho-sections">Next: Sections</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
