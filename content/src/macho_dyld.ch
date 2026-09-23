// Mach-O Course — Concept 22: How dyld Loads a Mach-O.
// Seven stages from execve to main, grounded in our two sample eras of load commands.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_dyld() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("How dyld Loads a Mach-O — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>How dyld Loads a Mach-O</h1>
            <div class="lesson-meta">20 min · Module 8: Loading &amp; Execution</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Between the shell's execve and the first line of your main() sits dyld, the dynamic linker — the only component that reads <em>every</em> load command you have studied and acts on them. Segments get mapped, dependencies chased, pointers fixed, exports published, initializers run, entry jumped to. A load command nobody reads is dead bytes; dyld is the reader.</p>
                <p>It also explains most load-time mysteries: why a missing dylib fails before any of your code runs, why a function pointer is wrong until "fixups" happen, why constructors fire in an order you did not choose, and why an unknown command marked LC_REQ_DYLD can stop the image from loading at all while an unknown optional command is silently ignored.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Seven stages, each backed by a load command we can point at in our samples:</p>
                <ol>
                    <li><strong>The kernel hands over.</strong> It maps the segments declared by LC_SEGMENT_64, reads LC_LOAD_DYLINKER, maps <code>/usr/lib/dyld</code>, and transfers control to it.</li>
                    <li><strong>dyld maps the executable</strong> at its preferred base (0x100000000) and picks the ASLR slide promised by MH_PIE — the same offset will be applied to every dependency.</li>
                    <li><strong>Closure.</strong> Walk LC_LOAD_DYLIB (plus weak and reexport variants) depth-first until the dependency set stops growing; LC_RPATH rows extend the run path used to resolve @rpath-prefixed names.</li>
                    <li><strong>Fixups.</strong> Modern files: one LC_DYLD_CHAINED_FIXUPS blob. Classic files: LC_DYLD_INFO_ONLY's rebase/bind/lazy/weak opcode streams. Either way: make every pointer name the right final address.</li>
                    <li><strong>Exports and symbols.</strong> Publish the image's exported names via LC_DYLD_EXPORTS_TRIE (or the export region inside dyld_info); LC_SYMTAB and LC_DYSYMTAB hold the full symbol view for tools.</li>
                    <li><strong>Initializers.</strong> Run S_MOD_INIT_FUNC_POINTERS sections, ObjC +load methods, Swift static init — the slot LC_ROUTINES ("image routines") reserved in the old format.</li>
                    <li><strong>Jump.</strong> Compute __TEXT.vmaddr + LC_MAIN.entryoff + slide and jump there. The startup sequence is the next concept; this one ends at the jump.</li>
                </ol>
                <p>The model's missing piece: stages 4 through 6 leave no line in otool — their evidence is the offsets and formats you decoded in earlier concepts. And dyld's shared-cache bootstrap (how /usr/lib/libSystem.B.dylib materializes without a loose file) lives outside our samples: we can see the <em>request</em> for that dylib, never the cache itself.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Our two samples sit on opposite sides of a format-era split. Same pipeline, different evidence — every cell read from the files:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Stage evidence</th><th scope="col">prog64.macho (modern)</th><th scope="col">libasyncProfiler.dylib (classic)</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Image / flags</td><td>EXECUTE, ncmds 14 — flags include MH_PIE (random base)</td><td>DYLIB, ncmds 18 — no MH_PIE; flags: NOUNDEFS DYLDLINK TWOLEVEL WEAK_DEFINES BINDS_TO_WEAK NO_REEXPORTED_DYLIBS</td></tr>
                        <tr><td>Dynamic linker</td><td>LC_LOAD_DYLINKER → /usr/lib/dyld</td><td>none — dylibs are loaded, not launched ("a file can have at most one of these")</td></tr>
                        <tr><td>Entry</td><td>LC_MAIN, entryoff 1104</td><td>none — LC_MAIN is "only used in MH_EXECUTE filetypes"</td></tr>
                        <tr><td>Dependencies</td><td>none — no LC_LOAD_DYLIB at all</td><td>/usr/lib/libSystem.B.dylib, /usr/lib/libc++.1.dylib</td></tr>
                        <tr><td>Run paths</td><td>none</td><td>LC_RPATH: @executable_path/../lib and @executable_path/../lib/server</td></tr>
                        <tr><td>Pointer fixing</td><td>LC_DYLD_CHAINED_FIXUPS, 56 bytes at 12288</td><td>LC_DYLD_INFO_ONLY: rebase 573440/248, bind 573688/2664, lazy 577472/4656</td></tr>
                        <tr><td>Exports</td><td>LC_DYLD_EXPORTS_TRIE, 96 bytes at 12344</td><td>export region 582128/1432 inside dyld_info</td></tr>
                        <tr><td>Full symbols</td><td>LC_SYMTAB, nsyms 6</td><td>LC_SYMTAB, nsyms 2015 (strings at 619424, 87936 bytes)</td></tr>
                    </tbody>
                </table>
                <p>The dylib also shows the install-name machinery the closure stage consumes: LC_ID_DYLIB names itself <code>build/lib/libasyncProfiler.dylib</code>, and each LC_LOAD_DYLIB carries an absolute path — no rpaths needed for those two, but the two LC_RPATH commands are there for any @rpath-prefixed dependency. <code>rpath_command</code>'s comment is exact: "a path which at runtime should be added to the current run path used to find @rpath prefixed dylibs."</p>
                <div class="callout callout-warn">
                    <strong>LC_REQ_DYLD, the stage gate.</strong> loader.h: if dyld meets a load command it does not understand that has the LC_REQ_DYLD bit, it errors "unknown load command required for execution" and refuses the image; unknown commands without the bit are ignored. Both era-marks above — LC_DYLD_INFO_ONLY and LC_DYLD_CHAINED_FIXUPS — carry the bit: neither generation can half-load.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The modern fixup stage, in full: <code>LC_DYLD_CHAINED_FIXUPS</code>'s 56-byte header at file offset 12288, decoded field by field against <code>fixup-chains.h</code>:</p>
                <div class="hex-dump">
                    <pre>00003000: 0000 0000 2000 0000 3800 0000 3800 0000  .... ...8...8...
00003010: 0000 0000 0100 0000 0000 0000 0000 0000  ................</pre>
                </div>
                <p><code>fixups_version</code> 0, <code>starts_offset</code> 0x20, <code>imports_offset</code> 0x38, <code>symbols_offset</code> 0x38, <code>imports_count</code> 0, <code>imports_format</code> 1, <code>symbols_format</code> 0. That imports_count of zero is the whole file in one number: this program links no libraries (no LC_LOAD_DYLIB), so it imports no symbols — only rebase chains, relocating code and data within its own image. The header's two length fields even agree: starts begin at 0x20, imports would begin at 0x38, and 56 bytes of payload end exactly at 0x38 with nothing between to count.</p>
                <p>Compare the classic side of the same stage — five offset/size pairs dyld walks in order (rebase, bind, weak_bind, lazy_bind, export), then LC_SYMTAB's nsyms 2015 for everything else. Two eras, one pipeline stage.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Watch both halves of the pipeline declare themselves — on macOS use <code>otool</code>, on Linux <code>llvm-otool</code>:</p>
                <pre><code>$ llvm-otool -l prog64.macho | grep -A2 LC_LOAD_DYLINKER
          cmd LC_LOAD_DYLINKER
      cmdsize 32
         name /usr/lib/dyld (offset 12)

$ llvm-otool -L libasyncProfiler.dylib
libasyncProfiler.dylib:
	build/lib/libasyncProfiler.dylib (compatibility version 0.0.0, current version 0.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1319.100.3)
	/usr/lib/libc++.1.dylib (compatibility version 1.0.0, current version 1500.65.0)

$ llvm-otool -l libasyncProfiler.dylib | grep -A11 LC_DYLD_INFO_ONLY
            cmd LC_DYLD_INFO_ONLY
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
                <p>What to look for: the executable names its dynamic linker and nothing else to load; <code>otool -L</code>'s first line is always the dylib's own install name (its LC_ID_DYLIB), the rest are stage-3 closure edges; and the five dyld_info pairs are the entire classic fixup-plus-exports stage in twelve lines. Every offset points into __LINKEDIT — where the map lesson said this metadata lives.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: which load command tells the kernel and dyld where the dynamic linker itself lives, and what does <code>prog64.macho</code> name?</p>
                <div class="quiz" id="quiz-dyld-1">
                    <button class="quiz-option" data-correct="false" data-explain="LC_LOAD_DYLIB loads image dependencies, not the linker itself — and this binary has none of those at all. dyld must be found before any dependency walk begins." onclick="checkQuiz('quiz-dyld-1', this)">LC_LOAD_DYLIB, pointing at /usr/lib/libSystem.B.dylib</button>
                    <button class="quiz-option" data-correct="true" data-explain="LC_LOAD_DYLINKER is the dylinker_command (at most one per file) that names the dynamic linker; prog64.macho carries exactly /usr/lib/dyld, which the kernel maps before transferring control." onclick="checkQuiz('quiz-dyld-1', this)">LC_LOAD_DYLINKER, naming /usr/lib/dyld</button>
                    <button class="quiz-option" data-correct="false" data-explain="LC_MAIN names the entry point inside the main executable (entryoff 1104) — that is stage 7, jumped to after dyld has already been loaded, run, and finished every earlier stage." onclick="checkQuiz('quiz-dyld-1', this)">LC_MAIN, whose entryoff points at dyld's own entry</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Suppose an executable declares LC_RPATH <code>@executable_path/../lib</code> and links a dependency named <code>@rpath/libFoo.dylib</code>. How does dyld resolve it?</p>
                <div class="quiz" id="quiz-dyld-2">
                    <button class="quiz-option" data-correct="false" data-explain="/usr/lib is where absolute-path dependencies like the sample's libSystem live. rpaths participate only for names that literally begin with @rpath — that prefix is what triggers the run-path search." onclick="checkQuiz('quiz-dyld-2', this)">Only in /usr/lib — absolute dylib paths bypass run paths entirely</button>
                    <button class="quiz-option" data-correct="true" data-explain="For each LC_RPATH, dyld expands @executable_path to the main binary's directory, appends it to the current run path, and tries the @rpath remainder — so .../lib/libFoo.dylib first, then .../lib/server/libFoo.dylib. That is exactly what rpath_command's comment promises." onclick="checkQuiz('quiz-dyld-2', this)">Substitutes @executable_path, then tries ../lib/libFoo.dylib and ../lib/server/libFoo.dylib</button>
                    <button class="quiz-option" data-correct="false" data-explain="The comment on rpath_command says the path is added to the run path at runtime — LC_RPATH is consumed by dyld during load, never merely recorded for the linker." onclick="checkQuiz('quiz-dyld-2', this)">It does not — LC_RPATH is a link-time hint dyld ignores</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: every stage of the pipeline has a load command as its receipt — dylinker, dylibs, rpaths, fixups, exports, init sections, entry. Read the commands and you have read the algorithm.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>dyld has now consumed the entire format: the <a href="/courses/macho/lessons/macho-hardening">protections</a> it mapped, the <a href="/courses/macho/lessons/macho-dyld-info">rebase and bind streams</a> or <a href="/courses/macho/lessons/macho-chained-fixups">chained fixups</a> it executed, the <a href="/courses/macho/lessons/macho-export-trie">export trie</a> it published, and the LC_MAIN entry it is about to jump to. But "the image is loaded" still hides a question every crash report depends on: at which addresses does all this actually exist right now?</p>
                <p>Next: <a href="/courses/macho/lessons/macho-memory-layout">Process Memory Layout</a> — preferred addresses, the slide, and the three coordinate systems (file offset, vmaddr, runtime address) that every bug report mixes together.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-hardening">Prev: __PAGEZERO and Memory Hardening</a></span>
                <span><a href="/courses/macho/lessons/macho-memory-layout">Next: Process Memory Layout</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
