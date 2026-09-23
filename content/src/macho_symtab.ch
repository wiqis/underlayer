// Mach-O Course — Concept 10: The Symbol Table.
// LC_SYMTAB, 16-byte nlist_64 entries, and the string table in __LINKEDIT.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_symtab() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Symbol Table — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>The Symbol Table</h1>
            <div class="lesson-meta">18 min · Module 4: Symbols</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The bytes on disk say <code>e8 00 00 00 00</code> — a call to nowhere. The symbol table is what turns that into <em>call _helper</em>. nm prints from it, debuggers set breakpoints through it, crash reports symbolicate with it, and the linker itself resolves cross-file references against it. In ELF terms it is .symtab and .strtab; the difference is how explicitly Mach-O points at them.</p>
                <p>Without LC_SYMTAB a file is anonymous machine code. Every "by name" story in this course — binding, exports, relocations, dyld lookups — ultimately indexes this one array.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>One 24-byte load command pointing at two blobs, both normally inside __LINKEDIT:</p>
                <ol>
                    <li><strong>symoff / nsyms</strong> — the symbol table: nsyms fixed 16-byte nlist_64 records, packed back to back.</li>
                    <li><strong>stroff / strsize</strong> — the string table: one NUL-separated pool of names, strsize bytes total.</li>
                </ol>
                <p>Each nlist_64 answers: what is the name (n_strx — an <em>index into the string table</em>, not into the file), what kind of symbol is it (n_type), which section is it defined in (n_sect, 1-based, or 0 for none), any extra flags (n_desc), and what is its address (n_value).</p>
                <p>The model's missing piece: n_type is not one field but four packed bitfields — nlist.h shows the layout: N_STAB:3, N_PEXT:1, N_TYPE:3, N_EXT:1. Stabs (debug entries) claim the top three bits; N_TYPE selects undefined/absolute/section/indirect; N_EXT is the global/local switch; N_PEXT marks private-external (hidden visibility).</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>loader.h's symtab_command (cmd 0x2, cmdsize 24): symoff, nsyms, stroff, strsize — four u32s after cmd and cmdsize. nlist.h's nlist_64 (16 bytes):</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Size</th><th scope="col">Field</th><th scope="col">What it says</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>4</td><td>n_strx</td><td>Name's index into the string table; 0 means the empty name</td></tr>
                        <tr><td>4</td><td>1</td><td>n_type</td><td>N_STAB / N_PEXT / N_TYPE / N_EXT bits</td></tr>
                        <tr><td>5</td><td>1</td><td>n_sect</td><td>1-based section ordinal, or 0 (NO_SECT) for absolute/undefined</td></tr>
                        <tr><td>6</td><td>2</td><td>n_desc</td><td>Reference type, library ordinal (high byte), weak/no-dead-strip bits</td></tr>
                        <tr><td>8</td><td>8</td><td>n_value</td><td>Address of the symbol (or size, for commons)</td></tr>
                    </tbody>
                </table>
                <p>The N_TYPE values from nlist.h: N_UNDF = 0x0 (undefined), N_ABS = 0x2 (absolute), N_INDR = 0xa (alias for another name), N_PBUD = 0xc (prebound), N_SECT = 0xe (defined in section n_sect). Combine with N_EXT = 0x01: <strong>0x0f = N_SECT | N_EXT</strong>, the classic "global function/data" byte, and 0x0e is the local version. n_desc's documented bits: REFERENCE_TYPE = 0x7 (lazy vs non-lazy undefined reference), REFERENCED_DYNAMICALLY = 0x0010, N_NO_DEAD_STRIP = 0x0020, N_WEAK_REF = 0x0040, N_WEAK_DEF = 0x0080, and the high byte is GET_LIBRARY_ORDINAL — which library an undefined symbol belongs to (next-but-one concept uses this).</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Treating n_strx as a file offset. It indexes the string table: the name's file position is stroff + n_strx. Second trap: a common symbol is n_type 0x01 (N_UNDF | N_EXT) with a <em>non-zero</em> n_value — there n_value holds the size in bytes, not an address (nlist.h's own wording).
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>prog64.macho's LC_SYMTAB: symoff 12448, nsyms 6, stroff 12544, strsize 72. The whole table is six entries — and nm reads exactly that:</p>
                <pre><code>$ nm prog64.macho
0000000100000000 T __mh_execute_header
0000000100000410 T _add
0000000100002004 S _bss_counter
0000000100002000 D _global_counter
0000000100000440 t _helper
0000000100000450 T _main</code></pre>
                <p>T/t = text (global/local), D = global data, S = defined outside the standard text/data/bss set — _bss_counter sits in __common. Now the raw bytes of _main's entry (symoff + 16):</p>
                <div class="hex-dump">
                    <pre>000030b0: 0a00 0000 0f01 0000 5004 0000 0100 0000  ........P.......</pre>
                </div>
                <ol>
                    <li><code>0a 00 00 00</code> — n_strx = 10: name at string table offset 10 (file offset 12544 + 10).</li>
                    <li><code>0f</code> — n_type 0x0f = N_SECT | N_EXT: defined, in a section, global. <code>01</code> — n_sect = 1, the first section_64 record (__text).</li>
                    <li><code>00 00</code> — n_desc = 0: no weak, no ordinal tricks.</li>
                    <li><code>50 04 00 00 01 00 00 00</code> — n_value = 0x0000000100000450, the address nm printed. Compare _helper: same layout but n_type 0x0e (local), which is why nm shows lowercase t.</li>
                </ol>
                <p>Both tables live inside __LINKEDIT (fileoff 12288, filesize 328): strings end at 12544 + 72 = 12616 = exactly the end of the file.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Unpack any nlist_64 yourself — the _main entry is bytes 12464..12479:</p>
                <pre><code>$ python3 -c "import struct; d=open('prog64.macho','rb').read(); print(struct.unpack('&lt;IBBhQ', d[12464:12480]))"
(10, 15, 1, 0, 4294968400)</code></pre>
                <p>The five numbers are n_strx, n_type, n_sect, n_desc, n_value — 15 is 0x0f, and 4294968400 is 0x100000450. Same order as the struct in nlist.h, all little-endian, one entry, one function. Cross-check with <code>otool -l prog64.macho | sed -n '/LC_SYMTAB/,/strsize/p'</code> for the four offsets.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a nlist_64 has n_type = 0x0f. What kind of symbol is it?</p>
                <div class="quiz" id="quiz-symtab-1">
                    <button class="quiz-option" data-correct="false" data-explain="Undefined-and-external is N_UNDF | N_EXT = 0x00 | 0x01 = 0x01. 0x0f has the N_TYPE bits set to 0xe (N_SECT), so the symbol is defined." onclick="checkQuiz('quiz-symtab-1', this)">Undefined and external</button>
                    <button class="quiz-option" data-correct="false" data-explain="Stab entries set N_STAB bits (0xe0) in the top three bit positions. 0x0f has none of them set." onclick="checkQuiz('quiz-symtab-1', this)">A debug stab entry</button>
                    <button class="quiz-option" data-correct="true" data-explain="N_TYPE (0x0e mask) gives 0x0e = N_SECT — defined in section n_sect — and N_EXT (0x01) is set: a global defined symbol, the byte you saw on _main." onclick="checkQuiz('quiz-symtab-1', this)">Defined in its section, and external (global)</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A symbol reports n_strx = 0x0000000a, and LC_SYMTAB says stroff = 12544. Where does its name start in the file?</p>
                <div class="quiz" id="quiz-symtab-2">
                    <button class="quiz-option" data-correct="false" data-explain="File offset 10 would be inside the mach_header. n_strx indexes the string table, never the raw file." onclick="checkQuiz('quiz-symtab-2', this)">At file offset 10</button>
                    <button class="quiz-option" data-correct="true" data-explain="n_strx is an index into the string table, and the string table starts at file offset stroff — so the name is at 12544 + 10 = 12554." onclick="checkQuiz('quiz-symtab-2', this)">At stroff + 10 = 12554</button>
                    <button class="quiz-option" data-correct="false" data-explain="symoff (12448) locates the nlist array itself, not names. Adding the index there would read the middle of the first symbol entry as text." onclick="checkQuiz('quiz-symtab-2', this)">At symoff + 10 = 12458</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: two bases (symoff, stroff), one index rule. That plus little-endian unpacking is the entire parse — nlist.h needs nothing else.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Each entry's n_sect field points straight back into the <a href="/courses/macho/lessons/macho-sections">Sections</a> you decoded — the section ordinal is nothing more than the position of the section_64 record in load-command order.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-dysymtab">The Dynamic Symbol Table</a> — LC_DYSYMTAB slices this same array into locals, defined externals, and undefined symbols, and adds the indirect table that stubs and GOT slots read.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-sections">Prev: Sections</a></span>
                <span><a href="/courses/macho/lessons/macho-dysymtab">Next: The Dynamic Symbol Table</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
