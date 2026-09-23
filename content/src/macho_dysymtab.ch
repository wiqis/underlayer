// Mach-O Course — Concept 11: The Dynamic Symbol Table.
// LC_DYSYMTAB partitions the symtab and adds the indirect symbol table.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_dysymtab() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Dynamic Symbol Table — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>The Dynamic Symbol Table</h1>
            <div class="lesson-meta">15 min · Module 4: Symbols</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>LC_SYMTAB gives you one flat array of nlist_64 entries. dyld cannot scan 2,005 symbols one by one every time it binds a reference — it needs to know, without searching, where the undefined symbols begin, where the exported definitions live, and which symbol each stub slot or GOT entry points at. LC_DYSYMTAB is that index into the same array: no new symbol storage, just ranges and pointers.</p>
                <p>This is the Mach-O answer to ELF's split between .symtab and .dynsym — except here both views share one array, and the "dyn" information is this load command's partitions plus the indirect table.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>One 80-byte command (cmd 0xb) holding eighteen u32 fields in five groups:</p>
                <ol>
                    <li><strong>Three index/count pairs</strong> — locals, defined externals, undefined externals. loader.h: the symbol table is "organized into three groups of symbols: local symbols, defined external symbols, undefined external symbols." The three ranges are contiguous and together cover every entry.</li>
                    <li><strong>toc, modtab, extrefsym</strong> — for dylibs only: which module (object file) defines each exported symbol, per-module ranges, per-module references. loader.h: executables and objects are single modules, so these tables are omitted and the sorted extdef range itself serves as the table of contents.</li>
                    <li><strong>Indirect symbol table</strong> — an array of u32 symbol indexes consumed by stub and pointer sections.</li>
                    <li><strong>extrel / locrel pools</strong> — relocation arrays for dylib files; in object and executable files relocations hang off the section headers instead (loader.h says exactly this).</li>
                </ol>
                <p>The model's missing piece: an indirect table entry is not a symbol — it is an index <em>into</em> LC_SYMTAB's array (or one of two specials, INDIRECT_SYMBOL_LOCAL = 0x80000000 and INDIRECT_SYMBOL_ABS = 0x40000000). The stub at address X and the nlist_64 at that index are two views of the same call target.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>dysymtab_command's fields, in file order after cmd/cmdsize: ilocalsym, nlocalsym, iextdefsym, nextdefsym, iundefsym, nundefsym (the three partitions), then tocoff/ntoc, modtaboff/nmodtab, extrefsymoff/nextrefsyms, indirectsymoff/nindirectsyms, extreloff/nextrel, locreloff/nlocrel — eighteen u32s, 8 + 72 = 80 bytes total.</p>
                <p>The real command from <code>libasyncProfiler.dylib</code> (x86_64 slice):</p>
                <pre><code>            cmd LC_DYSYMTAB
        cmdsize 80
      ilocalsym 0
      nlocalsym 1752
     iextdefsym 1752
     nextdefsym 45
      iundefsym 1797
      nundefsym 218
         tocoff 0
           ntoc 0
      modtaboff 0
        nmodtab 0
   extrefsymoff 0
    nextrefsyms 0
 indirectsymoff 617880
  nindirectsyms 385
      extreloff 0
        nextrel 0
      locreloff 0
        nlocrel 0</code></pre>
                <p>Read the partitions as half-open ranges: locals [0, 1752), defined externals [1752, 1797), undefined [1797, 2015). And they must tile the whole table — 1752 + 45 + 218 = 2015 = nsyms from LC_SYMTAB. If that sum ever disagrees with nsyms, the file is corrupt or you are looking at the wrong architecture slice.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Expecting extrel/locrel to be non-zero. Those pools exist for classic dylib relocations, but this modern dylib has nextrel = nlocrel = 0 — 64-bit toolchains rely on rebase/bind info instead, and object-file relocations live in section headers (reloff/nreloc). tocoff/ntoc/modtaboff are 0 too: loader.h documents them as dylib-only, and even here they can be absent when the newer binding paths take over.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The indirect table's 385 entries are exactly the slots three sections need. Each section's reserved1 field is its starting index (loader.h documents this), and entry counts fall out of size divided by slot size:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Section (flags type)</th><th scope="col">reserved1</th><th scope="col">Entries</th><th scope="col">Slot</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>__stubs (0x8 = S_SYMBOL_STUBS)</td><td>0</td><td>172 (size 0x408 ÷ 6, reserved2 = 6)</td><td>6-byte jump stub</td></tr>
                        <tr><td>__got (0x6 = S_NON_LAZY_SYMBOL_POINTERS)</td><td>172</td><td>41 (size 0x148 ÷ 8)</td><td>8-byte pointer</td></tr>
                        <tr><td>__la_symbol_ptr (0x7 = S_LAZY_SYMBOL_POINTERS)</td><td>213</td><td>172 (size 0x560 ÷ 8)</td><td>8-byte pointer</td></tr>
                    </tbody>
                </table>
                <p>The arithmetic closes twice: 172 + 41 + 172 = 385 = nindirectsyms, and 172 + 41 = 213 = __la_symbol_ptr's starting index. The ranges also line up with the partitions — otool's first stub entries hold indexes 1797, 1798, 1799... exactly where the undefined partition starts, because lazy stubs jump to symbols this image does not define.</p>
                <p>A small file shows the same structure: prog64.macho's LC_DYSYMTAB reads 0/1, 1/5, 6/0 — one local (_helper), five defined globals, nothing undefined. Even a fully resolved static-style executable still carries the command; dyld just has less to do.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <pre><code>$ otool -arch x86_64 -Iv libasyncProfiler.dylib | head -8
libasyncProfiler.dylib:
Indirect symbols for (__TEXT,__stubs) 172 entries
address            index
0x000000000006cb62  1797
0x000000000006cb68  1798
0x000000000006cb6e  1799
0x000000000006cb74  1800
0x000000000006cb7a  1801</code></pre>
                <p>What to look for: the address column walks 6 bytes at a time — one stub per entry, matching reserved2 = 6; and every index it prints lands at or past iundefsym (1797). Dump the command itself with <code>otool -arch x86_64 -l libasyncProfiler.dylib | sed -n '/LC_DYSYMTAB/,/nlocrel/p'</code>.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: iundefsym = 1797 and nundefsym = 218. Which index range holds the undefined symbols?</p>
                <div class="quiz" id="quiz-dysymtab-1">
                    <button class="quiz-option" data-correct="false" data-explain="That is the defined-external partition: iextdefsym 1752 with count 45 covers [1752, 1797) — 45 exported definitions." onclick="checkQuiz('quiz-dysymtab-1', this)">1752 through 1796</button>
                    <button class="quiz-option" data-correct="true" data-explain="Start at iundefsym 1797, take 218 entries: [1797, 2015). The end checks out — 1752 + 45 + 218 = 2015 = nsyms." onclick="checkQuiz('quiz-dysymtab-1', this)">1797 through 2014</button>
                    <button class="quiz-option" data-correct="false" data-explain="[0, 1752) is the local partition (static and debugging symbols) — ilocalsym 0 with nlocalsym 1752." onclick="checkQuiz('quiz-dysymtab-1', this)">0 through 1751</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>__stubs occupies indirect indexes [0, 172) and __got occupies [172, 213). __la_symbol_ptr comes next. What must its reserved1 be, and what is nindirectsyms?</p>
                <div class="quiz" id="quiz-dysymtab-2">
                    <button class="quiz-option" data-correct="false" data-explain="0 would make every section start at the table's first entry — all three would share stubs' indexes and bind the wrong symbols." onclick="checkQuiz('quiz-dysymtab-2', this)">0, with nindirectsyms 172</button>
                    <button class="quiz-option" data-correct="false" data-explain="172 is __stubs' exclusive end and __got's start. Sections do not overlap; each begins where the previous one finished." onclick="checkQuiz('quiz-dysymtab-2', this)">172, with nindirectsyms 344</button>
                    <button class="quiz-option" data-correct="true" data-explain="reserved1 = 172 + 41 = 213, and the table totals 172 + 41 + 172 = 385 entries — matching this dylib's actual nindirectsyms." onclick="checkQuiz('quiz-dysymtab-2', this)">213, with nindirectsyms 385</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: the indirect table is one shared, gap-free pool; reserved1 is a running offset, not a count. That is why section order in the file must match the order the linker allocated entries.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Everything here indexes the array from <a href="/courses/macho/lessons/macho-symtab">The Symbol Table</a> — same symoff, same nsyms, just ranged and cross-referenced instead of flat.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-relocations">Relocation Entries</a> — how the linker learns what to patch while the file is still an object, before any of these dynamic tables matter.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-symtab">Prev: The Symbol Table</a></span>
                <span><a href="/courses/macho/lessons/macho-relocations">Next: Relocation Entries</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
