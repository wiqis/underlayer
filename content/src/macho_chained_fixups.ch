// Mach-O Course — Concept 16: Chained Fixups.
// dyld_chained_fixups_header: fixup rows threaded through the pointers themselves.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_chained_fixups() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Chained Fixups — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>Chained Fixups</h1>
            <div class="lesson-meta">20 min · Module 6: Modern Linking &amp; Entry</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The dyld_info streams work, but they sit in __LINKEDIT while the pointers they describe sit in __DATA_CONST — far apart, and dyld must read them before anything runs. fixup-chains.h states the modern goal outright: the per-segment starts are "passed down to the kernel for page-in linking", so a page's fixups can be applied the moment that page faults in, without hunting through a side table. ELF's answer to the same pressure was DT_RELR bitmaps; Apple's answer is to stop treating fixup locations as data at all — the locations <em>are</em> the pointer slots, linked into chains.</p>
                <p>This is also the structural break between the course's two sample eras: libasyncProfiler.dylib carries four separate streams and no chain command; prog64.macho carries chains and a trie and no LC_DYLD_INFO. One load command, LC_DYLD_CHAINED_FIXUPS, replaces rebase, bind, weak_bind, and lazy_bind.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three regions, all offsets from the start of one blob:</p>
                <ol>
                    <li><strong>Starts</strong> — per segment, per page: the file offset of the first fixup slot on that page.</li>
                    <li><strong>Imports</strong> — a table of (library ordinal, weak bit, symbol-name offset) — the bind opcodes' state columns, flattened into fixed-size records.</li>
                    <li><strong>Symbols</strong> — the string pool the import records point into.</li>
                </ol>
                <p>Then the trick: every pointer slot packs a <code>next</code> distance to the following slot on its page plus a one-bit <code>bind</code> tag. Walk the page following next-hops; at each slot read bind — 0 means "this is a rebase: the other bits hold a target", 1 means "this is an import: the other bits hold an ordinal into the imports table". One pointer, two interpretations, selected by one bit.</p>
                <p>The model's missing piece: <code>next</code> is a small distance, not an address — chains die at the end of the page (0 = last element), and slots that need no fixup are simply not linked.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The blob opens with <code>dyld_chained_fixups_header</code> — seven u32s, verbatim from the header: fixups_version (0), starts_offset, imports_offset, symbols_offset, imports_count, imports_format (1 = DYLD_CHAINED_IMPORT, 2 = +addend s32, 3 = +addend64), symbols_format (0 uncompressed, 1 zlib). Then <code>dyld_chained_starts_in_image</code> &#123;seg_count, seg_info_offset&#91;&#93;&#125;, where each non-zero entry points at a <code>dyld_chained_starts_in_segment</code>: size, page_size (u16, 0x1000 or 0x4000), pointer_format (u16), segment_offset (u64), max_valid_pointer, page_count, then page_start&#91;&#93; — each entry the first chain's offset within that page, or 0xFFFF (DYLD_CHAINED_PTR_START_NONE) for a page with no fixups.</p>
                <p>pointer_format picks the slot bit layout. The header's enum includes DYLD_CHAINED_PTR_ARM64E = 1 (stride 8, arm64e pointer authentication), DYLD_CHAINED_PTR_64 = 2 ("target is vmaddr" — plain 64-bit userland, this course's samples' format family), DYLD_CHAINED_PTR_32 = 3, DYLD_CHAINED_PTR_64_OFFSET = 6 (target is a vm offset), and DYLD_CHAINED_PTR_ARM64E_USERLAND24 = 12 (24-bit bind ordinals). For PTR_64, the two overlay structs from fixup-chains.h:</p>
                <p class="formula">dyld_chained_ptr_64_rebase: target:36, high8:8, reserved:7, next:12, bind:1 — bind == 0<br>dyld_chained_ptr_64_bind: ordinal:24, addend:8, reserved:19, next:12, bind:1 — bind == 1</p>
                <p>Both carry "4-byte stride" next fields per the header's comments; the rebase target is a 36-bit vmaddr (64 GiB image ceiling), the bind ordinal indexes imports_format 1's record — <code>dyld_chained_import</code> &#123;lib_ordinal:8, weak_import:1, name_offset:23&#125; — the same ordinal space as the bind opcodes, now in a struct instead of a stream.</p>
                <div class="callout callout-warn">
                    <strong>Common mistakes.</strong> Do not read this blob with Mach-O's little-endian habit on auto-pilot and then mis-attribute field order — the header's u32s are plain little-endian like the rest of the file; it is only the code-signature superblob (later module) that flips to big-endian. And an empty payload is legal: seg_info_offset 0 for every segment means "no chains here", not "corrupt" — header still required.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>prog64.macho: LC_DYLD_CHAINED_FIXUPS at dataoff 12288, datasize 56 — the entire payload:</p>
                <div class="hex-dump">
                    <pre>00003000: 0000 0000 2000 0000 3800 0000 3800 0000  .... ...8...8...
00003010: 0000 0000 0100 0000 0000 0000 0000 0000  ................
00003020: 0400 0000 0000 0000 0000 0000 0000 0000  ................
00003030: 0000 0000 0000 0000                      ........</pre>
                </div>
                <p>Little-endian u32s: fixups_version 0, starts_offset 32, imports_offset 56, symbols_offset 56, imports_count 0, imports_format 1, symbols_format 0. At byte 32: seg_count 4, then seg_info_offset [0, 0, 0, 0] — every segment reports no chains, so no pointer_format or page_start arrays exist at all. imports_offset = symbols_offset = datasize = 56: both tables start exactly where the blob ends — zero records, zero strings. The four zero u32s past the starts table are alignment padding to the declared size.</p>
                <p>Why empty? Look at prog.c: one initialized int, one zero-fill int, one static helper, arithmetic between them — every reference is RIP-relative or intra-image, zero undefined symbols (the header carries MH_NOUNDEFS), zero binds, and self-pointers that x86-64's PC-relative code never creates. ld64 still emits the command — modern toolchains always do — with a valid header describing nothing to fix. The arm64 twin repeats the trick: dataoff 32768, datasize 56, same skeleton. Contrast the dylib, which has 644 rebases and 120 binds worth of chains on a real application — its equivalent blob would be full of seg_info_offset values and per-page starts.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <pre><code>$ xxd -s 12288 -l 56 prog64.macho
00003000: 0000 0000 2000 0000 3800 0000 3800 0000  .... ...8...8...

$ python3 -c "import struct; d=open('prog64.macho','rb').read(); print(struct.unpack_from('&lt;7I', d, 12288))"
(0, 32, 56, 56, 0, 1, 0)</code></pre>
                <p>What to look for: unpacking '&lt;7I' gives the header in field order — three of the five middle values are the numbers 32/56/56 you can see repeated as <code>20 00 … 38 00 … 38 00</code> in the dump. Then repeat both commands against a dylib built with -fixup_chains on your own machine: imports_count will be non-zero, imports_offset will point inside the blob, and seg_info_offset entries will no longer all be zero.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: dyld walks a chain and finds a slot whose lowest bit is 1. What are the other bits?</p>
                <div class="quiz" id="quiz-fixups-1">
                    <button class="quiz-option" data-correct="false" data-explain="A 36-bit vmaddr target belongs to the rebase overlay, which is selected when bind == 0, not 1." onclick="checkQuiz('quiz-fixups-1', this)">A rebase target — 36-bit vmaddr plus high8</button>
                    <button class="quiz-option" data-correct="true" data-explain="bind == 1 selects dyld_chained_ptr_64_bind: a 24-bit import ordinal (into the imports table), an 8-bit addend, and the next:12 hop — dyld looks the symbol up by ordinal and writes it into the slot." onclick="checkQuiz('quiz-fixups-1', this)">The bind overlay: import ordinal, addend, next hop</button>
                    <button class="quiz-option" data-correct="false" data-explain="Symbol strings live once in the symbols region; slots carry only an ordinal. The bit's whole job is choosing between the two overlays, not locating strings." onclick="checkQuiz('quiz-fixups-1', this)">A direct pointer to the symbol's bytes in the blob</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A chained-fixups header reports imports_offset = 56, symbols_offset = 56, and datasize = 56. What do you conclude?</p>
                <div class="quiz" id="quiz-fixups-2">
                    <button class="quiz-option" data-correct="false" data-explain="symbols_format is its own field (0 here = uncompressed, 1 = zlib); equal offsets say nothing about compression." onclick="checkQuiz('quiz-fixups-2', this)">The symbol strings are zlib-compressed</button>
                    <button class="quiz-option" data-correct="true" data-explain="Both tables begin at byte 56, which is exactly the declared size — they occupy zero bytes. With imports_count 0 as well, this image has no imports: the header and starts table describe an empty fixup set, which is exactly what prog64.macho ships." onclick="checkQuiz('quiz-fixups-2', this)">Both tables are empty — the image has nothing to import</button>
                    <button class="quiz-option" data-correct="false" data-explain="Offsets are measured from the blob's byte 0, not the file's. A file-relative reading would put both tables far past the end of this 56-byte payload." onclick="checkQuiz('quiz-fixups-2', this)">The tables live at file offset 56 — before the load commands end</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: every offset in this blob is relative to the blob; equal offsets mean empty regions; imports_count is the count that makes them matter.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>With fixups (rebase and bind) and exports (the trie) resolved, dyld's remaining job on a linked executable is administrative: find its own code path, decide where the process starts, and jump.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-entry">The Dynamic Linker and Entry Point</a> — LC_LOAD_DYLINKER names /usr/lib/dyld, LC_MAIN names the entry file offset, and the slide arithmetic turns both into runtime addresses.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-export-trie">Prev: The Export Trie</a></span>
                <span><a href="/courses/macho/lessons/macho-entry">Next: The Dynamic Linker and Entry Point</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
