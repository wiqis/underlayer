#!/usr/bin/env python3
"""H12 byte verifier for jvm.  Lesson hex sequences + shipped three-reader crosscheck."""
import sys
from verify_course_bytes import main_for

if __name__ == '__main__':
    sys.exit(main_for('jvm', 'content/src/jvm_*.ch; JVM Specification as cited in lesson'))
