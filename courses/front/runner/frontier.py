#!/usr/bin/env python3
"""frontier.py -- the reference front end for the Underlayer `front` course.

This is a REAL lexer and recursive-descent parser for a deliberately small,
documented language: integer arithmetic expressions from the Python language,
restricted to NAME, NUMBER, +, -, *, / and parentheses.  Every claim the course
makes about this code is checked against two independent authorities:

  * the token stream is compared with CPython's own `tokenize` module;
  * the AST is compared with CPython's own `ast.parse(..., mode='eval')`.

Toolchain used to author and verify: CPython 3.12.2 (MSC v.1937 64 bit AMD64),
2026-11-28.  See courses/front/research.md for the exact citation and the list
of what this language deliberately does NOT contain.

This module is dependency-free and performs no I/O unless `main` is called.
It is imported by tools/verify_front.py and by the sandbox runner.
"""
import json
import os
import sys

OPS = frozenset('+-*/()')
BINOPS = {'+': 'Add', '-': 'Sub', '*': 'Mult', '/': 'Div'}


class FrontError(Exception):
    """A calm, specific error about the learner's source."""


def lex(src):
    """Return a list of [kind, text] pairs, kind in {NAME, NUMBER, OP}.

    Offsets are character offsets into `src`, zero based; the error message
    reports them so a learner can locate the offending input.  Whitespace is
    skipped.  Anything outside the documented subset is refused rather than
    silently accepted.
    """
    if len(src) > 4096:
        raise FrontError('source is longer than 4096 characters (bounded input)')
    out = []
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        if c.isspace():
            i += 1
            continue
        if c.isdigit():
            j = i + 1
            while j < n and src[j].isdigit():
                j += 1
            out.append(['NUMBER', src[i:j]])
            i = j
            continue
        if c.isalpha() or c == '_':
            j = i + 1
            while j < n and (src[j].isalnum() or src[j] == '_'):
                j += 1
            out.append(['NAME', src[i:j]])
            i = j
            continue
        if c in OPS:
            out.append(['OP', c])
            i += 1
            continue
        raise FrontError('unexpected character %r at offset %d' % (c, i))
    return out


def parse(tokens):
    """Parse a token stream with a recursive-descent grammar.

        expr    := term (('+' | '-') term)*
        term    := unary (('*' | '/') unary)*
        unary   := '-' unary | primary
        primary := NUMBER | NAME | '(' expr ')'

    The grammar mirrors CPython's precedence for these five operators: unary
    minus binds tighter than * and /, which bind tighter than + and -, and all
    four binary operators are left-associative.  `-3` is a UnaryOp(USub, 3),
    matching CPython rather than folding a negative literal.
    """
    pos = 0
    steps = 0

    def bump():
        nonlocal steps
        steps += 1
        if steps > 100000:
            raise FrontError('parse step limit exceeded (bounded work)')

    def peek():
        return tokens[pos] if pos < len(tokens) else None

    def take():
        nonlocal pos
        tok = peek()
        if tok is None:
            raise FrontError('expected more input, reached end of source')
        pos += 1
        return tok

    def primary():
        bump()
        tok = take()
        if tok[0] == 'NUMBER':
            return {'k': 'num', 'v': int(tok[1])}
        if tok[0] == 'NAME':
            return {'k': 'name', 'v': tok[1]}
        if tok[0] == 'OP' and tok[1] == '(':
            node = expr()
            close = take()
            if close != ['OP', ')']:
                raise FrontError('expected ) after (, got %s' % close[1])
            return node
        raise FrontError('expected a number, a name, or (, got %s' % tok[1])

    def unary():
        bump()
        tok = peek()
        if tok is not None and tok[0] == 'OP' and tok[1] == '-':
            take()
            return {'k': 'un', 'op': 'USub', 'v': unary()}
        return primary()

    def term():
        bump()
        node = unary()
        while True:
            tok = peek()
            if tok is None or tok[0] != 'OP' or tok[1] not in ('*', '/'):
                return node
            op = take()[1]
            node = {'k': 'bin', 'op': BINOPS[op], 'l': node, 'r': unary()}

    def expr():
        bump()
        node = term()
        while True:
            tok = peek()
            if tok is None or tok[0] != 'OP' or tok[1] not in ('+', '-'):
                return node
            op = take()[1]
            node = {'k': 'bin', 'op': BINOPS[op], 'l': node, 'r': term()}

    if not tokens:
        raise FrontError('empty source has no expression')
    root = expr()
    if pos != len(tokens):
        raise FrontError('unexpected token %s at offset %d' %
                         (tokens[pos][1], pos))
    return root


def node_count(node):
    if node['k'] in ('num', 'name'):
        return 1
    if node['k'] == 'un':
        return 1 + node_count(node['v'])
    return 1 + node_count(node['l']) + node_count(node['r'])


def fixture_dir():
    return os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        'assets', 'samples')


def load_fixtures(root=None):
    root = root or fixture_dir()
    with open(os.path.join(root, 'specimen.tokens.json'), encoding='utf-8') as f:
        tokens = json.load(f)
    with open(os.path.join(root, 'specimen.ast.json'), encoding='utf-8') as f:
        ast = json.load(f)
    return tokens, ast


def main(argv):
    if len(argv) < 2:
        print('usage: frontier.py --selftest | --lex SRC | --parse SRC')
        return 2
    if argv[1] == '--selftest':
        src = open(os.path.join(fixture_dir(), 'specimen.src'),
                   encoding='utf-8').read().strip()
        tokens = lex(src)
        node = parse(tokens)
        et, ea = load_fixtures()
        print('tokens=%d ast_nodes=%d token_fixture=%s ast_fixture=%s' %
              (len(tokens), node_count(node), tokens == et, node == ea))
        return 0 if tokens == et and node == ea else 1
    if argv[1] in ('--lex', '--parse'):
        src = argv[2] if len(argv) > 2 else ''
        tokens = lex(src)
        print(json.dumps(tokens if argv[1] == '--lex' else parse(tokens)))
        return 0
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv))
