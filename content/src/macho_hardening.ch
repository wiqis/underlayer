// Mach-O Course — Concept 21: __PAGEZERO and Memory Hardening.
// The null guard, MH_PIE, W^X segment protections, and the policy flag bits.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_hardening() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("__PAGEZERO and Memory Hardening — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>__PAGEZERO and Memory Hardening</h1>
            <div class="lesson-meta">15 min · Module 7: Integrity &amp; Debug</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A NULL pointer is address 0. For decades the exploit playbook started by mapping page 0, so the program's "nothing" landed in attacker-owned memory. The second trick: find a page that is writable <em>and</em> executable and drop shellcode there. The third: hard-code target addresses because nothing ever moves. Every one of those tricks dies before your code runs — because Mach-O declares its defenses in load commands, in bytes you can read with otool.</p>
                <p>This is also where the numbers from earlier lessons stop being abstract. <code>initprot 0x00000005</code> is not trivia: it is 4 plus 1, which is EXECUTE plus READ, which is why __text runs and cannot be overwritten. Read these fields like a security policy, because that is what the kernel enforces.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Four defenses, four places to look:</p>
                <ol>
                    <li><strong>__PAGEZERO</strong> — 4 GiB at address 0, no protections, no file bytes. Anything that touches NULL faults.</li>
                    <li><strong>MH_PIE</strong> — a header flag: "the OS will load the main executable at a random address." Preferred base becomes just a preference.</li>
                    <li><strong>initprot / maxprot</strong> — per-segment protection: __TEXT read-execute, __DATA read-write, __LINKEDIT read-only. W^X by construction.</li>
                    <li><strong>Policy flag bits</strong> — MH_ALLOW_STACK_EXECUTION, MH_NO_HEAP_EXECUTION, MH_DYLIB_IN_CACHE and friends announce what the image opts into or out of.</li>
                </ol>
                <p>The model's missing piece: declaring is not enforcing. The segment protections are enforced by the kernel's VM system, the slide is applied by dyld, and the bytes being executed were attested by the code signature from the previous concept. One posture, three different enforcers — a defense only holds when all three agree.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Protections, decoded with the Mach-O values <code>VM_PROT_READ = 1</code>, <code>VM_PROT_WRITE = 2</code>, <code>VM_PROT_EXECUTE = 4</code>:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Segment</th><th scope="col">maxprot / initprot</th><th scope="col">Decode</th><th scope="col">What it means</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>__PAGEZERO</td><td>0 / 0</td><td>no access</td><td>any read, write, or fetch faults — the NULL trap</td></tr>
                        <tr><td>__TEXT</td><td>5 / 5</td><td>r-x (1|4)</td><td>code runs; nothing can overwrite it in memory</td></tr>
                        <tr><td>__DATA</td><td>3 / 3</td><td>rw- (1|2)</td><td>mutable globals; never executable</td></tr>
                        <tr><td>__LINKEDIT</td><td>1 / 1</td><td>r--</td><td>fixups, symbols, signature — readable, sealed</td></tr>
                    </tbody>
                </table>
                <p>In <code>prog64.macho</code> maxprot equals initprot on all four segments: the ceiling and the starting state are the same. <code>segment_command</code> comments the two fields "maximum VM protection" and "initial VM protection" — maxprot is the ceiling a later remap may raise up to, initprot is what the segment gets at map time.</p>
                <p>Now the flags word, 0x00200085, against the hardening-relevant bits in <code>loader.h</code>:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Flag</th><th scope="col">Value</th><th scope="col">Set in 0x00200085?</th><th scope="col">loader.h says</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>MH_NOUNDEFS</td><td>0x1</td><td>yes</td><td>"the object file has no undefined references"</td></tr>
                        <tr><td>MH_DYLDLINK</td><td>0x4</td><td>yes</td><td>"input for the dynamic linker and can't be staticly link edited again"</td></tr>
                        <tr><td>MH_TWOLEVEL</td><td>0x80</td><td>yes</td><td>"the image is using two-level name space bindings"</td></tr>
                        <tr><td>MH_PIE</td><td>0x200000</td><td><strong>yes</strong></td><td>"the OS will load the main executable at a random address"</td></tr>
                        <tr><td>MH_ALLOW_STACK_EXECUTION</td><td>0x20000</td><td>no</td><td>"all stacks in the task will be given stack execution privilege"</td></tr>
                        <tr><td>MH_NO_HEAP_EXECUTION</td><td>0x1000000</td><td>no</td><td>"run the main executable with a non-executable heap even on platforms (e.g. i386) that don't require it"</td></tr>
                        <tr><td>MH_DYLIB_IN_CACHE</td><td>0x80000000</td><td>no (dylib-only)</td><td>"the dylib is part of the dyld shared cache, rather than loose in the filesystem"</td></tr>
                    </tbody>
                </table>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> MH_PIE is 0x200000 and MH_ALLOW_STACK_EXECUTION is 0x20000 — one zero apart. The flags word 0x00200085 contains 0x200000, so ASLR is on; it does <em>not</em> contain 0x20000, so stack execution was never opted into. Confusing the two flips your verdict on both defenses.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The whole posture fits in the header's last eight bytes and four segment commands. Header bytes 16–31 of <code>prog64.macho</code>:</p>
                <div class="hex-dump">
                    <pre>00000010: 0e00 0000 c803 0000 8500 2000 0000 0000  ........</pre>
                </div>
                <p>ncmds = 14, sizeofcmds = 968, then the flags word <code>85 00 20 00</code> read little-endian = 0x00200085 = 0x1 | 0x4 | 0x80 | 0x200000 — NOUNDEFS, DYLDLINK, TWOLEVEL, PIE, and nothing else. The reserved word after it is zero.</p>
                <p>Pair it with the first load command, the one that gives the lesson its name:</p>
                <div class="hex-dump">
                    <pre>segname __PAGEZERO
   vmaddr 0x0000000000000000
   vmsize 0x0000000100000000
  fileoff 0
 filesize 0
  maxprot 0x00000000
 initprot 0x00000000</pre>
                </div>
                <p>Zero address, 4 GiB, zero bytes on disk, zero permissions — a region that exists only to fail. <code>loader.h</code> gives it the title it deserves: "the pagezero segment which has no protections and catches NULL references for MH_EXECUTE files."</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Any Mach-O works — on macOS use <code>otool</code>, on Linux <code>llvm-otool</code>. First the guard page, then the flag bits:</p>
                <pre><code>$ llvm-otool -l prog64.macho | grep -A7 __PAGEZERO
   segname __PAGEZERO
   vmaddr 0x0000000000000000
   vmsize 0x0000000100000000
  fileoff 0
 filesize 0
  maxprot 0x00000000
 initprot 0x00000000
   nsects 0

$ python3 -c "f=0x00200085; print('PIE', bool(f &amp; 0x200000)); print('STACK_EXECUTION', bool(f &amp; 0x20000))"
PIE True
STACK_EXECUTION False</code></pre>
                <p>What to look for: PAGEZERO is all zeros with filesize 0 — pure reserved address space; and the mask test splits 0x200000 from 0x20000 so you never confuse ASLR's bit with stack execution's. Then check your own binary's <code>initprot</code> values against the READ/WRITE/EXECUTE table above.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: catching NULL dereferences is __PAGEZERO's fame — what is its second job?</p>
                <div class="quiz" id="quiz-hard-1">
                    <button class="quiz-option" data-correct="false" data-explain="filesize is 0 — PAGEZERO maps no file bytes at all. The mach_header and load commands live inside __TEXT, which starts where PAGEZERO ends." onclick="checkQuiz('quiz-hard-1', this)">It maps the file header region read-only at low addresses</button>
                    <button class="quiz-option" data-correct="true" data-explain="PAGEZERO reserves the entire low 4 GiB (0x0 to 0x100000000) with no permissions, and its end boundary is exactly where __TEXT's preferred base sits — one segment's size defines the image's address." onclick="checkQuiz('quiz-hard-1', this)">It reserves the low 4 GiB and anchors __TEXT at 0x100000000</button>
                    <button class="quiz-option" data-correct="false" data-explain="The shared cache is announced by MH_DYLIB_IN_CACHE on system dylibs, and dyld's cache lives wherever the system maps it — not in the executable's PAGEZERO, which sits below the image." onclick="checkQuiz('quiz-hard-1', this)">It caches the dyld shared cache mappings for system dylibs</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>An auditor greps the flags of <code>prog64.macho</code>, sees 0x00200085, and asks: is MH_ALLOW_STACK_EXECUTION set — are stacks executable here?</p>
                <div class="quiz" id="quiz-hard-2">
                    <button class="quiz-option" data-correct="false" data-explain="The 0x200000 in the flags word is MH_PIE (ASLR). MH_ALLOW_STACK_EXECUTION is 0x20000 — different bit entirely. 0x00200085 minus 0x1, 0x4, 0x80, 0x200000 is exactly zero." onclick="checkQuiz('quiz-hard-2', this)">Yes — 0x200000 in the word covers the stack-execution bit</button>
                    <button class="quiz-option" data-correct="true" data-explain="The bit is 0x20000 and it is absent: 0x00200085 = 0x1 | 0x4 | 0x80 | 0x200000. Stacks never got the execution-privilege opt-in, and segment protections keep __TEXT as the only executable region." onclick="checkQuiz('quiz-hard-2', this)">No — 0x20000 is not among the set bits</button>
                    <button class="quiz-option" data-correct="false" data-explain="MH_NO_HEAP_EXECUTION is 0x1000000 and it is absent too. The verdict comes from the stack bit simply being unset — neither policy flag appears in 0x00200085." onclick="checkQuiz('quiz-hard-2', this)">No — but only because MH_NO_HEAP_EXECUTION is set instead</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: decode protections as bit values, never as appearances. 0x200000 and 0x20000 differ by one nibble — and so do ASLR and stack execution.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You have read the defense posture straight from the file: a guard page at zero, a random base, W^X segments, policy flags — declared in bytes, enforced by kernel and dyld, attested by the <a href="/courses/macho/lessons/macho-code-signing">code signature</a>. But someone has to actually <em>perform</em> that map: choose the slide, walk the dependencies, fix every pointer.</p>
                <p>Next: <a href="/courses/macho/lessons/macho-dyld">How dyld Loads a Mach-O</a> — seven stages from execve to main, each one anchored to a load command you have already met.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-debug-info">Prev: Debug Info</a></span>
                <span><a href="/courses/macho/lessons/macho-dyld">Next: How dyld Loads a Mach-O</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
