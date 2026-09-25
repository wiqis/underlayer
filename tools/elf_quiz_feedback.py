#!/usr/bin/env python3
"""Make the 24 ELF concept pages surface per-option quiz feedback.

The defect this fixes
---------------------
The ELF course (the reference course, 24 concepts, 144 multiple-choice
options) defines its own `checkQuiz(quizId, btn, correct)` in every concept
file, and that version hardcodes its feedback text:

    if(correct) { feedback.textContent = 'Correct!'; }
    else        { feedback.textContent = 'Not quite. Try again next time.'; }

So every option in the course gives the learner the same two sentences no
matter which one they picked, and the learner is never told *why* the other
options are wrong. PE, Mach-O, HAT and DWARF already do this properly: each
option carries `data-explain` and the shared checker prints it.

This script rewrites the ELF `checkQuiz` body so that, when a button carries
`data-explain`, that text is appended to the verdict. It is purely additive:
options without `data-explain` keep exactly the behaviour they have today, so
the change is safe to land before the explanations themselves are written.

Usage: python3 tools/elf_quiz_feedback.py content/src
"""
import glob
import os
import re
import sys

OLD_RE = re.compile(
    r"(if\(correct\) \{\s*\n\s*btn\.classList\.add\('correct'\);\s*\n\s*)"
    r"feedback\.textContent = 'Correct!';")

ALT_OLD_RE = re.compile(
    r"if\(correct\)\s*\{[^{}]*?feedback\.textContent = 'Correct!';[^{}]*?\}\s*"
    r"else\s*\{[^{}]*?feedback\.textContent = 'Not quite\.[^']*';[^{}]*?\}")


def patch(path):
    src = open(path, encoding='utf-8').read()
    if 'function checkQuiz(quizId, btn, correct)' not in src:
        return None
    if 'data-explain' in src:
        return 'already'

    m = ALT_OLD_RE.search(src)
    if not m:
        return None
    old = m.group(0)

    # Keep the original colouring and classList behaviour; only replace the
    # two textContent assignments with ones that append the explanation.
    new = old
    new = new.replace(
        "feedback.textContent = 'Correct!';",
        "var el = btn.getAttribute('data-explain');\n"
        "                feedback.textContent = el ? 'Correct. ' + el : 'Correct!';")
    new = re.sub(
        r"feedback\.textContent = 'Not quite\.[^']*';",
        "var el2 = btn.getAttribute('data-explain');\n"
        "                feedback.textContent = el2 ? 'Not quite. ' + el2"
        " : 'Not quite. Try again next time.';",
        new)
    if new == old:
        return None
    src = src.replace(old, new, 1)
    open(path, 'w', encoding='utf-8').write(src)
    return 'patched'


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else 'content/src'
    tally = {}
    for path in sorted(glob.glob(os.path.join(root, '*.ch'))):
        r = patch(path)
        if r:
            tally[r] = tally.get(r, 0) + 1
    for k, v in sorted(tally.items()):
        print(f'{k}: {v} files')
    return 0


if __name__ == '__main__':
    sys.exit(main())
