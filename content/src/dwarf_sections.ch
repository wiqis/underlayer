// DWARF Course — Module 1: Why Debug Info Exists
// Concept: The .debug_* sections — what exists, who reads it, what survives.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_sections() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The .debug_* Sections — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>The <code>.debug_*</code> Sections</h1>
            <div class="lesson-meta">16 min &middot; Module 1: Why Debug Info Exists &middot; Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>"Add debug info" is one compiler flag, but it produces at least six separate sections with different jobs, different readers, and different fates. When a build is too large, teams reach for <code>strip</code> without knowing which sections they are discarding &mdash; and then a crash report loses the one table it needed.</p>
                <p>Knowing the sections separately is what lets you answer practical questions: what did <code>strip</code> actually remove, what can be regenerated and what cannot, and why two string sections exist when one would do.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Group the six sections by what they answer:</p>
                <ol>
                    <li><strong>Line info</strong> (<code>.debug_line</code> + <code>.debug_line_str</code>): address to source line. This is the one crash reporters need first.</li>
                    <li><strong>Structure info</strong> (<code>.debug_info</code> + <code>.debug_abbrev</code>): the tree of types, functions, parameters and variables. This is what lets a debugger show you a variable's value and its type.</li>
                    <li><strong>String pools</strong> (<code>.debug_str</code>, <code>.debug_line_str</code>): names, referenced by offset, never by inline text.</li>
                    <li><strong>Index</strong> (<code>.debug_aranges</code>): which address ranges belong to which compilation unit, so a tool can skip CUs it does not care about.</li>
                </ol>
                <div class="callout callout-warn">
                    <strong>Simplified, and the simplification is load-bearing.</strong> There is no separate "variable location" section in this list, because for this course's programs there is not one &mdash; local variable addresses live inside <code>.debug_info</code> as expression opcodes. At <code>-O2</code> a fifth section (<code>.debug_rnglists</code> or <code>.debug_loclists</code>) appears. Treat the four groups as a way of finding things, not as a fixed list.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Here is the real section table for <code>shape_v5</code>, from <code>readelf -S -W</code>. Read the last three columns carefully &mdash; they carry the whole lesson.</p>
                <pre><code>  [26] .debug_aranges    PROGBITS  0000000000000000 003036 000030 00      0   0  1
  [27] .debug_info       PROGBITS  0000000000000000 003066 000110 00      0   0  1
  [28] .debug_abbrev     PROGBITS  0000000000000000 003176 0000bf 00      0   0  1
  [29] .debug_line       PROGBITS  0000000000000000 003235 000073 00      0   0  1
  [30] .debug_str        PROGBITS  0000000000000000 0032a8 000111 01  MS  0   0  1
  [31] .debug_line_str   PROGBITS  0000000000000000 0033b9 00005e 01  MS  0   0  1</code></pre>
                <p>Three facts fall straight out of those rows:</p>
                <ol>
                    <li><strong>Every <code>Address</code> is <code>0000000000000000</code>.</strong> No debug section is ever mapped into memory. This is the same conclusion as <code>Addr 0</code> in the <a href="/courses/elf/lessons/common-sections">ELF section header table</a> &mdash; these sections exist in the file, not in the running process.</li>
                    <li><strong>Alignment is 1 for all six.</strong> These are byte streams, not arrays of machine words. That is unusual for an ELF file and it means you can read them with any tool, on any architecture.</li>
                    <li><strong>Only the two string sections carry the <code>MS</code> flag and an entry size of 1.</strong> <code>MS</code> is <code>SHF_MERGE | SHF_STRINGS</code>: the linker is allowed to <em>deduplicate</em> them across every object file it links. That is why <code>main</code> and <code>int32_t</code> appear once in <code>.debug_str</code> no matter how many object files mention them.</li>
                </ol>
                <p>Point 3 explains a design choice that otherwise looks pointless. <code>.debug_line_str</code> was added in DWARF 5 purely so that <em>path</em> strings live in their own mergeable pool, separate from <code>.debug_str</code>. Before v5, <code>shape.c</code> and <code>int32_t</code> shared one pool, so the linker merged the type-name pool into what was really a directory-path pool &mdash; both fully occupied, no overlap, pure waste in every single object file.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>All three binaries below come from the same <code>shape.c</code>. Only the flags differ.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Command</th><th scope="col">Size (bytes)</th><th scope="col">Debug sections</th><th scope="col">.symtab</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>gcc -gdwarf-5 -O0 -o shape_v5 shape.c</code></td><td>17256</td><td>all six</td><td>present</td></tr>
                        <tr><td><code>gcc -g0 -O0 -o shape_g0 shape.c</code></td><td>15800</td><td>none</td><td>present</td></tr>
                        <tr><td><code>strip shape_v5</code></td><td>14328</td><td>none</td><td>removed</td></tr>
                    </tbody>
                </table>
                <p>Two things to notice. <code>-g0</code> costs 1456 bytes of debug info and leaves symbols alone. <code>strip</code> removes debug info <em>and</em> the symbol table, which is why the stripped binary is <strong>smaller than the one built with no debug info at all</strong> &mdash; 14328 against 15800. Stripping is a different operation from <code>-g0</code>, and it removes strictly more.</p>
                <p>Now the string pools, to see the merge flag doing its job. The <code>.debug_str</code> of <code>shape_v5</code> starts with the compiler's own signature:</p>
                <div class="hex-dump">
                    <pre>00000000: 474e 5520 4332 3320 3135 2e32 2e30 202d  GNU C23 15.2.0 -
00000010: 6d74 756e 653d 6765 6e65 7269 6320 2d6d  mtune=generic -m
00000020: 6172 6368 3d78 3836 2d36 3420 2d67 6477  arch=x86-64 -gdw
00000030: 6172 662d 3520 2d4f 3020 2d66 6173 796e  arf-5 -O0 -fasyn</pre>
                </div>
                <p>That whole string is the value of <code>DW_AT_producer</code> in the compilation unit. Note it records <code>-O0</code> &mdash; the optimisation level is part of the debug info, because changing it changes the line table completely. And note it is stored once, at offset 0, and referenced by a 4-byte offset from <code>.debug_info</code>, never copied inline. <code>readelf -p .debug_str</code> prints the whole pool with the offsets a DIE would use:</p>
                <pre><code>  [     0]  GNU C23 15.2.0 -mtune=generic -march=x86-64 -gdwarf-5 -O0 ...
  [     b6]  long unsigned int
  [     c8]  __int32_t
  [     d2]  unsigned char
  [     e0]  main
  [     e5]  long int</code></pre>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ gcc -gdwarf-5 -O0 -o shape_v5 shape.c
$ gcc -g0        -O0 -o shape_g0 shape.c
$ cp shape_v5 shape_stripped &amp;&amp; strip shape_stripped

$ readelf -S -W shape_v5        | grep debug
$ readelf -S -W shape_g0        | grep debug   # nothing
$ readelf -S -W shape_stripped | grep -E 'debug|symtab'   # nothing

$ ls -l shape_v5 shape_g0 shape_stripped</code></pre>
                <p>Then isolate a single section, which is the cleanest way to see that it is just file bytes:</p>
                <pre><code>$ objcopy --dump-section .debug_line=dl.bin shape_v5
$ xxd dl.bin</code></pre>
                <p>What to look for: the <code>MS</code> flag on exactly the two string sections and nowhere else, and the surprising size ordering in the <code>ls</code> output. Both are explained in the REALITY unit above.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a linker is combining forty object files into one executable. Why does the resulting <code>.debug_str</code> contain one copy of the string <code>unsigned int</code> rather than forty?</p>
                <div class="quiz" id="quiz-dwarf-sections-1">
                    <button class="quiz-option" data-correct="true" data-explain=".debug_str is flagged MS = SHF_MERGE | SHF_STRINGS, which tells the linker it may deduplicate identical byte sequences. Without that flag the linker would have to leave all forty copies alone, because it could not know that deleting one would be safe." onclick="checkQuiz('quiz-dwarf-sections-1', this)">Because <code>.debug_str</code> is flagged <code>SHF_MERGE | SHF_STRINGS</code>, which lets the linker deduplicate identical strings across object files</button>
                    <button class="quiz-option" data-correct="false" data-explain="The compiler is right, .debug_str is a mergeable pool &mdash; but the deduplication is performed by the linker across object files, not by the compiler before the objects are even created. The section flag is what authorises it." onclick="checkQuiz('quiz-dwarf-sections-1', this)">Because the compiler deduplicates strings before emitting the object file, so only one copy was ever produced</button>
                    <button class="quiz-option" data-correct="false" data-explain="This confuses a string pool with the data it describes. Four copies of the string would only exist if each DIE carried its name inline; instead each carries a 4-byte offset, so the size of .debug_str is driven by distinct names, not by how many DIEs reference them." onclick="checkQuiz('quiz-dwarf-sections-1', this)">Because <code>.debug_info</code> stores type names only once, so there is only ever one string to keep</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your release pipeline strips binaries to save space. Support keeps reporting crashes with <code>???</code> where the function name should be, but engineers can still see correct source file and line numbers. Which sections survived, and what single change fixes the rest?</p>
                <div class="quiz" id="quiz-dwarf-sections-2">
                    <button class="quiz-option" data-correct="true" data-explain="This is the signature of removing .symtab but keeping the line table. .debug_line and .debug_line_str are intact, which is why file and line resolve, but without .symtab nothing maps a raw address to a function name. Build with -s instead of strip, or keep a separate unstripped binary per release and upload it to your symbol server." onclick="checkQuiz('quiz-dwarf-sections-2', this)">The line table survived but the symbol table did not &mdash; strip removed <code>.symtab</code> &mdash; so ship the unstripped file to a symbol server and keep only the address-to-line data in the released binary</button>
                    <button class="quiz-option" data-correct="false" data-explain="Function names live in .symtab, which is a separate structure from DWARF. Nothing in .debug_line can supply a function name, because the line table maps addresses to file and line, never to symbols. Keeping all DWARF while dropping .symtab is exactly the broken state described." onclick="checkQuiz('quiz-dwarf-sections-2', this)">Nothing survived, so you need to re-run the build with debug info and symbols and replace the shipped binary entirely</button>
                    <button class="quiz-option" data-correct="false" data-explain="The evidence contradicts this: the reporter is already resolving file and line correctly, so .debug_line is present. Function names are the only missing piece, and .symtab is where they live." onclick="checkQuiz('quiz-dwarf-sections-2', this)">The DWARF sections survived but <code>.symtab</code> was dropped, so re-adding symbols is the fix</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a crash report is half-degraded, that pattern is diagnostic. Working line numbers but missing function names is a specific, known configuration, not a mystery.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The <code>MS</code> flag is an ELF section-header attribute, so this concept leans on <a href="/courses/elf/lessons/section-header-table">The ELF Section Header Table</a>. The address column that is always zero is the subject of <a href="/courses/elf/lessons/memory-mapping">ELF memory mapping</a>: a section with no address is never mapped.</p>
                <p>You now know the sections exist and what each is for. But they are not interchangeable &mdash; a v4 file and a v5 file lay the <em>same</em> data out differently, and a parser that assumes the wrong one reads garbage. That is next.</p>
                <p>Next: <a href="/courses/dwarf/lessons/dwarf-versions">DWARF 2, 3, 4 and 5</a> &mdash; what each version changed, and the two specific byte layouts that will silently break a reader.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-intro">Previous: Why DWARF Exists</a></span>
                <span><a href="/courses/dwarf/lessons/dwarf-versions">Next: DWARF 2, 3, 4 and 5</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
