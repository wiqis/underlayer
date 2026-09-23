// Mach-O Course — Concept 18: Build Versions and UUID.
// LC_BUILD_VERSION's platform/minos/sdk/tools and LC_UUID's 16-byte identity.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_build_version() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Build Versions and UUID — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>Build Versions and UUID</h1>
            <div class="lesson-meta">12 min · Module 6: Modern Linking &amp; Entry</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The same bytes ship to machines running different OS releases, get debugged months later, and may be rejected before they run at all. Two small load commands answer the three questions that follow: <em>where is this allowed to run</em> (platform + minimum OS), <em>what was it built against</em> (SDK, plus the tool versions that produced it), and <em>which exact build is this</em> (UUID). dyld consults the first to refuse old systems cleanly; crash reporters and <code>dsymutil</code> use the UUID to join a crashed binary to its debug file — without a matching UUID there are no symbols, only addresses.</p>
                <p>If you have ever seen "built with SDK … requires macOS …" in an error dialog, or a crash log keyed by a 36-character hex string, these two commands are the source.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of LC_BUILD_VERSION as a passport stamp and LC_UUID as a fingerprint:</p>
                <ol>
                    <li><strong>platform</strong> — which OS family (1 = macOS, 2 = iOS, … through 10 = DriverKit). One number disambiguates binaries that otherwise look identical.</li>
                    <li><strong>minos</strong> — the floor: dyld refuses the image below this OS version. <strong>sdk</strong> — the SDK it was compiled against: tells tools what APIs were available, not what runs.</li>
                    <li><strong>tools</strong> — a list of (tool, version) pairs: which clang/ld/swift produced the file.</li>
                </ol>
                <p>LC_UUID is simpler still: cmd, cmdsize, and 16 raw bytes. It is not derived from content (rebuild with identical sources and it changes) — it is minted per link, per architecture slice.</p>
                <p>The model's missing piece: minos and sdk answer different questions. A binary can carry sdk 13.3 and minos 10.15 — built today against the 13.3 SDK, still runnable on four-year-old systems — and only minos gates execution.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><code>build_version_command</code> = &#123;cmd 0x32, cmdsize, platform, minos, sdk, ntools&#125; followed by ntools × build_tool_version &#123;tool, version&#125; — so cmdsize = 32 + 8 × ntools for the usual ntools = 1. Versions pack three parts into one u32, loader.h's comment: "X.Y.Z is encoded in nibbles xxxx.yy.zz" — major shift 16, minor shift 8, patch in the low byte (13.3 → 0x000D0300). Tool values from the same header: TOOL_CLANG 1, TOOL_SWIFT 2, TOOL_LD 3. Platforms: PLATFORM_MACOS 1, IOS 2, TVOS 3, WATCHOS 4, BRIDGEOS 5, MACCATALYST 6, then simulators 7–9, DRIVERKIT 10.</p>
                <p>The older form, LC_VERSION_MIN_MACOSX (0x24), is a 16-byte version_min_command &#123;version, sdk&#125; with no platform field — one command per OS family (LC_VERSION_MIN_IPHONEOS etc.). LC_BUILD_VERSION (0x32) replaced it when one binary could target platforms the old commands could not name. LC_UUID is 0x1b, cmdsize 24, always exactly one per slice.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Reading sdk as the runtime requirement. sdk records the toolchain's headers; minos records the floor dyld enforces. Second trap: expecting one UUID for a FAT file — every slice links separately, so x86_64 and arm64 of the same program carry different UUIDs (our samples do: see below), and the debugger must match the crashed architecture's UUID, not the file's first bytes.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The dylib sample — classic era, macOS-only, built by the linker itself:</p>
                <pre><code>     cmd LC_UUID
 cmdsize 24
    uuid DA4AFC52-D48E-39AB-B574-FE3B9CC5232F

       cmd LC_BUILD_VERSION
   cmdsize 32
  platform 1
       sdk 13.3
     minos 10.15
    ntools 1
      tool 3
   version 857.1</code></pre>
                <p>Decode: platform 1 = macOS; sdk 13.3 = 0x000D0300; minos 10.15 = 0x000A0F00; tool 3 = TOOL_LD — this stamp says ld 857.1 built the file against the macOS 13.3 SDK with a 10.15 floor. Now the executable sample — modern era, both slices from the same link:</p>
                <pre><code>    uuid 4C4C44C9-5555-3144-A19F-1D5685FC622F   (x86_64)
    uuid 4C4C44B1-5555-3144-A130-3397BCE0A53C   (arm64)
  platform 1   sdk 13.0   minos 13.0   ntools 1
      tool 4   version 22.1.2</code></pre>
                <p>sdk and minos both 13.0 — a single-platform, single-floor build. tool 4 is where honesty matters: this course's loader.h revision names only tools 1–3, so the value 4 (version 22.1.2) is recorded here as observed, without a name we can cite from the header. And the two UUIDs differ despite identical sources — per-slice identity, exactly as the model says.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <pre><code>$ /usr/lib/llvm-21/bin/llvm-otool -arch x86_64 -l prog64.macho | grep -A8 LC_BUILD_VERSION

$ python3 -c "v=0x000D0300; print((v&gt;&gt;16)&amp;0xffff, (v&gt;&gt;8)&amp;0xff, v&amp;0xff)"
13 3 0

$ /usr/lib/llvm-21/bin/llvm-otool -arch x86_64 -l prog64.macho | grep -A2 LC_UUID</code></pre>
                <p>What to look for: the python unpack is the inverse of loader.h's xxxx.yy.zz rule — three numbers, one u32; otool prints sdk/minos already decoded. Then compare UUIDs across arch flags on a FAT binary: two slices, two stamps, and a crash log only makes sense once you know which one it cites.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a load command's minos field reads 0x000D0300. What version is that?</p>
                <div class="quiz" id="quiz-buildver-1">
                    <button class="quiz-option" data-correct="false" data-explain="0x000A0F00 would be 10.15 (0x0A=10, 0x0F=15). Here 0x0D=13 and 0x03=3 — the 10 comes from reading the middle byte as decimal 10 instead of hex 0x03's neighbor." onclick="checkQuiz('quiz-buildver-1', this)">10.15.0</button>
                    <button class="quiz-option" data-correct="true" data-explain="xxxx.yy.zz: 0x000D = 13 (major, shift 16), 0x03 = 3 (minor, shift 8), 0x00 = 0 (patch) — 13.3.0, printed as 13.3, exactly what otool shows for our dylib's sdk." onclick="checkQuiz('quiz-buildver-1', this)">13.3.0</button>
                    <button class="quiz-option" data-correct="false" data-explain="Swapping minor and patch would require the low byte to be 3 and the middle 0 — the packing is major:minor:patch, not major:patch:minor." onclick="checkQuiz('quiz-buildver-1', this)">13.0.3</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A binary reports platform 1, sdk 13.3, minos 10.15. A user runs it on macOS 11. What decides whether dyld loads it?</p>
                <div class="quiz" id="quiz-buildver-2">
                    <button class="quiz-option" data-correct="false" data-explain="sdk 13.3 is provenance — which headers it compiled against — not a runtime requirement. Building with a new SDK while supporting old systems is the normal case." onclick="checkQuiz('quiz-buildver-2', this)">sdk 13.3 — the binary needs the 13.3 SDK installed</button>
                    <button class="quiz-option" data-correct="true" data-explain="minos 10.15 is the floor: 11 is above it, so dyld loads the image. platform 1 (macOS) matches the host — that is the only other gate this command enforces." onclick="checkQuiz('quiz-buildver-2', this)">minos 10.15 — macOS 11 clears the floor</button>
                    <button class="quiz-option" data-correct="false" data-explain="The UUID is identity for debug matching — dsymutil and crash reporters read it; dyld's load decision never consults it." onclick="checkQuiz('quiz-buildver-2', this)">The UUID — it must match the system's registered build</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: platform must match, minos must be satisfied, sdk is provenance — and the UUID rides along untouched until a debugger needs it.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Knowing <em>which build</em> this is invites the next question: is it also <em>which bytes the developer signed</em>? The UUID identifies a build to tools; macOS wants a cryptographic statement identifying it to a developer — and the load command that carries it is next.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-code-signing">Code Signing</a> — LC_CODE_SIGNATURE, the big-endian superblob, page hashes in the CodeDirectory, and the team identity embedded at byte 101 of ours.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-entry">Prev: The Dynamic Linker and Entry Point</a></span>
                <span><a href="/courses/macho/lessons/macho-code-signing">Next: Code Signing</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
