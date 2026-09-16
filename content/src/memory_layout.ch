// ELF Course — Concept 23: Process Memory Layout
// Where .text, .data, .bss, heap, and stack live in a running process.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_memory_layout() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Process Memory Layout — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>Process Memory Layout</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Understanding where your code, data, and stack live in memory is critical for debugging. When you see a crash at address 0x7ffd..., you know it's on the stack. When you see 0x55555..., it's in your code segment. A core dump shows you each of these regions — knowing the layout tells you what went wrong.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>A 64-bit Linux process looks like this in memory (addresses grow upward):</p>
                <div class="hex-dump"><pre>High address (0x7fff...)
┌─────────────────────┐
│         Stack       │  ← argc, argv, envp, local variables
│         ↓           │     (grows downward)
│                     │
│         ↑           │
│         Heap        │  ← malloc() allocations (grows upward)
├─────────────────────┤
│    mmap region      │  ← shared libraries, mmap() allocations
│         ↓           │
├─────────────────────┤
│    .bss             │  ← zero-initialized globals
│    .data            │  ← initialized globals
│    .rodata          │  ← read-only data (string literals)
│    .text            │  ← your compiled code (executable)
└─────────────────────┘
Low address (0x5555...)</pre></div>
                <p>The stack and heap grow toward each other but rarely collide (the stack is usually limited to 8MB by default).</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>You can inspect the actual layout of any running process:</p>
                <div class="hex-dump"><pre># See your own process's memory map
cat /proc/self/maps
# Output:
# 555555554000-555555555000 r--p 00000000 08:01 123456  /usr/bin/cat
# 555555555000-555555556000 r-xp 00001000 08:01 123456  /usr/bin/cat
# 555555556000-555555557000 r--p 00002000 08:01 123456  /usr/bin/cat
# 555555557000-555555558000 rw-p 00003000 08:01 123456  /usr/bin/cat
# ...
# 7ffd12345000-7ffd12367000 rw-p 00000000 00:00 0       [stack]

# Read the ELF section-to-memory mapping
readelf -l /bin/ls | grep -E "LOAD|GNU_RELRO"</pre></div>
                <p>Key regions from the ELF perspective:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Region</th><th scope="col">Permission</th><th scope="col">Source</th><th scope="col">Purpose</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>.text</td><td>r-x (read-execute)</td><td>PT_LOAD (code segment)</td><td>Machine code</td></tr>
                        <tr><td>.rodata</td><td>r-- (read-only)</td><td>PT_LOAD (code segment)</td><td>String literals, constants</td></tr>
                        <tr><td>.data</td><td>rw- (read-write)</td><td>PT_LOAD (data segment)</td><td>Initialized globals</td></tr>
                        <tr><td>.bss</td><td>rw- (read-write)</td><td>PT_LOAD (data segment, memsz larger than filesz)</td><td>Zero-initialized globals</td></tr>
                        <tr><td>heap</td><td>rw- (read-write)</td><td>mmap by brk()</td><td>malloc() allocations</td></tr>
                        <tr><td>stack</td><td>rw- (read-write)</td><td>mmap by kernel</td><td>Local vars, function frames</td></tr>
                    </tbody>
                </table>
                <p>The .bss region is special: p_filesz = 0 but p_memsz is nonzero. The kernel allocates memory for it but doesn't read from the file — it's always zero-initialized. This saves file space.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump"><pre># mem_layout.c -- compile with: gcc -o mem_layout mem_layout.c
# global_init = 42       -- stored in .data
# global_uninit          -- stored in .bss (zero-initialized)
# ro = "hello"           -- pointer in .data, string in .rodata
#
# In main():
#   local_var            -- on the stack
#   heap_var = malloc()  -- on the heap (just above .bss)
#   data_ptr = &amp;global_init   -- .data segment
#   bss_ptr = &amp;global_uninit  -- .bss segment
#   stack_ptr = &amp;local_var    -- stack

$ ./mem_layout
text:     0x555555555149      -- code (low address)
rodata:   0x555555556004      -- read-only data
data:     0x555555558010      -- initialized globals
bss:      0x555555558014      -- zero-initialized globals
heap:     0x5555555592a0      -- malloc (just above .bss)
stack:    0x7ffd...f3c        -- stack (high address, grows down)</pre></div>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="hex-dump"><pre># See your program's memory layout
cat /proc/self/maps | head -20

# Find the text segment (look for r-xp)
cat /proc/$$/maps | grep r-xp

# Find the stack
cat /proc/$$/maps | grep stack

# Check stack size limit
ulimit -s
# Default: 8192 KB (8 MB)</pre></div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Why does the .bss segment save file space compared to .data?</p>
                <div class="quiz" id="quiz-ml-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-ml-1', this, false)">.bss uses a more efficient encoding</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ml-1', this, true)">.bss doesn't store data in the file at all — the kernel allocates zero-filled memory at load time, so p_filesz = 0 but p_memsz is nonzero</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ml-1', this, false)">.bss is compressed in the ELF file</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You see a crash at address 0x7ffd4a3b2100. Based on the memory layout, where is this likely?</p>
                <div class="quiz" id="quiz-ml-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-ml-2', this, false)">In the .text segment (code)</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ml-2', this, true)">On the stack — addresses in the 0x7ffd... range are in the mmap/stack region, far above the code/data segments</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ml-2', this, false)">In the .bss segment</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You know the memory layout. The final concept covers the complete startup sequence — from when ld.so finishes to when your main() function actually runs.</p>
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
        table { width: 100%; border-collapse: collapse; margin: 1rem 0; }
        th, td { padding: 0.5rem; border: 1px solid #d1d5db; text-align: left; }
        th { background: #f9fafb; font-weight: 600; }
        ul { margin: 0.5rem 0; padding-left: 1.5rem; }
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
