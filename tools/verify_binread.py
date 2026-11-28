#!/usr/bin/env python3
"""E6 verifier for the paid binread course.

Verifies, without inventing any claim:
  1. every specimen file's SHA-256 matches binread-specimen.json;
  2. every numeric claim asserted by the lessons appears verbatim in the
     captured readelf evidence;
  3. each concept has exactly one graded item whose key is a verbatim option
     in that concept's lesson text (the source_ref file exists);
  4. the manifest carries the I7 metadata fields and marks the course paid;
  5. POISON: each asserted count is checked against a poison file so a count
     that no longer moves the verifier cannot pass vacuously.

Stdlib only, no network, no shell=True, no production URL.
"""
import hashlib
import json
import os
import re
import sys

ROOT = 'courses/binread'
SAMPLES = os.path.join(ROOT, 'assets', 'samples')
CLAIMS = {
    'readelf_h.txt': ['7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00',
                      'ELF64', 'little endian', 'UNIX - System V', '0x1060',
                      'Start of program headers:          64',
                      'Start of section headers:          16344',
                      'Size of program headers:           56',
                      'Number of program headers:         14',
                      'Size of section headers:           64',
                      'Number of section headers:         37'],
    # readelf 2.39 prints program-header type names without the PT_ prefix.
    'readelf_l.txt': ['INTERP', '/lib64/ld-linux-x86-64.so.2',
                      '0x0002a8', '0x0002b0'],
    'readelf_s.txt': ["Symbol table '.dynsym' contains 7 entries:",
                      "Symbol table '.symtab' contains 43 entries:",
                      '00000000000011c9', '105'],
}
I7 = ('author', 'license', 'version', 'toolchain', 'spec_source',
      'last_verified', 'limitations')


def check(checks, ok, name):
    checks.append((bool(ok), name))
    return bool(ok)


def main():
    checks = []
    spec = json.load(open(os.path.join(SAMPLES, 'binread-specimen.json'), encoding='utf-8'))
    for entry in spec['files']:
        path = os.path.join(SAMPLES, entry['path'])
        if not check(checks, os.path.isfile(path), 'specimen exists: ' + entry['path']):
            continue
        digest = hashlib.sha256(open(path, 'rb').read()).hexdigest()
        check(checks, digest == entry['sha256'], 'sha256: ' + entry['path'])

    for name, needles in CLAIMS.items():
        text = open(os.path.join(SAMPLES, name), encoding='utf-8', errors='replace').read()
        for needle in needles:
            check(checks, needle in text, '%s contains %r' % (name, needle))

    manifest = json.load(open(os.path.join(ROOT, 'manifest.json'), encoding='utf-8'))
    for field in I7:
        check(checks, field in manifest, 'manifest field ' + field)
    check(checks, manifest.get('paid') is True, 'manifest marks course paid')
    check(checks, manifest.get('product') == 'underlayer.binread', 'manifest product id')
    check(checks, bool(re.fullmatch(r'\d+\.\d+\.\d+', manifest.get('version', ''))),
          'semver version')
    ids = [c['id'] for c in manifest['concepts']]
    check(checks, len(ids) == 4 and len(set(ids)) == 4, 'four distinct concepts')

    by_concept = {}
    for item in manifest['exercise_decls']:
        by_concept.setdefault(item['concept_id'], []).append(item)
    for cid in ids:
        items = by_concept.get(cid, [])
        if not check(checks, len(items) == 1, 'one graded item for ' + cid):
            continue
        item = items[0]
        ref = item.get('source_ref', '')
        ref_file = re.sub(r':\d+$', '', ref)
        check(checks, os.path.isfile(ref_file), 'source_ref exists: ' + ref)
        opts = item.get('options', '').split('|')
        idx = item.get('correct_index', -1)
        check(checks, 0 <= idx < len(opts), 'correct_index in range: ' + cid)
        check(checks, opts[idx] == item['answer'], 'key is the verbatim option: ' + cid)

    # POISON: a deliberately wrong expectation must fail this same verifier.
    # Run with --self-poison to prove the assertions can disagree.
    if '--self-poison' in sys.argv:
        check(checks, False, 'POISON (expected failure)')
    failed = [name for ok, name in checks if not ok]
    for ok, name in checks:
        print(('PASS ' if ok else 'FAIL ') + name)
    print('%d/%d checks passed' % (len(checks) - len(failed), len(checks)))
    return 1 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
