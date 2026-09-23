// Mach-O Course — Concept 7: The Load Command Area.
// cmd/cmdsize walking, the LC constants, and prog64.macho's real command list.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_load_commands() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Load Command Area — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>The Load Command Area</h1>
            <div class="lesson-meta">20 min · Module 3: Load Commands</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The header told you <em>that</em> load commands follow and how many bytes they span. The commands themselves are where the format does its actual talking: which segments to map, which symbols exist, which dylibs to load, where dyld lives, where <code>main()</code> is, where the code signature sits. Everything after this concept in the course — segments, sections, symbol tables, dynamic linking, entry — is one or more load commands unpacked.</p>
                <p>They are also the format's only variable-length structure, which makes them the natural place parsers go wrong: a wrong <code>cmdsize</code> does not fail loudly, it shifts every subsequent command and turns a type field into garbage.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>One flat array, one walk rule:</p>
                <ol>
                    <li><strong>Start at byte 32</strong>, right after mach_header_64. Read two u32s: <code>cmd</code> (a type constant) and <code>cmdsize</code> (this command's total size in bytes, header and payload included).</li>
                    <li><strong>Advance by cmdsize</strong> — add it to the current offset to reach the next command. Repeat until you have read ncmds commands or consumed sizeofcmds bytes; never trust one without checking the other.</li>
                    <li><strong>Dispatch on cmd</strong> — each type has its own payload struct (segment_command_64, dylib_command, entry_point_command…), but all of them begin with the same cmd + cmdsize prefix.</li>
                </ol>
                <p>The model's missing piece: the high bit 0x80000000 (LC_REQ_DYLD) changes the failure mode. <code>loader.h</code>: an unknown command <em>with</em> the bit makes dyld refuse the image ("unknown load command required for execution"); an unknown command <em>without</em> it is silently ignored — forward compatibility for old tools meeting new files.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><code>loader.h</code> defines the universal prefix and the walk rules: struct <code>load_command</code> is just <code>uint32_t cmd; uint32_t cmdsize;</code>. The header comment adds two constraints: on 64-bit architectures cmdsize must be a multiple of 8 (4 on 32-bit), "The padded bytes must be zero," and all tables must be memory-mappable. Constants you will constantly meet — old style and LC_REQ_DYLD style:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Constant</th><th scope="col">Value</th><th scope="col">Payload</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>LC_SEGMENT_64</td><td>0x19</td><td>segment_command_64 + section_64 array</td></tr>
                        <tr><td>LC_SYMTAB / LC_DYSYMTAB</td><td>0x2 / 0xB</td><td>symtab_command / dysymtab_command</td></tr>
                        <tr><td>LC_LOAD_DYLIB / LC_ID_DYLIB</td><td>0xC / 0xD</td><td>dylib_command — install name, versions</td></tr>
                        <tr><td>LC_LOAD_DYLINKER</td><td>0xE</td><td>dylinker_command — path to dyld</td></tr>
                        <tr><td>LC_UUID / LC_BUILD_VERSION</td><td>0x1B / 0x32</td><td>16-byte UUID / platform, minos, sdk, tools</td></tr>
                        <tr><td>LC_CODE_SIGNATURE</td><td>0x1D</td><td>linkedit_data_command — dataoff, datasize</td></tr>
                        <tr><td>LC_FUNCTION_STARTS / LC_DATA_IN_CODE</td><td>0x26 / 0x29</td><td>linkedit_data_command</td></tr>
                        <tr><td>LC_LOAD_WEAK_DYLIB / LC_RPATH</td><td>0x80000018 / 0x8000001C</td><td>dylib_command / rpath_command (LC_REQ_DYLD set)</td></tr>
                        <tr><td>LC_DYLD_INFO_ONLY</td><td>0x80000022</td><td>dyld_info_command — rebase/bind/export streams</td></tr>
                        <tr><td>LC_MAIN</td><td>0x80000028</td><td>entry_point_command — entryoff, stacksize</td></tr>
                        <tr><td>LC_DYLD_EXPORTS_TRIE / LC_DYLD_CHAINED_FIXUPS</td><td>0x80000033 / 0x80000034</td><td>linkedit_data_command</td></tr>
                    </tbody>
                </table>
                <p>Two payloads deserve a first look now. <code>dylib_command</code> = cmd, cmdsize, then a <code>dylib</code> struct: <code>name.offset</code> (u32, offset <em>from the start of the command</em> to a null-terminated install path), timestamp, current_version, compatibility_version — versions packed as major bits 16, minor 8, patch 8 (loader.h calls the layout xxxx.yy.zz). And the ordinals: dylibs are numbered 1, 2, 3… in the order their LC_LOAD_DYLIB-family commands appear (nlist.h: "The library ordinals start from 1"); special bind values are 0 = self, −1 = main executable, −2 = flat lookup, −3 = weak lookup (loader.h BIND_SPECIAL_DYLIB_*).</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> cmdsize is not "the payload size" — it includes the 8-byte prefix plus payload plus padding. Also, ncmds and sizeofcmds must agree: if your walk ends early or runs past 32 + sizeofcmds, one of the two header counts (or a cmdsize) is wrong, and you must stop rather than read on.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The first command in <code>prog64.macho</code>, at byte 32:</p>
                <div class="hex-dump">
                    <pre>00000020: 1900 0000 4800 0000 5f5f 5041 4745 5a45  ....H...__PAGEZE
00000030: 524f 0000 0000 0000 0000 0000 0000 0000  RO..............</pre>
                </div>
                <p><code>19 00 00 00</code> = cmd 0x19 (LC_SEGMENT_64), <code>48 00 00 00</code> = cmdsize 72, then the 16-byte segname <code>__PAGEZERO</code>. The next command starts at 32 + 72 = 104. Walking all 14 commands of this file, with cmdsizes that sum to exactly sizeofcmds = 968:</p>
                <table>
                    <thead>
                        <tr><th scope="col">#</th><th scope="col">cmd</th><th scope="col">cmdsize</th><th scope="col">Meaning</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0–3</td><td>LC_SEGMENT_64 ×4</td><td>72, 312, 232, 72</td><td>__PAGEZERO, __TEXT, __DATA, __LINKEDIT</td></tr>
                        <tr><td>4</td><td>LC_DYLD_CHAINED_FIXUPS</td><td>16</td><td>dataoff 12288, datasize 56</td></tr>
                        <tr><td>5</td><td>LC_DYLD_EXPORTS_TRIE</td><td>16</td><td>dataoff 12344, datasize 96</td></tr>
                        <tr><td>6–7</td><td>LC_SYMTAB, LC_DYSYMTAB</td><td>24, 80</td><td>symbol table (6 syms) and dynamic symbol info</td></tr>
                        <tr><td>8</td><td>LC_LOAD_DYLINKER</td><td>32</td><td>name offset 12 → "/usr/lib/dyld"</td></tr>
                        <tr><td>9</td><td>LC_UUID</td><td>24</td><td>4C4C44C9-5555-3144-A19F-1D5685FC622F</td></tr>
                        <tr><td>10</td><td>LC_BUILD_VERSION</td><td>32</td><td>platform 1 (macOS), minos 13.0, sdk 13.0</td></tr>
                        <tr><td>11</td><td>LC_MAIN</td><td>24</td><td>entryoff 1104 (0x450) — file offset of main()</td></tr>
                        <tr><td>12–13</td><td>LC_FUNCTION_STARTS, LC_DATA_IN_CODE</td><td>16, 16</td><td>linkedit_data_command blobs</td></tr>
                    </tbody>
                </table>
                <p>That is the whole instruction sheet of an executable in 968 bytes: four segments, how to fix up pointers, where the symbols are, which linker to run first, the build identity, the entry point, and two aux tables. The signed dylib adds LC_ID_DYLIB (its own install name <code>build/lib/libasyncProfiler.dylib</code> at offset 24) plus two LC_LOAD_DYLIB rows — <code>/usr/lib/libSystem.B.dylib</code> (current version 1319.100.3) and <code>/usr/lib/libc++.1.dylib</code> — which become bind ordinals 1 and 2.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>List the command area of any Mach-O:</p>
                <pre><code>$ llvm-otool -l prog64.macho | grep -E "  cmd |cmdsize"
      cmd LC_SEGMENT_64
  cmdsize 72
      cmd LC_SEGMENT_64
  cmdsize 312
      cmd LC_SEGMENT_64
  cmdsize 232
      cmd LC_SEGMENT_64
  cmdsize 72
... (9 more commands, total 968 bytes)

$ xxd -s 32 -l 8 prog64.macho
00000020: 1900 0000 4800 0000                            ......</code></pre>
                <p>What to look for: the first two little-endian words are exactly cmd = 0x19 and cmdsize = 0x48. Add cmdsize to your offset repeatedly and you will land on byte 1000 = 32 + 968 — one past the last command, where the walk must stop even if more data follows in the file.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what two fields open every load command, and how do you find the next one?</p>
                <div class="quiz" id="quiz-lc-1">
                    <button class="quiz-option" data-correct="false" data-explain="There is no next-pointer in a load command — the array is walked by size, not linked. And ncmds lives in the mach_header, not in each command." onclick="checkQuiz('quiz-lc-1', this)">cmd and a next-offset field; ncmds tells you when to stop</button>
                    <button class="quiz-option" data-correct="true" data-explain="load_command in loader.h is uint32 cmd plus uint32 cmdsize, where cmdsize covers prefix, payload and padding. The next command starts cmdsize bytes later; you stop after ncmds commands or at byte 32 + sizeofcmds." onclick="checkQuiz('quiz-lc-1', this)">cmd and cmdsize; advance the offset by cmdsize</button>
                    <button class="quiz-option" data-correct="false" data-explain="cmdsize is a byte count including the 8-byte header — not a count of payload words. Commands are variable-length, so there is no fixed stride to step by." onclick="checkQuiz('quiz-lc-1', this)">cmd and word-count; multiply by 4 and add 8</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your parser sits at file offset 32 and reads cmdsize = 72. Where does the next command begin, and where must the walk stop in this file (ncmds 14, sizeofcmds 968)?</p>
                <div class="quiz" id="quiz-lc-2">
                    <button class="quiz-option" data-correct="false" data-explain="32 + 72 = 104, not 144 — cmdsize is 72 bytes. And the stop line is 32 + sizeofcmds = 1000, not 32 + ncmds." onclick="checkQuiz('quiz-lc-2', this)">Next at 144; stop after 46 bytes of commands</button>
                    <button class="quiz-option" data-correct="true" data-explain="Next command = 32 + 72 = 104 (that is where LC_SEGMENT_64 for __TEXT begins). The walk's hard stop is byte 32 + 968 = 1000 — reaching it exactly when ncmds commands have been read is the consistency check that the header and the cmdsizes agree." onclick="checkQuiz('quiz-lc-2', this)">Next at 104; stop at byte 1000</button>
                    <button class="quiz-option" data-correct="false" data-explain="The command itself does start at 104 — but the walk never ends at 72. Byte 72 is still inside this first command's payload; the end of the area is 32 + sizeofcmds = 1000." onclick="checkQuiz('quiz-lc-2', this)">Next at 104; stop at byte 72</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: offset += cmdsize until ncmds commands are read and the total consumed equals sizeofcmds. Both bounds must land together.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You can now walk the command area safely: fixed prefix at byte 32, variable lengths bounded twice over, LC_REQ_DYLD deciding what happens to unknown types. The most important command in the array is the one that maps the file into memory — LC_SEGMENT_64, four of them in every executable you have seen.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-segments">LC_SEGMENT_64</a> — vmaddr, vmsize, fileoff, filesize, protections, and how __PAGEZERO, __TEXT, __DATA and __LINKEDIT tile both disk and address space.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-universal">Previous: Universal (FAT) Binaries</a></span>
                <span><a href="/courses/macho/lessons/macho-segments">Next: LC_SEGMENT_64</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
