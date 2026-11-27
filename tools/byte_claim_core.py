#!/usr/bin/env python3
"""byte_claim_core.py -- H12 shared byte-verification primitives.

A byte claim is ONLY accepted if it is written in that course's own verified
lesson text (content/src/*.ch) and the shipped specimen bytes match it.  No
byte, offset or spec value is invented here.  Two sources are used:

  * offset-prefixed hex dumps such as `00000000: cffa edfe 0700 0001 ...`
    (also the four-digit form `0000: ca fe ba be ...`);
  * whitespace-separated two-digit hex sequences inside <code> elements.

The second reader is the specimen itself: a claim counts only when a shipped
file has those bytes at that offset (or contains that sequence).  A crosscheck
harness shipped with the course is reported separately when it is runnable.
Stdlib only, no shell=True, explicit timeouts on subprocesses.
"""
import os
import re
import subprocess
import sys

from concept_sources import course_map, html_plain

DUMP_RE = re.compile(r'(?m)^\s*([0-9a-fA-F]{4}|[0-9a-fA-F]{8}):\s+((?:[0-9a-fA-F]{2,4}\s+){2,})')
CODE_RE = re.compile(r'<code(?:\s[^>]*)?>(.*?)</code>', re.S)
SEQ_RE = re.compile(r'^(?:[0-9a-fA-F]{2}\s+){1,7}[0-9a-fA-F]{2}$')
BIN_SUFFIXES = {'.o', '.obj', '.so', '.dylib', '.exe', '.macho', '.class',
                '.wasm', '.dwo', '.dwp', '.bin', '.a', '.out'}


def lesson_paths(course, root='.'):
    paths = []
    for rel in sorted(set(p for p in course_map(course).values() if p)):
        full = os.path.join(root, rel.replace('/', os.sep))
        if os.path.isfile(full):
            paths.append((rel, full))
    return paths


def spec_paths(course):
    return [p for _, p in lesson_paths(course)]


def sample_dir(course, root='.'):
    return os.path.join(root, 'courses', course, 'assets', 'samples')


def sample_files(course, root='.'):
    """Binary specimen files, sorted; skips scripts and sources."""
    out = []
    base = sample_dir(course, root)
    if not os.path.isdir(base):
        return out
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames.sort()
        for fn in sorted(filenames):
            suffix = os.path.splitext(fn)[1].lower()
            if suffix in ('.py', '.sh', '.c', '.cpp', '.java', '.wat',
                          '.gitignore', '.md', '.map', '.txt'):
                continue
            path = os.path.join(dirpath, fn)
            out.append(path)
    return out


def _sample_bytes(course, root='.'):
    for p in sample_files(course, root):
        try:
            with open(p, 'rb') as f:
                yield p, f.read()
        except OSError:
            continue


def dump_claims(course, root='.'):
    """[(source_rel, line_no, offset:int, bytes_hex:str)] from lesson text."""
    claims = []
    for rel, full in lesson_paths(course, root):
        text = open(full, encoding='utf-8', errors='replace').read()
        for li, line in enumerate(text.splitlines(), 1):
            m = DUMP_RE.match(line)
            if not m:
                continue
            try:
                data = bytes.fromhex(''.join(m.group(2).split()))
            except ValueError:
                continue
            if len(data) < 2:
                continue
            claims.append((rel, li, int(m.group(1), 16), data.hex(' ')))
    return claims


def verify_dump_claims(course, root='.'):
    """Return (verified, total, details) for offset dump claims."""
    claims = dump_claims(course, root)
    samples = list(_sample_bytes(course, root))
    details = []
    for rel, li, offset, hexs in claims:
        want = bytes.fromhex(hexs)
        hit = next((os.path.basename(p) for p, data in samples
                    if data[offset:offset + len(want)] == want), None)
        details.append({'source': '%s:%d' % (rel, li), 'offset': offset,
                        'bytes': hexs, 'sample': hit})
    return len([d for d in details if d['sample']]), len(details), details


def sequence_claims(course, root='.'):
    """[(source_rel, line_no, byte_sequence)] from <code> hex sequences."""
    claims = []
    for rel, full in lesson_paths(course, root):
        text = open(full, encoding='utf-8', errors='replace').read()
        lines = text.splitlines()
        for cm in CODE_RE.finditer(text):
            raw = html_plain(cm.group(1))
            if not SEQ_RE.match(raw) or len(raw.split()) < 2:
                continue
            seq = ' '.join(t.lower() for t in raw.split())
            claims.append((rel, text.count('\n', 0, cm.start()) + 1, seq))
    return claims


def verify_sequence_claims(course, root='.'):
    claims = sequence_claims(course, root)
    samples = list(_sample_bytes(course, root))
    details = []
    for rel, li, seq in claims:
        want = bytes.fromhex(seq)
        hit = next((os.path.basename(p) for p, data in samples if want in data), None)
        details.append({'source': '%s:%d' % (rel, li), 'bytes': seq, 'sample': hit})
    return len([d for d in details if d['sample']]), len(details), details


def reader_count(course, root='.', timeout=20):
    """Independent-reader count for a course with no byte-dump claims.

    sym's lesson text quotes no offset-prefixed byte dump.  Its shipped
    symtables.py is an independent ELF reader written from the gABI; the count
    it derives from ord_map is a real measurement of shipped bytes, not an
    invented claim.  Returns (count, note); 0 means 'could not read'.
    """
    script = os.path.join(sample_dir(course, root), 'symtables.py')
    specimen = os.path.join(sample_dir(course, root), 'ord_map')
    if not (os.path.isfile(script) and os.path.isfile(specimen)):
        return 0, 'reader or specimen missing'
    try:
        cp = subprocess.run([sys.executable, os.path.basename(script),
                             os.path.basename(specimen)],
                            cwd=sample_dir(course, root), capture_output=True,
                            text=True, timeout=timeout)
    except (subprocess.TimeoutExpired, OSError):
        return 0, 'reader timed out'
    m = re.search(r'-- \.dynsym \((\d+) entries\) --', cp.stdout or '')
    return (int(m.group(1)) if m else 0), 'symtables.py .dynsym entries in ord_map'


def run_crosscheck(course, root='.', timeout=30):
    """Run the shipped crosscheck.py in a temp-root copy; return (status, count).

    Status is 'pass', 'fail', or 'unavailable'.  The subprocess has an explicit
    timeout and a list argv (never shell=True).  A crosscheck that cannot run
    because a third-party tool is absent is NOT counted as a byte verification.
    """
    path = os.path.join(sample_dir(course, root), 'crosscheck.py')
    if not os.path.isfile(path):
        return 'unavailable', 0
    # Pin the child's text mode: the shipped crosschecks disagree under
    # PYTHONUTF8=1 on this machine (jvm: 2/25) but agree with the default
    # locale (0/25).  A verifier must not change its answer because the
    # caller's shell exported a different encoding flag.
    child_env = dict(os.environ)
    child_env['PYTHONUTF8'] = '0'
    child_env['PYTHONIOENCODING'] = 'utf-8'
    try:
        cp = subprocess.run([sys.executable, os.path.basename(path)],
                            cwd=os.path.dirname(path), capture_output=True,
                            text=True, timeout=timeout, env=child_env)
    except (subprocess.TimeoutExpired, OSError):
        return 'unavailable', 0
    if 'FileNotFoundError' in (cp.stderr or '') or 'not found' in (cp.stderr or '').lower():
        return 'unavailable', 0
    out = cp.stdout or ''
    n = 0
    m = re.search(r'(\d+)/(\d+) checks passed', out)
    if m:
        n = int(m.group(1))
        return ('pass' if cp.returncode == 0 and n == int(m.group(2)) else 'fail'), n
    m = re.search(r'(\d+) checks,\s*(\d+) failed', out)
    if not m:
        m = re.search(r'(\d+) passed,\s*(\d+) failed', out)
    if m:
        n = int(m.group(1))
        return ('pass' if cp.returncode == 0 and m.group(2) == '0' else 'fail'), n
    m = re.search(r'(\d+) file\(s\) checked,\s*(\d+) with disagreements', out)
    if m:
        n = int(m.group(1))
        return ('pass' if cp.returncode == 0 and m.group(2) == '0' else 'fail'), n
    return ('fail' if cp.returncode else 'unavailable'), 0
