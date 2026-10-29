# SPDX-License-Identifier: GPL-2.0-or-later
"""Gerador de Python a partir da AST verificada. Guarda o mapa linha Python -> linha Lume para erros."""
from __future__ import annotations

import keyword

from . import nodes as n
from .check import Checker

# Embutidos do Lume e o que viram em Python
BUILTIN_MAP = {"print": "_rt.show", "str": "_rt.to_str", "len": "len", "int": "int", "float": "float",
               "range": "_rt.lrange", "ui": "_rt.ui()"}
PRECEDENCE = {"or": 1, "and": 2, "not": 3, "==": 4, "!=": 4, "<": 4, "<=": 4, ">": 4, ">=": 4,
              "+": 5, "-": 5, "*": 6, "/": 6, "%": 6, "neg": 7}
HEADER = [
    "# Gerado por lumec {version} a partir de {source}. Não editar: edite o .lume e compile de novo.",
    "from lume_runtime import core as _rt",
    "",
]


def mangle(name: str) -> str:
    """Nomes do Lume que são palavras reservadas do Python, ou começam com _rt, ganham sufixo."""
    if keyword.iskeyword(name) or keyword.issoftkeyword(name) or name.startswith("_rt") or name in ("True", "False", "None"):
        return name + "_"
    return name


class CodeGen:
    def __init__(self, checker: Checker, source: str, version: str):
        self.checker = checker
        self.lines: list[str] = [h.format(version=version, source=source) for h in HEADER]
        self.line_map: dict[int, int] = {}  # linha Python (1-based) -> linha Lume

    def emit(self, text: str, depth: int, lume_line: int | None = None) -> None:
        self.lines.append("    " * depth + text)
        if lume_line is not None:
            self.line_map[len(self.lines)] = lume_line

    def program(self, prog: n.Program) -> str:
        self.block(prog.body, 0)
        return "\n".join(self.lines) + "\n"

    def block(self, body: list, depth: int) -> None:
        if not body:
            self.emit("pass", depth)
        for st in body:
            self.stmt(st, depth)

    def stmt(self, st, d: int) -> None:
        if isinstance(st, n.Let):
            self.emit(f"{mangle(st.name)} = {self.expr(st.value)}", d, st.line)
        elif isinstance(st, n.Assign):
            self.emit(f"{self.expr(st.target)} = {self.expr(st.value)}", d, st.line)
        elif isinstance(st, n.ExprStmt):
            self.emit(self.expr(st.expr), d, st.line)
        elif isinstance(st, n.Return):
            self.emit("return" if st.value is None else f"return {self.expr(st.value)}", d, st.line)
        elif isinstance(st, n.If):
            self.if_chain(st, d, "if")
        elif isinstance(st, n.While):
            self.emit(f"while {self.expr(st.cond)}:", d, st.line)
            self.block(st.body, d + 1)
        elif isinstance(st, n.For):
            self.emit(f"for {mangle(st.var)} in {self.expr(st.iterable)}:", d, st.line)
            self.block(st.body, d + 1)
        elif isinstance(st, n.Fn):
            params = ", ".join(mangle(p) for p in st.params)
            self.emit(f"def {mangle(st.name)}({params}):", d, st.line)
            scope = self.checker.fn_scopes[id(st)]
            if scope.rebinds_global:
                self.emit("global " + ", ".join(sorted(mangle(x) for x in scope.rebinds_global)), d + 1)
            if scope.rebinds_nonlocal:
                self.emit("nonlocal " + ", ".join(sorted(mangle(x) for x in scope.rebinds_nonlocal)), d + 1)
            self.block(st.body, d + 1)

    def if_chain(self, st: n.If, d: int, kw: str) -> None:
        self.emit(f"{kw} {self.expr(st.cond)}:", d, st.line)
        self.block(st.body, d + 1)
        if len(st.orelse) == 1 and isinstance(st.orelse[0], n.If):
            self.if_chain(st.orelse[0], d, "elif")
        elif st.orelse:
            self.emit("else:", d)
            self.block(st.orelse, d + 1)

    def expr(self, e, parent_prec: int = 0) -> str:
        if isinstance(e, n.Literal):
            return repr(e.value)
        if isinstance(e, n.Name):
            return BUILTIN_MAP.get(e.id) if e.id in BUILTIN_MAP else mangle(e.id)
        if isinstance(e, n.ListLit):
            return "[" + ", ".join(self.expr(i) for i in e.items) + "]"
        if isinstance(e, n.Unary):
            if e.op == "not":
                out, prec = f"not {self.expr(e.operand, PRECEDENCE['not'])}", PRECEDENCE["not"]
            else:
                out, prec = f"-{self.expr(e.operand, PRECEDENCE['neg'])}", PRECEDENCE["neg"]
            return f"({out})" if prec < parent_prec else out
        if isinstance(e, n.Binary):
            prec = PRECEDENCE[e.op]
            # +1 à direita: a - (b - c) mantém os parênteses; comparações nunca encadeiam
            out = f"{self.expr(e.left, prec)} {e.op} {self.expr(e.right, prec + 1)}"
            return f"({out})" if prec < parent_prec or (prec == 4 and parent_prec == 4) else out
        if isinstance(e, n.Call):
            return f"{self.expr(e.func, 8)}(" + ", ".join(self.expr(a) for a in e.args) + ")"
        if isinstance(e, n.Index):
            return f"{self.expr(e.target, 8)}[{self.expr(e.index)}]"
        if isinstance(e, n.Attr):
            return f"{self.expr(e.target, 8)}.{e.name}"
        raise TypeError(type(e).__name__)  # pragma: no cover
