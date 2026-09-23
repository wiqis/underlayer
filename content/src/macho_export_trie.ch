// Mach-O Course — Concept 15: The Export Trie.
// The byte-encoded prefix tree every dylib publishes for dyld and dlsym.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_export_trie() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Export Trie — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>The Export Trie</h1>
            <div class="lesson-meta">18 min · Module 5: Dynamic Linking</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Bind opcodes name the symbols this image needs; something must answer the reverse question — "what does <em>this</em> image provide?" — when dyld resolves another binary's binds, when <code>dlsym</code> runs, and when a re-export fans a dylib's names through a second library. ELF answers with a sorted <code>.dynsym</code>, PE with three parallel export arrays; both are lookup tables over flat names.</p>
                <p>Apple chose a trie instead, and loader.h says why: it "factors out common prefixes" and "reduces LINKEDIT pages in RAM because it encodes all information (name, address, flags) in one small, contiguous range." C++ mangling makes the case extreme — <code>__ZNSo…</code> and <code>__ZNS…</code> share long runs of bytes that a flat table would repeat per symbol. The trie is also load-bearing at runtime: it is the index dyld walks for every bind-by-name across every loaded image.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of a tree whose edges carry string fragments, rooted at byte offset 0 of the export area. Each node is:</p>
                <ol>
                    <li><strong>A uleb128 terminal size</strong> — 0 means "no exported symbol here, just a branch point"; otherwise it counts the payload bytes that follow.</li>
                    <li><strong>The terminal payload</strong> — a uleb flags value, then (normally) a uleb address: the symbol's location "from the mach_header for the image". REEXPORT swaps the address for an ordinal plus a string; STUB_AND_RESOLVER stores two ulebs (stub, resolver).</li>
                    <li><strong>A child count byte (0–255)</strong>, then each edge: a NUL-terminated UTF-8 fragment plus a uleb offset for the child node.</li>
                </ol>
                <p>Lookup walks the tree one character at a time against the requested name — prefixes are stored exactly once, so <code>_malloc</code> and <code>_main</code> share their <code>_m</code> edge. The model's missing piece: that child uleb is measured from the <em>start of the trie</em>, not from the current node — the header comment never says so, so it must be pinned by example below.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Two ways to reach the same payload. Older binaries carry it inside dyld_info's export_off/export_size pair (our dylib: offset 582128, size 1432 — no separate command). Modern binaries promote it to LC_DYLD_EXPORTS_TRIE = 0x80000033, a 16-byte <code>linkedit_data_command</code> &#123;cmd, cmdsize, dataoff, datasize&#125; — the same struct that carries code signatures and chained fixups, because all of them are "a blob at a file offset with a size".</p>
                <p>The terminal flags, straight from loader.h:</p>
                <table>
                    <thead><tr><th scope="col">Flag</th><th scope="col">Value</th><th scope="col">Meaning</th></tr></thead>
                    <tbody>
                        <tr><td>KIND_MASK</td><td>0x03</td><td>0 regular, 1 thread-local, 2 absolute</td></tr>
                        <tr><td>WEAK_DEFINITION</td><td>0x04</td><td>This export may be overridden</td></tr>
                        <tr><td>REEXPORT</td><td>0x08</td><td>Payload is ordinal + string, not an address — re-export from that dylib</td></tr>
                        <tr><td>STUB_AND_RESOLVER</td><td>0x10</td><td>Payload is two ulebs: lazy stub offset, resolver offset</td></tr>
                    </tbody>
                </table>
                <p>And the address rule, again from the header: the uleb after flags is "the location of the content named by the symbol from the mach_header" — an offset from image base, not a vmaddr and not a file offset (they coincide here only because __TEXT.fileoff is 0 and you add the vmaddr).</p>
                <div class="callout callout-warn">
                    <strong>Common mistakes.</strong> Child offsets are absolute within the trie — ld64's export reader resolves them as <code>start + childOffset</code> where start is the trie's base, and walking our sample desyncs under any other rule. Second trap: xxd's ASCII column lies — the bytes <code>43 47 4C 51 56</code> you will see printed as "C G L Q V" are uleb child offsets 67/71/76/81/86, not letters in a label.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>prog64.macho declares it as its own command — a modern-era binary with no LC_DYLD_INFO at all:</p>
                <pre><code>      cmd LC_DYLD_EXPORTS_TRIE
  cmdsize 16
  dataoff 12344
 datasize 96</code></pre>
                <p>All 96 bytes (5 exports, one root, one shared <code>_</code> edge):</p>
                <div class="hex-dump">
                    <pre>00003038: 0001 5f00 0500 055f 6d68 5f65 7865 6375  .._...._mh_execu
00003048: 7465 5f68 6561 6465 7200 4362 7373 5f63  te_header.Cbss_c
00003058: 6f75 6e74 6572 0047 6164 6400 4c6d 6169  ounter.Gadd.Lmai
00003068: 6e00 5167 6c6f 6261 6c5f 636f 756e 7465  n.Qglobal_counte
00003078: 7200 5602 0000 0003 0084 4000 0300 9008  r.V.......@.....
00003088: 0003 00d0 0800 0300 8040 0000 0000 0000  .........@......</pre>
                </div>
                <p>Walk it: byte 0 <code>00</code> — root has no terminal. Byte 1 <code>01</code> — one child; edge <code>5f 00</code> = <code>"_"</code>, child uleb <code>05</code>. Node 5: terminal size <code>00</code>, then <code>05</code> children, five edges — <code>_mh_execute_header\0 43</code> (child 67), <code>bss_counter\0 47</code> (71), <code>add\0 4c</code> (76), <code>main\0 51</code> (81), <code>global_counter\0 56</code> (86). Each leaf: terminal size 2, <code>00</code> flags, then the address uleb — and then <code>00</code> children. The five results:</p>
                <div class="hex-dump">
                    <pre>'__mh_execute_header' flags 0 addr 0x0
'_bss_counter'        flags 0 addr 0x2004
'_add'                flags 0 addr 0x410
'_main'               flags 0 addr 0x450
'_global_counter'     flags 0 addr 0x2000</pre>
                </div>
                <p>nm -g agrees symbol-for-symbol and address-for-address once you add __TEXT's vmaddr 0x100000000: <code>_main</code> trie address 0x450 = nm's 0x100000450, <code>_bss_counter</code> 0x2004 = 0x1000002004's low half (the zero-fill int bss_counter at (__DATA,__bss)+4), <code>_global_counter</code> 0x2000 = the 42 in (__DATA,__data). Five external-defined symbols in the symbol table, five terminals — a dylib's export trie simply <em>is</em> the public face of its dysymtab range.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <pre><code>$ /usr/lib/llvm-21/bin/llvm-nm -g prog64.macho
0000000100000000 T __mh_execute_header
0000000100000410 T _add
0000000100002004 S _bss_counter
0000000100002000 D _global_counter
0000000100000450 T _main

$ xxd -s 12344 -l 96 prog64.macho</code></pre>
                <p>What to look for: exactly five nm lines and five trie terminals; strip the top 32 bits of each nm address and you have the trie's ulebs (0, 0x410, 0x2004, 0x2000, 0x450). In the hex dump, the lone <code>5f 00</code> near the front is the only shared prefix edge — everything else hangs off node 5.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: an edge in the export trie stores the uleb value 81. What is 81 measured from?</p>
                <div class="quiz" id="quiz-exporttrie-1">
                    <button class="quiz-option" data-correct="false" data-explain="A file offset would need dataoff added (our trie lives at 12344), and child ulebs nowhere near 12344+81 appear in a 96-byte trie." onclick="checkQuiz('quiz-exporttrie-1', this)">The file offset of the trie (dataoff)</button>
                    <button class="quiz-option" data-correct="true" data-explain="Child ulebs are offsets within the export payload itself. Our sample proves it: node 5's edges point at 67/71/76/81/86, which land exactly on the five terminal size bytes; ld64 resolves them as start + childOffset." onclick="checkQuiz('quiz-exporttrie-1', this)">Byte 0 of the trie — an absolute offset within the payload</button>
                    <button class="quiz-option" data-correct="false" data-explain="Relative-to-the-node would desync immediately: node 5 would claim its first child sits at 5+67=72, in the middle of _add's terminal, not on a terminal-size byte." onclick="checkQuiz('quiz-exporttrie-1', this)">The current node — a relative skip to the child</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A terminal reads: size 2, then bytes <code>08 00</code>. What has the linker just advertised?</p>
                <div class="quiz" id="quiz-exporttrie-2">
                    <button class="quiz-option" data-correct="false" data-explain="An address of 8 would be 8 bytes into the mach_header — the magic, not a symbol. And flags 0 with address 8 is not what these two bytes say." onclick="checkQuiz('quiz-exporttrie-2', this)">A regular export at address 8</button>
                    <button class="quiz-option" data-correct="true" data-explain="Payload = flags uleb 0x08 (EXPORT_SYMBOL_FLAGS_REEXPORT) + one more uleb. loader.h: for REEXPORT the address slot is replaced by a library ordinal then a string — this symbol is re-exported from another dylib, possibly under a different name." onclick="checkQuiz('quiz-exporttrie-2', this)">A re-export: flags 0x08, then an ordinal (and string) instead of an address</button>
                    <button class="quiz-option" data-correct="false" data-explain="STUB_AND_RESOLVER is 0x10 and would store two ulebs (stub and resolver). 0x08 is the REEXPORT bit, and kind bits are the low 2 bits — 0x08 sits above them." onclick="checkQuiz('quiz-exporttrie-2', this)">A thread-local export with weak linkage</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: size first, flags decide the payload's shape, child count byte closes the node — and every offset inside is measured from the trie's byte 0.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The trie is the one structure from the dyld_info era that survives intact into modern binaries — prog64 ships it as its own LC. The other four streams do not survive: their job moves into the pointer slots themselves.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-chained-fixups">Chained Fixups</a> — how rebase and bind rows get threaded through the data they fix, so the kernel can apply them while paging faults in, replacing 644+120 opcodes with a linked list in the GOT.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-dyld-info">Prev: Rebase and Bind Opcodes</a></span>
                <span><a href="/courses/macho/lessons/macho-chained-fixups">Next: Chained Fixups</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
