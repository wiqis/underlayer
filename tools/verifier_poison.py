#!/usr/bin/env python3
"""verifier_poison.py -- E3 shared poison helper for verification counts.

A count that a cross-check reports must not be indistinguishable from the
same count reported by a check that has silently stopped comparing.  Every
verifier touched by this batch therefore exposes its reported count through a
function and, under `--poison`, plants one deliberate mutation in an isolated
copy of the inputs and requires that the count MOVE.

Safety: temp workspaces are created only under `tools/` (one of the two
directories this batch is allowed to write), use stdlib only, no shell, no
network, no secrets, and are removed in a `finally` block.

Usage from a verifier:

    from verifier_poison import (poison_workspace, assert_count_moves,
                                 flip_byte, replace_in_file)

    with poison_workspace('bank-') as root:
        copy_inputs(root)                 # copy ONLY the files the count reads
        before = count_valid_items(root)
        replace_in_file(path_in_root, 'correct_index": 1', 'correct_index": 2')
        after = count_valid_items(root)
        assert_count_moves('answer key', before, after)

The helper never mutates the real tree.
"""
import os
import shutil
import sys
import tempfile


class PoisonFailure(AssertionError):
    pass


def poison_workspace(prefix='poison-'):
    """Context manager: an isolated temp directory created under tools/."""
    from contextlib import contextmanager
    base = os.path.dirname(os.path.abspath(__file__))

    @contextmanager
    def _ctx():
        path = tempfile.mkdtemp(prefix=prefix, dir=base)
        try:
            yield path
        finally:
            shutil.rmtree(path, ignore_errors=True)

    return _ctx()


def copy_file(src, dst):
    """Copy one file into a temp workspace, creating parent dirs."""
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copyfile(src, dst)
    return dst


def copy_dir(src, dst):
    """Copy a specimen directory into a temp workspace."""
    if os.path.isdir(dst):
        shutil.rmtree(dst)
    shutil.copytree(src, dst)
    return dst


def flip_byte(path, offset=0):
    """Flip one byte in place; return (old, new).  Raises if file is too short."""
    with open(path, 'rb') as f:
        data = bytearray(f.read())
    if len(data) <= offset:
        raise PoisonFailure('%s is too short to flip at %d' % (path, offset))
    old = data[offset]
    data[offset] = old ^ 0xFF
    with open(path, 'wb') as f:
        f.write(data)
    return old, data[offset]


def replace_in_file(path, old, new, expected=1):
    """Replace a literal in a text file; fail loudly if the plant does not fit."""
    with open(path, encoding='utf-8') as f:
        text = f.read()
    n = text.count(old)
    if n < expected:
        raise PoisonFailure('plant %r not found in %s (found %d)' % (old, path, n))
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text.replace(old, new, expected))


def assert_count_moves(label, before, after):
    """The poison requirement: the reported count MUST change."""
    ok = before != after
    print('  poison %-28s %d -> %d  %s' %
          (label, before, after, 'MOVES (PASS)' if ok else 'UNCHANGED (FAIL)'))
    if not ok:
        raise PoisonFailure('count %r did not move under poison' % label)
    return True


def main():
    print('verifier_poison: shared helper loaded from %s' % __file__)
    print('  poison_workspace / copy_file / copy_dir / flip_byte / '
          'replace_in_file / assert_count_moves')
    # Self-test of the helper itself: a planted byte flip must change a count
    # of bytes equal to a literal, i.e. the helper really mutates an isolated
    # copy and leaves the original alone.
    with poison_workspace('helper-selftest-') as root:
        p = copy_file(__file__, os.path.join(root, 'sample.txt'))
        before = open(p, 'rb').read()[0]
        flip_byte(p, 0)
        after = open(p, 'rb').read()[0]
        assert_count_moves('helper byte flip', before, after)
    orig = open(__file__, 'rb').read()[0]
    print('  original file byte unchanged: %s' % (orig == before))
    return 0 if orig == before else 1


if __name__ == '__main__':
    sys.exit(main())
