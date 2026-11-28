#!/usr/bin/env python3
"""sandbox.py -- constrained execution envelope for learner-authored parser code.

This is NOT a security-grade sandbox and does not claim to be one.  It is an
exercise envelope with five independent limits, all of which are tested by
tools/front_runner_check.py:

  1. the learner submits JSON on stdin, never program text to eval in the
     server process; this program runs in its own short-lived subprocess;
  2. the learner's Python is parsed and rejected unless every node is on an
     explicit allowlist -- no imports, no attributes, no dunder names;
  3. the only builtins visible are pure data functions -- no open, no exec,
     no eval, no __import__, no socket;
  4. source and input are bounded (4096 / 8192 characters);
  5. the parent enforces a strict 2 second timeout and scrubs the environment.

The learner implements `parse_expr(tokens)`; the runner lexes the source with
the shipped, fixed lexer, calls that function, and compares the returned AST
BY VALUE with the verified fixture.  A mismatch is a calm sentence, not a
traceback.
"""
import ast as py_ast
import json
import os
import sys

# -I removes the script directory from sys.path; add it back for OUR module only.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import frontier

MAX_SOURCE = 4096
MAX_CODE = 8192
ALLOWED_NODES = (
    py_ast.Module, py_ast.FunctionDef, py_ast.arguments, py_ast.arg,
    py_ast.Return, py_ast.Assign,
    py_ast.AugAssign, py_ast.If, py_ast.While, py_ast.For, py_ast.Pass,
    py_ast.Break, py_ast.Continue, py_ast.Expr, py_ast.BinOp, py_ast.UnaryOp,
    py_ast.BoolOp, py_ast.Compare, py_ast.Call, py_ast.Name, py_ast.Load,
    py_ast.Store, py_ast.Subscript, py_ast.Index, py_ast.Slice,
    py_ast.Constant, py_ast.Dict, py_ast.List, py_ast.Tuple, py_ast.keyword,
    py_ast.Add, py_ast.Sub, py_ast.Mult, py_ast.Div, py_ast.FloorDiv,
    py_ast.Mod, py_ast.USub, py_ast.UAdd, py_ast.Not, py_ast.And, py_ast.Or,
    py_ast.Eq, py_ast.NotEq, py_ast.Lt, py_ast.LtE, py_ast.Gt, py_ast.GtE,
    py_ast.Is, py_ast.IsNot, py_ast.In, py_ast.NotIn,
)
ALLOWED_CALLS = frozenset(('int', 'str', 'len', 'range', 'list', 'dict',
                           'tuple', 'min', 'max', 'sum', 'abs', 'bool',
                           'sorted', 'reversed'))
SAFE_BUILTINS = {
    'int': int, 'str': str, 'len': len, 'range': range, 'list': list,
    'dict': dict, 'tuple': tuple, 'min': min, 'max': max, 'sum': sum,
    'abs': abs, 'bool': bool, 'sorted': sorted, 'reversed': reversed,
    'True': True, 'False': False, 'None': None,
}


class Refused(Exception):
    """The envelope refused the submission, with a calm sentence."""


def validate(code):
    if len(code) > MAX_CODE:
        raise Refused('learner code is longer than 8192 characters')
    try:
        tree = py_ast.parse(code, mode='exec')
    except SyntaxError as exc:
        raise Refused('learner code has a syntax error at line %d' % exc.lineno)
    for node in py_ast.walk(tree):
        if not isinstance(node, ALLOWED_NODES):
            raise Refused('%s is not available in the runner' %
                          type(node).__name__.lower())
        if isinstance(node, py_ast.Name) and node.id.startswith('__'):
            raise Refused('names beginning with double underscores are not available')
        if isinstance(node, py_ast.Call):
            fn = node.func
            if not isinstance(fn, py_ast.Name) or fn.id not in ALLOWED_CALLS:
                raise Refused('that call is not available in the runner')
    fns = [n for n in tree.body
           if isinstance(n, py_ast.FunctionDef) and n.name == 'parse_expr']
    if len(fns) != 1:
        raise Refused('define exactly one function named parse_expr(tokens)')
    return tree


def canon(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'))


def run(payload):
    code = payload.get('code', '')
    src = payload.get('source', '')
    if len(src) > MAX_SOURCE:
        raise Refused('source is longer than 4096 characters (bounded input)')
    tree = validate(code)
    namespace = {'__builtins__': SAFE_BUILTINS}
    exec(compile(tree, '<learner>', 'exec'), namespace)
    tokens = frontier.lex(src)
    got = namespace['parse_expr'](tokens)
    if not isinstance(got, dict):
        raise Refused('parse_expr must return an AST object')
    # The expected tree is produced by the FIXED reference parser, which is
    # itself checked against CPython's ast by tools/verify_front.py.  When the
    # source is the shipped specimen we also require the fixture to agree, so
    # a fixture that drifted cannot silently become the oracle.
    expected = frontier.parse(tokens)
    sample_dir = frontier.fixture_dir()
    specimen = open(os.path.join(sample_dir, 'specimen.src'),
                    encoding='utf-8').read().strip()
    if src.strip() == specimen:
        fixture = json.load(open(os.path.join(sample_dir, 'specimen.ast.json'),
                                 encoding='utf-8'))
        if canon(fixture) != canon(expected):
            raise Refused('the shipped fixture disagrees with the reference parser')
    return {
        'ok': True,
        'tokens': tokens,
        'ast': got,
        'expected': expected,
        'match': canon(got) == canon(expected),
        'note': 'expected tree comes from the reference parser, cross-checked with CPython ast',
    }


def main():
    try:
        raw = sys.stdin.read(MAX_CODE + MAX_SOURCE + 4096)
        if len(raw) > MAX_CODE + MAX_SOURCE + 4096:
            raise Refused('submission is too large')
        payload = json.loads(raw)
        answer = run(payload)
    except Refused as exc:
        answer = {'ok': False, 'error': str(exc)}
    except frontier.FrontError as exc:
        answer = {'ok': False, 'error': str(exc)}
    except Exception as exc:
        answer = {'ok': False, 'error': '%s: %s' % (type(exc).__name__, exc)}
    sys.stdout.write(json.dumps(answer, sort_keys=True))
    return 0


if __name__ == '__main__':
    sys.exit(main())
