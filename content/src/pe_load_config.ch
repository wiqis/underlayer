// PE Course — Concept 18: The Load Configuration.
// Size-versioned IMAGE_LOAD_CONFIG_DIRECTORY64: /GS cookie, SEH table, CFG, code integrity.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_load_config() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Load Configuration — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>The Load Configuration</h1>
            <div class="lesson-meta">15 min · Module 6: Relocations &amp; Hardening · Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The optional header is a fixed-size, frozen structure. It cannot grow every time the compiler invents a new hardening feature, yet the loader needs addresses that only exist at link time: where the /GS stack-overflow cookie lives, where the list of legitimate SEH handlers is, where Control Flow Guard's valid-target table sits, whether code integrity metadata is present. The Load Configuration is the overflow valve — one variable-length structure in <code>.rdata</code>, pointed to by data directory index 10, that has been extended field by field for two decades.</p>
                <p>Because it describes the mechanisms behind the flags from the previous lesson, it is also the structure most worth getting right when you are deciding whether to trust a binary. The load-bearing fields are few — a size, a cookie pointer, an optional handler table, a set of Guard pointers — but reading them at the wrong offsets yields confident nonsense, and the structure's growth is exactly why the first field exists.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Version it by length, not by a version number:</p>
                <ul>
                    <li><strong>First field: Size.</strong> The structure's own size in bytes. A reader checks Size first and only touches fields that fall inside it. An old Windows reading a new file sees a large Size and stops where its knowledge stops; a new reader seeing a small Size knows the later fields were never written.</li>
                    <li><strong>Then fixed-order fields</strong> that were only ever appended: heap policy, then the cookie, then the SEH table, then the CFG block, then code integrity, then newer tables.</li>
                </ul>
                <p>Two consumers with different appetites read it: the loader (cookie, SEH validation, CFG targets, affinity/heap flags) and tooling that inspects hardening state. The model's missing piece: a data directory gives you an address <em>and</em> a size for the whole table — trust neither blindly; the struct's own Size is what says which fields are real.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The spec's "Load Configuration Layout" table, PE32+ offsets, restricted to the fields that carry the weight:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Size</th><th scope="col">Field</th><th scope="col">What it says</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>4</td><td>Size</td><td>Total size of the structure — the version gate (see the warning below)</td></tr>
                        <tr><td>4</td><td>4</td><td>TimeDateStamp</td><td>Seconds since 1970-01-01; 0 or 0xFFFFFFFF means not meaningful</td></tr>
                        <tr><td>8 / 10</td><td>2 / 2</td><td>MajorVersion / MinorVersion</td><td>User-settable version numbers</td></tr>
                        <tr><td>12 / 16</td><td>4</td><td>GlobalFlagsClear / GlobalFlagsSet</td><td>Loader global flags to clear or set when the process starts</td></tr>
                        <tr><td>20</td><td>4</td><td>CriticalSectionDefaultTimeout</td><td>Default timeout for abandoned critical sections</td></tr>
                        <tr><td>80</td><td>8</td><td>EditList</td><td>Reserved for the system</td></tr>
                        <tr><td>88</td><td>8</td><td>SecurityCookie</td><td>VA of the /GS security cookie used by the Visual C++ GS implementation</td></tr>
                        <tr><td>96 / 104</td><td>8 / 8</td><td>SEHandlerTable / SEHandlerCount</td><td>x86 only: sorted table of RVAs of valid unique SE handlers, and its count</td></tr>
                        <tr><td>112</td><td>8</td><td>GuardCFCheckFunctionPointer</td><td>VA where the CFG check-function pointer is stored</td></tr>
                        <tr><td>120</td><td>8</td><td>GuardCFDispatchFunctionPointer</td><td>VA of the CFG dispatch pointer</td></tr>
                        <tr><td>128</td><td>8</td><td>GuardCFFunctionTable</td><td>VA of the sorted table of RVAs of every CFG-instrumented function</td></tr>
                        <tr><td>136</td><td>8</td><td>GuardCFFunctionCount</td><td>How many entries that table has</td></tr>
                        <tr><td>144</td><td>4</td><td>GuardFlags</td><td>Control-flow integrity flag bits (decoded below)</td></tr>
                        <tr><td>148</td><td>12</td><td>CodeIntegrity</td><td>Code integrity information sub-structure</td></tr>
                        <tr><td>160 / 168</td><td>8 / 8</td><td>GuardAddressTakenIatEntryTable / Count</td><td>VA and count of the address-taken IAT entry table</td></tr>
                        <tr><td>176 / 184</td><td>8 / 8</td><td>GuardLongJumpTargetTable / Count</td><td>VA and count of the longjmp target table</td></tr>
                    </tbody>
                </table>
                <p><strong>GuardFlags</strong> bits, from the spec's list: <code>0x00000100</code> CF_INSTRUMENTED (control-flow checks using system support), <code>0x00000200</code> CFW_INSTRUMENTED (control-flow <em>and</em> write integrity), <code>0x00000400</code> CF_FUNCTION_TABLE_PRESENT (valid control-flow target metadata present), <code>0x00000800</code> SECURITY_COOKIE_UNUSED, <code>0x00001000</code> PROTECT_DELAYLOAD_IAT (read-only delay-load IAT), <code>0x00002000</code> DELAYLOAD_IAT_IN_ITS_OWN_SECTION, <code>0x00004000</code> CF_EXPORT_SUPPRESSION_INFO_PRESENT, <code>0x00008000</code> CF_ENABLE_EXPORT_SUPPRESSION, <code>0x00010000</code> CF_LONGJUMP_TABLE_PRESENT, and the top nibble <code>0xF0000000</code> is a subfield holding the CFG function-table stride (right-justified with a shift of 28).</p>
                <p>Who reads which part: the loader needs SecurityCookie, the SEH table (on x86 — the spec marks SEHandlerTable/Count "x86 only", where exception dispatch consults it), and the CFG pointers; debuggers and security tools read GuardFlags/GuardCFFunctionCount to see what protection is really configured. The spec is blunt about the SEH path's failure mode: if a handler address falls inside the image and NO_SEH is clear, the handler must appear in the known-safe list, "otherwise, the operating system terminates the application" — the defense against x86 exception-handler hijacking.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> The spec's layout table labels offset 0 "Characteristics — flags that indicate attributes of the file, currently unused". Real images disagree: both samples open with <code>0x140</code>, which is exactly the structure's size (and exactly the Size value in their data directory entries), and LLVM's <code>coff_load_configuration64</code> declares the first field <code>Size</code>. Read the first dword as Size, and only then as a version gate — the spec itself says "the size is really only a version check". Never assume a fixed total length either: the structure grew from 64 bytes (the x86 SEH era) to hundreds, so a parser that seeks to a hard-coded offset on a foreign file will confidently report another field's bytes as GuardFlags.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Data directory index 10 of <code>conpty.dll</code>: RVA <code>0x13E40</code>, size <code>0x140</code>. .rdata has RVA <code>0x11000</code> at file <code>0xFC00</code>, so the structure sits at file <code>0x12A40</code>:</p>
                <div class="hex-dump">
                    <pre>00012a40: 4001 0000 0000 0000 0000 0000 0000 0000  @...............
00012a50: 0000 0000 0000 0000 0000 0000 0000 0000  ................
...
00012a90: 0000 0000 0000 0000 4080 0180 0100 0000  ........@.......
00012aa0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00012ab0: f013 0180 0100 0000 0014 0180 0100 0000  ................
00012ac0: a014 0180 0100 0000 4200 0000 0000 0000  ........B.......
00012ad0: 0075 0110 0000 0000 0000 0000 0000 0000  .u..............</pre>
                </div>
                <ol>
                    <li><code>4001 0000</code> = <code>0x140</code> (320 bytes) — Size, matching the directory's size field exactly.</li>
                    <li>Offset 88: <code>4080 0180 0100 0000</code> = <code>0x180018040</code> — SecurityCookie, a VA in <code>.data</code> (ImageBase <code>0x180000000</code> + <code>0x18040</code>). That is the /GS cookie the compiler will XOR stack frames against.</li>
                    <li>Offsets 112 and 120: <code>0x1800113F0</code> and <code>0x180011400</code> — GuardCFCheckFunctionPointer and GuardCFDispatchFunctionPointer, both in .rdata.</li>
                    <li>Offsets 128 and 136: table VA <code>0x1800114A0</code>, count <code>4200 0000 0000 0000</code> = <strong>66</strong> CFG-instrumented functions.</li>
                    <li>Offset 144: <code>0075 0110</code> = GuardFlags <code>0x10017500</code> = CF_INSTRUMENTED (0x100) + CF_FUNCTION_TABLE_PRESENT (0x400) + PROTECT_DELAYLOAD_IAT (0x1000) + DELAYLOAD_IAT_IN_ITS_OWN_SECTION (0x2000) + CF_EXPORT_SUPPRESSION_INFO_PRESENT (0x4000) + CF_LONGJUMP_TABLE_PRESENT (0x10000), plus stride subfield <code>0x10000000</code> = 1 after the shift of 28. The CodeIntegrity sub-structure at 148 is all zero — no embedded catalog metadata.</li>
                </ol>
                <p>Sample A's <code>cli-64.exe</code> carries the same Size, <code>0x140</code>, at its load config RVA <code>0x33D0</code> — modern linkers emit the full current struct whether or not every field is used.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>objdump prints the directory entry but not the struct — read it with xxd once you have the file offset:</p>
                <pre><code>$ objdump -p conpty.dll | grep "Load Configuration"
Entry a 0000000000013e40 00000140 Load Configuration Directory

$ xxd -s 0x12a40 -l 16 conpty.dll
00012a40: 4001 0000 0000 0000 0000 0000 0000 0000  @...............</code></pre>
                <p>Pull the three fields that matter in one line (offsets 0, 136, 144):</p>
                <pre><code>$ python3 -c "
import struct
d=open('conpty.dll','rb').read()
lc=0x12a40
print(hex(struct.unpack_from('&lt;I',d,lc)[0]),
      hex(struct.unpack_from('&lt;Q',d,lc+136)[0]),
      hex(struct.unpack_from('&lt;I',d,lc+144)[0]))"
0x140 0x42 0x10017500</code></pre>
                <p>What to look for: does the struct's Size match the directory size? Is SecurityCookie inside a writable section? Does GuardCFFunctionCount agree with the stride encoded in GuardFlags? In this file all three checks pass.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what does the first dword of the load configuration tell a reader, and why is it first?</p>
                <div class="quiz" id="quiz-loadcfg-1">
                    <button class="quiz-option" data-correct="false" data-explain="The spec table labels offset 0 Characteristics and calls the flags unused, but both sample images store 0x140 there — their structure size — not a flag pattern." onclick="checkQuiz('quiz-loadcfg-1', this)">A set of file-attribute flags, because flags come first in PE structures</button>
                    <button class="quiz-option" data-correct="true" data-explain="It is Size: the structure grew across Windows versions, so a reader uses it as a version gate and only trusts fields that fall inside it. The spec itself says the size is really only a version check." onclick="checkQuiz('quiz-loadcfg-1', this)">The structure's size, so the reader knows which of the ever-growing fields exist</button>
                    <button class="quiz-option" data-correct="false" data-explain="Sizes such as SizeOfImage live in the optional header, and the load config's directory entry already carries its own size. This dword is the struct's internal size field." onclick="checkQuiz('quiz-loadcfg-1', this)">The SizeOfImage of the whole PE</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You want to read <code>conpty.dll</code>'s GuardCFFunctionCount yourself. The directory says the structure is at RVA <code>0x13E40</code>; the section table says .rdata has VirtualAddress <code>0x11000</code> at PointerToRawData <code>0xFC00</code>. Which file offset do you read?</p>
                <div class="quiz" id="quiz-loadcfg-2">
                    <button class="quiz-option" data-correct="false" data-explain="0x13E40 is an RVA, not a file offset. Using RVAs as offsets reads whatever section happens to start at that file position." onclick="checkQuiz('quiz-loadcfg-2', this)">0x13E40 — the RVA, since RVAs are close to file offsets</button>
                    <button class="quiz-option" data-correct="true" data-explain="Convert with file = PointerToRawData + (RVA - VirtualAddress) = 0xFC00 + 0x13E40 - 0x11000 = 0x12A40. GuardCFFunctionCount lives 136 bytes in, at 0x12AC8, and reads 0x42 = 66." onclick="checkQuiz('quiz-loadcfg-2', this)">0x12A40 — then add the field offset 136 for the count</button>
                    <button class="quiz-option" data-correct="false" data-explain="0x14E40 is 0xFC00 plus the unadjusted RVA, which forgets to subtract the section's VirtualAddress. The delta to apply is 0x13E40 minus 0x11000 = 0x2E40, not 0x5240." onclick="checkQuiz('quiz-loadcfg-2', this)">0x14E40 — 0xFC00 plus the full RVA</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern is the same one from the RVA-conversion lesson: find the section that contains the RVA, then add the file pointer delta. The load configuration changes nothing about that rule — it only gives you a reason to care about getting it right.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Module 6 is done: the image can move, its hardening bits are declared, and its cookie and CFG tables are located. Module 7 opens the runtime tables with the structure that has nothing to do with loading and everything to do with what the user sees — icons, version strings, and dialogs, arranged in a three-level tree inside <code>.rsrc</code>.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-resources">The Resource Directory</a> — Type, Name, Language, and how Windows finds your icon.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-security-flags">Previous: Security &amp; Subsystem Flags</a></span>
                <span><a href="/courses/pe/lessons/pe-resources">Next: The Resource Directory</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
