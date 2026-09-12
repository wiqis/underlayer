// ELF Course — Concept 9: Memory Mapping
// How the loader maps file offsets to virtual addresses.
using std::string
using std::string_view

public func render_memory_mapping() : string {
    var page = HtmlPage()
    page.default_prepare()
    var title = std::string_view("Memory Mapping — Underlayer")
    page.append_title(&title)

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
                <p>If a PT_LOAD segment has p_offset=0x1000, p_vaddr=0x2000, and p_filesz=0x500, what virtual address does file offset 0x1200 map to?</p>
                <div class="quiz" id="quiz-mm-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-mm-1', this, false)">0x1200</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-mm-1', this, true)">0x2200</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-mm-1', this, false)">0x3200</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>0x2200 = 0x1200 - 0x1000 + 0x2000</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Program headers describe segments for the loader. But what about the section header table — how do sections relate to segments? That's next.</p>
            </div>
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
        .unit-connect { border-color: #10b981; background: #ecfdf5; }
        h1 { font-size: 1.5rem; margin-bottom: 1rem; }
        h2 { font-size: 1.1rem; margin-bottom: 0.75rem; }
        .hex-dump { background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; font-family: monospace; }
        .quiz { margin-top: 1rem; }
        .quiz-option { display: block; width: 100%; padding: 0.75rem 1rem; margin: 0.5rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; text-align: left; }
        .quiz-option:hover { border-color: #3b82f6; }
        .quiz-option.correct { border-color: #059669; background: #ecfdf5; }
        .quiz-option.wrong { border-color: #dc2626; background: #fef2f2; }
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
    }
    return page.to_string()
}
