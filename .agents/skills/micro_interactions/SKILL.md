# Micro-Interactions Skill — Underlayer

Tiny UI features that make the learning platform feel polished and helpful. Every detail matters.

---

## Chemical Implementation Note

All examples in this document use raw HTML/CSS for readability. **In the actual codebase**, these are written inside Chemical `.ch` files using `#html`, `#css`, and `#js` macros:

```chemical
#html {
    <span class="info-trigger" data-info="virt_addr_def">
        Virtual Address Space
        <span class="info-icon">i</span>
    </span>
}

#css {
    .info-trigger { border-bottom: 1px dotted var(--text-muted); cursor: help; }
    .info-icon { display: inline-flex; width: 16px; height: 16px; }
}

#js {
    // JS functions referenced by onclick handlers
}
```

Key rules:
- `onclick="fn(args)"` — use HTML string syntax, NOT JSX `{fn(args)}` syntax
- `@{}` to escape to Chemical logic inside `#html` blocks, re-enter HTML with nested `#html { }`
- Never split an HTML element across `#html` blocks
- CSS variables from `docs/ui-ux-design.md` (e.g. `var(--primary)`, `var(--border)`)
- See `docs/pedagogy-to-implementation.md` for component→macro mapping

---

## Quick Reference

| Category | Features | Count |
|----------|----------|-------|
| Information | Info button, scope badge, verification badge, simplification marker, breadcrumbs | 5 |
| Feedback | Correct/wrong animation, toast, success/error, progress fill, celebration | 5 |
| Navigation | Keyboard shortcuts, jump-to menu, recent activity, quick actions, back-to-top | 5 |
| Content | Copy code, bookmark, highlight, notes, hex hover | 5 |
| Visual | Skeleton, staggered entry, toggle animation, button press, focus ring | 5 |
| Accessibility | Reduced motion, high contrast, font size, skip links, screen reader | 5 |
| State | Dark mode, offline indicator, sync status, auto-save, undo/redo | 5 |
| **Total** | | **35** |

---

## 1. Info Button (i) System

### The Pattern
Every simplification, jargon term, and scope change has a small `(i)` button that reveals context on hover or click.

```
Virtual Address Space (i)
    ┌─────────────────────────────────────────┐
    │ The memory layout as seen by the process │
    │ (differs from physical addresses)        │
    │ Source: gABI §4.3                        │
    └─────────────────────────────────────────┘
```

### Info Types
| Type | Icon | Content | Example |
|------|------|---------|---------|
| Definition | (i) | Formal definition | "Virtual address = address as seen by the process" |
| Source | 📄 | Reference link | "gABI §4.3 — Program Headers" |
| Context | 💡 | Why this matters | "This is why position-independent code uses relative addressing" |
| Scope | 🔬 | Depth level | "This is a surface explanation. Click to go deeper." |

### Implementation
```html
<span class="info-trigger" data-info="virt_addr_def">
  Virtual Address Space
  <span class="info-icon">i</span>
</span>

<div class="info-tooltip" id="virt_addr_def">
  <p class="info-definition">The memory layout as seen by the process.</p>
  <a href="https://github.com/ghaiklor/elf-papers/blob/master/gabi.pdf#page=45" class="info-source">
    📄 gABI §4.3
  </a>
</div>
```

### CSS
```css
.info-trigger { border-bottom: 1px dotted var(--text-muted); cursor: help; }
.info-icon {
  display: inline-flex; align-items: center; justify-content: center;
  width: 16px; height: 16px; border-radius: 50%;
  background: var(--bg-muted); color: var(--text-muted);
  font-size: 10px; font-style: italic; margin-left: 4px;
}
.info-trigger:hover .info-icon { background: var(--primary); color: white; }
.info-tooltip {
  position: absolute; z-index: 100; max-width: 300px;
  padding: 12px 16px; border-radius: 8px;
  background: var(--bg-elevated); border: 1px solid var(--border);
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  opacity: 0; transform: translateY(4px); transition: all 0.15s ease;
}
.info-trigger:hover .info-tooltip { opacity: 1; transform: translateY(0); }
.info-definition { margin: 0 0 8px; }
.info-source { font-size: 0.85rem; color: var(--primary); }
```

### When to Add Info Buttons
- Every jargon term on first occurrence
- Every simplified concept
- Every scope change (surface → intermediate → deep)
- Every hex dump or byte-level diagram
- Every formula or formula variable

---

## 2. Keyboard Shortcuts

### Global Shortcuts
| Key | Action | Scope |
|-----|--------|-------|
| `→` or `Space` | Next exercise | Lesson |
| `←` | Previous exercise | Lesson |
| `Enter` | Submit answer | Exercise |
| `Cmd/Ctrl+K` | Jump to menu | Global |
| `Cmd/Ctrl+/` | Show shortcuts | Global |
| `Escape` | Close modal/menu | Global |
| `?` | Show help | Lesson |
| `b` | Bookmark current | Lesson |
| `n` | Add note | Lesson |

### Navigation Shortcuts
| Key | Action |
|-----|--------|
| `1`-`9` | Jump to unit 1-9 |
| `r` | Review session |
| `d` | Dashboard |
| `h` | Home |

### Exercise Shortcuts (Type-specific)
| Key | Action |
|-----|--------|
| `1`-`4` | Select multiple choice option |
| `Tab` | Next hex field |
| `Shift+Tab` | Previous hex field |
| `Ctrl+C` | Copy selected bytes |
| `Ctrl+V` | Paste into hex field |

### Implementation Pattern
```javascript
document.addEventListener('keydown', (e) => {
  // Don't trigger if typing in an input
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;

  switch(e.key) {
    case 'ArrowRight': nextExercise(); break;
    case 'ArrowLeft': prevExercise(); break;
    case 'Enter': submitAnswer(); break;
    case 'b': toggleBookmark(); break;
    case 'n': openNoteEditor(); break;
    case 'Escape': closeModal(); break;
  }

  // Cmd/Ctrl+K for jump menu
  if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
    e.preventDefault();
    openJumpMenu();
  }
});
```

### Shortcuts Modal
```
┌─────────────────────────────────────────┐
│  Keyboard Shortcuts                     │
│                                         │
│  Navigation                             │
│  →  Next exercise                       │
│  ←  Previous exercise                   │
│  1-9  Jump to unit                      │
│                                         │
│  Actions                                │
│  Enter  Submit answer                   │
│  b  Bookmark                            │
│  n  Add note                            │
│                                         │
│  Global                                 │
│  Cmd+K  Jump to menu                    │
│  ?  Show this help                      │
│  Esc  Close                             │
└─────────────────────────────────────────┘
```

---

## 3. Toast Notifications

### Toast Types
| Type | Icon | Duration | Example |
|------|------|----------|---------|
| Success | ✓ | 3s | "Answer correct!" |
| Error | ✗ | 5s | "Incorrect. Try again." |
| Info | ℹ | 4s | "Session saved" |
| Warning | ⚠ | 5s | "Weak area detected" |
| Bookmark | 🔖 | 2s | "Bookmarked" |

### Toast Position
Fixed bottom-right, stacked vertically:
```
                    ┌──────────────────┐
                    │ ✓ Saved!         │  ← newest
                    └──────────────────┘
              ┌──────────────────────────┐
              │ 🔖 Bookmarked lesson 3.2 │  ← older
              └──────────────────────────┘
```

### Animation
```css
.toast {
  position: fixed; bottom: 24px; right: 24px;
  padding: 12px 20px; border-radius: 8px;
  background: var(--bg-elevated); border: 1px solid var(--border);
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  animation: toast-in 0.3s ease, toast-out 0.3s ease 2.7s forwards;
}
@keyframes toast-in {
  from { opacity: 0; transform: translateY(20px) scale(0.95); }
  to { opacity: 1; transform: translateY(0) scale(1); }
}
@keyframes toast-out {
  from { opacity: 1; transform: translateY(0) scale(1); }
  to { opacity: 0; transform: translateY(-10px) scale(0.95); }
}
.toast-success { border-left: 3px solid #22c55e; }
.toast-error { border-left: 3px solid #ef4444; }
.toast-info { border-left: 3px solid #3b82f6; }
```

---

## 4. Progress Indicators

### Unit Progress Bar
Each unit has a thin progress bar below the unit card:
```
┌─────────────────────────────────────────┐
│ Unit 3: ELF Headers                     │
│ ████░░░░░░░░░░░░░░░░ 40% (2/5 lessons) │
└─────────────────────────────────────────┘
```

### Lesson Progress Bar
Horizontal bar at top of lesson:
```
┌─────────────────────────────────────────┐
│ ████░░░░░░░░░░░░░░░░░░░░░░░░░░░  40%  │
└─────────────────────────────────────────┘
│                                         │
│ Exercise 3 of 8                         │
│ What is the magic number in the ELF     │
│ header?                                 │
│                                         │
│  ○ 7f 45 4c 46                          │
│  ○ 01 02 03 04                          │
│  ○ fe ed fa ce                          │
│  ○ de ad be ef                          │
│                                         │
└─────────────────────────────────────────┘
```

### Fill Animation
```css
.progress-bar {
  height: 4px; background: var(--bg-muted); border-radius: 2px; overflow: hidden;
}
.progress-fill {
  height: 100%; background: var(--primary); border-radius: 2px;
  transition: width 0.4s ease;
}
.progress-fill.animate {
  animation: progress-pulse 0.6s ease;
}
@keyframes progress-pulse {
  0% { opacity: 1; }
  50% { opacity: 0.7; }
  100% { opacity: 1; }
}
```

### Overall Progress (Dashboard)
Circular progress indicator:
```
    ┌─────────┐
    │   42%   │  ← percentage in center
    │  ████   │  ← circular arc
    │  █  █   │
    └─────────┘
    3 of 7 units
```

---

## 5. Celebration Micro-Interactions

### Correct Answer
```css
@keyframes correct-bounce {
  0% { transform: scale(1); }
  30% { transform: scale(1.05); }
  60% { transform: scale(0.98); }
  100% { transform: scale(1); }
}
.exercise-correct {
  animation: correct-bounce 0.4s ease;
  border-color: #22c55e;
  box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.2);
}
```

### Unit Complete
```
┌─────────────────────────────────────────┐
│                                         │
│           ✓ Unit 3 Complete!            │
│                                         │
│     Accuracy: 87%                       │
│     Time: 12 min                        │
│     CLSI: 0.72                          │
│                                         │
│     [Next Unit →]                       │
│                                         │
└─────────────────────────────────────────┘
```

### Course Complete
Confetti animation (CSS-only):
```css
@keyframes confetti-fall {
  0% { transform: translateY(-100vh) rotate(0deg); opacity: 1; }
  100% { transform: translateY(100vh) rotate(720deg); opacity: 0; }
}
.confetti-piece {
  position: fixed; width: 10px; height: 10px;
  background: var(--primary); border-radius: 2px;
  animation: confetti-fall 3s ease-in forwards;
}
```

---

## 6. Skeleton Loading

### Skeleton Patterns
| Element | Skeleton |
|---------|----------|
| Unit card | Gray rectangle + animated pulse |
| Exercise | Gray boxes for question + options |
| Hex viewer | Gray grid of hex cells |
| Text paragraph | 3 gray lines of varying width |

### Animation
```css
.skeleton {
  background: linear-gradient(90deg, var(--bg-muted) 25%, var(--bg-hover) 50%, var(--bg-muted) 75%);
  background-size: 200% 100%;
  animation: skeleton-shimmer 1.5s ease-in-out infinite;
  border-radius: 4px;
}
@keyframes skeleton-shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
.skeleton-text { height: 16px; margin-bottom: 8px; }
.skeleton-text:last-child { width: 60%; }
.skeleton-hex { width: 32px; height: 32px; display: inline-block; margin: 2px; }
```

### Skeleton Layouts
```
Unit Card Skeleton:
┌─────────────────────────────────────────┐
│ ██████████████████████████  (title)     │
│ ████████████████████  (description)     │
│ ████░░░░░░░░░░░░░░░░  (progress)       │
└─────────────────────────────────────────┘

Exercise Skeleton:
┌─────────────────────────────────────────┐
│ ████████████████████████████████████    │
│ ████████████████████████  (question)    │
│                                         │
│ ████████████████████████  (option 1)    │
│ ████████████████████████  (option 2)    │
│ ████████████████████████  (option 3)    │
│ ████████████████████████  (option 4)    │
└─────────────────────────────────────────┘
```

---

## 7. Copy Code Button

### Pattern
Every code block, hex dump, and command gets a copy button:
```
┌─────────────────────────────────────────┐
│ $ readelf -h hello                      │
│ ELF Header:                             │
│   Magic:   7f 45 4c 46 02 01 01 00 ... │
│                                  [📋]   │
└─────────────────────────────────────────┘
```

### Implementation
```html
<div class="code-block">
  <button class="copy-btn" data-copy="readelf -h hello">📋</button>
  <pre><code>$ readelf -h hello</code></pre>
</div>

<script>
document.querySelectorAll('.copy-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    const text = btn.getAttribute('data-copy');
    navigator.clipboard.writeText(text);
    btn.textContent = '✓';
    setTimeout(() => btn.textContent = '📋', 2000);
  });
});
</script>
```

### CSS
```css
.code-block { position: relative; }
.copy-btn {
  position: absolute; top: 8px; right: 8px;
  background: var(--bg-muted); border: 1px solid var(--border);
  border-radius: 4px; padding: 4px 8px; cursor: pointer;
  opacity: 0; transition: opacity 0.15s ease;
}
.code-block:hover .copy-btn { opacity: 1; }
.copy-btn:hover { background: var(--bg-hover); }
```

### Copy Targets
- Code blocks
- Hex dumps (copy as text)
- Commands (copy to clipboard)
- Struct definitions (copy as C code)
- Memory addresses (copy as hex)

---

## 8. Bookmark System

### Bookmark Button
On every lesson, section, and exercise:
```
┌─────────────────────────────────────────┐
│ Exercise 3: ELF Header Magic            │
│                                         │
│ What is the magic number?         [🔖]  │
│                                         │
│  ○ 7f 45 4c 46                          │
│  ○ 01 02 03 04                          │
│  ○ fe ed fa ce                          │
│  ○ de ad be ef                          │
└─────────────────────────────────────────┘
```

### Bookmarks Panel
```
┌─────────────────────────────────────────┐
│ Bookmarks (3)                           │
│                                         │
│ 📖 ELF Header Magic                     │
│    "The first 4 bytes are 7f 45 4c 46"  │
│    [Go to] [Delete]                     │
│                                         │
│ 📖 Section Headers                      │
│    "SHT_SYMTAB = 2, SHT_STRTAB = 3"    │
│    [Go to] [Delete]                     │
│                                         │
│ 📖 Relocation Types                     │
│    "R_X86_64_64 = direct 64-bit"        │
│    [Go to] [Delete]                     │
└─────────────────────────────────────────┘
```

### Implementation
```javascript
function toggleBookmark(lessonId, sectionIndex, note = '') {
  const bookmarks = JSON.parse(localStorage.getItem('bookmarks') || '[]');
  const existing = bookmarks.findIndex(b =>
    b.lessonId === lessonId && b.sectionIndex === sectionIndex);

  if (existing >= 0) {
    bookmarks.splice(existing, 1);
    showToast('Bookmark removed', 'info');
  } else {
    bookmarks.push({ lessonId, sectionIndex, note, createdAt: Date.now() });
    showToast('Bookmarked!', 'success');
  }

  localStorage.setItem('bookmarks', JSON.stringify(bookmarks));
  updateBookmarkIcon(lessonId, sectionIndex);
}
```

---

## 9. Notes System

### Note-Taking Pattern
On any section, hover to reveal a note icon:
```
┌─────────────────────────────────────────┐
│ Virtual addresses are per-process.      │
│ Each process has its own address space. │
│                                [📝]     │
└─────────────────────────────────────────┘
```

### Note Editor (Inline)
```
┌─────────────────────────────────────────┐
│ Virtual addresses are per-process.      │
│ Each process has its own address space. │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ My notes:                           │ │
│ │ This is why two processes can have  │ │
│ │ the same virtual address but        │ │
│ │ different physical addresses.       │ │
│ │                                     │ │
│ │                      [Save] [Cancel]│ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### Notes Panel
```
┌─────────────────────────────────────────┐
│ Notes (5)                               │
│                                         │
│ 📝 ELF Header Magic                     │
│    "The first 4 bytes are 7f 45 4c 46"  │
│    Note: Remember, this is \x7f + 'ELF' │
│    [Go to] [Edit] [Delete]              │
│                                         │
│ 📝 Section Headers                      │
│    "SHT_SYMTAB = 2, SHT_STRTAB = 3"    │
│    Note: strtab holds section names     │
│    [Go to] [Edit] [Delete]              │
└─────────────────────────────────────────┘
```

### Implementation
```javascript
function saveNote(lessonId, sectionIndex, text) {
  const notes = JSON.parse(localStorage.getItem('notes') || '[]');
  const existing = notes.findIndex(n =>
    n.lessonId === lessonId && n.sectionIndex === sectionIndex);

  if (existing >= 0) {
    notes[existing].text = text;
    notes[existing].updatedAt = Date.now();
  } else {
    notes.push({ lessonId, sectionIndex, text, createdAt: Date.now() });
  }

  localStorage.setItem('notes', JSON.stringify(notes));
  showToast('Note saved', 'success');
}
```

---

## 10. Empty States

### No Progress Yet
```
┌─────────────────────────────────────────┐
│                                         │
│           📚                            │
│                                         │
│     Start Learning                      │
│                                         │
│     Your first lesson will appear       │
│     here. Pick a course to begin.       │
│                                         │
│     [Browse Courses →]                  │
│                                         │
└─────────────────────────────────────────┘
```

### No Bookmarks
```
┌─────────────────────────────────────────┐
│                                         │
│           🔖                            │
│                                         │
│     No Bookmarks Yet                    │
│                                         │
│     Bookmark lessons to revisit         │
│     them later.                         │
│                                         │
└─────────────────────────────────────────┘
```

### No Notes
```
┌─────────────────────────────────────────┐
│                                         │
│           📝                            │
│                                         │
│     No Notes Yet                        │
│                                         │
│     Add notes to sections to            │
│     remember key insights.              │
│                                         │
└─────────────────────────────────────────┘
```

### Search No Results
```
┌─────────────────────────────────────────┐
│                                         │
│           🔍                            │
│                                         │
│     No results for "phdr"               │
│                                         │
│     Try:                                │
│     • Program Headers                   │
│     • ELF Headers                       │
│     • Section Headers                   │
│                                         │
└─────────────────────────────────────────┘
```

### Error State
```
┌─────────────────────────────────────────┐
│                                         │
│           ⚠️                            │
│                                         │
│     Something went wrong                │
│                                         │
│     We couldn't load your progress.     │
│     Please try again.                   │
│                                         │
│     [Retry]  [Go Home]                  │
│                                         │
└─────────────────────────────────────────┘
```

---

## 11. Dark Mode Toggle

### Toggle Switch
```
┌─────────────────────────────────────────┐
│ Theme:  ☀️ ──●── 🌙                     │
└─────────────────────────────────────────┘
```

### CSS Variables
```css
:root {
  --bg-primary: #ffffff;
  --bg-secondary: #f8fafc;
  --bg-muted: #f1f5f9;
  --text-primary: #0f172a;
  --text-secondary: #475569;
  --border: #e2e8f0;
  --primary: #2563eb;
}

[data-theme="dark"] {
  --bg-primary: #0f172a;
  --bg-secondary: #1e293b;
  --bg-muted: #334155;
  --text-primary: #f8fafc;
  --text-secondary: #94a3b8;
  --border: #334155;
  --primary: #60a5fa;
}
```

### Implementation
```javascript
function toggleTheme() {
  const current = document.documentElement.getAttribute('data-theme');
  const next = current === 'dark' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', next);
  localStorage.setItem('theme', next);
}

// Load saved theme
const savedTheme = localStorage.getItem('theme') || 'light';
document.documentElement.setAttribute('data-theme', savedTheme);
```

---

## 12. Jump-to Menu (Cmd+K)

### Pattern
Global search + navigation menu:
```
┌─────────────────────────────────────────┐
│ 🔍 Search or jump to...                 │
│                                         │
│ Recent                                  │
│ 📖 ELF Header Magic          [Lesson 3]│
│ 📖 Section Headers           [Lesson 4]│
│ 📖 Relocation Types          [Lesson 6]│
│                                         │
│ Courses                                 │
│ 📚 Mastering the ELF Format  [Course]  │
│                                         │
│ Actions                                 │
│ ⚡ Review Session            [Action]   │
│ 📊 Dashboard                 [Action]   │
│ ⚙️ Settings                  [Action]   │
└─────────────────────────────────────────┘
```

### Implementation
```javascript
function openJumpMenu() {
  const menu = document.getElementById('jump-menu');
  menu.classList.add('open');
  menu.querySelector('input').focus();
}

document.addEventListener('keydown', (e) => {
  if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
    e.preventDefault();
    openJumpMenu();
  }
  if (e.key === 'Escape') {
    closeJumpMenu();
  }
});
```

---

## 13. Staggered List Entry

### Animation
```css
.stagger-item {
  opacity: 0; transform: translateY(10px);
  animation: stagger-in 0.3s ease forwards;
}
.stagger-item:nth-child(1) { animation-delay: 0ms; }
.stagger-item:nth-child(2) { animation-delay: 50ms; }
.stagger-item:nth-child(3) { animation-delay: 100ms; }
.stagger-item:nth-child(4) { animation-delay: 150ms; }
.stagger-item:nth-child(5) { animation-delay: 200ms; }
.stagger-item:nth-child(6) { animation-delay: 250ms; }
.stagger-item:nth-child(7) { animation-delay: 300ms; }
.stagger-item:nth-child(8) { animation-delay: 350ms; }

@keyframes stagger-in {
  to { opacity: 1; transform: translateY(0); }
}
```

### Use Cases
- Unit list on course page
- Exercise list in lesson
- Bookmarks panel
- Notes panel
- Search results

---

## 14. Focus Management

### Focus Ring
```css
:focus-visible {
  outline: 2px solid var(--primary);
  outline-offset: 2px;
}
```

### Focus Trap (Modal)
```javascript
function trapFocus(modal) {
  const focusable = modal.querySelectorAll(
    'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
  );
  const first = focusable[0];
  const last = focusable[focusable.length - 1];

  modal.addEventListener('keydown', (e) => {
    if (e.key !== 'Tab') return;
    if (e.shiftKey) {
      if (document.activeElement === first) { last.focus(); e.preventDefault(); }
    } else {
      if (document.activeElement === last) { first.focus(); e.preventDefault(); }
    }
  });
}
```

### Focus Restoration
```javascript
let lastFocusedElement = null;

function openModal() {
  lastFocusedElement = document.activeElement;
  // ... open modal
}

function closeModal() {
  // ... close modal
  if (lastFocusedElement) lastFocusedElement.focus();
}
```

---

## 15. Reduced Motion

### CSS
```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

### Implementation
```javascript
const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
if (prefersReducedMotion.matches) {
  document.documentElement.classList.add('reduced-motion');
}
```

---

## 16. Offline Indicator

### Pattern
```
┌─────────────────────────────────────────┐
│ ⚠️ You're offline. Progress will sync   │
│ when connection is restored.            │
└─────────────────────────────────────────┘
```

### Implementation
```javascript
window.addEventListener('online', () => {
  hideOfflineIndicator();
  syncProgress();
});

window.addEventListener('offline', () => {
  showOfflineIndicator();
});

function showOfflineIndicator() {
  const indicator = document.getElementById('offline-indicator');
  indicator.classList.add('visible');
}

function hideOfflineIndicator() {
  const indicator = document.getElementById('offline-indicator');
  indicator.classList.remove('visible');
}
```

### CSS
```css
.offline-indicator {
  position: fixed; top: 0; left: 0; right: 0;
  padding: 8px 16px; background: #f59e0b; color: #000;
  text-align: center; font-size: 0.875rem;
  transform: translateY(-100%); transition: transform 0.3s ease;
}
.offline-indicator.visible { transform: translateY(0); }
```

---

## 17. Auto-Save Indicator

### Pattern
```
┌─────────────────────────────────────────┐
│                            Saving... ●  │
│                            Saved ✓      │
└─────────────────────────────────────────┘
```

### Implementation
```javascript
let saveTimeout = null;

function autoSave() {
  const indicator = document.getElementById('save-indicator');
  indicator.textContent = 'Saving...';
  indicator.classList.add('saving');

  clearTimeout(saveTimeout);
  saveTimeout = setTimeout(() => {
    // Save to localStorage or server
    saveProgress();

    indicator.textContent = 'Saved ✓';
    indicator.classList.remove('saving');
    indicator.classList.add('saved');

    setTimeout(() => {
      indicator.classList.remove('saved');
    }, 2000);
  }, 500);
}
```

---

## 18. Keyboard Shortcut Help

### Pattern
Press `?` to show shortcuts:
```
┌─────────────────────────────────────────┐
│  Keyboard Shortcuts                     │
│                                         │
│  Navigation                             │
│  ┌─────────┬───────────────────────────┐│
│  │ →       │ Next exercise             ││
│  │ ←       │ Previous exercise         ││
│  │ 1-9     │ Jump to unit              ││
│  └─────────┴───────────────────────────┘│
│                                         │
│  Actions                                │
│  ┌─────────┬───────────────────────────┐│
│  │ Enter   │ Submit answer             ││
│  │ b       │ Bookmark                  ││
│  │ n       │ Add note                  ││
│  └─────────┴───────────────────────────┘│
│                                         │
│  Global                                 │
│  ┌─────────┬───────────────────────────┐│
│  │ Cmd+K   │ Jump to menu              ││
│  │ ?       │ Show this help            ││
│  │ Esc     │ Close                     ││
│  └─────────┴───────────────────────────┘│
└─────────────────────────────────────────┘
```

---

## 19. Hex Viewer Hover

### Pattern
When hovering over a byte in the hex viewer:
```
┌─────────────────────────────────────────┐
│ 00000000: 7f 45 4c 46 02 01 01 00 00 00 │
│          ▲                              │
│          │                              │
│     ┌────┴──────────────────────────┐   │
│     │ Byte 0x00: 0x7f              │   │
│     │ Decimal: 127                 │   │
│     │ ASCII: DEL (delete)          │   │
│     │ Offset: 0 (e_ident[EI_MAG0])│   │
│     └──────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### Implementation
```javascript
function showByteTooltip(byte, offset) {
  const tooltip = document.getElementById('byte-tooltip');
  const decimal = parseInt(byte, 16);
  const ascii = decimal >= 32 && decimal <= 126 ? String.fromCharCode(decimal) : '非打印';

  tooltip.innerHTML = `
    <strong>Byte 0x${offset.toString(16).padStart(2, '0')}:</strong> 0x${byte}<br>
    Decimal: ${decimal}<br>
    ASCII: ${ascii}<br>
    Offset: ${offset} (${getElfFieldName(offset)})
  `;
  tooltip.classList.add('visible');
}

function getElfFieldName(offset) {
  const fields = {
    0: 'e_ident[EI_MAG0]',
    1: 'e_ident[EI_MAG1]',
    2: 'e_ident[EI_MAG2]',
    3: 'e_ident[EI_MAG3]',
    4: 'e_ident[EI_CLASS]',
    // ... more fields
  };
  return fields[offset] || '';
}
```

---

## 20. Button Active States

### Press Effect
```css
.btn:active {
  transform: scale(0.98);
  transition: transform 0.1s ease;
}
```

### Loading State
```css
.btn.loading {
  pointer-events: none;
  opacity: 0.7;
}
.btn.loading::after {
  content: '';
  display: inline-block;
  width: 12px; height: 12px;
  border: 2px solid currentColor;
  border-top-color: transparent;
  border-radius: 50%;
  animation: btn-spin 0.6s linear infinite;
  margin-left: 8px;
}
@keyframes btn-spin {
  to { transform: rotate(360deg); }
}
```

---

## 21. Toggle Switch

### Pattern
```html
<label class="toggle">
  <input type="checkbox" class="toggle-input">
  <span class="toggle-slider"></span>
  <span class="toggle-label">Dark Mode</span>
</label>
```

### CSS
```css
.toggle {
  display: inline-flex; align-items: center; gap: 8px; cursor: pointer;
}
.toggle-input { display: none; }
.toggle-slider {
  width: 40px; height: 22px; border-radius: 11px;
  background: var(--bg-muted); position: relative;
  transition: background 0.2s ease;
}
.toggle-slider::after {
  content: ''; position: absolute; top: 2px; left: 2px;
  width: 18px; height: 18px; border-radius: 50%;
  background: white; transition: transform 0.2s ease;
}
.toggle-input:checked + .toggle-slider {
  background: var(--primary);
}
.toggle-input:checked + .toggle-slider::after {
  transform: translateX(18px);
}
```

---

## 22. Back-to-Top Button

### Pattern
```
                        ┌─────┐
                        │  ↑  │
                        └─────┘
```

### Implementation
```javascript
const backToTop = document.getElementById('back-to-top');

window.addEventListener('scroll', () => {
  if (window.scrollY > 300) {
    backToTop.classList.add('visible');
  } else {
    backToTop.classList.remove('visible');
  }
});

backToTop.addEventListener('click', () => {
  window.scrollTo({ top: 0, behavior: 'smooth' });
});
```

### CSS
```css
.back-to-top {
  position: fixed; bottom: 24px; left: 24px;
  width: 40px; height: 40px; border-radius: 50%;
  background: var(--bg-elevated); border: 1px solid var(--border);
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; opacity: 0; transform: translateY(20px);
  transition: all 0.2s ease;
}
.back-to-top.visible { opacity: 1; transform: translateY(0); }
.back-to-top:hover { background: var(--primary); color: white; }
```

---

## 23. Breadcrumbs

### Pattern
```
Home > Mastering the ELF Format > Unit 3: ELF Headers > Lesson 3.2
```

### Implementation
```html
<nav class="breadcrumbs" aria-label="Breadcrumb">
  <a href="/" class="breadcrumb-item">Home</a>
  <span class="breadcrumb-separator">/</span>
  <a href="/courses/elf" class="breadcrumb-item">Mastering the ELF Format</a>
  <span class="breadcrumb-separator">/</span>
  <a href="/courses/elf/3" class="breadcrumb-item">Unit 3: ELF Headers</a>
  <span class="breadcrumb-separator">/</span>
  <span class="breadcrumb-item current">Lesson 3.2</span>
</nav>
```

### CSS
```css
.breadcrumbs {
  display: flex; align-items: center; gap: 8px;
  font-size: 0.875rem; color: var(--text-muted);
  padding: 8px 0; margin-bottom: 16px;
}
.breadcrumb-item { color: var(--text-muted); text-decoration: none; }
.breadcrumb-item:hover { color: var(--primary); text-decoration: underline; }
.breadcrumb-item.current { color: var(--text-primary); font-weight: 500; }
.breadcrumb-separator { color: var(--text-muted); }
```

---

## 24. Search

### Pattern
```
┌─────────────────────────────────────────┐
│ 🔍 Search lessons, concepts...          │
│                                         │
│ Results (3)                             │
│ 📖 ELF Header Magic          [Lesson 3]│
│    The magic number is 7f 45 4c 46...   │
│                                         │
│ 📖 ELF Header Structure      [Lesson 3]│
│    The ELF header is 64 bytes for...    │
│                                         │
│ 📖 Section Header Table      [Lesson 4]│
│    Section headers describe each...     │
└─────────────────────────────────────────┘
```

### Implementation
```javascript
function searchLessons(query) {
  const results = [];
  for (const lesson of lessons) {
    if (lesson.title.includes(query) || lesson.content.includes(query)) {
      results.push(lesson);
    }
  }
  return results;
}
```

---

## 25. Responsive Design

### Breakpoints
```css
/* Mobile: < 640px */
/* Tablet: 640px - 1024px */
/* Desktop: > 1024px */

@media (max-width: 640px) {
  .lesson-layout { flex-direction: column; }
  .hex-viewer { font-size: 12px; }
  .exercise-options { flex-direction: column; }
}

@media (min-width: 641px) and (max-width: 1024px) {
  .lesson-layout { flex-direction: column; }
  .hex-viewer { font-size: 13px; }
}

@media (min-width: 1025px) {
  .lesson-layout { flex-direction: row; }
  .hex-viewer { font-size: 14px; }
}
```

---

## 26. Touch Interactions

### Swipe to Navigate
```javascript
let touchStartX = 0;
let touchEndX = 0;

document.addEventListener('touchstart', (e) => {
  touchStartX = e.changedTouches[0].screenX;
});

document.addEventListener('touchend', (e) => {
  touchEndX = e.changedTouches[0].screenX;
  handleSwipe();
});

function handleSwipe() {
  const diff = touchStartX - touchEndX;
  if (Math.abs(diff) > 50) {
    if (diff > 0) nextExercise();
    else prevExercise();
  }
}
```

### Long Press for Notes
```javascript
let longPressTimeout = null;

element.addEventListener('touchstart', () => {
  longPressTimeout = setTimeout(() => {
    openNoteEditor();
  }, 500);
});

element.addEventListener('touchend', () => {
  clearTimeout(longPressTimeout);
});
```

---

## 27. Screen Reader Support

### ARIA Labels
```html
<button aria-label="Next exercise">→</button>
<button aria-label="Bookmark this lesson">🔖</button>
<div role="progressbar" aria-valuenow="40" aria-valuemin="0" aria-valuemax="100">
  40% complete
</div>
```

### Live Regions
```html
<div aria-live="polite" aria-atomic="true" class="sr-only">
  Exercise 3 of 8
</div>
```

### CSS
```css
.sr-only {
  position: absolute; width: 1px; height: 1px;
  padding: 0; margin: -1px; overflow: hidden;
  clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0;
}
```

---

## 28. Print Styles

```css
@media print {
  .no-print { display: none !important; }
  .lesson-content { max-width: 100%; }
  a { color: #000; text-decoration: underline; }
  a[href]::after { content: " (" attr(href) ")"; font-size: 0.8em; }
}
```

---

## 29. High Contrast Mode

```css
@media (prefers-contrast: high) {
  :root {
    --bg-primary: #000000;
    --bg-secondary: #1a1a1a;
    --text-primary: #ffffff;
    --border: #ffffff;
    --primary: #ffff00;
  }
}
```

---

## 30. Font Size Controls

### Pattern
```
┌─────────────────────────────────────────┐
│ Font Size:  A-  A  A+                   │
└─────────────────────────────────────────┘
```

### Implementation
```javascript
function setFontSize(size) {
  document.documentElement.style.fontSize = `${size}px`;
  localStorage.setItem('fontSize', size);
}

const sizes = [12, 14, 16, 18, 20];
let currentSizeIndex = 2; // default 16px

function increaseFontSize() {
  if (currentSizeIndex < sizes.length - 1) {
    currentSizeIndex++;
    setFontSize(sizes[currentSizeIndex]);
  }
}

function decreaseFontSize() {
  if (currentSizeIndex > 0) {
    currentSizeIndex--;
    setFontSize(sizes[currentSizeIndex]);
  }
}
```

---

## 31. Undo/Redo

### Pattern
```
┌─────────────────────────────────────────┐
│ Undo (Ctrl+Z)  Redo (Ctrl+Y)           │
└─────────────────────────────────────────┘
```

### Implementation
```javascript
const history = [];
let historyIndex = -1;

function pushState(state) {
  history.splice(historyIndex + 1);
  history.push(state);
  historyIndex = history.length - 1;
}

function undo() {
  if (historyIndex > 0) {
    historyIndex--;
    restoreState(history[historyIndex]);
  }
}

function redo() {
  if (historyIndex < history.length - 1) {
    historyIndex++;
    restoreState(history[historyIndex]);
  }
}
```

---

## 32. Context Menu

### Pattern
Right-click on a lesson to get options:
```
┌─────────────────────────────────────────┐
│ 📖 Open in new tab                      │
│ 🔖 Bookmark                             │
│ 📝 Add note                             │
│ 📋 Copy link                            │
│ 📊 View progress                        │
└─────────────────────────────────────────┘
```

### Implementation
```javascript
element.addEventListener('contextmenu', (e) => {
  e.preventDefault();
  showContextMenu(e.clientX, e.clientY);
});

function showContextMenu(x, y) {
  const menu = document.getElementById('context-menu');
  menu.style.left = `${x}px`;
  menu.style.top = `${y}px`;
  menu.classList.add('visible');
}

document.addEventListener('click', () => {
  hideContextMenu();
});
```

---

## 33. Drag and Drop

### Pattern
Drag exercises to reorder:
```
┌─────────────────────────────────────────┐
│ ≡ Exercise 1: ELF Header Magic          │
│ ≡ Exercise 2: Header Structure          │
│ ≡ Exercise 3: Section Headers           │
│ ≡ Exercise 4: Program Headers           │
└─────────────────────────────────────────┘
```

### Implementation
```javascript
element.draggable = true;

element.addEventListener('dragstart', (e) => {
  e.dataTransfer.setData('text/plain', element.dataset.index);
});

element.addEventListener('dragover', (e) => {
  e.preventDefault();
});

element.addEventListener('drop', (e) => {
  e.preventDefault();
  const fromIndex = e.dataTransfer.getData('text/plain');
  const toIndex = element.dataset.index;
  reorderExercises(fromIndex, toIndex);
});
```

---

## 34. Resize Handle

### Pattern
Resize hex viewer:
```
┌─────────────────────────────────────────┐
│ Hex Viewer                         ⠿   │
│ 00000000: 7f 45 4c 46 02 01 01 00 ...   │
└─────────────────────────────────────────┘
```

### Implementation
```javascript
const handle = document.getElementById('resize-handle');
const panel = document.getElementById('hex-viewer');
let isResizing = false;

handle.addEventListener('mousedown', (e) => {
  isResizing = true;
  document.addEventListener('mousemove', resize);
  document.addEventListener('mouseup', stopResize);
});

function resize(e) {
  if (!isResizing) return;
  panel.style.width = `${e.clientX}px`;
}

function stopResize() {
  isResizing = false;
  document.removeEventListener('mousemove', resize);
  document.removeEventListener('mouseup', stopResize);
}
```

---

## 35. Skeleton Loading States

### Unit Card Skeleton
```html
<div class="skeleton-card">
  <div class="skeleton skeleton-title"></div>
  <div class="skeleton skeleton-text"></div>
  <div class="skeleton skeleton-text short"></div>
  <div class="skeleton skeleton-progress"></div>
</div>
```

### Exercise Skeleton
```html
<div class="skeleton-exercise">
  <div class="skeleton skeleton-text long"></div>
  <div class="skeleton skeleton-text medium"></div>
  <div class="skeleton-option"></div>
  <div class="skeleton-option"></div>
  <div class="skeleton-option"></div>
  <div class="skeleton-option"></div>
</div>
```

### Hex Viewer Skeleton
```html
<div class="skeleton-hex-viewer">
  <div class="skeleton skeleton-hex-row"></div>
  <div class="skeleton skeleton-hex-row"></div>
  <div class="skeleton skeleton-hex-row"></div>
  <div class="skeleton skeleton-hex-row"></div>
  <div class="skeleton skeleton-hex-row"></div>
</div>
```

---

## Summary

Every micro-interaction follows these principles:
1. **Immediate feedback** — user action → visible result < 100ms
2. **Subtle animation** — 150-300ms ease, never flashy
3. **Consistent styling** — use CSS variables for all colors
4. **Accessible** — ARIA labels, focus management, reduced motion
5. **Responsive** — works on mobile and desktop
6. **Offline-capable** — localStorage for bookmarks/notes
7. **Keyboard-navigable** — all features accessible via keyboard
