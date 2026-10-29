# SPDX-License-Identifier: GPL-2.0-or-later
"""Parser de descida recursiva: tokens -> nodes.Program.

Precedência (da menor para a maior): or, and, not, comparação, + -, * / %, - unário, chamada/índice/atributo.
"""
from __future__ import annotations

from . import LumeError
from . import nodes as n
from .lexer import Token, tokenize

COMPARISON = {"==", "!=", "<", "<=", ">", ">="}


class Parser:
    def __init__(self, tokens: list[Token]):
        self.toks, self.pos = tokens, 0

    # --- utilitários ---
    @property
    def tok(self) -> Token:
        return self.toks[self.pos]

    def at(self, kind: str, value=None) -> bool:
        t = self.tok
        return t.kind == kind and (value is None or t.value == value)

    def at_op(self, *ops: str) -> bool:
        return self.tok.kind == "OP" and self.tok.value in ops

    def advance(self) -> Token:
        t = self.tok
        self.pos += 1
        return t

    def expect(self, kind: str, value=None, what: str | None = None) -> Token:
        if not self.at(kind, value):
            wanted = what or (repr(value) if value is not None else kind.lower())
            raise LumeError(f"esperado {wanted}, encontrado {self.describe(self.tok)}", self.tok.line, self.tok.col)
        return self.advance()

    @staticmethod
    def describe(t: Token) -> str:
        if t.kind == "NEWLINE":
            return "fim de linha"
        if t.kind == "EOF":
            return "fim do arquivo"
        return repr(t.value)

    def skip_newlines(self) -> None:
        while self.at("NEWLINE"):
            self.advance()

    def end_statement(self) -> None:
        if self.at("NEWLINE"):
            self.advance()
        elif not (self.at_op("}") or self.at("EOF")):
            raise LumeError(f"esperado fim de linha, encontrado {self.describe(self.tok)}", self.tok.line, self.tok.col)

    # --- instruções ---
    def program(self) -> n.Program:
        body = []
        self.skip_newlines()
        while not self.at("EOF"):
            body.append(self.statement())
            self.skip_newlines()
        return n.Program(1, 1, body)

    def block(self) -> list:
        self.expect("OP", "{")
        body = []
        self.skip_newlines()
        while not self.at_op("}"):
            if self.at("EOF"):
                raise LumeError("bloco sem '}' de fechamento", self.tok.line, self.tok.col)
            body.append(self.statement())
            self.skip_newlines()
        self.advance()
        return body

    def statement(self):
        t = self.tok
        if self.at("KEYWORD", "let"):
            self.advance()
            name = self.expect("IDENT", what="nome da variável").value
            self.expect("OP", "=")
            node = n.Let(t.line, t.col, name, self.expression())
            self.end_statement()
            return node
        if self.at("KEYWORD", "fn"):
            self.advance()
            name = self.expect("IDENT", what="nome da função").value
            self.expect("OP", "(")
            params = []
            while not self.at_op(")"):
                params.append(self.expect("IDENT", what="nome de parâmetro").value)
                if not self.at_op(")"):
                    self.expect("OP", ",")
            self.advance()
            node = n.Fn(t.line, t.col, name, params, self.block())
            self.end_statement()
            return node
        if self.at("KEYWORD", "return"):
            self.advance()
            value = None if (self.at("NEWLINE") or self.at_op("}") or self.at("EOF")) else self.expression()
            node = n.Return(t.line, t.col, value)
            self.end_statement()
            return node
        if self.at("KEYWORD", "if"):
            node = self.if_statement()
            self.end_statement()
            return node
        if self.at("KEYWORD", "while"):
            self.advance()
            node = n.While(t.line, t.col, self.expression(), self.block())
            self.end_statement()
            return node
        if self.at("KEYWORD", "for"):
            self.advance()
            var = self.expect("IDENT", what="nome da variável do for").value
            self.expect("KEYWORD", "in")
            node = n.For(t.line, t.col, var, self.expression(), self.block())
            self.end_statement()
            return node
        expr = self.expression()
        if self.at_op("="):
            if not isinstance(expr, (n.Name, n.Index, n.Attr)):
                raise LumeError("só é possível atribuir a variável, índice ou atributo", t.line, t.col)
            self.advance()
            node = n.Assign(t.line, t.col, expr, self.expression())
        else:
            node = n.ExprStmt(t.line, t.col, expr)
        self.end_statement()
        return node

    def if_statement(self) -> n.If:
        t = self.expect("KEYWORD", "if")
        cond = self.expression()
        body = self.block()
        orelse = []
        if self.at("KEYWORD", "else"):
            self.advance()
            orelse = [self.if_statement()] if self.at("KEYWORD", "if") else self.block()
        return n.If(t.line, t.col, cond, body, orelse)

    # --- expressões ---
    def expression(self):
        return self.or_expr()

    def or_expr(self):
        left = self.and_expr()
        while self.at("KEYWORD", "or"):
            t = self.advance()
            left = n.Binary(t.line, t.col, "or", left, self.and_expr())
        return left

    def and_expr(self):
        left = self.not_expr()
        while self.at("KEYWORD", "and"):
            t = self.advance()
            left = n.Binary(t.line, t.col, "and", left, self.not_expr())
        return left

    def not_expr(self):
        if self.at("KEYWORD", "not"):
            t = self.advance()
            return n.Unary(t.line, t.col, "not", self.not_expr())
        return self.comparison()

    def comparison(self):
        left = self.additive()
        if self.tok.kind == "OP" and self.tok.value in COMPARISON:
            t = self.advance()
            left = n.Binary(t.line, t.col, t.value, left, self.additive())
            if self.tok.kind == "OP" and self.tok.value in COMPARISON:
                raise LumeError("comparações encadeadas não são permitidas; use 'and'", self.tok.line, self.tok.col)
        return left

    def additive(self):
        left = self.term()
        while self.at_op("+", "-"):
            t = self.advance()
            left = n.Binary(t.line, t.col, t.value, left, self.term())
        return left

    def term(self):
        left = self.unary()
        while self.at_op("*", "/", "%"):
            t = self.advance()
            left = n.Binary(t.line, t.col, t.value, left, self.unary())
        return left

    def unary(self):
        if self.at_op("-"):
            t = self.advance()
            return n.Unary(t.line, t.col, "-", self.unary())
        return self.postfix()

    def postfix(self):
        expr = self.primary()
        while True:
            if self.at_op("("):
                t = self.advance()
                args = []
                while not self.at_op(")"):
                    args.append(self.expression())
                    if not self.at_op(")"):
                        self.expect("OP", ",")
                self.advance()
                expr = n.Call(t.line, t.col, expr, args)
            elif self.at_op("["):
                t = self.advance()
                index = self.expression()
                self.expect("OP", "]")
                expr = n.Index(t.line, t.col, expr, index)
            elif self.at_op("."):
                t = self.advance()
                expr = n.Attr(t.line, t.col, expr, self.expect("IDENT", what="nome de atributo").value)
            else:
                return expr

    def primary(self):
        t = self.tok
        if t.kind in ("NUMBER", "STRING"):
            self.advance()
            return n.Literal(t.line, t.col, t.value)
        if t.kind == "KEYWORD" and t.value in ("true", "false", "nil"):
            self.advance()
            return n.Literal(t.line, t.col, {"true": True, "false": False, "nil": None}[t.value])
        if t.kind == "IDENT":
            self.advance()
            return n.Name(t.line, t.col, t.value)
        if self.at_op("("):
            self.advance()
            expr = self.expression()
            self.expect("OP", ")")
            return expr
        if self.at_op("["):
            self.advance()
            items = []
            while not self.at_op("]"):
                items.append(self.expression())
                if not self.at_op("]"):
                    self.expect("OP", ",")
            self.advance()
            return n.ListLit(t.line, t.col, items)
        raise LumeError(f"expressão esperada, encontrado {self.describe(t)}", t.line, t.col)


def parse(src: str) -> n.Program:
    return Parser(tokenize(src)).program()
