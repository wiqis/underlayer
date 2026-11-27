#!/usr/bin/env python3
"""H12 byte verifier for coff.  Derived from lesson hex dumps + samples."""
import sys
from verify_course_bytes import main_for

if __name__ == '__main__':
    sys.exit(main_for('coff', 'content/src/coff_*.ch; courses/coff/assets/samples/crosscheck.py'))
