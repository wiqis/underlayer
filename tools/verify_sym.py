#!/usr/bin/env python3
"""H12 byte verifier for sym.

The lesson text carries no offset-prefixed byte dump for this course, so the
count is taken from the shipped independent reader (symtables.py, written from
the ELF gABI) and the shipped crosscheck.  No byte claim is fabricated to make
the matrix look complete.
"""
import sys
from verify_course_bytes import main_for

if __name__ == '__main__':
    sys.exit(main_for('sym', 'content/src/sym_*.ch; ELF gABI (symtables.py docstring)'))
