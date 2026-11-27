#!/usr/bin/env python3
"""H12 byte verifier for macho.  Derived from lesson hex dumps + samples.

No crosscheck.py ships with this course; specimen bundles for the wider H12
claim are I5's work, but this course already has real samples and they are used
here.  No claim is invented to satisfy a count.
"""
import sys
from verify_course_bytes import main_for

if __name__ == '__main__':
    sys.exit(main_for('macho', 'content/src/macho_*.ch; loader.h / fat.h as cited in lesson'))
