#!/usr/bin/env python3
"""Check that every ELF quiz option served by a running Underlayer explains itself.

Usage:  py -3 tools/elf_feedback_check.py http://localhost:9003

The checker fetches every lesson named in courses/elf/manifest.json and fails
when any served .quiz-option button has a missing or empty data-explain. It
also checks the served script: ELF's local checkQuiz must read data-explain in
BOTH the correct branch and the wrong branch, otherwise a filled-in attribute
would still be ignored by the renderer.

Standard library only; no server is started and nothing is written to disk.
"""
import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / 'courses' / 'elf' / 'manifest.json'

BUTTON_RE = re.compile(r'<button\b[^>]*>', re.I)
CLASS_RE = re.compile(r'class="[^"]*\bquiz-option\b[^"]*"', re.I)
EXPLAIN_RE = re.compile(r'\bdata-explain="([^"]*)"', re.I)
SCRIPT_RE = re.compile(r'<script\b[^>]*>(.*?)</script>', re.I | re.S)
READ_RE = re.compile(r"getAttribute\(\s*['\"]data-explain['\"]\s*\)", re.I)


def lesson_ids():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    return [c['id'] if isinstance(c, dict) else c for c in manifest['concepts']]


def fetch(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'elf_feedback_check/1.0'})
    with urllib.request.urlopen(request, timeout=15) as response:
        data = response.read()
    return data.decode('utf-8', 'replace')


def missing_options(html):
    missing = []
    total = 0
    for tag in BUTTON_RE.findall(html):
        if not CLASS_RE.search(tag):
            continue
        total += 1
        m = EXPLAIN_RE.search(tag)
        if not m or not m.group(1).strip():
            missing.append(tag[:160])
    return total, missing


def branches_present(html):
    """Both verdict branches must consume the explanation they read."""
    js = '\n'.join(SCRIPT_RE.findall(html))
    reads = list(READ_RE.finditer(js))
    def has_branch(marker):
        for read in reads:
            window = js[read.end():read.end() + 240]
            if marker in window:
                return True
        return False
    return len(reads) >= 2 and has_branch('Correct. ') and has_branch('Not quite. ')


def main():
    if len(sys.argv) != 2:
        print('usage: py -3 tools/elf_feedback_check.py <base-url>')
        return 2
    base = sys.argv[1].rstrip('/')
    ids = lesson_ids()
    total = 0
    missing_total = 0
    js_failures = []
    errors = []
    for concept in ids:
        url = base + '/courses/elf/lessons/' + concept
        try:
            html = fetch(url)
        except (urllib.error.URLError, OSError, ValueError) as exc:
            errors.append(f'{concept}: {exc}')
            continue
        total_options, missing = missing_options(html)
        total += total_options
        missing_total += len(missing)
        if missing:
            print(f'FAIL {concept}: {len(missing)} of {total_options} options lack data-explain')
            for tag in missing:
                print('   ' + tag)
        if not branches_present(html):
            js_failures.append(concept)
    for concept in errors:
        print('ERROR ' + concept)
    if js_failures:
        print('FAIL served checkQuiz does not consume data-explain in both branches: '
              + ', '.join(js_failures))
    if errors or js_failures or missing_total:
        print(f'elf_feedback_check: FAIL - {missing_total} of {total} options missing '
              f'data-explain across {len(ids)} lessons; {len(errors)} fetch errors; '
              f'{len(js_failures)} JS branch failures')
        return 1
    print(f'elf_feedback_check: PASS - all {total} options in {len(ids)} lessons have '
          'non-empty data-explain; both checkQuiz branches consume it')
    return 0


if __name__ == '__main__':
    sys.exit(main())
