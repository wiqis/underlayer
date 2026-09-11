# Pedagogy to Implementation Bridge

Maps each teaching component from the catalog to its Chemical `#html`/`#css`/`#js` implementation pattern. Load this when translating a pedagogical design into Chemical code.

---

## Content Components

### Paragraph

**Pedagogy:** Prose text explaining a concept.

**Implementation:**
```chemical
#html {
    <p>Every ELF file starts with a header that tells the system how to interpret the rest of the file.</p>
}
```

### Heading

**Pedagogy:** Section header for structure.

**Implementation:**
```chemical
#html {
    <h2>Why This Matters</h2>
}
```

### Callout (Note, Tip, Warning, Danger)

**Pedagogy:** Highlighted info that breaks the reading flow.

**Implementation:**
```chemical
#html {
    <div class="callout callout-note">
        <strong>Note:</strong> This is a simplified model. The actual behavior is more complex — we'll cover that next.
    </div>
}

#css {
    .callout { padding: 1rem; border-radius: 6px; margin: 1rem 0; border-left: 3px solid; }
    .callout-note { background: #eff6ff; border-color: #2563eb; }
    .callout-tip { background: #ecfdf5; border-color: #059669; }
    .callout-warning { background: #fffbeb; border-color: #d97706; }
    .callout-danger { background: #fef2f2; border-color: #dc2626; }
}
```

### Definition

**Pedagogy:** Term + meaning for new terminology.

**Implementation:**
```chemical
#html {
    <dl>
        <dt>Virtual Address</dt>
        <dd>The memory address as seen by the process, before translation by the MMU. The ELF specification defines this in gABI §4.3.</dd>
    </dl>
}
```

### Table

**Pedagogy:** Structured data display (field layouts, comparisons).

**Implementation:**
```chemical
#html {
    <table>
        <thead>
            <tr><th>Field</th><th>Offset</th><th>Size</th><th>Description</th></tr>
        </thead>
        <tbody>
            <tr><td>e_ident</td><td>0</td><td>16</td><td>Magic + class + data encoding</td></tr>
            <tr><td>e_type</td><td>16</td><td>2</td><td>Object file type</td></tr>
        </tbody>
    </table>
}

#css {
    table { width: 100%; border-collapse: collapse; margin: 1rem 0; }
    th, td { padding: 0.5rem; border: 1px solid var(--border); text-align: left; }
    th { background: var(--bg-muted); font-weight: 600; }
}
```

### Image

**Pedagogy:** Diagrams, screenshots.

**Implementation:**
```chemical
#html {
    <figure>
        <img src="assets/images/elf-layout.svg" alt="ELF file layout showing header, program headers, and sections" />
        <figcaption>Figure 1: ELF file structure — header at offset 0, followed by program headers and sections.</figcaption>
    </figure>
}
```

---

## Code Components

### CodeBlock (Static Code)

**Pedagogy:** Show code examples, struct definitions.

**Implementation:**
```chemical
#html {
    <div class="code-block">
        <pre><code>struct Elf64_Ehdr {
    unsigned char e_ident[EI_NIDENT];  // 16 bytes
    Elf64_Half    e_type;               // 2 bytes
    Elf64_Half    e_machine;            // 2 bytes
    Elf64_Word    e_version;            // 4 bytes
    Elf64_Addr    e_entry;              // 8 bytes (64-bit)
};</code></pre>
    </div>
}

#css {
    .code-block { background: #f5f5f5; padding: 1rem; border-radius: 6px; overflow-x: auto; }
    .code-block pre { margin: 0; font-family: 'JetBrains Mono', monospace; font-size: 0.875rem; }
}
```

### HexDump

**Pedagogy:** Show binary data with byte-level detail.

**Implementation:**
```chemical
#html {
    <div class="hex-dump">
        <pre>00000000  7f 45 4c 46 02 01 01 00  00 00 00 00 00 00 00 00  |.ELF............|
00000010  03 00 3e 00 01 00 00 00  60 10 40 00 00 00 00 00  |..>.....`.@.....|</pre>
    </div>
}

#css {
    .hex-dump { background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; font-family: monospace; overflow-x: auto; }
}
```

### MemoryLayout

**Pedagogy:** Show stack/heap layout, struct padding.

**Implementation:**
```chemical
#html {
    <div class="memory-layout">
        <div class="mem-row"><span class="mem-addr">0x1000</span><span class="mem-val">7f 45 4c 46</span><span class="mem-label">e_ident (magic)</span></div>
        <div class="mem-row"><span class="mem-addr">0x1010</span><span class="mem-val">02 00</span><span class="mem-label">e_type (ET_EXEC)</span></div>
    </div>
}

#css {
    .memory-layout { font-family: monospace; font-size: 0.875rem; }
    .mem-row { display: flex; gap: 1rem; padding: 0.25rem 0; border-bottom: 1px solid var(--border); }
    .mem-addr { color: var(--text-secondary); width: 6rem; }
    .mem-val { color: var(--primary); width: 10rem; }
}
```

---

## Interactive Components

### Quiz (Multiple Choice)

**Pedagogy:** Quick knowledge check with one correct answer.

**Implementation:**
```chemical
#html {
    <div class="quiz" id="quiz-1">
        <p class="quiz-question">What are the first 4 bytes of an ELF file?</p>
        <div class="quiz-options">
            <button class="quiz-option" onclick="checkQuiz('quiz-1', this, false)">01 02 03 04</button>
            <button class="quiz-option" onclick="checkQuiz('quiz-1', this, true)">7f 45 4c 46</button>
            <button class="quiz-option" onclick="checkQuiz('quiz-1', this, false)">fe ed fa ce</button>
            <button class="quiz-option" onclick="checkQuiz('quiz-1', this, false)">de ad be ef</button>
        </div>
        <div class="quiz-feedback"></div>
    </div>
}

#css {
    .quiz-option { display: block; width: 100%; padding: 0.75rem 1rem; margin: 0.5rem 0; border: 1px solid var(--border); border-radius: 6px; background: var(--surface); cursor: pointer; text-align: left; }
    .quiz-option:hover { border-color: var(--primary); }
    .quiz-option.correct { border-color: var(--success); background: var(--success-light); }
    .quiz-option.wrong { border-color: var(--error); background: var(--error-light); }
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
            feedback.textContent = 'Not quite. The magic number is 7f 45 4c 46.';
            feedback.style.color = '#dc2626';
        }
    }
}
```

### Fill-in-the-Blank

**Pedagogy:** Complete a statement or command (active recall).

**Implementation:**
```chemical
#html {
    <div class="exercise">
        <p>The ELF magic bytes spell <code>.ELF</code> in ASCII. The class byte at offset 4 is <span class="blank" contenteditable="true"></span> for 64-bit files.</p>
        <button onclick="checkBlank(this, '02')">Check</button>
        <span class="blank-feedback"></span>
    </div>
}

#js {
    function checkBlank(btn, correct) {
        var blank = btn.previousElementSibling;
        var feedback = btn.nextElementSibling;
        var value = blank.textContent.trim().toLowerCase();
        if(value === correct) {
            feedback.textContent = 'Correct!';
            feedback.style.color = '#059669';
        } else {
            feedback.textContent = 'Not quite. Try again.';
            feedback.style.color = '#dc2626';
        }
    }
}
```

### Reveal (Progressive Disclosure)

**Pedagogy:** Let learner guess before seeing the answer.

**Implementation:**
```chemical
#html {
    <div class="reveal">
        <p>Without looking back: what field in the ELF header specifies the entry point?</p>
        <button onclick="this.parentElement.classList.add('revealed')">Show Answer</button>
        <div class="reveal-answer">
            <p><code>e_entry</code> — the virtual address where execution begins.</p>
        </div>
    </div>
}

#css {
    .reveal-answer { display: none; margin-top: 0.5rem; padding: 1rem; background: var(--bg-muted); border-radius: 6px; }
    .reveal.revealed .reveal-answer { display: block; }
    .reveal.revealed button { display: none; }
}
```

### Hex Inspector (Clickable Bytes)

**Pedagogy:** Click bytes to identify fields — active exploration.

**Implementation:**
```chemical
#html {
    <div class="hex-interactive">
        <span class="hex-byte" data-field="magic" onclick="selectByte(this)">7f</span>
        <span class="hex-byte" data-field="magic" onclick="selectByte(this)">45</span>
        <span class="hex-byte" data-field="magic" onclick="selectByte(this)">4c</span>
        <span class="hex-byte" data-field="magic" onclick="selectByte(this)">46</span>
        <span class="hex-byte" data-field="class" onclick="selectByte(this)">02</span>
        <span class="hex-byte" data-field="data" onclick="selectByte(this)">01</span>
        <div class="hex-field-label"></div>
    </div>
}

#css {
    .hex-interactive { font-family: monospace; background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; }
    .hex-byte { display: inline-block; width: 2ch; margin-right: 0.5ch; cursor: pointer; border-radius: 2px; }
    .hex-byte:hover { background: rgba(59, 130, 246, 0.3); }
    .hex-byte.selected { background: rgba(59, 130, 246, 0.5); }
    .hex-field-label { margin-top: 0.5rem; font-size: 0.8rem; color: #9ca3af; }
}

#js {
    function selectByte(el) {
        var all = el.parentElement.querySelectorAll('.hex-byte');
        for(var i = 0; i < all.length; i++) { all[i].classList.remove('selected'); }
        el.classList.add('selected');
        var field = el.getAttribute('data-field');
        var label = el.parentElement.querySelector('.hex-field-label');
        if(field === 'magic') { label.textContent = 'e_ident[0..3] — Magic number: 7f 45 4c 46 (.ELF)'; }
        else if(field === 'class') { label.textContent = 'e_ident[4] — Class: 02 (ELF64)'; }
        else if(field === 'data') { label.textContent = 'e_ident[5] — Data encoding: 01 (little-endian)'; }
    }
}
```

---

## Assessment Components

### Debugging Exercise

**Pedagogy:** Find and fix errors in code — tests application-level understanding.

**Implementation:**
```chemical
#html {
    <div class="exercise">
        <h3>Find the bug:</h3>
        <div class="code-block">
            <pre><code>// This parser reads the ELF entry point incorrectly
func read_entry(data : *u8) : u64 {
    return read_u64_le(data, 24)  // Is offset 24 correct?
}</code></pre>
        </div>
        <p>The entry point offset is wrong. What should it be?</p>
        <button class="option" onclick="checkQuiz('debug-1', this, false)">Offset 16 (after e_type)</button>
        <button class="option" onclick="checkQuiz('debug-1', this, true)">Offset 24 (after e_version)</button>
        <button class="option" onclick="checkQuiz('debug-1', this, false)">Offset 32 (after e_phoff)</button>
        <div class="quiz-feedback"></div>
    </div>
}
```

### Ordering Exercise

**Pedagogy:** Put items in correct order — tests sequential understanding.

**Implementation:**
```chemical
#html {
    <div class="exercise">
        <h3>Order these ELF structures by file offset:</h3>
        <div class="order-items" id="order-1">
            <div class="order-item" data-order="3" onclick="toggleOrder(this)">Section Headers</div>
            <div class="order-item" data-order="1" onclick="toggleOrder(this)">ELF Header</div>
            <div class="order-item" data-order="2" onclick="toggleOrder(this)">Program Headers</div>
        </div>
        <button onclick="checkOrder('order-1')">Check Order</button>
    </div>
}

#js {
    function toggleOrder(el) { el.classList.toggle('selected'); }
    function checkOrder(containerId) {
        var items = document.getElementById(containerId).querySelectorAll('.order-item');
        // Check if data-order attributes are in ascending order of selection
        // Implementation depends on selection logic
    }
}
```

---

## Visualization Components

### Diagram (SVG Inline)

**Pedagogy:** Structural visualization — file layout, memory map.

**Implementation:**
```chemical
#html {
    <div class="diagram">
        <svg viewBox="0 0 600 200" xmlns="http://www.w3.org/2000/svg">
            <rect x="0" y="0" width="100" height="200" fill="#3b82f6" opacity="0.2" stroke="#3b82f6" />
            <text x="50" y="100" text-anchor="middle" fill="#3b82f6" font-size="12">ELF Header</text>
            <rect x="110" y="0" width="150" height="200" fill="#059669" opacity="0.2" stroke="#059669" />
            <text x="185" y="100" text-anchor="middle" fill="#059669" font-size="12">Program Headers</text>
            <rect x="270" y="0" width="330" height="200" fill="#d97706" opacity="0.2" stroke="#d97706" />
            <text x="435" y="100" text-anchor="middle" fill="#d97706" font-size="12">Sections + Data</text>
        </svg>
    </div>
}
```

### State Machine

**Pedagogy:** Show state transitions — TLS handshake, linker states.

**Implementation:**
```chemical
#html {
    <div class="state-machine">
        <div class="state active" id="state-init">INIT</div>
        <div class="arrow">→</div>
        <div class="state" id="state-hello">CLIENT_HELLO</div>
        <div class="arrow">→</div>
        <div class="state" id="state-hello-done">SERVER_HELLO</div>
    </div>
}

#css {
    .state-machine { display: flex; align-items: center; gap: 0.5rem; font-family: monospace; }
    .state { padding: 0.5rem 1rem; border: 1px solid var(--border); border-radius: 6px; cursor: pointer; }
    .state.active { border-color: var(--primary); background: var(--primary-light); }
    .arrow { color: var(--text-secondary); }
}
```

---

## Reference Components

### Glossary

**Pedagogy:** Quick reference for terms.

**Implementation:**
```chemical
#html {
    <div class="glossary">
        <dl>
            <dt>ELF</dt><dd>Executable and Linkable Format — the standard binary format on Linux</dd>
            <dt>Section</dt><dd>A grouping of related data (code, data, symbols) used by the linker</dd>
            <dt>Segment</dt><dd>A memory mapping unit used by the loader at runtime</dd>
        </dl>
    </div>
}
```

### Comparison Table

**Pedagogy:** Side-by-side comparison.

**Implementation:**
```chemical
#html {
    <div class="comparison">
        <div class="comparison-side">
            <h4>Sections (Linker View)</h4>
            <ul>
                <li>Used by the linker</li>
                <li>.text, .data, .bss, .symtab</li>
                <li>Can be stripped without breaking execution</li>
            </ul>
        </div>
        <div class="comparison-side">
            <h4>Segments (Loader View)</h4>
            <ul>
                <li>Used by the loader</li>
                <li>PT_LOAD, PT_DYNAMIC, PT_INTERP</li>
                <li>Required for execution</li>
            </ul>
        </div>
    </div>
}
```

---

## Key Rules

1. **Use `onclick="fn(args)"`** (HTML string), NOT `onclick={fn(args)}` (JSX syntax)
2. **Use `@{}` for Chemical logic** inside `#html` blocks, re-enter HTML with nested `#html { }`
3. **Never split an HTML element** across `#html` blocks
4. **Keep JS minimal** — only for quiz checking, hex interaction, toggles, simple animations
5. **Use CSS variables** from the design system (`var(--primary)`, `var(--border)`, etc.)
6. **Every interactive element needs feedback** — never just "wrong", explain why
