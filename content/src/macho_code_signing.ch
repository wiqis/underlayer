// Mach-O Course — Concept 19: Code Signing.
// LC_CODE_SIGNATURE, the big-endian superblob, and the CodeDirectory's page hashes.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_code_signing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Code Signing — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>Code Signing</h1>
            <div class="lesson-meta">18 min · Module 7: Integrity &amp; Debug</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>macOS does not run code it cannot attribute. A signature binds three things to the exact bytes on disk: a hash of every page (nothing was modified), an identity (who produced it — a team, or an ad-hoc marker), and often entitlements (what it may do). PE answers the same need with Authenticode — page hashes plus a certificate chain in the attribute certificate table — and ELF distributions are typically unsigned; Mach-O puts it all in one big-endian blob at the end of __LINKEDIT.</p>
                <p>This is also the load command that changes the file's own arithmetic: our sample's signature covers every byte before it and stops exactly at its own start — so the header, load commands, and code are all inside the hash, while the signature's 23920 bytes sit outside, waiting to prove them.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of an envelope containing named documents:</p>
                <ol>
                    <li><strong>The envelope — SuperBlob</strong>: magic, total length, a count, then an index of (type, offset) pairs pointing at the documents inside. Everything big-endian — unlike the rest of the file.</li>
                    <li><strong>Document 1 — CodeDirectory</strong>: the workhorse. For every page of the signed range (default 4096 bytes), one hash; plus the identifier string, team ID, flags, hash algorithm, and the byte limit (codeLimit) that stops the hashing.</li>
                    <li><strong>Document 2 — Requirements</strong>: predicates on who may run it (designated requirement — typically "this team's certificate"). <strong>Document 3 — the CMS wrapper</strong>: a PKCS#7 signature proving the CodeDirectory came from a certificate holder. Entitlements, when present, arrive as another indexed document.</li>
                </ol>
                <p>Validation is then mechanical: re-hash pages 0..codeLimit with the declared algorithm, compare against the CodeDirectory, check the CMS over the CodeDirectory, apply requirements. Modern macOS enforces this policy at load — conceptually the same page-hash core as Authenticode, with Apple's identity model on top.</p>
                <p>The model's missing piece: the signature cannot hash itself — codeLimit is defined as the file offset where the signature begins, and everything from byte 0 up to (not including) that offset is what gets hashed.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>LC_CODE_SIGNATURE = 0x1d, a <code>linkedit_data_command</code> &#123;cmd, cmdsize 16, dataoff, datasize&#125; — the same 16-byte shape as LC_FUNCTION_STARTS, LC_DYLD_EXPORTS_TRIE, and LC_DYLD_CHAINED_FIXUPS: "a blob at a file offset, with a size".</p>
                <p>The blob's magics (Apple's cs_blobs.h family, all big-endian): SuperBlob 0xFADE0CC0, CodeDirectory 0xFADE0C02, Requirements 0xFADE0C01 (leaf 0xFADE0C00), BlobWrapper 0xFADE0B01 (the CMS carrier), entitlements 0xFADE7171. The SuperBlob header is magic u32, length u32, count u32, then count × &#123;type u32, offset u32&#125; — type first, offsets absolute within the blob. The CodeDirectory opens: magic, length, version, flags, hashOffset, identOffset, nSpecialSlots, nCodeSlots, codeLimit, then four bytes hashSize/hashType/platform/pageSize. Flags you will actually meet: CS_VALID 0x1, CS_ADHOC 0x2, CS_HARD 0x100, CS_KILL 0x200, CS_RUNTIME 0x10000, CS_LINKER_SIGNED 0x20000. Hash algorithms (hashType): 1 SHA-1, 2 SHA-256, 3 SHA-256-truncated, 4 SHA-384.</p>
                <div class="callout callout-warn">
                    <strong>Common mistakes.</strong> Byte order: this is the one structure in the file that is big-endian — superblob magic bytes on disk are <code>FA DE 0C C0</code>, reading them little-endian yields 0xC00CDEFA and nothing will parse. Second trap: index order — the SuperBlob entry is (type, offset), with the blob's own magic at the target offset serving as the ground truth for what it is; and nCodeSlots is ceil(codeLimit / page size), not the file's total page count (the signature's own pages are not in it).
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>libasyncProfiler.dylib: LC_CODE_SIGNATURE dataoff 707360, datasize 23920 — and the x86_64 slice is 731280 bytes = 707360 + 23920, so the signature runs exactly to the slice's end. First 64 bytes (FAT slice starts at file offset 0x4000, so these sit at 0xB0B20):</p>
                <div class="hex-dump">
                    <pre>000b0b20: fade 0cc0 0000 3a35 0000 0003 0000 0000  ......:5........
000b0b30: 0000 0024 0000 0002 0000 1674 0001 0000  ...$.......t....
000b0b40: 0000 1718 fade 0c02 0000 1650 0002 0500  ...........P....
000b0b50: 0001 0000 0000 00b0 0000 0060 0000 0002  ...........`....</pre>
                </div>
                <p>Decode: magic FADE0CC0, length 14901, count 3. Index: type 0 → offset 36 (CodeDirectory, magic FADE0C02, length 5712); type 2 → offset 5748 (Requirements, FADE0C01, length 164 — 36+5712=5748 ✓); type 0x10000 → offset 5912 (the CMS BlobWrapper, FADE0B01, length 8989 — 5748+164=5912 ✓; 5912+8989=14901 ✓). The remaining 23920 − 14901 = 9019 bytes of the declared datasize are zero padding out to the slice end. No entitlements document — three slots, none of type 5.</p>
                <p>Inside the CodeDirectory: version 0x20500 (2.5), flags 0x00010000 — CS_RUNTIME; hashOffset 176, identOffset 96 → identifier <code>"sign"</code>; teamOffset field (byte 48) = 101 → team ID <code>"2ZEFAR8TH3"</code> (both strings as observed in this sample); nSpecialSlots 2, nCodeSlots 173, codeLimit 707360 — which equals dataoff itself: every byte from 0 to 707359 (header, load commands, all segments) is inside the hashed range, and 173 = ceil(707360 / 4096). Then hashSize 32, hashType 2 (SHA-256), platform 0, pageSize 12 (2^12 = 4096). The CodeDirectory's own length checks out: 176 + 173 × 32 = 5712.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <pre><code>$ xxd -s $((0x4000 + 707360)) -l 64 libasyncProfiler.dylib
000b0b20: fade 0cc0 0000 3a35 0000 0003 0000 0000  ......:5........

$ python3 -c "import struct; b=open('libasyncProfiler.dylib','rb').read(); s=b[0x4000+707360:]; print([hex(x) for x in struct.unpack_from('&gt;3I', s)])"
['0xfade0cc0', '0x3a35', '0x3']</code></pre>
                <p>What to look for: '&gt;3I' — big-endian unpack is mandatory; the three values are magic, length 0x3a35 = 14901, count 3. Contrast with the file's first bytes <code>CF FA ED FE</code> (little-endian): one file, two byte orders, and the switch happens exactly at LC_CODE_SIGNATURE's dataoff. Then hunt the index: 12 + 8 × k lands on each (type, offset) pair; follow an offset and confirm the magic you find there.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: the first four bytes of a Mach-O signature blob are FA DE 0C C0. What 32-bit magic is that, and why did you have to think about it?</p>
                <div class="quiz" id="quiz-signing-1">
                    <button class="quiz-option" data-correct="false" data-explain="Little-endian reading gives 0xC00CDEFA, which matches no CSMAGIC — that is the classic trap of applying the file's dominant byte order to this blob." onclick="checkQuiz('quiz-signing-1', this)">0xC00CDEFA — like the header, read little-endian</button>
                    <button class="quiz-option" data-correct="true" data-explain="Big-endian: FADE0CC0 is CSMAGIC_EMBEDDED_SIGNATURE, the SuperBlob envelope. The signature subsystem is the one part of a Mach-O file that flips byte order — loader.h's little-endian rules do not apply inside it." onclick="checkQuiz('quiz-signing-1', this)">0xFADE0CC0 — the SuperBlob magic, big-endian</button>
                    <button class="quiz-option" data-correct="false" data-explain="0xCAFEBABE is FAT_MAGIC (bytes CA FE BA BE), which opens universal containers, not signatures — and it is also big-endian, which is the only part of this answer that is right." onclick="checkQuiz('quiz-signing-1', this)">0xCAFEBABE — it looks like a FAT header</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A CodeDirectory reports codeLimit 707360, hashType 2, pageSize 12, nCodeSlots 173. Which statement is true?</p>
                <div class="quiz" id="quiz-signing-2">
                    <button class="quiz-option" data-correct="false" data-explain="0x10000 is CS_RUNTIME (sandboxed-runtime policy); CS_LINKER_SIGNED is 0x20000 and CS_ADHOC is 0x2 — the flag value, not the hash math, decides among those." onclick="checkQuiz('quiz-signing-2', this)">The image is linker-signed (flag would be 0x20000)</button>
                    <button class="quiz-option" data-correct="true" data-explain="173 slots × 4096-byte pages (2^12) covers 708608 bytes, first covering codeLimit 707360 — SHA-256 (hashType 2), 32 bytes each. Hashed range is bytes 0..707359: header, load commands, segments — up to but not including the signature at dataoff 707360." onclick="checkQuiz('quiz-signing-2', this)">Each page's SHA-256 (32 bytes) is stored; hashing stops before the signature itself</button>
                    <button class="quiz-option" data-correct="false" data-explain="173 is less than ceil(731280/4096) = 174: nCodeSlots counts only the signed range (codeLimit), never the signature's own padding pages — those bytes cannot hash themselves." onclick="checkQuiz('quiz-signing-2', this)">The whole slice (731280 bytes) is hashed, signature included</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: codeLimit is the fence — nCodeSlots = ceil(codeLimit / 2^pageSize), the algorithm is whatever hashType says, and the fence always lands exactly where LC_CODE_SIGNATURE.dataoff begins.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The superblob proves the bytes and the team; the UUID from the previous lesson proves which link produced them. Neither helps you <em>read</em> the program — for that you need debug information matched to that same identity.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-debug-info">Debug Info</a> — dSYM companion bundles, why full DWARF never ships inside the binary, and how LC_UUID is the join key between a crash and its symbols.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-build-version">Prev: Build Versions and UUID</a></span>
                <span><a href="/courses/macho/lessons/macho-debug-info">Next: Debug Info</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
