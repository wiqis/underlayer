// Mach-O Course — Concept 12: Relocation Entries.
// The 8-byte records object files use so the linker can patch references.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_relocations() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Relocation Entries — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>Relocation Entries</h1>
            <div class="lesson-meta">18 min · Module 4: Symbols</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The compiler emits prog64.o without knowing where _helper will finally live, so the call instruction ships as <code>e8 00 00 00 00</code> — four placeholder zeros. Something must tell the linker: "at offset 0x12 in __text there is a 4-byte PC-relative branch against symbol _helper." That something is the relocation entry — Mach-O's equivalent of ELF's .rela.text, and the reason object files and linked images are different species.</p>
                <p>This is the last concept where the linker, not dyld, is the audience. Once you see that final executables carry zero classic relocations, the design of rebase/bind opcodes — and why images need them at all — stops being a mystery.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Each section_64 may point at an array (reloff, nreloc), one 8-byte record per patch site:</p>
                <ul>
                    <li><strong>r_address</strong> (i32) — where to patch: the offset within this section's address space. 0x12 means "18 bytes into __text."</li>
                    <li><strong>A packed word</strong> (u32) carrying five fields: r_symbolnum : 24, r_pcrel : 1, r_length : 2, r_extern : 1, r_type : 4. reloc.h puts them in that exact order (loader.h defers to it).</li>
                </ul>
                <p>How the fields combine: <strong>r_extern = 1</strong> means r_symbolnum is an index into the symbol table — patch against _helper, entry 0. <strong>r_extern = 0</strong> means it is a section ordinal — patch against another section (this is how 8-byte pointers to __text in unwind data get resolved, with r_type UNSIGNED). <strong>r_length</strong> is log2 of the slot width: 0 = 1 byte, 1 = 2 bytes, 2 = 4 bytes, 3 = 8 bytes. <strong>r_pcrel</strong> says the patched value is relative to the next instruction, not absolute.</p>
                <p>The model's missing piece: r_type is architecture vocabulary. The same number 2 means BRANCH on x86_64 and BRANCH26 on arm64 — you cannot decode a relocation without first knowing the file's cputype (there is also a scattered_relocation_info form for 32-bit files; 64-bit code does not use it).</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Within the packed u32, bit positions are: symbolnum 0-23, pcrel bit 24, length bits 25-26, extern bit 27, type bits 28-31. The type enums, from Apple's reloc headers (as mirrored in LLVM's BinaryFormat/MachO.h):</p>
                <table>
                    <thead>
                        <tr><th scope="col">x86_64 type</th><th scope="col">Name</th><th scope="col">arm64 type</th><th scope="col">Name</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>X86_64_RELOC_UNSIGNED</td><td>0</td><td>ARM64_RELOC_UNSIGNED</td></tr>
                        <tr><td>1</td><td>X86_64_RELOC_SIGNED</td><td>1</td><td>ARM64_RELOC_SUBTRACTOR</td></tr>
                        <tr><td>2</td><td>X86_64_RELOC_BRANCH</td><td>2</td><td>ARM64_RELOC_BRANCH26</td></tr>
                        <tr><td>3</td><td>X86_64_RELOC_GOT_LOAD</td><td>3</td><td>ARM64_RELOC_PAGE21</td></tr>
                        <tr><td>4</td><td>X86_64_RELOC_GOT</td><td>4</td><td>ARM64_RELOC_PAGEOFF12</td></tr>
                        <tr><td>5</td><td>X86_64_RELOC_SUBTRACTOR</td><td>5-6</td><td>GOT_LOAD_PAGE21 / PAGEOFF12</td></tr>
                        <tr><td>6-9</td><td>SIGNED_1 / SIGNED_2 / SIGNED_4 / TLV</td><td>7-11</td><td>POINTER_TO_GOT, TLVP_LOAD_*, ADDEND, AUTHENTICATED_POINTER</td></tr>
                    </tbody>
                </table>
                <p>Semantics you will meet constantly: SIGNED patches a RIP-relative displacement (the linker adds the delta); BRANCH patches a call/jump displacement; PAGE21 + PAGEOFF12 are arm64's two-instruction ADRP+ADD/LOAD pair; UNSIGNED writes a raw 64-bit address (pointers, with extern = 0 and a section target).</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Looking for relocations in a linked program. MH_OBJECT files carry them for the linker; MH_EXECUTE and MH_DYLIB images do not — loader.h says executable and object relocation entries "continue to hang off the section structures," while dylib pools sit in LC_DYSYMTAB (and modern 64-bit dylibs leave those pools empty too). Images fix addresses at load time with rebase/bind info or chained fixups instead. prog64.macho's __text has nreloc = 0, correctly.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>All five relocations in <code>prog64.o</code>'s __text (reloff 816, nreloc 5), decoded — every one is pcrel = 1, length = 2 (4-byte slot), extern = 1:</p>
                <table>
                    <thead>
                        <tr><th scope="col">r_address</th><th scope="col">r_type</th><th scope="col">Target (symnum)</th><th scope="col">Instruction it patches</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x12</td><td>2 BRANCH</td><td>0 = _helper</td><td>call disp32 — placeholder <code>e8 00 00 00 00</code> at 0x11</td></tr>
                        <tr><td>0x1B</td><td>1 SIGNED</td><td>3 = _global_counter</td><td>RIP-relative addl reading __data</td></tr>
                        <tr><td>0x5A</td><td>2 BRANCH</td><td>1 = _add</td><td>call disp32 from _main to _add</td></tr>
                        <tr><td>0x60</td><td>1 SIGNED</td><td>2 = _bss_counter</td><td>RIP-relative store into __bss slot</td></tr>
                        <tr><td>0x66</td><td>1 SIGNED</td><td>2 = _bss_counter</td><td>RIP-relative load from that slot</td></tr>
                    </tbody>
                </table>
                <p>Notice r_address points at the <em>displacement</em>, not the opcode — 0x12 sits one byte after the 0xE8 at 0x11. The section's own bytes show the zeros waiting to be filled: __text starts <code>55 48 89 e5 48 83 ec 10</code>, and the linker's only job for these entries is computing target-minus-site and writing it into each 4-byte hole.</p>
                <p>The arm64 object makes the extern = 0 case visible: prog_arm64.o's __compact_unwind holds three UNSIGNED relocations, length = 3 (8-byte slot), extern = 0, symbolnum = 1 — "write the address of section 1 (__text) here," the unwind records pointing at their function's section.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <pre><code>$ llvm-readobj --relocations prog64.o
Relocations &#91;
  Section __text &#123;
    0x66 1 2 1 X86_64_RELOC_SIGNED 0 _bss_counter
    0x60 1 2 1 X86_64_RELOC_SIGNED 0 _bss_counter
    0x5A 1 2 1 X86_64_RELOC_BRANCH 0 _add
    0x1B 1 2 1 X86_64_RELOC_SIGNED 0 _global_counter
    0x12 1 2 1 X86_64_RELOC_BRANCH 0 _helper
  &#125;
&#93;</code></pre>
                <p>The columns are address, pcrel, length, extern, type name, addend, symbol — matching the packed word you decoded by hand. Swap in <code>prog_arm64.o</code> to watch the type names change to ARM64_RELOC_PAGE21, PAGEOFF12, and BRANCH26 while the bit layout stays identical.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a relocation entry reports r_length = 2. What width does it patch?</p>
                <div class="quiz" id="quiz-relocs-1">
                    <button class="quiz-option" data-correct="false" data-explain="Length is log2 of the byte width, like ELF's size field — 2 is the exponent, not the byte count." onclick="checkQuiz('quiz-relocs-1', this)">2 bytes</button>
                    <button class="quiz-option" data-correct="true" data-explain="2 raised to 2 = 4 bytes. Every entry in prog64.o's __text has length 2 because x86_64 displacements are 32-bit slots." onclick="checkQuiz('quiz-relocs-1', this)">4 bytes</button>
                    <button class="quiz-option" data-correct="false" data-explain="8 bytes would be length 3 — the width prog_arm64.o's __compact_unwind UNSIGNED entries use for full 64-bit pointers." onclick="checkQuiz('quiz-relocs-1', this)">8 bytes</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You check prog64.macho (the linked executable) and find __text has reloff = 0 and nreloc = 0, while prog64.o has five. Is the executable broken?</p>
                <div class="quiz" id="quiz-relocs-2">
                    <button class="quiz-option" data-correct="false" data-explain="The placeholder days are over: once ld64 has written final displacements, no classic relocation remains to apply — and a linked file is never expected to grow them." onclick="checkQuiz('quiz-relocs-2', this)">Yes — every linked file must keep its relocations for ASLR</button>
                    <button class="quiz-option" data-correct="true" data-explain="Classic relocations exist for the linker, not the loader. This MH_EXECUTE carries LC_DYLD_CHAINED_FIXUPS instead — load-time fixups in dyld's format, which is why nreloc 0 is correct." onclick="checkQuiz('quiz-relocs-2', this)">No — images use rebase/bind fixups; relocations are for objects</button>
                    <button class="quiz-option" data-correct="false" data-explain="Mach-O has no image-bias relocation list like PE's .reloc to skip when the preferred address holds — ASLR is handled by dyld fixups, not by absence of an offset." onclick="checkQuiz('quiz-relocs-2', this)">No — zero relocations mean it loaded at its preferred address</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: reloff/nreloc non-zero means "still being linked." The moment those fields go to zero, symbol binding has moved to the dyld-side tables — which the next two concepts begin to build.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Relocations reference the same nlist_64 array indexed by <a href="/courses/macho/lessons/macho-dysymtab">The Dynamic Symbol Table</a> — r_extern = 1 means "look up this symtab index," which is why the two concepts sit side by side.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-dylibs">Dynamic Libraries and Install Names</a> — extern references only resolve if dyld knows which libraries to load and what to call them at runtime: LC_LOAD_DYLIB, install names, and the ordinals bind opcodes will use.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-dysymtab">Prev: The Dynamic Symbol Table</a></span>
                <span><a href="/courses/macho/lessons/macho-dylibs">Next: Dynamic Libraries and Install Names</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
