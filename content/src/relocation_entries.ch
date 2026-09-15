// ELF Course — Concept 16: Relocation Entries
// How the linker records patches that need to be applied to code and data.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_relocation_entries() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Relocation Entries — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>Relocation Entries</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>When you compile a function call like printf("hello"), the compiler doesn't know where printf will eventually live in memory. It leaves a placeholder and creates a relocation entry — a note that says "patch this address when you know the final location."</p>
                <p>Without relocations, the linker couldn't combine object files into a program, and the dynamic linker couldn't load shared libraries.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>A relocation entry is a "TODO note" for the linker:</p>
                <ul>
                    <li><strong>Offset</strong> — Where to patch (which byte in the file)</li>
                    <li><strong>Info</strong> — What symbol to use and what kind of patch to apply</li>
                    <li><strong>Addend</strong> — An extra adjustment to add to the final value</li>
                </ul>
                <p>When the linker resolves a symbol, it walks all relocation entries for that symbol, computes the correct value, and writes it into the binary at the specified offset.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>ELF defines two relocation structures:</p>
                <div class="hex-dump">
                    <pre># Elf64_Rel (without addend, rarely used)
#   r_offset  (uint64_t)  Where to patch
#   r_info    (uint64_t)  Symbol index + relocation type

# Elf64_Rela (with addend, used on x86-64)
#   r_offset  (uint64_t)  Where to patch
#   r_info    (uint64_t)  Symbol index + relocation type
#   r_addend  (int64_t)   Constant addend for the computation</pre>
                </div>
                <p>The r_info field packs two values:</p>
                <ul>
                    <li><strong>Symbol</strong>: ELF64_R_SYM(info) — index into the symbol table</li>
                    <li><strong>Type</strong>: ELF64_R_TYPE(info) — what kind of relocation to apply</li>
                </ul>
                <p>Relocations live in sections named .rela.text (for code), .rela.data (for data), .rela.dyn (dynamic relocations), and .rela.plt (PLT stubs).</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump">
                    <pre>$ readelf -rW a.o

Relocation section '.rela.text' at offset 0x2a0 contains 3 entries:
  Offset          Info           Type             Sym. Value    Sym. Name + Addend
00000000000c  000500000004   R_X86_64_PLT32    0000000000000000 printf - 4
000000000015  000300000004   R_X86_64_PLT32    0000000000000000 foo - 4
000000000022  000600000002   R_X86_64_PC32     0000000000000000 bar + 0</pre>
                </div>
                <p>This says:</p>
                <ul>
                    <li>At offset 0x0c in .text, patch a 32-bit PC-relative call to printf</li>
                    <li>At offset 0x15 in .text, patch a 32-bit PC-relative call to foo</li>
                    <li>At offset 0x22 in .text, patch a 32-bit PC-relative reference to bar</li>
                </ul>
                <p>After the linker resolves them:</p>
                <div class="hex-dump">
                    <pre>$ objdump -d a.out | grep -A1 "call"
    1125:   e8 b6 ff ff ff          call   10e0 printf@plt
    112e:   e8 4d 00 00 00          call   1180 foo
    1139:   8b 05 c1 00 00 00       mov    eax,rip+0xc1  # bar's value</pre>
                </div>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="hex-dump"><pre># See relocations in an object file
# reloc_test.c: calls an external global variable
gcc -c reloc_test.c
readelf -rW reloc_test.o

# See relocations in a final executable
gcc reloc_test.c -o reloc_test
readelf -rW reloc_test | head -20</pre></div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>What is the purpose of the r_addend field in Elf64_Rela?</p>
                <div class="quiz" id="quiz-re-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-re-1', this, false)">It stores the symbol index</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-re-1', this, true)">It's an extra constant added to the computed relocation value</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-re-1', this, false)">It stores the size of the symbol</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Why are most modern systems using Elf64_Rela instead of Elf64_Rel?</p>
                <div class="quiz" id="quiz-re-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-re-2', this, false)">Rela is smaller</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-re-2', this, true)">The addend is stored in the relocation entry itself, not pre-patched into the target location — cleaner for position-independent code</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-re-2', this, false)">Rel supports more relocation types</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Each relocation entry specifies a type that determines how the patched value is computed. The next concept covers the different relocation types and when each one is used.</p>
            </div>

            <nav class="toc" id="toc">
                <div class="toc-title">On this page</div>
                <ul class="toc-list" id="toc-list"></ul>
            </nav>
            <button class="back-to-top" id="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" aria-label="Back to top">↑ Top</button>
        </div>
    }

    #css {
        .lesson { max-width: 800px; margin: 0 auto; padding: 2rem; font-family: system-ui, sans-serif; }
        .unit { margin-bottom: 2rem; padding: 1.5rem; border-radius: 8px; border-left: 4px solid; }
        .unit-why { border-color: #3b82f6; background: #eff6ff; }
        .unit-model { border-color: #059669; background: #ecfdf5; }
        .unit-reality { border-color: #d97706; background: #fffbeb; }
        .unit-example { border-color: #8b5cf6; background: #f5f3ff; }
        .unit-interact { border-color: #ec4899; background: #fdf2f8; }
        .unit-retrieve { border-color: #06b6d4; background: #ecfeff; }
        .unit-apply { border-color: #f97316; background: #fff7ed; }
        .unit-connect { border-color: #10b981; background: #ecfdf5; }
        h1 { font-size: 1.5rem; margin-bottom: 1rem; }
        h2 { font-size: 1.1rem; margin-bottom: 0.75rem; }
        .hex-dump { background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; font-family: monospace; overflow-x: auto; }
        .quiz { margin-top: 1rem; }
        .quiz-option { display: block; width: 100%; padding: 0.75rem 1rem; margin: 0.5rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; text-align: left; }
        .quiz-option:hover { border-color: #3b82f6; }
        .quiz-option.correct { border-color: #059669; background: #ecfdf5; }
        .quiz-option.wrong { border-color: #dc2626; background: #fef2f2; }
        table { width: 100%; border-collapse: collapse; margin: 1rem 0; }
        th, td { padding: 0.5rem; border: 1px solid #d1d5db; text-align: left; }
        th { background: #f9fafb; font-weight: 600; }
        ul, ol { margin: 0.5rem 0; padding-left: 1.5rem; }
        li { margin-bottom: 0.25rem; }
        pre { background: #f3f4f6; padding: 1rem; border-radius: 6px; overflow-x: auto; }
        code { font-family: ui-monospace, monospace; font-size: 0.9em; }
        .toc { position: sticky; top: 2rem; padding: 1rem; border: 1px solid #e5e7eb; border-radius: 8px; background: #f9fafb; margin-bottom: 1.5rem; }
        .toc-title { font-weight: 600; font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.05em; color: #6b7280; margin-bottom: 0.5rem; }
        .toc-list { list-style: none; padding: 0; margin: 0; }
        .toc-list li { margin-bottom: 0.25rem; }
        .toc-list a { color: #374151; text-decoration: none; font-size: 0.85rem; display: block; padding: 0.2rem 0.5rem; border-radius: 4px; }
        .toc-list a:hover { background: #e5e7eb; }
        .back-to-top { position: fixed; bottom: 2rem; right: 2rem; padding: 0.6rem 1rem; background: #1f2937; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 0.85rem; opacity: 0; transition: opacity 0.3s; pointer-events: none; z-index: 50; }
        .back-to-top.visible { opacity: 1; pointer-events: auto; }
        .back-to-top:hover { background: #111827; }
    }

    #js {
        function checkQuiz(quizId, btn, correct) {
            var quiz = document.getElementById(quizId);
            var options = quiz.querySelectorAll('.quiz-option');
            var feedback = quiz.querySelector('.quiz-feedback');
            for(var i = 0; i < options.length; i++) { options[i].disabled = true; }
            if(correct) {
                btn.classList.add('correct');
                feedback.textContent = 'Correct!';
                feedback.style.color = '#059669';
            } else {
                btn.classList.add('wrong');
                feedback.textContent = 'Not quite. Try again next time.';
                feedback.style.color = '#dc2626';
            }
        }

        (function() {
            var btn = document.getElementById('back-to-top');
            window.addEventListener('scroll', function() {
                if(window.scrollY > 300) { btn.classList.add('visible'); }
                else { btn.classList.remove('visible'); }
            });
            var tocList = document.getElementById('toc-list');
            var headings = document.querySelectorAll('.lesson h2');
            for(var i = 0; i < headings.length; i++) {
                var h = headings[i];
                var id = 'section-' + i;
                h.id = id;
                var li = document.createElement('li');
                var a = document.createElement('a');
                a.href = '#' + id;
                a.textContent = h.textContent;
                li.appendChild(a);
                tocList.appendChild(li);
            }
        })();
    }

    return page.toString()
}
}
