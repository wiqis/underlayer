#!/usr/bin/env python3
"""H12 byte verifier for obj.  Lesson hex dumps + shipped 87-check crosscheck."""
import sys
from verify_course_bytes import main_for

if __name__ == '__main__':
    sys.exit(main_for('obj', 'content/src/obj_*.ch; ELF gABI / COFF / Mach-O as cited'))
