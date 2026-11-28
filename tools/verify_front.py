#!/usr/bin/env python3
"""verify_front.py -- independent verifier for the `front` course (E1/E3).

It re-derives every numeric claim from the real specimen and from CPython's own
`tokenize` / `ast` modules, then checks the lesson sources, the graded bank and
the shipped static runner against those numbers.  It shares NO extraction code
with tools/generate_graded_banks.py: the converter from CPython's AST to the
course's node encoding is written here, independently of runner/frontier.py.

Reported counts and their own poison plants:

    token_agreement   poison a token's TEXT in the specimen
    ast_agreement     poison the tree SHAPE in the specimen
    claim_hits        poison a claim sentence in a lesson source
    graded_valid      poison a correct_index in the manifest
    retired_hits      plant a retired concept name in the manifest
    runner_markers    remove a marker from the runner source

No network, no shell, stdlib only.  See courses/front/research.md for the
authoritative sources and the dated toolchain.
"""
import argparse
import ast as py_ast
import importlib.util
import io
import json
import os
import re
import sys
import tokenize

from concept_sources import html_plain

COURSE = 'front'
REL = {
    'src': 'a + 2 * (b - 3) / 4',
    'specimen': 'courses/front/assets/samples/specimen.src',
    'tokens': 'courses/front/assets/samples/specimen.tokens.json',
    'tree': 'courses/front/assets/samples/specimen.ast.json',
    'frontier': 'courses/front/runner/frontier.py',
    'manifest': 'courses/front/manifest.json',
    'lexer': 'courses/front/src/lexer.ch',
    'parser': 'courses/front/src/parser.ch',
    'ast': 'courses/front/src/ast.ch',
    'runner': 'courses/front/src/runner_js.ch',
    'page': 'courses/front/output/fe-ast.html',
}
RETIRED = ('lexers', 'recursive-descent-parsing', 'abstract-syntax-trees')
CLAIMS = (
    ('11 tokens', 'lexer', 'reports <strong>11</strong> tokens'),
    ('9 nodes', 'parser', 'tree of <strong>9</strong> nodes'),
    ('9 nodes', 'ast', 'tree has <strong>9</strong> nodes'),
    ('precedence quote', 'parser', 'Operators in the same box group left to right'),
    ('negative literal quote', 'parser', 'syntactically not literals'),
    ('fixture', 'ast', '&#123;"k": "bin"'),
    ('oracle', 'runner', 'function oracleParse'),
    ('input bound', 'runner', 'src.length > 4096'),
    ('step bound', 'runner', 'steps > 100000'),
    ('calm error', 'runner', "throw new Error('unexpected character"),
)
RUNNER_MARKERS = ('function frontLex', 'function frontParse', 'function oracleParse',
                  'function canon', 'front-fixture', 'front-run', 'front-error',
                  'front-source', 'front-output')


def path(root, key):
    return os.path.join(root, REL[key].replace('/', os.sep))


def read(root, key):
    with open(path(root, key), encoding='utf-8', errors='replace') as f:
        return f.read()


def load_frontier(root):
    """Import the course's reference code from the (possibly temp) root."""
    name = '_front_ref_%s' % abs(hash(root))
    spec = importlib.util.spec_from_file_location(name, path(root, 'frontier'))
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def convert(node):
    """CPython AST -> course node encoding. Written independently of frontier."""
    if isinstance(node, py_ast.Constant) and isinstance(node.value, int):
        return {'k': 'num', 'v': node.value}
    if isinstance(node, py_ast.Name):
        return {'k': 'name', 'v': node.id}
    if isinstance(node, py_ast.UnaryOp) and isinstance(node.op, py_ast.USub):
        return {'k': 'un', 'op': 'USub', 'v': convert(node.operand)}
    if isinstance(node, py_ast.BinOp):
        names = {py_ast.Add: 'Add', py_ast.Sub: 'Sub',
                 py_ast.Mult: 'Mult', py_ast.Div: 'Div'}
        op = names.get(type(node.op))
        if op:
            return {'k': 'bin', 'op': op,
                    'l': convert(node.left), 'r': convert(node.right)}
    raise ValueError('unsupported CPython node %r' % (node,))


def canon(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'))


def authority_tokens(src):
    return [[tokenize.tok_name[t.type], t.string]
            for t in tokenize.generate_tokens(io.StringIO(src).readline)
            if tokenize.tok_name[t.type] in ('NAME', 'NUMBER', 'OP')]


def authority_tree(src):
    return convert(py_ast.parse(src.strip(), mode='eval').body)


def count_tokens(root, frontier):
    """Number of token positions where all three readers agree."""
    src = read(root, 'specimen')
    fixture = json.loads(read(root, 'tokens'))
    mine = frontier.lex(src)
    oracle = authority_tokens(src)
    n = min(len(fixture), len(mine), len(oracle))
    return sum(1 for i in range(n)
               if canon(fixture[i]) == canon(mine[i]) == canon(oracle[i]))


def count_tree(root, frontier):
    """Node count if the fixture, our parser and CPython all agree; else 0."""
    src = read(root, 'specimen')
    fixture = json.loads(read(root, 'tree'))
    mine = frontier.parse(frontier.lex(src))
    oracle = authority_tree(src)
    if canon(fixture) != canon(mine) or canon(fixture) != canon(oracle):
        return 0
    return frontier.node_count(fixture)


def count_claims(root):
    return sum(1 for _, key, needle in CLAIMS if needle in read(root, key))


def count_graded(root):
    """Valid generated items, checked independently of the bank generator."""
    m = json.loads(read(root, 'manifest'))
    ids = set(c['id'] for c in m.get('concepts', []))
    valid = 0
    for item in m.get('exercise_decls', []):
        ref = item.get('source_ref', '')
        match = re.match(r'^(.*):(\d+)$', ref)
        if not match or item.get('concept_id') not in ids:
            continue
        rel, line = match.group(1), int(match.group(2))
        dst = os.path.join(root, rel.replace('/', os.sep))
        if not os.path.isfile(dst):
            continue
        lines = open(dst, encoding='utf-8', errors='replace').read().splitlines()
        if not (1 <= line <= len(lines)):
            continue
        quote = html_plain(item.get('source_quote', ''))
        answer = html_plain(str(item.get('answer', '')))
        if not quote or quote not in html_plain(lines[line - 1]):
            continue
        options = [html_plain(p) for p in str(item.get('options', '')).split('|')]
        ci = item.get('correct_index')
        if len(options) < 2 or not isinstance(ci, int) or not (0 <= ci < len(options)):
            continue
        if answer != options[ci] or answer not in html_plain(read(root, 'lexer') + read(root, 'parser') + read(root, 'ast')):
            continue
        if not str(item.get('explanation', '')).strip():
            continue
        valid += 1
    return valid


def count_retired(root):
    """Whole-segment occurrences of roadmap names that were renamed."""
    m = json.loads(read(root, 'manifest'))
    blob = json.dumps(m) + read(root, 'lexer') + read(root, 'parser') + read(root, 'ast')
    n = 0
    for name in RETIRED:
        n += len(re.findall(r'(?<![A-Za-z0-9-])%s(?![A-Za-z0-9-])' %
                            re.escape(name), blob))
    return n


def count_runner(root):
    """Markers present in BOTH the authored source and the generated page.

    Counting the intersection is deliberate: a marker that exists only in the
    .ch source was never emitted, and a marker that exists only in a stale
    generated page has no source of truth.  Poisoning the source must move it.
    """
    source = read(root, 'runner') + read(root, 'ast')
    page_path = path(root, 'page')
    if not os.path.isfile(page_path):
        # courses/*/output is gitignored; a clean checkout has to regenerate it.
        # The count still checks every marker in the authored sources.
        return sum(1 for marker in RUNNER_MARKERS if marker in source)
    page = read(root, 'page')
    return sum(1 for marker in RUNNER_MARKERS
               if marker in page and marker in source)


def collect(root='.'):
    frontier = load_frontier(root)
    return {
        'token_agreement': count_tokens(root, frontier),
        'ast_agreement': count_tree(root, frontier),
        'claim_hits': count_claims(root),
        'graded_valid': count_graded(root),
        'retired_hits': count_retired(root),
        'runner_markers': count_runner(root),
    }


def copy_inputs(root, dst):
    from verifier_poison import copy_file
    for key in REL:
        src = path(root, key)
        if os.path.isfile(src):
            copy_file(src, os.path.join(dst, REL[key].replace('/', os.sep)))


def poison_demo():
    from verifier_poison import (poison_workspace, replace_in_file,
                                 assert_count_moves)
    plants = (
        ('token_agreement', 'specimen',
         (('a + 2', 'aa + 2'),)),           # token TEXT, not count
        ('ast_agreement', 'specimen',
         (('(b - 3)', 'b'),)),              # tree SHAPE
        ('claim_hits', 'parser',
         (('tree of <strong>9</strong> nodes',
           'tree of <strong>8</strong> nodes'),)),
        ('graded_valid', 'manifest',
         (('"correct_index": 0', '"correct_index": 1'),)),
        ('retired_hits', 'manifest',
         (('"fe-lexer"', '"lexers"'),)),
        ('runner_markers', 'runner',
         (('function oracleParse', 'function oracleGone'),)),
    )
    for name, key, edits in plants:
        with poison_workspace('front-poison-') as root:
            copy_inputs('.', root)
            before = collect(root)[name]
            for old, new in edits:
                replace_in_file(path(root, key), old, new)
            after = collect(root)[name]
            assert_count_moves(name, before, after)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--poison', action='store_true',
                    help='plant one mutation per reported count and require it to move')
    args = ap.parse_args()
    stats = collect('.')
    print('front verifier (root = repo, specimen %s):' % REL['src'])
    for key in ('token_agreement', 'ast_agreement', 'claim_hits',
                'graded_valid', 'retired_hits', 'runner_markers'):
        print('  %-18s %d' % (key, stats[key]))
    ok = (stats['token_agreement'] == 11 and stats['ast_agreement'] == 9
          and stats['claim_hits'] == len(CLAIMS)
          and stats['graded_valid'] == 6 and stats['retired_hits'] == 0
          and stats['runner_markers'] == len(RUNNER_MARKERS))
    print('  verdict: %s' % ('PASS' if ok else 'FAIL'))
    if args.poison:
        print('\npoison demonstration (each reported count has its own plant):')
        poison_demo()
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
