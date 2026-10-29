# SPDX-License-Identifier: GPL-2.0-or-later
"""Árvore sintática do Lume. Cada nó guarda a linha e a coluna de origem."""
from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class Node:
    line: int
    col: int


# --- expressões ---
@dataclass
class Literal(Node):
    value: object


@dataclass
class Name(Node):
    id: str


@dataclass
class ListLit(Node):
    items: list


@dataclass
class Unary(Node):
    op: str
    operand: Node


@dataclass
class Binary(Node):
    op: str
    left: Node
    right: Node


@dataclass
class Call(Node):
    func: Node
    args: list


@dataclass
class Index(Node):
    target: Node
    index: Node


@dataclass
class Attr(Node):
    target: Node
    name: str


# --- instruções ---
@dataclass
class Let(Node):
    name: str
    value: Node


@dataclass
class Assign(Node):
    target: Node
    value: Node


@dataclass
class ExprStmt(Node):
    expr: Node


@dataclass
class Return(Node):
    value: Node | None


@dataclass
class If(Node):
    cond: Node
    body: list
    orelse: list = field(default_factory=list)


@dataclass
class While(Node):
    cond: Node
    body: list


@dataclass
class For(Node):
    var: str
    iterable: Node
    body: list


@dataclass
class Fn(Node):
    name: str
    params: list
    body: list


@dataclass
class Program(Node):
    body: list
