// DWARF Course — Module 1: Why Debug Info Exists
// Concept: Why DWARF Exists — the address-to-source problem.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_intro() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Why DWARF Exists — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>Why DWARF Exists</h1>
            <div class="lesson-meta">14 min &middot; Module 1: Why Debug Info Exists &middot; Orientation</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Your program has a bug at line 15. You attach a debugger, and it stops. But the machine does not know what a "line 15" is &mdash; it knows that address <code>0x1154</code> holds the bytes <code>48 8b 45 f8</code>. Between your source text and that byte sequence, the compiler discarded every scrap of information about <em>which statement produced which instruction</em>.</p>
                <p>DWARF (Debugging With Attributed Record Formats) is the standard that puts that information back, as data in the file itself. It is not a debugger. It is not a library. It is a <strong>file format</strong> &mdash; the same kind of thing as the ELF header you learned to parse, just describing a different question.</p>
                <p>You have already met the other half of this. <a href="/courses/elf/lessons/memory-mapping">ELF memory mapping</a> turns file offsets into virtual addresses. DWARF is the table that says what source construct lives at each of those addresses. Debug a program and you are using both at once.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>For now, treat a compiled program as three separate things that happen to travel together:</p>
                <ol>
                    <li><strong>Code.</strong> Addresses and instructions. The CPU needs this and nothing else.</li>
                    <li><strong>Symbols.</strong> A name for a few addresses, like <code>main</code>. The linker keeps these so a crash report can print <code>main+0x1a</code> instead of <code>0x116b</code>.</li>
                    <li><strong>Debug info.</strong> A description of types, variables, lines, and scopes, addressed by the same numbers.</li>
                </ol>
                <div class="callout callout-warn">
                    <strong>This model is wrong in one important way, and knowing how is the point of this course.</strong> Debug info is not a tidy third list. It is a set of interlocking tables that each point at the others, and following a single source line can walk you through four of them. We build the real model in Module 2.
                </div>
                <p>Also note what the model leaves out: <strong>DWARF says nothing about running.</strong> The CPU never reads it. A program with its DWARF sections deleted executes identically, just 15&nbsp;KB smaller. Debug info is strictly for tools.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>DWARF is produced by the compiler, stored in sections the linker keeps, and read by debuggers, profilers, crash reporters, and language runtimes. The reference implementation on this machine is GCC 15.2, and the <code>shape.c</code> used throughout this course is:</p>
                <pre><code>#include &lt;stdint.h&gt;

struct Point &#123;
    int32_t x;
    int32_t y;
&#125;;

int32_t add(int32_t a, int32_t b) &#123;
    return a + b;
    &#125;

int main(void) &#123;
    struct Point p;
    p.x = 3;
    p.y = add(p.x, 4);
    return p.y;
&#125;</code></pre>
                <p>Compiled <code>gcc -gdwarf-5 -O0 -o shape_v5 shape.c</code>, it produces six debug sections:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Section</th><th scope="col">File offset</th><th scope="col">Size</th><th scope="col">Answers the question</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>.debug_info</code></td><td>0x3066</td><td>0x110</td><td>What types, functions and variables exist?</td></tr>
                        <tr><td><code>.debug_abbrev</code></td><td>0x3176</td><td>0xbf</td><td>What shapes do the entries in <code>.debug_info</code> take?</td></tr>
                        <tr><td><code>.debug_line</code></td><td>0x3235</td><td>0x73</td><td>Which source line is this address on?</td></tr>
                        <tr><td><code>.debug_line_str</code></td><td>0x33b9</td><td>0x5e</td><td>File and directory paths</td></tr>
                        <tr><td><code>.debug_str</code></td><td>0x32a8</td><td>0x111</td><td>Every other string (type names, producers, variables)</td></tr>
                        <tr><td><code>.debug_aranges</code></td><td>0x3036</td><td>0x30</td><td>Which address ranges belong to which CU?</td></tr>
                    </tbody>
                </table>
                <p>Every one of them has <code>Addr 0</code> and <code>ES 0</code> in the section header table. A debug section is never mapped into memory. It is file content that tools read from disk, which is exactly why you can strip it without changing behaviour.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Here is the payoff, on the real binary. This is <code>objdump -d</code> &mdash; pure disassembly, no source, no line numbers. This is what the machine actually has:</p>
                <pre><code>0000000000001129 &lt;add&gt;:
    1129:	f3 0f 1e fa          	endbr64
    112d:	55                   	push   %rbp
    112e:	48 89 e5             	mov    %rsp,%rbp
    1131:	89 7d fc             	mov    %edi,-0x4(%rbp)
    1134:	89 75 f8             	mov    %esi,-0x8(%rbp)
    1137:	8b 55 fc             	mov    -0x4(%rbp),%edx
    113a:	8b 45 f8             	mov    -0x8(%rbp),%eax
    113d:	01 d0                	add    %edx,%eax
    113f:	5d                   	pop    %rbp
    1140:	c3                   	ret</code></pre>
                <p>Now add <code>-l</code>. <code>objdump</code> reads the DWARF line table and interleaves the source positions. Same bytes, same addresses, and now every instruction is attributed:</p>
                <pre><code>0000000000001129 &lt;add&gt;:
add():
/tmp/opencode/dwarf-research/shape.c:8
    1129:	f3 0f 1e fa          	endbr64
    112d:	55                   	push   %rbp
    112e:	48 89 e5             	mov    %rsp,%rbp
    1131:	89 7d fc             	mov    %edi,-0x4(%rbp)
    1134:	89 75 f8             	mov    %esi,-0x8(%rbp)
/tmp/opencode/dwarf-research/shape.c:9
    1137:	8b 55 fc             	mov    -0x4(%rbp),%edx
    113a:	8b 45 f8             	mov    -0x8(%rbp),%eax
    113d:	01 d0                	add    %edx,%eax
/tmp/opencode/dwarf-research/shape.c:10
    113f:	5d                   	pop    %rbp
    1140:	c3                   	ret</code></pre>
                <p>The whole difference between these two outputs is 115 bytes of <code>.debug_line</code> (plus the tables it references). <code>0x113d</code> is an <code>add %edx,%eax</code> instruction. Because the line table says address <code>0x1137</code> is on line 9, and a line row stays current until the next row, <code>objdump</code> can say that <code>0x113d</code> is also line 9 &mdash; and line 9 is <code>return a + b;</code>. It did not disassemble anything clever. It just did a lookup.</p>
                <p>Notice line 8 begins at <code>0x1129</code>, the very first instruction of <code>add</code>, and line 10 begins at <code>0x113f</code>, the <code>pop</code> &mdash; the closing brace. The compiler's prologue and epilogue are attributed to the braces that produced them.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <p>Build the reference binary. This is the exact command used to produce every hex dump in this course:</p>
                <pre><code>$ gcc -gdwarf-5 -O0 -o shape_v5 shape.c
$ objdump -d shape_v5 | sed -n '/&lt;add&gt;:/,/^$/p'
$ objdump -dl shape_v5 | sed -n '/&lt;add&gt;:/,/^$/p'</code></pre>
                <p>Then watch the debug info disappear:</p>
                <pre><code>$ cp shape_v5 shape_stripped
$ strip shape_stripped
$ objdump -l shape_stripped</code></pre>
                <p>What to look for: the second command prints <strong>nothing</strong> for <code>add</code>. The disassembly is still there &mdash; <code>objdump -d</code> still works &mdash; but every line-number annotation is gone, because <code>strip</code> removed <code>.debug_*</code>. That is the whole subject of this course in one experiment.</p>
                <p>Also try <code>readelf -S shape_v5 | grep debug</code> and compare against <code>readelf -S shape_stripped | grep debug</code>.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a program runs correctly after you <code>strip</code> it. What does that tell you about whether the CPU reads the debug sections?</p>
                <div class="quiz" id="quiz-dwarf-intro-1">
                    <button class="quiz-option" data-correct="true" data-explain="The program still executes correctly, and that is the proof: execution never touched .debug_line or .debug_info. Only tools read them, which is why stripping is safe for production binaries." onclick="checkQuiz('quiz-dwarf-intro-1', this)">The CPU never reads them &mdash; they exist purely for tools, so removing them cannot change behaviour</button>
                    <button class="quiz-option" data-correct="false" data-explain="If the CPU needed them, stripping would crash the program. Since it keeps working, the loader did not map them either &mdash; every debug section has Addr 0 and is never loaded." onclick="checkQuiz('quiz-dwarf-intro-1', this)">The CPU reads them lazily, and stripping just makes the reads fail silently</button>
                    <button class="quiz-option" data-correct="false" data-explain="The line table is data, not code. A CPU executing an add instruction does not consult a source-line mapping, and the ELF section header shows Addr 0 for every .debug_* section." onclick="checkQuiz('quiz-dwarf-intro-1', this)">The CPU reads them to decide which instructions are safe to speculatively execute</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are handed a core dump from a stripped production binary. The report says <code>crash at 0x4005a1, in ???</code>. Which single fact decides whether you can recover the source line, and why is it not something you can fix by re-running the binary?</p>
                <div class="quiz" id="quiz-dwarf-intro-2">
                    <button class="quiz-option" data-correct="true" data-explain="The address-to-line mapping lived in .debug_line, which strip removed from that file. Re-running produces a new binary whose debug info is absent too, so the information is gone permanently &mdash; it is not recoverable, only reproducible from a build you no longer have." onclick="checkQuiz('quiz-dwarf-intro-2', this)">The .debug_line table was removed, and re-running cannot help because a fresh build from the same recipe would be stripped as well</button>
                    <button class="quiz-option" data-correct="false" data-explain="Re-running does reproduce the addresses &mdash; the crash is at the same 0x4005a1. What is missing is the mapping from that address to a source line, and no amount of re-execution regenerates a table that was never recorded." onclick="checkQuiz('quiz-dwarf-intro-2', this)">Nothing is decided yet &mdash; re-running with a debugger attached will rebuild the mapping automatically</button>
                    <button class="quiz-option" data-correct="false" data-explain="Symbols are not the issue here; the report already shows the address, and .symtab only names a handful of functions. The address-to-line mapping is the separate job of .debug_line." onclick="checkQuiz('quiz-dwarf-intro-2', this)">The symbol table was removed, so you need symbols rather than line info</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: before shipping a binary, ask which of its debug sections a future you will actually need. The usual answer is that you cannot re-create them later.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Two things established here carry through the rest of the course. First, the mental model: <strong>code, symbols, debug info are separate layers</strong>, and only symbols survive a normal <code>strip</code>. Second, the mechanism: <strong>an address-to-line table is a lookup, not an inference</strong> &mdash; the whole of Module 2 is the byte layout of that lookup table.</p>
                <p>Next: <a href="/courses/dwarf/lessons/dwarf-sections">The .debug_* Sections</a> &mdash; which sections exist, who reads each one, and why the linker usually throws half of them away.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf">Course home</a></span>
                <span><a href="/courses/dwarf/lessons/dwarf-sections">Next: The .debug_* Sections</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
