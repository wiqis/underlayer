#!/usr/bin/env python3
"""H12 byte verifier for wasm.  Lesson hex sequences + shipped crosscheck."""
import sys
from verify_course_bytes import main_for

if __name__ == '__main__':
    sys.exit(main_for('wasm', 'content/src/wasm_*.ch; WebAssembly Specification as cited'))
