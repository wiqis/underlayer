// Mach-O Course — Concept 14: Rebase and Bind Opcodes.
// LC_DYLD_INFO_ONLY's five __LINKEDIT byte streams and the machine dyld runs.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_dyld_info() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Rebase and Bind Opcodes — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>Rebase and Bind Opcodes</h1>
            <div class="lesson-meta">20 min · Module 5: Dynamic Linking</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Two address problems appear the moment an image loads. First, <a href="/courses/macho/lessons/macho-header">MH_PIE</a> randomizes the load address, so every pointer the linker wrote to <em>this image's own</em> data is now off by the slide — those fixups are called <strong>rebases</strong>. Second, <code>printf</code> lives in libSystem, whose address nobody knows at link time — those fixups are called <strong>binds</strong>, and each one names the library ordinal you learned in <a href="/courses/macho/lessons/macho-dylibs">Dynamic Libraries</a>.</p>
                <p>The classic answer, live since OS X 10.6, is one load command and five compressed byte streams in __LINKEDIT. loader.h notes the streams need "no endian swapping" — they are opcodes, not structs. This is Mach-O's equivalent of ELF's <code>.rela.dyn</code> plus <code>.rela.plt</code>, and of PE's import-address-table fixups, but expressed as a tiny bytecode dyld interprets.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>loader.h defines both streams as tables, then compresses them. Rebase info is conceptually rows of:</p>
                <p class="formula">&lt;seg-index, seg-offset, type&gt;</p>
                <p>Bind info is conceptually rows of:</p>
                <p class="formula">&lt;seg-index, seg-offset, type, symbol-library-ordinal, symbol-name, addend&gt;</p>
                <p>"The opcodes are a compressed way to encode the table by only encoding when a column changes." So the stream is a little state machine: <em>set</em> opcodes update columns (segment, offset, ordinal, symbol), <em>do</em> opcodes emit one or a run of rows. Rebinding means adding the slide to a self-pointer; binding means writing a resolved foreign address into the slot.</p>
                <p>The model's missing piece: a do-op also advances the offset by one pointer (8 bytes), and runs like "five rows at consecutive slots" cost one byte. Most of the stream is runs and repeated columns — that is where the compression comes from.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><code>dyld_info_command</code> is 48 bytes: cmd, cmdsize, then five (offset, size) pairs — rebase, bind, weak_bind, lazy_bind, export. Two constants exist: LC_DYLD_INFO = 0x22 and LC_DYLD_INFO_ONLY = 0x80000022. The high bit is LC_REQ_DYLD, which loader.h defines as: if dyld meets a required command it does not understand, it issues an "unknown load command required for execution" error and refuses the image. Unknown commands <em>without</em> the bit are simply ignored.</p>
                <p>The rebase opcodes (high nibble = opcode, low nibble = immediate):</p>
                <table>
                    <thead><tr><th scope="col">Byte</th><th scope="col">Opcode</th><th scope="col">Effect</th></tr></thead>
                    <tbody>
                        <tr><td>0x00</td><td>DONE</td><td>End of stream</td></tr>
                        <tr><td>0x10</td><td>SET_TYPE_IMM</td><td>Type = nibble (1 pointer, 2 text absolute, 3 text pcrel)</td></tr>
                        <tr><td>0x20</td><td>SET_SEGMENT_AND_OFFSET_ULEB</td><td>Segment = nibble (0-based), then uleb offset</td></tr>
                        <tr><td>0x30</td><td>ADD_ADDR_ULEB</td><td>Offset += uleb</td></tr>
                        <tr><td>0x40</td><td>ADD_ADDR_IMM_SCALED</td><td>Offset += nibble × 8</td></tr>
                        <tr><td>0x50</td><td>DO_REBASE_IMM_TIMES</td><td>Emit nibble rows, each +8</td></tr>
                        <tr><td>0x60</td><td>DO_REBASE_ULEB_TIMES</td><td>Emit uleb rows</td></tr>
                        <tr><td>0x70</td><td>DO_REBASE_ADD_ADDR_ULEB</td><td>Emit one row, then offset += 8 + uleb</td></tr>
                        <tr><td>0x80</td><td>DO_REBASE_ULEB_TIMES_SKIPPING_ULEB</td><td>Emit uleb rows, gap = uleb</td></tr>
                    </tbody>
                </table>
                <p>The bind stream uses the same shape with its own opcodes: DONE 0x00, SET_DYLIB_ORDINAL_IMM 0x10, SET_DYLIB_ORDINAL_ULEB 0x20, SET_DYLIB_SPECIAL_IMM 0x30, SET_SYMBOL_TRAILING_FLAGS_IMM 0x40 (nibble = symbol flags: weak-import 0x1, non-weak-definition 0x8), SET_TYPE_IMM 0x50, SET_ADDEND_SLEB 0x60, SET_SEGMENT_AND_OFFSET_ULEB 0x70, ADD_ADDR_ULEB 0x80, DO_BIND 0x90, then DO_BIND_ADD_ADDR_ULEB 0xA0, DO_BIND_ADD_ADDR_IMM_SCALED 0xB0, DO_BIND_ULEB_TIMES_SKIPPING_ULEB 0xC0. Special ordinals from 0x30 sign-extend the nibble: 0 is self, 0xF is −1 (main executable), 0xE is −2 (flat lookup), 0xD is −3 (weak lookup).</p>
                <p>The third stream, weak_bind, is the same opcodes "sorted alphabetically by symbol name" so dyld can walk every image in order and detect collisions after binding — loader.h's example: calls to <code>operator new</code> first bind normally, then get rebound if some image overrides it. The fourth, lazy_bind, holds one DONE-terminated entry per lazy symbol: the stub helper pushes the entry's offset, dyld adds it to lazy_bind_off and binds on first call. The fifth stream, export_off, is the next lesson.</p>
                <div class="callout callout-warn">
                    <strong>Common mistakes.</strong> The segment index is 0-based over LC_SEGMENT_64 commands in header order — for an executable that makes __PAGEZERO index 0 (there is no +1, and pagezero counts). DO_REBASE_IMM_TIMES takes its count straight from the nibble — no +1 anywhere in dyld's decoder. And ordinal 1 is not "special": it is simply the first LC_LOAD_DYLIB.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The classic-era sample: <code>libasyncProfiler.dylib</code> (x86_64 slice of a FAT file) has LC_DYLD_INFO_ONLY and no chained-fixups or exports-trie commands. otool prints the five streams:</p>
                <pre><code>            cmd LC_DYLD_INFO_ONLY
        cmdsize 48
     rebase_off 573440
    rebase_size 248
       bind_off 573688
      bind_size 2664
  weak_bind_off 576352
 weak_bind_size 1120
  lazy_bind_off 577472
 lazy_bind_size 4656
     export_off 582128
    export_size 1432</code></pre>
                <p>The rebase stream starts exactly at __LINKEDIT's fileoff (573440). First bytes:</p>
                <div class="hex-dump">
                    <pre>00090000: 1121 0055 4470 1854 4557 4470 1852 4260  .!.UDp.TEWDp.RB`
00090010: 1141 5741 5b30 e00c 5841 7008 5241 5841  .AWA[0..XAp.RAXA</pre>
                </div>
                <p>Decode: <code>11</code> set type pointer; <code>21 00</code> segment 1 (__DATA_CONST, the second LC_SEGMENT_64), offset 0; <code>55</code> rebase five times — slots 0, 8, 16, 24, 32 — the front of (__DATA_CONST,__got), whose vmaddr is 0x7c000; <code>44</code> add 4 × 8 → offset 72; <code>70 18</code> rebase once at 72 then jump +8+24. Fully decoded: <strong>644 rebase targets</strong>, all type 1, all in segments 1 and 2 — self-pointers in __got, __mod_init_func, and __data needing the slide.</p>
                <p>The bind stream (file offset 573688):</p>
                <div class="hex-dump">
                    <pre>000900f8: 1140 5f5f 5f73 7461 636b 5f63 686b 5f67  .@___stack_chk_g
00090108: 7561 7264 0051 7180 0290 405f 6578 6974  uard.Qq...@_exit</pre>
                </div>
                <p><code>11</code> ordinal 1 (first LC_LOAD_DYLIB — /usr/lib/libSystem.B.dylib); <code>40</code> then the NUL-terminated name <code>___stack_chk_guard</code> (nm confirms: <code>U ___stack_chk_guard</code>); <code>51</code> type pointer; <code>71 80 02</code> segment 1, uleb offset 256 — inside __got; <code>90</code> DO_BIND: dyld resolves the symbol in libSystem and writes it there. Then <code>40 _exit</code>, <code>80 08</code> add 8, <code>90</code> bind the next eager import. <strong>120 eager binds</strong> total; the lazy stream opens <code>72 00 11 40 __Unwind_Resume 00 90 00</code> — set segment 2 (__DATA), ordinal 1, name, bind, DONE — one entry per lazy stub, <strong>166</strong> in all; weak_bind (1120 bytes) opens directly with a symbol name, no ordinal preamble.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <pre><code>$ /usr/lib/llvm-21/bin/llvm-otool -arch x86_64 -l libasyncProfiler.dylib | grep -A12 LC_DYLD_INFO_ONLY

$ xxd -s $((0x4000 + 573440)) -l 32 libasyncProfiler.dylib
00090000: 1121 0055 4470 1854 4557 4470 1852 4260  .!.UDp.TEWDp.RB`</code></pre>
                <p>What to look for: rebase_off equals __LINKEDIT's fileoff (the streams sit at the segment's front); the stream's first byte is an opcode, not a struct magic — start decoding at <code>11 21 00</code> and the rows should land in (__DATA_CONST,__got). Remember the 0x4000: this sample is a FAT file, so slice-relative offsets need the fat_arch offset added.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: which of the five streams moves this image's own pointers after ASLR, and which one fills GOT slots with addresses from other images?</p>
                <div class="quiz" id="quiz-dyldinfo-1">
                    <button class="quiz-option" data-correct="false" data-explain="lazy_bind only resolves lazy stub symbols on first call, one DONE-terminated entry each — it is not the slide pass." onclick="checkQuiz('quiz-dyldinfo-1', this)">lazy_bind does both — it is the only stream dyld runs</button>
                    <button class="quiz-option" data-correct="true" data-explain="Rebase adds the slide to self-pointers (644 rows here); bind writes foreign symbols by library ordinal (120 rows). Two streams, two different address problems." onclick="checkQuiz('quiz-dyldinfo-1', this)">rebase fixes the slide; bind resolves foreign symbols</button>
                    <button class="quiz-option" data-correct="false" data-explain="export describes what this image offers to others — the reverse direction. It writes nothing into this image's slots." onclick="checkQuiz('quiz-dyldinfo-1', this)">export does both — it advertises and imports symbols</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are mid-decode of a bind stream and hit byte <code>0x12</code>. What does it mean?</p>
                <div class="quiz" id="quiz-dyldinfo-2">
                    <button class="quiz-option" data-correct="false" data-explain="Type is set by opcode 0x50 (SET_TYPE_IMM), not 0x10. The high nibble 1 selects the ordinal-set family." onclick="checkQuiz('quiz-dyldinfo-2', this)">SET_TYPE_IMM with type 2 (text absolute 32)</button>
                    <button class="quiz-option" data-correct="true" data-explain="0x10 = SET_DYLIB_ORDINAL_IMM, and the low nibble 2 is the ordinal itself: bind the following symbol against the second LC_LOAD_DYLIB. (Ordinal 1 was libSystem; 2 is libc++ in our sample.)" onclick="checkQuiz('quiz-dyldinfo-2', this)">SET_DYLIB_ORDINAL_IMM — use ordinal 2 from now on</button>
                    <button class="quiz-option" data-correct="false" data-explain="Specials live under opcode 0x30 with sign-extended nibbles. 0x12 belongs to the plain ordinal-set family and the nibble is taken as-is." onclick="checkQuiz('quiz-dyldinfo-2', this)">SET_DYLIB_SPECIAL_IMM — ordinal −14</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: read the high nibble as the opcode and the low nibble as its argument — then watch the five state columns, not the raw bytes.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Four of the five streams are consumed entirely by dyld at load time; the fifth (export_off, 1432 bytes here) is the image's outward face — every name other binaries will bind against.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-export-trie">The Export Trie</a> — the prefix-sharing tree dyld walks to answer "does this dylib export that symbol?", and the structure modern binaries promote into its own load command.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-dylibs">Prev: Dynamic Libraries and Install Names</a></span>
                <span><a href="/courses/macho/lessons/macho-export-trie">Next: The Export Trie</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
