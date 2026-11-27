#!/usr/bin/env python3
"""verify_course_bytes.py -- shared runner for per-course H12 byte verifiers.

Reported counts contain ONLY claims that the lesson text makes AND a shipped
specimen satisfies.  Candidates that are spec constants or refer to an
unshipped specimen are listed as excluded, never counted.  A poison mutation
must move the reported count (E3).
"""
import os
import sys

from byte_claim_core import (lesson_paths, sample_dir, verify_dump_claims,
                             verify_sequence_claims, run_crosscheck,
                             reader_count)
from verifier_poison import (poison_workspace, copy_file, copy_dir,
                             flip_byte, assert_count_moves)
from byte_claim_core import _sample_bytes


def counts(course, root='.'):
    dv, dt, ddet = verify_dump_claims(course, root)
    sv, st, sdet = verify_sequence_claims(course, root)
    status, n = run_crosscheck(course, root)
    rc, rnote = reader_count(course, root) if course == 'sym' else (0, '')
    return {
        'dump_verified': dv, 'dump_total': dt,
        'seq_verified': sv, 'seq_total': st,
        'crosscheck_status': status, 'crosscheck_count': n,
        'reader_count': rc,
        'verified': dv + sv + (n if status == 'pass' else 0) + rc,
        'ddet': ddet, 'sdet': sdet,
    }


def _copy_inputs(course, root, dst):
    for rel, full in lesson_paths(course, root):
        copy_file(full, os.path.join(dst, rel.replace('/', os.sep)))
    copy_dir(sample_dir(course, root),
             os.path.join(dst, 'courses', course, 'assets', 'samples'))


def report(course, spec_source, status_label, poison=True):
    c = counts(course)
    print('%s byte verification (2026-11-27):' % course)
    print('  spec source        : %s' % spec_source)
    print('  specimen assets    : %s' % sample_dir(course))
    print('  dump claims        : %d verified / %d candidates' %
          (c['dump_verified'], c['dump_total']))
    print('  hex sequences      : %d verified / %d candidates' %
          (c['seq_verified'], c['seq_total']))
    print('  shipped crosscheck : %s (%d checks)' %
          (c['crosscheck_status'], c['crosscheck_count']))
    if course == 'sym':
        print('  independent reader : %d entries (symtables.py on ord_map)' %
              c['reader_count'])
    print('  reported count     : %d' % c['verified'])
    print('  poison status      : %s' % status_label)
    excluded = ([d for d in c['ddet'] if not d['sample']] +
                [d for d in c['sdet'] if not d['sample']])
    print('  excluded candidates: %d (spec constants or unshipped specimens)' %
          len(excluded))
    for d in excluded[:3]:
        print('    %s %s' % (d['source'], d['bytes']))
    if poison:
        print('  poison demonstration (E3):')
        with poison_workspace('%s-poison-' % course) as root:
            _copy_inputs(course, '.', root)
            before = counts(course, root)['verified']
            planted = False
            # Deterministic plant: corrupt the claimed bytes in EVERY shipped
            # specimen that satisfies the claim.  Corrupting only the first
            # match leaves another specimen satisfying it and the count stays
            # put (measured on dwarf, 2026-11-27).  A verifier that has stopped
            # comparing would report the same count; one that compares moves.
            for d in c['ddet']:
                if not d['sample']:
                    continue
                want = bytes.fromhex(d['bytes'])
                hits = [p for p, data in _sample_bytes(course, root)
                        if data[d['offset']:d['offset'] + len(want)] == want]
                for p in hits:
                    flip_byte(p, d['offset'])
                if hits:
                    planted = 'dump specimen'
                    break
            if not planted:
                for d in c['sdet']:
                    if not d['sample']:
                        continue
                    want = bytes.fromhex(d['bytes'])
                    hits = []
                    for p, data in _sample_bytes(course, root):
                        positions = []
                        start = 0
                        while True:
                            idx = data.find(want, start)
                            if idx < 0:
                                break
                            positions.append(idx)
                            start = idx + 1
                        if positions:
                            hits.append((p, positions))
                    for p, positions in hits:
                        # Flip the first byte of every occurrence; a claim that
                        # a sequence appears in a specimen must stop being true.
                        for idx in reversed(positions):
                            flip_byte(p, idx)
                    if hits:
                        planted = 'sequence specimen'
                        break
            if not planted and course == 'sym':
                p = os.path.join(sample_dir(course, root), 'ord_map')
                with open(p, 'rb') as f:
                    data = f.read()
                with open(p, 'wb') as f:
                    f.write(data[:64])
                planted = 'sym specimen truncation'
            if not planted:
                raise RuntimeError('no poison plant available for ' + course)
            after = counts(course, root)['verified']
            assert_count_moves('%s expected bytes' % course, before, after)
    ok = c['verified'] > 0 and c['crosscheck_status'] != 'fail'
    if c['dump_verified'] < c['dump_total'] or c['seq_verified'] < c['seq_total']:
        print('  NOTE: not every candidate is a shipped byte claim; only '
              'matched claims count.')
    return 0 if ok else 1


def main_for(course, spec_source, status_label='active'):
    return report(course, spec_source, status_label)
