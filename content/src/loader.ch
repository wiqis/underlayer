// ELF Course — Concept 22: The Kernel Loader
// How execve() maps ELF segments into memory — PT_LOAD segments and the mmap syscall.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_loader() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Kernel Loader — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>The Kernel Loader</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>When you type <code>./myprog</code>, the kernel reads the ELF header, creates the process, and maps your code into memory — all before a single instruction of yours runs. Understanding the kernel loader explains why some ELF files are executable and others aren't, why you can't run a 32-bit binary on a 64-bit kernel without multilib, and how ASLR randomizes your program's memory layout.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The kernel's ELF loading process has three steps:</p>
                <ol>
                    <li><strong>Validate</strong> — Read ELF header, check magic number, verify architecture matches</li>
                    <li><strong>Map</strong> — For each PT_LOAD segment, mmap() it into the process at the specified virtual address</li>
                    <li><strong>Set up</strong> — Process PT_INTERP (dynamic linker), set up stack with argc/argv/envp, apply ASLR offsets</li>
                </ol>
                <p>The key insight: the kernel doesn't understand relocations or symbols. It only maps raw bytes. The dynamic linker (ld.so) does the real setup work.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Each PT_LOAD segment specifies a virtual address range, file offset, and permissions:</p>
                <div class="hex-dump">
                    <pre># Elf64_Phdr structure (56 bytes):
#   p_type   (Elf64_Word)   PT_LOAD (1)
#   p_flags  (Elf64_Word)   PF_R (4), PF_W (2), PF_X (1)
#   p_offset (Elf64_Off)    Offset in file
#   p_vaddr  (Elf64_Addr)   Virtual address to map
#   p_paddr  (Elf64_Addr)   Physical address (usually = vaddr)
#   p_filesz (Elf64_Xword)  Size in file
#   p_memsz  (Elf64_Xword)  Size in memory (more than p_filesz, BSS is zero-filled)
#   p_align  (Elf64_Xword)  Alignment (usually page size)</pre>
                </div>
                <p>Typical PT_LOAD segments:</p>
                <ul>
                    <li><strong>Code segment</strong> — p_flags = PF_R | PF_X (read-execute, no write), contains .text and .rodata</li>
                    <li><strong>Data segment</strong> — p_flags = PF_R | PF_W (read-write), contains .data and .bss</li>
                </ul>
                <p>The kernel calls mmap() for each segment, which is how shared libraries can share their code pages across processes — they're mapped read-only and marked copy-on-write.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump">
                    <pre>$ readelf -l /bin/ls

Elf file type is DYN (Position-Executable)
Entry point 0x5a40
Program Headers:
  Type   Offset   VirtAddr           PhysAddr           FileSiz  MemSiz   Flg
  PHDR   0x000040 0x0000000000000040 0x0000000000000040 0x0002d8 0x0002d8 R E
  INTERP 0x000318 0x0000000000000318 0x0000000000000318 0x00001c 0x00001c R
  LOAD   0x000000 0x0000000000000000 0x0000000000000000 0x004000 0x004000 R E
  LOAD   0x004000 0x0000000000004000 0x0000000000004000 0x001a00 0x001a00 R
  LOAD   0x006000 0x0000000000006000 0x0000000000006000 0x001200 0x001200 R E
  LOAD   0x008000 0x0000000000008000 0x0000000000008000 0x000600 0x000600 R
  LOAD   0x009000 0x0000000000009000 0x0000000000009000 0x000200 0x000200 RW
  LOAD   0x00a000 0x000000000000b000 0x000000000000b000 0x000200 0x000200 RW</pre>
                </div>
                <p>Notice the gaps: LOAD segments are page-aligned (0x1000 = 4KB), so the file and memory offsets may differ. The kernel only maps the portions it needs.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="hex-dump"><pre># See program headers (kernel loading info)
readelf -l /bin/ls

# See which segments are executable
readelf -l /bin/ls | grep LOAD

# Compare static vs dynamic entry points
readelf -l static_binary | grep Entry
# Entry point = 0x400xxx (direct entry into main)

readelf -l dynamic_binary | grep Entry
# Entry point = 0x5xxx (ld.so entry point)

# Check if ASLR is enabled
cat /proc/sys/kernel/randomize_va_space
# 0 = disabled, 1 = stack+mmap, 2 = full (default)</pre></div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Why are PT_LOAD segments mapped page-aligned, even if the file data doesn't fill the whole page?</p>
                <div class="quiz" id="quiz-kl-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-kl-1', this, false)">Because the kernel always allocates full pages</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-kl-1', this, true)">The memory management unit (MMU) operates in pages — partial pages would waste memory or require special handling</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-kl-1', this, false)">Because ELF files must be 4KB-aligned</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>If a PT_LOAD segment has p_flags = PF_R | PF_X but your code writes to a global variable in that segment, what happens?</p>
                <div class="quiz" id="quiz-kl-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-kl-2', this, false)">It works fine because the kernel doesn't check permissions</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-kl-2', this, true)">The program crashes with a segfault — the MMU enforces page permissions and the write triggers a protection fault</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-kl-2', this, false)">The kernel silently ignores the write</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The kernel maps ELF segments into memory at specific virtual addresses. But what does the final memory layout look like — where are the stack, heap, and mmap regions? That's the next concept.</p>
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
        ul, ol { margin: 0.5rem 0; padding-left: 1.5rem; }
        li { margin-bottom: 0.25rem; }
        pre { background: #f3f4f6; padding: 1rem; border-radius: 6px; overflow-x: auto; }
        code { font-family: ui-monospace, monospace; font-size: 0.9em; }
    }

    #js {
        function __ul_ctx() {
            var parts = window.location.pathname.split('/').filter(function(p) { return p.length > 0; });
            if (parts.length >= 4) {
                if (parts[0] === 'courses') {
                    if (parts[2] === 'lessons') {
                        return { course: parts[1], concept: parts[3] };
                    }
                }
            }
            return null;
        }
        function __ul_token() {
            var t = '';
            try { t = localStorage.getItem('session_token') || ''; } catch (e) { t = ''; }
            return t;
        }
        function __ul_report_attempt(correct) {
            var ctx = __ul_ctx();
            if (!ctx) { return; }
            var t = __ul_token();
            if (!t) { return; }
            var rating = 'again';
            if (correct) { rating = 'good'; }
            var url = '/api/review/submit?concept_id=' + encodeURIComponent(ctx.concept) + '&course_id=' + encodeURIComponent(ctx.course) + '&rating=' + rating;
            try { fetch(url, { method: 'POST', headers: { 'Authorization': 'Bearer ' + t } }).catch(function() {}); } catch (e) {}
        }
        function __ul_report_view() {
            var ctx = __ul_ctx();
            if (!ctx) { return; }
            var t = __ul_token();
            if (!t) { return; }
            try {
                fetch('/api/learning/view', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + t },
                    body: JSON.stringify({ course_id: ctx.course, concept_id: ctx.concept })
                }).catch(function() {});
            } catch (e) {}
        }
        document.addEventListener('DOMContentLoaded', function() { __ul_report_view(); });
        document.addEventListener('click', function(ev) {
            var el = ev.target;
            while (el && el !== document && !(el.classList && el.classList.contains('quiz-option'))) { el = el.parentNode; }
            if (!el || el === document) { return; }
            setTimeout(function() { __ul_report_attempt(el.classList.contains('correct')); }, 80);
        }, true);
        document.addEventListener('change', function(ev) {
            var el = ev.target;
            if (!el || !el.classList) { return; }
            var isBlank = el.classList.contains('fill-blank');
            var isSelect = el.classList.contains('app-select');
            if (!isBlank && !isSelect) { return; }
            var ans = el.getAttribute('data-answer');
            if (!ans) { ans = el.getAttribute('data-correct'); }
            if (!ans) { return; }
            var val = '';
            if (el.value) { val = el.value; }
            val = val.trim();
            __ul_report_attempt(val === ans);
        }, true);
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
    }

    return page.toString()
}
}
