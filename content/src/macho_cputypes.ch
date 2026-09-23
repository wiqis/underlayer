// Mach-O Course — Concept 5: CPU Types and Subtypes.
// CPU_TYPE_X86_64, CPU_TYPE_ARM64, and capability bits.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_cputypes() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("CPU Types and Subtypes — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>CPU Types and Subtypes</h1>
            <div class="lesson-meta">12 min · Module 2: Headers</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Try to launch an Intel-only binary on Apple Silicon (or the reverse) and macOS refuses with "Bad CPU type in executable." That verdict comes from two 4-byte header fields: <code>cputype</code> and <code>cpusubtype</code>. They are also how <code>lipo</code>, the FAT parser, and dyld's slice picker choose which code in a universal file is allowed to run on the machine in front of them.</p>
                <p>Misread these values and you will "run" x86 code on arm64 — or decide a slice is compatible when its capability bits say otherwise. The encoding is simple once you see that both fields pack a base value plus flags.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two questions, two fields:</p>
                <ol>
                    <li><strong>cputype — which architecture family and ABI width?</strong> A small base number (7 = x86, 12 = ARM) with capability bits ORed into the high byte: 0x01000000 means "64-bit ABI." So x86_64 is not a new number — it is 7 with the ABI64 bit: 0x01000007.</li>
                    <li><strong>cpusubtype — which variant within the family?</strong> A low value selecting the instruction-level baseline (3 = any x86_64, 0 = any arm64, 2 = arm64e) plus its own capability bits in the top byte, masked by CPU_SUBTYPE_MASK = 0xFF000000. CPU_SUBTYPE_LIB64 = 0x80000000 is the one you will see on x86_64 executables.</li>
                </ol>
                <p>The model's missing piece: the loader masks off the capability byte before choosing a slice — "ALL" subtypes mean "runs on any hardware of this type," while capability bits annotate how the binary was built (64-bit libraries, pointer authentication).</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Apple's <code>&lt;mach/machine.h&gt;</code> defines the constants (cputype is <code>integer_t</code>, 4 bytes, stored little-endian in thin files):</p>
                <table>
                    <thead>
                        <tr><th scope="col">Constant</th><th scope="col">Value</th><th scope="col">How it is formed</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>CPU_TYPE_X86</td><td>7</td><td>base family number</td></tr>
                        <tr><td>CPU_TYPE_X86_64</td><td>0x01000007 (16777223)</td><td>CPU_TYPE_X86 | CPU_ARCH_ABI64 (0x01000000)</td></tr>
                        <tr><td>CPU_TYPE_ARM</td><td>12</td><td>base family number</td></tr>
                        <tr><td>CPU_TYPE_ARM64</td><td>0x0100000C (16777228)</td><td>CPU_TYPE_ARM | CPU_ARCH_ABI64</td></tr>
                        <tr><td>CPU_SUBTYPE_X86_64_ALL</td><td>3</td><td>runs on any x86_64 hardware</td></tr>
                        <tr><td>CPU_SUBTYPE_ARM64_ALL</td><td>0</td><td>runs on any arm64 hardware</td></tr>
                        <tr><td>CPU_SUBTYPE_ARM64E</td><td>2</td><td>arm64e — pointer-authenticated ABI</td></tr>
                        <tr><td>CPU_SUBTYPE_LIB64</td><td>0x80000000</td><td>capability bit ORed into the subtype's high byte</td></tr>
                    </tbody>
                </table>
                <p>In real headers: <code>prog64.macho</code> stores cpusubtype bytes <code>03 00 00 80</code> = 0x80000003 — subtype 3 (X86_64_ALL) with the LIB64 capability bit, which <code>otool</code> helpfully splits into subtype <code>ALL</code> and caps <code>0x80</code>. <code>prog_arm64.macho</code> stores subtype 0 (ARM64_ALL), caps 0x00. In the FAT tables, universal.macho's x86_64 arch carries 0x80000003 while its arm64 arch carries plain 0.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Do not treat cpusubtype as a strict equality check. CPU_SUBTYPE_X86_64_ALL (3) means "any x86_64 CPU," so the loader compares subtypes with masking rules from machine.h — capability bits live above CPU_SUBTYPE_MASK and the low bits express a baseline, not a SKU.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The same twelve bytes from our two thin executables — only cputype and subtype differ:</p>
                <div class="hex-dump">
                    <pre>prog64.macho (x86_64):
00000000: cffa edfe 0700 0001 0300 0080 0200 0000  ........

prog_arm64.macho (arm64):
00000000: cffa edfe 0c00 0001 0000 0000 0200 0000  ........</pre>
                </div>
                <ol>
                    <li>Both: <code>CF FA ED FE</code> — same magic, same 64-bit little-endian regime.</li>
                    <li>Bytes 4–7: <code>07 00 00 01</code> = 0x01000007 (x86_64) vs <code>0C 00 00 01</code> = 0x0100000C (arm64). Same base-plus-ABI64 construction, different base (7 vs 12).</li>
                    <li>Bytes 8–11: <code>03 00 00 80</code> = 0x80000003 (X86_64_ALL | LIB64) vs <code>00 00 00 00</code> = 0 (ARM64_ALL).</li>
                    <li>Byte 12 onward: filetype 2, ncmds 14 vs 15 — headers otherwise follow the same shape.</li>
                </ol>
                <p>These are exactly the two slices inside <code>universal.macho</code> — the FAT arch entries store the same pairs (0x01000007/0x80000003 and 0x0100000C/0) in big-endian.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Compare architectures across every sample at once:</p>
                <pre><code>$ for f in *.macho *.o; do echo "== $f"; xxd -l 12 "$f" | head -1; done
== prog64.o
00000000: cffa edfe 0700 0001 0300 0000  ....
== prog_arm64.o
00000000: cffa edfe 0c00 0001 0000 0000  ....

$ llvm-readobj --file-headers prog_arm64.macho | grep Cpu
  CpuType: Arm64 (0x100000C)
  CpuSubType: CPU_SUBTYPE_ARM64_ALL (0x0)</code></pre>
                <p>What to look for: bytes 4–7 are the whole architecture story — <code>07 00 00 01</code> versus <code>0C 00 00 01</code>, little-endian, identical position in every 64-bit Mach-O ever made. Bytes 8–11 then refine the variant and carry the capability byte.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: how is CPU_TYPE_ARM64 (0x0100000C) constructed, and what does the high byte of a cpusubtype like 0x80000003 carry?</p>
                <div class="quiz" id="quiz-cpu-1">
                    <button class="quiz-option" data-correct="false" data-explain="0x0100000C is not a typo and not two separate fields — cputype is a single 4-byte value. CPU_TYPE_ARM alone is just 12 (0x0C)." onclick="checkQuiz('quiz-cpu-1', this)">It is two packed 16-bit fields: family 0x0100 and model 0x000C</button>
                    <button class="quiz-option" data-correct="true" data-explain="machine.h defines CPU_TYPE_ARM64 as (CPU_TYPE_ARM | CPU_ARCH_ABI64): base 12 (0x0C) ORed with the 0x01000000 ABI64 bit. In a subtype like 0x80000003, the top byte is capability flags — CPU_SUBTYPE_LIB64 = 0x80000000 — sitting above the CPU_SUBTYPE_MASK boundary, while the low byte 3 is the real subtype." onclick="checkQuiz('quiz-cpu-1', this)">Base 12 ORed with ABI64 0x01000000; high byte = capability bits (LIB64)</button>
                    <button class="quiz-option" data-correct="false" data-explain="ARM64_ALL is the value 0, not 0x0100000C — that number is the cputype. And 0x80000000 is CPU_SUBTYPE_LIB64, a capability bit, not part of the cputype encoding." onclick="checkQuiz('quiz-cpu-1', this)">It equals CPU_SUBTYPE_ARM64_ALL shifted left; high byte stores cputype</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A FAT header entry reads cputype 0x01000007, cpusubtype 0x80000003. Which slice is this, and how would a tool display the subtype?</p>
                <div class="quiz" id="quiz-cpu-2">
                    <button class="quiz-option" data-correct="false" data-explain="0x01000007 with base 7 is x86, not ARM — ARM64 would be 0x0100000C. Also ARM64_ALL is subtype 0, not 3." onclick="checkQuiz('quiz-cpu-2', this)">arm64 slice, subtype ARM64_ALL</button>
                    <button class="quiz-option" data-correct="true" data-explain="0x01000007 = CPU_TYPE_X86_64. Subtype 0x80000003 splits at CPU_SUBTYPE_MASK: low part 3 = CPU_SUBTYPE_X86_64_ALL, high byte 0x80 = CPU_SUBTYPE_LIB64 capability — exactly how otool prints subtype ALL with caps 0x80 for prog64.macho." onclick="checkQuiz('quiz-cpu-2', this)">x86_64 slice; displayed as subtype 3 (ALL) with capability bit LIB64</button>
                    <button class="quiz-option" data-correct="false" data-explain="Subtype 8 is CPU_SUBTYPE_X86_64_H (the Haswell subset) — but this value is 0x80000003, whose low byte is 3, not 8. The 0x80000000 top byte is a capability flag, not part of the variant number." onclick="checkQuiz('quiz-cpu-2', this)">Haswell-only x86_64 slice (subtype H = 8)</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: cputype = family | ABI-width bits; cpusubtype = variant | capability bits in the top byte. Mask before you compare.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>cputype and cpusubtype are not only header decoration — they are the selection keys of a container format. When one file must carry both an x86_64 slice (0x01000007) and an arm64 slice (0x0100000C), those pairs are written into a big-endian table up front, and the loader picks by them.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-universal">Universal (FAT) Binaries</a> — fat_header, fat_arch, slice offsets and alignment, walked through the real <code>universal.macho</code> and <code>libasyncProfiler.dylib</code>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-header">Previous: The mach_header_64 Field by Field</a></span>
                <span><a href="/courses/macho/lessons/macho-universal">Next: Universal (FAT) Binaries</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
