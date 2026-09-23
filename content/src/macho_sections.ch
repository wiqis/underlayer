// Mach-O Course — Concept 9: Sections.
// section_64 records: dual names, alignment, flags, types, and attributes.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_sections() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Sections — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>Sections</h1>
            <div class="lesson-meta">15 min · Module 3: Load Commands</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Segments decide where memory comes from; sections decide what it means. ELF programmers reach for .text, .data, .bss; PE programmers for .text and .rdata. Mach-O's equivalents are sections — __text, __data, __cstring, __stubs — and they carry the metadata that lets every tool behave correctly: the linker merges same-named sections, nm finds functions, dyld discovers stub tables and initialiser arrays, debuggers skip sections marked S_ATTR_DEBUG.</p>
                <p>The flags field is the contract. Get it wrong and tools will execute your data or treat code as strings. One 32-bit word separates a section of machine instructions from a section of NUL-terminated C strings.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Immediately after each segment_command_64 come <code>nsects</code> fixed-size records — section_64, 80 bytes each:</p>
                <ul>
                    <li><strong>Two names</strong> — <code>sectname[16]</code> ("__text") and <code>segname[16]</code> ("__TEXT"). Every section repeats its parent segment's name; the pair (__TEXT, __text) uniquely identifies it, which is exactly how otool prints sections.</li>
                    <li><strong>Address and size</strong> — <code>addr</code> and <code>size</code>, in memory (addr sits inside the segment's vmaddr range).</li>
                    <li><strong>File position</strong> — <code>offset</code> plus <code>align</code>, the alignment as a log2 power (4 means 2^4 = 16 bytes).</li>
                    <li><strong>Relocation hook</strong> — <code>reloff</code> and <code>nreloc</code>, used by object files (covered two concepts from now).</li>
                    <li><strong>Meaning</strong> — <code>flags</code>, split into a type (low 8 bits) and any number of attributes (upper 24 bits), plus three reserved words.</li>
                </ul>
                <p>The model's missing piece: sections are numbered. loader.h and nlist.h number them 1, 2, 3... in load-command order across all segments of the file — that number is what a symbol's n_sect field stores, so "section 4" means "the fourth section_64 record the loader walked past."</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>loader.h lays out <code>section_64</code> as 80 bytes: sectname[16], segname[16], addr u64, size u64, offset u32, align u32, reloff u32, nreloc u32, flags u32, reserved1 u32, reserved2 u32, reserved3 u32. It then defines the flags split: <code>SECTION_TYPE = 0x000000ff</code>, <code>SECTION_ATTRIBUTES = 0xffffff00</code>. The types you will actually meet:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Type (low 8)</th><th scope="col">Name</th><th scope="col">Contains</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x0</td><td>S_REGULAR</td><td>Ordinary bytes</td></tr>
                        <tr><td>0x1</td><td>S_ZEROFILL</td><td>Uninitialised space — no file bytes, zero-filled at load</td></tr>
                        <tr><td>0x2</td><td>S_CSTRING_LITERALS</td><td>NUL-terminated C strings</td></tr>
                        <tr><td>0x6</td><td>S_NON_LAZY_SYMBOL_POINTERS</td><td>GOT-style pointers, bound before main</td></tr>
                        <tr><td>0x7</td><td>S_LAZY_SYMBOL_POINTERS</td><td>Lazy binding slots (la_symbol_ptr)</td></tr>
                        <tr><td>0x8</td><td>S_SYMBOL_STUBS</td><td>Jump stubs that trigger lazy binding</td></tr>
                        <tr><td>0x9</td><td>S_MOD_INIT_FUNC_POINTERS</td><td>Initialiser function pointers (constructors)</td></tr>
                        <tr><td>0xb</td><td>S_COALESCED</td><td>Symbols to coalesce across objects (eh_frame)</td></tr>
                    </tbody>
                </table>
                <p>The attribute bits you will meet in real files: S_ATTR_PURE_INSTRUCTIONS = 0x80000000, S_ATTR_SOME_INSTRUCTIONS = 0x00000400, S_ATTR_DEBUG = 0x02000000, S_ATTR_EXT_RELOC = 0x00000200, S_ATTR_LOC_RELOC = 0x00000100. Two reserved words are not reserved in practice: for stub and symbol-pointer sections, <code>reserved1</code> is the section's start index into the indirect symbol table and <code>reserved2</code> is the stub's byte size — loader.h documents both.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Reading flags as one number. It is always two questions: flags AND 0xff gives the type; flags AND 0xffffff00 gives the attributes. Also: a zerofill section's offset is 0 with no backing bytes — loader.h notes zero-fill sections are always last in their segment so the segment's tail padding can serve them.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>All four sections of <code>prog64.o</code>, straight from otool:</p>
                <pre><code>  sectname __text
    offset 544
     align 2^4 (16)
    reloff 816
    nreloc 5
     flags 0x80000400
  sectname __data
    offset 664
     align 2^2 (4)
    reloff 0
    nreloc 0
     flags 0x00000000
  sectname __common
    offset 0
     align 2^2 (4)
    reloff 0
    nreloc 0
     flags 0x00000001
  sectname __eh_frame
    offset 672
     align 2^3 (8)
    reloff 0
    nreloc 0
     flags 0x6800000b</code></pre>
                <ul>
                    <li>__text: 0x80000400 = type 0 (S_REGULAR) plus PURE_INSTRUCTIONS and SOME_INSTRUCTIONS — this section is only machine code, aligned to 16 bytes, carrying 5 relocations for the linker.</li>
                    <li>__data: flags 0 — plain regular data, the default for everything unremarkable.</li>
                    <li>__common: flags 1 = S_ZEROFILL, which is why offset is 0 — its 4 bytes exist only in memory.</li>
                    <li>__eh_frame: 0x6800000b = type 0xb (S_COALESCED) plus NO_TOC, STRIP_STATIC_SYMS, and LIVE_SUPPORT attribute bits — coalesced, strippable, linker-managed data, not code.</li>
                </ul>
                <p>A linked dylib shows the richer cases: __stubs has flags 0x80000408 (type 8, instructions) with reserved2 = 6 (each stub is 6 bytes); __cstring has flags 2; __la_symbol_ptr flags 7; __got flags 6 with reserved1 = 172 — the index where its 41 indirect-symbol entries begin.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <pre><code>$ otool -l prog64.o | grep -E "^  sectname|^    offset|^     align|^    reloff|^    nreloc|^     flags"
  sectname __text
    offset 544
     align 2^4 (16)
    reloff 816
    nreloc 5
     flags 0x80000400
  ...</code></pre>
                <p>What to look for: <code>align 2^n</code> is a power-of-two exponent, not a byte count (2^4 = 16); a non-zero reloff/nreloc pair marks an unlinked object file; and every section you see is followed by loader.h's rule that same-named sections in the same segment get merged by the link editor into one aligned, zero-padded result.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: prog64.o's __text section reports flags = 0x80000400. What does that say?</p>
                <div class="quiz" id="quiz-sections-1">
                    <button class="quiz-option" data-correct="false" data-explain="SECTION_TYPE is only the low 8 bits (0xff). 0x400 has no bits below 0x100, so the type is 0, not 0x40." onclick="checkQuiz('quiz-sections-1', this)">Type 0x40 with attribute 0x80000000</button>
                    <button class="quiz-option" data-correct="true" data-explain="Low 8 bits 0x00 = S_REGULAR; 0x80000000 = S_ATTR_PURE_INSTRUCTIONS; 0x00000400 = S_ATTR_SOME_INSTRUCTIONS. Regular section, all machine code." onclick="checkQuiz('quiz-sections-1', this)">S_REGULAR type, PURE_INSTRUCTIONS and SOME_INSTRUCTIONS attributes</button>
                    <button class="quiz-option" data-correct="false" data-explain="The top bit is not reserved — it is S_ATTR_PURE_INSTRUCTIONS, the attribute that tells tools this section contains only true machine instructions." onclick="checkQuiz('quiz-sections-1', this)">Type 0 with attribute 0x400 only; the top bit is reserved</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>libasyncProfiler.dylib's __bss section prints size 0x9739, offset 0, align 2^4, flags 0x00000001. Where do its bytes live on disk?</p>
                <div class="quiz" id="quiz-sections-2">
                    <button class="quiz-option" data-correct="false" data-explain="offset 0 would be the mach_header — no section points there. For S_ZEROFILL, offset 0 means 'no file data at all'." onclick="checkQuiz('quiz-sections-2', this)">At file offset 0, right where the header is</button>
                    <button class="quiz-option" data-correct="true" data-explain="flags 1 = S_ZEROFILL: the section claims 0x9739 bytes of memory inside __DATA but occupies no file bytes — the loader maps and zeroes them, and 2^4 alignment applies to the address, not a file position." onclick="checkQuiz('quiz-sections-2', this)">Nowhere — S_ZEROFILL reserves memory only, zeroed at load</button>
                    <button class="quiz-option" data-correct="false" data-explain="S_ZEROFILL sections are deliberately excluded from the file so binaries stay small; they ride along on the segment's vmsize-over-filesize tail instead." onclick="checkQuiz('quiz-sections-2', this)">At the end of __LINKEDIT, padded to align 16</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: offset only means something when the section type stores file bytes. Check the type first, then the offset — never the reverse.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Sections subdivide the <a href="/courses/macho/lessons/macho-segments">LC_SEGMENT_64</a> commands you just decoded — same command stream, one level finer, with the flags word doing the heavy lifting.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-symtab">The Symbol Table</a> — every symbol's n_sect field is one of these section numbers, and the names you have been reading as strings live in a separate table in __LINKEDIT.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-segments">Prev: LC_SEGMENT_64</a></span>
                <span><a href="/courses/macho/lessons/macho-symtab">Next: The Symbol Table</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
