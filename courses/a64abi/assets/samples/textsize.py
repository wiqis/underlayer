#!/usr/bin/env python3
"""textsize.py -- print the size of one section of an ELF object.

    ./textsize.py abi_O2.o .text

A two-line helper, and it exists for a specific reason.  The first version of
build_samples.sh computed this inline with a python heredoc inside a ``$( )``
substitution.  POSIX shells read a heredoc body starting on the line *after*
the one carrying the ``<<`` token, so a heredoc opened inside a multi-line
command substitution swallows the rest of the script.  The symptom was not a
crash: the line printed ``.text= bytes`` four times, with an empty number and
a zero exit status.  A missing tool in a shell script is usually loud; this
one was quiet, which is worse.  Hence a file.
"""
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0] or ".")
import a64abi  # noqa: E402  (path set up above)

path = sys.argv[1]
want = sys.argv[2] if len(sys.argv) > 2 else ".text"
_, _, secs = a64abi.elf_sections(path)
print(secs.get(want, {}).get("size", 0))
