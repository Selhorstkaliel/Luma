#!/usr/bin/env python3
"""Lexer, parser e verificador do Lume: tokens, precedência e mensagens de erro com linha:coluna."""
import unittest

import _util  # noqa: F401  (caminho de importação)
from lumec import LumeError
from lumec.check import check
from lumec.lexer import tokenize
from lumec.parser import parse


def error_of(src):
    with unittest.TestCase().assertRaises(LumeError) as cm:
        check(parse(src))
    e = cm.exception
    return e.line, e.col, e.message


class TestLexer(unittest.TestCase):
    def test_tokens_and_positions(self):
        toks = tokenize('let x = 3.5\nprint("a\\n")  # comentário\n')
        kinds = [(t.kind, t.value) for t in toks]
        self.assertEqual(kinds, [("KEYWORD", "let"), ("IDENT", "x"), ("OP", "="), ("NUMBER", 3.5), ("NEWLINE", None),
                                 ("IDENT", "print"), ("OP", "("), ("STRING", "a\n"), ("OP", ")"), ("NEWLINE", None),
                                 ("EOF", None)])
        self.assertEqual((toks[5].line, toks[5].col), (2, 1))

    def test_newlines_inside_brackets_are_ignored(self):
        toks = tokenize("f(1,\n  2)\n")
        self.assertEqual(sum(t.kind == "NEWLINE" for t in toks), 1)

    def test_lexer_errors(self):
        with self.assertRaises(LumeError) as cm:
            tokenize('let s = "sem fim\n')
        self.assertEqual((cm.exception.line, cm.exception.col), (1, 9))
        with self.assertRaises(LumeError):
            tokenize("let x = 1 @ 2")


class TestParser(unittest.TestCase):
    def test_precedence(self):
        prog = parse("let x = 1 + 2 * 3 == 7 and not false\n")
        e = prog.body[0].value
        self.assertEqual(e.op, "and")
        self.assertEqual(e.left.op, "==")
        self.assertEqual(e.left.left.op, "+")
        self.assertEqual(e.left.left.right.op, "*")

    def test_chained_comparison_rejected(self):
        with self.assertRaises(LumeError):
            parse("let x = 1 < 2 < 3\n")

    def test_missing_brace(self):
        with self.assertRaises(LumeError) as cm:
            parse("fn f() {\n  return 1\n")
        self.assertIn("'}'", cm.exception.message)


class TestChecker(unittest.TestCase):
    def test_undeclared_name(self):
        self.assertEqual(error_of("print(y)\n")[:2], (1, 7))

    def test_assign_without_let(self):
        self.assertIn("let z", error_of("z = 1\n")[2])

    def test_redeclare_same_function(self):
        self.assertIn("já foi declarado", error_of("let a = 1\nlet a = 2\n")[2])

    def test_return_outside_function(self):
        self.assertIn("fora de função", error_of("return 1\n")[2])

    def test_builtin_cannot_be_redeclared(self):
        self.assertIn("embutido", error_of("let print = 1\n")[2])

    def test_top_level_functions_visible_before_definition(self):
        check(parse("fn a() {\n  return b()\n}\nfn b() {\n  return 1\n}\n"))


if __name__ == "__main__":
    unittest.main()
