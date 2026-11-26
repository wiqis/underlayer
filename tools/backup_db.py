#!/usr/bin/env python3
"""backup_db.py -- take a verified, timestamped copy of Underlayer's SQLite DB.

USE THE STDLIB BACKUP API, NOT A FILE COPY. sqlite3.Connection.backup() takes a
consistent snapshot even while the server has the database open; `shutil.copy`
on a live WAL database can produce a file that is missing committed pages.

The source is opened read-only. An integrity_check runs on the source BEFORE the
copy and on the backup AFTER it; a backup that fails either check is deleted and
reported as a failure. An existing destination is never overwritten unless
--force is given. The copy is written to a temp file and renamed into place, so
a failed run never leaves a half-written backup that looks usable.

Usage:
    python tools/backup_db.py SOURCE_DB OUTPUT_PATH [--force]

OUTPUT_PATH may be a directory (a timestamped <dbname>-YYYYmmdd-HHMMSS.db is
created inside it) or an explicit file path (used verbatim).

Exit 0 on a verified backup, 1 otherwise.
"""
import argparse
import os
import sqlite3
import sys
import time
from datetime import datetime
from pathlib import Path


def ro_uri(path: Path) -> str:
    """A read-only SQLite URI. as_uri() handles Windows drive letters."""
    return path.resolve().as_uri() + '?mode=ro'


def integrity(con: sqlite3.Connection) -> str:
    rows = con.execute('PRAGMA integrity_check').fetchall()
    return '\n'.join(str(r[0]) for r in rows) if rows else '(no result)'


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('source', help='path to the live SQLite database (opened read-only)')
    ap.add_argument('output', help='directory for a timestamped backup, or an explicit file path')
    ap.add_argument('--force', action='store_true',
                    help='overwrite the destination if it already exists')
    args = ap.parse_args()

    src = Path(args.source)
    if not src.is_file():
        print('backup_db: FAIL -- source is not a file: %s' % src, file=sys.stderr)
        return 1

    out = Path(args.output)
    # An extension-less path (or one with a trailing separator) means "directory
    # of timestamped backups"; a path with a suffix is an explicit file name.
    if out.is_dir() or str(out).endswith(('/', '\\')) or out.suffix == '':
        out.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now().strftime('%Y%m%d-%H%M%S')
        out = out / ('%s-%s.db' % (src.stem, stamp))
    if out.exists() and not args.force:
        print('backup_db: FAIL -- destination exists (use --force): %s' % out,
              file=sys.stderr)
        return 1

    tmp = out.with_name('%s.tmp-%d' % (out.name, os.getpid()))
    if tmp.exists():
        tmp.unlink()

    print('backup_db: source   %s (%d bytes)' % (src, src.stat().st_size))
    print('backup_db: dest     %s' % out)
    started = time.time()
    src_con = None
    dst_con = None
    try:
        src_con = sqlite3.connect(ro_uri(src), uri=True)
        before = integrity(src_con)
        print('backup_db: source integrity_check: %s' % before)
        if before.strip() != 'ok':
            print('backup_db: FAIL -- source failed integrity_check', file=sys.stderr)
            return 1

        dst_con = sqlite3.connect(str(tmp))
        src_con.backup(dst_con)
        dst_con.close()
        dst_con = None

        check_con = sqlite3.connect(ro_uri(tmp), uri=True)
        after = integrity(check_con)
        pages = check_con.execute('PRAGMA page_count').fetchone()[0]
        check_con.close()
        print('backup_db: backup integrity_check: %s (%d pages)' % (after, pages))
        if after.strip() != 'ok':
            print('backup_db: FAIL -- backup failed integrity_check', file=sys.stderr)
            return 1

        os.replace(str(tmp), str(out))
    except Exception as e:
        print('backup_db: FAIL -- %s: %s' % (type(e).__name__, e), file=sys.stderr)
        return 1
    finally:
        if dst_con is not None:
            dst_con.close()
        if src_con is not None:
            src_con.close()
        if tmp.exists():
            tmp.unlink()

    print('backup_db: OK -- %d bytes in %.2fs' % (out.stat().st_size, time.time() - started))
    print('backup_db: restore with: stop the server, copy this file over the live DB, restart')
    return 0


if __name__ == '__main__':
    sys.exit(main())
