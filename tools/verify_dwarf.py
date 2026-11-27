#!/usr/bin/env python3
"""H12 byte verifier for dwarf.  Derived from lesson hex dumps + samples.

No crosscheck.py ships with this course; no byte claim is invented to make the
count non-zero.  Claims not found in the lesson text are simply not counted.
"""
import sys
from verify_course_bytes import main_for

if __name__ == '__main__':
    sys.exit(main_for('dwarf', 'content/src/dwarf_*.ch (DWARF 2-5 specs cited there)'))
