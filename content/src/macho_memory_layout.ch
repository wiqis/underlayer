// Mach-O Course — Concept 23: Process Memory Layout.
// Preferred vmaddrs, the ASLR slide, and translating between file offsets and addresses.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_memory_layout() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Process Memory Layout — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>Process Memory Layout</h1>
            <div class="lesson-meta">18 min · Module 8: Loading &amp; Execution</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A crash log says 0x7fff5fbff000. Is that stack, a dylib, or the NULL guard? A debugger says your code is at 0x100004450 but the file says 0x100000450. Symbol offsets in a bug tracker are file bytes, not addresses. Every one of these is a collision between three coordinate systems — file offset, preferred vmaddr, and runtime address — and this lesson is where you learn to tell them apart.</p>
                <p>The layout is also the contract between everything so far: __PAGEZERO set the base, dyld applied the slide, segments declared what can be read or written. Get the translation wrong and you will "fix" a bug at an address that is not even mapped.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>One picture, then the rule:</p>
                <ol>
                    <li><strong>0x0 – 0x100000000</strong> — __PAGEZERO: reserved, no access, no file.</li>
                    <li><strong>0x100000000</strong> — __TEXT preferred base: header, load commands, code.</li>
                    <li><strong>0x100002000</strong> — __DATA preferred base: initialized globals, then zero-fill commons.</li>
                    <li><strong>0x100003000</strong> — __LINKEDIT: fixups, exports, symbols, strings.</li>
                    <li><strong>Above the image</strong> — the heap grows up; <strong>far above, near 0x7fff…</strong> — the stack grows down; dependencies (e.g. /usr/lib/libSystem.B.dylib) land wherever dyld's randomized closure put them.</li>
                </ol>
                <p>The rule: <em>runtime address = preferred vmaddr + slide</em>, applied uniformly to every image. The rule's missing piece: preferred is a preference, not a fact — MH_PIE exists so the second run of the program sees none of these numbers as printed. And file offsets are a separate axis entirely: to translate, find the segment whose file range contains the offset, then add (offset − fileoff) to that segment's vmaddr.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The full preferred map of <code>prog64.macho</code>, straight from its four LC_SEGMENT_64 commands:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Segment</th><th scope="col">Preferred vmaddr</th><th scope="col">vmsize</th><th scope="col">fileoff / filesize</th><th scope="col">initprot</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>__PAGEZERO</td><td>0x0</td><td>0x100000000</td><td>0 / 0</td><td>0</td></tr>
                        <tr><td>__TEXT</td><td>0x100000000</td><td>0x2000</td><td>0 / 8192</td><td>5</td></tr>
                        <tr><td>__DATA</td><td>0x100002000</td><td>0x1000</td><td>8192 / 4096</td><td>3</td></tr>
                        <tr><td>__LINKEDIT</td><td>0x100003000</td><td>0x148</td><td>12288 / 328</td><td>1</td></tr>
                    </tbody>
                </table>
                <p>Every vmaddr + vmsize equals the next vmaddr — the four segments tile address space contiguously from 0 through 0x100003148 with zero gaps, exactly as their file ranges tile the 12616-byte file. Two section-level details finish the map: __text begins at file offset 1040 (addr 0x100000410, flags 0x80000400 = pure instructions + some instructions), and __common sits at addr 0x100002004 with <em>offset 0</em> and flags 0x1 = S_ZEROFILL — "zero fill on demand" — so <code>_bss_counter</code>'s 4 bytes exist only in memory, which is why filesize accounting stops at initialized data. <code>loader.h</code> even reserves the convention: the link-editor "will allocate common symbols at the end of the __common section in the __DATA segment."</p>
                <p>Contrast with ELF, once: a PIE ELF executable typically declares no fixed base and lets the loader choose; Mach-O's MH_EXECUTE names 0x100000000 explicitly <em>and</em> reserves everything below it. Same ASLR outcome, different philosophy — the address story is part of the file format, not just the loader.</p>
                <div class="callout callout-warn">
                    <strong>Universal files multiply the map.</strong> In <code>universal.macho</code> each slice — x86_64 at file offset 4096, arm64 at 32768 — is a complete thin Mach-O with its <em>own</em> segment map, its own preferred addresses, its own UUID. Only one slice's map is ever live in a given process.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Every symbol in the file, placed on the map by one <code>nm</code> run:</p>
                <div class="hex-dump">
                    <pre>0000000100000000 T __mh_execute_header
0000000100000410 T _add
0000000100000440 t _helper
0000000100000450 T _main
00000001000002000 D _global_counter
00000001000002004 S _bss_counter</pre>
                </div>
                <p>Read the column as coordinates, not decoration: __mh_execute_header marks 0x100000000, the __TEXT base; _add, _helper, _main sit inside __text (0x100000410 … 0x100000484); _global_counter (type D, data) is the first byte of __DATA — the <code>42</code> you saw at file offset 8192; _bss_counter (type S, zero-fill) is the next 4 bytes at 0x100002004 with no file byte behind them. Lowercase t for _helper says "local text" — the same address space, tighter binding. Two address columns (file layout lesson and this one) now join into one picture.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Verify contiguity and practice the translation — on macOS use <code>otool</code>, on Linux <code>llvm-otool</code>:</p>
                <pre><code>$ llvm-otool -l prog64.macho | grep -E "segname|vmaddr|vmsize|initprot"
   segname __PAGEZERO
   vmaddr 0x0000000000000000
   vmsize 0x0000000100000000
 initprot 0x00000000
   segname __TEXT
   vmaddr 0x0000000100000000
   vmsize 0x0000000000002000
 initprot 0x00000005
   ... __DATA vmaddr 0x100002000 vmsize 0x1000 initprot 0x3
   ... __LINKEDIT vmaddr 0x100003000 vmsize 0x148 initprot 0x1

$ python3 -c "print(hex(0x100000000 + 1104))"
0x100000450</code></pre>
                <p>What to look for: each vmaddr + vmsize equals the next vmaddr — add them on paper until you reach 0x100003148, the first address past the image's preferred extent. The python line is the file-offset translation you will need constantly: LC_MAIN's entryoff (1104) lives in __TEXT, whose fileoff is 0, so the preferred address is base + offset. Next, take a random offset like 8192 or 12288 and do the same by hand.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what is __TEXT's preferred address in <code>prog64.macho</code>, and what determines that particular number?</p>
                <div class="quiz" id="quiz-memlay-1">
                    <button class="quiz-option" data-correct="false" data-explain="0x0 is __PAGEZERO's vmaddr — a guard region with no permissions where no code may live. __TEXT begins exactly where that reservation ends." onclick="checkQuiz('quiz-memlay-1', this)">Address 0 — segments are listed in file order, starting at zero</button>
                    <button class="quiz-option" data-correct="true" data-explain="0x100000000 is the first address above __PAGEZERO's 4 GiB reservation — PAGEZERO's vmsize literally defines where the image's preferred base must sit." onclick="checkQuiz('quiz-memlay-1', this)">0x100000000 — it starts where the 4 GiB PAGEZERO reservation ends</button>
                    <button class="quiz-option" data-correct="false" data-explain="0x100000410 is the address of __text's first byte (file offset 1040) — the segment base is 0x410 bytes below it, holding the header and all 968 bytes of load commands." onclick="checkQuiz('quiz-memlay-1', this)">0x100000410 — the first instruction's address is the segment base</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A fuzzer reports a crash at a file offset of 12288 inside <code>prog64.macho</code> (preferred addresses, slide 0). What virtual address is that?</p>
                <div class="quiz" id="quiz-memlay-2">
                    <button class="quiz-option" data-correct="false" data-explain="__DATA covers file bytes 8192 through 12287 — byte 12288 is the first byte after it, so it belongs to __LINKEDIT, whose vmaddr is 0x100003000." onclick="checkQuiz('quiz-memlay-2', this)">0x100002000 — __DATA is the segment that owns large offsets</button>
                    <button class="quiz-option" data-correct="true" data-explain="12288 is __LINKEDIT's fileoff, so (offset − fileoff) = 0 and the address is its vmaddr: 0x100003000 + 0. Preferred addresses need no slide — that is a translation you apply only for a running process." onclick="checkQuiz('quiz-memlay-2', this)">0x100003000 — __LINKEDIT's vmaddr plus the in-segment delta</button>
                    <button class="quiz-option" data-correct="false" data-explain="You can tell without any slide: file offsets map to preferred vmaddrs through segment fileoff/vmaddr pairs, purely statically. The ASLR slide enters only when talking about a live process." onclick="checkQuiz('quiz-memlay-2', this)">Cannot tell yet — vmaddrs are runtime values, so the slide comes first</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: pick the segment by file range, add (offset − fileoff) to vmaddr for the preferred address, add the slide last — in that order, never mixed.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The map is live now: preferred addresses from the <a href="/courses/macho/lessons/macho-segments">segment commands</a>, a randomized slide from dyld, and a translation rule between disk and memory. One number in that picture has not fired yet — LC_MAIN's entryoff of 1104, sitting in __text at 0x100000450, waiting.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-execution">The Startup Sequence</a> — what the kernel does first, where argv really comes from, and why entryoff does not always point at main().</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-dyld">Prev: How dyld Loads a Mach-O</a></span>
                <span><a href="/courses/macho/lessons/macho-execution">Next: The Startup Sequence</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
