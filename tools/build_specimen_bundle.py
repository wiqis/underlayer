#!/usr/bin/env python3
"""Build a deterministic specimen zip + index from files already on disk.

No byte or format claim is authored here: only SHA-256 copy integrity. The
caller supplies the course id, the exact member list, the recorded toolchain
contract and a SOURCES.md that evidences every version/date. Zip timestamps
are fixed at 1980-01-01 so the archive hash is reproducible (same convention
as the other 34 bundles; see docs/verification-coverage.md).

Stdlib only, explicit timeouts are not needed (no network), no shell, and an
existing bundle is never overwritten without --force.
"""
import argparse
import hashlib
import json
import zipfile
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIXED_DATE = (1980, 1, 1, 0, 0, 0)


def sha_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def build(course, members, contract, toolchain, date, source, not_checked, force):
    sample_dir = ROOT / 'courses' / course / 'assets' / 'samples'
    if not sample_dir.is_dir():
        raise SystemExit('no sample directory: %s' % sample_dir)
    index_path = sample_dir / ('%s-specimen.json' % course)
    zip_path = sample_dir / ('%s-specimen.zip' % course)
    if not force and (index_path.exists() or zip_path.exists()):
        raise SystemExit('bundle exists; pass --force to replace it')
    entries = []
    for name in members:
        path = sample_dir / name
        if not path.is_file():
            raise SystemExit('member missing: %s' % path)
        entries.append({'path': name, 'bytes': path.stat().st_size,
                        'sha256': sha_file(path)})
    with zipfile.ZipFile(zip_path, 'w', compression=zipfile.ZIP_DEFLATED) as zf:
        for entry in entries:
            info = zipfile.ZipInfo(entry['path'], date_time=FIXED_DATE)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            zf.writestr(info, (sample_dir / entry['path']).read_bytes())
    meta = {
        'course_id': course,
        'bundle': zip_path.name,
        'sha256': sha_file(zip_path),
        'bytes': zip_path.stat().st_size,
        'toolchain': toolchain,
        'toolchain_contract': contract,
        'verification_date': date,
        'source': source,
        'not_checked': not_checked,
        'file_count': len(entries),
        'files': entries,
    }
    index_path.write_text(json.dumps(meta, indent=2) + '\n', encoding='utf-8')
    print('%s: %d members, sha256=%s' % (course, len(entries), meta['sha256']))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--course', required=True)
    ap.add_argument('--member', action='append', required=True)
    ap.add_argument('--contract', required=True)
    ap.add_argument('--toolchain', required=True, help='JSON object')
    ap.add_argument('--date', required=True)
    ap.add_argument('--source', required=True)
    ap.add_argument('--not-checked', action='append', default=[])
    ap.add_argument('--force', action='store_true')
    args = ap.parse_args()
    build(args.course, args.member, args.contract, json.loads(args.toolchain),
          args.date, args.source, args.not_checked, args.force)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
