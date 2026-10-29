# SPDX-License-Identifier: GPL-2.0-or-later
"""Verificação de escopo do Lume 0.1 e coleta do que o gerador de código precisa.

Regras (spec-0.1): variáveis existem a partir do `let` e valem na função inteira (escopo de função,
como em Python); redeclarar na mesma função é erro; atribuir a nome não declarado é erro; usar nome
não declarado é erro; `return` só dentro de função. Funções são declaradas antes do uso no mesmo nível
(as de nível superior podem ser chamadas antes da definição, dentro de outras funções).
"""
from __future__ import annotations

from dataclasses import dataclass, field

from . import LumeError
from . import nodes as n

BUILTINS = {"print", "len", "str", "int", "float", "range", "ui"}


@dataclass
class Scope:
    parent: Scope | None
    is_function: bool
    names: set = field(default_factory=set)
    # nomes de escopos externos que esta função reatribui: global (nível superior) ou nonlocal
    rebinds_global: set = field(default_factory=set)
    rebinds_nonlocal: set = field(default_factory=set)

    def lookup(self, name: str) -> Scope | None:
        s = self
        while s is not None:
            if name in s.names:
                return s
            s = s.parent
        return None


class Checker:
    def __init__(self):
        self.root = Scope(None, False)
        self.fn_scopes: dict[int, Scope] = {}  # id(nodes.Fn) -> escopo da função

    def check(self, prog: n.Program) -> None:
        # Funções do nível superior ficam visíveis em todo o arquivo (chamada mútua, recursão)
        for st in prog.body:
            if isinstance(st, n.Fn):
                self.declare(self.root, st.name, st)
        self.block(prog.body, self.root, top=True)

    def declare(self, scope: Scope, name: str, node: n.Node) -> None:
        if name in BUILTINS:
            raise LumeError(f"'{name}' é um nome embutido e não pode ser redeclarado", node.line, node.col)
        if name in scope.names:
            raise LumeError(f"'{name}' já foi declarado nesta função", node.line, node.col)
        scope.names.add(name)

    def block(self, body: list, scope: Scope, top: bool = False) -> None:
        for st in body:
            self.stmt(st, scope, top)

    def stmt(self, st, scope: Scope, top: bool) -> None:
        if isinstance(st, n.Let):
            self.expr(st.value, scope)
            self.declare(scope, st.name, st)
        elif isinstance(st, n.Assign):
            self.expr(st.value, scope)
            if isinstance(st.target, n.Name):
                self.rebind(st.target, scope)
            else:
                self.expr(st.target, scope)
        elif isinstance(st, n.ExprStmt):
            self.expr(st.expr, scope)
        elif isinstance(st, n.Return):
            if not self.inside_function(scope):
                raise LumeError("'return' fora de função", st.line, st.col)
            if st.value is not None:
                self.expr(st.value, scope)
        elif isinstance(st, n.If):
            self.expr(st.cond, scope)
            self.block(st.body, scope)
            self.block(st.orelse, scope)
        elif isinstance(st, n.While):
            self.expr(st.cond, scope)
            self.block(st.body, scope)
        elif isinstance(st, n.For):
            self.expr(st.iterable, scope)
            if st.var not in scope.names:
                self.declare(scope, st.var, st)
            self.block(st.body, scope)
        elif isinstance(st, n.Fn):
            if not (top and scope is self.root):
                self.declare(scope, st.name, st)
            inner = Scope(scope, True)
            self.fn_scopes[id(st)] = inner
            for p in st.params:
                self.declare(inner, p, st)
            self.block(st.body, inner)
        else:  # pragma: no cover - o parser só produz os nós acima
            raise LumeError(f"instrução desconhecida: {type(st).__name__}", st.line, st.col)

    @staticmethod
    def inside_function(scope: Scope) -> bool:
        return scope.is_function

    def rebind(self, target: n.Name, scope: Scope) -> None:
        owner = scope.lookup(target.id)
        if owner is None:
            if target.id in BUILTINS:
                raise LumeError(f"'{target.id}' é embutido e não pode receber valor", target.line, target.col)
            raise LumeError(f"'{target.id}' não foi declarado; use 'let {target.id} = ...'", target.line, target.col)
        if owner is not scope and scope.is_function:
            (scope.rebinds_global if owner is self.root else scope.rebinds_nonlocal).add(target.id)

    def expr(self, e, scope: Scope) -> None:
        if isinstance(e, n.Literal):
            return
        if isinstance(e, n.Name):
            if e.id not in BUILTINS and scope.lookup(e.id) is None:
                raise LumeError(f"'{e.id}' não foi declarado", e.line, e.col)
        elif isinstance(e, n.ListLit):
            for i in e.items:
                self.expr(i, scope)
        elif isinstance(e, n.Unary):
            self.expr(e.operand, scope)
        elif isinstance(e, n.Binary):
            self.expr(e.left, scope)
            self.expr(e.right, scope)
        elif isinstance(e, n.Call):
            self.expr(e.func, scope)
            for a in e.args:
                self.expr(a, scope)
        elif isinstance(e, n.Index):
            self.expr(e.target, scope)
            self.expr(e.index, scope)
        elif isinstance(e, n.Attr):
            self.expr(e.target, scope)


def check(prog: n.Program) -> Checker:
    c = Checker()
    c.check(prog)
    return c
