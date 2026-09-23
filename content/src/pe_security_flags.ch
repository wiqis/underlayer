// PE Course — Concept 17: Security & Subsystem Flags.
// COFF Characteristics, Subsystem, DllCharacteristics, stack/heap sizes, Authenticode.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_security_flags() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Security & Subsystem Flags — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>Security &amp; Subsystem Flags</h1>
            <div class="lesson-meta">15 min · Module 6: Relocations &amp; Hardening · Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Before mapping a single section, Windows reads a few tiny fields and decides: is this a console tool or a GUI app, is a 1 MiB stack enough, may this image move for ASLR, may its pages be non-executable, does it claim Control Flow Guard, is there a signature at the end of the file? None of these fields hold code or data — they are the binary's self-declared posture, and both the OS and the security ecosystem treat them as promises.</p>
                <p>This is the first lesson in the course where a wrong value has consequences beyond "your program crashes". Misreading <code>DYNAMIC_BASE</code> tells you ASLR is on when it is not; misreading the certificate directory's first field as an RVA sends your parser into the wrong part of the file entirely. And because these are plain bitfields, they are also the fastest thing in the whole format to verify by hand — which is exactly what incident responders and malware analysts do first.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Four independent knobs, in four places:</p>
                <ul>
                    <li><strong>COFF Characteristics</strong> (COFF header, offset 18) — what kind of file is this: a runnable image, a DLL, relocations stripped, 32-bit machine.</li>
                    <li><strong>Subsystem</strong> (optional header, offset 68) — which environment must exist to run it: native driver, GUI, or console.</li>
                    <li><strong>DllCharacteristics</strong> (optional header, offset 70) — the hardening switches: ASLR, high-entropy VA, NX, CFG, and friends. The name says "DLL" but every image has the field.</li>
                    <li><strong>Certificate table</strong> (data directory index 4) — the Authenticode signature, which unlike every other directory is not mapped into memory at all.</li>
                </ul>
                <p>Sitting next to Subsystem are four size fields the loader also honors: stack reserve, stack commit, heap reserve, heap commit. The model's missing piece: reserve versus commit. Reserve is address space set aside; only the commit size is backed by physical memory up front, and the rest is granted one page at a time as it is touched.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>COFF Characteristics bits, from the spec's Characteristics table (the subset that matters for loading and hardening):</p>
                <table>
                    <thead>
                        <tr><th scope="col">Value</th><th scope="col">Constant</th><th scope="col">Meaning</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x0001</td><td>IMAGE_FILE_RELOCS_STRIPPED</td><td>No base relocations; must load at ImageBase or the loader reports an error</td></tr>
                        <tr><td>0x0002</td><td>IMAGE_FILE_EXECUTABLE_IMAGE</td><td>The image is valid and can run; if clear, it is a linker error</td></tr>
                        <tr><td>0x0004</td><td>IMAGE_FILE_LINE_NUMS_STRIPPED</td><td>COFF line numbers removed (deprecated, should be zero)</td></tr>
                        <tr><td>0x0008</td><td>IMAGE_FILE_LOCAL_SYMS_STRIPPED</td><td>Local COFF symbols removed (deprecated, should be zero)</td></tr>
                        <tr><td>0x0020</td><td>IMAGE_FILE_LARGE_ADDRESS_AWARE</td><td>Application can handle addresses above 2 GB</td></tr>
                        <tr><td>0x0100</td><td>IMAGE_FILE_32BIT_MACHINE</td><td>Machine is a 32-bit-word architecture</td></tr>
                        <tr><td>0x0200</td><td>IMAGE_FILE_DEBUG_STRIPPED</td><td>Debugging information removed</td></tr>
                        <tr><td>0x1000</td><td>IMAGE_FILE_SYSTEM</td><td>System file, not a user program</td></tr>
                        <tr><td>0x2000</td><td>IMAGE_FILE_DLL</td><td>The file is a DLL</td></tr>
                    </tbody>
                </table>
                <p>Subsystem values (spec's "Windows Subsystem" table): <code>1</code> NATIVE (drivers and native processes), <code>2</code> WINDOWS_GUI, <code>3</code> WINDOWS_CUI (character/console). More exist for EFI, Xbox, and boot applications.</p>
                <p>DllCharacteristics bits (spec's "DLL Characteristics" table) — bits 0x0001-0x0008 are reserved and must be zero:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Value</th><th scope="col">Constant</th><th scope="col">Meaning</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x0020</td><td>HIGH_ENTROPY_VA</td><td>Can handle a high-entropy 64-bit address space</td></tr>
                        <tr><td>0x0040</td><td>DYNAMIC_BASE</td><td>Can be relocated at load time (needs a .reloc table to be true)</td></tr>
                        <tr><td>0x0080</td><td>FORCE_INTEGRITY</td><td>Code integrity checks are enforced</td></tr>
                        <tr><td>0x0100</td><td>NX_COMPAT</td><td>Image is NX (DEP) compatible</td></tr>
                        <tr><td>0x0200</td><td>NO_ISOLATION</td><td>Isolation aware, but do not isolate</td></tr>
                        <tr><td>0x0400</td><td>NO_SEH</td><td>No structured exception handling; no SEH handler may be called in this image</td></tr>
                        <tr><td>0x0800</td><td>NO_BIND</td><td>Do not bind the image</td></tr>
                        <tr><td>0x1000</td><td>APPCONTAINER</td><td>Must execute in an AppContainer</td></tr>
                        <tr><td>0x2000</td><td>WDM_DRIVER</td><td>A WDM driver</td></tr>
                        <tr><td>0x4000</td><td>GUARD_CF</td><td>Supports Control Flow Guard</td></tr>
                        <tr><td>0x8000</td><td>TERMINAL_SERVER_AWARE</td><td>Terminal Server aware</td></tr>
                    </tbody>
                </table>
                <p>Decoded real values: <code>cli-64.exe</code> has DllCharacteristics <code>0x8160</code> = HIGH_ENTROPY_VA | DYNAMIC_BASE | NX_COMPAT | TERMINAL_SERVER_AWARE; <code>conpty.dll</code> has <code>0x4160</code> = the same first three plus GUARD_CF instead of the terminal-server bit. Characteristics are <code>0x0022</code> (exe) and <code>0x2022</code> (DLL | executable | large-address-aware). Subsystems are 3 (console) and 2 (GUI). In PE32+, the four size fields sit at optional-header offsets 72 (SizeOfStackReserve), 80 (SizeOfStackCommit), 88 (SizeOfHeapReserve), 96 (SizeOfHeapCommit) — all four 8-byte fields, all four reading <code>0x100000</code> reserve and <code>0x1000</code> commit in both samples. The spec notes CheckSum (offset 64) is validated at load time for drivers, boot-time DLLs, and DLLs loaded into critical Windows processes.</p>
                <p>The certificate side: data directory index 4 stores <strong>file offsets</strong>, not RVAs — the spec is explicit that the certificate table "is not loaded into memory as part of the image", so its VirtualAddress field is a file pointer. Each entry is a WIN_CERTIFICATE: 4-byte dwLength, 2-byte wRevision (<code>0x0100</code> v1, <code>0x0200</code> v2/current), 2-byte wCertificateType (<code>0x0001</code> X509 unsupported, <code>0x0002</code> PKCS#7 SignedData = Authenticode), then the certificate bytes, padded so each entry ends on an 8-byte boundary. The Authenticode image hash deliberately excludes the CheckSum field and the Certificate Table directory entry, because adding a signature changes both.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Reading <code>GUARD_CF</code> here and concluding CFG protection is configured. This bit only <em>advertises</em> support — the actual CFG machinery (the check/dispatch pointers, the valid-target table, GuardFlags) lives in the Load Configuration structure, the next lesson. Also: CheckSum is not a signature. A non-zero checksum proves nothing about who wrote the file; only directory index 4 does that, and only if the signature chain itself verifies.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p><code>conpty.dll</code> is signed. Its Security directory entry reads <code>VirtualAddress = 0x18600</code>, <code>Size = 0x3D20</code> — and because this directory holds file offsets, the WIN_CERTIFICATE is exactly there, at the very end of the file (<code>0x18600 + 0x3D20 = 0x1C320</code> = the file's 115488 bytes):</p>
                <div class="hex-dump">
                    <pre>00018600: 203d 0000 0002 0200 3082 3d10 0609 2a86   =......0.=...*.
00018610: 4886 f70d 0107 02a0 823d 0130 823c fd02  H........=.0.&lt;..</pre>
                </div>
                <ol>
                    <li><code>203d 0000</code> = dwLength <code>0x00003D20</code> — the entry's full length, equal to the directory Size because this file has one certificate.</li>
                    <li><code>0002</code> = wRevision <code>0x0200</code> — WIN_CERT_REVISION_2_0, the current structure version.</li>
                    <li><code>0200</code> = wCertificateType <code>0x0002</code> — WIN_CERT_TYPE_PKCS_SIGNED_DATA.</li>
                    <li>Then <code>30 82 3d 10</code>: a DER SEQUENCE of length 0x3D10, followed by <code>06 09 2a 86 48 86 f7 0d 01 07 02</code> — OID 1.2.840.113549.1.7.2, the PKCS#7 <code>signedData</code> content type. That is a genuine Authenticode blob, not padding.</li>
                </ol>
                <p>Decode the flag fields of any PE in one pass — this is the same script that produced <code>0x4160 HIGH_ENTROPY_VA | DYNAMIC_BASE | NX_COMPAT | GUARD_CF</code> above:</p>
                <div class="hex-dump">
                    <pre>e_lfanew=0x100  COFF Characteristics @0x116 = 0x0022
Subsystem        @0x15C = 3   (WINDOWS_CUI)
DllCharacteristics @0x15E = 0x8160
  0x0020 | 0x0040 | 0x0100 | 0x8000</pre>
                </div>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>objdump already knows every bit name in the spec tables:</p>
                <pre><code>$ objdump -x cli-64.exe | grep -A6 "Characteristics"
Characteristics 0x22
	executable
	large address aware
...
Subsystem		00000003	(Windows CUI)
DllCharacteristics	00008160
					HIGH_ENTROPY_VA
					DYNAMIC_BASE
					NX_COMPAT
					TERMINAL_SERVICE_AWARE</code></pre>
                <p>Decode DllCharacteristics yourself, bit by bit:</p>
                <pre><code>$ python3 -c "
import struct
d=open('conpty.dll','rb').read()
e=struct.unpack_from('&lt;I',d,0x3c)[0]
dll=struct.unpack_from('&lt;H',d,e+24+70)[0]
t=[(0x20,'HIGH_ENTROPY_VA'),(0x40,'DYNAMIC_BASE'),(0x80,'FORCE_INTEGRITY'),
   (0x100,'NX_COMPAT'),(0x400,'NO_SEH'),(0x4000,'GUARD_CF'),(0x8000,'TSAWARE')]
print(hex(dll),[n for b,n in t if dll&amp;b])"
0x4160 ['HIGH_ENTROPY_VA', 'DYNAMIC_BASE', 'NX_COMPAT', 'GUARD_CF']</code></pre>
                <p>Then confirm the signature offset: <code>objdump -p conpty.dll | grep Security</code> prints <code>Entry 4 0000000000018600 00003d20 Security Directory</code> — and remember, unlike every other entry around it, that 0x18600 is a file offset.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: decode <code>cli-64.exe</code>'s DllCharacteristics value <code>0x8160</code>.</p>
                <div class="quiz" id="quiz-flags-1">
                    <button class="quiz-option" data-correct="false" data-explain="FORCE_INTEGRITY is 0x0080, which is not set in 0x8160, and Control Flow Guard is 0x4000, also not set. Sample C, not sample A, carries GUARD_CF." onclick="checkQuiz('quiz-flags-1', this)">FORCE_INTEGRITY plus GUARD_CF</button>
                    <button class="quiz-option" data-correct="true" data-explain="0x0020 HIGH_ENTROPY_VA + 0x0040 DYNAMIC_BASE + 0x0100 NX_COMPAT + 0x8000 TERMINAL_SERVER_AWARE = 0x8160, the same four bits objdump lists for this file." onclick="checkQuiz('quiz-flags-1', this)">HIGH_ENTROPY_VA, DYNAMIC_BASE, NX_COMPAT, TERMINAL_SERVER_AWARE</button>
                    <button class="quiz-option" data-correct="false" data-explain="NO_SEH is 0x0400 and APPCONTAINER is 0x1000; neither bit appears in 0x8160. Missing a bit here would mispredict how the loader treats exceptions." onclick="checkQuiz('quiz-flags-1', this)">NO_SEH, APPCONTAINER, and DYNAMIC_BASE</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p><code>conpty.dll</code>'s Security directory entry reads <code>VirtualAddress = 0x18600</code>, <code>Size = 0x3D20</code>. What exactly is 0x18600?</p>
                <div class="quiz" id="quiz-flags-2">
                    <button class="quiz-option" data-correct="false" data-explain="Certificates are never mapped into memory — the spec says the certificate table is not loaded as part of the image, so this value cannot be an RVA." onclick="checkQuiz('quiz-flags-2', this)">An RVA of the signature once the DLL is loaded</button>
                    <button class="quiz-option" data-correct="true" data-explain="For data directory index 4 the VirtualAddress field is a file pointer, not an RVA. At file 0x18600 sits a WIN_CERTIFICATE with dwLength 0x3D20, wRevision 0x0200, wCertificateType 0x0002 — and 0x18600 plus 0x3D20 equals the file size." onclick="checkQuiz('quiz-flags-2', this)">A file offset to the WIN_CERTIFICATE at the end of the file</button>
                    <button class="quiz-option" data-correct="false" data-explain="The checksum is a separate 4-byte optional-header field at offset 64, not a directory entry, and it is much smaller than 0x3D20." onclick="checkQuiz('quiz-flags-2', this)">The file offset of the CheckSum field</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: every data directory is an RVA/size pair except index 4. That single exception is why signature parsers that treat all sixteen directories alike walk straight off the end of the mapped image.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>These flags are promises; the Load Configuration is where the hard parts of those promises are actually implemented — the /GS security cookie, the whitelist of valid SEH handlers, and the Control Flow Guard tables that the GUARD_CF bit only announces. It is also the first structure in the course whose size, not its position, tells you which version you are reading.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-load-config">The Load Configuration</a> — cookies, handler lists, and CFG targets.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-base-relocations">Previous: Base Relocations</a></span>
                <span><a href="/courses/pe/lessons/pe-load-config">Next: The Load Configuration</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
