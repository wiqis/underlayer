// ELF Course — Concept 9: Memory Mapping
// How the loader maps file offsets to virtual addresses.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_memory_mapping() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Memory Mapping — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>Memory Mapping</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Understanding how file offsets become virtual addresses is essential for debugging. When you see a crash at address 0x401234, you need to know which part of the file that corresponds to — and that requires understanding memory mapping.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The loader uses <code>mmap()</code> to map file segments into memory. For each PT_LOAD segment, it maps the file region [p_offset, p_offset + p_filesz] to virtual address [p_vaddr, p_vaddr + p_memsz]. The file offset and virtual address are related by:</p>
                <p><code>virtual_address = file_offset - p_offset + p_vaddr</code></p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The alignment (p_align) affects how mapping works. For p_align = 0x1000 (4KB, typical page size):</p>
                <ul>
                    <li>The file offset and virtual address must be congruent modulo p_align</li>
                    <li>The kernel rounds down to page boundaries</li>
                    <li>Multiple sections can share one segment (and one page)</li>
                </ul>
                <p>For example, .init, .plt, and .text might all be in the same PT_LOAD segment with R-X permissions.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump">
                    <pre>File:                          Memory:
Offset  Section               VirtAddr  Section
0x0000  ELF header            0x1000    (within first page)
0x0040  .init, .plt           0x1040    .init
0x1000  .text                 0x2000    .text
0x3000  .rodata               0x4000    .rodata
0x3dc0  .data, .bss           0x4dc0    .data</pre>
                </div>
                <p>The .text section at file offset 0x1000 maps to virtual address 0x2000. The formula: 0x2000 = 0x1000 - 0x1000 + 0x2000.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>A segment has p_offset=0x1000, p_vaddr=0x2000. File offset 0x1200 maps to what virtual address?</p>
                <div class="quiz" id="quiz-mm-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-mm-1', this, false)">0x1200</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-mm-1', this, true)">0x2200</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-mm-1', this, false)">0x3200</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>0x2200 = 0x1200 - 0x1000 + 0x2000</em></p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Two PT_LOAD segments overlap in virtual address space. What happens?</p>
                <div class="quiz" id="quiz-mm-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-mm-2', this, false)">The kernel rejects the binary</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-mm-2', this, false)">The second segment overwrites the first</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-mm-2', this, true)">It's allowed — the linker ensures non-overlapping alignments</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Program headers describe segments for the loader. But what about the section header table — how do sections relate to segments? That's next.</p>
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
        .unit-retrieve { border-color: #06b6d4; background: #ecfeff; }
        .unit-apply { border-color: #f97316; background: #fff7ed; }
        .unit-connect { border-color: #10b981; background: #ecfdf5; }
        h1 { font-size: 1.5rem; margin-bottom: 1rem; }
        h2 { font-size: 1.1rem; margin-bottom: 0.75rem; }
        .hex-dump { background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; font-family: monospace; }
        .quiz { margin-top: 1rem; }
        .quiz-option { display: block; width: 100%; padding: 0.75rem 1rem; margin: 0.5rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; text-align: left; }
        .quiz-option:hover { border-color: #3b82f6; }
        .quiz-option.correct { border-color: #059669; background: #ecfdf5; }
        .quiz-option.wrong { border-color: #dc2626; background: #fef2f2; }
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
            if(correct) { btn.classList.add('correct'); feedback.textContent = 'Correct!'; feedback.style.color = '#059669'; }
            else { btn.classList.add('wrong'); feedback.textContent = 'Not quite.'; feedback.style.color = '#dc2626'; }
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
